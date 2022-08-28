// SPDX-License-Identifier: MIT

pragma solidity ^0.7.0;

interface IPerpetualsFastPriceFeed {
    function lastUpdatedAt() external view returns (uint256);

    function lastUpdatedBlock() external view returns (uint256);

    function setIsSpreadEnabled(bool _isSpreadEnabled) external;

    function setSigner(address _account, bool _isActive) external;
}
