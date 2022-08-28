// SPDX-License-Identifier: MIT

pragma solidity ^0.7.0;

import { AggregatorInterface } from "./AggregatorInterface.sol";
import { AggregatorV3Interface } from "./AggregatorV3Interface.sol";

// solhint-disable-next-line no-empty-blocks
interface AggregatorV2V3Interface is AggregatorInterface, AggregatorV3Interface {}
