pragma solidity ^0.8.0;

contract TimeUtils {
    function getCurrentDate() public view returns (string memory) {
        return _formatDate(block.timestamp);
    }

    /* There might be some BS with the 1 days constant*/
    function getFutureDate(uint256 paymentPeriodInDays, uint256 numberOfPeriods) public view returns (string memory) {
        uint256 futureTimestamp = block.timestamp + (paymentPeriodInDays * 1 days * numberOfPeriods);
        return _formatDate(futureTimestamp);
    }

    function getFutureTimestamp(uint256 paymentPeriodInDays, uint256 numberOfPeriods) public view returns (uint256) {
        uint256 futureTimestamp = block.timestamp + (paymentPeriodInDays * 1 days * numberOfPeriods);
        return futureTimestamp;
    }

    function convertEpochToDate(uint256 timestamp) public pure returns (string memory) {
        return _formatDate(timestamp);
    }

    function compareDates(string memory date1, string memory date2) public pure returns (bool) {
        return bytes(date1).length == bytes(date2).length && keccak256(bytes(date1)) == keccak256(bytes(date2));
    }

    function convertEpochToDays(uint256 timestamp) public pure returns (uint256) {
        uint256 daysSinceEpoch = timestamp / (1 days);
        return daysSinceEpoch;
    }

    function _formatDate(uint256 timestamp) internal pure returns (string memory) {
        uint256 day = 86400; // Number of seconds in a day

        // Calculate the components of the date
        uint256 secondsAccountedFor = 0;
        uint256 year = 1970;
        uint256 month = 1;
        uint256 dayOfMonth;

        uint256[] memory monthLengths = new uint256[](12);
        monthLengths[0] = 31;
        monthLengths[1] = 28;
        monthLengths[2] = 31;
        monthLengths[3] = 30;
        monthLengths[4] = 31;
        monthLengths[5] = 30;
        monthLengths[6] = 31;
        monthLengths[7] = 31;
        monthLengths[8] = 30;
        monthLengths[9] = 31;
        monthLengths[10] = 30;
        monthLengths[11] = 31;

        while (true) {
            uint256 yearLength = _isLeapYear(year) ? 366 : 365;
            if (timestamp >= secondsAccountedFor + day * yearLength) {
                secondsAccountedFor += day * yearLength;
                year++;
            } else {
                uint256 index = 0;
                for (index = 0; index < 12; index++) {
                    uint256 monthLength = monthLengths[index];
                    if (index == 1 && _isLeapYear(year)) {
                        monthLength += 1; // Leap year, February has 29 days
                    }
                    if (timestamp >= secondsAccountedFor + day * monthLength) {
                        secondsAccountedFor += day * monthLength;
                        month++;
                    } else {
                        break;
                    }
                }
                dayOfMonth = (timestamp - secondsAccountedFor) / day + 1;
                break;
            }
        }

        // Convert the components into a string format "YYYY-MM-DD"
        string memory yearStr = _uintToString(year);
        string memory monthStr = _uintToString(month);
        string memory dayStr = _uintToString(dayOfMonth);

        // Add leading zeros if necessary
        if (bytes(monthStr).length < 2) {
            monthStr = string(abi.encodePacked("0", monthStr));
        }
        if (bytes(dayStr).length < 2) {
            dayStr = string(abi.encodePacked("0", dayStr));
        }

        string memory date = string(abi.encodePacked(yearStr, "-", monthStr, "-", dayStr));
        return date;
    }

    function _isLeapYear(uint256 year) internal pure returns (bool) {
        if (year % 4 != 0) {
            return false;
        }
        if (year % 100 != 0) {
            return true;
        }
        if (year % 400 != 0) {
            return false;
        }
        return true;
    }

    function _uintToString(uint256 num) internal pure returns (string memory) {
        if (num == 0) {
            return "0";
        }

        uint256 temp = num;
        uint256 digits;

        while (temp != 0) {
            digits++;
            temp /= 10;
        }

        bytes memory buffer = new bytes(digits);

        while (num != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + (num % 10)));
            num /= 10;
        }

        return string(buffer);
    }
}
