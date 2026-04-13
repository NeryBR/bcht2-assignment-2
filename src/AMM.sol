// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {LPToken} from "./LPToken.sol";

contract AMM {
    IERC20 public immutable tokenA;
    IERC20 public immutable tokenB;
    LPToken public immutable lpToken;

    uint256 public reserveA;
    uint256 public reserveB;

    // События согласно требованиям Task 3 [cite: 38]
    event LiquidityAdded(address indexed provider, uint256 amountA, uint256 amountB, uint256 lpAmount);
    event LiquidityRemoved(address indexed provider, uint256 amountA, uint256 amountB, uint256 lpAmount);
    event Swap(address indexed user, address tokenIn, uint256 amountIn, uint256 amountOut);

    constructor(address _tokenA, address _tokenB) {
        tokenA = IERC20(_tokenA);
        tokenB = IERC20(_tokenB);
        lpToken = new LPToken();
    }

// Добавление ликвидности [cite: 34]
    function addLiquidity(uint256 amountA, uint256 amountB) external returns (uint256 lpAmount) {
        tokenA.transferFrom(msg.sender, address(this), amountA);
        tokenB.transferFrom(msg.sender, address(this), amountB);

        if (lpToken.totalSupply() == 0) {
            // Первый провайдер: выпускаем LP как среднее геометрическое [cite: 41]
            lpAmount = _sqrt(amountA * amountB);
        } else {
            // Последующие провайдеры: выпускаем пропорционально резервам [cite: 34, 41]
            lpAmount = _min(
                (amountA * lpToken.totalSupply()) / reserveA,
                (amountB * lpToken.totalSupply()) / reserveB
            );
        }

        require(lpAmount > 0, "Insufficient LP minted");
        lpToken.mint(msg.sender, lpAmount);

        reserveA = tokenA.balanceOf(address(this));
        reserveB = tokenB.balanceOf(address(this));

        emit LiquidityAdded(msg.sender, amountA, amountB, lpAmount); 
    }

    // Расчет суммы выхода с учетом комиссии 0.3% [cite: 36, 37]
    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) public pure returns (uint256) {
        require(amountIn > 0, "Insufficient input amount");
        require(reserveIn > 0 && reserveOut > 0, "Insufficient liquidity");

        // Формула: (amountIn * 997 * reserveOut) / (reserveIn * 1000 + amountIn * 997)
        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * 1000) + amountInWithFee;
        return numerator / denominator;
    }

    // Обмен токенов с защитой от проскальзывания [cite: 36, 39]
    function swap(address tokenIn, uint256 amountIn, uint256 minAmountOut) external returns (uint256 amountOut) {
        require(tokenIn == address(tokenA) || tokenIn == address(tokenB), "Invalid token");
        
        bool isTokenA = tokenIn == address(tokenA);
        (IERC20 tIn, IERC20 tOut, uint256 rIn, uint256 rOut) = isTokenA 
            ? (tokenA, tokenB, reserveA, reserveB) 
            : (tokenB, tokenA, reserveB, reserveA);

        tIn.transferFrom(msg.sender, address(this), amountIn);
        
        amountOut = getAmountOut(amountIn, rIn, rOut);
        require(amountOut >= minAmountOut, "Slippage: high price impact");

        tOut.transfer(msg.sender, amountOut);

        reserveA = tokenA.balanceOf(address(this));
        reserveB = tokenB.balanceOf(address(this));

        emit Swap(msg.sender, tokenIn, amountIn, amountOut); 
    }

    // Удаление ликвидности [cite: 35]
    function removeLiquidity(uint256 lpAmount) external returns (uint256 amountA, uint256 amountB) {
        uint256 totalSupply = lpToken.totalSupply();
        amountA = (lpAmount * reserveA) / totalSupply;
        amountB = (lpAmount * reserveB) / totalSupply;

        lpToken.burn(msg.sender, lpAmount);
        tokenA.transfer(msg.sender, amountA);
        tokenB.transfer(msg.sender, amountB);

        reserveA = tokenA.balanceOf(address(this));
        reserveB = tokenB.balanceOf(address(this));

        emit LiquidityRemoved(msg.sender, amountA, amountB, lpAmount); 
    }

    // Математика: корень квадратный (нужен для расчета первых LP токенов)
    function _sqrt(uint y) internal pure returns (uint z) {
        if (y > 3) {
            z = y;
            uint x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }

    function _min(uint x, uint y) internal pure returns (uint) {
        return x <= y ? x : y;
    }
}