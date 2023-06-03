pragma solidity ^0.8.0;

import "./debt-ERC20.sol";
import "./time-utils.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

contract LoanContract {

    ERC20 public usdcContract;
    address public moduleAddress;

    constructor(address usdc, address module) {
        usdcContract = ERC20(usdc);
        moduleAddress = module;
    }

    struct Loan {
        uint256 principleAmount;
        uint256 paymentPeriodLength;
        uint256 numberPaymentPeriods;
        uint256 usdPerPeriod;
        bool callable;
        bool repaid;
        address debtAddress;
    }

    /* bytes32 - the final repayment date for principle - 2023-08-20 
        Loan[] - loan list that need to be repaid on this date
    */
    mapping(bytes32 => Loan[]) dateToLoans;
    /*  bytes32 - each debt's index: ACORP-BOND-2023-08-20-01
        Loan - specific debt that matches up with the index
    */
    mapping(bytes32 => Loan) indexToLoan;
    /*  bytes32 - date for periodic payment
        Loan[] - debt that has periodic payment on this date
    */
    mapping(bytes32 => Loan[]) periodicDateToLoans;


    // function addStruct(string memory key, uint256 value1, string memory value2) public {
    //     bytes32 hashedKey = keccak256(abi.encodePacked(key));
        
    //     MyStruct memory myStruct = MyStruct(value1, value2);
    //     myStructMapping[hashedKey] = myStruct;
    // }

    // function getStruct(string memory key) public view returns (MyStruct memory) {
    //     bytes32 hashedKey = keccak256(abi.encodePacked(key));

    //     return myStructMapping[hashedKey];
    // }

    // Getters for these mappings
    function getLoansFromDate(string memory date) public view returns (Loan[] memory){
        bytes32 hashedDate = keccak256(abi.encodePacked(date));
        return dateToLoans[hashedDate];
    }
    
    function getLoanFromIndex(string memory index) public view returns (Loan memory){
        bytes32 hashedIndex = keccak256(abi.encodePacked(index));
        return indexToLoan[hashedIndex];
    }   

    function getLoansFromPeriodicDate(string memory date) public view returns (Loan[] memory){
        bytes32 hashedDate = keccak256(abi.encodePacked(date));
        return periodicDateToLoans[hashedDate];
    }

    /* Using time-utils.sol to get current time in form YYYY-MM-DD
    */
    function getCurrentTimeString() internal returns (string memory) {
        TimeUtils instance = new TimeUtils();
        return instance.getCurrentDate();
    }

    function getPaymentDateString(uint256 paymentPeriodInDays, uint256 numberOfPeriods) internal returns (string memory) {
        TimeUtils instance = new TimeUtils();
        return instance.getFutureDate(paymentPeriodInDays, numberOfPeriods);
    }

    /* Get Hashed key for byte32 storage in every mapping
    */
    function getHashedKey(string memory date) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(date));
    }

    /* Concatenation of CORP TYPE and YYYY-MM-DD
    */
    function concat(string memory a, string memory b) internal pure returns (string memory) {
        return string(abi.encodePacked(a, b));
    }
    function concat(string memory a, string memory b, string memory c) internal pure returns (string memory) {
        return string(abi.encodePacked(a, b, c));
    }

    /*  Store debt and its essential variables
        Currently only the bond variables for now.

        paymentPeriodLength (days)

        REQUIRE THIS TO ONLY BE CALLED BY AUCTION CONTRACT
    */

    function storeDebt(string memory Symbol, 
                        string memory Type, 
                        address debtTokenAddress,
                        uint256 principleAmount,
                        uint256 paymentPeriodLength,
                        uint256 numberPaymentPeriods,
                        uint256 coupon,
                        bool callable
    ) external {

        Loan memory newLoan = Loan(principleAmount, paymentPeriodLength, numberPaymentPeriods, coupon, callable, false, debtTokenAddress);
        // Store this loan
        string memory formattedString = getPaymentDateString(paymentPeriodLength, numberPaymentPeriods);
        bytes32 hashedDate = getHashedKey(formattedString);
        
        // Final Repayment of Principle Amount Store
        dateToLoans[hashedDate].push(newLoan);
        // Setup periodic repayment, load future date onto mapping
        for (uint i = 1; i < numberPaymentPeriods ; i++) 
        {
            string memory periodicDate = getPaymentDateString(paymentPeriodLength, i);
            bytes32 hashedPeriodicDate = getHashedKey(periodicDate);
            periodicDateToLoans[hashedPeriodicDate].push(newLoan);
        }
        // Token index to loan struct
        string memory SymbolWithDash = concat(Symbol, "-");
        string memory TypeWithDash = concat(Type, "-");
        string memory TokenIndex = concat(SymbolWithDash, TypeWithDash, formattedString);
        bytes32 hashedTokenIndex = getHashedKey(TokenIndex);
        indexToLoan[hashedTokenIndex] = newLoan;

        /*
            ^ This currently does not support n'th variable at the end, 
            so the same company CANNOT issue two debt taht ends at the same time.

            Also, the tokenindex should rather be passed into this contract by the auction contract,
            which creates the ERC20 with tokenindex and calls storeDebt with tokenindex, so this will be removed
        */
    }

    /* Finding all of the periodic payment loans that needs payment today
    */
    function allPeriodicRepaymentLoanToday() internal returns (Loan[] memory){
        string memory todayDate = getCurrentTimeString();
        require(getLoansFromPeriodicDate(todayDate).length > 0, 
            "There's no periodic payment period that ends today");
        
        /* All of the loan details for payment today
        */
        return periodicDateToLoans[getHashedKey(todayDate)];
    }

    /*  Finding all debt token addresses that need periodic payment today, in order for the frontend
        to find all the tokenholders for these erc20 tokens.
    */
    function getDebtAddressesPeriodicToday() public returns (address[] memory) {
        Loan[] memory periodicPaymentToday = allPeriodicRepaymentLoanToday();
        /* Store debt addresses in erc20 to give to external service to find tokenholders
        */
        address[] memory debtAddresses = new address[](periodicPaymentToday.length);
        for (uint i = 0; i < periodicPaymentToday.length; i++) 
        {
            debtAddresses[i] = periodicPaymentToday[i].debtAddress;
        }
        return debtAddresses;
    }

    // ^ Make the same one but for principleDebt repayment

    /* Finding all of the final repayment principle loans today 
    */

    function allFinalRepaymentLoanToday() internal returns (Loan[] memory){
        string memory todayDate = getCurrentTimeString();
        require(getLoansFromDate(todayDate).length > 0, 
            "There's no periodic payment period that ends today");
        
        /* All of the loan details for payment today
        */
        return dateToLoans[getHashedKey(todayDate)];
    }

    /* Finding all of the erc20 debt addresses for the final principle loans
    */
    function getDebtAddressesFinalToday() public returns (address[] memory) {
        Loan[] memory finalPaymentToday = allFinalRepaymentLoanToday();
        /* Store debt addresses in erc20 to give to external service to find tokenholders
        */
        address[] memory debtAddresses = new address[](finalPaymentToday.length);
        for (uint i = 0; i < finalPaymentToday.length; i++) 
        {
            debtAddresses[i] = finalPaymentToday[i].debtAddress;
        }
        return debtAddresses;
    }


    /*  This is the periodic payment function for all loans that have periodic payments today.
        Frontend calls getDebtAddressesPeriodicToday(), and uses that to get all tokenHolders, 
        and then calls periodicRepayment.

        address[][] holds all of token holders, each address[] being the tokenholders list 
        of a loan.

        Loops through all of the tokenholders and pays them each respective coupon in Loan[]
    */
    function periodicRepayment(address[][] memory tokenHolders) public {
        require(tokenHolders.length > 0, "There's no loan to do repayment to today");

        Loan[] memory periodicPaymentToday = allPeriodicRepaymentLoanToday();

        for (uint i = 0; i < tokenHolders.length; i++) 
        {   
            Loan memory instance = periodicPaymentToday[i];
            uint256 coupon = instance.usdPerPeriod;
            address debtAddress = instance.debtAddress;
            ERC20 debtContract = ERC20(debtAddress);
            uint256 totalTokens = debtContract.totalSupply();

            // Check if the company is not broke
            require(usdcContract.balanceOf(0x886E5ef0FE0DeD31C15f9f4f2eDFeBE64eDFa583) >= coupon, 
                "The company is broke, AHHHHHHHHHHH");
            // check if the company had allowed this to happen
            require(usdcContract.allowance(0x886E5ef0FE0DeD31C15f9f4f2eDFeBE64eDFa583, address(this)) >= coupon, 
                "There is not enough allowance to transfer this coupon");

            for (uint j = 0; j < tokenHolders[i].length; j++) 
            {
                address tokenHolder = tokenHolders[i][j];
                uint256 balance = debtContract.balanceOf(tokenHolders[i][j]);
                uint256 proportion = Math.mulDiv(coupon, balance, totalTokens);
                usdcContract.transferFrom(0x886E5ef0FE0DeD31C15f9f4f2eDFeBE64eDFa583, tokenHolder, proportion);
            }
        }
    }
    
    /*  Same thing as the above, but for final repayment situations

        address[][] holds all of token holders, each address[] being the tokenholders list 
        of a loan.

        Loops through all of the tokenholders and pays them each respective coupon in Loan[]
    */

    function finalRepayment(address[][] memory tokenHolders) public {
        require(tokenHolders.length > 0, "There's no loan to do repayment to today");

        Loan[] memory finalRepaymentToday = allFinalRepaymentLoanToday();

        for (uint i = 0; i < tokenHolders.length; i++) 
        {   
            Loan memory instance = finalRepaymentToday[i];
            uint256 principleAmount = instance.principleAmount;
            address debtAddress = instance.debtAddress;
            ERC20 debtContract = ERC20(debtAddress);
            uint256 totalTokens = debtContract.totalSupply();

            // Check if the company is not broke
            require(usdcContract.balanceOf(0x886E5ef0FE0DeD31C15f9f4f2eDFeBE64eDFa583) >= principleAmount, 
                "The company is broke, it's over frick");
            // check if the company had allowed this to happen
            require(usdcContract.allowance(0x886E5ef0FE0DeD31C15f9f4f2eDFeBE64eDFa583, address(this)) >= principleAmount, 
                "There is not enough allowance to transfer this coupon");

            for (uint j = 0; j < tokenHolders[i].length; j++) 
            {
                address tokenHolder = tokenHolders[i][j];
                uint256 balance = debtContract.balanceOf(tokenHolders[i][j]);
                uint256 proportion = Math.mulDiv(principleAmount, balance, totalTokens);
                usdcContract.transferFrom(0x886E5ef0FE0DeD31C15f9f4f2eDFeBE64eDFa583, tokenHolder, proportion);
            }
        }
    }
}