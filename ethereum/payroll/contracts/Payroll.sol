pragma solidity ^0.4.17;

import "./PayrollInterface.sol";

contract Payroll is PayrollInterface {
    
    address owner;  // contract owner address

    uint256 totalAnnualSalariesEUR;


    /** Employee */
	
    struct Employee {
    	address accountAddress;  // employee address
    	bool active;
    	mapping(address => bool) allowedTokens;  // token contract addresses employee is allowed to have
      	uint256 lastAllocationDay;  // timestamp for last time employee changes pay distribution
      	uint256 lastPayDay;  // timestamp for last time employee gets paid
      	address[] distributionTokenList;
        uint256[] distributionInPercentageList;
      	uint256 annualSalaryEUR;  // annual salary in EUR
    }

    Employee[] employees;
    
    uint256 lastEmployeeId = 0;  // the last employee ID
    
    uint256 employeeCount = 0;  // number of current employees
    
    mapping (address => uint256) employeeIds;  // mapping of the employee address to the employee array index

        
    /** Tokens */
	
	// For the sake of simplicity lets assume EUR is a ERC20 token 
	address tokenEUR;
	
    struct TokenExchange {
        address token;  // ERC20 token address
        uint256 exchangeRateEUR;  // token to EUR exchange rate
    }
    
    TokenExchange[] exchangableTokens;
    
    uint256 lastExchangableTokenId = 0;  // the last exchangable token ID
	
    mapping(address => uint256) exchangableTokenIds;  // mapping of the token address to the token array index


	/*
	 *  Authorised oracle address
	 *  Assume we can 100% trust Oracle,
	 *  Assume also Oracle calls back to set exchange rates while the contract is constructed.
	 */
    address oracle;
    
	
    /** Constructors */
	
    function Payroll(address _oracle, address _tokenEUR) public {
        owner = msg.sender;
        oracle = _oracle;
        tokenEUR = _tokenEUR;
        
        uint256 exchangableTokenId = lastExchangableTokenId++;
        
        exchangableTokens[exchangableTokenId] = TokenExchange(
            tokenEUR,
            1  // EUR to EUR exchange rate
        );

        exchangableTokenIds[tokenEUR] = exchangableTokenId;
    }
    

    /* OWNER ONLY */

    function addEmployee(
        address accountAddress, 
        address[] allowedTokens, 
        uint256 initialYearlyEURSalary
    ) public ifOwner returns(uint256 employeeId) {

        require(
            initialYearlyEURSalary > 0 &&
            accountAddress != address(0) &&
            employeeIds[accountAddress] == 0  // not an existing employee 
        );
        
        // now add the new employee
        
    	employeeId = lastEmployeeId++;
    	employeeCount++;

        address[] memory distributionTokenList = new address[](1);
        distributionTokenList[0] = tokenEUR;

        uint256[] memory distributionInPercentageList = new uint256[](1);
        distributionInPercentageList[0] = 100;

        employees[employeeId] = Employee({
            accountAddress: accountAddress,
            active: true,
            lastAllocationDay: 0,
            lastPayDay: 0,
            distributionTokenList: distributionTokenList,
            distributionInPercentageList: distributionInPercentageList,
            annualSalaryEUR: initialYearlyEURSalary
        });

        // validate all the tokens are exchangable before adding to the mapping

        for (uint i = 0; i < allowedTokens.length; i++) {
            require(exchangableTokenIds[allowedTokens[i]] > 0);
            employees[employeeId].allowedTokens[allowedTokens[i]] = true;
        }

        employeeIds[accountAddress] = employeeId;
        
        _updateTotalAnnualSalaries(0, initialYearlyEURSalary);

        return employeeId;
    }
    
    function _updateTotalAnnualSalaries(
        uint256 currentSalaryEUR,
        uint256 newSalaryEUR
    ) internal {
        totalAnnualSalariesEUR += newSalaryEUR - currentSalaryEUR;
    }

    function _updateEmployeeSalary(
        uint256 employeeId,
        uint256 newSalaryEUR
    ) internal {
        Employee storage emp = employees[employeeId];
        _updateTotalAnnualSalaries(emp.annualSalaryEUR, newSalaryEUR);
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
        emp.active = false;

        _updateEmployeeSalary(employeeId, 0);
        employeeCount--;
    }

    function addFunds() payable public returns(string) {
        LogFundsAdded(msg.value);
    	return "OK";
    }
    
    function getEmployeeCount() public constant returns(uint256) {
    	return employeeCount;
    }

    function getEmployee(uint256 employeeId) public constant
    	returns(address accountAddress, bool active, uint256 lastAllocationDay, uint256 annualSalaryEUR, uint256 lastPayDay) {
		
		Employee storage emp = employees[employeeId];
        
        accountAddress = emp.accountAddress;
        active = emp.active;
        lastAllocationDay = emp.lastAllocationDay;
        annualSalaryEUR = emp.annualSalaryEUR;
        lastPayDay = emp.lastPayDay;
	}
    
    // Monthly EUR amount spent in salaries
    function calculatePayrollBurnrate() public constant returns(uint256) {
     	return totalAnnualSalariesEUR / 12;
    }



    
    // Days until the contract can run out of funds 
    function calculatePayrollRunway() public constant returns(uint256) {
        // TODO
    }
    

    /* EMPLOYEE ONLY */ 
    
    function determineAllocation(
        address[] tokens, 
        uint256[] distribution
    ) public {
        // TODO
    }

    function payday() public {
        // TODO
    }


    /* ORACLE ONLY */ 
    
    // uses decimals from token
    function setExchangeRate(
      address token, 
      uint256 exchangeRateEUR
    ) public ifOracle {
        // TODO
    }


    /** Modifiers */

    modifier ifOwner() {
    	require(msg.sender == owner);
    	_;
    }
    
    modifier ifActiveEmployee() {
    	require(employees[employeeIds[msg.sender]].active);
    	_;
    }
    
    modifier ifOracle() {
    	require(msg.sender == oracle);
    	_;
    }


    /** events */
    event LogFundsAdded(uint256 amount);

}
