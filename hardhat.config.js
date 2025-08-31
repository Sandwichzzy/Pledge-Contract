require("@nomicfoundation/hardhat-toolbox");
require("hardhat-deploy");
require("dotenv").config();
require("solidity-coverage");
require("hardhat-gas-reporter");
/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    version: "0.8.20",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  networks: {
    hardhat: {},
    bscTestnet: {
      url: process.env.BSC_TESTNET_URL,
      accounts: [
        process.env.PRIVATE_KEY,
        process.env.PRIVATE_KEY_2,
        process.env.PRIVATE_KEY_3,
      ],
      chainId: 97,
      timeout: 120000, // 增加超时时间到 2 分钟
    },
    sepolia: {
      url: process.env.SEPOLIA_URL,
      accounts: [
        process.env.PRIVATE_KEY,
        process.env.PRIVATE_KEY_2,
        process.env.PRIVATE_KEY_3,
      ],
      chainId: 11155111,
      timeout: 120000, // 增加超时时间到 2 分钟
    },
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY,
  },

  namedAccounts: {
    deployer: {
      default: 0,
    },
    user1: {
      default: 1,
    },
    user2: {
      default: 2,
    },
  },
};
