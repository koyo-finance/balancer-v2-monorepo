// SPDX-License-Identifier: MIT

pragma solidity ^0.7.0;

interface IPerpetualsVaultInternalStable {
    function addVault(address _vault) external;

    function removeVault(address _vault) external;

    function mint(address _account, uint256 _amount) external;

    function burn(address _account, uint256 _amount) external;
}
