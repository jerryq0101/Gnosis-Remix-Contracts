// ALL ADDRESSES ON GOERLI
// ethFunds should be Gnosis Address. (USDC receival)
// aggregator interface was used for purchasing of Token using ETH/USD (removed for now)
// For buyToken - Call approve for USDC and then call the function
    // USDC is 10^6, ETH is 10^18 (This shit killed me)
// USDC goerli address is 0x07865c6e87b9f70255377e024ace6630c1eaa37f

pragma solidity ^0.8.0;

import './shares-ERC20.sol';
// This was for ETH/USD
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract SharesSale {
    address payable public admin;
    address payable private ethFunds = payable(0x6902702BB5678D7361C94441c71F600C255dd833);
    Shares public token;
    ERC20 public USDC;
    uint256 public tokensSold;
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

    function buyToken(uint256 _amount) public payable {
        // check if there's enough tokens this crowdsale contract
        // check if user has enough USDC erc20s in wallet
        require(token.balanceOf(address(this)) >= _amount, "Failed token balance of");
        require(USDC.balanceOf(msg.sender) >= (_amount) , "Failed usdc balance of");

        // exchange (transferfrom) tokens. 

        require(USDC.transferFrom(msg.sender, ethFunds, _amount), "Failed USDC Transfer From");
        require(token.transfer(msg.sender, _amount) , "Failed Shares transferfrom");
        
        // This is the ethereum intepretation - ethFunds.transfer(msg.value);
        
        tokensSold+=_amount;
        transaction[transactionCount] = Transaction(msg.sender, _amount);
        transactionCount++;
        emit Sell(msg.sender, _amount);
    }

    function endSale() public {
        require(msg.sender == admin);

        uint256 amount = token.balanceOf(address(this));
        require(token.transfer(admin, amount));

        selfdestruct(payable(admin));
    }
}