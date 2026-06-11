// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract VulnerableVault {
    mapping(address => uint256) public credit;
    uint256 public totalLiabilities;

    function deposit() external payable {
        credit[msg.sender] += msg.value;
        totalLiabilities += msg.value;
    }

    // Intentionally vulnerable: the caller is not required to own `account`.
    function withdrawFrom(address account, uint256 amount, address payable recipient) external {
        require(credit[account] >= amount, "INSUFFICIENT_CREDIT");
        credit[account] -= amount;
        totalLiabilities -= amount;
        (bool success,) = recipient.call{ value: amount }("");
        require(success, "TRANSFER_FAILED");
    }
}

