const MockOracle = artifacts.require("./mocks/MockOracle.sol");
const EIP20 = artifacts.require("tokens/eip20/EIP20.sol");
const Payroll = artifacts.require("../contracts/Payroll.sol");

const ETH_EUR_EXCHANGE_RATE = 1000;
const BTC_EUR_EXCHANGE_RATE = 10000;
const XRP_USD_EXCHANGE_RATE = 2;

contract("Payroll", (accounts) => {
    const OWNER = accounts[0];
    const EMPLOYEE_1 = accounts[1];
    const EMPLOYEE_2 = accounts[2];
    const EMPLOYEE_3 = accounts[3];

    let oracle;
    let eur;
    let eth;
    let btc;
    let xrp;
    let payroll;

    beforeEach(async () => {
        oracle = await MockOracle.new();
        eur = await EIP20.new();
        eth = await EIP20.new();
        btc = await EIP20.new();
        xrp = await EIP20.new();

        payroll = await Payroll.new(oracle.address, eur.address, eth.address);

        // configure exchange rates
        await oracle.setExchangeRate(payroll.address, eth.address, ETH_EUR_EXCHANGE_RATE);
        await oracle.setExchangeRate(payroll.address, btc.address, BTC_EUR_EXCHANGE_RATE);
        await oracle.setExchangeRate(payroll.address, xrp.address, XRP_USD_EXCHANGE_RATE);
    });

    it("should have no employee on creation", async () => {
        const numEmployees = await payroll.getEmployeeCount();
        assert.equal(numEmployees, 0);
    });

    it("should have no burn rate on creation", async () => {
        const burnRate = await payroll.calculatePayrollBurnrate();
        assert.equal(burnRate, 0);
    });

    it("should have an endless runway on creation", async () => {
        const END_OF_TIME = 115792089237316195423570985008687907853269984665640564039457584007913129639935;
        const runway = await payroll.calculatePayrollRunway();
        assert.equal(runway.toNumber(), END_OF_TIME);
    });

    it("should add new employees", async () => {
        await payroll.addEmployee(EMPLOYEE_1, [btc.address, xrp.address], 150000);
        let numEmployees = await payroll.getEmployeeCount();
        assert.equal(numEmployees, 1);

        await payroll.addEmployee(EMPLOYEE_2, [], 150000);
        numEmployees = await payroll.getEmployeeCount();
        assert.equal(numEmployees, 2);
    });

    it("should not add an already added employee", async () => {
        await payroll.addEmployee(EMPLOYEE_1, [btc.address, xrp.address], 150000);

        try {
            await payroll.addEmployee(EMPLOYEE_1, [btc.address, xrp.address], 150000);
        } catch (error) {
            assertJump(error);
        }
    });

});

function assertJump (error) {
    assert.equal(error.message.search("invalid opcode"), -1);
}
