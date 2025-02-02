// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: 2024 Kiln <contact@kiln.fi>
//
// ██╗  ██╗██╗██╗     ███╗   ██╗
// ██║ ██╔╝██║██║     ████╗  ██║
// ██╔═██╗ ██║██║     ██║╚██╗██║
// ██║  ██╗██║███████╗██║ ╚████║
// ╚═╝  ╚═╝╚═╝╚══════╝╚═╝  ╚═══╝
//
pragma solidity 0.8.22;

import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";

/// @title Interface for connectors.
/// @author maximebrugel @ Kiln.
interface IConnector {
    /// @notice Get the total balance (deposit + rewards).
    /// @param asset The asset to get the balance of.
    /// @dev Always called using `.call` (use `msg.sender` and not `address(this)`).
    function totalAssets(IERC20 asset) external view returns (uint256);

    /// @notice Deposit the asset in the underlying protocol.
    /// @param asset The asset to deposit.
    /// @param amount The amount to deposit.
    /// @dev Always called using `.delegatecall` (use `address(this)` and not `msg.sender`).
    function deposit(IERC20 asset, uint256 amount) external;

    /// @notice Withdraw the asset from the underlying protocol.
    /// @param asset The asset to withdraw.
    /// @param amount The amount to withdraw.
    /// @dev Always called using `.delegatecall` (use `address(this)` and not `msg.sender`).
    function withdraw(IERC20 asset, uint256 amount) external;

    /// @notice Claim additional rewards from the underlying protocol.
    /// @param asset The vault underlying asset.
    /// @param rewardsAsset The rewards asset to claim.
    function claim(IERC20 asset, IERC20 rewardsAsset, bytes calldata payload) external;

    /// @notice Get the maximum amount that can be deposited.
    /// @param asset The asset to get the maximum deposit amount of.
    function maxDeposit(IERC20 asset) external view returns (uint256);

    /// @notice Get the maximum amount that can be withdrawn (by the vault, not a specific user).
    /// @param asset The asset to get the maximum withdraw amount of.
    function maxWithdraw(IERC20 asset) external view returns (uint256);
}
