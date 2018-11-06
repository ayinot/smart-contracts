// (C) block.one all rights reserved

pragma solidity ^0.4.24;

import "../math/SafeMath.sol";
import "../ERC20/IERC20.sol";
import "../presale/IPresale.sol";
import "./ICrowdsale.sol";
import "../access/roles/ManagerRole.sol";
import "../access/roles/RecoverRole.sol";

contract TBNCrowdSale is ICrowdsale, ManagerRole, RecoverRole, FundkeeperRole {
    using SafeMath for uint256;

    uint256 private _numberOfIntervals;     // number of intervals in the sale
    bytes32 private _hiddenCap;             // a hash of <the hidden hard cap(in WEI)>+"SECRET"+<a secret number> to be revealed if/when the hard cap is reached - does not rebase so choose wisely

    IERC20 private _erc20;                  // the TBN ERC20 token deployment
    IPresale private _presale;              // the presale contract deployment
                                                    // Note: 18 decimal precision accomodates ETH prices up to 10**5
    uint256 private _ETHPrice;                      // ETH price in USD with 18 decimal precision for calculating reserve pricing
    uint256 private _reserveFloor;                  // the minimum possible reserve price in USD @ 18 decimal precision
    uint256 private _reserveCeiling;                // the maximum possible reserve price in USD @ 18 decimal precision
    uint256 private _reserveStep = 29166 * 10**10;  // the base amount to step down the price if reserve is not met @ 18 decimals of precision

    uint256 private _crowdsaleAllocation;   // total amount of TBN allocated to the crowdsale contract for distribution
    uint256 private _presaleDistribution;   // total amount of TBN distributed to account in the presale contract

    uint256 private _rebaseNewPrice;        // temporarily holds the rebase ETH price until the next active interval @ decimal 18
    uint256 private _rebaseSet;             // the interval the rebase is set in, set back to 0 after rebasing

    uint256 private WEI_FACTOR = 10**18;    // ETH base in WEI

    uint256 private INTERVAL_BLOCKS = 5520; // number of block per interval - 23 hours @ 15 sec per block
    uint256 private REBASE_BLOCKS = 69120;  // number of blocks per rebase period - 12 days @ 15 sec per block
    
    uint256 private _startBlock;              // block number of the start of interval 0
    
    uint256 private _tokensPerInterval;       // number of tokens available for distribution each interval
    
    uint256 private _lastAdjustedInterval;    // number of tokens available for distribution each interval


    mapping (uint256 => uint256) public dailyTotals;
    mapping (uint256 => bool) public rebased;

    
    struct Interval {
        uint256 reservePrice;  // the reservePrice for this interval @ 18 decimals of precision
        uint256 ETHReserveAmount;
        
    }
    mapping (uint256 => Interval) public intervals;


    mapping (uint256 => mapping (address => uint256)) public participationAmount;
    mapping (uint256 => mapping (address => bool)) public claimed;
    
    Stages public stages;

    /*
     *  Enums
     */
    enum Stages {
        CrowdsaleDeployed,
        Crowdsale,
        CrowdsaleEnded
    }

    /*
     *  Modifiers
     */
    modifier atStage(Stages _stage) {
        require(stages == _stage, "functionality not allowed at current stage");
        _;
    }

    // check that re-serve adjustment is current and all are re-based 
    modifier reChecks() {
        uint256 interval = getInterval(block.number);
        if(_lastAdjustedInterval != interval){
            for (uint i = _lastAdjustedInterval.add(1); i <= interval; i++) {
                _adjustReserve(i);
            }
            _lastAdjustedInterval = interval;
        }

        if(_rebaseSet != 0){
            require(_rebaseNewPrice != 0, "_rebaseNewPrice cannot equal zero");
            // only after ajdustment is current can we rebase
            _rebase(_rebaseNewPrice);
            _;
            _rebaseSet = 0;
        } else {
            _;
        }
    }

    constructor(
        IERC20 token,
        IPresale presale,
        uint256 numberOfIntervals,
        bytes32 hiddenCap
        
    ) public {
        require(address(token) != 0x0, "token address cannot be 0x0");
        require(address(presale) != 0x0, "presale address cannot be 0x0");
        require(presale.getERC20() == address(token), "Presale contract must be assigned to the same ERC20 instance as this contract");
        require(numberOfIntervals > 0, "numberOfIntervals must be larger than zero");

        _numberOfIntervals = numberOfIntervals;
        _hiddenCap = hiddenCap;
        _erc20 = token;
        _presale = presale;

        stages = Stages.CrowdsaleDeployed;
    }

    /**
    * @dev Fallback participates with any ETH payment 
    */
    function () public payable {
        participate(0);
    }

    function getInterval(uint256 blockNumber) public view returns (uint256) {
        return _intervalFor(blockNumber);
    }

    function getERC20() public view returns (address) {
        return address(_erc20);
    }

    function getPresale() public view returns (address) {
        return address(_presale);
    }

    // rebase ETH participation depending on ETH and reserve pricing
    function getMin() public view atStage(Stages.Crowdsale) returns (uint256) {
        uint256 interval = getInterval(block.number);
        uint256 minETH;
        if (_ETHPrice < intervals[interval].reservePrice) {
            minETH = 10 ether;
        } else if (_ETHPrice < intervals[interval].reservePrice.mul(uint256(10))) {
            minETH = 1 ether;
        } else if (_ETHPrice < intervals[interval].reservePrice.mul(uint256(100))) {
            minETH = .1 ether;
        } else if (_ETHPrice < intervals[interval].reservePrice.mul(uint256(1000))) {
            minETH = .01 ether;
        } else {
            minETH = .001 ether;
        }
    }

    // This method provides the participant some protections regarding which
    // day the participation is submitted and the maximum price prior to
    // applying this payment that will be allowed. (price is in TBN per ETH)
    function participate(uint256 limit) public payable reChecks atStage(Stages.Crowdsale) returns (bool) {
        uint256 interval = getInterval(block.number);
        require(interval <= _numberOfIntervals, "interval of current block number must be less than or equal to the number of intervals");
        require(msg.value >= getMin(), "minimum participation amount, enforced to prevent rounding errors in ");

        participationAmount[interval][msg.sender] = participationAmount[interval][msg.sender].add(msg.value);
        dailyTotals[interval] = dailyTotals[interval].add(msg.value);

        if (limit != 0) {
            require(_tokensPerInterval.div(dailyTotals[interval]) <= limit, "");
        }

        emit Participated(interval, msg.sender, msg.value);

        return true;
    }

    function claim(uint256 interval) public reChecks atStage(Stages.Crowdsale) {
        require(stages == Stages.Crowdsale || stages == Stages.CrowdsaleEnded, "must be in the last two stages to call");
        require(getInterval(block.number) > interval, "the given interval must be less than the current interval");

        if (claimed[interval][msg.sender] || dailyTotals[interval] == 0) {
            return;
        }

        //uint256 claiming = dailyTotals[interval].mul(WEI_FACTOR).div(tokensPerInterval).mul(participationAmount[interval][msg.sender]);
        
        uint256 contributorProportion = participationAmount[interval][msg.sender].mul(WEI_FACTOR).div(dailyTotals[interval]);
        uint256 reserveMultiplier;
        if (dailyTotals[interval] >= intervals[interval].ETHReserveAmount){
            reserveMultiplier = WEI_FACTOR;
        } else {
            reserveMultiplier = dailyTotals[interval].mul(WEI_FACTOR).div(intervals[interval].ETHReserveAmount);
        }
        uint256 intervalClaim = _tokensPerInterval.mul(contributorProportion).mul(reserveMultiplier).div(WEI_FACTOR.mul(3));

        claimed[interval][msg.sender] = true;
        _erc20.transfer(msg.sender, intervalClaim);

        emit Claimed(interval, msg.sender, intervalClaim);
    }

    function claimAll() public atStage(Stages.Crowdsale) {
        for (uint i = 0; i < getInterval(block.number); i++) {
            claim(i);
        }
    }

    function initialize(
        uint256 ETHPrice,
        uint256 reserveFloor, 
        uint256 reserveCeiling,
        uint256 crowdsaleAllocation
    ) 
        external 
        onlyManager 
        atStage(Stages.CrowdsaleDeployed) 
        returns (bool) 
    {
        require(ETHPrice > 0, "ETH basis price must be greater than 0"); 
        require(reserveFloor > 0, "the reserve floor must be greater than 0");
        require(reserveCeiling > reserveFloor, "the reserve ceiling must be greater than the reserve floor");
        require(crowdsaleAllocation > 0, "crowdsale allocation must be assigned a number greater than 0");
        
        address fundkeeper = _erc20.fundkeeper();
        require(_erc20.allowance(address(fundkeeper), address(this)) == crowdsaleAllocation, "crowdsale allocation must be equal to the amount of tokens approved for this contract");
        require(_presale.getCrowdsale() == address(this), " crowdsale contract address has not been set in the presale contract yet");

        _ETHPrice = ETHPrice;
        _crowdsaleAllocation = crowdsaleAllocation;
        _reserveFloor = reserveFloor;
        _reserveCeiling = reserveCeiling;
        
        // calc initial intervalReserve
        uint256 interval = getInterval(block.number);
        intervals[interval].reservePrice = reserveCeiling;
        intervals[interval].ETHReserveAmount = _tokensPerInterval.mul(intervals[interval].reservePrice.mul(WEI_FACTOR).div(_ETHPrice));
        
        
        rebased[_rebaseFor(block.number)] = true;

        // place crowdsale allocation in this contract
        _erc20.transferFrom(fundkeeper, address(this), crowdsaleAllocation);

        // end the Presale Stage of the presale contract (therby locking any presale account updates and transferring the distributed presale tokens to this contract for vested claiming)
        _presale.presaleEnd();
        uint256 presaleDistribution = _presale.getPresaleDistribution(); // this can no longer change and is the amount sent to this contract form the presale contract
        _presaleDistribution = presaleDistribution;
        //create variables
        _startBlock = block.number;
        _tokensPerInterval = crowdsaleAllocation.div(_numberOfIntervals);
       
        stages = Stages.Crowdsale;

        return true;
    }

    /**
    * @dev Safety function for recovering missent ERC20 tokens
    * @param token address of the ERC20 contract
    */
    function recoverToken(IERC20 token) external onlyRecoverer atStage(Stages.CrowdsaleEnded) returns (bool) {
        token.transfer(msg.sender, token.balanceOf(address(this)));
        return true;
    }

    // crowdsale manager can rebase the ETH price once ever 12 days
    function setRebase(uint256 newETHPrice) external onlyManager atStage(Stages.Crowdsale) returns (bool) {
        uint256 rebasePeriod = _rebaseFor(block.number);
        require(!rebased[rebasePeriod], "rebase has been successfully run for this period, cannot rebase again");
        _rebaseNewPrice = newETHPrice;
        _rebaseSet = block.number;
        return true;
    }

    // reveal hidden cap (and end sale early)
    function revealCap(uint256 cap, uint256 secret) external onlyManager atStage(Stages.Crowdsale) returns (bool) {
        bytes32 hashed = keccak256(abi.encode(cap, secret));
        if (hashed == _hiddenCap) {
            stages = Stages.CrowdsaleEnded;
            return true;
        }
        return false;
    }

    // Fundkeeper can collect ETH any number of times
    function collect() external onlyFundkeeper returns (bool) {
        msg.sender.transfer(address(this).balance);
        emit Collected(msg.sender, address(this).balance);
    }

    function _rebase(uint256 newETHPrice) internal onlyManager atStage(Stages.Crowdsale) {
        uint256 setRebasePeriod = _rebaseFor(_rebaseSet);
        uint256 rebasePeriod = _rebaseFor(block.number);
        uint256 interval = getInterval(block.number);
        require(setRebasePeriod == rebasePeriod, "current rebase period must match the period when this rebase was initiated");
        
        // new ETH base price
        _ETHPrice = newETHPrice;

        // recalc intervals reserve amount
        intervals[interval].ETHReserveAmount = _tokensPerInterval.mul(intervals[interval].reservePrice.mul(WEI_FACTOR).div(_ETHPrice));

        rebased[rebasePeriod] = true;   // rebase has been successfully run
        _rebaseSet = 0;                 // _rebaseSet block number back to 0
        
        emit Rebased(
            _ETHPrice,
            intervals[interval].ETHReserveAmount
        );
    } 

    // Each rebase cycle is 12 days long (total of 15 rebase periods during the sale)
    //
    function _rebaseFor(uint256 blockNumber) internal view returns (uint256) {
        return blockNumber < _startBlock
            ? 0
            : blockNumber.sub(_startBlock).div(REBASE_BLOCKS);
    }


    // Each window is 23 hours long so that end-of-window rotates
    // around the clock for all timezones.
    function _intervalFor(uint256 blockNumber) internal view returns (uint256) {
        return blockNumber < _startBlock
            ? 0
            : blockNumber.sub(_startBlock).div(INTERVAL_BLOCKS);
    }

    function _adjustReserve(uint256 interval) internal {
        require(_lastAdjustedInterval.add(uint256(1)) == interval, "must adjust exactly the next interval");
        // get last reserve info
        uint256 lastIntervalPrice = dailyTotals[_lastAdjustedInterval].mul(WEI_FACTOR).div(_tokensPerInterval); // token price in ETH
        uint256 lastAmount = intervals[_lastAdjustedInterval].ETHReserveAmount;

        // check if last reserve was met
        uint256 adjustment;
        // adjust reservePrice accordingly
        if (dailyTotals[_lastAdjustedInterval] >= lastAmount){
            if(lastIntervalPrice >= _reserveCeiling){
                intervals[interval].reservePrice = _reserveCeiling;
            } else {
                intervals[interval].reservePrice = dailyTotals[_lastAdjustedInterval].mul(_ETHPrice).div(_tokensPerInterval);
            }
        } else {
            uint256 offset = WEI_FACTOR.sub(dailyTotals[_lastAdjustedInterval].mul(WEI_FACTOR).div(intervals[_lastAdjustedInterval].ETHReserveAmount));
            if (offset < 10**17) {
                adjustment = uint256(1);
            } else if(offset != WEI_FACTOR) {
                adjustment = (offset.div(10**17)).add(uint256(1));
            } else {
                adjustment = uint256(10);
            }

            uint256 newReservePrice = intervals[interval].reservePrice.sub(_reserveStep.mul(adjustment));
            if(newReservePrice <= _reserveFloor){
                intervals[interval].reservePrice = _reserveFloor;
            } else {
                intervals[interval].reservePrice = newReservePrice;
            } 
        }
        // calculate reserveAmount
        intervals[interval].ETHReserveAmount = _tokensPerInterval.mul(intervals[interval].reservePrice.mul(WEI_FACTOR).div(_ETHPrice));
    }

}




    /**
    * @dev Calculate the total vesting allowance for this account (internal operation)
    * @param months The account which is assigned presale holdings
    * @param initial The initial percentage of this account's vesting schedule
    * @param extended The extended percentage of this account's vesting schedule
    * @return The total amount of tokens scheduled to be vested (excluding those tokens already vested)
    
    function _calcVestAllowance(uint256 months, uint256 initial, uint256 extended) internal returns (uint256) {
        uint256 initialAllowance = _vestData[msg.sender].vestingBalance.mul(initial).div(1000000);
        uint256 blocks = block.number.sub(vestingBlock);

        uint256 multiplier = blocks.div(MONTH_BLOCKS);
        
        if(multiplier >= months) {
            require(!_vestData[msg.sender].vested[months], "this phase has already been vested");
            _vestData[msg.sender].vested[months] = true;
            return _vestData[msg.sender].vestingBalance;
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
    
    function _getIndex(uint256 vestingBalance) internal view returns (uint256) {
        uint256 index;
        for (uint256 i = 0; i < _vestThresholds.length; i++) {
            if(vestingBalance >= _vestThresholds[i]) {
                index = i.add(uint256(1));
            }
        }
        return index;
    }

        mapping (address => VestData) private _vestData;
    
    struct VestData {
        mapping (uint256 => bool) vested; // flag if current pahse has already vested
        uint256 vestingBalance; // the account balance when the vesting period started
        uint256 vestingPeriod; // the total number of blocks this account is vested for
        uint256 vestedAmount; // the amount of tokens already vested
        bool vestApproved; // system flag to approve vesting
         
    }

        /**
    * @dev Gets the amount of token already vest and sent out of this contract
    * @param account The address to vested amount
    * @return The total amount of tokens vested by this account
    
    function getVestedAmount(address account) public view atStage(Stages.Vesting) returns (uint256) {
        return _vestData[account].vestedAmount;
    }


    /**
    * @dev Vest and transfer any available vesting tokens based on schedule and approval
    * @return True when successful
    
    function vest() external atStage(Stages.Vesting) returns (bool){
        uint256 currentBalance = _presaleBalances[msg.sender];
        require(currentBalance > 0, "must have tokens to vest");
        
        if( _vestData[msg.sender].vestingBalance == 0 ) { // first vest call sets vestingBalance
            _vestData[msg.sender].vestingBalance = currentBalance;
        }

        uint256 index = _getIndex(_vestData[msg.sender].vestingBalance);
        if(index > 0){ // not lowest tier follow the schedule
            uint256 months = _vestSchedules[index.sub(uint256(1))].months;
            uint256 initial = _vestSchedules[index.sub(uint256(1))].initial;
            uint256 extended = _vestSchedules[index.sub(uint256(1))].extended;
            if( _vestData[msg.sender].vestApproved == false ) { // first vest call sets vestApproved for higher tiers
                _vestData[msg.sender].vestApproved = true;
                emit VestApproved(msg.sender);
            }
        } else { // lowest tier can vest all but needs manager approval
            require(_vestData[msg.sender].vestApproved, "must be approved by manager role to prevent sybil attacks");
            _vestData[msg.sender].vestedAmount = currentBalance;
            _presaleBalances[msg.sender] = _presaleBalances[msg.sender].sub(currentBalance);
            emit Vested(msg.sender, currentBalance);
            erc20.transfer(msg.sender, currentBalance);
            return true;
        }
        
        if( _vestData[msg.sender].vestingPeriod == 0 ){ // first vest call sets vestingPeriod
            _vestData[msg.sender].vestingPeriod = MONTH_BLOCKS.mul(months); // these should be set to an internal map with struct for all vesting info
        }
        uint256 totalAllowance = _calcVestAllowance(months, initial, extended);

        uint vestAmount = totalAllowance.sub(_vestData[msg.sender].vestedAmount);

        _vestData[msg.sender].vestedAmount = _vestData[msg.sender].vestedAmount.add(vestAmount);
        _presaleBalances[msg.sender] = _presaleBalances[msg.sender].sub(vestAmount);
        emit Vested(msg.sender, vestAmount);
        erc20.transfer(msg.sender, vestAmount);
        return true;
    }
    */