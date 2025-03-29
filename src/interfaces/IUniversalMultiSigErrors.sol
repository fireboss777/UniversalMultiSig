// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IUniversalMultiSigErrors {
    /// @notice Error thrown when the number of owners provided is invalid.
    error InvalidOwnersCount();

    /// @notice Error thrown when an address that is not an owner is referenced.
    error InvalidOwner();

    /// @notice Error thrown when an delegated approval is invalid.
    error InvalidSignature();

    /// @notice Error thrown when attempting to approve a transaction that is already approved.
    error AlreadyApproved();

    /// @notice Error thrown when attempting to revoke approval of a transaction that is not approved.
    error NotApproved();

    /// @notice Error thrown when a transaction is attempted with an invalid target address.
    error InvalidTarget();

    /// @notice Error thrown when a caller is not authorized to perform an action.
    error UnauthorizedCaller();

    /// @notice Error thrown when a transaction is not authorized for execution.
    error UnauthorizedTx();

    /// @notice Error thrown when a transaction fails to execute, with a reason indicating why it failed.
    /// @param reason The reason for the failure as a bytes value.
    error TxFailed(bytes reason);

    /// @notice Error thrown when the arguments provided to a function are invalid.
    error InvalidArguments();

    /// @notice Error thrown when trying to set an address as an owner that is already an owner.
    error AlreadyOwner();
}
