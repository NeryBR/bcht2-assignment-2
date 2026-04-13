// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";

// Интерфейс, чтобы мы могли вызвать функцию balanceOf у контракта WETH
interface IERC20 {
    function balanceOf(address owner) external view returns (uint256);
}

contract ForkTest is Test {
    // Адрес контракта WETH в основной сети Ethereum
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    
    // Адрес какого-нибудь крупного держателя WETH (Binance или любой крупный кошелек)
    address constant HOLDER = 0xF977814e90dA44bFA03b6295A0616a897441aceC;

    function setUp() public {
        // Мы создадим форк внутри кода
        // Вставь свой RPC URL вместо переменной в терминале позже
    }

    function test_ReadMainnetBalance() public {
        // Проверяем баланс реального адреса в реальной сети
        uint256 balance = IERC20(WETH).balanceOf(HOLDER);
        
        console.log("WETH Balance of Holder:", balance / 1e18);
        
        // Убеждаемся, что баланс больше нуля (значит форк работает)
        assertTrue(balance > 0);
    }
}