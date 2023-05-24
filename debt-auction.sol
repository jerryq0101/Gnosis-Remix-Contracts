pragma solidity ^0.8.0;

import "./debt-ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./create-loan.sol";
import "./shares-address-Storage.sol";

contract DebtAuction {

    struct Bid {
        address bidder;
        uint256 amount;
    }

    address public debtor;
    uint256 public debtAmount;
    uint256 public debtPeriod;
    uint256 public maxInterest;
    uint256 public auctionEndTime;
    bool public auctionEnded;

    Bid[] public bids;
    address public bestBidder;
    uint256 public bestIRate;

    event AuctionStarted(address indexed debtor, uint256 debtAmount, uint256 maxIRate, uint256 auctionEndTime);
    event BidPlaced(address indexed bidder, uint256 amount);
    event AuctionEnded(address indexed winner, uint256 amount);

    Debt private debtAddress;
    ERC20 usdc = ERC20(0x07865c6E87B9F70255377e024ace6630C1Eaa37F);
    LoanContract loanStorage;
    Storage addressStorage;

    constructor(Debt debtaddress, LoanContract _loanStorage, Storage _addressStorage) {
        debtAddress = debtaddress;
        debtor = 0x886E5ef0FE0DeD31C15f9f4f2eDFeBE64eDFa583;
        loanStorage = _loanStorage;
        addressStorage = _addressStorage;
    }

    // BULLET AUCTION SITUATION

    // maxIRate is the maximum interest rate the company is willing to pay
    function startBullet(uint256 _principleDebt, uint256 _debtTime, uint256 _maxIRate, uint256 _auctionDuration) public {
        debtAmount = _principleDebt;
        debtPeriod = _debtTime;
        auctionEndTime = block.timestamp + _auctionDuration;
        maxInterest = _maxIRate;
        bestIRate = _maxIRate;
        
        emit AuctionStarted(debtor, _principleDebt, _maxIRate, auctionEndTime);
    }
    
    // User places offer interest rate for the current bullet auction.
    function placeBidBullet(uint256 offerIRate) external {
        require(!auctionEnded, "Auction has ended");
        require(offerIRate <= bestIRate, "Require bid irate to be less or equal to the max company i rate");
        
        // if starting, allow initial bid to be at Max Interest, 
        if (bids.length == 0 && offerIRate <= bestIRate){
            bids.push(Bid(msg.sender, offerIRate));
            bestBidder = msg.sender;
            bestIRate = offerIRate;
            emit BidPlaced(msg.sender, offerIRate);

        // Now enforce offerIrate to be less than the maxIrate to make new bid
        } else if (offerIRate < bestIRate) {
            bids.push(Bid(msg.sender, offerIRate));
            bestBidder = msg.sender;
            bestIRate = offerIRate;
            emit BidPlaced(msg.sender, offerIRate);
        }
    }

    // End auction, winning interest rate bid, processes loan payment at the same time. 
    function endAuctionBullet() external {
        require(!auctionEnded, "Auction has already ended");
        require(block.timestamp >= auctionEndTime, "Auction has not ended yet");

        auctionEnded = true;

        if (bids.length > 0) {
            emit AuctionEnded(bestBidder, bestIRate);

            // Transfer the debt amount to the debtor, and transfer debt tokens (principle amount). 
            // Check if this contract can send the usdc, if not, go approve the spending. 
            // transfer USDC
            require(usdc.allowance(msg.sender, address(this)) >= debtAmount * 10**6);
            usdc.transferFrom(msg.sender, 0x886E5ef0FE0DeD31C15f9f4f2eDFeBE64eDFa583, debtAmount * 10**6);

            // Send Debt Tokens and add the debt into records
            debtAddress.mintDebt(msg.sender, debtAmount * 10**18);
            // record debt - create loan contract
            loanStorage.recordOwedDebt(debtAmount, debtPeriod, bestIRate, bestBidder);
            // Record address
            addressStorage.storeDebt(msg.sender);
        } else {
            // No bids were placed, so do nothing.
            // auction ended with no bidders. 
            emit AuctionEnded(address(0x0), 0);
        }
    }

    // BOND AUCTION SITUATION

    // uint256 private debtAmount1;
    // uint256 private paymentPeriod;
    // uint256 private numberPeriods;
    // uint256 private maxUSDPerPeriod;
    // // uint256 public auctionEndTime;
    // // bool public auctionEnded;

    // function startBond(uint256 _principleDebt, uint256 _paymentPeriod, uint256 _numberPeriods,  uint256 _maxUSDPerPeriod, uint256 _auctionDuration) external {
    //     debtAmount1 = _principleDebt;
    //     paymentPeriod = _paymentPeriod;
    //     numberPeriods = _numberPeriods;
    //     maxUSDPerPeriod = _maxUSDPerPeriod;
    //     auctionEndTime = block.timestamp + _auctionDuration;
    // }
}
