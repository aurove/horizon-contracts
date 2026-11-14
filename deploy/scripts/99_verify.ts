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
    const maxAttempts = 4;
    for (let attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        await hre.run("verify:verify", {
          address: deployment.address,
          contract: `${artifact.sourceName}:${artifact.contractName}`,
          constructorArguments,
        });
        break;
      } catch (error: unknown) {
        const message = error instanceof Error ? error.message : String(error);
        if (/already verified|already been verified/i.test(message)) {
          hre.deployments.log(`${name} is already verified`);
          break;
        }
        // Mezo / Base explorers sometimes lag behind fresh CREATE receipts.
        const retryable =
          /not a smart-contract|does not have bytecode|Unable to locate ContractCode|connection|timeout|429|502|503|deprecated V1 endpoint|Etherscan API V2/i.test(
            message,
          );
        if (retryable && attempt < maxAttempts) {
          const delayMs = attempt * 8_000;
          hre.deployments.log(
            `${name} verify attempt ${attempt}/${maxAttempts} failed (${message.split("\n")[0]}); retrying in ${delayMs}ms`,
          );
          await new Promise((r) => setTimeout(r, delayMs));
          continue;
        }
        if (process.env.HORIZON_VERIFY_SOFT_FAIL === "YES" && retryable) {
          hre.deployments.log(
            `WARNING: soft-failing verify for ${name} after ${attempt} attempts: ${message.split("\n")[0]}`,
          );
          break;
        }
        throw error;
      }
    }
  }
};

func.tags = ["Verify"];
func.runAtTheEnd = true;
export default func;
