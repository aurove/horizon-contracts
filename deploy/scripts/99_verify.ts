import type { DeployFunction } from "hardhat-deploy/types";

/**
 * Placeholder verify tag. Mezo Blockscout verification is submitted via hardhat-verify /
 * Sourcify v2 from ops scripts once addresses are live (same pattern as id20/core).
 */
const func: DeployFunction = async (hre) => {
  const factory = await hre.deployments.getOrNull("VaultFactory");
  if (!factory) {
    hre.deployments.log("VaultFactory not deployed; nothing to verify");
    return;
  }
  hre.deployments.log(`VaultFactory at ${factory.address} — run hardhat verify manually or via Sourcify v2`);
};

func.tags = ["Verify"];
func.runAtTheEnd = true;
export default func;
