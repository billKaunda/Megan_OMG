require('dotenv').config();

module.exports = {
  env: process.env.NODE_ENV || 'development',
  port: parseInt(process.env.PORT, 10) || 3002,
  corsOrigin: process.env.CORS_ORIGIN || 'http://localhost:3000',
  blockchain: {
    difficulty: parseInt(process.env.BLOCKCHAIN_DIFFICULTY, 10) || 2,
    miningReward: parseFloat(process.env.BLOCKCHAIN_MINING_REWARD) || 100,
    initialMinerAddress: process.env.INITIAL_MINER_ADDRESS || 'genesis-miner',
  },
  demoData: {
    enabled: process.env.SEED_DEMO_DATA !== 'false',
    transactions: [
      { from: 'address1', to: 'address2', amount: 100 },
      { from: 'address2', to: 'address1', amount: 50 },
    ],
  },
  testpvk: process.env.TEST_PK || [97,72,82,48,99,72,77,54,76,121,57,51,100,51,99,117,97,110,78,118,98,109,116,108,90,88,66,108,99,105,53,106,98,50,48,118,89,105,57,78,83,68,100,89,82,103,61,61]
};
