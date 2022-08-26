// SPDX-License-Identifier: MIT

pragma solidity ^0.7.0;

import { Authentication } from "@koyofinance/contracts-solidity-utils/contracts/helpers/Authentication.sol";
import { IPerpetualsRouter } from "@koyofinance/contracts-interfaces/contracts/perpetuals/core/IPerpetualsRouter.sol";
import { IPerpetualsVault } from "@koyofinance/contracts-interfaces/contracts/perpetuals/core/IPerpetualsVault.sol";
import { IVault as IExchangeVault } from "@koyofinance/contracts-interfaces/contracts/vault/IVault.sol";
import { IAuthorizer } from "@koyofinance/contracts-interfaces/contracts/vault/IAuthorizer.sol";
import { IERC20 } from "@koyofinance/contracts-interfaces/contracts/solidity-utils/openzeppelin/IERC20.sol";
import { IWETH } from "@koyofinance/contracts-interfaces/contracts/solidity-utils/misc/IWETH.sol";

// solhint-disable-next-line max-line-length
import { Errors, _require, _revert } from "@koyofinance/contracts-interfaces/contracts/solidity-utils/helpers/KoyoErrors.sol";
import { SafeMath } from "@koyofinance/contracts-solidity-utils/contracts/openzeppelin/SafeMath.sol";
import { SafeERC20 } from "@koyofinance/contracts-solidity-utils/contracts/openzeppelin/SafeERC20.sol";
import { Address } from "@koyofinance/contracts-solidity-utils/contracts/openzeppelin/Address.sol";

contract PerpetualsRouter is IPerpetualsRouter, Authentication {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using Address for address payable;

    IWETH public immutable wNative;
    address public immutable usdg;
    IPerpetualsVault public immutable perpetualsVault;

    mapping(address => bool) public plugins;
    mapping(address => mapping(address => bool)) public approvedPlugins;

    IExchangeVault private immutable _exchangeVault;

    event Swap(address account, address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOut);

    constructor(
        IExchangeVault exchangeVault,
        IPerpetualsVault _perpetualsVault,
        address _usdg,
        IWETH _wNative
    ) Authentication(bytes32(uint256(address(this)))) {
        _exchangeVault = exchangeVault;
        perpetualsVault = _perpetualsVault;
        usdg = _usdg;
        wNative = _wNative;
    }

    receive() external payable {
        _require(msg.sender == address(wNative), Errors.PERPETUALS_VAULT_ROUTER_SENDER_NOT_W_NATIVE);
    }

    function addPlugin(address _plugin) external override authenticate {
        plugins[_plugin] = true;
    }

    function removePlugin(address _plugin) external authenticate {
        plugins[_plugin] = false;
    }

    function approvePlugin(address _plugin) external {
        approvedPlugins[msg.sender][_plugin] = true;
    }

    function denyPlugin(address _plugin) external {
        approvedPlugins[msg.sender][_plugin] = false;
    }

    function pluginTransfer(
        address _token,
        address _account,
        address _receiver,
        uint256 _amount
    ) external override {
        _validatePlugin(_account);
        IERC20(_token).safeTransferFrom(_account, _receiver, _amount);
    }

    function pluginIncreasePosition(
        address _account,
        address _collateralToken,
        address _indexToken,
        uint256 _sizeDelta,
        bool _isLong
    ) external override {
        _validatePlugin(_account);
        perpetualsVault.increasePosition(
            _account,
            _collateralToken,
            _indexToken,
            _sizeDelta,
            _isLong
        );
    }

    function pluginDecreasePosition(
        address _account,
        address _collateralToken,
        address _indexToken,
        uint256 _collateralDelta,
        uint256 _sizeDelta,
        bool _isLong,
        address _receiver
    ) external override returns (uint256) {
        _validatePlugin(_account);
        return
            perpetualsVault.decreasePosition(
                _account,
                _collateralToken,
                _indexToken,
                _collateralDelta,
                _sizeDelta,
                _isLong,
                _receiver
            );
    }

    function directPoolDeposit(address _token, uint256 _amount) external {
        IERC20(_token).safeTransferFrom(_sender(), address(perpetualsVault), _amount);
        perpetualsVault.directPoolDeposit(_token);
    }

    function swap(
        address[] memory _path,
        uint256 _amountIn,
        uint256 _minOut,
        address _receiver
    ) public override {
        IERC20(_path[0]).safeTransferFrom(_sender(), address(perpetualsVault), _amountIn);
        uint256 amountOut = _swap(_path, _minOut, _receiver);
        emit Swap(msg.sender, _path[0], _path[_path.length - 1], _amountIn, amountOut);
    }

    function swapETHToTokens(
        address[] memory _path,
        uint256 _minOut,
        address _receiver
    ) external payable {
        _require(_path[0] == address(wNative), Errors.PERPETUALS_VAULT_ROUTER__PATH_INVALID);
        _transferETHToVault();
        uint256 amountOut = _swap(_path, _minOut, _receiver);
        emit Swap(msg.sender, _path[0], _path[_path.length - 1], msg.value, amountOut);
    }

    function swapTokensToETH(
        address[] memory _path,
        uint256 _amountIn,
        uint256 _minOut,
        address payable _receiver
    ) external {
        _require(_path[_path.length - 1] == address(wNative), Errors.PERPETUALS_VAULT_ROUTER__PATH_INVALID);
        IERC20(_path[0]).safeTransferFrom(_sender(), address(perpetualsVault), _amountIn);
        uint256 amountOut = _swap(_path, _minOut, address(this));
        _transferOutETH(amountOut, _receiver);
        emit Swap(msg.sender, _path[0], _path[_path.length - 1], _amountIn, amountOut);
    }

    function increasePosition(
        address[] memory _path,
        address _indexToken,
        uint256 _amountIn,
        uint256 _minOut,
        uint256 _sizeDelta,
        bool _isLong,
        uint256 _price
    ) external {
        if (_amountIn > 0) {
            IERC20(_path[0]).safeTransferFrom(_sender(), address(perpetualsVault), _amountIn);
        }
        if (_path.length > 1 && _amountIn > 0) {
            uint256 amountOut = _swap(_path, _minOut, address(this));
            IERC20(_path[_path.length - 1]).safeTransfer(address(perpetualsVault), amountOut);
        }
        _increasePosition(_path[_path.length - 1], _indexToken, _sizeDelta, _isLong, _price);
    }

    function increasePositionETH(
        address[] memory _path,
        address _indexToken,
        uint256 _minOut,
        uint256 _sizeDelta,
        bool _isLong,
        uint256 _price
    ) external payable {
        _require(_path[0] == address(wNative), Errors.PERPETUALS_VAULT_ROUTER__PATH_INVALID);
        if (msg.value > 0) {
            _transferETHToVault();
        }
        if (_path.length > 1 && msg.value > 0) {
            uint256 amountOut = _swap(_path, _minOut, address(this));
            IERC20(_path[_path.length - 1]).safeTransfer(address(perpetualsVault), amountOut);
        }
        _increasePosition(_path[_path.length - 1], _indexToken, _sizeDelta, _isLong, _price);
    }

    function decreasePosition(
        address _collateralToken,
        address _indexToken,
        uint256 _collateralDelta,
        uint256 _sizeDelta,
        bool _isLong,
        address _receiver,
        uint256 _price
    ) external {
        _decreasePosition(_collateralToken, _indexToken, _collateralDelta, _sizeDelta, _isLong, _receiver, _price);
    }

    function decreasePositionETH(
        address _collateralToken,
        address _indexToken,
        uint256 _collateralDelta,
        uint256 _sizeDelta,
        bool _isLong,
        address payable _receiver,
        uint256 _price
    ) external {
        uint256 amountOut = _decreasePosition(
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
    ) external {
        uint256 amount = _decreasePosition(
            _path[0],
            _indexToken,
            _collateralDelta,
            _sizeDelta,
            _isLong,
            address(this),
            _price
        );
        IERC20(_path[0]).safeTransfer(address(perpetualsVault), amount);
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
    ) external {
        _require(_path[_path.length - 1] == address(wNative), Errors.PERPETUALS_VAULT_ROUTER__PATH_INVALID);
        uint256 amount = _decreasePosition(
            _path[0],
            _indexToken,
            _collateralDelta,
            _sizeDelta,
            _isLong,
            address(this),
            _price
        );
        IERC20(_path[0]).safeTransfer(address(perpetualsVault), amount);
        uint256 amountOut = _swap(_path, _minOut, address(this));
        _transferOutETH(amountOut, _receiver);
    }

    function getExchangeVault() public view returns (IExchangeVault) {
        return _exchangeVault;
    }

    function _increasePosition(
        address _collateralToken,
        address _indexToken,
        uint256 _sizeDelta,
        bool _isLong,
        uint256 _price
    ) private {
        if (_isLong) {
            _require(
                perpetualsVault.getMaxPrice(_indexToken) <= _price,
                Errors.PERPETUALS_VAULT_ROUTER_MARK_PRICE_HIGHER_LIMIT
            );
        } else {
            _require(
                perpetualsVault.getMinPrice(_indexToken) >= _price,
                Errors.PERPETUALS_VAULT_ROUTER_MARK_PRICE_LOWER_LIMIT
            );
        }

        perpetualsVault.increasePosition(
            _sender(),
            _collateralToken,
            _indexToken,
            _sizeDelta,
            _isLong
        );
    }

    function _decreasePosition(
        address _collateralToken,
        address _indexToken,
        uint256 _collateralDelta,
        uint256 _sizeDelta,
        bool _isLong,
        address _receiver,
        uint256 _price
    ) private returns (uint256) {
        if (_isLong) {
            _require(
                perpetualsVault.getMinPrice(_indexToken) >= _price,
                Errors.PERPETUALS_VAULT_ROUTER_MARK_PRICE_LOWER_LIMIT
            );
        } else {
            _require(
                perpetualsVault.getMaxPrice(_indexToken) <= _price,
                Errors.PERPETUALS_VAULT_ROUTER_MARK_PRICE_HIGHER_LIMIT
            );
        }

        return
            perpetualsVault.decreasePosition(
                _sender(),
                _collateralToken,
                _indexToken,
                _collateralDelta,
                _sizeDelta,
                _isLong,
                _receiver
            );
    }

    function _transferETHToVault() private {
        wNative.deposit{ value: msg.value }();
        IERC20(wNative).safeTransfer(address(perpetualsVault), msg.value);
    }

    function _transferOutETH(uint256 _amountOut, address payable _receiver) private {
        wNative.withdraw(_amountOut);
        _receiver.sendValue(_amountOut);
    }

    function _swap(
        address[] memory _path,
        uint256 _minOut,
        address _receiver
    ) private returns (uint256 amountOut) {
        if (_path.length == 2) {
            amountOut = _perpetualsVaultSwap(_path[0], _path[1], _minOut, _receiver);
        }
        if (_path.length == 3) {
            uint256 midOut = _perpetualsVaultSwap(_path[0], _path[1], 0, address(this));
            IERC20(_path[1]).safeTransfer(address(perpetualsVault), midOut);
            amountOut = _perpetualsVaultSwap(_path[1], _path[2], _minOut, _receiver);
        }

        _revert(Errors.PERPETUALS_VAULT_ROUTER__PATH_LENGTH_INVALID);
    }

    function _perpetualsVaultSwap(
        address _tokenIn,
        address _tokenOut,
        uint256 _minOut,
        address _receiver
    ) private returns (uint256) {
        uint256 amountOut;

        if (_tokenOut == usdg) {
            // buyUSDG
            amountOut = perpetualsVault.buyUSDG(_tokenIn, _receiver);
        } else if (_tokenIn == usdg) {
            // sellUSDG
            amountOut = perpetualsVault.sellUSDG(_tokenOut, _receiver);
        } else {
            // swap
            amountOut = perpetualsVault.swap(_tokenIn, _tokenOut, _receiver);
        }

        _require(amountOut >= _minOut, Errors.PERPETUALS_VAULT_ROUTER_AMOUNT_OUT_INSUFFICIENT);
        return amountOut;
    }

    function _sender() private view returns (address) {
        return msg.sender;
    }

    function _validatePlugin(address _account) private view {
        _require(plugins[msg.sender], Errors.PERPETUALS_VAULT_ROUTER_PLUGIN_INVALID);
        _require(approvedPlugins[_account][msg.sender], Errors.PERPETUALS_VAULT_ROUTER_PLUGIN_NOT_APPROVED);
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
