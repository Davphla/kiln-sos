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
import "@openzeppelin/contracts/access/Ownable.sol";

import {AddressNotContract} from "./Errors.sol";

contract ReserveContract {
    address public owner;

    struct reserveParams {
        uint256 id;
        uint256 amount;
        uint256 remainingAmount;
        uint256 lockedExchangeRate;
        uint256 endDate;
        address oracleForward; // callback
    }
    reserveParams public params;

    //address next;

    constructor(address _owner, reserveParams memory _params) {
        owner = _owner;
        params = _params;
    }

    function withdraw(uint256 amount, address to) external {
        require(msg.sender == owner, "Not the owner");
        require(amount <= params.remainingAmount, "Insufficient funds");

        params.remainingAmount -= amount;
        IERC20 token = IERC20(params.oracleForward);
        require(token.transfer(to, amount), "Transfer failed");
    }
}

/// @title Kiln DeFi Integration Vault Factory.
/// @notice Factory to deploy new Vaults and initialize them.
contract ReserveFactory {
    /* -------------------------------------------------------------------------- */
    /*                                   STORAGE                                  */
    /* -------------------------------------------------------------------------- */
    /// @notice The list of deployed vaults.
    ReserveContract[] public deployedReserves;
    address public owner;

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    /* -------------------------------------------------------------------------- */
    /*                                   EVENTS                                   */
    /* -------------------------------------------------------------------------- */

    /// @dev Emitted when a new vault is created.
    /// @param vault The address of the new vault.
    /// @param id The id of the new vault.
    event ReserveCreated(address indexed vault, uint256 id);

    /* -------------------------------------------------------------------------- */
    /*                                FACTORY LOGIC                               */
    /* -------------------------------------------------------------------------- */

    /// @notice Creates a new vault.
    /// @param params The parameters to initialize the vault.
    /// @param salt The salt for the Vault deployment with CREATE2.
    /// @return The address of the new vault.
    function createReserve(
        ReserveContract.reserveParams memory params,
        bytes32 salt
    ) external onlyOwner returns (address) {
        ReserveContract.reserveParams
            memory initializationParams = ReserveContract.reserveParams({
                id: params.id,
                amount: params.amount,
                remainingAmount: params.remainingAmount,
                lockedExchangeRate: params.lockedExchangeRate,
                endDate: params.endDate,
                oracleForward: params.oracleForward
            });

        ReserveContract newContract = new ReserveContract(
            msg.sender,
            initializationParams
        );
        deployedReserves.push(newContract);

        bytes memory bytecode = abi.encodePacked(
            type(ReserveContract).creationCode,
            abi.encode(newContract)
        );
        address payable _newReserve = payable(
            Create2.deploy(0, salt, bytecode)
        );

        emit ReserveCreated(address(_newReserve), params.id);
        //return _newVault;
        return _newReserve;
    }
}
