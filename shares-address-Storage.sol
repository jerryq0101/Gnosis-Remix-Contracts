// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


// Using this method is going to be a bit costly for larger arrays, (ERC20 doesn't do this)
// so find external services that are able to keep track of tokenholders. 
contract Storage {
    address[] potentialTokenHolders;
    address owner;

    mapping(address => uint256) investQuantity;

    constructor(address _owner){
        owner = _owner;
    }
    // Remember to set the following function as restricted access 
    
    function store(address someone) public {
        potentialTokenHolders.push(someone);
    }

    function storeInvestment(address someone, uint256 quantityUSDC) public{
        investQuantity[someone] = quantityUSDC;
    }
    
    function queryInvestment(address someone) public returns (uint256){
        return investQuantity[someone];
    }

    function query() public returns(address[] memory) {
        return potentialTokenHolders;
    }
}