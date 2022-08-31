// SPDX-License-Identifier: MIT

pragma solidity ^0.7.0;

// solhint-disable-next-line max-line-length
import { IPerpetualsBasePositionManager } from "@koyofinance/contracts-interfaces/contracts/perpetuals/core/IPerpetualsBasePositionManager.sol";
import { Authentication } from "@koyofinance/contracts-solidity-utils/contracts/helpers/Authentication.sol";
import { ReentrancyGuard } from "@koyofinance/contracts-solidity-utils/contracts/openzeppelin/ReentrancyGuard.sol";
import { IPerpetualsVault } from "@koyofinance/contracts-interfaces/contracts/perpetuals/core/IPerpetualsVault.sol";
import { IPerpetualsRouter } from "@koyofinance/contracts-interfaces/contracts/perpetuals/core/IPerpetualsRouter.sol";
// solhint-disable-next-line max-line-length
import { IPerpetualsReferralStorage } from "@koyofinance/contracts-interfaces/contracts/perpetuals/referrals/IPerpetualsReferralStorage.sol";
import { IVault as IExchangeVault } from "@koyofinance/contracts-interfaces/contracts/vault/IVault.sol";
// solhint-disable-next-line max-line-length
import { IPerpetualsAbstractVaultController } from "@koyofinance/contracts-interfaces/contracts/perpetuals/control/IPerpetualsAbstractVaultController.sol";
import { IAuthorizer } from "@koyofinance/contracts-interfaces/contracts/vault/IAuthorizer.sol";
import { IERC20 } from "@koyofinance/contracts-interfaces/contracts/solidity-utils/openzeppelin/IERC20.sol";
import { IWETH } from "@koyofinance/contracts-interfaces/contracts/solidity-utils/misc/IWETH.sol";

import { SafeMath } from "@koyofinance/contracts-solidity-utils/contracts/openzeppelin/SafeMath.sol";
import { SafeERC20 } from "@koyofinance/contracts-solidity-utils/contracts/openzeppelin/SafeERC20.sol";
import { Address } from "@koyofinance/contracts-solidity-utils/contracts/openzeppelin/Address.sol";

contract BasePositionManager is IPerpetualsBasePositionManager, Authentication, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using Address for address payable;

    uint256 public constant BASIS_POINTS_DIVISOR = 10000;

    address public vault;
    address public router;
    address public wNative;

    // to prevent using the deposit and withdrawal of collateral as a zero fee swap,
    // there is a small depositFee charged if a collateral deposit results in the decrease
    // of leverage for an existing position
    // increasePositionBufferBps allows for a small amount of decrease of leverage
    uint256 public depositFee;
    uint256 public increasePositionBufferBps = 100;

    address public referralStorage;

    mapping(address => uint256) public feeReserves;

    mapping(address => uint256) public override maxGlobalLongSizes;
    mapping(address => uint256) public override maxGlobalShortSizes;

    IExchangeVault private immutable _exchangeVault;

    event SetDepositFee(uint256 depositFee);
    event SetIncreasePositionBufferBps(uint256 increasePositionBufferBps);
    event SetReferralStorage(address referralStorage);
    event WithdrawFees(address token, address receiver, uint256 amount);

    event SetMaxGlobalSizes(address[] tokens, uint256[] longSizes, uint256[] shortSizes);

    event IncreasePositionReferral(
        address account,
        uint256 sizeDelta,
        uint256 marginFeeBasisPoints,
        bytes32 referralCode,
        address referrer
    );

    event DecreasePositionReferral(
        address account,
        uint256 sizeDelta,
        uint256 marginFeeBasisPoints,
        bytes32 referralCode,
        address referrer
    );

    constructor(
        IExchangeVault exchangeVault,
        address _vault,
        address _router,
        address _wNative,
        uint256 _depositFee
    ) Authentication(bytes32(uint256(address(this)))) {
        _exchangeVault = exchangeVault;
        vault = _vault;
        router = _router;
        wNative = _wNative;
        depositFee = _depositFee;
    }

    receive() external payable {
        require(msg.sender == wNative, "BasePositionManager: invalid sender");
    }

    function setDepositFee(uint256 _depositFee) external authenticate {
        depositFee = _depositFee;
        emit SetDepositFee(_depositFee);
    }

    function setIncreasePositionBufferBps(uint256 _increasePositionBufferBps) external authenticate {
        increasePositionBufferBps = _increasePositionBufferBps;
        emit SetIncreasePositionBufferBps(_increasePositionBufferBps);
    }

    function setReferralStorage(address _referralStorage) external authenticate {
        referralStorage = _referralStorage;
        emit SetReferralStorage(_referralStorage);
    }

    function setMaxGlobalSizes(
        address[] memory _tokens,
        uint256[] memory _longSizes,
        uint256[] memory _shortSizes
    ) external authenticate {
        for (uint256 i = 0; i < _tokens.length; i++) {
            address token = _tokens[i];
            maxGlobalLongSizes[token] = _longSizes[i];
            maxGlobalShortSizes[token] = _shortSizes[i];
        }

        emit SetMaxGlobalSizes(_tokens, _longSizes, _shortSizes);
    }

    function withdrawFees(address _token, address _receiver) external authenticate {
        uint256 amount = feeReserves[_token];
        if (amount == 0) {
            return;
        }

        feeReserves[_token] = 0;
        IERC20(_token).safeTransfer(_receiver, amount);

        emit WithdrawFees(_token, _receiver, amount);
    }

    function approve(
        address _token,
        address _spender,
        uint256 _amount
    ) external authenticate {
        IERC20(_token).approve(_spender, _amount);
    }

    function sendValue(address payable _receiver, uint256 _amount) external authenticate {
        _receiver.sendValue(_amount);
    }

    function getExchangeVault() public view returns (IExchangeVault) {
        return _exchangeVault;
    }

    function _increasePosition(
        address _account,
        address _collateralToken,
        address _indexToken,
        uint256 _sizeDelta,
        bool _isLong,
        uint256 _price
    ) internal {
        address _vault = vault;

        if (_isLong) {
            require(
                IPerpetualsVault(_vault).getMaxPrice(_indexToken) <= _price,
                "BasePositionManager: mark price higher than limit"
            );
        } else {
            require(
                IPerpetualsVault(_vault).getMinPrice(_indexToken) >= _price,
                "BasePositionManager: mark price lower than limit"
            );
        }

        if (_isLong) {
            uint256 maxGlobalLongSize = maxGlobalLongSizes[_indexToken];
            if (
                maxGlobalLongSize > 0 &&
                IPerpetualsVault(_vault).guaranteedUsd(_indexToken).add(_sizeDelta) > maxGlobalLongSize
            ) {
                revert("BasePositionManager: max global longs exceeded");
            }
        } else {
            uint256 maxGlobalShortSize = maxGlobalShortSizes[_indexToken];
            if (
                maxGlobalShortSize > 0 &&
                IPerpetualsVault(_vault).globalShortSizes(_indexToken).add(_sizeDelta) > maxGlobalShortSize
            ) {
                revert("BasePositionManager: max global shorts exceeded");
            }
        }

        address externalAuthorization = IPerpetualsVault(_vault).gov();

        IPerpetualsAbstractVaultController(externalAuthorization).enableLeverage();
        IPerpetualsRouter(router).pluginIncreasePosition(_account, _collateralToken, _indexToken, _sizeDelta, _isLong);
        IPerpetualsAbstractVaultController(externalAuthorization).disableLeverage();

        _emitIncreasePositionReferral(_account, _sizeDelta);
    }

    function _decreasePosition(
        address _account,
        address _collateralToken,
        address _indexToken,
        uint256 _collateralDelta,
        uint256 _sizeDelta,
        bool _isLong,
        address _receiver,
        uint256 _price
    ) internal returns (uint256) {
        address _vault = vault;

        if (_isLong) {
            require(
                IPerpetualsVault(_vault).getMinPrice(_indexToken) >= _price,
                "BasePositionManager: mark price lower than limit"
            );
        } else {
            require(
                IPerpetualsVault(_vault).getMaxPrice(_indexToken) <= _price,
                "BasePositionManager: mark price higher than limit"
            );
        }

        address externalAuthorization = IPerpetualsVault(_vault).gov();

        IPerpetualsAbstractVaultController(externalAuthorization).enableLeverage();
        uint256 amountOut = IPerpetualsRouter(router).pluginDecreasePosition(
            _account,
            _collateralToken,
            _indexToken,
            _collateralDelta,
            _sizeDelta,
            _isLong,
            _receiver
        );
        IPerpetualsAbstractVaultController(externalAuthorization).disableLeverage();

        _emitDecreasePositionReferral(_account, _sizeDelta);

        return amountOut;
    }

    function _emitIncreasePositionReferral(address _account, uint256 _sizeDelta) internal {
        address _referralStorage = referralStorage;
        if (_referralStorage == address(0)) {
            return;
        }

        (bytes32 referralCode, address referrer) = IPerpetualsReferralStorage(_referralStorage).getTraderReferralInfo(
            _account
        );
        emit IncreasePositionReferral(
            _account,
            _sizeDelta,
            IPerpetualsVault(vault).marginFeeBasisPoints(),
            referralCode,
            referrer
        );
    }

    function _emitDecreasePositionReferral(address _account, uint256 _sizeDelta) internal {
        address _referralStorage = referralStorage;
        if (_referralStorage == address(0)) {
            return;
        }

        (bytes32 referralCode, address referrer) = IPerpetualsReferralStorage(_referralStorage).getTraderReferralInfo(
            _account
        );

        if (referralCode == bytes32(0)) {
            return;
        }

        emit DecreasePositionReferral(
            _account,
            _sizeDelta,
            IPerpetualsVault(vault).marginFeeBasisPoints(),
            referralCode,
            referrer
        );
    }

    function _swap(
        address[] memory _path,
        uint256 _minOut,
        address _receiver
    ) internal returns (uint256) {
        if (_path.length == 2) {
            return _vaultSwap(_path[0], _path[1], _minOut, _receiver);
        }
        revert("BasePositionManager: invalid _path.length");
    }

    function _vaultSwap(
        address _tokenIn,
        address _tokenOut,
        uint256 _minOut,
        address _receiver
    ) internal returns (uint256) {
        uint256 amountOut = IPerpetualsVault(vault).swap(_tokenIn, _tokenOut, _receiver);
        require(amountOut >= _minOut, "BasePositionManager: insufficient amountOut");
        return amountOut;
    }

    function _transferInETH() internal {
        if (msg.value != 0) {
            IWETH(wNative).deposit{ value: msg.value }();
        }
    }

    function _transferOutETH(uint256 _amountOut, address payable _receiver) internal {
        IWETH(wNative).withdraw(_amountOut);
        _receiver.sendValue(_amountOut);
    }

    function _transferOutETHWithGasLimit(uint256 _amountOut, address payable _receiver) internal {
        IWETH(wNative).withdraw(_amountOut);
        _receiver.transfer(_amountOut);
    }

    function _collectFees(
        address _account,
        address[] memory _path,
        uint256 _amountIn,
        address _indexToken,
        bool _isLong,
        uint256 _sizeDelta
    ) internal returns (uint256) {
        bool shouldDeductFee = _shouldDeductFee(_account, _path, _amountIn, _indexToken, _isLong, _sizeDelta);

        if (shouldDeductFee) {
            uint256 afterFeeAmount = _amountIn.mul(BASIS_POINTS_DIVISOR.sub(depositFee)).div(BASIS_POINTS_DIVISOR);
            uint256 feeAmount = _amountIn.sub(afterFeeAmount);
            address feeToken = _path[_path.length - 1];
            feeReserves[feeToken] = feeReserves[feeToken].add(feeAmount);
            return afterFeeAmount;
        }

        return _amountIn;
    }

    function _shouldDeductFee(
        address _account,
        address[] memory _path,
        uint256 _amountIn,
        address _indexToken,
        bool _isLong,
        uint256 _sizeDelta
    ) internal view returns (bool) {
        // if the position is a short, do not charge a fee
        if (!_isLong) {
            return false;
        }

        // if the position size is not increasing, this is a collateral deposit
        if (_sizeDelta == 0) {
            return true;
        }

        address collateralToken = _path[_path.length - 1];

        IPerpetualsVault _vault = IPerpetualsVault(vault);
        (uint256 size, uint256 collateral, , , , , , ) = _vault.getPosition(
            _account,
            collateralToken,
            _indexToken,
            _isLong
        );

        // if there is no existing position, do not charge a fee
        if (size == 0) {
            return false;
        }

        uint256 nextSize = size.add(_sizeDelta);
        uint256 collateralDelta = _vault.tokenToUsdMin(collateralToken, _amountIn);
        uint256 nextCollateral = collateral.add(collateralDelta);

        uint256 prevLeverage = size.mul(BASIS_POINTS_DIVISOR).div(collateral);
        // Allow for a maximum of a increasePositionBufferBps decrease
        // since there might be some swap fees taken from the collateral
        uint256 nextLeverage = nextSize.mul(BASIS_POINTS_DIVISOR + increasePositionBufferBps).div(nextCollateral);

        // deduct a fee if the leverage is decreased
        return nextLeverage < prevLeverage;
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
