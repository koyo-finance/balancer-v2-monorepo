// SPDX-License-Identifier: MIT

pragma solidity ^0.7.0;

interface IPerpetualsAbstractVaultController {
    function enableLeverage() external;

    function disableLeverage() external;
}
