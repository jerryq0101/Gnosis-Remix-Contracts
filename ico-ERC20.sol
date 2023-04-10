pragma solidity ^0.8.0;

import './shares-ERC20.sol';
// This was for ETH/USD
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract SharesSale {
    address payable public admin;
    address payable private ethFunds = payable(0x6902702BB5678D7361C94441c71F600C255dd833);
    Shares public token;
    ERC20 public USDC;
    // ONLY MADE WITH USDC ASSET IN MIND FOR TESTING PURPOSES - CAN INCREASE LATER. 

    uint256 public tokensSold;
    uint256 public _usdcPrice;
    AggregatorV3Interface internal priceFeed;

    uint256 public transactionCount;

    event Sell(address _buyer, uint256 _amount);

    struct Transaction {
        address buyer;
        uint256 amount;
    }

    mapping(uint256 => Transaction) public transaction;

    constructor(Shares _token, ERC20 _usdcAddress) {
        priceFeed = AggregatorV3Interface(0xD4a33860578De61DBAbDc8BFdb98FD742fA7028e);
        
        USDC = _usdcAddress;
        token = _token;
        admin = payable(msg.sender);
    }

    // CALL APPROVE FUNCTION FIRST, And THEN CALL THIS
    function buyToken(uint256 _amount) public payable {
        // check if there's enough tokens this crowdsale contract
        // check if user has enough USDC erc20s in wallet
        require(token.balanceOf(address(this)) >= _amount, "Failed token balance of");
        require(USDC.balanceOf(msg.sender) >= (_amount) , "Failed usdc balance of");

        // exchange (transferfrom) tokens. 
            // I swear there's some decimal situation here - added the stuff did not test yet
        require(USDC.transferFrom(msg.sender, ethFunds, _amount * 10**6 * _usdcPrice), "Failed USDC Transfer From");
        require(token.transfer(msg.sender, _amount * 10**18) , "Failed Shares transferfrom");
        
        tokensSold+=_amount;
        transaction[transactionCount] = Transaction(msg.sender, _amount);
        transactionCount++;
        emit Sell(msg.sender, _amount);
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

    // TRANSFER ADMIN TO GNOSIS SAFE
    function transferAdmin(address payable newAdmin) public {
        require(msg.sender == admin, "Only the admin can transfer admin");
        admin = newAdmin;
    }

    // PROBABLY NEVER USED since the contract is going to be continued to be used. 
    function endSale() public {
        require(msg.sender == admin);

        uint256 amount = token.balanceOf(address(this));
        require(token.transfer(admin, amount));

        selfdestruct(payable(admin));
    }
}