import type { DeployFunction } from "hardhat-deploy/types";

const func: DeployFunction = async (hre) => {
  const deployments = await hre.deployments.all();
  const candidates = Object.entries(deployments).filter(([, deployment]) =>
    Boolean(deployment.address && deployment.address !== hre.ethers.ZeroAddress),
  );
  if (candidates.length === 0) {
    throw new Error(`No deployed contracts recorded for ${hre.network.name}`);
  }

  for (const [name, deployment] of candidates) {
    const source = deployment.linkedData as
      | {
          contractName?: string;
          sourceName?: string;
          asset?: string;
          name?: string;
          symbol?: string;
        }
      | undefined;
    const contractName =
      source?.contractName ??
      (name.endsWith("Peer") ? "VaultPeer" : name.endsWith("Vault") ? "Vault" : name);
    const artifact = await hre.deployments.getArtifact(contractName);
    let constructorArguments = deployment.args ?? [];

    // Vaults are created by VaultFactory, so their constructor args are kept in linkedData.
    if (contractName === "Vault" && source?.asset && source.name && source.symbol) {
      constructorArguments = [source.asset, source.name, source.symbol];
    }

    hre.deployments.log(`Verifying ${name} (${contractName}) at ${deployment.address}`);
    await hre.run("verify:verify", {
      address: deployment.address,
      contract: `${artifact.sourceName}:${artifact.contractName}`,
      constructorArguments,
    }).catch((error: unknown) => {
      const message = error instanceof Error ? error.message : String(error);
      if (/already verified|already been verified/i.test(message)) {
        hre.deployments.log(`${name} is already verified`);
        return;
      }
      throw error;
    });
  }
};

func.tags = ["Verify"];
func.runAtTheEnd = true;
export default func;
