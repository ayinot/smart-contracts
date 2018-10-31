pragma solidity ^0.4.24;

import "../Roles.sol";

contract FundkeeperRole {
    using Roles for Roles.Role;

    address public fundkeeper;

    event FundkeeperTransferred(
      address indexed previousKeeper,
      address indexed newKeeper
    );

    Roles.Role private fundkeepers;

    constructor() internal {
        _addFundkeeper(msg.sender);
    }

    modifier onlyFundkeeper() {
        require(isFundkeeper(msg.sender), "msg.sender does not have the fundkeeper role");
        _;
    }

    function isFundkeeper(address account) public view returns (bool) {
        return fundkeepers.has(account);
    }

    function transferFundkeeper(address newFundkeeper) public onlyFundkeeper {
        _transferFundkeeper(newFundkeeper);
    }

    /**
    * @dev Transfers control of the intial contract tokens to a newFunkeeper.
    * @param newFundkeeper The address to transfer the fundkeeper role to.
    */
    function _transferFundkeeper(address newFundkeeper) internal {
        _addFundkeeper(newFundkeeper);
        _removeFundkeeper(msg.sender);
        emit FundkeeperTransferred(msg.sender, newFundkeeper);
    }

    function renounceFundkeeper() public {
        _removeFundkeeper(msg.sender);
    }

    function _addFundkeeper(address account) internal {
        require(account != address(0), "fundkeeper role cannot be held by 0x0");
        fundkeepers.add(account);
        fundkeeper = account;
        emit FundkeeperTransferred(address(0), account);
    }

    function _removeFundkeeper(address account) internal {
        fundkeepers.remove(account);
        emit FundkeeperTransferred(account, address(0));
    }
}