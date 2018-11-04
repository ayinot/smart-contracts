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
    
    uint256 private _presaleAllocation;

    uint256 private _totalPresaleSupply;

    IERC20 private _erc20;

    ICrowdsale private _crowdsale;

    Stages public stages;

    /*
     *  Enums
     */
    enum Stages {
        PresaleDeployed,
        Presale,
        PresaleEnded
    }

    /*
     *  Modifiers
     */
    modifier atStage(Stages _stage) {
        require(stages == _stage, "functionality not allowed at current stage");
        _;
    }

    modifier onlyCrowdsale() {
        require(msg.sender == address(_crowdsale), "only the crowdsale can call this function");
        _;
    }

    /**
    * @dev Constructor
    * @param token_ TBNERC20 token contract
    */
    constructor(
        IERC20 token
    ) public {
        require(token != address(0), "token address cannot be 0x0");
        _erc20 = token;
        stages = Stages.PresaleDeployed;
    }

    /**
    * @dev Safety fallback reverts missent ETH payments 
    */
    function () public payable {
        revert (); 
    }  

  /**
    * @dev Safety function for recovering missent ERC20 tokens (and recovering the un-distributed allocation after PresaleEnded)
    * @param token address of the ERC20 contract to recover
    */
    function recoverTokens(IERC20 token) external onlyRecoverer atStage(Stages.PresaleEnded) returns (bool) {
        uint256 recovered = token.balanceOf(address(this));
        token.transfer(msg.sender, recovered);
        emit TokensRecovered(token, recovered);
        return true;
    }

    /**
    * @dev Total number of tokens allocated to presale
    */
    function getPresaleAllocation() public view returns (uint256) {
        return _presaleAllocation;
    }

    /**
    * @dev Total number of presale tokens un-distributed to presale accounts
    */
    function totalPresaleSupply() public view returns (uint256) {
        return _totalPresaleSupply;
    }

    /**
    * @dev Total number of presale tokens distributed to presale accounts
    */
    function getPresaleDistribution() public view returns (uint256) {
        return _presaleAllocation.sub(_totalPresaleSupply);
    }

    /**
    * @dev Gets the balance of the specified address.
    * @param account The address to query the balance of.
    * @return An uint256 representing the amount owned by the passed address.
    */
    function presaleBalanceOf(address account) public view returns (uint256) {
        return _presaleBalances[account];
    }
    
    function getERC20() public view returns (address) {
        return address(_erc20);
    }

    function getCrowdsale() public view returns (address) {
        return address(_crowdsale);
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
        require(presaleAllocation > 0, "presaleAllocation must be greater than zero");
        address fundkeeper = _erc20.fundkeeper();
        require(_erc20.allowance(address(fundkeeper), address(this)) == presaleAllocation, "presale allocation must be equal to the amount of tokens approved for this contract");
       

        _presaleAllocation = presaleAllocation;
        _totalPresaleSupply = presaleAllocation;

        // place presale allocation in this contract (uses the approve/transferFrom pattern)
        _erc20.transferFrom(fundkeeper, address(this), presaleAllocation);
        stages = Stages.Presale;
        emit PresaleInitialized(presaleAllocation);
        return true;
    }

    /**
    * @dev Transfer presale tokens to another account
    * @param from The address to transfer from.
    * @param to The address to transfer to.
    * @param value The amount to be transferred.
    * @return bool true on success
    */
    function presaleTransfer(address from, address to, uint256 value) external onlyManager atStage(Stages.Presale) returns (bool) {
        _presaleTransfer(from, to, value);
        return true;
    }

    /**
    * @dev Set the crowdsale contract storage (only contract Manger and only at Presale Stage)
    * @param TBNCrowdsale The crowdsale contract deployment
    */
    function setCrowdsale(ICrowdsale TBNCrowdsale)      
        external 
        onlyManager 
        atStage(Stages.Presale) 
        returns (bool) 
    {
        require(TBNCrowdsale.getERC20() == address(_erc20), "Crowdsale contract must be assigned to the same ERC20 instance as this contract");
        _crowdsale = TBNCrowdsale;
        emit SetCrowdsale(_crowdsale);
        return true;
    }

    /**
    * @dev Assign presale tokens to accounts (only contract Manger and only at Presale Stage)
    * @param presaleAccounts The accounts to add presale token balances from
    * @param values The amount of tokens to be add to each account
    */
    function addPresaleBalance(address[] presaleAccounts, uint256[] values) external onlyManager atStage(Stages.Presale) returns (bool) {
        require(presaleAccounts.length == values.length, "presaleAccounts and values must have one-to-one relationship");
        
        for (uint32 i = 0; i < presaleAccounts.length; i++) {
            _addPresaleBalance(presaleAccounts[i], values[i]);
        }
        return true;
    }

    /**
    * @dev Subtract presale tokens to accounts (only contract Manger and only at Presale Stage)
    * @param presaleAccounts The accounts to subtract presale token balances from
    * @param values The amount of tokens to subtract from each account
    */
    function subPresaleBalance(address[] presaleAccounts, uint256[] values) external onlyManager atStage(Stages.Presale) returns (bool) {
        require(presaleAccounts.length == values.length, "presaleAccounts and values must have one-to-one relationship");
        
        for (uint32 i = 0; i < presaleAccounts.length; i++) {
            _subPresaleBalance(presaleAccounts[i], values[i]);
        }
        return true;
    }

    /**
    * @dev Called to end presale Stage. Can only be called by the crowdsale contract and will only be called when the Crowdsale begins
    */
    function presaleEnd() external onlyCrowdsale atStage(Stages.Presale) returns (bool) {
        uint256 presaleDistribution = getPresaleDistribution();
        _erc20.transfer(_crowdsale, presaleDistribution);
        stages = Stages.PresaleEnded;
        emit PresaleEnded();
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
    * @dev Add presale tokens to an account (internal operation)
    * @param presaleAccount The account which is assigned presale holdings
    * @param value The amount of tokens to be assigned to this account
    */
    function _addPresaleBalance(address presaleAccount, uint256 value) internal {
        require(presaleAccount != address(0), "cannot add balance to the 0x0 account");
        require(value <= _totalPresaleSupply, "");

        _totalPresaleSupply = _totalPresaleSupply.sub(value);
        _presaleBalances[presaleAccount] = _presaleBalances[presaleAccount].add(value);
        emit PresaleBalanceAdded(presaleAccount, value);
    }

    /**
    * @dev Assign presale tokens to an account (internal operation)
    * @param presaleAccount The account which is assigned presale holdings
    * @param value The amount of tokens to be assigned to this account
    */
    function _subPresaleBalance(address presaleAccount, uint256 value) internal {
        require(_presaleBalances[presaleAccount] > 0, "presaleAccount must have presale balance to subtract");
        require(value <= _presaleBalances[presaleAccount], "value must be less than or equal to the presale Account balance");

        _totalPresaleSupply = _totalPresaleSupply.add(value);
        _presaleBalances[presaleAccount] = _presaleBalances[presaleAccount].sub(value);
        emit PresaleBalanceASubtracted(presaleAccount, value);

    }

}