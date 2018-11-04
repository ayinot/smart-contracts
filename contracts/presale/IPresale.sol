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

    // the amount of tokens allocated to this presale contract
    function getPresaleAllocation() external view returns (uint256);

    // the remaining token supply not assigned to accounts
    function totalPresaleSupply() external view returns (uint256);

    // the total number of presale tokens distributed to presale accounts
    function getPresaleDistribution() external view returns (uint256);

    // get an account's current presale token balance
    function presaleBalanceOf(address account) external view returns (uint256);

    // get the ERC20 token deployment this presale contract is dependent on
    function getERC20() external view returns (address);

    // get the Crowdsale deployment this presale contract is attached to
    function getCrowdsale() external view returns (address);

    /*** PresaleDeployed Stage functions ***/ 

    /** 
    * Manager Role Functionality
    */ 
    function initilize (uint256 presaleAllocation) external  returns (bool);
    
    // Presale Stage functions

    /** 
    * Manager Role Functionality
    */ 
 
    // add presale tokens to accounts to allow for distribution during the Crowdsale claiming process
    function addPresaleBalance(address[] presaleAccounts, uint256[] values) external returns (bool);

    // subtract presale tokens from accounts to adjust their presale balance
    function subPresaleBalance(address[] presaleAccounts, uint256[] values) external returns (bool);
    
    // transfer some amount of tokens from one account to another
    function presaleTransfer(address from, address to, uint256 value) external returns (bool);

    // set the Crowdsale contract deployed address (required for initializing the Crowdsale)
    function setCrowdsale(ICrowdsale TBNCrowdsale) external returns (bool);


    /** 
    * Crowdsale Only Functionality
    */
    // ends the Presale Stage (thereby locking any account updating and tranferring the amount of distributed tokens to the Crowdsale contract for vested claiming)
    function presaleEnd() external returns (bool);

    // PresaleEnded Stage functions

    /** 
    * Recoverer Role Functionality
    */
    // allows recovery of missent tokens as well as recovery of un-distributed TBN once the Presale Stage has ended.
    function recoverTokens(IERC20 token) external returns (bool);


    /** 
    * Events
    */
    event PresaleInitialized(
        uint256 presaleAllocation
    );

    event PresaleBalanceAdded( 
        address indexed presaleAccount, 
        uint256 value
    );

    event PresaleBalanceASubtracted( 
        address indexed presaleAccount, 
        uint256 value
    );

    event PresaleTransfer(
        address indexed from, 
        address indexed to,
        uint256 value
    );

    event SetCrowdsale(
        ICrowdsale crowdsale 
    );

    event PresaleEnded();

    event TokensRecovered(
        IERC20 token, 
        uint256 recovered
    );

}
