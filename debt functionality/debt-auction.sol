// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./debt-ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "./create-loan.sol";
import "./time-utils.sol";

contract DebtAuction {
    address usdcContract;
    address loanAddress;
    address treasury;
    TimeUtils instance = new TimeUtils();
    bool public isActive;

    constructor(address usdc, address loanContract, address companyTreasury) {
        isActive = true;
        usdcContract = usdc;
        loanAddress = loanContract;
        treasury = companyTreasury;
    }

    struct Bid {
        address bidder;
        uint256 loanAmount;
        uint256 coupon;
    }

    event AuctionFilled(address[] winners, uint256[] loanAmounts, uint256 coupon);
    event AuctionNotFilled();

    /* All of the bond debt variables, and auction tracking thing 
    */
    Bid[] public bids;
    Bid bestBid;

    /* Debt Period Length is in DAYS!!!
        Require Setup auction to only be called by a safe? Not sure if this is possible
    */
    uint256 principleDebt;
    uint256 debtPeriod;
    uint256 debtNumberOfPeriods;
    uint256 maxCoupon;
    bool callableOrNot;
    
    /* Auction end time will be in date format. So any checking will be through time-utils. 
    */
    string auctionEndTime;
    string companySymbol;

    /* Auction Length will be in days 
    */
    function setupAuction(uint256 principleAmount, 
                            uint256 periodLength, 
                            uint256 numberOfPeriods,
                            uint256 usdPerPeriod,
                            bool callable,
                            uint256 auctionLength,
                            string memory symbol
    ) public {
        require(isActive, "Auction Contract is not Active anymore");
        principleDebt = principleAmount;
        debtPeriod = periodLength;
        debtNumberOfPeriods = numberOfPeriods;
        maxCoupon = usdPerPeriod;
        callableOrNot = callable;
        auctionEndTime = instance.convertEpochToDate(block.timestamp + instance.convertEpochToDays(auctionLength));
        companySymbol = symbol;
    }

    // Approve for this transaction beforehand for testing
    function placeBid(uint256 loanAmount, uint256 paymentPerPeriod) public {
        require(isActive, "Auction contract is not active anymore");
        require(paymentPerPeriod <= maxCoupon, "Company cannot afford to pay this amount of coupon");

        // Check that user has enough funds. 
        // Still figuring out the binding function for funds to bid
        ERC20 usdc = ERC20(usdcContract);
        require(usdc.balanceOf(msg.sender) >= loanAmount, "Balance of User is less than their specified bid");
        require(usdc.allowance(msg.sender, address(this)) >= loanAmount, "User did not approve the spending of their bid amount");
        
        // Making the bid will require the user to make a deposit
        require(usdc.transferFrom(msg.sender, address(this), loanAmount*10**6), "The transfer of funds from user to the auction contract failed");

        // Just add a bid into the array, no matter what it is.
        Bid memory better = Bid(msg.sender, loanAmount, paymentPerPeriod);
        bids.push(better);
        bestBid = better;
    }

    /* Using time-utils.sol to get current time in form YYYY-MM-DD
    */
    function getCurrentTimeString() internal view returns (string memory) {
        return instance.getCurrentDate();
    }

    /* Concatenation of CORP TYPE and YYYY-MM-DD
    */
    function concat(string memory a, string memory b) internal pure returns (string memory) {
        return string(abi.encodePacked(a, b));
    }
    function concat(string memory a, string memory b, string memory c) internal pure returns (string memory) {
        return string(abi.encodePacked(a, b, c));
    }

    /* endAuction contract would be called automatically everyday at a set time, 
        findEligibleBids recursively finds the lowestCoupon that fulfills principleDebt.
    */
    function findEligibleBids(uint256 lowestCoupon) internal view returns (Bid[] memory, uint256, address[] memory) {
        uint256 smallestCoupon = maxCoupon;
        uint256 numberOfEligibleBids = 0;
        Bid[] memory eligibleBids = new Bid[](bids.length);

        // Find the eligible bids with the smallest coupon amount greater than lowestCoupon
        for (uint256 i = 0; i < bids.length; i++) {
            if (bids[i].coupon < smallestCoupon && bids[i].loanAmount > 0 && bids[i].coupon > lowestCoupon) {
                smallestCoupon = bids[i].coupon;
                numberOfEligibleBids = 0; // Reset the counter
                eligibleBids[numberOfEligibleBids] = bids[i];
                numberOfEligibleBids++;
            } else if (bids[i].coupon == smallestCoupon) {
                eligibleBids[numberOfEligibleBids] = bids[i];
                numberOfEligibleBids++;
            }
        }

        uint256 totalLoanAmount = 0;
        address[] memory finalWinners = new address[](numberOfEligibleBids);

        // Calculate the total loan amount of the eligible bids and record the eligible bidders
        for (uint256 i = 0; i < numberOfEligibleBids; i++) {
            totalLoanAmount += eligibleBids[i].loanAmount;
            finalWinners[i] = eligibleBids[i].bidder;
        }

        return (eligibleBids, totalLoanAmount, finalWinners);
    }

    uint256 smallestCoupon;

    /*  endAuction: finds Winners through all bids with findEligible, gives them tokens and transfers money, 
        also calls revoke approval. It also calls the record loan function in the other contract. dis
    */
    function endAuction() public {
        require(isActive, "Auction is not Active anymore");
        // This is commented out just for testing, no time restrictions. 
        // require(instance.compareDates(getCurrentTimeString(), auctionEndTime), "Auction has not ended yet");
        
        uint256 lowestCoupon = 0;
        uint256 totalLoanAmount;
        address[] memory winningBidders;
        uint256[] memory winningLoanAmounts;  // New array to track loanAmount for each winning bidder

        // Find the eligible bids iteratively until totalLoanAmount meets principleDebt or run out of bids
        while (true) {
            (Bid[] memory eligibleBids, uint256 currentLoanAmount, address[] memory currentWinners) = findEligibleBids(lowestCoupon);
            
            if (currentLoanAmount >= principleDebt) {
                smallestCoupon = eligibleBids[0].coupon;
                totalLoanAmount = currentLoanAmount;
                winningBidders = currentWinners;
                
                // Populate the winningLoanAmounts array with the loanAmount for each winning bidder
                winningLoanAmounts = new uint256[](winningBidders.length);
                for (uint256 i = 0; i < winningBidders.length; i++) {
                    for (uint256 j = 0; j < eligibleBids.length; j++) {
                        if (eligibleBids[j].bidder == winningBidders[i]) {
                            winningLoanAmounts[i] = eligibleBids[j].loanAmount;
                            break;
                        }
                    }
                }
                break;
            }
            
            if (eligibleBids.length == 0) {
                // No more eligible bids available
                break;
            }

            lowestCoupon = eligibleBids[0].coupon;

            if (lowestCoupon >= maxCoupon) {
                // Reached the maximum coupon level, no more eligible bids available
                break;
            }
        }

        // Change this to disable the auction contract, but not make any other changes as well. 
        // require(totalLoanAmount >= principleDebt, "No eligible bids meet the principleDebt criteria, auction has no winner");
        // Make an event for this message to be broadcasted, so frontend can pick this up and display it. 

        if (totalLoanAmount >= principleDebt) {
            // Cutting off extra bids 
            (winningBidders, winningLoanAmounts) = processWinningBids(winningBidders, winningLoanAmounts);
            
            // debtTokens distribution and USDC transferring
            distributeDebtTokens(winningBidders, winningLoanAmounts);

            emit AuctionFilled(winningBidders, winningLoanAmounts, smallestCoupon);
        }
        else {
            emit AuctionNotFilled();
        }

        require(returnFunds(), "Failed to return funds to non-winning/bidders");

        // Deactivate the contract for further use.
        isActive = false;
    }

    function returnFunds() internal returns (bool){
        // Thought: If the funds are won, then allowances are already transferred,
        // If funds are not won, everyone allowance is 0, so return everyone's funds
        for (uint256 i = 0; i < bids.length; i++) 
        {
            Bid memory specificBid = bids[i];
            uint256 refundAmount = specificBid.loanAmount;
            address bidder = specificBid.bidder;
            ERC20 usdc = ERC20(usdcContract);
            if (usdc.allowance(bidder, address(this)) > 0) {
                continue;
            } else {
                usdc.transferFrom(address(this), bidder, refundAmount*10**6);
            }
        }
        return true;
    }

    function processWinningBids(address[] memory bidders, uint256[] memory loanAmounts) internal view returns (address[] memory, uint256[] memory) {
        uint256[] memory newLoanAmounts = new uint256[](loanAmounts.length);
        address[] memory newBidders = new address[](bidders.length);
        uint256 newIndex = 0;
        uint256 summations = 0;
        
        for (uint256 i = 0; i < loanAmounts.length; i++) {
            summations += loanAmounts[i];
            
            if (summations <= principleDebt) {
                newLoanAmounts[newIndex] = loanAmounts[i];
                newBidders[newIndex] = bidders[i];
                newIndex++;
            } else {
                uint256 difference = summations - principleDebt;
                if (difference < loanAmounts[i]) {
                    newLoanAmounts[newIndex] = loanAmounts[i] - difference;
                    newBidders[newIndex] = bidders[i];
                    newIndex++;
                    summations = principleDebt;
                }
            }
        }
        
        // Resize arrays to remove excess elements
        assembly {
            mstore(newLoanAmounts, newIndex)
            mstore(newBidders, newIndex)
        }
        
        return (newBidders, newLoanAmounts);
    }


    /* This function distributes tokens, called by endAuction
    */
    function distributeDebtTokens(address[] memory winningBidders, uint256[] memory winningLoanAmounts) internal {
        // Mint tokens and record loans for the winning bids
        string memory currentDate = getCurrentTimeString();
        string memory symbolWithDash = concat(companySymbol, "-");
        string memory typeWithDash = concat("BOND", "-");
        string memory tokenIndex = concat(symbolWithDash, typeWithDash, currentDate);
        Debt token = new Debt(companySymbol, tokenIndex);
        ERC20 usdc = ERC20(usdcContract);
        for (uint256 i = 0; i < winningBidders.length; i++) {
            token.mintDebt(winningBidders[i], winningLoanAmounts[i]);  // Use winningLoanAmounts array
            // Transfer USDC to the safe
            usdc.transferFrom(winningBidders[i], treasury, winningLoanAmounts[i] * 10**6);
        }
        // call the record loan function
        recordLoan(token);
    }

    /* This function records the loan into the create-loan.sol, called by endAuction.
        Note: Smallest Coupon is a state variable so I don't have to param it
    */
    function recordLoan(Debt token) internal {
        LoanContract loan = LoanContract(loanAddress);
        loan.storeDebt(
            companySymbol,
            "BOND",
            address(token),
            principleDebt,
            debtPeriod,
            debtNumberOfPeriods,
            smallestCoupon,
            callableOrNot
        );
    }
}
