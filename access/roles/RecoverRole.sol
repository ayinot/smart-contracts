pragma solidity ^0.4.24;

import "../Roles.sol";

contract RecoverRole {
    using Roles for Roles.Role;

    event RecovererAdded(address indexed account);
    event RecovererRemoved(address indexed account);

    Roles.Role private recoverers;

    constructor() internal {
        _addRecoverer(msg.sender);
    }

    modifier onlyRecoverer() {
        require(isRecoverer(msg.sender), "msg.sender does not have the recoverer role");
        _;
    }

    function isRecoverer(address account) public view returns (bool) {
        return recoverers.has(account);
    }

    function addRecoverer(address account) public onlyRecoverer {
        _addRecoverer(account);
    }

    function renounceRecoverer() public {
        _removeRecoverer(msg.sender);
    }

    function _addRecoverer(address account) internal {
        recoverers.add(account);
        emit RecovererAdded(account);
    }

    function _removeRecoverer(address account) internal {
        recoverers.remove(account);
        emit RecovererRemoved(account);
    }
}
