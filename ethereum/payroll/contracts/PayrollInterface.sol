pragma solidity ^0.4.17;

// Assume we can 100% trust the exchange rate oracle returns

contract PayrollInterface {


    /* OWNER ONLY */

    function addEmployee(
        address accountAddress, 
        address[] allowedTokens, 
        uint256 initialYearlyEURSalary
    ) public returns(uint256 employeeId);

    function setEmployeeSalary(
        uint256 employeeId, 
        uint256 yearlyEURSalary
    ) public;

    function removeEmployee(uint256 employeeId) public;

    function addFunds() payable public returns(string); 

    function getEmployeeCount() public constant returns(uint256);

    function getEmployee(uint256 employeeId) public constant
    	returns(address accountAddress, address[] allowedTokens, uint256 annualSalaryEUR, uint256 lastPayDay); 
    
    function calculatePayrollBurnrate() public constant returns(uint256); // Monthly EUR amount spent in salaries 
    
    function calculatePayrollRunway() public constant returns(uint256); // Days until the contract can run out of funds 


    /* EMPLOYEE ONLY */ 
    
    function determineAllocation(
        address[] tokens, 
        uint256[] distribution
    ) public; // only callable once every 6 months 

    function payday() public; // only callable once a month


    /* ORACLE ONLY */ 
    
    function setExchangeRate(
      address token, 
      uint256 EURExchangeRate
    ) public; // uses decimals from token


    /* Escape Hatch */

    // TODO if time permitted
    //function escapeHatch(bool escapeHatchInd) public;

}
