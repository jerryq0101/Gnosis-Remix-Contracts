pragma solidity ^0.8.0;

import './shares-ERC20.sol';
import './shares-pref-ERC20.sol';
import './shares-address-Storage.sol';
// This was for ETH/USD
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract SharesSale {
    address payable public admin;
    // Replace ethFunds with Gnosis safe.
    address payable private ethFunds = payable(0x6902702BB5678D7361C94441c71F600C255dd833);
    Shares public token;
    SharesPref public priorityToken;
    ERC20 public USDC;
    // ONLY MADE WITH USDC ASSET IN MIND FOR TESTING PURPOSES. 
    uint256 public tokensSold;
    uint256 public priorityTokensSold;
    uint256 public _usdcPrice;
    AggregatorV3Interface internal priceFeed;

    uint256 public transactionCount;
    event Sell(address _buyer, uint256 _amount, bool priority);
    struct Transaction {
        address buyer;
        uint256 amount;
        bool priority;
    }

    mapping(uint256 => Transaction) public transaction;
    Storage tokenHolderStorage;

    constructor(Shares _token, 
        ERC20 _usdcAddress, 
        SharesPref _priorityToken,
        Storage storageAddress) {
        
        priceFeed = AggregatorV3Interface(0xD4a33860578De61DBAbDc8BFdb98FD742fA7028e);
        USDC = _usdcAddress;
        token = _token;
        priorityToken = _priorityToken;
        tokenHolderStorage = storageAddress;
        admin = payable(msg.sender);
    }

    // CALL APPROVE FUNCTION FIRST, And THEN CALL THIS
    // This function is meant to be able to be called anytime as general purchase.
    function buyToken(uint256 _amount) public {
        // check if there's enough tokens this crowdsale contract
        // check if user has enough USDC erc20s in wallet
        require(token.balanceOf(address(this)) >= _amount, "Failed token balance of");
        require(USDC.balanceOf(msg.sender) >= (_amount * _usdcPrice) , "Failed usdc balance of");
        require(USDC.allowance(msg.sender, address(this)) >= (_amount * _usdcPrice), "Buyer needs to approve spending of USDC from this contract");

        // exchange (transferfrom) tokens. 
        require(USDC.transferFrom(msg.sender, ethFunds, _amount * 10**6 * _usdcPrice), "Failed USDC Transfer From");
        require(token.transfer(msg.sender, _amount * 10**18) , "Failed Shares transferfrom");
        
        tokensSold+=_amount;
        tokenHolderStorage.store(msg.sender);
        transaction[transactionCount] = Transaction(msg.sender, _amount, false);
        transactionCount++;
        emit Sell(msg.sender, _amount, false);
    }

    // A sale that is limited by quantity
    // ONLY CALLABLE BY THE ADMIN
    function createAmountSale(uint256 _amount, uint256 usdcPrice) public{
        // require the creation of a sale to be by admin
        require(msg.sender == admin);

        // mint the _amount tokens and transfer it to this sale wallet 
        token.mint(address(this), _amount * 10**18);
        _usdcPrice = usdcPrice;
    }

    // Priority investments for the company, (using general price variable still in the beginning)
    function earlyBuyToken(uint256 _amount) external {
        // same thing as the buytoken function except a different token
        require(priorityToken.balanceOf(address(this)) >= _amount, "Contract does not have enough tokens");
        require(USDC.balanceOf(msg.sender) >= (_amount * _usdcPrice), "Buyer does not have enough USDC to purchase specified amount");
        require(USDC.allowance(msg.sender, address(this)) >= (_amount * _usdcPrice), "Buyer needs to approve spending of USDC from this contract");

        // Transfer the tokens
        require(USDC.transferFrom(msg.sender, ethFunds, _amount * 10**6 * _usdcPrice), "Failed USDC transfer from");
        require(priorityToken.transfer(msg.sender, _amount * 10**18));

        // Increment values for tokenholder and transaction purpose in LIQUIDATION
        priorityTokensSold+=_amount;
        tokenHolderStorage.store(msg.sender);
        tokenHolderStorage.storeInvestment(msg.sender, _amount*_usdcPrice);
        transaction[transactionCount] = Transaction(msg.sender, _amount, true);
        transactionCount++;
        emit Sell(msg.sender, _amount, false);
    }

    function initializeEarlyBuyToken(uint256 _amount, uint256 price) public{
        require(msg.sender == admin);
        
        // mint priority tokens and transfer it to this
        priorityToken.mint(address(this), _amount * 10**18);
        _usdcPrice = price;
    }

    // TRANSFER ADMIN TO GNOSIS SAFE
    function transferAdmin(address payable newAdmin) public {
        require(msg.sender == admin, "Only the admin can transfer admin");
        admin = newAdmin;
    }

    // PROBABLY not going to be used since the contract is going to be continued to be used. 
    function endSale() public {
        require(msg.sender == admin);

        uint256 amount = token.balanceOf(address(this));
        require(token.transfer(admin, amount));

        selfdestruct(payable(admin));
    }
}