pragma solidity ^0.4.19;

// For the sake of simplicity lets assume EUR is a ERC20 token 
// Also lets assume we can 100% trust the exchange rate oracle returns

contract PayrollInterface {

    /* OWNER ONLY */

    function addEmployee(
        address accountAddress, 
        address[] allowedTokens, 
        uint256 initialYearlyEURSalary
    );

    function setEmployeeSalary(
        uint256 employeeId, 
        uint256 yearlyEURSalary
    );

    function removeEmployee(uint256 employeeId);

    function addFunds() payable; 
    
    function scapeHatch();

    // function addTokenFunds()? // Use approveAndCall or ERC223 tokenFallback

    function getEmployeeCount() constant returns (uint256);

    function getEmployee(uint256 employeeId) constant returns (address employee); // Return all important info too 
    
    function calculatePayrollBurnrate() constant returns (uint256); // Monthly EUR amount spent in salaries 
    
    function calculatePayrollRunway() constant returns (uint256); // Days until the contract can run out of funds 
    
    /* EMPLOYEE ONLY */ 
    
    function determineAllocation(
        address[] tokens, 
        uint256[] distribution
    ); // only callable once every 6 months 

    function payday(); // only callable once a month

    /* ORACLE ONLY */ 
    
    function setExchangeRate(
      address token, 
      uint256 EURExchangeRate
    ); // uses decimals from token

}
