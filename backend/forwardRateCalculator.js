/**
 * Calculate forward rate based on exchange rate data
 * @param {Object[]} data - JSON data containing exchange rates
 * @param {string} currency - Currency to filter by (e.g., "EURUSD")
 * @param {Date} givenDate - Reference date for calculation
 * @returns {Object} Calculation results including forward rate and reference dates
 */
function calculateForwardRate(data, currency, givenDate) {
    try {
        // Convert givenDate to timestamp for comparison
        const Jd = givenDate.getTime();

        // Filter by currency and parse dates
        const filteredRates = data
            .filter(rate => rate.Currency === currency)
            .map(rate => ({
                date: parseDate(rate["Date "]),  // Note the space after "Date"
                rate: parseFloat(rate.Close)
            }))
            .sort((a, b) => a.date.getTime() - b.date.getTime());

        if (filteredRates.length === 0) {
            throw new Error(`No data found for currency: ${currency}`);
        }

        // Find anterior and posterior dates
        let dateAnterieure = null;
        let datePosterieure = null;
        let tauxAnterieur = null;
        let tauxPosterieur = null;

        for (let i = 0; i < filteredRates.length; i++) {
            const currentDate = filteredRates[i].date.getTime();
            
            if (currentDate <= Jd) {
                dateAnterieure = currentDate;
                tauxAnterieur = filteredRates[i].rate;
            } else {
                datePosterieure = currentDate;
                tauxPosterieur = filteredRates[i].rate;
                break;
            }
        }

        // Handle edge cases
        if (!dateAnterieure) {
            throw new Error('No anterior date found - given date is before all available dates');
        }
        if (!datePosterieure) {
            throw new Error('No posterior date found - given date is after all available dates');
        }

        // Calculate forward rate using the formula
        const Ja = dateAnterieure;
        const Jp = datePosterieure;
        const Ta = tauxAnterieur;
        const Tp = tauxPosterieur;

        // Calculate time differences in days
        const msPerDay = 24 * 60 * 60 * 1000;
        const totalDays = (Jp - Ja) / msPerDay;
        const daysToTarget = (Jd - Ja) / msPerDay;
        
        // Calculate weights for interpolation
        const weightAnterieur = (totalDays - daysToTarget) / totalDays;
        const weightPosterieur = daysToTarget / totalDays;
        
        // Calculate forward rate using weighted average
        const tauxForward = (weightAnterieur * Ta) + (weightPosterieur * Tp);

        return {
            success: true,
            forwardRate: tauxForward,
            dateAnterieure: new Date(dateAnterieure),
            datePosterieure: new Date(datePosterieure),
            tauxAnterieur: Ta,
            tauxPosterieur: Tp
        };
    } catch (error) {
        return {
            success: false,
            error: error.message
        };
    }
}

/**
 * Parse date from DD/MM/YYYY format
 * @param {string} dateStr - Date string in DD/MM/YYYY format
 * @returns {Date} Parsed date object
 */
function parseDate(dateStr) {
    const [day, month, year] = dateStr.trim().split('/');
    return new Date(year, month - 1, day);
}

// Example usage and test function
function testCalculation() {
    const jsonData = require('./forward_rates.json');
    
    // Test cases
    const testCases = [
        {
            currency: 'EURUSD',
            date: new Date('2025-02-10'),  // Between 01/02/2025 and 17/02/2025
            description: 'EURUSD mid-February'
        },
        {
            currency: 'BRLUSD',
            date: new Date('2025-03-15'),  // Between 04/03/2025 and 02/04/2025
            description: 'BRLUSD mid-March'
        }
    ];

    testCases.forEach(test => {
        console.log(`\nTesting ${test.description}:`);
        const result = calculateForwardRate(jsonData, test.currency, test.date);
        console.log(result);
    });
}

// Export for use in other modules
module.exports = calculateForwardRate;

// Uncomment to run tests
testCalculation();
