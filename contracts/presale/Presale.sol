pragma solidity ^0.4.24;

import "../ERC20/IERC20.sol";
import "../crowdsale/ICrowdsale.sol";
import "./IPresale.sol";
import "../access/roles/ManagerRole.sol";
import "../access/roles/RecoverRole.sol";
import "../math/SafeMath.sol";

/**
 * @title Presale module contract
 *
 */
contract Presale is IPresale, ManagerRole, RecoverRole {
    using SafeMath for uint256;
    
    /*
     *  Storage
     */

    mapping (address => uint256) private _presaleBalances;
    
    mapping (address => VestData) private _vestData;
    
    struct VestData {
        mapping (uint256 => bool) vested; // flag if current pahse has already vested
        uint256 vestingBalance; // the account balance when the vesting period started
        uint256 vestingPeriod; // the total number of blocks this account is vested for
        uint256 vestedAmount; // the amount of tokens already vested
        bool vestApproved; // system flag to approve vesting
         
    }

    struct VestSchedule {
        uint256 months;
        uint256 initial;
        uint256 extended;
    }

    uint256 private _vestingBlock;

    uint256 private _presaleAllocation;

    uint256 private _totalPresaleSupply;
    
    uint256[5] private _vestThresholds;

    bool private _vestReady;

    VestSchedule[5] private _vestSchedules;
    
    uint256 private MONTH_BLOCKS = 172800;
    
    Stages public stages;

    IERC20 public erc20;

    ICrowdsale public crowdsale;
    /*
     *  Enums
     */
    enum Stages {
        PresaleDeployed,
        Presale,
        Vesting
    }

    /*
     *  Modifiers
     */
    modifier atStage(Stages _stage) {
        require(stages == _stage, "functionality not allowed at current stage");
        _;
    }

    modifier onlyCrowdsale() {
        require(msg.sender == address(crowdsale), "only the crowdsale can call this function");
        _;
    }

    /**
    * @dev Constructor
    * @param token_ TBNERC20 token contract
    */
    constructor(
        IERC20 token_
    ) public {
        require(token_ != address(0), "token address cannot be 0x0");
        erc20 = token_;
        stages = Stages.PresaleDeployed;
    }

    /**
    * @dev Fallback reverts any ETH payment 
    */
    function () public payable {
        revert (); 
    }  

    /**
    * @dev Total number of tokens available for presale distribution
    */
    function totalPresaleSupply() public view returns (uint256) {
        return _totalPresaleSupply;
    }

    /**
    * @dev Total number of tokens allocated to presale
    */
    function getPresaleAllocation() public view returns (uint256) {
        return _presaleAllocation;
    }

    /**
    * @dev Gets the balance of the specified address.
    * @param account The address to query the balance of.
    * @return An uint256 representing the amount owned by the passed address.
    */
    function presaleBalanceOf(address account) public view returns (uint256) {
        return _presaleBalances[account];
    }

    /**
    * @dev Gets the static vesting balance of the specified address.
    * @param account The address to query the balance of.
    * @return The static amount of total vesting balance.
    */
    function getVestingBalance(address account) public view atStage(Stages.Vesting) returns (uint256) {
        return _vestData[account].vestingBalance;
    }

    /**
    * @dev Gets the vesting period of the specified address.
    * @param account The address to query the period of.
    * @return The total vesting period in blocks.
    */
    function getVestingPeriod(address account) public view atStage(Stages.Vesting) returns (uint256) {
        return _vestData[account].vestingPeriod;
    }

    /**
    * @dev Gets the vesting schedule of this account (returns schedule based on presaleBalances if called before Vesting Stage, otherwise based on vestingBalance)
    * @param account The address to vested amount
    * @return The total amount of tokens vested by this account
    */
    function getVestingSchedule(address account) public view atStage(Stages.Vesting) returns (uint256, uint256, uint256) {
        uint256 balance;
        if(_getIndex(_vestData[account].vestingBalance) == 0) {
            balance = _presaleBalances[account];
        } else {
            balance = _vestData[account].vestingBalance;
        }
        uint256 index = _getIndex(balance);
        if(index > 0){ // higher tier schedules
            uint256 months = _vestSchedules[index.sub(1)].months;
            uint256 initial = _vestSchedules[index.sub(1)].initial;
            uint256 extended = _vestSchedules[index.sub(1)].extended;
            return (months, initial, extended);
        } else { // lowest tier can vest all initially
            return (0, 1000000, 0);
        }
    }

    /**
    * @dev Gets the amount of token already vest and sent out of this contract
    * @param account The address to vested amount
    * @return The total amount of tokens vested by this account
    */
    function getVestedAmount(address account) public view atStage(Stages.Vesting) returns (uint256) {
        return _vestData[account].vestedAmount;
    }

    /**
    * @dev Gets the vesting status of this account (returns 0 until account calls vest or manager calls vestingApproved)
    * @param account The address to vested amount
    * @return The total amount of tokens vested by this account
    */
    function getVestApproved(address account) public view atStage(Stages.Vesting) returns (bool) {
        return _vestData[account].vestApproved;
    }
    
    function getERC20() public view returns (address) {
        return address(erc20);
    }

    // check the status of this contract to see if it has been set as ready to vest
    function readyToVest() public view returns (bool) {
        return _vestReady;
    }

    /**
    * @dev Transfer presale tokens to another account
    * @param to The address to transfer to.
    * @param value The amount to be transferred.
    * @return bool true on success
    */
    function presaleTransfer(address to, uint256 value) external atStage(Stages.Presale) returns (bool) {
        _presaleTransfer(msg.sender, to, value);
        return true;
    }

    /**
    * @dev Vest and transfer any available vesting tokens based on schedule and approval
    * @return True when successful
    */
    function vest() external atStage(Stages.Vesting) returns (bool){
        uint256 currentBalance = _presaleBalances[msg.sender];
        require(currentBalance > 0, "must have tokens to vest");

        if( _vestData[msg.sender].vestingBalance == 0 ) { // first vest call sets vestingBalance
            _vestData[msg.sender].vestingBalance = currentBalance;
            _vestData[msg.sender].vestApproved = true;
            emit VestApproved(msg.sender);
            return true;
        }

        uint256 index = _getIndex(_vestData[msg.sender].vestingBalance);
        if(index > 0){ // not lowest tier follow the schedule
            uint256 months = _vestSchedules[index.sub(1)].months;
            uint256 initial = _vestSchedules[index.sub(1)].initial;
            uint256 extended = _vestSchedules[index.sub(1)].extended;
        } else { // lowest tier can vest all but needs manager approval
            require(_vestData[msg.sender].vestApproved, "must be approved by manager role to prevent sybil attacks");
            _vestData[msg.sender].vestedAmount = currentBalance;
            _presaleBalances[msg.sender].sub(currentBalance);
        
            erc20.transfer(msg.sender, currentBalance);
            emit Vested(msg.sender, currentBalance);
        }
        
        
        if( _vestData[msg.sender].vestingPeriod == 0 ){ // first vest call sets vestingPeriod
            _vestData[msg.sender].vestingPeriod = MONTH_BLOCKS.mul(months); // these should be set to an internal map with struct for all vesting info
        }
        uint256 totalAllowance = _calcVestAllowance(months, initial, extended);

        uint vestAmount = totalAllowance.sub(_vestData[msg.sender].vestedAmount);

        _vestData[msg.sender].vestedAmount = _vestData[msg.sender].vestedAmount.add(vestAmount);
        _presaleBalances[msg.sender].sub(vestAmount);
        
        erc20.transfer(msg.sender, vestAmount);
        emit Vested(msg.sender, vestAmount);
    }

    /**
    * @dev Assigns the  presale token allocation to this contract. Note: fundkeeper must give this contract an allowance before callin intialize
    * @param presaleAllocation the amount of tokens to assign to this contract for presale distribution
    */
    function initilize(
        uint256 presaleAllocation
    )
        external 
        onlyManager 
        atStage(Stages.PresaleDeployed) 
        returns (bool) 
    {
        address fundkeeper = erc20.fundkeeper();
        require(erc20.allowance(address(fundkeeper), address(this)) == presaleAllocation, "presale allocation must be equal to the amount of tokens approved for this contract");
        erc20.transferFrom(fundkeeper, address(this), presaleAllocation);
        _presaleAllocation = erc20.balanceOf(address(this));
        _totalPresaleSupply = erc20.balanceOf(address(this));
        stages = Stages.Presale;
        return true;
    }

    /**
    * @dev Setup the vesting rules to prepare for the vesting period. Note: must have deployed the crowdsale contract before calling this funciton
    * @param TBNCrowdsale The TBN crowdsale obeject deployed as some address
    * @param vestThresholds An array of the TBN thresholds whereby the different vesting schedules apply
    * @param vestSchedules An array of the the vesting schedule information [#ofMonthsInSchedule, initialPrecentageToVest, monthlyPercentageToVest]
    *   Note: vestSchedules percentages have 4 decimal precision so 100% = 1000000, 16.667% = 166670
    */
    function setupVest(
        uint256[5] vestThresholds, 
        uint256[3][5] vestSchedules
    ) 
        external 
        onlyManager 
        atStage(Stages.Presale) 
        returns (bool) 
    {
        require(vestThresholds[0] > 0, "smallest vesting threshold should be larger than 0");
        require(vestThresholds[4] < _presaleAllocation, "largest vesting threshold must be less than the presale allocation");
        for (uint8 i = 0; i < vestSchedules.length; i++) {
            if(i > 0){
                require(vestThresholds[i] > vestThresholds[i-1], "every threshold must be larger than the last");
            }
        }
        for (uint8 j = 0; j < vestSchedules.length; j++) {
            _vestSchedules[j] = VestSchedule(vestSchedules[j][0], vestSchedules[j][1], vestSchedules[j][2]);
        }
        
        _vestThresholds = vestThresholds;
        _vestReady = true;
        emit VestSetup(vestThresholds, vestSchedules);
        return true;
    }

    /**
    * @dev Set the crowdsale contract storage
    * @param TBNCrowdsale The crowdsale contract deployment
    */
    function setCrowdsale(ICrowdsale TBNCrowdsale)      
        external 
        onlyManager 
        atStage(Stages.Presale) 
        returns (bool) 
    {
        require(TBNCrowdsale.getERC20() == address(erc20), "Crowdsale contract must be assigned to the same ERC20 instance as this contract");
        crowdsale = TBNCrowdsale;
        emit SetCrowdsale(crowdsale);
    }

    /**
    * @dev Assign presale tokens to an account (only manager role and only at the Presale stage)
    * @param presaleAccounts The account which is assigned presale holdings
    * @param values The amount of tokens to be assigned to each account
    */
    function addPresaleBalance(address[] presaleAccounts, uint256[] values) external onlyManager atStage(Stages.Presale) returns (bool) {
        require(presaleAccounts.length == values.length, "presaleAccounts and values must have one-to-one relationship");
        
        for (uint32 i = 0; i < presaleAccounts.length; i++) {
            _addPresaleBalance(presaleAccounts[i], values[i]);
        }
        return true;
    }

    /**
    * @dev Manager role must approve vesting for accounts without a schedule
    * @param account The account to have vesting approved
    */
    function approveVest(address account) external onlyManager atStage(Stages.Vesting) returns (bool) {
        require(!_vestData[account].vestApproved, "this account must not have been previously approved");
        require(_presaleBalances[account] > 0, "must have a balance to approve");
        if( _vestData[msg.sender].vestingBalance == 0 ) { // first approve call sets vestingBalance if not already done
            _vestData[msg.sender].vestingBalance = _presaleBalances[account];
        }
        require(_getIndex(_vestData[msg.sender].vestingBalance) == 0, "vesting balance must be small enough to not have a schedule");
        _vestData[account].vestApproved = true;
        emit VestApproved(account);
        return true;
    }

    /**
    * @dev Manager role can move unapproved balances to a single address so that it may fall under a vesting schedule (in case a sybil attack was discovered)
    */
    function moveBalance(address account, address to) external onlyManager atStage(Stages.Vesting) returns (bool) {
        require(_presaleBalances[account] > 0, "this account must have a balance to move");
        uint256 value = _presaleBalances[account];
        _presaleBalances[account] = 0;
        _presaleBalances[to] = _presaleBalances[to].add(value);
        emit BalanceMoved(account, to, value);
        return true;
    }

    /**
    * @dev Safety function for recovering missent ERC20 tokens
    * @param token_ address of the ERC20 contract to recover
    */
    function recoverLost(IERC20 token_) external onlyRecoverer atStage(Stages.Vesting) returns (bool) {
        token_.transfer(msg.sender, token_.balanceOf(address(this)));
        return true;
    }

   /**
    * @dev Called to change the stage to Vesting. Can only be called by the crwodsale contract and will only be called when the Crowdsale begins
    */
    function startVestingStage() external onlyCrowdsale atStage(Stages.Presale) returns (bool) {
        _vestingBlock = block.number;
        stages = Stages.Vesting;
        return true;
    }

    /**
    * @dev Transfer presale tokens to another account (internal operation)
    * @param from The address to transfer from.
    * @param to The address to transfer to.
    * @param value The amount to be transferred.
    */
    function _presaleTransfer(address from, address to, uint256 value) internal {
        require(value <= _presaleBalances[from], "transfer value must be less than the balance of the from account");
        require(to != address(0), "cannot transfer to the 0x0 address");

        _presaleBalances[from] = _presaleBalances[from].sub(value);
        _presaleBalances[to] = _presaleBalances[to].add(value);
        emit PresaleTransfer(from, to, value);
    }

    /**
    * @dev Assign presale tokens to an account (internal operation)
    * @param presaleAccount The account which is assigned presale holdings
    * @param value The amount of tokens to be assigned to this account
    */
    function _addPresaleBalance(address presaleAccount, uint256 value) internal {
        if(presaleAccount != address(0) && value <= _totalPresaleSupply) {
            _totalPresaleSupply = _totalPresaleSupply.sub(value);
            _presaleBalances[presaleAccount] = _presaleBalances[presaleAccount].add(value);
            emit PresaleBalanceAdded(presaleAccount, value);
        }
    }

    /**
    * @dev Calculate the total vesting allowance for this account (internal operation)
    * @param months The account which is assigned presale holdings
    * @param initial The initial percentage of this account's vesting schedule
    * @param extended The extended percentage of this account's vesting schedule
    * @return The total amount of tokens scheduled to be vested (excluding those tokens already vested)
    */
    function _calcVestAllowance(uint256 months, uint256 initial, uint256 extended) internal returns (uint256) {
        uint256 initialAllowance = _vestData[msg.sender].vestingBalance.mul(initial).div(1000000);
        uint256 blocks = block.number.sub(_vestingBlock);
        uint256 phase = _vestData[msg.sender].vestingPeriod.div(months);

        uint256 multiplier = blocks.div(phase);
        if(multiplier >= months) {
            require(!_vestData[msg.sender].vested[months], "this phase has already been vested");
            _vestData[msg.sender].vested[months] = true;
            return initialAllowance.add(_presaleBalances[msg.sender]);
        }
        require(!_vestData[msg.sender].vested[multiplier], "this phase has already been vested");
        uint256 extendedAllowance = _vestData[msg.sender].vestingBalance.mul(multiplier).mul(extended).div(1000000);
        _vestData[msg.sender].vested[multiplier] = true;
        return initialAllowance.add(extendedAllowance);
    }

    /**
    * @dev Get the index of the vesting schedule for an account given its total balance of presale tokens and the contract vestign thresholds
    * @param vestingBalance The total balance of presale tokens at the time of vesting
    * @return The index of the vesting schedule to follow
    */
    function _getIndex(uint256 vestingBalance) internal view returns (uint256) {
        uint256 index;
        for (uint8 i = 0; i < _vestThresholds.length; i++) {
            if(vestingBalance >= _vestThresholds[i]) {
                index.add(1);
            }
        }
        return index;
    }

}