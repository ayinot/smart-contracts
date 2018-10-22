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
   * @param to The address that will receive the minted tokens.
   * @param value The amount of tokens to mint.
   * @return A boolean that indicates if the operation was successful.
   */
    constructor(uint256 totalSupply, string name, string symbol, uint8 decimals)
    ERC20(totalSupply, name, symbol, decimals) public {
        mint(msg.sender, totalSupply);
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
    function recoverLost(IERC20 token) public onlyRecoverer {
        token.transfer(owner(), token.balanceOf(this));
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