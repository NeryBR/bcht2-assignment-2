// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MyToken is ERC20 {
    constructor(uint256 initialSupply) ERC20("MyToken", "MTK") {
        // Умножаем на 10^18, чтобы получить целые токены (decimals)
        _mint(msg.sender, initialSupply * 10**18);
    }

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}