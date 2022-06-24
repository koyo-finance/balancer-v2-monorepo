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

import "../solidity-utils/openzeppelin/IERC20.sol";

library ConcentratedPoolUserData {
    // In order to preserve backwards compatibility, make sure new join and exit kinds are added at the end of the enum.
    enum JoinKind {
        INIT,
        EXACT_TOKENS_IN_FOR_BPT_OUT, // IGNORE
        TOKEN_IN_FOR_EXACT_BPT_OUT, // IGNORE
        ALL_TOKENS_IN_FOR_EXACT_BPT_OUT, // IGNORE
        ADD_TOKEN, // IGNORE
        CREATE_POSITON
    }
    enum ExitKind {
        EXACT_BPT_IN_FOR_ONE_TOKEN_OUT, // IGNORE
        EXACT_BPT_IN_FOR_TOKENS_OUT, // IGNORE
        BPT_IN_FOR_EXACT_TOKENS_OUT, // IGNORE
        REMOVE_TOKEN // IGNORE
    }

    function joinKind(bytes memory self) internal pure returns (JoinKind) {
        return abi.decode(self, (JoinKind));
    }

    function exitKind(bytes memory self) internal pure returns (ExitKind) {
        return abi.decode(self, (ExitKind));
    }

    // Joins

    function initialPricing(bytes memory self) internal pure returns (uint160 sqrtPriceX96) {
        (, sqrtPriceX96) = abi.decode(self, (JoinKind, uint160));
    }

    // Exits
}
