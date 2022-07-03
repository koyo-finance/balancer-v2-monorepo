// SPDX-License-Identifier: GPL-3.0-or-later
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import { BaseTokenlessPool } from "../base/BaseTokenlessPool.sol";

import { IERC20 } from "@koyofinance/exchange-vault-interfaces/contracts/solidity-utils/openzeppelin/IERC20.sol";
import { IVault } from "@koyofinance/exchange-vault-interfaces/contracts/vault/IVault.sol";

import { ConcentratedPoolMiscData } from "./ConcentratedPoolMiscData.sol";
import {
    ConcentratedPoolUserData
} from "@koyofinance/exchange-vault-interfaces/contracts/pool-concentrated/ConcentratedPoolUserData.sol";
import { FixedPoint } from "@koyofinance/exchange-vault-solidity-utils/contracts/math/FixedPoint.sol";
import { TickMath } from "../math/TickMath.sol";
import { TickMappingMath } from "../math/TickMappingMath.sol";
import {
    _require,
    Errors
} from "@koyofinance/exchange-vault-interfaces/contracts/solidity-utils/helpers/BalancerErrors.sol";

contract ConcentratedPool is BaseTokenlessPool {
    using FixedPoint for uint256;
    using ConcentratedPoolMiscData for bytes32;
    using ConcentratedPoolUserData for bytes;

    IERC20 internal immutable _token0;
    IERC20 internal immutable _token1;

    // All token balances are normalized to behave as if the token had 18 decimals. We assume a token's decimals will
    // not change throughout its lifetime, and store the corresponding scaling factor for each at construction time.
    // These factors are always greater than or equal to one: tokens with more than 18 decimals are not supported.
    uint256 internal immutable _scalingFactor0;
    uint256 internal immutable _scalingFactor1;

    int24 internal immutable _tickSpacing;
    uint128 internal immutable _maxLiquidityPerTick;

    struct NewConcentratedPoolParams {
        IVault vault;
        IERC20[] tokens;
        address[] assetManagers;
        int24 tickSpacing;
        uint256 swapFeePercentage;
        uint256 pauseWindowDuration;
        uint256 bufferPeriodDuration;
        address owner;
    }

    constructor(NewConcentratedPoolParams memory params)
        BaseTokenlessPool(
            params.vault,
            IVault.PoolSpecialization.TWO_TOKEN,
            params.tokens,
            params.assetManagers,
            params.swapFeePercentage,
            params.pauseWindowDuration,
            params.bufferPeriodDuration,
            params.owner
        )
    {
        _require(params.tokens.length == 2, Errors.TOKENS_LENGTH_MUST_BE_2);

        _token0 = params.tokens[0];
        _token1 = params.tokens[1];

        _scalingFactor0 = _computeScalingFactor(params.tokens[0]);
        _scalingFactor1 = _computeScalingFactor(params.tokens[1]);

        _tickSpacing = params.tickSpacing;
        _maxLiquidityPerTick = TickMappingMath.tickSpacingToMaxLiquidityPerTick(_tickSpacing);
    }

    function getMiscData()
        external
        view
        returns (
            uint160 sqrtPriceX96,
            int24 tick,
            uint256 swapFeePercentage
        )
    {
        bytes32 miscData = _getMiscData();
        tick = miscData.tick();
        sqrtPriceX96 = miscData.sqrtPriceX96();

        swapFeePercentage = getSwapFeePercentage();
    }

    function getTickSpacing() external view returns (int24) {
        return _tickSpacing;
    }

    function getMaxLiquidityPerTick() external view returns (uint128) {
        return _maxLiquidityPerTick;
    }

    function onJoinPool(
        bytes32 poolId,
        address sender,
        address recipient,
        uint256[] memory balances,
        uint256 lastChangeBlock,
        uint256 protocolSwapFeePercentage,
        bytes memory userData
    ) public virtual override onlyVault(poolId) returns (uint256[] memory, uint256[] memory) {
        uint256[] memory scalingFactors = _scalingFactors();
        bytes32 miscData = _getMiscData();
        uint160 sqrtPriceX96 = miscData.sqrtPriceX96();

        if (sqrtPriceX96 == 0) {
            _onInitializePool(poolId, sender, recipient, scalingFactors, userData);

            // // On initialization, we lock _getMinimumBpt() by minting it for the zero address. This BPT acts as a
            // // minimum as it will never be burned, which reduces potential issues with rounding, and also prevents the
            // // Pool from ever being fully drained.
            // _require(bptAmountOut >= _getMinimumBpt(), Errors.MINIMUM_BPT);
            // _mintPoolTokens(address(0), _getMinimumBpt());
            // _mintPoolTokens(recipient, bptAmountOut - _getMinimumBpt());

            // // amountsIn are amounts entering the Pool, so we round up.
            // _downscaleUpArray(amountsIn, scalingFactors);

            // return (amountsIn, new uint256[](balances.length));
        } else {
            // _upscaleArray(balances, scalingFactors);
            // (uint256 bptAmountOut, uint256[] memory amountsIn) = _onJoinPool(
            //     poolId,
            //     sender,
            //     recipient,
            //     balances,
            //     lastChangeBlock,
            //     protocolSwapFeePercentage,
            //     scalingFactors,
            //     userData
            // );
            // // Note we no longer use `balances` after calling `_onJoinPool`, which may mutate it.
            // _mintPoolTokens(recipient, bptAmountOut);
            // // amountsIn are amounts entering the Pool, so we round up.
            // _downscaleUpArray(amountsIn, scalingFactors);
            // // This Pool ignores the `dueProtocolFees` return value, so we simply return a zeroed-out array.
            // return (amountsIn, new uint256[](balances.length));
        }
    }

    function _scalingFactor(bool token0) internal view returns (uint256) {
        return token0 ? _scalingFactor0 : _scalingFactor1;
    }

    function _scalingFactor(IERC20 token) internal view virtual override returns (uint256) {
        return _scalingFactor(token == _token0);
    }

    function _scalingFactors() internal view virtual override returns (uint256[] memory) {
        uint256[] memory scalingFactors = new uint256[](2);
        scalingFactors[0] = _scalingFactor0;
        scalingFactors[1] = _scalingFactor1;
        return scalingFactors;
    }

    function _getMaxTokens() internal pure virtual override returns (uint256) {
        return 2;
    }

    function _getTotalTokens() internal pure virtual override returns (uint256) {
        return 2;
    }

    function _onInitializePool(
        bytes32,
        address,
        address,
        uint256[] memory,
        bytes memory userData
    ) internal virtual override whenNotPaused {
        // It would be strange for the Pool to be paused before it is initialized, but for consistency we prevent
        // initialization in this case.

        ConcentratedPoolUserData.JoinKind kind = userData.joinKind();
        _require(kind == ConcentratedPoolUserData.JoinKind.INIT, Errors.UNINITIALIZED);

        uint160 sqrtPriceX96 = userData.initialPricing();
        _setMiscData(_getMiscData().setSqrtPriceX96(sqrtPriceX96));

        int24 tick = TickMath.getTickAtSqrtRatio(sqrtPriceX96);
        _setMiscData(_getMiscData().setTick(tick));
    }
}
