// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { Test } from "forge-std/Test.sol";

import { UniversalMultiSigHandler } from "./Handler.sol";

contract BaseFixture is Test {
    /* ------------------------------ PRIVATE KEYS ------------------------------ */
    uint256 internal constant USER_1_PK = 1;
    uint256 internal constant USER_2_PK = 2;
    uint256 internal constant USER_3_PK = 3;
    uint256 internal constant USER_4_PK = 4;

    /* -------------------------------- ADDRESSES ------------------------------- */
    address internal USER_1 = vm.addr(USER_1_PK);
    address internal USER_2 = vm.addr(USER_2_PK);
    address internal USER_3 = vm.addr(USER_3_PK);
    address internal USER_4 = vm.addr(USER_4_PK);

    function _setUp() internal virtual {
        vm.deal(USER_1, 10000 ether);
        vm.deal(USER_2, 10000 ether);
        vm.deal(USER_3, 10000 ether);
        vm.deal(USER_4, 10000 ether);
    }
}

contract UniversalMultiSigFixture is BaseFixture {
    UniversalMultiSigHandler internal multisig;
    address[] internal OWNERS = [USER_1, USER_2, USER_3];

    function _setUp() internal virtual override {
        super._setUp();
        multisig = new UniversalMultiSigHandler(OWNERS);
    }
}
