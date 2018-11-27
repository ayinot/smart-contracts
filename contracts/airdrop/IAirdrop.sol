pragma solidity ^0.4.24;

import "../ERC20/IERC20.sol";
import "../crowdsale/ICrowdsale.sol";
/**
 * @title Airdrop interface
 */
interface IAirdrop {

    /** 
    * Getters
    */

    // the amount of tokens allocated to this Airdrop contract
    function getAllocation() external view returns (uint256);

    // the remaining token supply not assigned to accounts
    function totalSupply() external view returns (uint256);

    // the total number of Airdrop tokens distributed to accounts
    function getDistribution() external view returns (uint256);

    // get an account's current Airdrop token record
    function airdropBalanceOf(address account) external view returns (uint256);

    // get the ERC20 token deployment this Airdrop contract is dependent on
    function getERC20() external view returns (address);

    /*** AirdropDeployed Stage functions ***/ 

    /** 
    * Manager Role Functionality
    */ 
    function initilize (uint256 airdropAllocation) external  returns (bool);
    
    // Airdrop Stage functions

    /**
    * Public Functionality
    */
    function claim() public returns (bool);

    /** 
    * Manager Role Functionality
    */

    // add new token allotment to the total airdrop allocation 
    function addAllocation(uint256 value) external returns (bool); 

    // add airdrop tokens to user account balances
    function addBalance(address[] accounts, uint256[] values) external returns (bool);

    // subtract airdrop tokens from accounts to adjust airdrop balances
    function subBalance(address[] accounts, uint256[] values) external returns (bool);
    
    // transfer some amount of tokens from one account to another to adjust airdrop balances
    function airdropTransfer(address from, address to, uint256 value) external returns (bool);

    // ends the Airdrop Stage (thereby locking any account updating and tranferring or additional allocation)
    function airdropEnd() external returns (bool);

    // AirdropEnded Stage functions

    /** 
    * Recoverer Role Functionality
    */
    // allows recovery of missent tokens as well as recovery of un-distributed TBN once the Airdrop Stage has ended.
    function recoverTokens(IERC20 token) external returns (bool);


    /** 
    * Events
    */
    event AirdropInitialized(
        uint256 airdropAllocation
    );

    event AllocationAdded(
        uint256 value
    );

    event BalanceAdded( 
        address indexed airdropAccount, 
        uint256 value
    );

    event BalanceSubtracted( 
        address indexed airdropAccount, 
        uint256 value
    );

    event Transfer(
        address indexed from, 
        address indexed to,
        uint256 value
    );

    event AirdropClaim(
        address indexed account;
        uint256 claimAmount;
    );

    event AirdropEnded();

    event TokensRecovered(
        IERC20 token, 
        uint256 recovered
    );

}
