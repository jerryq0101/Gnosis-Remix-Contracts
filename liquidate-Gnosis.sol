// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@gnosis.pm/safe-contracts/contracts/GnosisSafe.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

contract Liquidator {
    address payable private _safeAddress;
    address private _sharesAddress;
    ERC20 USDC;

    constructor(address payable safeAddress, 
                address sharesAddress,
                ERC20 USDCAddress
                ) {
        USDC = USDCAddress;
        _safeAddress = safeAddress;
        _sharesAddress = sharesAddress;
    }

    // FOR EVERY LIQUIDATE CONTRACT DEPLOYMENT I HAVE TO CALL APPROVE ALL USDC ASSETS IN SAFE. (new addy)
    function liquidate() external {
        GnosisSafe safe = GnosisSafe(_safeAddress);
        ERC20 token = ERC20(_sharesAddress);
        // I don't think the balance of Function is wrong
        uint256 USDCBalance = USDC.balanceOf(_safeAddress);
        // I don't think the totalsupply Function is wrong
        uint256 tokenTotalSupply = token.totalSupply();
        uint256 numOwners = safe.getOwners().length;

        for (uint256 i = 0; i < numOwners; i++) {
            address owner = safe.getOwners()[i];
            // I don't think the balance of Function is wrong
            uint256 userTokenBalance = token.balanceOf(owner);
            // 9.9e8 Shares
            // uint256 proportion = userTokenBalance / tokenTotalSupply * 100;
            // (9.9e8 * 100 ) / 1e9  = 99
            uint256 proportion = Math.mulDiv(userTokenBalance, 100, tokenTotalSupply);
            // what it should be (99/100 proportion * 9.91e4) = 98109 (IT WORKS)
            uint256 amountToLiquidate = Math.mulDiv(proportion, USDCBalance, 100);

            USDC.transferFrom(_safeAddress, msg.sender, amountToLiquidate);
        }
    }
}
