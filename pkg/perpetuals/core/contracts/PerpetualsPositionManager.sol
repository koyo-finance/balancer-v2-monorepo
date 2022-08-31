// SPDX-License-Identifier: MIT

pragma solidity ^0.7.0;

import { PerpetualsBasePositionManager } from "./base/PerpetualsBasePositionManager.sol";
import { IPerpetualsRouter } from "@koyofinance/contracts-interfaces/contracts/perpetuals/core/IPerpetualsRouter.sol";
import { IPerpetualsVault } from "@koyofinance/contracts-interfaces/contracts/perpetuals/core/IPerpetualsVault.sol";
// solhint-disable-next-line max-line-length
import { IPerpetualsOrderBook } from "@koyofinance/contracts-interfaces/contracts/perpetuals/core/IPerpetualsOrderBook.sol";
// solhint-disable-next-line max-line-length
import { IPerpetualsAbstractVaultController } from "@koyofinance/contracts-interfaces/contracts/perpetuals/control/IPerpetualsAbstractVaultController.sol";
import { IVault as IExchangeVault } from "@koyofinance/contracts-interfaces/contracts/vault/IVault.sol";
import { IERC20 } from "@koyofinance/contracts-interfaces/contracts/solidity-utils/openzeppelin/IERC20.sol";

import { SafeMath } from "@koyofinance/contracts-solidity-utils/contracts/openzeppelin/SafeMath.sol";
import { SafeERC20 } from "@koyofinance/contracts-solidity-utils/contracts/openzeppelin/SafeERC20.sol";

contract PerpetualsPositionManager is PerpetualsBasePositionManager {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    IPerpetualsOrderBook public immutable orderBook;

    bool public inLegacyMode = false;
    bool public shouldValidateIncreaseOrder = true;

    mapping(address => bool) public isOrderKeeper;
    mapping(address => bool) public isPartner;
    mapping(address => bool) public isLiquidator;

    event SetOrderKeeper(address indexed account, bool isActive);
    event SetLiquidator(address indexed account, bool isActive);
    event SetPartner(address account, bool isActive);
    event SetInLegacyMode(bool inLegacyMode);
    event SetShouldValidateIncreaseOrder(bool shouldValidateIncreaseOrder);

    modifier onlyOrderKeeper() {
        require(isOrderKeeper[msg.sender], "PositionManager: forbidden");
        _;
    }

    modifier onlyLiquidator() {
        require(isLiquidator[msg.sender], "PositionManager: forbidden");
        _;
    }

    modifier onlyPartnersOrLegacyMode() {
        require(isPartner[msg.sender] || inLegacyMode, "PositionManager: forbidden");
        _;
    }

    constructor(
        IExchangeVault exchangeVault,
        address _vault,
        address _router,
        address _wNative,
        uint256 _depositFee,
        IPerpetualsOrderBook _orderBook
    ) PerpetualsBasePositionManager(exchangeVault, _vault, _router, _wNative, _depositFee) {
        orderBook = _orderBook;
    }

    function setOrderKeeper(address _account, bool _isActive) external authenticate {
        isOrderKeeper[_account] = _isActive;
        emit SetOrderKeeper(_account, _isActive);
    }

    function setLiquidator(address _account, bool _isActive) external authenticate {
        isLiquidator[_account] = _isActive;
        emit SetLiquidator(_account, _isActive);
    }

    function setPartner(address _account, bool _isActive) external authenticate {
        isPartner[_account] = _isActive;
        emit SetPartner(_account, _isActive);
    }

    function setInLegacyMode(bool _inLegacyMode) external authenticate {
        inLegacyMode = _inLegacyMode;
        emit SetInLegacyMode(_inLegacyMode);
    }

    function setShouldValidateIncreaseOrder(bool _shouldValidateIncreaseOrder) external authenticate {
        shouldValidateIncreaseOrder = _shouldValidateIncreaseOrder;
        emit SetShouldValidateIncreaseOrder(_shouldValidateIncreaseOrder);
    }

    function increasePosition(
        address[] memory _path,
        address _indexToken,
        uint256 _amountIn,
        uint256 _minOut,
        uint256 _sizeDelta,
        bool _isLong,
        uint256 _price
    ) external nonReentrant onlyPartnersOrLegacyMode {
        require(_path.length == 1 || _path.length == 2, "PositionManager: invalid _path.length");

        if (_amountIn > 0) {
            if (_path.length == 1) {
                IPerpetualsRouter(router).pluginTransfer(_path[0], msg.sender, address(this), _amountIn);
            } else {
                IPerpetualsRouter(router).pluginTransfer(_path[0], msg.sender, vault, _amountIn);
                _amountIn = _swap(_path, _minOut, address(this));
            }

            uint256 afterFeeAmount = _collectFees(msg.sender, _path, _amountIn, _indexToken, _isLong, _sizeDelta);
            IERC20(_path[_path.length - 1]).safeTransfer(vault, afterFeeAmount);
        }

        _increasePosition(msg.sender, _path[_path.length - 1], _indexToken, _sizeDelta, _isLong, _price);
    }

    function increasePositionETH(
        address[] memory _path,
        address _indexToken,
        uint256 _minOut,
        uint256 _sizeDelta,
        bool _isLong,
        uint256 _price
    ) external payable nonReentrant onlyPartnersOrLegacyMode {
        require(_path.length == 1 || _path.length == 2, "PositionManager: invalid _path.length");
        require(_path[0] == wNative, "PositionManager: invalid _path");

        if (msg.value > 0) {
            _transferInETH();
            uint256 _amountIn = msg.value;

            if (_path.length > 1) {
                IERC20(wNative).safeTransfer(vault, msg.value);
                _amountIn = _swap(_path, _minOut, address(this));
            }

            uint256 afterFeeAmount = _collectFees(msg.sender, _path, _amountIn, _indexToken, _isLong, _sizeDelta);
            IERC20(_path[_path.length - 1]).safeTransfer(vault, afterFeeAmount);
        }

        _increasePosition(msg.sender, _path[_path.length - 1], _indexToken, _sizeDelta, _isLong, _price);
    }

    function decreasePosition(
        address _collateralToken,
        address _indexToken,
        uint256 _collateralDelta,
        uint256 _sizeDelta,
        bool _isLong,
        address _receiver,
        uint256 _price
    ) external nonReentrant onlyPartnersOrLegacyMode {
        _decreasePosition(
            msg.sender,
            _collateralToken,
            _indexToken,
            _collateralDelta,
            _sizeDelta,
            _isLong,
            _receiver,
            _price
        );
    }

    function decreasePositionETH(
        address _collateralToken,
        address _indexToken,
        uint256 _collateralDelta,
        uint256 _sizeDelta,
        bool _isLong,
        address payable _receiver,
        uint256 _price
    ) external nonReentrant onlyPartnersOrLegacyMode {
        require(_collateralToken == wNative, "PositionManager: invalid _collateralToken");

        uint256 amountOut = _decreasePosition(
            msg.sender,
            _collateralToken,
            _indexToken,
            _collateralDelta,
            _sizeDelta,
            _isLong,
            address(this),
            _price
        );
        _transferOutETH(amountOut, _receiver);
    }

    function decreasePositionAndSwap(
        address[] memory _path,
        address _indexToken,
        uint256 _collateralDelta,
        uint256 _sizeDelta,
        bool _isLong,
        address _receiver,
        uint256 _price,
        uint256 _minOut
    ) external nonReentrant onlyPartnersOrLegacyMode {
        require(_path.length == 2, "PositionManager: invalid _path.length");

        uint256 amount = _decreasePosition(
            msg.sender,
            _path[0],
            _indexToken,
            _collateralDelta,
            _sizeDelta,
            _isLong,
            address(this),
            _price
        );
        IERC20(_path[0]).safeTransfer(vault, amount);
        _swap(_path, _minOut, _receiver);
    }

    function decreasePositionAndSwapETH(
        address[] memory _path,
        address _indexToken,
        uint256 _collateralDelta,
        uint256 _sizeDelta,
        bool _isLong,
        address payable _receiver,
        uint256 _price,
        uint256 _minOut
    ) external nonReentrant onlyPartnersOrLegacyMode {
        require(_path.length == 2, "PositionManager: invalid _path.length");
        require(_path[_path.length - 1] == wNative, "PositionManager: invalid _path");

        uint256 amount = _decreasePosition(
            msg.sender,
            _path[0],
            _indexToken,
            _collateralDelta,
            _sizeDelta,
            _isLong,
            address(this),
            _price
        );
        IERC20(_path[0]).safeTransfer(vault, amount);
        uint256 amountOut = _swap(_path, _minOut, address(this));
        _transferOutETH(amountOut, _receiver);
    }

    function liquidatePosition(
        address _account,
        address _collateralToken,
        address _indexToken,
        bool _isLong,
        address _feeReceiver
    ) external nonReentrant onlyLiquidator {
        address _vault = vault;
        address externalAuthorization = IPerpetualsVault(_vault).gov();

        IPerpetualsAbstractVaultController(externalAuthorization).enableLeverage();
        IPerpetualsVault(_vault).liquidatePosition(_account, _collateralToken, _indexToken, _isLong, _feeReceiver);
        IPerpetualsAbstractVaultController(externalAuthorization).disableLeverage();
    }

    function executeSwapOrder(
        address _account,
        uint256 _orderIndex,
        address payable _feeReceiver
    ) external onlyOrderKeeper {
        orderBook.executeSwapOrder(_account, _orderIndex, _feeReceiver);
    }

    function executeIncreaseOrder(
        address _account,
        uint256 _orderIndex,
        address payable _feeReceiver
    ) external onlyOrderKeeper {
        uint256 sizeDelta = _validateIncreaseOrder(_account, _orderIndex);

        address _vault = vault;
        address externalAuthorization = IPerpetualsVault(_vault).gov();

        IPerpetualsAbstractVaultController(externalAuthorization).enableLeverage();
        orderBook.executeIncreaseOrder(_account, _orderIndex, _feeReceiver);
        IPerpetualsAbstractVaultController(externalAuthorization).disableLeverage();

        _emitIncreasePositionReferral(_account, sizeDelta);
    }

    function executeDecreaseOrder(
        address _account,
        uint256 _orderIndex,
        address payable _feeReceiver
    ) external onlyOrderKeeper {
        address _vault = vault;
        address externalAuthorization = IPerpetualsVault(_vault).gov();

        (
            ,
            ,
            ,
            // _collateralToken
            // _collateralDelta
            // _indexToken
            uint256 _sizeDelta, // _isLong // triggerPrice // triggerAboveThreshold // executionFee
            ,
            ,
            ,

        ) = orderBook.getDecreaseOrder(_account, _orderIndex);

        IPerpetualsAbstractVaultController(externalAuthorization).enableLeverage();
        orderBook.executeDecreaseOrder(_account, _orderIndex, _feeReceiver);
        IPerpetualsAbstractVaultController(externalAuthorization).disableLeverage();

        _emitDecreasePositionReferral(_account, _sizeDelta);
    }

    function _validateIncreaseOrder(address _account, uint256 _orderIndex) internal view returns (uint256) {
        (
            address _purchaseToken,
            uint256 _purchaseTokenAmount,
            address _collateralToken,
            address _indexToken,
            uint256 _sizeDelta,
            bool _isLong, // triggerPrice // triggerAboveThreshold // executionFee
            ,
            ,

        ) = orderBook.getIncreaseOrder(_account, _orderIndex);

        if (!shouldValidateIncreaseOrder) {
            return _sizeDelta;
        }

        // shorts are okay
        if (!_isLong) {
            return _sizeDelta;
        }

        // if the position size is not increasing, this is a collateral deposit
        require(_sizeDelta > 0, "PositionManager: long deposit");

        IPerpetualsVault _vault = IPerpetualsVault(vault);
        (uint256 size, uint256 collateral, , , , , , ) = _vault.getPosition(
            _account,
            _collateralToken,
            _indexToken,
            _isLong
        );

        // if there is no existing position, do not charge a fee
        if (size == 0) {
            return _sizeDelta;
        }

        uint256 nextSize = size.add(_sizeDelta);
        uint256 collateralDelta = _vault.tokenToUsdMin(_purchaseToken, _purchaseTokenAmount);
        uint256 nextCollateral = collateral.add(collateralDelta);

        uint256 prevLeverage = size.mul(BASIS_POINTS_DIVISOR).div(collateral);
        // allow for a maximum of a increasePositionBufferBps decrease
        // since there might be some swap fees taken from the collateral
        uint256 nextLeverageWithBuffer = nextSize.mul(BASIS_POINTS_DIVISOR + increasePositionBufferBps).div(
            nextCollateral
        );

        require(nextLeverageWithBuffer >= prevLeverage, "PositionManager: long leverage decrease");

        return _sizeDelta;
    }
}
