// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Script } from "forge-std/Script.sol";
import { UniversalMultiSig } from "../src/UniversalMultiSig.sol";

contract UniversalMultiSigScript is Script {
    function run() public returns (UniversalMultiSig multisig_) {
        address[] memory OWNERS = vm.envAddress("OWNERS", ",");
        vm.startBroadcast();
        multisig_ = new UniversalMultiSig(OWNERS);
        vm.stopBroadcast();
    }
}
