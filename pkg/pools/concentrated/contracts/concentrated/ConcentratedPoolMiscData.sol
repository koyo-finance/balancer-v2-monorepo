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

import { WordCodec } from "@koyofinance/exchange-vault-solidity-utils/contracts/helpers/WordCodec.sol";

/**
 * @dev This module provides an interface to store seemingly unrelated pieces of information in the same storage slot,
 * in particular to be used by Concentrated Pool with a price oracle.
 *
 * Data is stored with the following structure,
 * which is compatible with BaseTokenlessPool's misc data field as the upper 64 bits
 * are reserved.
 *
 * [ reserved | unused | sqrtPriceX96 | tick  ]
 * [  uint64  | uint8  |    uint160   | int24 ]
 */
library ConcentratedPoolMiscData {
    using WordCodec for bytes32;
    using WordCodec for uint256;

    uint256 private constant _TICK_OFFSET = 0;
    uint256 private constant _SQRT_PRICE_X96_OFFSET = 24;

    uint256 private constant _TICK_LENGTH = 24;
    uint256 private constant _SQRT_PRICE_X96_LENGTH = 160;

    function tick(bytes32 data) internal pure returns (int256) {
        return data.decodeInt(_TICK_OFFSET, _TICK_LENGTH);
    }

    function sqrtPriceX96(bytes32 data) internal pure returns (int256) {
        return data.decodeUint(_SQRT_PRICE_X96_OFFSET, _SQRT_PRICE_X96_LENGTH);
    }

    function setTick(bytes32 data, int24 _tick) internal pure returns (bytes32) {
        return data.insertInt(_tick, _TICK_OFFSET, _TICK_LENGTH);
    }

    function setSqrtPriceX96(bytes32 data, int24 _sqrtPriceX96) internal pure returns (bytes32) {
        return data.insertUint(_sqrtPriceX96, _SQRT_PRICE_X96_OFFSET, _SQRT_PRICE_X96_LENGTH);
    }
}
