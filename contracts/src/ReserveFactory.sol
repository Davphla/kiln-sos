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

import {Create2} from "@openzeppelin/utils/Create2.sol";
import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";

import {AddressNotContract} from "./Errors.sol";
import {Reserve} from "./Vault.sol";

/// @title Kiln DeFi Integration Vault Factory.
/// @notice Factory to deploy new Vaults and initialize them.
contract ReserveFactory {
    /* -------------------------------------------------------------------------- */
    /*                                   STORAGE                                  */
    /* -------------------------------------------------------------------------- */
    /// @notice The list of deployed vaults.
    Reserve[] public deployedReserves;

    /* -------------------------------------------------------------------------- */
    /*                                   EVENTS                                   */
    /* -------------------------------------------------------------------------- */

    /// @dev Emitted when a new vault is created.
    /// @param vault The address of the new vault.
    /// @param name The name of the new vault.
    event ReserveCreated(address indexed vault, string name);

    /* -------------------------------------------------------------------------- */
    /*                                FACTORY LOGIC                               */
    /* -------------------------------------------------------------------------- */

    /// @notice The parameters to create a new vault.
    struct CreateReserveParams {
        uint256 amount;
        uint256 lockedExchangeRate;
        uint256 endDate;
        uint256 oracleSpot;
        uint256 oracleForward;
    }

    /// @notice Creates a new vault.
    /// @param params The parameters to initialize the vault.
    /// @param salt The salt for the Vault deployment with CREATE2.
    /// @return The address of the new vault.
    function createReserve(
        CreateReserveParams memory params,
        bytes32 salt
    ) external returns (address) {
        Reserve.InitializationParams memory initializationParams = Vault
            .InitializationParams();

        bytes memory _initCalldata = abi.encodeCall(
            Vault.initialize,
            initializationParams
        );

        //address payable _newVault = payable(
        //    Create2.deploy(
        //        0, salt, abi.encodePacked(type(VaultBeaconProxy).creationCode, abi.encode(vaultBeacon, _initCalldata))
        //    )
        //);

        deployedVaults.push(Vault(_newVault));
        emit VaultCreated(_newVault, params.name_);
        return _newVault;
    }

    /// @notice Create new forward contract object
    function forwardSetUp() internal returns () {
        forwards[forwardCounter] = Forward({
            forwardId: forwardCounter,
            lockedExchangeRate: lockedExchangeRate,
            endDate: endDate,
            totalAmount: amount
        });
        // Additional logic to store Forward_ID, LockedExchangeRate, OracleSpot, TotalAmount
    }
}
