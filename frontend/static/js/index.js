/**
 * @typedef {Object} ExchangeRate
 * @property {string} Date - Date in DD/MM/YYYY format
 * @property {string} Close - Exchange rate value
 * @property {string} Currency - Currency pair code
 */

/**
 * @typedef {Object} ForwardRateResult
 * @property {boolean} success - Whether the calculation was successful
 * @property {number} [forwardRate] - Calculated forward rate
 * @property {Date} [dateAnterieure] - Previous reference date
 * @property {Date} [datePosterieure] - Next reference date
 * @property {number} [tauxAnterieur] - Rate for previous date
 * @property {number} [tauxPosterieur] - Rate for next date
 * @property {string} [error] - Error message if calculation failed
 */

module.exports = {};  // Types are only used for JSDoc documentation
