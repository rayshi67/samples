pragma solidity ^0.4.17;

import "tokens/eip20/EIP20.sol";
import "./DateTime.sol";
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
    
    /**
     * Mapping of the employee address to the employee array index,
     * The array index actually starts from 1, so that it can check for condition where mapping key does not exist.
     */
    mapping (address => uint256) employeeIds;

        
    /** Tokens */
	
    // Assume we can get their ETH/EUR exchange rates via ETH token address.
    address tokenETH;

	// For the sake of simplicity lets assume EUR is a ERC20 token 
	address tokenEUR;
	
    struct TokenExchange {
        address token;  // ERC20 token address
        uint256 exchangeRateEUR;  // EUR to token exchange rate
    }
    
    TokenExchange[] exchangableTokens;
 
    uint256 lastExchangableTokenId = 0;  // the last exchangable token ID

    /**
     * Mapping of the token address to the array index,
     * The array index actually starts from 1, so that it can check for condition where mapping key does not exist.
     */   	
    mapping(address => uint256) exchangableTokenIds;


	/*
	 *  Authorised oracle address
	 *  Assume we can 100% trust Oracle,
	 *  Assume also Oracle calls back to set exchange rates while the contract is constructed.
	 */
    address oracle;
    
	
    /** Constructors */
	
    function Payroll(address _oracle, address _tokenEUR, address _tokenETH) public {
        owner = msg.sender;
        oracle = _oracle;
        tokenEUR = _tokenEUR;
        tokenETH = _tokenETH;
        
        exchangableTokens.push(TokenExchange({
            	token: tokenEUR,
            	exchangeRateEUR: 1
        }));

        exchangableTokenIds[tokenEUR] = lastExchangableTokenId++;
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
        
    	employeeId = ++lastEmployeeId;
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
    
    function getEmployeeCount() public constant ifOwner returns(uint256) {
    	return employeeCount;
    }

    function getEmployee(uint256 employeeId) public constant ifOwner
    	returns(address accountAddress, bool active, uint256 lastAllocationDay, uint256 annualSalaryEUR, uint256 lastPayDay) {
		
		Employee storage emp = employees[employeeId];
        
        accountAddress = emp.accountAddress;
        active = emp.active;
        lastAllocationDay = emp.lastAllocationDay;
        annualSalaryEUR = emp.annualSalaryEUR;
        lastPayDay = emp.lastPayDay;
	}
    
    // Monthly EUR amount spent in salaries
    function calculatePayrollBurnrate() public constant ifOwner returns(uint256) {
     	return totalAnnualSalariesEUR / 12;
    }
    
    // Days until the contract can run out of funds, or -1 if there is no burn rate.
    function calculatePayrollRunway() public constant ifOwner returns(uint256) {
        uint256 dailyBurnRateEUR = totalAnnualSalariesEUR / 365;

        if (dailyBurnRateEUR == 0) {
            return uint256(-1);
        }

        uint256 balanceEUR = this.balance / exchangableTokens[exchangableTokenIds[tokenETH]].exchangeRateEUR;

        return balanceEUR / dailyBurnRateEUR;
    }
    

    /* EMPLOYEE ONLY */ 
    
    /**
     * Reset the token allocation for employee.
     * Only callable once every 6 months.
     */
    function determineAllocation(
        address[] tokens, 
        uint256[] distribution
    ) public ifActiveEmployee {
    
    	require(tokens.length == distribution.length);
    	
    	// check all tokens are allowed for the employee
        uint i;

        for (i = 0; i < tokens.length; i++) {
        	require(employee.allowedTokens[tokens[i]]);
        }

		// check all distribution adds up to 100
        uint totalDistribution = 0;
        for (i = 0; i < distribution.length; i++) {
        	totalDistribution += distribution[i];
        }
        
        require(totalDistribution == 100);

        uint256 employeeId = employeeIds[msg.sender];
    	Employee storage employee = employees[employeeId];
    
        // is it more than 6 months since last allocation
        require(now > _addMonths(6, employee.lastAllocationDay));
    
    	address[] memory distributionTokenList;
    	uint256[] memory distributionInPercentageList;

      	// if no token is given, assume EUR is used
        if (tokens.length == 0) {
        	distributionTokenList = new address[](1);
        	distributionTokenList[0] = tokenEUR;

        	distributionInPercentageList = new uint256[](1);
        	distributionInPercentageList[0] = 100;
    	} else {
      		distributionTokenList = tokens;
      		distributionInPercentageList = distribution;
    	}
    
		// now set the new allocation
    	employee.lastAllocationDay = now;
    	employee.distributionTokenList = distributionTokenList;
    	employee.distributionInPercentageList = distributionInPercentageList;
    }

	/**
	 * Make monthly payment to employee as per the token distributions.
	 * Only callable once a month.
	 */
    function payday() public ifActiveEmployee {
        Employee storage employee = employees[employeeIds[msg.sender]];
        
        // is it more than 1 month since last payday
        if (!(now > _addMonths(1, employee.lastPayDay))) {
            revert();
        }
        
        uint256 monthlyPayEUR = employee.annualSalaryEUR / 12;
        
        for (uint i = 0; i < employee.distributionTokenList.length; i++) {
        	address token = employee.distributionTokenList[i];
        	
            uint256 monthlyTokenPayEUR = monthlyPayEUR * employee.distributionInPercentageList[i] / 100;
            uint256 monthlyTokenPay = monthlyTokenPayEUR * exchangableTokens[exchangableTokenIds[token]].exchangeRateEUR;

			// send the payment            
            require(EIP20(token).transfer(msg.sender, monthlyTokenPay));            
        }
        
        // now set the new pay day
        employee.lastPayDay = now;
    }
    
    /**
     * Return a unix timestamp that is the given timestamp plus the given months.
     * @param months the number of months to add
     * @param timestamp the unix timestamp
     */
    function _addMonths(uint8 months, uint timestamp) pure internal returns(uint) {
        DateTime dateTime = DateTime(address(0x1a6184CD4C5Bea62B0116de7962EE7315B7bcBce));
        uint16 year = dateTime.getYear(timestamp);
        uint8 month = dateTime.getMonth(timestamp);
        
        month += months;
        while (month > 12) {
            month -= 12;
            year++;
        }
        
        return dateTime.toTimestamp(
            year,
            month,
            dateTime.getDay(timestamp),
            dateTime.getHour(timestamp),
            dateTime.getMinute(timestamp),
            dateTime.getSecond(timestamp)
        );
    }


    /* ORACLE ONLY */ 
    
    function setExchangeRate(
      address token, 
      uint256 exchangeRateEUR
    ) public ifOracle {
    	
    	require (exchangeRateEUR > 0);
    	
    	uint256 exchangableTokenId = exchangableTokenIds[token];
    	
    	if (exchangableTokenId == 0) {  // new token exchange
    	    uint256 tokenId = ++lastExchangableTokenId;

        	exchangableTokens[tokenId] = TokenExchange({
            	token: token,
            	exchangeRateEUR: exchangeRateEUR
        	});
        	
        	// add new token the mapping
        	exchangableTokenIds[token] = tokenId;
        	
        	return;
    	}
    
        // update existing token exchange
        exchangableTokens[exchangableTokenId].token = token;
        
       	// uses decimals from token
        exchangableTokens[exchangableTokenId].exchangeRateEUR = exchangeRateEUR * EIP20(token).decimals();
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
