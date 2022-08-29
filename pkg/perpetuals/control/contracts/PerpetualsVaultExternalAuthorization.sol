// SPDX-License-Identifier: MIT

pragma solidity ^0.7.0;

import { Authentication } from "@koyofinance/contracts-solidity-utils/contracts/helpers/Authentication.sol";
import { IAuthorizer } from "@koyofinance/contracts-interfaces/contracts/vault/IAuthorizer.sol";
import { IPerpetualsVault } from "@koyofinance/contracts-interfaces/contracts/perpetuals/core/IPerpetualsVault.sol";
// solhint-disable-next-line max-line-length
import { IPerpetualsVaultPriceFeed } from "@koyofinance/contracts-interfaces/contracts/perpetuals/oracle/IPerpetualsVaultPriceFeed.sol";
import { IVault as IExchangeVault } from "@koyofinance/contracts-interfaces/contracts/vault/IVault.sol";

// solhint-disable-next-line max-line-length
import { Errors, _require } from "@koyofinance/contracts-interfaces/contracts/solidity-utils/helpers/KoyoErrors.sol";

contract PerpetualsVaultExternalAuthorization is Authentication {
    uint256 public marginFeeBasisPoints;
    uint256 public maxMarginFeeBasisPoints;
    bool public shouldToggleIsLeverageEnabled = true;

    IExchangeVault private immutable _exchangeVault;
    IPerpetualsVault private immutable _perpetualsVault;
    IPerpetualsVaultPriceFeed private _perpetualsVaultPriceFeed;

    constructor(
        IExchangeVault exchangeVault,
        IPerpetualsVault perpetualsVault,
        uint256 _marginFeeBasisPoints,
        uint256 _maxMarginFeeBasisPoints
    ) Authentication(bytes32(uint256(address(this)))) {
        _exchangeVault = exchangeVault;
        _perpetualsVault = perpetualsVault;
        _perpetualsVaultPriceFeed = IPerpetualsVaultPriceFeed(perpetualsVault.priceFeed());

        marginFeeBasisPoints = _marginFeeBasisPoints;
        maxMarginFeeBasisPoints = _maxMarginFeeBasisPoints;
    }

    function setVaultPriceFeed(address priceFeed) external authenticate {
        IPerpetualsVault perpetualsVault = getPerpetualsVault();

        perpetualsVault.setPriceFeed(priceFeed);
        _perpetualsVaultPriceFeed = IPerpetualsVaultPriceFeed(priceFeed);
    }

    function setShouldToggleIsLeverageEnabled(bool _shouldToggleIsLeverageEnabled) external authenticate {
        shouldToggleIsLeverageEnabled = _shouldToggleIsLeverageEnabled;
    }

    function setMarginFeeBasisPoints(uint256 _marginFeeBasisPoints, uint256 _maxMarginFeeBasisPoints)
        external
        authenticate
    {
        marginFeeBasisPoints = _marginFeeBasisPoints;
        maxMarginFeeBasisPoints = _maxMarginFeeBasisPoints;
    }

    function setTokenConfig(
        address _token,
        uint256 _tokenDecimals,
        uint256 _tokenWeight,
        uint256 _minProfitBps,
        uint256 _maxUsdgAmount,
        bool _isStable,
        bool _isShortable,
        uint256 _bufferAmount,
        uint256 _usdgAmount
    ) external authenticate {
        IPerpetualsVault perpetualsVault = getPerpetualsVault();

        perpetualsVault.setTokenConfig(
            _token,
            _tokenDecimals,
            _tokenWeight,
            _minProfitBps,
            _maxUsdgAmount,
            _isStable,
            _isShortable
        );

        perpetualsVault.setBufferAmount(_token, _bufferAmount);
        perpetualsVault.setUsdgAmount(_token, _usdgAmount);
    }

    function modifyTokenConfig(
        address _token,
        uint256 _tokenWeight,
        uint256 _minProfitBps,
        uint256 _maxUsdgAmount,
        uint256 _bufferAmount,
        uint256 _usdgAmount
    ) external authenticate {
        require(_minProfitBps <= 500, "Timelock: invalid _minProfitBps");
        IPerpetualsVault perpetualsVault = getPerpetualsVault();

        uint256 tokenDecimals = perpetualsVault.tokenDecimals(_token);
        bool isStable = perpetualsVault.stableTokens(_token);
        bool isShortable = perpetualsVault.shortableTokens(_token);

        perpetualsVault.setTokenConfig(
            _token,
            tokenDecimals,
            _tokenWeight,
            _minProfitBps,
            _maxUsdgAmount,
            isStable,
            isShortable
        );

        perpetualsVault.setBufferAmount(_token, _bufferAmount);
        perpetualsVault.setUsdgAmount(_token, _usdgAmount);
    }

    function setSwapFees(
        uint256 _taxBasisPoints,
        uint256 _stableTaxBasisPoints,
        uint256 _mintBurnFeeBasisPoints,
        uint256 _swapFeeBasisPoints,
        uint256 _stableSwapFeeBasisPoints
    ) external authenticate {
        IPerpetualsVault perpetualsVault = getPerpetualsVault();

        perpetualsVault.setFees(
            _taxBasisPoints,
            _stableTaxBasisPoints,
            _mintBurnFeeBasisPoints,
            _swapFeeBasisPoints,
            _stableSwapFeeBasisPoints,
            maxMarginFeeBasisPoints,
            perpetualsVault.liquidationFeeUsd(),
            perpetualsVault.minProfitTime(),
            perpetualsVault.hasDynamicFees()
        );
    }

    // assign _marginFeeBasisPoints to this.marginFeeBasisPoints
    // because enableLeverage would update Vault.marginFeeBasisPoints to this.marginFeeBasisPoints
    // and disableLeverage would reset the Vault.marginFeeBasisPoints to this.maxMarginFeeBasisPoints
    function setFees(
        uint256 _taxBasisPoints,
        uint256 _stableTaxBasisPoints,
        uint256 _mintBurnFeeBasisPoints,
        uint256 _swapFeeBasisPoints,
        uint256 _stableSwapFeeBasisPoints,
        uint256 _marginFeeBasisPoints,
        uint256 _liquidationFeeUsd,
        uint256 _minProfitTime,
        bool _hasDynamicFees
    ) external authenticate {
        IPerpetualsVault perpetualsVault = getPerpetualsVault();

        marginFeeBasisPoints = _marginFeeBasisPoints;

        perpetualsVault.setFees(
            _taxBasisPoints,
            _stableTaxBasisPoints,
            _mintBurnFeeBasisPoints,
            _swapFeeBasisPoints,
            _stableSwapFeeBasisPoints,
            maxMarginFeeBasisPoints,
            _liquidationFeeUsd,
            _minProfitTime,
            _hasDynamicFees
        );
    }

    function enableLeverage() external authenticate {
        IPerpetualsVault perpetualsVault = getPerpetualsVault();

        if (shouldToggleIsLeverageEnabled) {
            perpetualsVault.setIsLeverageEnabled(true);
        }

        perpetualsVault.setFees(
            perpetualsVault.taxBasisPoints(),
            perpetualsVault.stableTaxBasisPoints(),
            perpetualsVault.mintBurnFeeBasisPoints(),
            perpetualsVault.swapFeeBasisPoints(),
            perpetualsVault.stableSwapFeeBasisPoints(),
            marginFeeBasisPoints,
            perpetualsVault.liquidationFeeUsd(),
            perpetualsVault.minProfitTime(),
            perpetualsVault.hasDynamicFees()
        );
    }

    function disableLeverage() external authenticate {
        IPerpetualsVault perpetualsVault = getPerpetualsVault();

        if (shouldToggleIsLeverageEnabled) {
            perpetualsVault.setIsLeverageEnabled(false);
        }

        perpetualsVault.setFees(
            perpetualsVault.taxBasisPoints(),
            perpetualsVault.stableTaxBasisPoints(),
            perpetualsVault.mintBurnFeeBasisPoints(),
            perpetualsVault.swapFeeBasisPoints(),
            perpetualsVault.stableSwapFeeBasisPoints(),
            maxMarginFeeBasisPoints, // marginFeeBasisPoints
            perpetualsVault.liquidationFeeUsd(),
            perpetualsVault.minProfitTime(),
            perpetualsVault.hasDynamicFees()
        );
    }

    function executePerpetualsVault(uint256 value, bytes calldata data) external authenticate {
        // solhint-disable-next-line avoid-low-level-calls
        (bool success, ) = address(_perpetualsVault).call{ value: value }(data);
        _require(success, Errors.PERPETUALS_EXTERNAL_AUTHORIZATION_ARBITRARY_VAULT_CALL_REVERTED);
    }

    function executePerpetualsVaultPriceFeed(uint256 value, bytes calldata data) external authenticate {
        // solhint-disable-next-line avoid-low-level-calls
        (bool success, ) = address(_perpetualsVaultPriceFeed).call{ value: value }(data);
        _require(success, Errors.PERPETUALS_EXTERNAL_AUTHORIZATION_ARBITRARY_PRICE_FEED_CALL_REVERTED);
    }

    function executePerpetualsVaultFastPriceFeed(
        address fastPriceFeed,
        uint256 value,
        bytes calldata data
    ) external authenticate {
        _require(
            (fastPriceFeed != address(_perpetualsVault)) && (fastPriceFeed != address(_perpetualsVaultPriceFeed)),
            Errors.PERPETUALS_EXTERNAL_AUTHORIZATION_ARBITRARY_DISSALOWED_TARGET_ADDRESS
        );

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, ) = fastPriceFeed.call{ value: value }(data);
        _require(success, Errors.PERPETUALS_EXTERNAL_AUTHORIZATION_ARBITRARY_PRICE_FEED_CALL_REVERTED);
    }

    function getExchangeVault() public view returns (IExchangeVault) {
        return _exchangeVault;
    }

    function getPerpetualsVault() public view returns (IPerpetualsVault) {
        return _perpetualsVault;
    }

    function _getAuthorizer() internal view returns (IAuthorizer) {
        // Access control management is delegated to the Vault's Authorizer. This lets Balancer Governance manage which
        // accounts can call permissioned functions.
        return getExchangeVault().getAuthorizer();
    }

    function _canPerform(bytes32 actionId, address account) internal view override returns (bool) {
        return _getAuthorizer().canPerform(actionId, account, address(this));
    }
}
