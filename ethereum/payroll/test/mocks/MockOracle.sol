pragma solidity ^0.4.17;

import "../../contracts/PayrollInterface.sol";

contract MockOracle {

    function setExchangeRate(
        address payroll, 
        address token, 
        uint256 exchangeRate
    ) public {

        PayrollInterface(payroll).setExchangeRate(token, exchangeRate);
    }

}
