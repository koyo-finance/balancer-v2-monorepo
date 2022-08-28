// SPDX-License-Identifier: MIT

pragma solidity ^0.7.0;

interface IPerpetualsSecondaryPriceFeed {
    function getPrice(
        address _token,
        uint256 _referencePrice,
        bool _maximise
    ) external view returns (uint256);
}
