// SPDX-License-Identifier: MIT

pragma solidity ^0.7.0;

interface IPerpetualsBasePositionManager {
    function maxGlobalLongSizes(address _token) external view returns (uint256);

    function maxGlobalShortSizes(address _token) external view returns (uint256);
}
