import { getAddress, ZeroAddress } from "ethers";
import { task } from "hardhat/config";

import { VaultPeer__factory } from "../typechain/factories/src/VaultPeer__factory";

task("vault-peer:set-minter", "Seal a VaultPeer to its NTT manager")
  .addParam("peer", "VaultPeer contract address")
  .addParam("manager", "NTT manager contract address")
  .setAction(async ({ peer: peerArg, manager: managerArg }, hre) => {
    if (hre.network.name !== "baseSepolia" && hre.network.name !== "base") {
      throw new Error(`VaultPeer minter setup must run on a Base spoke, not ${hre.network.name}`);
    }

    const peerAddress = getAddress(peerArg);
    const managerAddress = getAddress(managerArg);
    if (managerAddress === ZeroAddress) throw new Error("NTT manager cannot be the zero address");

    const [signer] = await hre.ethers.getSigners();
    if (!signer) throw new Error("No deployer signer configured for the selected Base network");

    const vaultPeer = VaultPeer__factory.connect(peerAddress, signer);
    const [owner, minter] = await Promise.all([vaultPeer.owner(), vaultPeer.minter()]);

    if (minter.toLowerCase() === managerAddress.toLowerCase() && owner === ZeroAddress) {
      console.log(`VaultPeer ${peerAddress} is already sealed to NTT Manager ${managerAddress}`);
      return;
    }
    if (minter !== ZeroAddress) {
      throw new Error(`VaultPeer already has a different minter (${minter}); refusing to proceed`);
    }
    if (owner.toLowerCase() !== signer.address.toLowerCase()) {
      throw new Error(
        `Signer ${signer.address} is not the temporary VaultPeer owner (${owner}); refusing one-time setup`,
      );
    }

    console.log(`Sealing VaultPeer ${peerAddress} to NTT Manager ${managerAddress}`);
    const tx = await vaultPeer.setMinter(managerAddress);
    await tx.wait();

    const [finalOwner, finalMinter] = await Promise.all([vaultPeer.owner(), vaultPeer.minter()]);
    if (finalOwner !== ZeroAddress || finalMinter.toLowerCase() !== managerAddress.toLowerCase()) {
      throw new Error(
        `VaultPeer handoff did not verify (owner=${finalOwner}, minter=${finalMinter})`,
      );
    }
  });
