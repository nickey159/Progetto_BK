// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Interfaccia per leggere le riserve da una pool di Uniswap V2
interface IUniswapV2Pair {
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function token0() external view returns (address);
}

contract LendingProtocol {
    IERC20 public immutable collateralToken; // WETH
    IERC20 public immutable debtToken;       // USDC
    IUniswapV2Pair public immutable priceOracle; // La pool WETH/USDC di Uniswap

    mapping(address => uint256) public collateralBalances;

    // LTV: Per ogni dollaro di collaterale, puoi prendere in prestito 0.7 dollari di debito
    uint256 public constant LOAN_TO_VALUE = 70; // 70%

    constructor(address _collateral, address _debt, address _oracle) {
        collateralToken = IERC20(_collateral);
        debtToken = IERC20(_debt);
        priceOracle = IUniswapV2Pair(_oracle);
    }

    // Funzione per depositare WETH come collaterale
    function deposit(uint256 _amount) external {
        collateralBalances[msg.sender] += _amount;
        collateralToken.transferFrom(msg.sender, address(this), _amount);
    }

    // LA FUNZIONE VULNERABILE
    function borrow(uint256 _borrowAmount) external {
        // 1. Calcola il valore del collaterale usando l'oracolo vulnerabile
        uint256 collateralValueInUsd = getCollateralValueInUsd(msg.sender);

        // 2. Calcola quanto l'utente può prendere in prestito
        uint256 maxBorrowable = (collateralValueInUsd * LOAN_TO_VALUE) / 100;
        require(_borrowAmount <= maxBorrowable, "Borrow amount exceeds max LTV");

        // 3. Eroga il prestito in USDC
        debtToken.transfer(msg.sender, _borrowAmount);
    }

    // L'ORACOLO VULNERABILE
    function getCollateralValueInUsd(address _user) public view returns (uint256) {
        uint256 collateralAmount = collateralBalances[_user];
        if (collateralAmount == 0) return 0;

        // Prende il prezzo spot direttamente dalla pool di Uniswap
        (uint112 reserve0, uint112 reserve1, ) = priceOracle.getReserves();
        
        // Assumiamo che token0 sia USDC (6 decimali) e token1 sia WETH (18 decimali)
        // Questo andrebbe controllato con priceOracle.token0() in un caso reale
        uint256 price = (uint256(reserve0) * 1e18) / uint256(reserve1); // Prezzo di WETH in USDC (con 6 decimali)

        // Valore = (quantità di WETH * prezzo) / 10^18 (per normalizzare i decimali di WETH)
        return (collateralAmount * price) / 1e18;
    }
}