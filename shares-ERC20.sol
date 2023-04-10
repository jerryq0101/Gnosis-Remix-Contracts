// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Shares is ERC20 {
    address private _owner;
    address private auction;

    constructor() ERC20("Shares1", "S1"){
        _owner = msg.sender;
        _mint(msg.sender, 1000000000 * 10**18);
    }

    function setAuction(address newAuction) public {
        require(msg.sender == _owner, "only the owner can set Auction");
        auction = newAuction;
    }

    function changeOwner(address newOwner) public {
        require(msg.sender == _owner, "Only the current owner can transfer ownership");
        _owner = newOwner;
    }

    function mint(address to, uint256 amount) external {
        require(msg.sender == _owner || msg.sender == auction, "Only owner or the auction is authorized to mint");
        _mint(to, amount);
    }
}