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

import {Math} from "@openzeppelin/utils/math/Math.sol";
import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {Initializable} from "@openzeppelin-upgradeable/proxy/utils/Initializable.sol";

import {
    AddressZero,
    EmptyArray,
    FeeRecipientDoesNotExist,
    FeeRecipientNotUnique,
    WrongManagementFeeSplit,
    WrongPerformanceFeeSplit
} from "../Errors.sol";
import {IFeeDispatcher} from "../interfaces/IFeeDispatcher.sol";

/// @title FeeDispatcher.
/// @notice Dispatches the pending management and performance fees to the fee recipients.
/// @dev Using ERC-7201 standard.
/// @author maximebrugel @ Kiln.
abstract contract FeeDispatcher is Initializable, IFeeDispatcher {
    using SafeERC20 for IERC20;
    using Math for uint256;

    /* -------------------------------------------------------------------------- */
    /*                                  CONSTANTS                                 */
    /* -------------------------------------------------------------------------- */

    /// @dev Represents the maximum percentage value in calculations.
    ///      This constant is used as a scaling factor for percentage-based computations.
    uint256 internal constant _MAX_PERCENT = 100;

    /* -------------------------------------------------------------------------- */
    /*                               STORAGE (proxy)                              */
    /* -------------------------------------------------------------------------- */

    /// @notice The storage layout of the contract.
    /// @param _pendingManagementFee The pending management fee (to be dispatched).
    /// @param _pendingPerformanceFee The pending performance fee (to be dispatched).
    /// @param _feeRecipients Array of all the fee recipients.
    struct FeeDispatcherStorage {
        uint256 _pendingManagementFee;
        uint256 _pendingPerformanceFee;
        FeeRecipient[] _feeRecipients;
    }

    function _getFeeDispatcherStorage() private pure returns (FeeDispatcherStorage storage $) {
        assembly {
            $.slot := FeeDispatcherStorageLocation
        }
    }

    /// @dev The storage slot of the FeeDispatcherStorage struct in the proxy contract.
    ///      keccak256(abi.encode(uint256(keccak256("kiln.storage.feedispatcher")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant FeeDispatcherStorageLocation =
        0xfdd5e928c3467d3da929a44639dde8d54e0576a04fec4ff333caa67a6f243300;

    /* -------------------------------------------------------------------------- */
    /*                                   EVENTS                                   */
    /* -------------------------------------------------------------------------- */

    /// @dev Emitted when the pending management fee is dispatched to a recipient.
    /// @param recipient The recipient of the management fee.
    /// @param managementFee The amount of the management fee dispatched.
    event ManagementFeeDispatched(address indexed recipient, uint256 managementFee);

    /// @dev Emitted when the pending performance fee is dispatched to a recipient.
    /// @param recipient The recipient of the performance fee.
    /// @param performanceFee The amount of the performance fee dispatched.
    event PerformanceFeeDispatched(address indexed recipient, uint256 performanceFee);

    /// @dev Emitted when the fee recipients are set.
    /// @param feeRecipients The fee recipients (array of structs).
    event FeeRecipientsSet(FeeRecipient[] feeRecipients);

    /// @dev Emitted performance fees are collected.
    /// @param performanceFeeAmount The amount of performance fees collected.
    event PerformanceFeesCollected(uint256 performanceFeeAmount);

    /// @dev Emitted management fees are collected.
    /// @param managementFeeAmount The amount of management fees collected.
    event ManagementFeesCollected(uint256 managementFeeAmount);

    /* -------------------------------------------------------------------------- */
    /*                                 PROXY LOGIC                                */
    /* -------------------------------------------------------------------------- */

    function __FeeDispatcher_init(FeeRecipient[] memory recipients, uint8 underlyingDecimal)
        internal
        onlyInitializing
    {
        __FeeDispatcher_init_unchained(recipients, underlyingDecimal);
    }

    function __FeeDispatcher_init_unchained(FeeRecipient[] memory recipients, uint8 underlyingDecimal)
        internal
        onlyInitializing
    {
        _setFeeRecipients(recipients, underlyingDecimal);
    }

    /* -------------------------------------------------------------------------- */
    /*                            FEE DISPATCHER LOGIC                            */
    /* -------------------------------------------------------------------------- */

    /// @dev Dispatch the pending management/performance fee to the fee recipients.
    /// @param asset The asset to dispatch the fees in.
    /// @param underlyingDecimals The number of decimals of the underlying asset.
    function _dispatchFees(IERC20 asset, uint8 underlyingDecimals) internal {
        FeeDispatcherStorage storage $ = _getFeeDispatcherStorage();

        uint256 _pendingManagementFee = $._pendingManagementFee;
        uint256 _pendingPerformanceFee = $._pendingPerformanceFee;
        uint256 _managementFeeTransferred;
        uint256 _performanceFeeTransferred;

        uint256 _recipientsLength = $._feeRecipients.length;
        FeeRecipient memory currentRecipient;
        for (uint256 i; i < _recipientsLength; i++) {
            currentRecipient = $._feeRecipients[i];

            if (_pendingManagementFee > 0) {
                // Compute the management fee amount for the current recipient (based on the management
                // fee split between all recipients).
                uint256 _managementFeeAmount = _pendingManagementFee.mulDiv(
                    currentRecipient.managementFeeSplit, _MAX_PERCENT * 10 ** underlyingDecimals
                );
                if (_managementFeeAmount > 0) {
                    asset.safeTransfer(currentRecipient.recipient, _managementFeeAmount);
                    _managementFeeTransferred += _managementFeeAmount;
                    emit ManagementFeeDispatched(currentRecipient.recipient, _managementFeeAmount);
                }
            }

            if (_pendingPerformanceFee > 0) {
                // Compute the performance fee amount for the current recipient (based on the performance
                // fee split between all recipients).
                uint256 _performanceFeeAmount = _pendingPerformanceFee.mulDiv(
                    currentRecipient.performanceFeeSplit, _MAX_PERCENT * 10 ** underlyingDecimals
                );
                if (_performanceFeeAmount > 0) {
                    asset.safeTransfer(currentRecipient.recipient, _performanceFeeAmount);
                    _performanceFeeTransferred += _performanceFeeAmount;
                    emit PerformanceFeeDispatched(currentRecipient.recipient, _performanceFeeAmount);
                }
            }
        }
        $._pendingManagementFee = _pendingManagementFee - _managementFeeTransferred;
        $._pendingPerformanceFee = _pendingPerformanceFee - _performanceFeeTransferred;
    }

    /* -------------------------------------------------------------------------- */
    /*                                   GETTERS                                  */
    /* -------------------------------------------------------------------------- */

    /// @inheritdoc IFeeDispatcher
    function pendingManagementFee() public view returns (uint256) {
        FeeDispatcherStorage storage $ = _getFeeDispatcherStorage();
        return $._pendingManagementFee;
    }

    /// @inheritdoc IFeeDispatcher
    function pendingPerformanceFee() public view returns (uint256) {
        FeeDispatcherStorage storage $ = _getFeeDispatcherStorage();
        return $._pendingPerformanceFee;
    }

    /// @inheritdoc IFeeDispatcher
    function feeRecipients() public view returns (FeeRecipient[] memory) {
        FeeDispatcherStorage storage $ = _getFeeDispatcherStorage();
        return $._feeRecipients;
    }

    /// @inheritdoc IFeeDispatcher
    function feeRecipient(address recipient) public view returns (FeeRecipient memory) {
        FeeDispatcherStorage storage $ = _getFeeDispatcherStorage();
        uint256 _recipientsLength = $._feeRecipients.length;
        for (uint256 i; i < _recipientsLength; i++) {
            if ($._feeRecipients[i].recipient == recipient) {
                return $._feeRecipients[i];
            }
        }
        revert FeeRecipientDoesNotExist(recipient);
    }

    /// @inheritdoc IFeeDispatcher
    function feeRecipientAt(uint256 index) public view returns (FeeRecipient memory) {
        FeeDispatcherStorage storage $ = _getFeeDispatcherStorage();
        return $._feeRecipients[index];
    }

    /* -------------------------------------------------------------------------- */
    /*                                   SETTERS                                  */
    /* -------------------------------------------------------------------------- */

    /// @dev Increment the pending management fee.
    /// @param amount The amount to increment the pending management fee by.
    function _incrementPendingManagementFee(uint256 amount) internal {
        FeeDispatcherStorage storage $ = _getFeeDispatcherStorage();
        $._pendingManagementFee += amount;
        emit ManagementFeesCollected(amount);
    }

    /// @dev Increment the pending performance fee.
    /// @param amount The amount to increment the pending performance fee by.
    function _incrementPendingPerformanceFee(uint256 amount) internal {
        FeeDispatcherStorage storage $ = _getFeeDispatcherStorage();
        $._pendingPerformanceFee += amount;
        emit PerformanceFeesCollected(amount);
    }

    /// @dev Set the fee recipients.
    ///      The fee recipients must be unique and the total fee splits must be 100e18 (representing 100%).
    /// @param recipients The new fee recipients.
    /// @param underlyingDecimal The number of decimals of the underlying asset.
    function _setFeeRecipients(FeeRecipient[] memory recipients, uint8 underlyingDecimal) internal {
        FeeDispatcherStorage storage $ = _getFeeDispatcherStorage();

        if (recipients.length == 0) {
            revert EmptyArray();
        }

        delete $._feeRecipients;

        uint256 _totalManagementFeeSplit;
        uint256 _totalPerformanceFeeSplit;
        uint256 _recipientsLength = recipients.length;
        for (uint256 i; i < _recipientsLength; i++) {
            _totalManagementFeeSplit += recipients[i].managementFeeSplit;
            _totalPerformanceFeeSplit += recipients[i].performanceFeeSplit;

            if (recipients[i].recipient == address(0)) {
                revert AddressZero();
            }

            for (uint256 j = i + 1; j < _recipientsLength; j++) {
                if (recipients[i].recipient == recipients[j].recipient) {
                    revert FeeRecipientNotUnique(recipients[i].recipient);
                }
            }
            $._feeRecipients.push(recipients[i]);
        }
        if (_totalManagementFeeSplit != _MAX_PERCENT * 10 ** underlyingDecimal) {
            revert WrongManagementFeeSplit(_totalManagementFeeSplit);
        }
        if (_totalPerformanceFeeSplit != _MAX_PERCENT * 10 ** underlyingDecimal) {
            revert WrongPerformanceFeeSplit(_totalPerformanceFeeSplit);
        }
        emit FeeRecipientsSet($._feeRecipients);
    }
}
