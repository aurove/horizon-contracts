// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {HorizonDestinationExecutor} from "../src/HorizonDestinationExecutor.sol";

/// @notice Base Sepolia deploy stub for HorizonDestinationExecutor (no required broadcast).
/// @dev Env (optional for simulation): PRIVATE_KEY, SWAP_ROUTER, NPM, MUSD, PEER_TOKEN.
contract DeployHorizonDestinationExecutor is Script {
    function run() public {
        address swapRouter = vm.envOr("SWAP_ROUTER", address(0));
        address npm = vm.envOr("NPM", address(0));
        address musd = vm.envOr("MUSD", address(0));
        address peerToken = vm.envOr("PEER_TOKEN", address(0));

        uint256 pk = vm.envOr("PRIVATE_KEY", uint256(0));
        address deployer = pk != 0 ? vm.rememberKey(pk) : msg.sender;

        vm.startBroadcast(deployer);
        HorizonDestinationExecutor executor = new HorizonDestinationExecutor(deployer);

        if (swapRouter != address(0) && npm != address(0) && musd != address(0)) {
            executor.setConfig(swapRouter, npm, musd);
        }
        if (peerToken != address(0)) {
            executor.setPeerToken(peerToken, true);
        }
        vm.stopBroadcast();

        console.log("HorizonDestinationExecutor", address(executor));
        console.log("owner", deployer);
        console.log("swapRouter", executor.swapRouter());
        console.log("npm", executor.npm());
        console.log("musd", executor.musd());
    }
}
