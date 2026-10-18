/**
 * Known Aurove Id20 wrapper addresses used by managed vault deploys.
 * Source: packages/id20/deployments/{mainnet,testnet}.
 */
export const ID20_MAINNET = {
  avBTCm: "0xf333171788dE7005695b2E8FB9cAE97Ba9c4dD7a",
  avMEZOm: "0xb894b11A78B762c82Cb095148F5BC11DC93C3560",
} as const;

export const ID20_TESTNET = {
  avBTCm: "0xf2aeB53d71CD541EFeaA37788F0841D7d21612F9",
  avMEZOm: "0x0aeDdEaB271Bc032d6758c34Dc8356632D6F812e",
} as const;

export function getId20Addresses(networkName: string): {
  avBTCm: string;
  avMEZOm: string;
} {
  switch (networkName) {
    case "mainnet":
    case "localhost":
    case "hardhat":
      return ID20_MAINNET;
    case "testnet":
      return ID20_TESTNET;
    default:
      throw new Error(`Unsupported Id20 address network: ${networkName}`);
  }
}

/** Dead address that holds mandatory seed shares for managed vaults. */
export const DEAD_SHARES = "0x000000000000000000000000000000000000dEaD";

/** Default Id20 wei deposited as the empty-vault seed (18-decimal Id20). */
export const SEED_ASSETS = 10n ** 12n;
