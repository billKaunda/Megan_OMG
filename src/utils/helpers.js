/**
 * Returns true when the provided value is a non-empty string after trimming.
 */
export const isNonEmptyString = (value) =>
  typeof value === 'string' && value.trim().length > 0;

/**
 * Returns true when the value parses to a finite, positive number.
 */
export const isPositiveNumber = (value) => {
  const n = parseFloat(value);
  return !isNaN(n) && isFinite(n) && n > 0;
};

/**
 * Clamps a number between min and max (inclusive).
 */
export const clamp = (value, min, max) => Math.min(Math.max(value, min), max);

/**
 * Deep-clones a JSON-serialisable object.
 */
export const deepClone = (obj) => JSON.parse(JSON.stringify(obj));

/**
 * Groups an array of transactions by block index.
 */
export const groupTransactionsByBlock = (chain = []) =>
  chain.reduce((acc, block, index) => {
    acc[index] = block.transactions || [];
    return acc;
  }, {});
