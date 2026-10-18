import type { DeployFunction } from "hardhat-deploy/types";
import { getAddress } from "ethers";

import { Vault__factory } from "../../typechain/factories/src/Vault__factory";
import { VaultFactory__factory } from "../../typechain/factories/src/VaultFactory__factory";
import { IERC20__factory } from "../../typechain/factories/@openzeppelin/contracts/token/ERC20/IERC20__factory";
import {
  DEAD_SHARES,
  SEED_ASSETS,
  getId20Addresses,
} from "../../helpers/id20-addresses";
import { saveDeployedContract } from "../utils/deployment";

const MANAGED_VAULTS = [
  { key: "avBTCm" as const, name: "avBTC Vault", symbol: "avBTCv", deploymentName: "avBTCVault" },
  { key: "avMEZOm" as const, name: "avMEZO Vault", symbol: "avMEZOv", deploymentName: "avMEZOVault" },
];

const func: DeployFunction = async (hre) => {
  const { deployer } = await hre.getNamedAccounts();
  const signer = await hre.ethers.getSigner(deployer);
  const factoryDeployment = await hre.deployments.get("VaultFactory");
  const factory = VaultFactory__factory.connect(factoryDeployment.address, signer);
  const id20Addresses = getId20Addresses(hre.network.name);
  const vaultArtifact = await hre.deployments.getArtifact("Vault");

  for (const spec of MANAGED_VAULTS) {
    const asset = getAddress(id20Addresses[spec.key]);
    let vaultAddr = await factory.getVault(asset);

    if (vaultAddr === hre.ethers.ZeroAddress) {
      const tx = await factory.createVault(asset, spec.name, spec.symbol);
      await tx.wait();
      vaultAddr = await factory.getVault(asset);
      hre.deployments.log(`Created ${spec.deploymentName} at ${vaultAddr}`);
    } else {
      hre.deployments.log(`${spec.deploymentName} already exists at ${vaultAddr}`);
    }

    await saveDeployedContract(hre, spec.deploymentName, vaultArtifact, vaultAddr, {
      asset,
      name: spec.name,
      symbol: spec.symbol,
    });

    const vault = Vault__factory.connect(vaultAddr, signer);
    const deadBalance = await vault.balanceOf(DEAD_SHARES);
    if (deadBalance > 0n) {
      hre.deployments.log(`Seed shares already present for ${spec.deploymentName}; skipping`);
      continue;
    }

    const id20 = IERC20__factory.connect(asset, signer);
    const balance = await id20.balanceOf(deployer);
    if (balance < SEED_ASSETS) {
      hre.deployments.log(
        `Skipping seed for ${spec.deploymentName}: deployer Id20 balance ${balance} < ${SEED_ASSETS}`,
      );
      continue;
    }

    const allowance = await id20.allowance(deployer, vaultAddr);
    if (allowance < SEED_ASSETS) {
      await (await id20.approve(vaultAddr, SEED_ASSETS)).wait();
    }
    await (await vault.deposit(SEED_ASSETS, deployer)).wait();
    const seedShares = await vault.balanceOf(deployer);
    await (await vault.transfer(DEAD_SHARES, seedShares)).wait();
    hre.deployments.log(
      `Seeded ${spec.deploymentName}: ${SEED_ASSETS} assets → ${seedShares} shares to ${DEAD_SHARES}`,
    );
  }
};

func.tags = ["Vaults", "Managed"];
func.dependencies = ["VaultFactory"];
export default func;
