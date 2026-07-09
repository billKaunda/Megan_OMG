/**
 * Truncates a long hex hash for display: "abcd1234...efgh5678"
 */
export const truncateHash = (hash, chars = 8) => {
  if (!hash || hash.length <= chars * 2) return hash;
  return `${hash.slice(0, chars)}...${hash.slice(-chars)}`;
};

/**
 * Formats a Unix-ms timestamp into a human-readable locale string.
 */
export const formatTimestamp = (timestamp) => {
  if (!timestamp) return 'N/A';
  return new Date(timestamp).toLocaleString();
};

/**
 * Formats a numeric amount with up to 8 decimal places, stripping trailing zeros.
 */
export const formatAmount = (amount, decimals = 8) => {
  if (amount === null || amount === undefined) return '0';
  return parseFloat(Number(amount).toFixed(decimals)).toString();
};

/**
 * Returns "Mining Reward" when fromAddress is null (coinbase tx).
 */
export const formatAddress = (address) => {
  if (!address) return 'Mining Reward';
  return address;
};
