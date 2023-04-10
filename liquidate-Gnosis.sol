// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@gnosis.pm/safe-contracts/contracts/GnosisSafe.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "./shares-address-Storage.sol";

contract Liquidator {
    address payable private _safeAddress;
    address private _sharesAddress;
    address private _prioritySharesAddress;

    Storage _tokenAddressStorage;
    ERC20 USDC;

    constructor(address payable safeAddress, 
                address sharesAddress,
                address prioritySharesAddress,
                ERC20 USDCAddress,
                Storage tokenAddressStorage
                ) {
        USDC = USDCAddress;
        _safeAddress = safeAddress;
        _sharesAddress = sharesAddress;
        _prioritySharesAddress = prioritySharesAddress;
        _tokenAddressStorage = tokenAddressStorage;
    }
    
    // FOR LIQUIDATE CONTRACT DEPLOYMENT I HAVE TO CALL APPROVE ALL USDC ASSETS IN SAFE. (new addy)
        // This whole system is very janky without UI!
    function shareholderLiquidation() internal {
        //Some require statements here! 
        // require(msg.sender == _safeAddress, "only the safe is authorized to call liquidation");

        address[] memory tokenholders = _tokenAddressStorage.query();
        ERC20 token = ERC20(_sharesAddress);
        uint256 USDCBalance = USDC.balanceOf(_safeAddress);
        uint256 tokenTotalSupply = token.totalSupply();
        uint256 numHolders = tokenholders.length;

        for (uint256 i = 0; i < numHolders; i++) {
            address owner = tokenholders[i];
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

    function investmentLiquidation() external {
        // Some require statements here!
        // require(msg.sender == _safeAddress, "only the safe is authorized to call liquidation");
        address[] memory tokenholders = _tokenAddressStorage.query();
        // Similar to shareholder, but only returning exactly initial priority liquidity 
        GnosisSafe safe = GnosisSafe(_safeAddress);
        ERC20 token = ERC20(_sharesAddress);
        ERC20 priorityToken = ERC20(_prioritySharesAddress);
        // General holders (invest + general people)
        uint256 numHolders = tokenholders.length;

        for (uint256 i = 0; i < numHolders; i++) {
            // check if there is holding of pprioritytoken 
            // find out how much we owe them
            // send money back to them
            address owner = tokenholders[i];
            // This will probably break if priorityToken is a floating point
            if (priorityToken.balanceOf(owner) > 0) {
                // Amount in USDC 
                uint256 owedAssets = _tokenAddressStorage.queryInvestment(owner);
                require(USDC.allowance(_safeAddress, address(this)) >= owedAssets, "Safe needs to approve distribution of funds to investors");
                USDC.transferFrom(_safeAddress, owner, owedAssets*10**6);
            }
        }
    }
}
