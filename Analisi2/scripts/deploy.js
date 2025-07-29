// deploy.js - VERSIONE FINALE
const { ethers } = require("hardhat");

// Indirizzi mainnet
const AAVE_POOL = "0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2";
const UNISWAP_ROUTER = "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D";
const WETH_USDC_PAIR = "0xB4e16d0168e52d35CaCD2c6185b44281Ec28C9Dc";
const WETH = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";
const USDC = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48";

// Un indirizzo "whale" che possiede tantissimi USDC sulla mainnet (es. un wallet di Binance)
const USDC_WHALE = "0xF977814e90dA44bFA03b6295A0616a897441aceC";

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with:", deployer.address);

  // 1. Deploy del protocollo VITTMA
  const LendingProtocol = await ethers.getContractFactory("LendingProtocol");
  const lendingProtocol = await LendingProtocol.deploy(WETH, USDC, WETH_USDC_PAIR);
  await lendingProtocol.deployed();
  console.log("Contratto Vittima (LendingProtocol) deployato a:", lendingProtocol.address);

  // --- NUOVA SEZIONE: Finanziamo il protocollo vittima ---
  console.log("Finanziamo il LendingProtocol con USDC...");

  // Impersoniamo il whale per poter muovere i suoi fondi
  await hre.network.provider.request({
    method: "hardhat_impersonateAccount",
    params: [USDC_WHALE],
  });
  const whaleSigner = await ethers.getSigner(USDC_WHALE);

  // Otteniamo un'istanza del contratto USDC
  const usdcContract = await ethers.getContractAt("IERC20", USDC);
  
  // Trasferiamo 100,000 USDC dal whale al nostro LendingProtocol
  const amountToFund = 100000 * 1e6; // 100,000 USDC (ha 6 decimali)
  await usdcContract.connect(whaleSigner).transfer(lendingProtocol.address, amountToFund);

  // Smettiamo di impersonare il whale
  await hre.network.provider.request({
    method: "hardhat_stopImpersonatingAccount",
    params: [USDC_WHALE],
  });
  console.log(`Trasferiti 100,000 USDC al LendingProtocol.`);
  // --- FINE NUOVA SEZIONE ---

  // 2. Deploy del contratto ATTACCANTE, passando l'indirizzo della vittima
  const Attack = await ethers.getContractFactory("Attack");
  const attack = await Attack.deploy(AAVE_POOL, UNISWAP_ROUTER, lendingProtocol.address);
  await attack.deployed();
  console.log(" Contratto Attaccante (Attack) deployato a:", attack.address);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});