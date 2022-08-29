// SPDX-License-Identifier: MIT

pragma solidity ^0.7.0;

// solhint-disable-next-line max-line-length
import { IPerpetualsVaultUtils } from "@koyofinance/contracts-interfaces/contracts/perpetuals/core/IPerpetualsVaultUtils.sol";
import { Authentication } from "@koyofinance/contracts-solidity-utils/contracts/helpers/Authentication.sol";
import { IPerpetualsVault } from "@koyofinance/contracts-interfaces/contracts/perpetuals/core/IPerpetualsVault.sol";
import { IVault as IExchangeVault } from "@koyofinance/contracts-interfaces/contracts/vault/IVault.sol";
import { IAuthorizer } from "@koyofinance/contracts-interfaces/contracts/vault/IAuthorizer.sol";
import { IERC20 } from "@koyofinance/contracts-interfaces/contracts/solidity-utils/openzeppelin/IERC20.sol";

// solhint-disable-next-line max-line-length
import { Errors, _require, _revert } from "@koyofinance/contracts-interfaces/contracts/solidity-utils/helpers/KoyoErrors.sol";
import { SafeMath } from "@koyofinance/contracts-solidity-utils/contracts/openzeppelin/SafeMath.sol";

contract PerpetualsVaultUtils is IPerpetualsVaultUtils, Authentication {
    using SafeMath for uint256;

    struct Position {
        uint256 size;
        uint256 collateral;
        uint256 averagePrice;
        uint256 entryFundingRate;
        uint256 reserveAmount;
        int256 realisedPnl;
        uint256 lastIncreasedTime;
    }

    uint256 public constant BASIS_POINTS_DIVISOR = 10000;
    uint256 public constant FUNDING_RATE_PRECISION = 1000000;

    uint256 public constant MAX_WITHDRAWAL_COOLDOWN_DURATION = 30 days;
    uint256 public constant MIN_LEVERAGE_CAP = 10 * BASIS_POINTS_DIVISOR;

    IPerpetualsVault public immutable vault;

    uint256 public withdrawalCooldownDuration = 0;
    uint256 public minLeverage = 25000; // 2.5x

    IExchangeVault private immutable _exchangeVault;

    constructor(IExchangeVault exchangeVault, IPerpetualsVault _vault) Authentication(bytes32(uint256(address(this)))) {
        _exchangeVault = exchangeVault;
        vault = _vault;
    }

    function setWithdrawalCooldownDuration(uint256 _withdrawalCooldownDuration) external authenticate {
        _require(
            _withdrawalCooldownDuration <= MAX_WITHDRAWAL_COOLDOWN_DURATION,
            Errors.PERPETUALS_VAULT_UTILS_WITHDRAWAL_COOLDOWN_DURATION_MAX
        );
        withdrawalCooldownDuration = _withdrawalCooldownDuration;
    }

    function setMinLeverage(uint256 _minLeverage) external authenticate {
        _require(_minLeverage <= MIN_LEVERAGE_CAP, Errors.PERPETUALS_VAULT_UTILS_MIN_LEVERAGE_CAP_EXCEEDED);
        minLeverage = _minLeverage;
    }

    function updateCumulativeFundingRate(
        address, /* _collateralToken */
        address /* _indexToken */
    ) public pure override returns (bool) {
        return true;
    }

    function validateIncreasePosition(
        address _account,
        address _collateralToken,
        address _indexToken,
        uint256 _sizeDelta,
        bool _isLong
    ) external view override {
        Position memory position = getPosition(_account, _collateralToken, _indexToken, _isLong);

        uint256 prevBalance = vault.tokenBalances(_collateralToken);
        uint256 nextBalance = IERC20(_collateralToken).balanceOf(address(vault));
        uint256 collateralDelta = nextBalance.sub(prevBalance);
        uint256 collateralDeltaUsd = vault.tokenToUsdMin(_collateralToken, collateralDelta);

        uint256 nextSize = position.size.add(_sizeDelta);
        uint256 nextCollateral = position.collateral.add(collateralDeltaUsd);

        if (nextCollateral > 0) {
            uint256 nextLeverage = nextSize.mul(BASIS_POINTS_DIVISOR + 1).div(nextCollateral);
            _require(nextLeverage >= minLeverage, Errors.PERPETUALS_VAULT_UTILS_LEVERAGE_LOW);
        }
    }

    function validateDecreasePosition(
        address _account,
        address _collateralToken,
        address _indexToken,
        uint256 _collateralDelta,
        uint256 _sizeDelta,
        bool _isLong,
        address /* _receiver */
    ) external view override {
        Position memory position = getPosition(_account, _collateralToken, _indexToken, _isLong);

        if (position.size > 0 && _sizeDelta < position.size) {
            // solhint-disable-next-line not-rely-on-time
            bool isCooldown = position.lastIncreasedTime + withdrawalCooldownDuration > block.timestamp;

            uint256 prevLeverage = position.size.mul(BASIS_POINTS_DIVISOR).div(position.collateral);
            uint256 nextSize = position.size.sub(_sizeDelta);
            uint256 nextCollateral = position.collateral.sub(_collateralDelta);
            // use BASIS_POINTS_DIVISOR - 1 to allow for a 0.01% decrease in leverage
            // even if within the cooldown duration
            uint256 nextLeverage = nextSize.mul(BASIS_POINTS_DIVISOR - 1).div(nextCollateral);

            _require(nextLeverage >= minLeverage, Errors.PERPETUALS_VAULT_UTILS_LEVERAGE_LOW);

            bool isWithdrawal = nextLeverage > prevLeverage;

            if (isCooldown && isWithdrawal) {
                _revert(Errors.PERPETUALS_VAULT_UTILS_COOLDOWN_DURATION_NOT_PASSED);
            }
        }
    }


    // solhint-disable-next-line private-vars-leading-underscore
    function getPosition(
        address _account,
        address _collateralToken,
        address _indexToken,
        bool _isLong
    ) internal view returns (Position memory) {
        IPerpetualsVault _vault = vault;
        Position memory position;
        {
            (
                uint256 size,
                uint256 collateral,
                uint256 averagePrice,
                uint256 entryFundingRate, /* reserveAmount */ /* realisedPnl */ /* hasProfit */
                ,
                ,
                ,
                uint256 lastIncreasedTime
            ) = _vault.getPosition(_account, _collateralToken, _indexToken, _isLong);
            position.size = size;
            position.collateral = collateral;
            position.averagePrice = averagePrice;
            position.entryFundingRate = entryFundingRate;
            position.lastIncreasedTime = lastIncreasedTime;
        }
        return position;
    }

    function validateLiquidation(
        address _account,
        address _collateralToken,
        address _indexToken,
        bool _isLong,
        bool _raise
    ) public view override returns (uint256, uint256) {
        Position memory position = getPosition(_account, _collateralToken, _indexToken, _isLong);
        IPerpetualsVault _vault = vault;

        (bool hasProfit, uint256 delta) = _vault.getDelta(
            _indexToken,
            position.size,
            position.averagePrice,
            _isLong,
            position.lastIncreasedTime
        );
        uint256 marginFees = getFundingFee(
            _account,
            _collateralToken,
            _indexToken,
            _isLong,
            position.size,
            position.entryFundingRate
        );
        marginFees = marginFees.add(getPositionFee(_account, _collateralToken, _indexToken, _isLong, position.size));

        if (!hasProfit && position.collateral < delta) {
            if (_raise) {
                _revert(Errors.PERPETUALS_VAULT_UTILS_LOSSES_COLLATERAL_EXCEED);
            }
            return (1, marginFees);
        }

        uint256 remainingCollateral = position.collateral;
        if (!hasProfit) {
            remainingCollateral = position.collateral.sub(delta);
        }

        if (remainingCollateral < marginFees) {
            if (_raise) {
                _revert(Errors.PERPETUALS_VAULT_UTILS_FEES_COLLATERAL_EXCEED);
            }
            // cap the fees to the remainingCollateral
            return (1, remainingCollateral);
        }

        if (remainingCollateral < marginFees.add(_vault.liquidationFeeUsd())) {
            if (_raise) {
                _revert(Errors.PERPETUALS_VAULT_UTILS_LIQUIDATION_FEES_COLLATERAL_EXCEED);
            }
            return (1, marginFees);
        }

        if (remainingCollateral.mul(_vault.maxLeverage()) < position.size.mul(BASIS_POINTS_DIVISOR)) {
            if (_raise) {
                _revert(Errors.PERPETUALS_VAULT_UTILS_MAX_LEVERAGE_EXCEEDED);
            }
            return (2, marginFees);
        }

        return (0, marginFees);
    }

    function getEntryFundingRate(
        address _collateralToken,
        address, /* _indexToken */
        bool /* _isLong */
    ) public view override returns (uint256) {
        return vault.cumulativeFundingRates(_collateralToken);
    }

    function getPositionFee(
        address, /* _account */
        address, /* _collateralToken */
        address, /* _indexToken */
        bool, /* _isLong */
        uint256 _sizeDelta
    ) public view override returns (uint256) {
        if (_sizeDelta == 0) {
            return 0;
        }
        uint256 afterFeeUsd = _sizeDelta.mul(BASIS_POINTS_DIVISOR.sub(vault.marginFeeBasisPoints())).div(
            BASIS_POINTS_DIVISOR
        );
        return _sizeDelta.sub(afterFeeUsd);
    }

    function getFundingFee(
        address, /* _account */
        address _collateralToken,
        address, /* _indexToken */
        bool, /* _isLong */
        uint256 _size,
        uint256 _entryFundingRate
    ) public view override returns (uint256) {
        if (_size == 0) {
            return 0;
        }

        uint256 fundingRate = vault.cumulativeFundingRates(_collateralToken).sub(_entryFundingRate);
        if (fundingRate == 0) {
            return 0;
        }

        return _size.mul(fundingRate).div(FUNDING_RATE_PRECISION);
    }

    function getBuyUsdgFeeBasisPoints(address _token, uint256 _usdgAmount) public view override returns (uint256) {
        return getFeeBasisPoints(_token, _usdgAmount, vault.mintBurnFeeBasisPoints(), vault.taxBasisPoints(), true);
    }

    function getSellUsdgFeeBasisPoints(address _token, uint256 _usdgAmount) public view override returns (uint256) {
        return getFeeBasisPoints(_token, _usdgAmount, vault.mintBurnFeeBasisPoints(), vault.taxBasisPoints(), false);
    }

    function getSwapFeeBasisPoints(
        address _tokenIn,
        address _tokenOut,
        uint256 _usdgAmount
    ) public view override returns (uint256) {
        bool isStableSwap = vault.stableTokens(_tokenIn) && vault.stableTokens(_tokenOut);
        uint256 baseBps = isStableSwap ? vault.stableSwapFeeBasisPoints() : vault.swapFeeBasisPoints();
        uint256 taxBps = isStableSwap ? vault.stableTaxBasisPoints() : vault.taxBasisPoints();
        uint256 feesBasisPoints0 = getFeeBasisPoints(_tokenIn, _usdgAmount, baseBps, taxBps, true);
        uint256 feesBasisPoints1 = getFeeBasisPoints(_tokenOut, _usdgAmount, baseBps, taxBps, false);
        // use the higher of the two fee basis points
        return feesBasisPoints0 > feesBasisPoints1 ? feesBasisPoints0 : feesBasisPoints1;
    }

    // cases to consider
    // 1. initialAmount is far from targetAmount, action increases balance slightly => high rebate
    // 2. initialAmount is far from targetAmount, action increases balance largely => high rebate
    // 3. initialAmount is close to targetAmount, action increases balance slightly => low rebate
    // 4. initialAmount is far from targetAmount, action reduces balance slightly => high tax
    // 5. initialAmount is far from targetAmount, action reduces balance largely => high tax
    // 6. initialAmount is close to targetAmount, action reduces balance largely => low tax
    // 7. initialAmount is above targetAmount, nextAmount is below targetAmount and vice versa
    // 8. a large swap should have similar fees as the same trade split into multiple smaller swaps
    function getFeeBasisPoints(
        address _token,
        uint256 _usdgDelta,
        uint256 _feeBasisPoints,
        uint256 _taxBasisPoints,
        bool _increment
    ) public view override returns (uint256) {
        if (!vault.hasDynamicFees()) {
            return _feeBasisPoints;
        }

        uint256 initialAmount = vault.usdgAmounts(_token);
        uint256 nextAmount = initialAmount.add(_usdgDelta);
        if (!_increment) {
            nextAmount = _usdgDelta > initialAmount ? 0 : initialAmount.sub(_usdgDelta);
        }

        uint256 targetAmount = vault.getTargetUsdgAmount(_token);
        if (targetAmount == 0) {
            return _feeBasisPoints;
        }

        uint256 initialDiff = initialAmount > targetAmount
            ? initialAmount.sub(targetAmount)
            : targetAmount.sub(initialAmount);
        uint256 nextDiff = nextAmount > targetAmount ? nextAmount.sub(targetAmount) : targetAmount.sub(nextAmount);

        // action improves relative asset balance
        if (nextDiff < initialDiff) {
            uint256 rebateBps = _taxBasisPoints.mul(initialDiff).div(targetAmount);
            return rebateBps > _feeBasisPoints ? 0 : _feeBasisPoints.sub(rebateBps);
        }

        uint256 averageDiff = initialDiff.add(nextDiff).div(2);
        if (averageDiff > targetAmount) {
            averageDiff = targetAmount;
        }
        uint256 taxBps = _taxBasisPoints.mul(averageDiff).div(targetAmount);
        return _feeBasisPoints.add(taxBps);
    }

    function getExchangeVault() public view returns (IExchangeVault) {
        return _exchangeVault;
    }

    function _getAuthorizer() internal view returns (IAuthorizer) {
        // Access control management is delegated to the Vault's Authorizer. This lets Kōyō Governance manage which
        // accounts can call permissioned functions.
        return getExchangeVault().getAuthorizer();
    }

    function _canPerform(bytes32 actionId, address account) internal view override returns (bool) {
        return _getAuthorizer().canPerform(actionId, account, address(this));
    }
}
