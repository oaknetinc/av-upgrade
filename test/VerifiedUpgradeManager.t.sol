// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { VerifiedUpgradeManager } from "../src/modules/VerifiedUpgradeManager.sol";

interface VmUpgrade {
    function warp(uint256 newTimestamp) external;
    function expectRevert() external;
}

contract MockImplementation { }

contract MockUpgradeableProxy {
    address public manager;
    address public implementation;
    bytes public initializationData;

    constructor(address initialManager) {
        manager = initialManager;
    }

    function upgradeToAndCall(address newImplementation, bytes calldata data) external payable {
        require(msg.sender == manager, "NOT_MANAGER");
        implementation = newImplementation;
        initializationData = data;
    }
}

contract VerifiedUpgradeManagerTest {
    VmUpgrade private constant vm =
        VmUpgrade(address(uint160(uint256(keccak256("hevm cheat code")))));

    function testExecutesOnlyScheduledCodeHashAfterDelay() public {
        VerifiedUpgradeManager manager = new VerifiedUpgradeManager(address(this), 2 days, 1 days);
        MockUpgradeableProxy proxy = new MockUpgradeableProxy(address(manager));
        MockImplementation implementation = new MockImplementation();
        bytes memory data = abi.encode(uint256(42));

        uint256 upgradeId = manager.schedule(
            address(proxy), address(implementation), address(implementation).codehash, data
        );

        vm.expectRevert();
        manager.execute(upgradeId, data);

        vm.warp(block.timestamp + 2 days);
        manager.execute(upgradeId, data);
        require(proxy.implementation() == address(implementation), "implementation not updated");
        require(
            keccak256(proxy.initializationData()) == keccak256(data), "initialization data changed"
        );
    }

    function testRejectsIncorrectExpectedCodeHash() public {
        VerifiedUpgradeManager manager = new VerifiedUpgradeManager(address(this), 0, 1 days);
        MockUpgradeableProxy proxy = new MockUpgradeableProxy(address(manager));
        MockImplementation implementation = new MockImplementation();
        bytes memory data;

        vm.expectRevert();
        manager.schedule(address(proxy), address(implementation), bytes32(uint256(1)), data);
    }

    function testRejectsEOAImplementation() public {
        VerifiedUpgradeManager manager = new VerifiedUpgradeManager(address(this), 0, 1 days);
        MockUpgradeableProxy proxy = new MockUpgradeableProxy(address(manager));
        address eoa = address(0xBEEF);
        bytes memory data;

        vm.expectRevert();
        manager.schedule(address(proxy), eoa, eoa.codehash, data);
    }
}
