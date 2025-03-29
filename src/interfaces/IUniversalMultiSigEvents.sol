// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IUniversalMultiSigEvents {
    /// @notice Emitted when a transaction is approved by an owner.
    /// @param owner The address of the owner who approved the transaction.
    /// @param executor The address that executed the transaction.
    /// @param txHash The hash of the approved transaction.
    event TxApproved(address indexed owner, address indexed executor, bytes32 txHash);

    /// @notice Emitted when a transaction approval is revoked by an owner.
    /// @param owner The address of the owner who revoked the approval.
    /// @param txHash The hash of the revoked transaction.
    event TxRevoked(address indexed owner, bytes32 txHash);

    /// @notice Emitted when the list of owners is updated.
    /// @param owners The new array of owner addresses after the update.
    /// @param ownersVersion The owners version after the update.
    event OwnersUpdated(address[] owners, uint256 ownersVersion);

    /// @notice Emitted when a transaction is successfully executed.
    /// @param caller The address that invoked the transaction execution.
    /// @param txHash The hash of the executed transaction.
    /// @param txNonce The tx nonce of the transaction.
    event TxExecuted(address indexed caller, bytes32 txHash, uint256 txNonce);
}
