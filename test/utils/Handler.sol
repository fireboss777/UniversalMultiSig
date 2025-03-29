// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { Test } from "forge-std/Test.sol";
import { UniversalMultiSig } from "../../src/UniversalMultiSig.sol";

contract UniversalMultiSigHandler is UniversalMultiSig, Test {
    constructor(address[] memory owners) UniversalMultiSig(owners) { }
}
