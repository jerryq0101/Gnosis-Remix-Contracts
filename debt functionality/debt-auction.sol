pragma solidity ^0.8.0;

import "./debt-ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "./create-loan.sol";
import "./time-utils.sol";

contract DebtAuction {
    address usdcContract;
    address loanAddress;
    TimeUtils instance = new TimeUtils();

    constructor(address usdc, address loanContract) {
        usdcContract = usdc;
        loanAddress = loanContract;
    }

    struct Bid {
        address bidder;
        uint256 loanAmount;
        uint256 coupon;
    }

    /* All of the bond debt variables, and auction tracking shit
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
        principleDebt = principleAmount;
        debtPeriod = periodLength;
        debtNumberOfPeriods = numberOfPeriods;
        maxCoupon = usdPerPeriod;
        callableOrNot = callable;
        auctionEndTime = instance.convertEpochToDate(block.timestamp + instance.convertEpochToDays(auctionLength));
        companySymbol = symbol;
    }

    function placeBid(uint256 loanAmount, uint256 paymentPerPeriod) public {
        require(paymentPerPeriod <= maxCoupon, "Company cannot afford to pay this amount of coupon");
        if (bids.length > 0) {
            require(paymentPerPeriod < bestBid.coupon, "Cannot bid more than the last offered coupon");
        }
        // Make user call approve for their USDC

        // We are sure that this is a better bid
        Bid memory better = Bid(msg.sender,loanAmount, paymentPerPeriod);
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
        address[] memory winners = new address[](bids.length);

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

    function endAuction() public {
        require(instance.compareDates(getCurrentTimeString(), auctionEndTime), "Auction has not ended yet");
        
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

        require(totalLoanAmount >= principleDebt, "No eligible bids meet the principleDebt criteria, auction has no winner");

        // Mint tokens and record loans for the winning bids
        string memory currentDate = getCurrentTimeString();
        string memory symbolWithDash = concat(companySymbol, "-");
        string memory typeWithDash = concat("BOND", "-");
        string memory tokenIndex = concat(symbolWithDash, typeWithDash, currentDate);
        Debt token = new Debt(companySymbol, tokenIndex);
        for (uint256 i = 0; i < winningBidders.length; i++) {
            token.mintDebt(winningBidders[i], winningLoanAmounts[i]);  // Use winningLoanAmounts array
        }
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
