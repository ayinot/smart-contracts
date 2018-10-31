pragma solidity ^0.4.24;

import "../ERC20/IERC20.sol";
import "../presale/IPresale.sol";

/**
 * @title ERC20 interface
 * @dev see https://github.com/ethereum/EIPs/issues/20
 */
interface ICrowdsale {

  function getInterval(uint256 blockNumber) external view returns (uint256);
  
  function getERC20() external view returns (address);
  
  function getMin() external view returns (uint256);

  function participate(uint256 limit) external payable returns (bool);

  function claim(uint256 interval) external;

  function claimAll() external;

  //manager functions 
  function initialize(
      uint256 basisPrice_,
      uint256 reserveFloor_, 
      uint256 reserveCeiling_,
      uint256 crowdsaleAllocation_
    ) external returns (bool); 

  function setRebase(uint256 newETHPrice) external returns (bool);

  function revealCap(uint256 cap, uint256 secret) external returns (bool); 

  //recoverer functions
  function recoverToken(IERC20 token) external returns (bool);

  //fundkeeper functions
  function collect() external returns (bool);

  event Participated (uint256 interval, address account, uint256 amount);
  event Claimed (uint256 interval, address account, uint256 amount);
  event Collected (address collector, uint256 amount);
  event Rebased(uint256 newETHPrice, uint256 newETHResrveAmount);

}