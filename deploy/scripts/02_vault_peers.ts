import { getAddress } from "ethers";
import type { DeployFunction } from "hardhat-deploy/types";

import { deployDirect, saveAbiOnly } from "../utils/deployment";

const SPOKE_NETWORKS = new Set(["baseSepolia", "base"]);
const PEERS = [
  { name: "avBTCvPeer", tokenName: "avBTC Vault", symbol: "avBTCv" },
  { name: "avMEZOvPeer", tokenName: "avMEZO Vault", symbol: "avMEZOv" },
] as const;

const func: DeployFunction = async (hre) => {
  if (!SPOKE_NETWORKS.has(hre.network.name)) {
    throw new Error(
      `VaultPeer can only be deployed to Base spokes (baseSepolia or base), not ${hre.network.name}`,
    );
  }

  const { deployer } = await hre.getNamedAccounts();
  const owner = getAddress(deployer);
  const artifact = await hre.deployments.getArtifact("VaultPeer");

  for (const peer of PEERS) {
    const result = await deployDirect(hre, peer.name, "VaultPeer", deployer, [
      peer.tokenName,
      peer.symbol,
      owner,
    ]);
    hre.deployments.log(`${peer.name}: ${result.action} (${result.deployment.address})`);
  }

  await saveAbiOnly(hre, "VaultPeer", artifact);
};

func.tags = ["VaultPeers", "VaultPeer"];
export default func;
