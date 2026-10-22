import "dotenv/config";
import { resolve } from "node:path";
import { config as loadDotEnv } from "dotenv";
import type { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-ethers";
import "@nomicfoundation/hardhat-chai-matchers";
import "@nomicfoundation/hardhat-network-helpers";
import "@nomicfoundation/hardhat-verify";
// hardhat-verify must be imported before hardhat-upgrades so proxy/beacon verification is intercepted.
import "@openzeppelin/hardhat-upgrades";
import "@typechain/hardhat";
import "hardhat-deploy";
import "hardhat-deploy-ethers";
import "./tasks/set-vault-peer-minter";

// Support package commands that are run directly from contracts/, not only the
// Horizon root orchestrator (which has already loaded the workspace .env).
loadDotEnv({ path: resolve(__dirname, "../.env") });

const accounts = (key: string | undefined): string[] => (key ? [key] : []);

const getOptionalBlockNumber = (value: string | undefined): number | undefined => {
  if (!value) return undefined;
  const parsed = Number.parseInt(value, 10);
  if (Number.isNaN(parsed)) {
    throw new Error(`Invalid block number: "${value}"`);
  }
  return parsed;
};

/** Default fork target: Mezo testnet. Override with FORK_RPC_URL / FORK_BLOCK_NUMBER. */
const hardhatForkRpcUrl =
  process.env.FORK_RPC_URL?.trim() ||
  process.env.MEZO_TESTNET_RPC_URL?.trim() ||
  "https://rpc.test.mezo.org";
const hardhatForkBlockNumber = getOptionalBlockNumber(process.env.FORK_BLOCK_NUMBER);

const config: HardhatUserConfig = {
  // Solidity settings below are the source of truth for this package.
  // Keep foundry.toml in lockstep (solc, optimizer, viaIR, evmVersion).
  // Mezo mainnet RPC accepts Cancun opcodes (verified via eth_call probes).
  solidity: {
    version: "0.8.28",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
      viaIR: true,
      // Match live Mezo (Cancun). Fork hardfork must match so PUSH0 contracts execute.
      evmVersion: "cancun",
    },
  },
  namedAccounts: { deployer: { default: 0 } },
  networks: {
    hardhat: {
      hardfork: "cancun",
      // Opt-in: set FORK_ENABLED=1 so unit/deploy paths stay offline by default.
      ...(process.env.FORK_ENABLED === "1" || process.env.FORK_ENABLED === "true"
        ? {
            // Match Mezo testnet so address/code resolution and chain checks work.
            chainId: 31611,
            forking: {
              url: hardhatForkRpcUrl,
              ...(hardhatForkBlockNumber !== undefined
                ? { blockNumber: hardhatForkBlockNumber }
                : {}),
            },
          }
        : {}),
      // EDR requires a hardfork activation history for forked chain ids.
      chains: {
        31611: {
          hardforkHistory: {
            berlin: 0,
            london: 0,
            arrowGlacier: 0,
            grayGlacier: 0,
            merge: 0,
            shanghai: 0,
            cancun: 0,
          },
        },
        31612: {
          hardforkHistory: {
            berlin: 0,
            london: 0,
            arrowGlacier: 0,
            grayGlacier: 0,
            merge: 0,
            shanghai: 0,
            cancun: 0,
          },
        },
      },
    },
    localhost: { url: process.env.LOCALHOST_RPC_URL ?? "http://127.0.0.1:8545" },
    testnet: {
      url: process.env.MEZO_TESTNET_RPC_URL?.trim() || "https://rpc.test.mezo.org",
      chainId: 31611,
      accounts: accounts(process.env.TESTNET_PRIVATE_KEY),
    },
    mainnet: {
      url: process.env.MEZO_MAINNET_RPC_URL?.trim() || "",
      chainId: 31612,
      accounts: accounts(process.env.MAINNET_PRIVATE_KEY),
    },
    baseSepolia: {
      url: process.env.BASE_SEPOLIA_RPC_URL ?? "https://sepolia.base.org",
      chainId: 84532,
      accounts: accounts(process.env.BASE_SEPOLIA_PRIVATE_KEY),
    },
    base: {
      url: process.env.BASE_RPC_URL ?? "https://mainnet.base.org",
      chainId: 8453,
      accounts: accounts(process.env.BASE_PRIVATE_KEY),
    },
  },
  paths: { sources: "src", deploy: "deploy/scripts", deployments: "deployments" },
  typechain: { outDir: "typechain", target: "ethers-v6" },
  mocha: {
    timeout: 300_000,
  },
  etherscan: {
    apiKey: {
      testnet: "empty",
      mainnet: "empty",
      baseSepolia: process.env.BASESCAN_API_KEY ?? process.env.ETHERSCAN_API_KEY ?? "",
      base: process.env.BASESCAN_API_KEY ?? process.env.ETHERSCAN_API_KEY ?? "",
    },
    customChains: [
      {
        network: "testnet",
        chainId: 31611,
        urls: {
          apiURL: "https://api.explorer.test.mezo.org/api",
          browserURL: "https://explorer.test.mezo.org",
        },
      },
      {
        network: "mainnet",
        chainId: 31612,
        urls: {
          apiURL: "https://api.explorer.mezo.org/api",
          browserURL: "https://explorer.mezo.org",
        },
      },
    ],
  },
  // Mezo Blockscout is Etherscan-compatible and does not require an API key.
  // Hardhat-verify's Sourcify client is API v1 (retired). Deploy scripts submit Sourcify v2.
  sourcify: {
    enabled: false,
  },
};

export default config;
