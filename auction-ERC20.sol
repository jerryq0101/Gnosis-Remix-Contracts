pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./shares-ERC20.sol";

contract TokenAuction {
    ERC20 public USDC;
    Shares public shares;
    uint256 public auctionEndTime;
    address public highestBidder;
    uint256 public highestBid;
    uint256 public tokensForSale;

    mapping(address => uint256) public bids;

    bool public ended;
    event AuctionEnded(address winner, uint256 amount);

    constructor(Shares sharesAddress) {
        shares = sharesAddress;
    }
    
    // THIS CAN ONLY CALLED BY GNOSIS SAFE PRIVATE
    function startAuction(uint256 duration, uint256 _tokensForSale, address _usdcTokenAddress) external {
        require(auctionEndTime == 0, "Auction already started");
        require(_tokensForSale > 0, "Token amount should be greater than zero");
        // Raw Address to be Gnosis multisig
        require(msg.sender == 0x6902702BB5678D7361C94441c71F600C255dd833, "Not authorized to start auction");
        
        USDC = ERC20(_usdcTokenAddress);
        auctionEndTime = block.timestamp + duration;
        tokensForSale = _tokensForSale;

        // Mint tokens to this contract (make this one of the minters)
        shares.mint(address(this), _tokensForSale * 10**18);
    }

    // CALL USDC ALLOWANCE FUNCTION, THEN CALL THIS. 
    function placeBid(uint256 _amount) public {
        require(!ended, "Auction has ended");
        require(block.timestamp < auctionEndTime, "Auction has ended");
        require(_amount > highestBid, "There is already an equal or higher bid");
        // Each person has to approve their USDC before hand to make sure they don't go back on their promise
        require(USDC.allowance(msg.sender, address(this)) >= _amount * 10**6, "You need to approve the USDC transfer first");
        require(USDC.balanceOf(msg.sender) >= _amount, "You don't have enough USDC to bid that amount");

        // If theres a new highest bid within 3 minutes of the auction
        if (auctionEndTime - block.timestamp <= 3 minutes) {
            extendAuction();
        }
        // To update the public highest bid
        if (highestBidder != address(0)) {
            bids[highestBidder] += highestBid;
        }

        highestBidder = msg.sender;
        highestBid = _amount;
    }

    function extendAuction() internal {
        require(!ended, "Auction has already ended");
        require(block.timestamp < auctionEndTime, "Auction has ended");
        require(block.timestamp >= auctionEndTime - 3 minutes, "Cannot extend auction yet");

        auctionEndTime += 60 seconds;
    }

    function endAuction() public {
        require(!ended, "Auction has already ended");
        require(block.timestamp >= auctionEndTime, "Auction has not yet ended");

        ended = true;
        emit AuctionEnded(highestBidder, highestBid);

        if (highestBid > 0) {
            require(shares.balanceOf(address(this)) >= tokensForSale, "Tokens not deposited in the contract");
            // Transfer USDC from highest bidder. the Raw address will be the gnosis safe address
            USDC.transferFrom(highestBidder, 0x6902702BB5678D7361C94441c71F600C255dd833, highestBid * 10**6);
            // Transfer Shares from this contract to the highest bidder.
            shares.transfer(highestBidder, tokensForSale*10**18); 
            resetAuction();
        } else {
            shares.transfer(msg.sender, highestBid);
            resetAuction();
        }
    }

    function resetAuction() internal {
        ended = false;
        auctionEndTime = 0;
        tokensForSale = 0;
        highestBidder = address(0x0);
        highestBid = 0;
        bids[highestBidder] = 0;
    }
}