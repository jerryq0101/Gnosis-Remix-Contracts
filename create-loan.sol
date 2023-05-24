pragma solidity ^0.8.0;

import "./debt-ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

contract LoanContract {

    // structure for a default loan
    struct BulletLoan {
        address lender;
        uint256 amount;
        uint256 interestRate;
        uint256 repaymentPeriod;
        uint256 startTime;
        uint256 index;
        bool repaid;
    }

    // All owedDebtBullet ledger
        // First record the loanCounter and its corresponding loanType index in "loanType" 
        // add thing into the type of mapping
    mapping(uint256 => BulletLoan) public owedDebtBullet;
    mapping(uint256 => uint256) public loanType;
    // 0:BulletLoan, 1:BondLoan, 2: AmorLoan


    // All owed debt situation will have a unique # (incremented per loan)
    uint256 public loanCounter;

    // Note
        // So loan counter will continue to be incremented with every loan
        // Thus, for each type of loan, the count represents its order as well as which mapping to get loan from.
        // Which the loanType is for. 

    // A way to get current debt for the person. 
    mapping(address => BulletLoan[]) public currentAddressDebt;

    event bulletLoanRecorded(uint256 loanId, address indexed lender, uint256 amount, uint256 interestRate);

    Debt private debtToken;
    address private safeAddress;
    ERC20 usdc = ERC20(0x07865c6E87B9F70255377e024ace6630C1Eaa37F);

    constructor(Debt debtContract, address safe) {
        debtToken = debtContract;
        safeAddress = safe;
    }

    // recording owed debt from the company. 
    function recordOwedDebtBullet(uint256 amount, uint256 debtTime, uint256 interestRate, address lender) external {
        // require the one to call this function to be the debt auction contract!!!
        BulletLoan storage newLoan = owedDebtBullet[loanCounter];
        newLoan.amount = amount;
        newLoan.lender = lender; 
        newLoan.interestRate = interestRate;
        newLoan.repaymentPeriod = debtTime;
        newLoan.startTime = block.timestamp;
        newLoan.repaid = false;
        
        // Add BulletLoan to the all bullet loans mapping, and set loan type to bullet, and address specific loan array
        owedDebtBullet[loanCounter] = newLoan;
        loanType[loanCounter] = 0;
        currentAddressDebt[lender].push(newLoan);
        loanCounter++;
        emit bulletLoanRecorded(loanCounter, lender, amount, interestRate);
    }

    // for frontend data.
    function retrieveActiveLoans(address lender) public view returns (BulletLoan[] memory){
        return currentAddressDebt[lender];
    }

    // P2P transactions of debt

        // On the UI, all loans for an ADDRESS will be displayed, and its index will be displayed as well
        // The user is able to select the 'INDEX' of loan that they own and switch its owner. 
        // This is called by the user that wants to switch the owner of the loan. Should make another-
        // -one for 'admins' 
    
    function transferOwnedDebt(uint256 index, address newOwner) external {
        // Retrieve the loan details
        BulletLoan storage exchangedLoan = owedDebtBullet[index];
        address originalLender = exchangedLoan.lender;

        // Transfer USDC from the new owner to the original lender
        uint256 debtAmount = exchangedLoan.amount * exchangedLoan.interestRate;
        require(usdc.transferFrom(newOwner, originalLender, debtAmount), "USDC transfer failed");

        // Update the lender to the new owner
        exchangedLoan.lender = newOwner;
    }

    // called by the lender, to retrieve their profits.
    // THIS DOESN"T WORK AT THE MOMENT DUE TO THE REPAYMENT THINGY
    function retrieveProfits() external {
        BulletLoan[] memory loans = currentAddressDebt[msg.sender];

        // loop through all of the loans to execute the existing debts to REPAY
        for (uint i = 0; i <loans.length; i++){
            BulletLoan memory someloan = loans[i];

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
                owedDebtBullet[someloan.index].repaid = true;
            }
        }
    }


    // BOND LOAN SITUATION

    // structure for a bond loan
    struct BondLoan {
        address lender;
        uint256 amount;
        uint256 paymentPeriod;
        uint256 numberPeriods;
        uint256 usdPaymentPer;
        uint256 startTime;
        uint256 index;
        bool repaid; 
        uint256 curPaymentPeriod;
    }

    // All owedDebtBullet ledger
    mapping(uint256 => BondLoan) public owedDebtBond;

    // A way to get current debt for the person. 
    mapping(address => BondLoan[]) public currentAddressDebtBond;

    event bondLoanRecorded(uint256 loanId, 
            address indexed lender, 
            uint256 amount, 
            uint256 paymentPeriod,
            uint256 numberPeriods,
            uint256 paymentPerPeriod,
            uint256 startTime,
            bool repaid
    );

    // recording owed debt from the company. 
    // ALL OF THE PERIODS HERE HAVE TO BE IN EPOCHs
    function recordOwedDebtBond(uint256 amount, uint256 paymentPeriod, uint256 numberPeriods, uint256 paymentPerPeriod, address lender) external {
        // require the one to call this function to be the debt auction contract!!!
        BondLoan storage newLoan = owedDebtBond[loanCounter];
        newLoan.amount = amount;
        newLoan.lender = lender; 
        newLoan.paymentPeriod = paymentPeriod;
        newLoan.numberPeriods = numberPeriods;
        newLoan.usdPaymentPer = paymentPerPeriod;
        newLoan.startTime = block.timestamp;
        newLoan.repaid = false;
        newLoan.curPaymentPeriod = 1;
        
        // Add BulletLoan to the all bullet loans mapping, and set loan type to bullet, and address specific loan array
        owedDebtBond[loanCounter] = newLoan;
        loanType[loanCounter] = 1;
        currentAddressDebtBond[lender].push(newLoan);
        loanCounter++;
        emit bondLoanRecorded(loanCounter, lender, amount, paymentPeriod, numberPeriods, paymentPerPeriod, newLoan.startTime, false);
    }


    // UI will display all of the user's loans, so they will be able to retrieve it using index
    function retrievePeriodicInterest(uint256 index) public {
        BondLoan memory bond = owedDebtBond[index];
        require(bond.curPaymentPeriod <= bond.numberPeriods, "Already collected enough periodic payments");
        require(block.timestamp - bond.startTime >= (bond.paymentPeriod * bond.curPaymentPeriod), "Not enough time for the next period yet");
            // require that the current payment period is not over total allowed
            // require that elapsed time for collecting periodic payment is enough  

        // increase allowance function would need to be called either beforehand or an approve function by the gnosis safe
        require(usdc.allowance(safeAddress, address(this)) >= bond.usdPaymentPer, "There's not enough allowance for the transfer to take place");
        require(usdc.transferFrom(safeAddress, msg.sender, bond.usdPaymentPer), "TransferFrom Failed");
    }

} 
