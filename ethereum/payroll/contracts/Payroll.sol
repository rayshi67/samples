pragma solidity ^0.4.17;

import "./PayrollInterface.sol";

contract Payroll is PayrollInterface {
    
	address owner;  // contract owner address
	
	address oracle;  // authorised oracle address

    uint256 totalAnnualSalariesEUR;


	/** Employee */
	
    struct Employee {
    	address accountAddress;  // employee Ether aaccount
    	address[] allowedTokens;  // ERC20 token contract addresses employee uses to receive the payment
      	uint256 lastPayDay;  // timestamp for last time employee gets paid
      	uint256 annualSalaryEUR;  // annual salary in EUR
    }
    
    Employee[] employees;
    
    uint256 lastEmployeeId = 0;  // the last employee ID
    
    uint256 employeeCount = 0;  // number of current employees
    
    mapping (address => uint256) employeeIds;  // mapping of the employee address to the employee array index

        
	/** Tokens */
	
	struct Token {
        address tokenAddress;  // address of the ERC20 token contract
        uint256 exchangeRateEUR;  // token to EUR exchange rate
    }
    
    Token[] tokens;
	
	mapping(address => uint256) tokenIds;  // mapping of the token address to the token array index

	
	/** Constructors */
	
	function Payroll(address _oracle) public {
        owner = msg.sender;
        oracle = _oracle;
    }
    
	
	/** Modifiers */

    modifier ifOwner() {
    	require(msg.sender == owner);
    	_;
    }
    
    modifier ifEemployee() {
    	require(employeeIds[msg.sender] > 0);
    	_;
    }
    
    modifier ifOracle() {
    	require(msg.sender == oracle);
    	_;
    }
    

    /* OWNER ONLY */

    function addEmployee(
        address accountAddress, 
        address[] allowedTokens, 
        uint256 initialYearlyEURSalary
	) public ifOwner returns(uint256 employeeId) {
	
		require(initialYearlyUSDSalary > 0);
	
		// validate all the tokens are allowed
		
        for (uint i = 0; i < allowedTokens.length; i++) {
            require(tokenIds[allowedTokens[i]] > 0);
        }
        
        // now add the new employee
        
    	uint256 employeeId = lastEmployeeId++;
    	employeeCount++;
        
        employees[employeeId] = Employee(
            accountAddress,
            allowedTokens,
            0,
            initialYearlyEURSalary
        );

        employeeIds[accountAddress] = employeeId;
        
        _updateTotalAnnualSalaries(0, initialYearlyEURSalary);

        return employeeId;
    }
    
    function _updateTotalAnnualSalaries(
        uint256 currentSalaryEUR,
        uint256 newSalaryEUR) internal {

        totalAnnualSalariesEUR += newSalaryEUR - currentSalaryEUR;
    }

    function _updateEmployeeSalary(
        uint256 employeeId,
        uint256 newSalaryEUR) internal {

        Employee storage emp = employees[employeeId];
        _updateTotalYearlySalaries(emp.annualSalaryEUR, newSalaryEUR);
        emp.annualSalaryEUR = newSalaryEUR;
    }

    function setEmployeeSalary(
        uint256 employeeId, 
        uint256 yearlyEURSalary
    ) public ifOwner {

        require(yearlyEURSalary > 0);

        _updateEmployeeSalary(employeeId, yearlyEURSalary);
    }

    function removeEmployee(uint256 employeeId) public ifOwner {
        Employee storage emp = employees[employeeId];
        delete employeeIds[emp.accountAddress];
        delete employees[employeeId];
        employeeCount--;
    }






    function addFunds() payable; 
    


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
