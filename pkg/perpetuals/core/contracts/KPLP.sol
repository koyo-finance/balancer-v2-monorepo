// SPDX-License-Identifier: MIT

pragma solidity ^0.7.0;

import { MintableBaseToken } from "./base/MintableBaseToken.sol";

contract KPLP is MintableBaseToken {
    // solhint-disable-next-line no-empty-blocks
    constructor() MintableBaseToken("Koyo Perpetuals LP", "KPLP", 0) {}

    function id() external pure returns (string memory _name) {
        return "KPLP";
    }
}
