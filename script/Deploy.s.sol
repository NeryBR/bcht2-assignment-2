// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {MyToken} from "../src/MyToken.sol";

contract DeployMyToken is Script {
    function run() external returns (MyToken) {
        // Мы читаем приватный ключ из переменных окружения (или просто имитируем)
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // Начало записи транзакций для деплоя
        vm.startBroadcast(deployerPrivateKey);

        // Создаем токен с начальной эмиссией 1,000,000
        MyToken token = new MyToken(1000000);

        // Конец записи
        vm.stopBroadcast();

        console.log("Token deployed at:", address(token));
        return token;
    }
} 