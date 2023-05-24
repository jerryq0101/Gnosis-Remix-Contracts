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
    uint256 public auctionEndTime;
    bool public auctionEnded;
    Bid[] public bids;
    address public bestBidder;

    // uint256 amount variable is for each context.
    event BidPlaced(address indexed bidder, uint256 amount);
    event AuctionEnded(address indexed winner, uint256 amount);

    // Variables Specific to Bullet Auction
    event BulletAuctionStarted(address indexed debtor, uint256 debtAmount, uint256 maxIRate, uint256 auctionEndTime);
    uint256 public bestIRate; // Interest Rate
    uint256 public debtPeriod; // Total Debt Time
    uint256 public maxInterest; // Maximum Company's acceptable interest rate

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
        // Require this to be started by the safe 
        debtAmount = _principleDebt;
        debtPeriod = _debtTime;
        auctionEndTime = block.timestamp + _auctionDuration;
        maxInterest = _maxIRate;
        bestIRate = _maxIRate;
        
        emit BulletAuctionStarted(debtor, _principleDebt, _maxIRate, auctionEndTime);
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

        // Clear Items from array for a new auction 
        bids = new Bid[](0);
        // CLEAR ALL OTHER VARIABLES FOR ANOTHER AUCTION
    }

    
    // BOND AUCTION SITUATION
    // BOND AUCTION SITUATION
    // BOND AUCTION SITUATION


    // Variables specific to Bond auction
    uint256 public paymentPeriodBond;
    uint256 public numberPeriodsBond;
    uint256 public maxPaymentPerBond; //maximum payment per period for bond auction
    uint256 public bestPaymentBond;
    
    // Event structure (auction variables ..., endEpoch)
    event BondAuctionStarted(address indexed debtor, 
                    uint256 debtAmount, 
                    uint256 paymentPeriodBond, 
                    uint256 numberPeriodsBond,
                    uint256 maxPaymentPerBond,
                    uint256 auctionEndTime
    );

    function startBond(uint256 _principleDebt, 
                    uint256 _paymentPeriod, 
                    uint256 _numberPeriods, 
                    uint256 _maxUSDPerPeriod, 
                    uint256 _auctionDuration // I think this might be EPOCHS Test this out 
    ) public {
        // Require this to be started by the gnosis safe people
        debtAmount = _principleDebt;
        paymentPeriodBond = _paymentPeriod;
        numberPeriodsBond = _numberPeriods;
        maxPaymentPerBond = _maxUSDPerPeriod;
        auctionEndTime = block.timestamp + _auctionDuration;

        emit BondAuctionStarted(debtor, debtAmount, paymentPeriodBond, numberPeriodsBond, maxPaymentPerBond, auctionEndTime);
    }

    // Place bid Bond auction
    // OfferPayment that is the lowest wins, as the debtor has to pay the least recurring thing
    function placeBidBond(uint256 offerPayment) external {
        require(!auctionEnded, "Auction has ended");
        require(offerPayment <= maxPaymentPerBond, "Require bid irate to be less or equal to the max company i rate");
        
        // if starting, allow initial bid to be at Max Interest, 
        if (bids.length == 0 && offerPayment <= maxPaymentPerBond){
            bids.push(Bid(msg.sender, offerPayment));
            bestBidder = msg.sender;
            bestPaymentBond = offerPayment;
            emit BidPlaced(msg.sender, offerPayment);

        // Now enforce offerIrate to be less than the maxIrate to make new bid
        } else if (offerPayment < bestPaymentBond) {
            bids.push(Bid(msg.sender, offerPayment));
            bestBidder = msg.sender;
            bestPaymentBond = offerPayment;
            emit BidPlaced(msg.sender, offerPayment);
        }
    }

    // End Bond auction
    function endBondAuction() external {
        require(!auctionEnded, "Auction has already ended");
        require(block.timestamp >= auctionEndTime, "Auction has not ended yet");

        auctionEnded = true;

        if (bids.length > 0) {
            emit AuctionEnded(bestBidder, bestPaymentBond);

            // Transfer the debt amount to the debtor, and transfer debt tokens (principle amount). 
            // Check if this contract can send the usdc, if not, go approve the spending. 
            // transfer USDC
            require(usdc.allowance(msg.sender, address(this)) >= debtAmount * 10**6);
            usdc.transferFrom(msg.sender, 0x886E5ef0FE0DeD31C15f9f4f2eDFeBE64eDFa583, debtAmount * 10**6);

            // Send Debt Tokens and add the debt into records
            debtAddress.mintDebt(msg.sender, debtAmount * 10**18);
            // record debt - create loan contract. Create another option for this storage. 
            loanStorage.recordOwedDebtBond(debtAmount, paymentPeriodBond, numberPeriodsBond, bestPaymentBond, bestBidder);
            // Record address
            addressStorage.storeDebt(msg.sender);
        } else {
            // No bids were placed, so do nothing.
            // auction ended with no bidders. 
            emit AuctionEnded(address(0x0), 0);
        }

        // Clear Items from array for a new auction 
        bids = new Bid[](0);
        // Clear all other variables
        auctionEnded = false;
    }


    //  AMOR SITUATION
    //  AMOR SITUATION
    //  AMOR SITUATION

    uint256 public paymentPeriodAmor;
    uint256 public numberPeriodsAmor;
    uint256 public maxPaymentPerAmor;

    uint256 public bestPaymentAmor;

    // Event structure (auction variables ..., endEpoch)
    event AmorAuctionStarted(address indexed debtor, 
                    uint256 debtAmount, 
                    uint256 paymentPeriodAmor, 
                    uint256 numberPeriodsAmor,
                    uint256 maxPaymentPerAmor,
                    uint256 auctionEndTime
    );

    function startAmor(uint256 _principleDebt, 
                    uint256 _paymentPeriod, 
                    uint256 _numberPeriods, 
                    uint256 _maxUSDPerPeriod, 
                    uint256 _auctionDuration // I think this might be EPOCHS Test this out 
    ) public {
        // Require this to be started by the gnosis safe people
        debtAmount = _principleDebt;
        paymentPeriodAmor = _paymentPeriod;
        numberPeriodsAmor = _numberPeriods;
        maxPaymentPerAmor = _maxUSDPerPeriod;
        auctionEndTime = block.timestamp + _auctionDuration;

        emit AmorAuctionStarted(debtor, debtAmount, paymentPeriodBond, numberPeriodsBond, maxPaymentPerBond, auctionEndTime);
    }

    // Place bid Bond auction
    // OfferPayment that is the lowest wins, as the debtor has to pay the least recurring thing.
    // For Amor, this offerPayment per payment needs to >= principleLoan 
    function placeBidAmor(uint256 offerPayment) external {
        require(!auctionEnded, "Auction has ended");
        require(offerPayment <= maxPaymentPerAmor, "Require bid irate to be less or equal to the max company i rate");
        
        // if starting, allow initial bid to be at Max Interest, 
        if (bids.length == 0 && offerPayment <= maxPaymentPerAmor){
            bids.push(Bid(msg.sender, offerPayment));
            bestBidder = msg.sender;
            bestPaymentAmor = offerPayment;
            emit BidPlaced(msg.sender, offerPayment);

        // Now enforce offerIrate to be less than the maxIrate to make new bid
        } else if (offerPayment < bestPaymentAmor) {
            bids.push(Bid(msg.sender, offerPayment));
            bestBidder = msg.sender;
            bestPaymentAmor = offerPayment;
            emit BidPlaced(msg.sender, offerPayment);
        }
    }

    // End Bond auction
    function endAmorAuction() external {
        require(!auctionEnded, "Auction has already ended");
        require(block.timestamp >= auctionEndTime, "Auction has not ended yet");

        auctionEnded = true;

        if (bids.length > 0) {
            emit AuctionEnded(bestBidder, bestPaymentAmor);

            // Transfer the debt amount to the debtor, and transfer debt tokens (principle amount). 
            // Check if this contract can send the usdc, if not, go approve the spending. 
            // transfer USDC
            require(usdc.allowance(msg.sender, address(this)) >= debtAmount * 10**6);
            usdc.transferFrom(msg.sender, 0x886E5ef0FE0DeD31C15f9f4f2eDFeBE64eDFa583, debtAmount * 10**6);

            // Send Debt Tokens and add the debt into records
            debtAddress.mintDebt(msg.sender, debtAmount * 10**18);
            // record debt - create loan contract. Create another option for this storage. 
            loanStorage.recordOwedDebtAmor(debtAmount, paymentPeriodAmor, numberPeriodsAmor, bestPaymentAmor, bestBidder);
            // Record address
            addressStorage.storeDebt(msg.sender);
        } else {
            // No bids were placed, so do nothing.
            // auction ended with no bidders. 
            emit AuctionEnded(address(0x0), 0);
        }

        // Clear Items from array for a new auction 
        bids = new Bid[](0);
        // Clear all other variables
        auctionEnded = false;
    }

}
