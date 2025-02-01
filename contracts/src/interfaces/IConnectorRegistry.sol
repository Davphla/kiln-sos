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

/// @title ConnectorRegistry Interface.
/// @author maximebrugel @ Kiln.
interface IConnectorRegistry {
    /// @notice Get the address of a connector.
    /// @param name The name of the connector.
    function get(bytes32 name) external view returns (address);

    /// @notice Get the address of a connector or revert if it is paused.
    /// @param name The name of the connector.
    /// @dev revert if the connector is paused.
    function getOrRevert(bytes32 name) external view returns (address);

    /// @notice Check if a connector exists.
    /// @param name The name of the connector.
    /// @return True if the connector exists, false if not.
    function connectorExists(bytes32 name) external view returns (bool);

    /// @notice Adds a connector to the registry.
    /// @param name The name of the connector.
    /// @param connector The address of the connector.
    function add(bytes32 name, address connector) external;

    /// @notice Updates a connector in the registry.
    /// @param name The name of the connector.
    /// @param connector The address of the connector.
    /// @dev A connector can't be updated if it is frozen.
    function update(bytes32 name, address connector) external;

    /// @notice Removes a connector from the registry.
    /// @param name The name of the connector.
    /// @dev A connector can't be removed if it is frozen.
    function remove(bytes32 name) external;

    /// @notice Pauses a connector for an unspecified amount of time.
    /// @param name The name of the connector.
    function pause(bytes32 name) external;

    /// @notice Pauses a connector for a specified amount of time.
    /// @dev Cannot decrease the current pauseTimestamp of the connector.
    /// @param name The name of the connector.
    /// @param duration The duration until which the connector is paused.
    function pauseFor(bytes32 name, uint256 duration) external;

    /// @notice Unpauses a connector.
    /// @param name The name of the connector.
    function unPause(bytes32 name) external;

    /// @notice Checks if a connector is paused.
    /// @param name The name of the connector.
    /// @return True if the connector is paused, false if not.
    function paused(bytes32 name) external view returns (bool);

    /// @notice Freezes a connector.
    /// @param name The name of the connector.
    /// @dev A connector can't be unfrozen.
    function freeze(bytes32 name) external;
}
