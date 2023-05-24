pragma solidity ^0.8.0;

import "./debt-ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

contract LoanContract {

    // structure for a default loan
    struct Loan {
        address lender;
        uint256 amount;
        uint256 interestRate;
        uint256 repaymentPeriod;
        uint256 startTime;
        uint256 index;
        bool repaid;
    }

    // All owedDebt ledger
    mapping(uint256 => Loan) public owedDebt;

    // All owedDebt will have a unique # (incremented per loan)
    uint256 public loanCounter;

    // A way to get current debt for the person. 
    mapping(address => Loan[]) public currentAddressDebt;

    event loanRecorded(uint256 loanId, address indexed lender, uint256 amount, uint256 interestRate);

    Debt private debtToken;
    address private safeAddress;
    ERC20 usdc = ERC20(0x07865c6E87B9F70255377e024ace6630C1Eaa37F);

    constructor(Debt debtContract, address safe) {
        debtToken = debtContract;
        safeAddress = safe;
    }

    // recording owed debt from the company. 
    function recordOwedDebt(uint256 amount, uint256 debtTime, uint256 interestRate, address lender) external {
        // require the one to call this function to be the debt auction contract!!!
        Loan storage newLoan = owedDebt[loanCounter];
        newLoan.amount = amount;
        newLoan.lender = lender; 
        newLoan.interestRate = interestRate;
        newLoan.repaymentPeriod = debtTime;
        newLoan.startTime = block.timestamp;
        newLoan.repaid = false;
        
        // Add Loan to total loans, and address specific loan array. 
        owedDebt[loanCounter] = newLoan;
        currentAddressDebt[lender].push(newLoan);
        loanCounter++;
        emit loanRecorded(loanCounter, lender, amount, interestRate);
    }

    // for frontend data.
    function retrieveActiveLoans(address lender) public view returns (Loan[] memory){
        return currentAddressDebt[lender];
    }

    // called by the lender, to retrieve their profits.
    // THIS DOESN"T WORK AT THE MOMENT DUE TO THE REPAYMENT THINGY
    function retrieveProfits() external {
        Loan[] memory loans = currentAddressDebt[msg.sender];

        // loop through all of the loans to execute the existing stuff
        for (uint i = 0; i <loans.length; i++){
            Loan memory someloan = loans[i];

            // repayment period is arrived!
            if (someloan.repaymentPeriod + someloan.startTime >= block.timestamp) {
                // repay the loan with interest
                require(debtToken.balanceOf(msg.sender) >= someloan.amount);
                // BURN THE DEBT!!!! (tokens amount is the same as principleDebt)
                debtToken.transferFrom(msg.sender, address(0x0), someloan.amount * 10**18);

                uint256 calculation = 0; // I don't know how to implement these power calculations yet.
                require(usdc.allowance(0x886E5ef0FE0DeD31C15f9f4f2eDFeBE64eDFa583, address(this)) >= calculation * 10**6);
                require(usdc.balanceOf(0x886E5ef0FE0DeD31C15f9f4f2eDFeBE64eDFa583) >= calculation * 10**6);
                usdc.transferFrom(0x886E5ef0FE0DeD31C15f9f4f2eDFeBE64eDFa583, someloan.lender, calculation * 10**6);

                // Set Repaid = true, so the liquidation func doesn't screw this up.
                owedDebt[someloan.index].repaid = true;
            }
        }
    }

} 
