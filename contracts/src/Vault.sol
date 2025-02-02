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
import {Address} from "@openzeppelin/utils/Address.sol";
import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {IERC20Metadata} from "@openzeppelin/interfaces/IERC20Metadata.sol";
import {ERC20Upgradeable, ERC4626Upgradeable} from "@openzeppelin-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import {AccessControlDefaultAdminRulesUpgradeable} from "@openzeppelin-upgradeable/access/extensions/AccessControlDefaultAdminRulesUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

import {AmountZero, AddressNotContract, AddressSanctioned, DepositPaused, InvalidConnectorName, MinimumTotalSupplyNotReached, NoAdditionalRewardsClaimed, NotDelegateCall, NothingToCollect, NotTransferable, OffsetTooHigh, PreviewZero, RemainderNotZero, TotalAssetsDecreased, WrongManagementFee, WrongPerformanceFee} from "./Errors.sol";
import {IConnector} from "./interfaces/IConnector.sol";
import {ISanctionsList} from "./interfaces/ISanctionsList.sol";
import {IConnectorRegistry} from "./interfaces/IConnectorRegistry.sol";
import {FeeDispatcher, IFeeDispatcher} from "./abstracts/FeeDispatcher.sol";
import {ReserveContract, ReserveFactory} from "./ReserveFactory.sol";
import {OracleForward} from "./OracleForward.sol";

/// @title Kiln DeFi Integration Vault.
/// @notice ERC-4626 Vault depositing assets into a protocol.
/// @dev Using ERC-7201 standard.
contract Vault is
    ERC4626Upgradeable,
    AccessControlDefaultAdminRulesUpgradeable,
    ReentrancyGuardUpgradeable,
    FeeDispatcher
{
    using Address for address;
    using Math for uint256;

    /* -------------------------------------------------------------------------- */
    /*                                  CONSTANTS                                 */
    /* -------------------------------------------------------------------------- */

    /// @dev Represents the maximum fee that can be charged for performance and management fees.
    uint256 internal constant _MAX_FEE = 35;

    /// @dev Represents the maximum offset.
    uint8 internal constant _MAX_OFFSET = 23;

    /// @notice The role code for the fee manager.
    bytes32 public constant FEE_MANAGER_ROLE = bytes32("FEE_MANAGER");

    /// @notice The role code for the sanctions manager.
    bytes32 public constant SANCTIONS_MANAGER_ROLE =
        bytes32("SANCTIONS_MANAGER");

    /// @notice The role code for the claim manager.
    bytes32 public constant CLAIM_MANAGER_ROLE = bytes32("CLAIM_MANAGER");

    /// @notice The role code for the pauser role.
    bytes32 public constant PAUSER_ROLE = bytes32("PAUSER");

    /// @notice The role code for the unpauser role.
    bytes32 public constant UNPAUSER_ROLE = bytes32("UNPAUSER");

    /* -------------------------------------------------------------------------- */
    /*                                  IMMUTABLE                                 */
    /* -------------------------------------------------------------------------- */

    /// @dev The address of the implementation (regardless of the context).
    address internal immutable _self = address(this);

    /* -------------------------------------------------------------------------- */
    /*                               STORAGE (proxy)                              */
    /* -------------------------------------------------------------------------- */

    /// @notice The storage layout of the contract.
    /// @param _connectorRegistry The connector registry address.
    /// @param _connectorName The name of the connector used by the vault to interact with the proper protocol.
    /// @param _managementFee The management fee (between 0 and 100, scaled to the underlying asset decimals).
    /// @param _performanceFee The performance fee (between 0 and 100, scaled to the underlying asset decimals).
    /// @param _lastTotalAssets The last amount of the underlying asset that is “managed” by the vault.
    /// @param _minTotalSupply The minimum total supply of the vault shares.
    /// @param _transferable True if the vault shares are transferable, False if not.
    /// @param _offset The offset (inflation attack mitigation).
    /// @param _collectablePerformanceFeesShares The amount of performance fees shares that can be collected by the FeeManager.
    /// @param _sanctionsList The sanctions list contract from Chainalysis.
    struct VaultStorage {
        IConnectorRegistry _connectorRegistry;
        bytes32 _connectorName;
        uint256 _managementFee;
        uint256 _performanceFee;
        uint256 _lastTotalAssets;
        uint256 _minTotalSupply;
        bool _transferable;
        uint8 _offset;
        uint256 _collectablePerformanceFeesShares;
        ISanctionsList _sanctionsList;
        bool _depositPaused;
    }

    function _getVaultStorage() private pure returns (VaultStorage storage $) {
        assembly {
            $.slot := VaultStorageLocation
        }
    }

    /// @dev The storage slot of the VaultStorage struct in the proxy contract.
    ///      keccak256(abi.encode(uint256(keccak256("kiln.storage.vault")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant VaultStorageLocation =
        0x6bb5a2a0ae924c2ea94f037035a09f65614421e2a7d96c9bcbd59acdd32e6000;

    /* -------------------------------------------------------------------------- */
    /*                                   EVENTS                                   */
    /* -------------------------------------------------------------------------- */

    /// @dev Emitted when the management fee is updated.
    /// @param newManagementFee The new management fee.
    event ManagementFeeUpdated(uint256 newManagementFee);

    /// @dev Emitted when the performance fee is updated.
    /// @param newPerformanceFee The new performance fee.
    event PerformanceFeeUpdated(uint256 newPerformanceFee);

    /// @dev Emitted when the connector registry is updated.
    /// @param newConnectorRegistry The new connector registry.
    event ConnectorRegistryUpdated(IConnectorRegistry newConnectorRegistry);

    /// @dev Emitted when the connector name is updated.
    /// @param newConnectorName The new connector name.
    event ConnectorNameUpdated(bytes32 newConnectorName);

    /// @dev Emitted when the transferable flag is updated.
    /// @param newTransferableFlag The new transferable flag.
    event TransferableUpdated(bool newTransferableFlag);

    /// @dev Emitted when the ERC4626 name is initialized.
    /// @param name The name of the ERC4626.
    event NameInitialized(string name);

    /// @dev Emitted when the ERC4626 symbol is initialized.
    /// @param symbol The symbol of the ERC4626.
    event SymbolInitialized(string symbol);

    /// @dev Emitted when an asset is initialized.
    /// @param asset The (ERC20) asset that is initialized.
    event AssetInitialized(IERC20 asset);

    /// @dev Emitted when the offset is initialized.
    /// @param offset The offset.
    event OffsetInitialized(uint8 offset);

    /// @dev Emitted when minimum supply state is updated.
    /// @param newMinTotalSupply The new minimum supply state.
    event MinTotalSupplyInitialized(uint256 newMinTotalSupply);

    /// @dev Emitted when the sanctions list is updated.
    /// @param newSanctionsList The new sanctions list.
    event SanctionsListUpdated(ISanctionsList newSanctionsList);

    /// @dev Emitted when addtionnal rewards are claimed to the underlying protocol.
    /// @param rewardsAsset The rewards asset claimed.
    /// @param amount The amount distributed to the vault.
    event RewardsClaimed(address indexed rewardsAsset, uint256 amount);

    /* -------------------------------------------------------------------------- */
    /*                                  MODIFIERS                                 */
    /* -------------------------------------------------------------------------- */

    /// @dev Throws if the ERC4626 is not transferable.
    modifier whenTransferable() {
        if (!_getVaultStorage()._transferable) revert NotTransferable();
        _;
    }

    /// @dev Throws if the call is not a delegate call.
    ///      Allow to check if the contract is called from a proxy.
    modifier onlyDelegateCall() {
        if (address(this) == _self) revert NotDelegateCall();
        _;
    }

    /// @dev Throws if the given address is sanctioned by Chainalysis.
    ///      If the sanctions list is not set, the check is skipped.
    /// @param addr The address to check.
    modifier notSanctioned(address addr) {
        _notSanctioned(addr);
        _;
    }

    /// @dev Throws if the deposit is paused.
    modifier whenDepositNotPaused() {
        if (_getVaultStorage()._depositPaused) revert DepositPaused();
        _;
    }

    /* -------------------------------------------------------------------------- */
    /*                                 PROXY LOGIC                                */
    /* -------------------------------------------------------------------------- */

    /// @notice Parameters for the `initialize()` function.
    struct InitializationParams {
        IERC20 asset_;
        string name_;
        string symbol_;
        bool transferable_;
        IConnectorRegistry connectorRegistry_;
        bytes32 connectorName_;
        FeeRecipient[] recipients_;
        uint256 managementFee_;
        uint256 performanceFee_;
        address initialDefaultAdmin_;
        address initialFeeManager_;
        address initialSanctionsManager_;
        address initialClaimManager_;
        address initialPauser_;
        address initialUnpauser_;
        uint48 initialDelay_;
        uint8 offset_;
        ISanctionsList sanctionsList_;
        uint256 minTotalSupply_;
    }

    /// @notice Initializes the contract in the proxy context.
    /// @param params The initialization parameters.
    function initialize(
        InitializationParams calldata params
    ) public onlyDelegateCall initializer {
        __ERC4626_init(params.asset_);
        emit AssetInitialized(params.asset_);

        __ERC20_init(params.name_, params.symbol_);
        emit NameInitialized(params.name_);
        emit SymbolInitialized(params.symbol_);

        __ReentrancyGuard_init();
        __AccessControlDefaultAdminRules_init(
            params.initialDelay_,
            params.initialDefaultAdmin_
        );
        __FeeDispatcher_init(
            params.recipients_,
            IERC20Metadata(asset()).decimals()
        );

        __Vault_init(params);
    }

    function __Vault_init(
        InitializationParams memory params
    ) internal onlyInitializing {
        __Vault_init_unchained(
            params.transferable_,
            params.connectorRegistry_,
            params.connectorName_,
            params.managementFee_,
            params.performanceFee_,
            params.offset_,
            params.initialFeeManager_,
            params.initialSanctionsManager_,
            params.initialClaimManager_,
            params.initialPauser_,
            params.initialUnpauser_,
            params.sanctionsList_,
            params.minTotalSupply_
        );
    }

    function __Vault_init_unchained(
        bool _transferable,
        IConnectorRegistry _connectorRegistry,
        bytes32 _connectorName,
        uint256 _managementFee,
        uint256 _performanceFee,
        uint8 _offset,
        address _initialFeeManager,
        address _initialSanctionsManager,
        address _initialClaimManager,
        address _initialPauser,
        address _initialUnpauser,
        ISanctionsList _sanctionsList,
        uint256 _minTotalSupply
    ) internal onlyInitializing {
        _setOffset(_offset);
        _setPerformanceFee(_performanceFee);
        _setManagementFee(_managementFee);
        _setConnectorRegistry(_connectorRegistry);
        _setConnectorName(_connectorName);
        _setTransferable(_transferable);
        _setSanctionsList(_sanctionsList);
        _setMinTotalSupply(_minTotalSupply);
        _grantRole(FEE_MANAGER_ROLE, _initialFeeManager);
        _grantRole(SANCTIONS_MANAGER_ROLE, _initialSanctionsManager);
        _grantRole(CLAIM_MANAGER_ROLE, _initialClaimManager);
        _grantRole(PAUSER_ROLE, _initialPauser);
        _grantRole(UNPAUSER_ROLE, _initialUnpauser);
    }

    /* -------------------------------------------------------------------------- */
    /*                           ERC4626 (PUBLIC) LOGIC                           */
    /* -------------------------------------------------------------------------- */

    /// @inheritdoc ERC4626Upgradeable
    function totalAssets() public view override returns (uint256) {
        return
            _getConnector().totalAssets(IERC20Metadata(asset())) +
            totalReserveAssets();
    }

    /// @inheritdoc ERC4626Upgradeable
    function maxDeposit(address) public view override returns (uint256) {
        VaultStorage storage $ = _getVaultStorage();
        if ($._connectorRegistry.paused($._connectorName) || $._depositPaused) {
            return 0;
        }
        return _maxDeposit();
    }

    /// @inheritdoc ERC4626Upgradeable
    function maxMint(address) public view override returns (uint256) {
        VaultStorage storage $ = _getVaultStorage();
        if ($._connectorRegistry.paused($._connectorName) || $._depositPaused) {
            return 0;
        }
        return _maxMint(totalAssets(), totalSupply());
    }

    /// @inheritdoc ERC4626Upgradeable
    function maxWithdraw(address owner) public view override returns (uint256) {
        VaultStorage storage $ = _getVaultStorage();
        if ($._connectorRegistry.paused($._connectorName)) {
            return 0;
        }
        return _maxWithdraw(owner);
    }

    // @inheritdoc ERC4626Upgradeable
    function maxRedeem(address owner) public view override returns (uint256) {
        VaultStorage storage $ = _getVaultStorage();
        if ($._connectorRegistry.paused($._connectorName)) {
            return 0;
        }
        return _maxRedeem(owner, totalAssets(), totalSupply());
    }

    /// @inheritdoc ERC4626Upgradeable
    function previewDeposit(
        uint256 assets
    ) public view override returns (uint256) {
        (
            uint256 _performanceFeeShares,
            uint256 _newTotalAssets
        ) = _accruedPerformanceFeeShares();
        (uint256 _shares, ) = _previewDeposit(
            assets,
            _newTotalAssets,
            totalSupply() + _performanceFeeShares
        );
        return _shares;
    }

    /// @inheritdoc ERC4626Upgradeable
    function previewMint(
        uint256 shares
    ) public view override returns (uint256) {
        (
            uint256 _performanceFeeShares,
            uint256 _newTotalAssets
        ) = _accruedPerformanceFeeShares();
        (uint256 _assets, ) = _previewMint(
            shares,
            _newTotalAssets,
            totalSupply() + _performanceFeeShares
        );
        return _assets;
    }

    /// @inheritdoc ERC4626Upgradeable
    function previewWithdraw(
        uint256 assets
    ) public view override returns (uint256) {
        (
            uint256 _performanceFeeShares,
            uint256 _newTotalAssets
        ) = _accruedPerformanceFeeShares();

        return
            assets.mulDiv(
                totalSupply() + _performanceFeeShares + 10 ** _decimalsOffset(),
                _newTotalAssets + 1,
                Math.Rounding.Ceil
            );
    }

    /// @inheritdoc ERC4626Upgradeable
    function previewRedeem(
        uint256 shares
    ) public view override returns (uint256) {
        (
            uint256 _performanceFeeShares,
            uint256 _newTotalAssets
        ) = _accruedPerformanceFeeShares();

        return
            shares.mulDiv(
                _newTotalAssets + 1,
                totalSupply() + _performanceFeeShares + 10 ** _decimalsOffset(),
                Math.Rounding.Floor
            );
    }

    /// @inheritdoc ERC4626Upgradeable
    function deposit(
        uint256 assets,
        address receiver
    )
        public
        override
        nonReentrant
        notSanctioned(msg.sender)
        whenDepositNotPaused
        returns (uint256)
    {
        if (assets == 0) revert AmountZero();

        uint256 _maxAssets = _maxDeposit();
        if (assets > _maxAssets)
            revert ERC4626ExceededMaxDeposit(receiver, assets, _maxAssets);

        uint256 _newTotalAssets = _accruePerformanceFee();

        (uint256 _shares, uint256 _managementFeeAmount) = _previewDeposit(
            assets,
            _newTotalAssets,
            totalSupply()
        );
        if (_shares == 0) revert PreviewZero();
        _checkPartialShares(_shares);

        _deposit(_msgSender(), receiver, assets, _shares, _managementFeeAmount);

        return _shares;
    }

    /// @inheritdoc ERC4626Upgradeable
    function mint(
        uint256 shares,
        address receiver
    )
        public
        override
        nonReentrant
        notSanctioned(msg.sender)
        whenDepositNotPaused
        returns (uint256)
    {
        if (shares == 0) revert AmountZero();
        _checkPartialShares(shares);

        uint256 _newTotalAssets = _accruePerformanceFee();
        uint256 _newTotalSupply = totalSupply();

        uint256 _maxShares = _maxMint(_newTotalAssets, _newTotalSupply);
        if (shares > _maxShares)
            revert ERC4626ExceededMaxMint(receiver, shares, _maxShares);

        (uint256 _assets, uint256 _managementFeeAmount) = _previewMint(
            shares,
            _newTotalAssets,
            _newTotalSupply
        );
        if (_assets == 0) revert PreviewZero();

        _deposit(_msgSender(), receiver, _assets, shares, _managementFeeAmount);

        return _assets;
    }

    /// @inheritdoc ERC4626Upgradeable
    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    ) public override nonReentrant notSanctioned(msg.sender) returns (uint256) {
        if (assets == 0) revert AmountZero();

        uint256 _maxAssets = _maxWithdraw(owner);
        if (assets > _maxAssets)
            revert ERC4626ExceededMaxWithdraw(owner, assets, _maxAssets);

        uint256 _newTotalAssets = _accruePerformanceFee();

        uint256 _shares = _convertToShares(
            assets,
            Math.Rounding.Ceil,
            _newTotalAssets,
            totalSupply()
        );
        if (_shares == 0) revert PreviewZero();
        _checkPartialShares(_shares);
        _withdraw(_msgSender(), receiver, owner, assets, _shares);

        return _shares;
    }

    /// @inheritdoc ERC4626Upgradeable
    function redeem(
        uint256 shares,
        address receiver,
        address owner
    ) public override nonReentrant notSanctioned(msg.sender) returns (uint256) {
        if (shares == 0) revert AmountZero();
        _checkPartialShares(shares);

        uint256 _newTotalAssets = _accruePerformanceFee();
        uint256 _newTotalSupply = totalSupply();

        uint256 _maxShares = _maxRedeem(
            owner,
            _newTotalAssets,
            _newTotalSupply
        );
        if (shares > _maxShares)
            revert ERC4626ExceededMaxRedeem(owner, shares, _maxShares);

        uint256 _assets = _convertToAssets(
            shares,
            Math.Rounding.Floor,
            _newTotalAssets,
            _newTotalSupply
        );
        if (_assets == 0) revert PreviewZero();
        _withdraw(_msgSender(), receiver, owner, _assets, shares);

        return _assets;
    }

    /* -------------------------------------------------------------------------- */
    /*                          ERC4626 (INTERNAL) LOGIC                          */
    /* -------------------------------------------------------------------------- */

    /// @dev Variant of ERC4626Upgradeable's _deposit but taking the management fee amount.
    ///      See ERC4626Upgradeable.
    /// @param caller The caller of the function.
    /// @param receiver The receiver of the minted shares.
    /// @param assets The amount of assets to deposit.
    /// @param shares The number of shares to mint.
    /// @param managementFeeAmount The amount of management fee in asset terms, calculated based on the deposit amount.
    function _deposit(
        address caller,
        address receiver,
        uint256 assets,
        uint256 shares,
        uint256 managementFeeAmount
    ) internal {
        uint256 _balanceBefore = IERC20(asset()).balanceOf(address(this));
        SafeERC20.safeTransferFrom(
            IERC20(asset()),
            caller,
            address(this),
            assets
        );
        _mint(receiver, shares);

        VaultStorage storage $ = _getVaultStorage();

        if (totalSupply() < $._minTotalSupply)
            revert MinimumTotalSupplyNotReached();

        // Deposit to underlying protocol
        address _connector = $._connectorRegistry.getOrRevert($._connectorName);
        _connector.functionDelegateCall(
            abi.encodeCall(
                IConnector.deposit,
                (
                    IERC20(asset()),
                    IERC20(asset()).balanceOf(address(this)) -
                        _balanceBefore -
                        managementFeeAmount
                )
            )
        );

        $._lastTotalAssets = totalAssets();
        _incrementPendingManagementFee(managementFeeAmount);

        emit Deposit(caller, receiver, assets, shares);
    }

    /// @dev Variant of ERC4626Upgradeable's _withdraw. See ERC4626Upgradeable.
    /// @param caller The caller of the function.
    /// @param receiver The receiver of the withdrawn assets.
    /// @param owner The owner of the shares to redeem.
    /// @param assets The amount of assets to withdraw from the underlying protocol.
    /// @param shares The number of shares to burn.
    function _withdraw(
        address caller,
        address receiver,
        address owner,
        uint256 assets,
        uint256 shares
    ) internal override {
        if (caller != owner) {
            _spendAllowance(owner, caller, shares);
        }
        _burn(owner, shares);

        // Withdraw from underlying protocol
        VaultStorage storage $ = _getVaultStorage();
        address _connector = $._connectorRegistry.getOrRevert($._connectorName);
        uint256 _balanceBefore = IERC20(asset()).balanceOf(address(this));
        _connector.functionDelegateCall(
            abi.encodeCall(IConnector.withdraw, (IERC20(asset()), assets))
        );

        SafeERC20.safeTransfer(
            IERC20(asset()),
            receiver,
            IERC20(asset()).balanceOf(address(this)) - _balanceBefore
        );

        $._lastTotalAssets = totalAssets();

        emit Withdraw(caller, receiver, owner, assets, shares);
    }

    /// @dev Internal function to retrieve the max depositable amount.
    ///      Calls the connector to get the max depositable amount for the asset (e.g. the supply cap).
    function _maxDeposit() internal view returns (uint256) {
        return _getConnector().maxDeposit(IERC20(asset()));
    }

    /// @dev Internal function to retrieve the max mintable amount.
    /// @param newTotalAssets The Vault's total assets.
    /// @param newTotalSupply The (shares) total supply.
    function _maxMint(
        uint256 newTotalAssets,
        uint256 newTotalSupply
    ) internal view returns (uint256) {
        uint256 _maxDepositable = _maxDeposit();

        if (_maxDepositable == type(uint256).max - 1) {
            return type(uint256).max - 1;
        }

        return
            _convertToShares(
                _maxDepositable,
                Math.Rounding.Floor,
                newTotalAssets,
                newTotalSupply
            );
    }

    /// @dev Internal function to retrieve the max withdrawable amount for a given owner.
    /// @param owner The owner of the shares.
    function _maxWithdraw(address owner) internal view returns (uint256) {
        return
            Math.min(
                _getConnector().maxWithdraw(IERC20(asset())),
                previewRedeem(balanceOf(owner))
            );
    }

    /// @dev Internal function to retrieve the max redeemable amount for a given owner.
    /// @param owner The owner of the shares.
    /// @param newTotalAssets The Vault's total assets.
    /// @param newTotalSupply The (shares) total supply.
    function _maxRedeem(
        address owner,
        uint256 newTotalAssets,
        uint256 newTotalSupply
    ) internal view returns (uint256) {
        uint256 _maxWithdrawable = _getConnector().maxWithdraw(IERC20(asset()));

        if (_maxWithdrawable == type(uint256).max - 1) {
            return balanceOf(owner);
        }

        return
            Math.min(
                _convertToShares(
                    _maxWithdrawable,
                    Math.Rounding.Floor,
                    newTotalAssets,
                    newTotalSupply
                ),
                balanceOf(owner)
            );
    }

    /// @dev Estimates the number of shares mintable from a given deposit and the associated management fee.
    /// @param assets The amount of assets to deposit.
    /// @param newTotalAssets The Vault's total assets
    /// @param supply The (shares) total supply.
    /// @return shares The number of shares that can be minted from the deposited assets, after deducting the management fee.
    /// @return managementFeeAmount The amount of management fee in asset terms, calculated based on the deposit amount.
    function _previewDeposit(
        uint256 assets,
        uint256 newTotalAssets,
        uint256 supply
    ) internal view returns (uint256 shares, uint256 managementFeeAmount) {
        VaultStorage storage $ = _getVaultStorage();

        // Calculate the management fee amount.
        // This is a portion of the deposited assets, scaled by the management fee rate and adjusted for the asset's decimals.
        managementFeeAmount = assets.mulDiv(
            $._managementFee,
            _MAX_PERCENT * 10 ** IERC20Metadata(asset()).decimals()
        );

        // Convert the net asset amount (after deducting the management fee) to shares.
        // The conversion uses floor rounding to determine the number of shares that can be minted.
        shares = _convertToShares(
            assets - managementFeeAmount,
            Math.Rounding.Floor,
            newTotalAssets,
            supply
        );
    }

    /// @dev Estimates the asset amount and management fee for minting a specified number of shares.
    /// @param shares The number of shares to be minted.
    /// @param newTotalAssets The Vault's total assets.
    /// @param supply The (shares) total supply.
    /// @return assets The total amount of assets required to mint the specified number of shares, including the management fee.
    /// @return managementFeeAmount The amount of management fee in asset terms deducted when minting the shares.
    function _previewMint(
        uint256 shares,
        uint256 newTotalAssets,
        uint256 supply
    ) internal view returns (uint256 assets, uint256 managementFeeAmount) {
        VaultStorage storage $ = _getVaultStorage();
        uint256 _managementFee = $._managementFee;
        uint256 _decimals = IERC20Metadata(asset()).decimals();

        // Convert the number of shares to assets with ceiling rounding.
        // This gives us a raw asset value equivalent to the shares before considering management fees.
        uint256 _rawAssetValue = _convertToAssets(
            shares,
            Math.Rounding.Ceil,
            newTotalAssets,
            supply
        );

        // To ensure accuracy in calculations, it's necessary to scale values up.
        uint256 _scaledRawAssetValue = _rawAssetValue * 10 ** _decimals;

        // The management fee is deducted from the maximum percent scale adjusted for decimals.
        uint256 _adjustedMaxPercent = (_MAX_PERCENT * 10 ** _decimals) -
            _managementFee;

        // Calculate the assets required to mint the shares, including the management fee.
        //
        //            _MAX_PERCENT * (_rawAssetValue * 10 ** decimals)
        // assets = -----------------------------------------------------
        //             (_MAX_PERCENT * 10 ** decimals) - _managementFee
        //
        // Note: _managementFee is already scaled to asset decimals.
        //
        assets = _scaledRawAssetValue.mulDiv(
            _MAX_PERCENT,
            _adjustedMaxPercent,
            Math.Rounding.Ceil
        );

        // Calculate the management fee amount from the assets required to mint the shares.
        managementFeeAmount = assets.mulDiv(
            _managementFee,
            _MAX_PERCENT * 10 ** _decimals,
            Math.Rounding.Floor
        );
    }

    /// @dev Variant of  _convertToShares from ERC4626Upgradeable but taking the totalAssets/totalSupply
    ///      parameters instead of calling `totalAssets()` and `totalSupply()`.
    function _convertToShares(
        uint256 assets,
        Math.Rounding rounding,
        uint256 total,
        uint256 supply
    ) internal view returns (uint256) {
        return
            assets.mulDiv(
                supply + 10 ** _decimalsOffset(),
                total + 1,
                rounding
            );
    }

    /// @dev Variant of _convertToAssets from ERC4626Upgradeable but taking the totalAssets/totalSupply
    ///      parameters instead of calling `totalAssets()` and `totalSupply()`.
    function _convertToAssets(
        uint256 shares,
        Math.Rounding rounding,
        uint256 total,
        uint256 supply
    ) internal view returns (uint256) {
        return
            shares.mulDiv(
                total + 1,
                supply + 10 ** _decimalsOffset(),
                rounding
            );
    }

    /// @inheritdoc ERC4626Upgradeable
    function _decimalsOffset() internal view override returns (uint8) {
        return _getVaultStorage()._offset;
    }

    /// @dev Internal function accrue the performance fee and mints the shares.
    /// @return newTotalAssets The vaults total assets after accruing the interest.
    function _accruePerformanceFee() internal returns (uint256 newTotalAssets) {
        VaultStorage storage $ = _getVaultStorage();

        uint256 performanceFeeShares;
        (performanceFeeShares, newTotalAssets) = _accruedPerformanceFeeShares();

        if (performanceFeeShares != 0) {
            _mint(address(this), performanceFeeShares);
            $._collectablePerformanceFeesShares += performanceFeeShares;
        }
    }

    /// @dev Computes and returns the performanceFee shares to mint and the new vault's total assets.
    /// @return performanceFeeShares The number of shares to mint as performance fee.
    /// @return newTotalAssets The vaults total assets after accruing the interest.
    function _accruedPerformanceFeeShares()
        internal
        view
        returns (uint256 performanceFeeShares, uint256 newTotalAssets)
    {
        VaultStorage storage $ = _getVaultStorage();

        newTotalAssets = totalAssets();
        (, uint256 _performance) = newTotalAssets.trySub($._lastTotalAssets);

        if (_performance != 0 && $._performanceFee != 0) {
            uint256 _performanceFeeAmount = _performance.mulDiv(
                $._performanceFee,
                _MAX_PERCENT * 10 ** IERC20Metadata(asset()).decimals(),
                Math.Rounding.Floor
            );

            // Performance fee is subtracted from the total assets as it's already increased by total interest
            // (including performance fee).
            performanceFeeShares = _convertToShares(
                _performanceFeeAmount,
                Math.Rounding.Floor,
                newTotalAssets - _performanceFeeAmount,
                totalSupply()
            );
        }
    }

    /// @dev Internal function that throws an error if the remainder of the shares is not zero.
    /// @param shares The number of shares to mint/transfer.
    function _checkPartialShares(uint256 shares) internal view {
        uint8 _offset = _decimalsOffset();
        if (_offset > 0) {
            if (shares % 10 ** _offset > 0) revert RemainderNotZero(shares);
        }
    }

    /* -------------------------------------------------------------------------- */
    /*                                 ERC20 LOGIC                                */
    /* -------------------------------------------------------------------------- */

    /// @inheritdoc ERC20Upgradeable
    function transfer(
        address to,
        uint256 value
    )
        public
        override(ERC20Upgradeable, IERC20)
        whenTransferable
        notSanctioned(msg.sender)
        notSanctioned(to)
        returns (bool)
    {
        _checkPartialShares(value);
        return super.transfer(to, value);
    }

    /// @inheritdoc ERC20Upgradeable
    function transferFrom(
        address from,
        address to,
        uint256 value
    )
        public
        override(ERC20Upgradeable, IERC20)
        whenTransferable
        notSanctioned(msg.sender)
        notSanctioned(from)
        notSanctioned(to)
        returns (bool)
    {
        _checkPartialShares(value);
        return super.transferFrom(from, to, value);
    }

    /// @inheritdoc ERC20Upgradeable
    function approve(
        address spender,
        uint256 value
    )
        public
        override(ERC20Upgradeable, IERC20)
        whenTransferable
        notSanctioned(msg.sender)
        notSanctioned(spender)
        returns (bool)
    {
        return super.approve(spender, value);
    }

    /* -------------------------------------------------------------------------- */
    /*                            FEE MANAGEMENT LOGIC                            */
    /* -------------------------------------------------------------------------- */

    /// @inheritdoc IFeeDispatcher
    function dispatchFees() external override nonReentrant {
        _dispatchFees(IERC20(asset()), IERC20Metadata(asset()).decimals());
    }

    /// @notice Collects the performance fees
    function collectPerformanceFees()
        external
        nonReentrant
        onlyRole(FEE_MANAGER_ROLE)
    {
        VaultStorage storage $ = _getVaultStorage();

        (
            uint256 _performanceFeeShares,
            uint256 _newTotalAssets
        ) = _accruedPerformanceFeeShares();

        uint256 _collectable = _convertToAssets(
            $._collectablePerformanceFeesShares + _performanceFeeShares,
            Math.Rounding.Floor,
            _newTotalAssets,
            totalSupply() + _performanceFeeShares
        );
        if (_collectable == 0) revert NothingToCollect();

        uint256 _balanceBefore = IERC20(asset()).balanceOf(address(this));
        address _connector = $._connectorRegistry.getOrRevert($._connectorName);
        _connector.functionDelegateCall(
            abi.encodeCall(IConnector.withdraw, (IERC20(asset()), _collectable))
        );

        _incrementPendingPerformanceFee(
            IERC20(asset()).balanceOf(address(this)) - _balanceBefore
        );

        _burn(address(this), $._collectablePerformanceFeesShares);
        $._collectablePerformanceFeesShares = 0;
        $._lastTotalAssets = totalAssets();
    }

    /* -------------------------------------------------------------------------- */
    /*                                 CLAIM LOGIC                                */
    /* -------------------------------------------------------------------------- */

    /// @notice Claims additional rewards to the underlying protocol.
    /// @dev Additional rewards are considered as yield, where the performance fee can be applied.
    /// @param rewardsAsset The rewards asset to claim.
    /// @param payload The payload to pass to the connector.
    function claimAdditionalRewards(
        address rewardsAsset,
        bytes calldata payload
    ) external nonReentrant onlyRole(CLAIM_MANAGER_ROLE) {
        VaultStorage storage $ = _getVaultStorage();

        uint256 _totalAssetsBefore = totalAssets();
        address _connector = $._connectorRegistry.getOrRevert($._connectorName);
        _connector.functionDelegateCall(
            abi.encodeCall(
                IConnector.claim,
                (IERC20(asset()), IERC20(rewardsAsset), payload)
            )
        );

        uint256 _totalAssets = totalAssets();
        if (_totalAssetsBefore > _totalAssets) {
            revert TotalAssetsDecreased(_totalAssetsBefore, _totalAssets);
        } else if (_totalAssetsBefore == _totalAssets) {
            revert NoAdditionalRewardsClaimed();
        }

        emit RewardsClaimed(rewardsAsset, _totalAssets - _totalAssetsBefore);
    }

    /* -------------------------------------------------------------------------- */
    /*                            SANCTIONS LIST LOGIC                            */
    /* -------------------------------------------------------------------------- */

    /// @notice Sets the sanctions list.
    /// @param newSanctionsList The new sanctions list.
    function setSanctionsList(
        ISanctionsList newSanctionsList
    ) external onlyRole(SANCTIONS_MANAGER_ROLE) {
        _setSanctionsList(newSanctionsList);
    }

    /// @dev Internal modifier logic to check if the given address is sanctioned.
    /// @param addr The address to check.
    function _notSanctioned(address addr) internal view {
        ISanctionsList _sanctionsList = _getVaultStorage()._sanctionsList;
        if (
            address(_sanctionsList) != address(0) &&
            _sanctionsList.isSanctioned(addr)
        ) {
            revert AddressSanctioned(addr);
        }
    }

    /* -------------------------------------------------------------------------- */
    /*                             DEPOSIT PAUSE LOGIC                            */
    /* -------------------------------------------------------------------------- */

    /// @notice Pauses the deposit.
    function pauseDeposit() external onlyRole(PAUSER_ROLE) {
        _getVaultStorage()._depositPaused = true;
    }

    /// @notice Unpauses the deposit.
    function unpauseDeposit() external onlyRole(UNPAUSER_ROLE) {
        _getVaultStorage()._depositPaused = false;
    }

    /* -------------------------------------------------------------------------- */
    /*                              (PUBLIC) SETTERS                              */
    /* -------------------------------------------------------------------------- */

    /// @notice Sets the fee recipients.
    /// @param recipients The new fee recipients.
    function setFeeRecipients(
        FeeRecipient[] memory recipients
    ) external onlyRole(FEE_MANAGER_ROLE) {
        _setFeeRecipients(recipients, IERC20Metadata(asset()).decimals());
    }

    /// @notice Sets the management fee.
    /// @param newManagementFee The new management fee.
    function setManagementFee(
        uint256 newManagementFee
    ) external onlyRole(FEE_MANAGER_ROLE) {
        _setManagementFee(newManagementFee);
    }

    /// @notice Sets the performance fee.
    /// @dev This function also collects the last performance fees prior to updating the fee.
    /// @param newPerformanceFee The new performance fee.
    function setPerformanceFee(
        uint256 newPerformanceFee
    ) external onlyRole(FEE_MANAGER_ROLE) {
        // Accrue the last performance fees prior to updating the fee amount.
        VaultStorage storage $ = _getVaultStorage();
        $._lastTotalAssets = _accruePerformanceFee();

        _setPerformanceFee(newPerformanceFee);
    }

    /* -------------------------------------------------------------------------- */
    /*                             (INTERNAL) SETTERS                             */
    /* -------------------------------------------------------------------------- */

    /// @dev Internal logic to set the performance fee.
    /// @param newPerformanceFee The new performance fee.
    function _setPerformanceFee(uint256 newPerformanceFee) internal {
        if (
            newPerformanceFee >
            _MAX_FEE * 10 ** IERC20Metadata(asset()).decimals()
        ) {
            revert WrongPerformanceFee(newPerformanceFee);
        }
        _getVaultStorage()._performanceFee = newPerformanceFee;
        emit PerformanceFeeUpdated(newPerformanceFee);
    }

    /// @dev Internal logic to set the management fee.
    /// @param newManagementFee The new management fee.
    function _setManagementFee(uint256 newManagementFee) internal {
        if (
            newManagementFee >
            _MAX_FEE * 10 ** IERC20Metadata(asset()).decimals()
        ) {
            revert WrongManagementFee(newManagementFee);
        }
        _getVaultStorage()._managementFee = newManagementFee;
        emit ManagementFeeUpdated(newManagementFee);
    }

    /// @notice Internal logic to set the connector registry.
    /// @param newConnectorRegistry The new connector registry.
    function _setConnectorRegistry(
        IConnectorRegistry newConnectorRegistry
    ) internal {
        VaultStorage storage $ = _getVaultStorage();
        if (address(newConnectorRegistry).code.length == 0)
            revert AddressNotContract(address(newConnectorRegistry));
        $._connectorRegistry = newConnectorRegistry;
        emit ConnectorRegistryUpdated(newConnectorRegistry);
    }

    /// @notice Internal logic to set the connector name.
    /// @param newConnectorName The new connector name.
    function _setConnectorName(bytes32 newConnectorName) internal {
        VaultStorage storage $ = _getVaultStorage();
        if (!$._connectorRegistry.connectorExists(newConnectorName))
            revert InvalidConnectorName(newConnectorName);
        $._connectorName = newConnectorName;
        emit ConnectorNameUpdated(newConnectorName);
    }

    /// @notice Internal logic to set the transferable flag.
    /// @param newTransferableFlag The new transferable flag.
    function _setTransferable(bool newTransferableFlag) internal {
        _getVaultStorage()._transferable = newTransferableFlag;
        emit TransferableUpdated(newTransferableFlag);
    }

    /// @notice Internal logic to set the offset.
    /// @param offset The new offset.
    function _setOffset(uint8 offset) internal {
        if (offset > _MAX_OFFSET) revert OffsetTooHigh(offset);
        _getVaultStorage()._offset = offset;
        emit OffsetInitialized(offset);
    }

    /// @notice Internal logic to set the sanctions list.
    /// @dev Possible to set the sanctions list to address(0) to disable it.
    /// @param newSanctionsList The new sanctions list.
    function _setSanctionsList(ISanctionsList newSanctionsList) internal {
        _getVaultStorage()._sanctionsList = newSanctionsList;
        emit SanctionsListUpdated(newSanctionsList);
    }

    /// @notice Internal logic to set the minimum supply state.
    /// @dev This is used to prevent a griefing attack.
    /// @param newMinTotalSupply The new minimum total supply required after a deposit.
    function _setMinTotalSupply(uint256 newMinTotalSupply) internal {
        _getVaultStorage()._minTotalSupply = newMinTotalSupply;
        emit MinTotalSupplyInitialized(newMinTotalSupply);
    }

    /* -------------------------------------------------------------------------- */
    /*                                   GETTERS                                  */
    /* -------------------------------------------------------------------------- */

    /// @notice Returns if the ERC4626 share is transferable.
    /// @return transferable True if the ERC4626 share is transferable, False if not.
    function transferable() external view returns (bool) {
        return _getVaultStorage()._transferable;
    }

    /// @notice Returns the connector registry.
    /// @return connectorRegistry The connector registry.
    function connectorRegistry() external view returns (IConnectorRegistry) {
        return _getVaultStorage()._connectorRegistry;
    }

    /// @notice Returns the connector name.
    /// @return connectorName The connector name.
    function connectorName() external view returns (bytes32) {
        return _getVaultStorage()._connectorName;
    }

    /// @notice Returns the management fee.
    /// @return managementFee The management fee.
    function managementFee() external view returns (uint256) {
        return _getVaultStorage()._managementFee;
    }

    /// @notice Returns the performance fee.
    /// @return performanceFee The performance fee.
    function performanceFee() external view returns (uint256) {
        return _getVaultStorage()._performanceFee;
    }

    /// @notice Returns the collectable performance fees (when calling `collectPerformanceFees`).
    /// @return collectablePerformanceFees The amount of performance fees that can be collected by the FeeManager.
    function collectablePerformanceFees() external view returns (uint256) {
        (
            uint256 _accruedShares,
            uint256 _newTotalAssets
        ) = _accruedPerformanceFeeShares();
        uint256 _totalShares = _accruedShares +
            _getVaultStorage()._collectablePerformanceFeesShares;

        return
            _convertToAssets(
                _totalShares,
                Math.Rounding.Floor,
                _newTotalAssets,
                totalSupply() + _accruedShares
            );
    }

    /// @notice Returns the sanctions list.
    /// @return sanctionsList The sanctions list.
    function sanctionsList() external view returns (ISanctionsList) {
        return _getVaultStorage()._sanctionsList;
    }

    /// @dev Get the connector address.
    function _getConnector() internal view returns (IConnector) {
        VaultStorage storage $ = _getVaultStorage();
        return IConnector($._connectorRegistry.get($._connectorName));
    }

    /* -------------------------------------------------------------------------- */
    /*                              RESERVE CONTRACT                              */
    /* -------------------------------------------------------------------------- */

    address[] public deployedReserves;
    uint256 public reserveCounter = 0;
    address public reserveFactory;
    address oracleSpot;

    /// @notice Get total assets of each reserves of the vault
    function totalReserveAssets() public view returns (uint256) {
        uint256 totalBalance = 0;
        for (uint256 i = 0; i < deployedReserves.length; i++) {
            if (deployedReserves[i] != address(0)) {
                (, , uint256 remainingAmount, , , ) = ReserveContract(
                    deployedReserves[i]
                ).params();
                totalBalance += getForwardValue(i, remainingAmount);
            }
        }
        return totalBalance;
    }

    uint256 internal constant _LOCKED_EXCHANGE_RATE = 112;
    uint256 internal _END_DATE;
    uint256 internal _SETUP_DATE;
address _owner;

    constructor(address _reserveFactory) {
        _owner = msg.sender;
        reserveFactory = _reserveFactory;
        oracleSpot = address(new OracleForward());
        _SETUP_DATE = _END_DATE - 2;
        _END_DATE = block.timestamp + 90 days;
    }

    /// @notice Create new forward contract object
    function reserveSetUp(
        uint256 amount,
        uint256 remainingAmount,
        uint256 lockedExchangeRate,
        uint256 endDate,
        address oracleForward
    ) internal returns (address) {
        ReserveContract.reserveParams memory reserveParams = ReserveContract
            .reserveParams({
                id: reserveCounter,
                amount: amount,
                remainingAmount: remainingAmount,
                lockedExchangeRate: lockedExchangeRate,
                endDate: endDate,
                oracleForward: oracleForward // T0
            });

        bytes memory data = abi.encodeWithSelector(
            ReserveFactory(reserveFactory).createReserve.selector,
            reserveParams,
            bytes32(reserveCounter)
        );
        (bool success, bytes memory returnData) = reserveFactory.call(data);
        require(success, "Reserve creation failed");
        address reserveAddr = abi.decode(returnData, (address));
        deployedReserves[reserveCounter] = reserveAddr;
        reserveCounter++;
        return reserveAddr;
    }

    /// @notice Function to allow bank to launch a new forward with new terms
    function newForwardRate(uint256 contractId) public view {
        address current = deployedReserves[contractId];
        require(current != address(0), "Reserve contract does not exist");

        if (block.timestamp > _SETUP_DATE) {
            // Banks should calculate new amount as Underlying_assets_Value + APY_Vault_Value * pro_rata
            //address reserve = reserveSetUp();
        }
    }

    /// @notice close forward vault if empty
    function closeForward(uint256 id) public {
        address a = deployedReserves[id];
        require(a.balance == 0, "Non empty vault");

        ReserveContract ctr = ReserveContract(a);
        require(ctr.owner() == msg.sender, "Invalid user");

        delete deployedReserves[id];
    }

    function getForwardValue(
        uint256 forwardId,
        uint256 amount
    ) public view returns (uint256) {
        ReserveContract forward = ReserveContract(deployedReserves[forwardId]);
        (, , uint256 remainingAmount, , , address oracleForward) = forward
            .params();
        OracleForward oracle = OracleForward(oracleForward);
        uint64 oracleValue = oracle.getOracleResult();

        return (oracleValue * amount) / (remainingAmount);
    }

    function claimBalance(address vaultAddress) internal {
        ReserveContract currentContract = ReserveContract(vaultAddress);
        uint256 balance = IERC20(asset()).balanceOf(address(currentContract));

        require(balance > 0, "No balance to claim");

        currentContract.withdraw(balance, msg.sender);
    }

    struct NegativeResult {
        uint vaultId;
        int256 amount;
    }

    function withdrawAmount(uint256 amount) public returns (uint256) {
        NegativeResult[] memory negativeResults = new NegativeResult[](deployedReserves.length);
        uint count = 0;
        uint256 amount_vault_currency = amount *
            OracleForward(oracleSpot).getOracleSpot();
        uint amount_remaining = amount_vault_currency;
        int256 profitAndLoss = 0;

        for (uint i = 0; i < deployedReserves.length; i++) {
            ReserveContract currentContract = ReserveContract(
                deployedReserves[i]
            );
            (, , uint256 remainingAmount, , , ) = currentContract.params();
            int256 result = int256(
                getForwardValue(i, Math.min(amount_remaining, remainingAmount))
            );

            if (result < 0) {
                negativeResults[count] = (NegativeResult(i, result));
                count++;
            } else {
                claimBalance(deployedReserves[i]);
            }

            profitAndLoss += result;

            if (amount_remaining > remainingAmount) {
                amount_remaining -= remainingAmount;
                closeForward(i);
            } else {
                break;
            }
        }
        uint256 prorata = amount_vault_currency / totalAssets();
        
        uint256 nbShares = IERC20(asset()).balanceOf(address(this));
        nbShares = Math.ceilDiv(prorata * nbShares, 1);
        

        uint256 assets = _convertToAssets(
            nbShares,
            Math.Rounding.Ceil,
            totalAssets(),
            totalSupply()
        );
        // 
        _withdraw(_msgSender(), msg.sender, _owner, assets, nbShares);
        return uint256(profitAndLoss);
    }
}
