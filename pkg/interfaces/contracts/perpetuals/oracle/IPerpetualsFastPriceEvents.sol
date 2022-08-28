// SPDX-License-Identifier: MIT

pragma solidity ^0.7.0;

interface IPerpetualsFastPriceEvents {
    function emitPriceEvent(address _token, uint256 _price) external;
}
