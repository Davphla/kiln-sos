// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: 2024 Kiln <contact@kiln.fi>
//
// ██╗  ██╗██╗██╗     ███╗   ██╗
// ██║ ██╔╝██║██║     ████╗  ██║
// █████╔╝ ██║██║     ██╔██╗ ██║
// ██╔═██╗ ██║██║     ██║╚██╗██║
// ██║  ██╗██║███████╗██║ ╚████║
// ╚═╝  ╚═╝╚═╝╚══════╝╚═╝  ╚═══╝
//
pragma solidity 0.8.22;

/// @title FeeDispatcher Interface.
/// @author maximebrugel @ Kiln.
interface IFeeDispatcher {
    /// @notice Entity eligible to receive a portion of fees.
    /// @param recipient The address of the fee recipient.
    /// @param managementFeeSplit The split percentage of the management fee allocated to this recipient.
    /// @param performanceFeeSplit The split percentage of the performance fee allocated to this recipient.
    struct FeeRecipient {
        address recipient;
        uint256 managementFeeSplit;
        uint256 performanceFeeSplit;
    }

    /// @notice Dispatch pending fees to the fee recipients.
    function dispatchFees() external;

    /// @notice Get the pending management fee.
    /// @return The pending management fee.
    function pendingManagementFee() external view returns (uint256);

    /// @notice Get the pending performance fee.
    /// @return The pending performance fee.
    function pendingPerformanceFee() external view returns (uint256);

    /// @notice Get the fee recipients.
    /// @return The fee recipients.
    function feeRecipients() external view returns (FeeRecipient[] memory);

    /// @notice Get the fee recipient of a given address.
    /// @param recipient The address of the fee recipient.
    /// @return The fee recipient.
    function feeRecipient(address recipient) external view returns (FeeRecipient memory);

    /// @notice Get the fee recipient at a given index.
    /// @param index The index of the fee recipient.
    /// @return The fee recipient.
    function feeRecipientAt(uint256 index) external view returns (FeeRecipient memory);
}
