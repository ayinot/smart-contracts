pragma solidity ^0.4.24;

import "./ERC20.sol";
import "../access/roles/MinterRole.sol";
import "../access/roles/RecoverRole.sol";

/**
 * @title ERC20Mintable
 * @dev TBN ERC20 specific logic
 */
contract TBNERC20 is ERC20, MinterRole, RecoverRole {
  /**
   * @dev Function to mint tokens
   * @param totalSupply The total token supply to be minted
   * @param name The amount of tokens to mint.
   * @param symbol The three letter symbol for this token
   * @param decimals The decimal precision display
   */
    constructor(uint256 totalSupply, string name, string symbol, uint8 decimals)
    ERC20(name, symbol, decimals) public {
        mint(fundkeeper, totalSupply);
        renounceMinter();
    }

    /**
    * @dev Fallback reverts any ETH payment 
    */
    function () public payable {
        revert (); 
    }  

    /**
    * @dev Safety function for recovering missent ERC20 tokens
    * @param token address of the ERC20 contract
    */
    function recoverToken(IERC20 token) external onlyRecoverer {
        token.transfer(msg.sender, token.balanceOf(this));
    }

   /**
    * @dev Mint function to mint the intiali total supply
    * @param to address to mint the tokens into
    * @param value total amount to be minted
    */
    function mint(
        address to,
        uint256 value
    )
        public
        onlyMinter
        returns (bool)
    {
        _mint(to, value);
        return true;
    }
}