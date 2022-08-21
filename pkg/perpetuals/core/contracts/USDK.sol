// SPDX-License-Identifier: MIT

pragma solidity ^0.7.0;

import { YieldBaseToken } from "./base/YieldBaseToken.sol";
// solhint-disable-next-line max-line-length
import { IPerpetualsVaultInternalStable } from "@koyofinance/contracts-interfaces/contracts/perpetuals/core/IPerpetualsVaultInternalStable.sol";

contract USDK is YieldBaseToken, IPerpetualsVaultInternalStable {
    mapping(address => bool) public vaults;

    modifier onlyVault() {
        require(vaults[msg.sender], "USDK: forbidden");
        _;
    }

    constructor(address _vault) YieldBaseToken("USD Koyo", "USDK", 0) {
        vaults[_vault] = true;
    }

    function addVault(address _vault) external override onlyGov {
        vaults[_vault] = true;
    }

    function removeVault(address _vault) external override onlyGov {
        vaults[_vault] = false;
    }

    function mint(address _account, uint256 _amount) external override onlyVault {
        _mint(_account, _amount);
    }

    function burn(address _account, uint256 _amount) external override onlyVault {
        _burn(_account, _amount);
    }
}
