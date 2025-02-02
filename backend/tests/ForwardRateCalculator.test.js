const ForwardRateCalculator = require('../src/services/ForwardRateCalculator');
const { parseDate } = require('../src/utils/dateUtils');

/**
 * Test data setup
 */
const mockExchangeRates = [
    {
        "Date ": "01/02/2025",
        "Close": "1.0393",
        "Currency": "EURUSD"
    },
    {
        "Date ": "17/02/2025",
        "Close": "1.03902",
        "Currency": "EURUSD"
    },
    {
        "Date ": "01/02/2025",
        "Close": "0.171218",
        "Currency": "BRLUSD"
    },
    {
        "Date ": "04/03/2025",
        "Close": "0.17051",
        "Currency": "BRLUSD"
    }
];

/**
 * Test suite
 */
function runTests() {
    const calculator = new ForwardRateCalculator();
    let totalTests = 0;
    let passedTests = 0;

    function expect(actual) {
        const expectObj = {
            toBe: (expected) => {
                totalTests++;
                if (actual === expected) {
                    passedTests++;
                    return true;
                }
                console.error(`Expected ${expected} but got ${actual}`);
                return false;
            },
            toBeCloseTo: (expected, precision = 4) => {
                totalTests++;
                const diff = Math.abs(actual - expected);
                if (diff < Math.pow(10, -precision)) {
                    passedTests++;
                    return true;
                }
                console.error(`Expected ${expected} but got ${actual}`);
                return false;
            },
            toBeNull: () => {
                totalTests++;
                if (actual === null) {
                    passedTests++;
                    return true;
                }
                console.error(`Expected null but got ${actual}`);
                return false;
            },
            toBeLessThan: (expected) => {
                totalTests++;
                if (actual < expected) {
                    passedTests++;
                    return true;
                }
                console.error(`Expected ${actual} to be less than ${expected}`);
                return false;
            }
        };

        expectObj.not = {
            toBeNull: () => {
                totalTests++;
                if (actual !== null) {
                    passedTests++;
                    return true;
                }
                console.error('Expected value to not be null');
                return false;
            }
        };

        return expectObj;
    }

    console.log('\nRunning ForwardRateCalculator tests...\n');

    // Test 1: Valid EURUSD forward rate calculation
    console.log('Test 1: Valid EURUSD forward rate calculation');
    const result1 = calculator.calculateForwardRate(
        mockExchangeRates,
        'EURUSD',
        new Date('2025-02-10')
    );
    expect(result1).toBeCloseTo(1.0391);
    
    // Test 2: Valid BRLUSD forward rate calculation
    console.log('Test 2: Valid BRLUSD forward rate calculation');
    const result2 = calculator.calculateForwardRate(
        mockExchangeRates,
        'BRLUSD',
        new Date('2025-02-15')
    );
    expect(result2).toBeCloseTo(0.1709);

    // Test 3: Invalid currency forward rate
    console.log('Test 3: Invalid currency handling');
    const result3 = calculator.calculateForwardRate(
        mockExchangeRates,
        'INVALID',
        new Date('2025-02-10')
    );
    expect(result3).toBeNull();

    // Test 4: Date out of range forward rate
    console.log('Test 4: Date out of range handling');
    const result4 = calculator.calculateForwardRate(
        mockExchangeRates,
        'EURUSD',
        new Date('2026-01-01')
    );
    expect(result4).toBeNull();

    // Test 5: Invalid input data forward rate
    console.log('Test 5: Invalid input data handling');
    const result5 = calculator.calculateForwardRate(
        null,
        'EURUSD',
        new Date('2025-02-10')
    );
    expect(result5).toBeNull();

    // Test 6: Date parsing
    console.log('Test 6: Date parsing');
    const parsedDate = parseDate('01/02/2025');
    expect(parsedDate instanceof Date).toBe(true);
    expect(parsedDate.getFullYear()).toBe(2025);
    expect(parsedDate.getMonth()).toBe(1); // February is 1
    expect(parsedDate.getDate()).toBe(1);

    // Test 7: Cost calculation for EURUSD
    console.log('Test 7: EURUSD cost calculation');
    const costResult1 = calculator.calculateCost(
        mockExchangeRates,
        'EURUSD',
        new Date('2025-02-10')
    );
    expect(costResult1).not.toBeNull();
    expect(Math.abs(costResult1)).toBeLessThan(0.01);

    // Test 8: Cost calculation for BRLUSD
    console.log('Test 8: BRLUSD cost calculation');
    const costResult2 = calculator.calculateCost(
        mockExchangeRates,
        'BRLUSD',
        new Date('2025-02-15')
    );
    expect(costResult2).not.toBeNull();
    expect(Math.abs(costResult2)).toBeLessThan(0.01);

    // Test 9: Cost calculation with invalid currency
    console.log('Test 9: Cost calculation with invalid currency');
    const costResult3 = calculator.calculateCost(
        mockExchangeRates,
        'INVALID',
        new Date('2025-02-10')
    );
    expect(costResult3).toBeNull();

    // Print test results
    console.log(`\nTest Results: ${passedTests}/${totalTests} tests passed`);
}

// Run the tests
runTests();
