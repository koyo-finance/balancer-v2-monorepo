// SPDX-License-Identifier: MIT

pragma solidity ^0.7.0;

interface IYieldToken {
    function totalStaked() external view returns (uint256);

    function stakedBalance(address _account) external view returns (uint256);

    function removeAdmin(address _account) external;
}
