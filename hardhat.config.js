
require('dotenv').config();
require("@nomiclabs/hardhat-ethers");

const privateKey = process.env.privateKey;

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  networks: {
    bsc: {
      url: process.env.bscRpc || "https://bsc-dataseed.binance.org/",
      accounts: [privateKey]
    },
    polygon: {
      url: process.env.polygonRpc || "https://rpc-mainnet.matic.network",
      accounts: [privateKey]
    },
    metis: {
      url: process.env.metis_rpc || "https://andromeda.metis.io/?owner=1088",
      accounts: [privateKey]
    }
  },
  solidity: {
    version: "0.6.12",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  },
};
