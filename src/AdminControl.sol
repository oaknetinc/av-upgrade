// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

abstract contract AdminControl {
    error NotAdmin();
    error ZeroAddress();
    error NotContract(address account);

    address public admin;
    address public pendingAdmin;

    event AdminTransferStarted(address indexed currentAdmin, address indexed pendingAdmin);
    event AdminTransferred(address indexed previousAdmin, address indexed newAdmin);

    constructor(address initialAdmin) {
        if (initialAdmin == address(0)) revert ZeroAddress();
        admin = initialAdmin;
        emit AdminTransferred(address(0), initialAdmin);
    }

    modifier onlyAdmin() {
        _requireAdmin();
        _;
    }

    function _requireAdmin() private view {
        if (msg.sender != admin) revert NotAdmin();
    }

    function _requireContract(address account) internal view {
        if (account.code.length == 0) revert NotContract(account);
    }

    function transferAdmin(address newAdmin) external onlyAdmin {
        if (newAdmin == address(0)) revert ZeroAddress();
        pendingAdmin = newAdmin;
        emit AdminTransferStarted(admin, newAdmin);
    }

    function acceptAdmin() external {
        if (msg.sender != pendingAdmin) revert NotAdmin();
        address previousAdmin = admin;
        admin = msg.sender;
        pendingAdmin = address(0);
        emit AdminTransferred(previousAdmin, msg.sender);
    }
}
