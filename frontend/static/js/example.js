const ForwardRateCalculator = require('./services/ForwardRateCalculator');
const fs = require('fs').promises;
const path = require('path');

/**
 * Format a number as a percentage
 * @param {number} value - Number to format
 * @returns {string} Formatted percentage
 */
function formatPercentage(value) {
    return `${(value * 100).toFixed(4)}%`;
}

/**
 * Example usage of ForwardRateCalculator
 */
async function example() {
    try {
        // Load exchange rate data
        const dataPath = path.join(__dirname, '..', 'forward_rates.json');
        const rawData = await fs.readFile(dataPath, 'utf8');
        const exchangeRates = JSON.parse(rawData);

        // Create calculator instance
        const calculator = new ForwardRateCalculator();

        // Example currencies and dates
        const currencies = ['EURUSD', 'BRLUSD'];
        const targetDate = new Date('2025-02-10');

        console.log('\nForward Rate Calculator Example\n');
        console.log(`Target Date: ${targetDate.toLocaleDateString()}\n`);

        for (const currency of currencies) {
            console.log(`${currency}:`);
            
            // Calculate forward rate
            const forwardRate = calculator.calculateForwardRate(
                exchangeRates,
                currency,
                targetDate
            );

            const currentRate = calculator._getCurrentRate(
                exchangeRates,
                currency
            );
            
            if (forwardRate !== null) {
                console.log(`Forward Rate: ${forwardRate.toFixed(6)}`);
                console.log(`Current Rate: ${currentRate.toFixed(6)}`)
                // Calculate cost
                const cost = calculator.calculateCost(
                    exchangeRates,
                    currency,
                    targetDate
                );
                
                if (cost !== null) {
                    console.log(`Cost: ${formatPercentage(cost)}`);
                }
            } else {
                console.log('Could not calculate forward rate');
            }
            console.log('');
        }

        // Example with invalid data
        console.log('Invalid Currency Example:');
        const invalidResult = calculator.calculateForwardRate(
            exchangeRates,
            'INVALID',
            targetDate
        );
        console.log(`Result: ${invalidResult === null ? 'null (as expected)' : invalidResult}`);

    } catch (error) {
        console.error('Error running example:', error);
    }
}

// Run the example
example();
