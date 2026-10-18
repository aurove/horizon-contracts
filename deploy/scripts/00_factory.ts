import type { DeployFunction } from "hardhat-deploy/types";
import { deployDirect, saveAbiOnly } from "../utils/deployment";

const func: DeployFunction = async (hre) => {
  const { deployer } = await hre.getNamedAccounts();
  const result = await deployDirect(hre, "VaultFactory", "VaultFactory", deployer, []);
  await saveAbiOnly(hre, "Vault", await hre.deployments.getArtifact("Vault"));
  hre.deployments.log(`VaultFactory: ${result.action} (${result.deployment.address})`);
};

func.tags = ["VaultFactory", "Factory"];
export default func;
