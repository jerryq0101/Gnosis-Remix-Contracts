// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Debt is ERC20 {
    address private _owner;
    address private _issuer;

    constructor() ERC20("Debt", "DEBT"){
        _owner = msg.sender; 
        _issuer = 0x886E5ef0FE0DeD31C15f9f4f2eDFeBE64eDFa583;
    }

    // Can use this to set as Gnosis
    function changeOwner(address newOwner) public {
        require(msg.sender == _owner, "Only the current owner can transfer ownership");
        _owner = newOwner;
    }
    
    function mintDebt(address to, uint256 amount) external {
        require(msg.sender == _owner || msg.sender == _issuer, "Only owner or the auction is authorized to mint");
        // Use 10**18 as an default ERC20 is 18 decimals
        _mint(to, amount * 10**18);
    }
}