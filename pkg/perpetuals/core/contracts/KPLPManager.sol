// SPDX-License-Identifier: MIT

pragma solidity ^0.7.0;

import { IKPLPManager } from "@koyofinance/contracts-interfaces/contracts/perpetuals/core/IKPLPManager.sol";
import { Authentication } from "@koyofinance/contracts-solidity-utils/contracts/helpers/Authentication.sol";
import { ReentrancyGuard } from "@koyofinance/contracts-solidity-utils/contracts/openzeppelin/ReentrancyGuard.sol";
import { IPerpetualsVault } from "@koyofinance/contracts-interfaces/contracts/perpetuals/core/IPerpetualsVault.sol";
import { IVault as IExchangeVault } from "@koyofinance/contracts-interfaces/contracts/vault/IVault.sol";
import { IAuthorizer } from "@koyofinance/contracts-interfaces/contracts/vault/IAuthorizer.sol";
// solhint-disable-next-line max-line-length
import { IPerpetualsVaultInternalStable } from "@koyofinance/contracts-interfaces/contracts/perpetuals/core/IPerpetualsVaultInternalStable.sol";
import { IMintable } from "@koyofinance/contracts-interfaces/contracts/perpetuals/core/IMintable.sol";
import { IERC20 } from "@koyofinance/contracts-interfaces/contracts/solidity-utils/openzeppelin/IERC20.sol";

// solhint-disable-next-line max-line-length
import { Errors, _require, _revert } from "@koyofinance/contracts-interfaces/contracts/solidity-utils/helpers/KoyoErrors.sol";
import { SafeMath } from "@koyofinance/contracts-solidity-utils/contracts/openzeppelin/SafeMath.sol";
import { SafeERC20 } from "@koyofinance/contracts-solidity-utils/contracts/openzeppelin/SafeERC20.sol";

contract KPLPManager is IKPLPManager, Authentication, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    uint256 public constant PRICE_PRECISION = 10**30;
    uint256 public constant USDG_DECIMALS = 18;
    uint256 public constant MAX_COOLDOWN_DURATION = 48 hours;

    IPerpetualsVault public immutable perpetualsVault;
    IPerpetualsVaultInternalStable public usdk;
    address public kplp;

    uint256 public override cooldownDuration;
    mapping(address => uint256) public override lastAddedAt;

    uint256 public aumAddition;
    uint256 public aumDeduction;

    bool public inPrivateMode;
    mapping(address => bool) public isHandler;

    IExchangeVault private immutable _exchangeVault;

    event AddLiquidity(
        address account,
        address token,
        uint256 amount,
        uint256 aumInUsdk,
        uint256 kplpSupply,
        uint256 usdkAmount,
        uint256 mintAmount
    );

    event RemoveLiquidity(
        address account,
        address token,
        uint256 kplpAmount,
        uint256 aumInUsdk,
        uint256 kplpSupply,
        uint256 usdkAmount,
        uint256 amountOut
    );

    constructor(
        IExchangeVault exchangeVault,
        IPerpetualsVault _perpetualsVault,
        IPerpetualsVaultInternalStable _usdk,
        address _kplp,
        uint256 _cooldownDuration
    ) Authentication(bytes32(uint256(address(this)))) {
        _exchangeVault = exchangeVault;
        perpetualsVault = _perpetualsVault;
        usdk = _usdk;
        kplp = _kplp;
        cooldownDuration = _cooldownDuration;
    }

    function setInPrivateMode(bool _inPrivateMode) external authenticate {
        inPrivateMode = _inPrivateMode;
    }

    function setHandler(address _handler, bool _isActive) external authenticate {
        isHandler[_handler] = _isActive;
    }

    function setCooldownDuration(uint256 _cooldownDuration) external authenticate {
        _require(_cooldownDuration <= MAX_COOLDOWN_DURATION, Errors.KPLP_MANAGER__COOLDOWN_DURATION_INVALID);
        cooldownDuration = _cooldownDuration;
    }

    function setAumAdjustment(uint256 _aumAddition, uint256 _aumDeduction) external authenticate {
        aumAddition = _aumAddition;
        aumDeduction = _aumDeduction;
    }

    function addLiquidity(
        address _token,
        uint256 _amount,
        uint256 _minUsdk,
        uint256 _minGlp
    ) external override nonReentrant returns (uint256) {
        if (inPrivateMode) {
            _revert(Errors.KPLP_MANAGER_ACTION_NOT_ENABLED);
        }
        return _addLiquidity(msg.sender, msg.sender, _token, _amount, _minUsdk, _minGlp);
    }

    function addLiquidityForAccount(
        address _fundingAccount,
        address _account,
        address _token,
        uint256 _amount,
        uint256 _minUsdk,
        uint256 _minGlp
    ) external override nonReentrant returns (uint256) {
        _validateHandler();
        return _addLiquidity(_fundingAccount, _account, _token, _amount, _minUsdk, _minGlp);
    }

    function removeLiquidity(
        address _tokenOut,
        uint256 _kplpAmount,
        uint256 _minOut,
        address _receiver
    ) external override nonReentrant returns (uint256) {
        if (inPrivateMode) {
            _revert(Errors.KPLP_MANAGER_ACTION_NOT_ENABLED);
        }
        return _removeLiquidity(msg.sender, _tokenOut, _kplpAmount, _minOut, _receiver);
    }

    function removeLiquidityForAccount(
        address _account,
        address _tokenOut,
        uint256 _kplpAmount,
        uint256 _minOut,
        address _receiver
    ) external override nonReentrant returns (uint256) {
        _validateHandler();
        return _removeLiquidity(_account, _tokenOut, _kplpAmount, _minOut, _receiver);
    }

    function getAums() public view returns (uint256[] memory) {
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = getAum(true);
        amounts[1] = getAum(false);
        return amounts;
    }

    function getAumInUsdk(bool maximise) public view returns (uint256) {
        uint256 aum = getAum(maximise);
        return aum.mul(10**USDG_DECIMALS).div(PRICE_PRECISION);
    }

    function getAum(bool maximise) public view returns (uint256) {
        uint256 length = perpetualsVault.allWhitelistedTokensLength();
        uint256 aum = aumAddition;
        uint256 shortProfits = 0;

        for (uint256 i = 0; i < length; i++) {
            address token = perpetualsVault.allWhitelistedTokens(i);
            bool isWhitelisted = perpetualsVault.whitelistedTokens(token);

            if (!isWhitelisted) {
                continue;
            }

            uint256 price = maximise ? perpetualsVault.getMaxPrice(token) : perpetualsVault.getMinPrice(token);
            uint256 poolAmount = perpetualsVault.poolAmounts(token);
            uint256 decimals = perpetualsVault.tokenDecimals(token);

            if (perpetualsVault.stableTokens(token)) {
                aum = aum.add(poolAmount.mul(price).div(10**decimals));
            } else {
                // add global short profit / loss
                uint256 size = perpetualsVault.globalShortSizes(token);
                if (size > 0) {
                    uint256 averagePrice = perpetualsVault.globalShortAveragePrices(token);
                    uint256 priceDelta = averagePrice > price ? averagePrice.sub(price) : price.sub(averagePrice);
                    uint256 delta = size.mul(priceDelta).div(averagePrice);
                    if (price > averagePrice) {
                        // add losses from shorts
                        aum = aum.add(delta);
                    } else {
                        shortProfits = shortProfits.add(delta);
                    }
                }

                aum = aum.add(perpetualsVault.guaranteedUsd(token));

                uint256 reservedAmount = perpetualsVault.reservedAmounts(token);
                aum = aum.add(poolAmount.sub(reservedAmount).mul(price).div(10**decimals));
            }
        }

        aum = shortProfits > aum ? 0 : aum.sub(shortProfits);
        return aumDeduction > aum ? 0 : aum.sub(aumDeduction);
    }

    function getExchangeVault() public view returns (IExchangeVault) {
        return _exchangeVault;
    }

    function _addLiquidity(
        address _fundingAccount,
        address _account,
        address _token,
        uint256 _amount,
        uint256 _minUsdk,
        uint256 _minGlp
    ) private returns (uint256) {
        _require(_amount > 0, Errors.KPLP_MANAGER__AMOUNT_INVALID);

        // calculate aum before buyUSDG
        uint256 aumInUsdk = getAumInUsdk(true);
        uint256 kplpSupply = IERC20(kplp).totalSupply();

        IERC20(_token).safeTransferFrom(_fundingAccount, address(perpetualsVault), _amount);
        uint256 usdkAmount = perpetualsVault.buyUSDG(_token, address(this));
        _require(usdkAmount >= _minUsdk, Errors.KPLP_MANAGER_USDK_OUTPUT_INSUFFICIENT);

        uint256 mintAmount = aumInUsdk == 0 ? usdkAmount : usdkAmount.mul(kplpSupply).div(aumInUsdk);
        _require(mintAmount >= _minGlp, Errors.KPLP_MANAGER_KPLP_OUTPUT_INSUFFICIENT);

        IMintable(kplp).mint(_account, mintAmount);

        // solhint-disable-next-line not-rely-on-time
        lastAddedAt[_account] = block.timestamp;

        emit AddLiquidity(_account, _token, _amount, aumInUsdk, kplpSupply, usdkAmount, mintAmount);

        return mintAmount;
    }

    function _removeLiquidity(
        address _account,
        address _tokenOut,
        uint256 _kplpAmount,
        uint256 _minOut,
        address _receiver
    ) private returns (uint256) {
        _require(_kplpAmount > 0, Errors.KPLP_MANAGER__KPLP_AMOUNT_INVALID);
        _require(
            // solhint-disable-next-line not-rely-on-time
            lastAddedAt[_account].add(cooldownDuration) <= block.timestamp,
            Errors.KPLP_MANAGER_COOLDOWN_NOT_PASSED
        );

        // calculate aum before sellUSDG
        uint256 aumInUsdk = getAumInUsdk(false);
        uint256 kplpSupply = IERC20(kplp).totalSupply();

        uint256 usdkAmount = _kplpAmount.mul(aumInUsdk).div(kplpSupply);
        uint256 usdkBalance = IERC20(address(usdk)).balanceOf(address(this));
        if (usdkAmount > usdkBalance) {
            usdk.mint(address(this), usdkAmount.sub(usdkBalance));
        }

        IMintable(kplp).burn(_account, _kplpAmount);

        IERC20(address(usdk)).transfer(address(perpetualsVault), usdkAmount);
        uint256 amountOut = perpetualsVault.sellUSDG(_tokenOut, _receiver);
        _require(amountOut >= _minOut, Errors.KPLP_MANAGER_OUTPUT_INSUFFICIENT);

        emit RemoveLiquidity(_account, _tokenOut, _kplpAmount, aumInUsdk, kplpSupply, usdkAmount, amountOut);

        return amountOut;
    }

    function _validateHandler() private view {
        _require(isHandler[msg.sender], Errors.KPLP_MANAGER_CALLER_NOT_HANDLER);
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
