import type { Artifact, HardhatRuntimeEnvironment } from "hardhat/types";
import type { DeployResult } from "hardhat-deploy/types";

export async function requireCode(
  hre: HardhatRuntimeEnvironment,
  address: string,
  label: string,
): Promise<void> {
  let code = "0x";
  let error: unknown;
  for (let attempt = 0; attempt < 8; attempt += 1) {
    try {
      code = await hre.ethers.provider.getCode(address);
      error = undefined;
      break;
    } catch (caught) {
      error = caught;
      await new Promise((resolve) => setTimeout(resolve, 250 * (attempt + 1)));
    }
  }
  if (error) throw error;
  if (code === "0x") {
    throw new Error(
      `${label} deployment at ${address} has no on-chain code; refusing to redeploy over stale state`,
    );
  }
}

export async function deployDirect(
  hre: HardhatRuntimeEnvironment,
  name: string,
  contract: string,
  from: string,
  args: readonly unknown[] = [],
): Promise<{ action: "deployed" | "unchanged"; deployment: DeployResult }> {
  const existing = await hre.deployments.getOrNull(name);
  if (existing) await requireCode(hre, existing.address, name);
  const deployment = await hre.deployments.deploy(name, {
    from,
    contract,
    args: [...args],
    log: true,
  });
  return { action: deployment.newlyDeployed ? "deployed" : "unchanged", deployment };
}

function toJsonCompatible<T>(value: T): T {
  return JSON.parse(
    JSON.stringify(value, (_key, nestedValue) => {
      if (typeof nestedValue === "bigint") {
        return nestedValue.toString();
      }
      return nestedValue;
    }),
  ) as T;
}

export async function saveAbiOnly(
  hre: HardhatRuntimeEnvironment,
  name: string,
  artifact: Artifact,
): Promise<void> {
  if (name.includes("/") || name.includes("\\") || name === "." || name === "..") {
    throw new Error(`Invalid ABI export name: ${name}`);
  }

  await hre.deployments.save(`${name}`, {
    address: "",
    abi: artifact.abi,
    linkedData: toJsonCompatible({
      contractName: artifact.contractName,
      sourceName: artifact.sourceName,
    }),
  });
}

export async function saveDeployedContract(
  hre: HardhatRuntimeEnvironment,
  name: string,
  artifact: Artifact,
  address: string,
  extraLinkedData: Record<string, unknown> = {},
): Promise<void> {
  if (name.includes("/") || name.includes("\\") || name === "." || name === "..") {
    throw new Error(`Invalid deployment name: ${name}`);
  }

  await hre.deployments.save(name, {
    address,
    abi: artifact.abi,
    linkedData: toJsonCompatible({
      contractName: artifact.contractName,
      sourceName: artifact.sourceName,
      ...extraLinkedData,
    }),
  });
}
