// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import { IERC721Receiver } from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

import { IUniversalMultiSigEvents as Events } from "../src/interfaces/IUniversalMultiSig.sol";
import { IUniversalMultiSigErrors as Errors } from "../src/interfaces/IUniversalMultiSigErrors.sol";

import { UniversalMultiSigFixture } from "./utils/Fixture.sol";
import { UniversalMultiSigHandler } from "./utils/Handler.sol";

contract UniversalMultiSigTest is UniversalMultiSigFixture {
    uint256 internal constant BASE_AMOUNT = 1 ether;

    function setUp() public {
        _setUp();
    }

    /* -------------------------------------------------------------------------- */
    /*                                 CONSTRUCTOR                                */
    /* -------------------------------------------------------------------------- */

    function test_constructor() external {
        vm.expectEmit();
        emit Events.OwnersUpdated(OWNERS, 0);
        multisig = new UniversalMultiSigHandler(OWNERS);

        assertEq(multisig.getOwnersCount(), OWNERS.length);
        assertEq(multisig.getOwnersVersion(), 0);

        for (uint256 i; i < OWNERS.length; i++) {
            assertTrue(multisig.isOwner(OWNERS[i]));
        }
    }

    function test_RevertWhen_constructorInvalidOwnersCount() external {
        OWNERS.pop();
        assertLt(OWNERS.length, multisig.MIN_OWNER_COUNT());
        vm.expectRevert(Errors.InvalidOwnersCount.selector);
        new UniversalMultiSigHandler(OWNERS);
    }

    function test_RevertWhen_constructorAlreadyOwner() external {
        OWNERS[0] = OWNERS[1];
        assertEq(OWNERS.length, multisig.MIN_OWNER_COUNT());
        vm.expectRevert(Errors.AlreadyOwner.selector);
        new UniversalMultiSigHandler(OWNERS);
    }

    function test_RevertWhen_constructorInvalidOwner() external {
        OWNERS[0] = address(0);
        assertEq(OWNERS.length, multisig.MIN_OWNER_COUNT());
        vm.expectRevert(Errors.InvalidOwner.selector);
        new UniversalMultiSigHandler(OWNERS);
    }

    /* -------------------------------------------------------------------------- */
    /*                                 APPROVE_TX                                 */
    /* -------------------------------------------------------------------------- */

    function test_RevertWhen_approveTxNotOwner() external {
        (address[] memory targets, uint256[] memory values, bytes[] memory datas) =
            _getTransferEthTx(address(this), BASE_AMOUNT);

        bytes32 txHash = multisig.getTxHash(targets, values, datas, multisig.getTxNonce());

        vm.expectRevert(Errors.UnauthorizedCaller.selector);
        multisig.approveTx(txHash);
    }

    function test_approveTx() external {
        (address[] memory targets, uint256[] memory values, bytes[] memory datas) =
            _getTransferEthTx(address(this), BASE_AMOUNT);

        bytes32 txHash = multisig.getTxHash(targets, values, datas, multisig.getTxNonce());
        uint256 ownersTxApprovalsCountBefore = multisig.getOwnersTxApprovalsCount(txHash);

        vm.prank(OWNERS[0]);
        vm.expectEmit();
        emit Events.TxApproved(OWNERS[0], OWNERS[0], txHash);
        multisig.approveTx(txHash);

        assertTrue(multisig.isOwnerTxApproved(txHash, OWNERS[0]));
        assertEq(multisig.getOwnersTxApprovalsCount(txHash), ownersTxApprovalsCountBefore + 1);
    }

    function test_RevertWhen_approveTxAlreadyApproved() external {
        (address[] memory targets, uint256[] memory values, bytes[] memory datas) =
            _getTransferEthTx(address(this), BASE_AMOUNT);

        bytes32 txHash = multisig.getTxHash(targets, values, datas, multisig.getTxNonce());
        uint256 ownersTxApprovalsCountBefore = multisig.getOwnersTxApprovalsCount(txHash);

        vm.prank(OWNERS[0]);
        multisig.approveTx(txHash);

        assertTrue(multisig.isOwnerTxApproved(txHash, OWNERS[0]));
        assertEq(multisig.getOwnersTxApprovalsCount(txHash), ownersTxApprovalsCountBefore + 1);

        vm.prank(OWNERS[0]);
        vm.expectRevert(Errors.AlreadyApproved.selector);
        multisig.approveTx(txHash);
    }

    function test_approveTxForEvenOwners() external {
        /* --------------------------- update even owners --------------------------- */

        address[] memory newOwners = new address[](4);
        newOwners[0] = vm.addr(type(uint160).max);
        newOwners[1] = vm.addr(type(uint160).max - 1);
        newOwners[2] = vm.addr(type(uint160).max - 2);
        newOwners[3] = vm.addr(type(uint160).max - 3);

        (address[] memory targets, uint256[] memory values, bytes[] memory datas) =
            _getUpdateOwnersTx(newOwners);

        bytes32 txHash = multisig.getTxHash(targets, values, datas, multisig.getTxNonce());

        for (uint256 i; i < OWNERS.length; i++) {
            vm.prank(OWNERS[i]);
            multisig.approveTx(txHash);

            if (multisig.isAuthorizedTx(txHash)) {
                break;
            }
        }

        uint256 ownersVersion = multisig.getOwnersVersion();
        uint256 txNonce = multisig.getTxNonce();

        vm.prank(OWNERS[0]);
        vm.expectEmit();
        emit Events.OwnersUpdated(newOwners, ownersVersion + 1);
        vm.expectEmit();
        emit Events.TxExecuted(OWNERS[0], txHash, txNonce);
        multisig.universalTx(targets, values, datas, new bytes[](0));

        for (uint256 i; i < OWNERS.length; i++) {
            assertFalse(multisig.isOwner(OWNERS[i]));
        }

        for (uint256 i; i < newOwners.length; i++) {
            assertTrue(multisig.isOwner(newOwners[i]));
        }

        assertEq(multisig.getOwnersVersion(), ownersVersion + 1);
        assertEq(multisig.getTxNonce(), txNonce + 1);

        /* ------------------------------- approve tx ------------------------------- */

        (targets, values, datas) = _getTransferEthTx(address(this), BASE_AMOUNT);

        txHash = multisig.getTxHash(targets, values, datas, multisig.getTxNonce());

        for (uint256 i; i < newOwners.length; i++) {
            vm.prank(newOwners[i]);
            multisig.approveTx(txHash);

            if (multisig.isAuthorizedTx(txHash)) {
                assertEq(i, newOwners.length / 2);
                break;
            }
        }
    }

    /* -------------------------------------------------------------------------- */
    /*                                  REVOKE_TX                                 */
    /* -------------------------------------------------------------------------- */

    function test_revokeTx() external {
        (address[] memory targets, uint256[] memory values, bytes[] memory datas) =
            _getTransferEthTx(address(this), BASE_AMOUNT);

        bytes32 txHash = multisig.getTxHash(targets, values, datas, multisig.getTxNonce());
        uint256 ownersTxApprovalsCountBefore = multisig.getOwnersTxApprovalsCount(txHash);

        vm.prank(OWNERS[0]);
        multisig.approveTx(txHash);

        assertTrue(multisig.isOwnerTxApproved(txHash, OWNERS[0]));
        assertEq(multisig.getOwnersTxApprovalsCount(txHash), ownersTxApprovalsCountBefore + 1);

        vm.prank(OWNERS[0]);
        vm.expectEmit();
        emit Events.TxRevoked(OWNERS[0], txHash);
        multisig.revokeTx(txHash);

        assertFalse(multisig.isOwnerTxApproved(txHash, OWNERS[0]));
        assertEq(multisig.getOwnersTxApprovalsCount(txHash), ownersTxApprovalsCountBefore);
    }

    function test_RevertWhen_revokeTxNotApproved() external {
        (address[] memory targets, uint256[] memory values, bytes[] memory datas) =
            _getTransferEthTx(address(this), BASE_AMOUNT);

        bytes32 txHash = multisig.getTxHash(targets, values, datas, multisig.getTxNonce());

        vm.prank(OWNERS[0]);
        vm.expectRevert(Errors.NotApproved.selector);
        multisig.revokeTx(txHash);
    }

    /* -------------------------------------------------------------------------- */
    /*                                UPDATE_OWNERS                               */
    /* -------------------------------------------------------------------------- */

    function test_RevertWhen_updateOwnersUnauthorizedCaller() external {
        vm.expectRevert(Errors.UnauthorizedCaller.selector);
        multisig.updateOwners(new address[](0));
    }

    function test_updateOwners() external {
        address[] memory newOwners = new address[](3);
        newOwners[0] = vm.addr(type(uint160).max);
        newOwners[1] = vm.addr(type(uint160).max - 1);
        newOwners[2] = vm.addr(type(uint160).max - 2);

        (address[] memory targets, uint256[] memory values, bytes[] memory datas) =
            _getUpdateOwnersTx(newOwners);

        bytes32 txHash = multisig.getTxHash(targets, values, datas, multisig.getTxNonce());

        for (uint256 i; i < OWNERS.length; i++) {
            vm.prank(OWNERS[i]);
            multisig.approveTx(txHash);

            if (multisig.isAuthorizedTx(txHash)) {
                assertEq(i + 1, (newOwners.length + 1) / 2);

                break;
            }
        }

        uint256 ownersVersion = multisig.getOwnersVersion();
        uint256 txNonce = multisig.getTxNonce();

        vm.prank(OWNERS[0]);
        vm.expectEmit();
        emit Events.OwnersUpdated(newOwners, ownersVersion + 1);
        vm.expectEmit();
        emit Events.TxExecuted(OWNERS[0], txHash, txNonce);
        multisig.universalTx(targets, values, datas, new bytes[](0));

        for (uint256 i; i < OWNERS.length; i++) {
            assertFalse(multisig.isOwner(OWNERS[i]));
        }

        for (uint256 i; i < newOwners.length; i++) {
            assertTrue(multisig.isOwner(newOwners[i]));
        }

        assertEq(multisig.getOwnersVersion(), ownersVersion + 1);
        assertEq(multisig.getTxNonce(), txNonce + 1);
    }

    function test_updateOwnersInvalidOwner() external {
        address[] memory newOwners = new address[](multisig.MIN_OWNER_COUNT());

        (address[] memory targets, uint256[] memory values, bytes[] memory datas) =
            _getUpdateOwnersTx(newOwners);

        bytes32 txHash = multisig.getTxHash(targets, values, datas, multisig.getTxNonce());

        for (uint256 i; i < OWNERS.length; i++) {
            vm.prank(OWNERS[i]);
            multisig.approveTx(txHash);

            if (multisig.isAuthorizedTx(txHash)) {
                break;
            }
        }

        vm.prank(OWNERS[0]);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.TxFailed.selector, abi.encodePacked(Errors.InvalidOwner.selector)
            )
        );
        multisig.universalTx(targets, values, datas, new bytes[](0));
    }

    function test_RevertWhen_updateOwnersInvalidOwnersCount() external {
        address[] memory newOwners = new address[](multisig.MIN_OWNER_COUNT() - 1);

        (address[] memory targets, uint256[] memory values, bytes[] memory datas) =
            _getUpdateOwnersTx(newOwners);

        bytes32 txHash = multisig.getTxHash(targets, values, datas, multisig.getTxNonce());

        for (uint256 i; i < OWNERS.length; i++) {
            vm.prank(OWNERS[i]);
            multisig.approveTx(txHash);

            if (multisig.isAuthorizedTx(txHash)) {
                break;
            }
        }

        vm.prank(OWNERS[0]);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.TxFailed.selector, abi.encodePacked(Errors.InvalidOwnersCount.selector)
            )
        );
        multisig.universalTx(targets, values, datas, new bytes[](0));
    }

    function test_RevertWhen_updateOwnersAlreadyOwner() external {
        address[] memory newOwners = OWNERS;
        newOwners[0] = newOwners[1];

        (address[] memory targets, uint256[] memory values, bytes[] memory datas) =
            _getUpdateOwnersTx(newOwners);

        bytes32 txHash = multisig.getTxHash(targets, values, datas, multisig.getTxNonce());

        for (uint256 i; i < OWNERS.length; i++) {
            vm.prank(OWNERS[i]);
            multisig.approveTx(txHash);

            if (multisig.isAuthorizedTx(txHash)) {
                break;
            }
        }

        vm.prank(OWNERS[0]);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.TxFailed.selector, abi.encodePacked(Errors.AlreadyOwner.selector)
            )
        );
        multisig.universalTx(targets, values, datas, new bytes[](0));
    }

    /* -------------------------------------------------------------------------- */
    /*                                UNIVERSAL_TX                                */
    /* -------------------------------------------------------------------------- */

    function test_universalTx() external {
        vm.deal(address(multisig), BASE_AMOUNT);
        (address[] memory targets, uint256[] memory values, bytes[] memory datas) =
            _getTransferEthTx(address(this), BASE_AMOUNT);

        uint256 txNonce = multisig.getTxNonce();
        bytes32 txHash = multisig.getTxHash(targets, values, datas, txNonce);

        for (uint256 i; i < OWNERS.length; i++) {
            vm.prank(OWNERS[i]);
            multisig.approveTx(txHash);

            if (multisig.isAuthorizedTx(txHash)) {
                break;
            }
        }

        uint256 balanceBefore = address(this).balance;

        vm.prank(OWNERS[0]);
        vm.expectEmit();
        emit Events.TxExecuted(OWNERS[0], txHash, txNonce);
        multisig.universalTx(targets, values, datas, new bytes[](0));

        txNonce = multisig.getTxNonce();
        txHash = multisig.getTxHash(targets, values, datas, txNonce);

        assertEq(multisig.getTxNonce(), txNonce);
        assertEq(address(this).balance, balanceBefore + BASE_AMOUNT);
        assertFalse(multisig.isAuthorizedTx(txHash));
    }

    function test_RevertWhen_universalTxUnauthorizedTxReplay() external {
        vm.deal(address(multisig), BASE_AMOUNT * 2);
        (address[] memory targets, uint256[] memory values, bytes[] memory datas) =
            _getTransferEthTx(address(this), BASE_AMOUNT);

        uint256 txNonce = multisig.getTxNonce();
        bytes32 txHash = multisig.getTxHash(targets, values, datas, txNonce);

        for (uint256 i; i < OWNERS.length; i++) {
            vm.prank(OWNERS[i]);
            multisig.approveTx(txHash);

            if (multisig.isAuthorizedTx(txHash)) {
                break;
            }
        }

        uint256 balanceBefore = address(this).balance;

        vm.prank(OWNERS[0]);
        multisig.universalTx(targets, values, datas, new bytes[](0));

        assertEq(multisig.getTxNonce(), txNonce + 1);
        assertEq(address(this).balance, balanceBefore + BASE_AMOUNT);

        vm.prank(OWNERS[0]);
        vm.expectRevert(Errors.UnauthorizedTx.selector);
        multisig.universalTx(targets, values, datas, new bytes[](0));
    }

    function test_universalTxWithDelegation() external {
        vm.deal(address(multisig), BASE_AMOUNT);
        (address[] memory targets, uint256[] memory values, bytes[] memory datas) =
            _getTransferEthTx(address(this), BASE_AMOUNT);

        uint256 txNonce = multisig.getTxNonce();
        bytes32 txHash = multisig.getTxHash(targets, values, datas, txNonce);

        bytes[] memory delegationList = new bytes[](2);
        bytes memory user1Sig = _getSignature(USER_1_PK, txHash, OWNERS[0]);
        bytes memory user2Sig = _getSignature(USER_2_PK, txHash, OWNERS[0]);
        delegationList[0] = abi.encode(vm.addr(USER_1_PK), user1Sig);
        delegationList[1] = abi.encode(vm.addr(USER_2_PK), user2Sig);

        uint256 balanceBefore = address(this).balance;

        vm.prank(OWNERS[0]);
        vm.expectEmit();
        emit Events.TxApproved(vm.addr(USER_1_PK), OWNERS[0], txHash);
        vm.expectEmit();
        emit Events.TxApproved(vm.addr(USER_2_PK), OWNERS[0], txHash);
        vm.expectEmit();
        emit Events.TxExecuted(OWNERS[0], txHash, txNonce);
        multisig.universalTx(targets, values, datas, delegationList);

        assertEq(multisig.getTxNonce(), txNonce + 1);
        assertEq(address(this).balance, balanceBefore + BASE_AMOUNT);
    }

    function test_RevertWhen_universalTxInvalidSignature() external {
        (address[] memory targets, uint256[] memory values, bytes[] memory datas) =
            _getTransferEthTx(address(this), BASE_AMOUNT);

        uint256 txNonce = multisig.getTxNonce();
        bytes32 txHash = multisig.getTxHash(targets, values, datas, txNonce);

        vm.prank(OWNERS[0]);
        multisig.approveTx(txHash);

        bytes[] memory delegationList = new bytes[](2);
        bytes memory user2Sig = _getSignature(USER_2_PK, txHash, OWNERS[0]);
        bytes memory user3Sig = _getSignature(USER_3_PK, txHash, OWNERS[0]);
        delegationList[0] = abi.encode(OWNERS[0], user2Sig);
        delegationList[1] = abi.encode(OWNERS[0], user3Sig);

        vm.prank(OWNERS[0]);
        vm.expectRevert(Errors.InvalidSignature.selector);
        multisig.universalTx(targets, values, datas, delegationList);
    }

    function test_RevertWhen_universalTxInvalidArguments() external {
        (address[] memory targets, uint256[] memory values,) =
            _getTransferEthTx(address(this), BASE_AMOUNT);

        vm.prank(OWNERS[0]);
        vm.expectRevert(Errors.InvalidArguments.selector);
        multisig.universalTx(targets, values, new bytes[](0), new bytes[](0));
    }

    function test_RevertWhen_universalTxInvalidTarget() external {
        (address[] memory targets, uint256[] memory values, bytes[] memory datas) =
            _getTransferEthTx(address(0), BASE_AMOUNT);

        uint256 txNonce = multisig.getTxNonce();
        bytes32 txHash = multisig.getTxHash(targets, values, datas, txNonce);

        for (uint256 i; i < OWNERS.length; i++) {
            vm.prank(OWNERS[i]);
            multisig.approveTx(txHash);

            if (multisig.isAuthorizedTx(txHash)) {
                break;
            }
        }

        vm.prank(OWNERS[0]);
        vm.expectRevert(Errors.InvalidTarget.selector);
        multisig.universalTx(targets, values, datas, new bytes[](0));
    }

    /* -------------------------------------------------------------------------- */
    /*                             ON_ERC721_RECEIVED                             */
    /* -------------------------------------------------------------------------- */

    function test_onERC721Received() external view {
        assertEq(
            multisig.onERC721Received(address(0), address(0), 0, ""),
            IERC721Receiver.onERC721Received.selector
        );
    }

    /* -------------------------------------------------------------------------- */
    /*                                   HELPERS                                  */
    /* -------------------------------------------------------------------------- */

    function _getTransferEthTx(address to, uint256 value)
        internal
        pure
        returns (address[] memory targets_, uint256[] memory values_, bytes[] memory datas_)
    {
        targets_ = new address[](1);
        targets_[0] = to;

        values_ = new uint256[](1);
        values_[0] = value;

        datas_ = new bytes[](1);
    }

    function _getUpdateOwnersTx(address[] memory newOwners)
        internal
        view
        returns (address[] memory targets_, uint256[] memory values_, bytes[] memory datas_)
    {
        targets_ = new address[](1);
        targets_[0] = address(multisig);

        values_ = new uint256[](1);

        datas_ = new bytes[](1);
        datas_[0] = abi.encodeWithSignature("updateOwners(address[])", newOwners);
    }

    function _getSignature(uint256 signerPK, bytes32 txHash, address executor)
        internal
        view
        returns (bytes memory)
    {
        address signer = vm.addr(signerPK);

        bytes32 structHash = keccak256(
            abi.encode(
                multisig.DELEGATED_APPROVAL_STRUCT_HASH(),
                signer,
                txHash,
                executor,
                multisig.getOwnerDelegationNonce(signer)
            )
        );
        bytes32 digest = MessageHashUtils.toTypedDataHash(multisig.domainSeparatorV4(), structHash);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPK, digest);

        return abi.encodePacked(r, s, v);
    }

    receive() external payable { }
}
