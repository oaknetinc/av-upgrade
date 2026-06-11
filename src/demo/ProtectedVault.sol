// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { AVGuard } from "../AVGuard.sol";
import { VaultContext } from "./VaultInvariants.sol";

contract ProtectedVault {
    AVGuard public immutable avGuard;
    mapping(address => uint256) public credit;
    uint256 public totalLiabilities;

    constructor(AVGuard guard) {
        avGuard = guard;
    }

    function deposit() external payable {
        credit[msg.sender] += msg.value;
        totalLiabilities += msg.value;
    }

    // The missing inline authorization check is deliberate for the AV demonstration.
    function withdrawFrom(address account, uint256 amount, address payable recipient) external {
        require(credit[account] >= amount, "INSUFFICIENT_CREDIT");

        VaultContext.Withdrawal memory context = VaultContext.Withdrawal({
            caller: msg.sender,
            account: account,
            balanceBefore: address(this).balance,
            liabilitiesBefore: totalLiabilities,
            amount: amount
        });
        avGuard.check(msg.sig, amount, abi.encode(context));

        credit[account] -= amount;
        totalLiabilities -= amount;
        (bool success,) = recipient.call{ value: amount }("");
        require(success, "TRANSFER_FAILED");
    }
}

