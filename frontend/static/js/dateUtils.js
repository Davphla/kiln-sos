/**
 * Constants for date calculations
 */
export const MS_PER_DAY = 24 * 60 * 60 * 1000;

/**
 * Parse date from DD/MM/YYYY format
 * @param {string} dateStr - Date string in DD/MM/YYYY format
 * @returns {Date} Parsed date object
 * @throws {Error} If date format is invalid
 */
export function parseDate(dateStr) {
    if (!dateStr || typeof dateStr !== 'string') {
        throw new Error('Invalid date string provided');
    }

    const [day, month, year] = dateStr.trim().split('/');
    
    if (!day || !month || !year) {
        throw new Error('Invalid date format. Expected DD/MM/YYYY');
    }

    const date = new Date(year, month - 1, day);
    
    if (isNaN(date.getTime())) {
        throw new Error('Invalid date values');
    }

    return date;
}

/**
 * Calculate number of days between two dates
 * @param {Date} date1 - First date
 * @param {Date} date2 - Second date
 * @returns {number} Number of days between dates
 */
export function calculateDaysDifference(date1, date2) {
    return (date2.getTime() - date1.getTime()) / MS_PER_DAY;
}

/**
 * Calculate interpolation weights based on target date
 * @param {Date} dateAnterieure - Previous reference date
 * @param {Date} datePosterieure - Next reference date
 * @param {Date} targetDate - Target date for interpolation
 * @returns {{weightAnterieur: number, weightPosterieur: number}} Interpolation weights
 */
export function calculateInterpolationWeights(dateAnterieure, datePosterieure, targetDate) {
    const totalDays = calculateDaysDifference(dateAnterieure, datePosterieure);
    const daysToTarget = calculateDaysDifference(dateAnterieure, targetDate);
    
    return {
        weightAnterieur: (totalDays - daysToTarget) / totalDays,
        weightPosterieur: daysToTarget / totalDays
    };
}

/**
 * Add a specified number of days to a date
 * @param {Date} date - The starting date
 * @param {number} days - Number of days to add
 * @returns {Date} New date with added days
 */
export function addDays(date, days) {
    const newDate = new Date(date);
    newDate.setDate(newDate.getDate() + days);
    return newDate;
}
