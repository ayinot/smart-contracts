pragma solidity ^0.4.24;

import "../ERC20/IERC20.sol";
import "../crowdsale/ICrowdsale.sol";
/**
 * @title ERC20 interface
 * @dev see https://github.com/ethereum/EIPs/issues/20
 */
interface IPresale {

    /** 
    * Getters
    */ 
    // the amount of toekns allocated to this presale contract
    function getPresaleAllocation() external view returns (uint256);

    // the remianing token supply not assigned to accounts
    function totalPresaleSupply() external view returns (uint256);

    // get an account's current presale token balance
    function presaleBalanceOf(address account) external view returns (uint256);

    // get an account's static total vesting balance (returns 0 until user has called the vest() function or manager has called approveVest())
    function getVestingBalance(address account) external view returns (uint256);

    // get an account's vesting period in blocks (returns 0 until user has called the vest() function)
    function getVestingPeriod(address account) external view returns (uint256);

    // get an account's vesting schedule (returns based on presaleBalnce prior to Vesting Stage and vestingBalance after)
    function getVestingSchedule(address account) external view returns (uint256, uint256, uint256);

    // the total amount of tokens already vested and transferred out of this contract
    function getVestedAmount(address account) external view returns (uint256);

    // the vesting approval status fo this account (returns false until user has called the vest() function or manager has called approveVest())
    function getVestApproved(address account) external view returns (bool);

    // the ERC20 token deployment this presale contract is dependent on
    function getERC20() external view returns (address);

    // check the status of this contract to see if it has been set as ready to vest
    function readyToVest() external view returns (bool);

   /** 
    * Account Based Functionality
    */ 
    // Presale Stage functions
    function presaleTransfer(address to, uint256 value) external returns (bool);

    // Vesting Stage functions
    function vest() external returns (bool);


    /** 
    * Manager Role Functionality
    */ 
    // PresaleDeployed Stage functions
    function initilize (uint256 presaleAllocation) external  returns (bool);
    
    // Presale Stage functions
    function setupVest (uint256[5] vestThresholds, uint256[3][5] vestSchedules) external returns (bool);
    function setCrowdsale(ICrowdsale TBNCrowdsale) external returns (bool);
    function addPresaleBalance(address[] presaleAccounts, uint256[] values) external returns (bool);
    
    // Vesting Stage functions
    function approveVest(address account) external returns (bool);
    function moveBalance(address account, address to) external returns (bool);
    

    /** 
    * Recoverer Role Functionality
    */ 
    // Vesting Stage functions
    function recoverLost(IERC20 token_) external returns (bool);
    

    /** 
    * Crowdsale Only Functionality
    */
    // Presale Stage functions
    function startVestingStage() external returns (bool);


    /** 
    * Events
    */
    event PresaleBalanceAdded( 
        address indexed presaleAccount, 
        uint256 value
    );

    event PresaleTransfer(
        address indexed from, 
        address indexed to,
        uint256 value
    );

    event VestSetup(
        uint256[5] vestThresholds, 
        uint256[3][5] vestSchedules
    );

    event SetCrowdsale(
        ICrowdsale crowdsale 
    );

    event Vested(
        address indexed account,
        uint256 currentBalance
    );

    event VestApproved(
        address indexed account
    );

    event BalanceMoved(
        address indexed account,
        address indexed to, 
        uint256 value
    );

}
