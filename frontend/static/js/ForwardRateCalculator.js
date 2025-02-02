import { parseDate, calculateInterpolationWeights } from './dateUtils.js'

export default class ForwardRateCalculator {
    /**
     * Create a new ForwardRateCalculator instance
     * @param {Function} [dateParser] - Custom date parsing function (optional)
     */
    constructor(dateParser = parseDate) {
        this.dateParser = dateParser;
    }

    /**
     * Filter and sort exchange rates by currency
     * @private
     * @param {Array<ExchangeRate>} data - Raw exchange rate data
     * @param {string} currency - Currency to filter by
     * @returns {Array<{date: Date, rate: number}>} Filtered and sorted rates
     */
    _filterAndSortRates(data, currency) {
        return data
            .filter(rate => rate.Currency === currency)
            .map(rate => ({
                date: this.dateParser(rate["Date "]),
                rate: parseFloat(rate.Close)
            }))
            .sort((a, b) => a.date.getTime() - b.date.getTime());
    }

    /**
     * Find nearest reference dates and rates
     * @private
     * @param {Array<{date: Date, rate: number}>} rates - Filtered rates
     * @param {Date} targetDate - Target date for calculation
     * @returns {{dateAnterieure: number, datePosterieure: number, tauxAnterieur: number, tauxPosterieur: number}}
     * @throws {Error} If reference dates cannot be found
     */
    _findReferenceRates(rates, targetDate) {
        const targetTime = targetDate.getTime();
        let dateAnterieure = null;
        let datePosterieure = null;
        let tauxAnterieur = null;
        let tauxPosterieur = null;

        for (let i = 0; i < rates.length; i++) {
            const currentDate = rates[i].date.getTime();
            
            if (currentDate <= targetTime) {
                dateAnterieure = currentDate;
                tauxAnterieur = rates[i].rate;
            } else {
                datePosterieure = currentDate;
                tauxPosterieur = rates[i].rate;
                break;
            }
        }

        if (!dateAnterieure) {
            throw new Error('No anterior date found - target date is before all available dates');
        }
        if (!datePosterieure) {
            throw new Error('No posterior date found - target date is after all available dates');
        }

        return {
            dateAnterieure,
            datePosterieure,
            tauxAnterieur,
            tauxPosterieur
        };
    }

    /**
     * Get current rate for a given currency
     * @private
     * @param {Array<ExchangeRate>} data - Exchange rate data
     * @param {string} currency - Currency to look for
     * @returns {number} Current rate
     * @throws {Error} If current rate cannot be found
     */
    _getCurrentRate(data, currency) {
        const currentRates = data
            .filter(rate => rate.Currency === currency)
            .map(rate => ({
                date: this.dateParser(rate["Date "]),
                rate: parseFloat(rate.Close)
            }))
            .sort((a, b) => a.date.getTime() - b.date.getTime()); // Sort by earliest date first

        if (currentRates.length === 0) {
            throw new Error(`No current rate found for currency: ${currency}`);
        }

        return currentRates[0].rate;
    }

    /**
     * Internal method to calculate forward rate with full details
     * @private
     * @param {Array<ExchangeRate>} data - Exchange rate data
     * @param {string} currency - Currency to calculate for
     * @param {Date} targetDate - Target date for calculation
     * @returns {Object} Full calculation result
     * @throws {Error} If calculation fails
     */
    _calculateForwardRateWithDetails(data, currency, targetDate) {
        if (!Array.isArray(data) || data.length === 0) {
            throw new Error('Invalid or empty data provided');
        }
        if (!currency || typeof currency !== 'string') {
            throw new Error('Invalid currency provided');
        }
        if (!(targetDate instanceof Date) || isNaN(targetDate.getTime())) {
            throw new Error('Invalid target date provided');
        }

        const filteredRates = this._filterAndSortRates(data, currency);
        
        if (filteredRates.length === 0) {
            throw new Error(`No data found for currency: ${currency}`);
        }

        const {
            dateAnterieure,
            datePosterieure,
            tauxAnterieur,
            tauxPosterieur
        } = this._findReferenceRates(filteredRates, targetDate);

        const { weightAnterieur, weightPosterieur } = calculateInterpolationWeights(
            new Date(dateAnterieure),
            new Date(datePosterieure),
            targetDate
        );

        const forwardRate = (weightAnterieur * tauxAnterieur) + (weightPosterieur * tauxPosterieur);

        return {
            forwardRate,
            dateAnterieure: new Date(dateAnterieure),
            datePosterieure: new Date(datePosterieure),
            tauxAnterieur,
            tauxPosterieur
        };
    }

    /**
     * Calculate forward rate for given currency and date
     * @param {Array<ExchangeRate>} data - Exchange rate data
     * @param {string} currency - Currency to calculate for
     * @param {Date} targetDate - Target date for calculation
     * @returns {number|null} Forward rate or null if calculation fails
     */
    calculateForwardRate(data, currency, targetDate) {
        try {
            const result = this._calculateForwardRateWithDetails(data, currency, targetDate);
            return result.forwardRate;
        } catch (error) {
            return null;
        }
    }

    /**
     * Calculate cost based on forward rate and current rate
     * @param {Array<ExchangeRate>} data - Exchange rate data
     * @param {string} currency - Currency to calculate for
     * @param {Date} targetDate - Target date for calculation
     * @returns {number|null} Cost or null if calculation fails
     */
    calculateCost(data, currency, targetDate) {
        try {
            const forwardRate = this.calculateForwardRate(data, currency, targetDate);
            if (forwardRate === null) {
                return null;
            }

            const currentRate = this._getCurrentRate(data, currency);
            return (forwardRate / currentRate) - 1;
        } catch (error) {
            return null;
        }
    }
}