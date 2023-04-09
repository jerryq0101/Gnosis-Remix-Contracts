// Just a default ERC20 token
// This token will send the total supply to the contract creator at first

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Shares is ERC20 {
    constructor() ERC20("Shares", "S"){
        _mint(msg.sender, 1000000000 * 10**18);
    }
}