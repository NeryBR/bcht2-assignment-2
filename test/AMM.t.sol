// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/AMM.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Простой токен для тестов
contract TestToken is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        _mint(msg.sender, 1000000 * 10**18);
    }
}

contract AMMTest is Test {
    AMM public amm;
    TestToken public tokenA;
    TestToken public tokenB;
    address public alice = address(0x1);
    address public bob = address(0x2);

    function setUp() public {
        tokenA = new TestToken("Token A", "TKNA");
        tokenB = new TestToken("Token B", "TKNB");
        amm = new AMM(address(tokenA), address(tokenB));

        // Раздаем токены пользователям
        tokenA.transfer(alice, 10000 * 1e18);
        tokenB.transfer(alice, 10000 * 1e18);
        tokenA.transfer(bob, 10000 * 1e18);
        tokenB.transfer(bob, 10000 * 1e18);

        vm.startPrank(alice);
        tokenA.approve(address(amm), type(uint256).max);
        tokenB.approve(address(amm), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(bob);
        tokenA.approve(address(amm), type(uint256).max);
        tokenB.approve(address(amm), type(uint256).max);
        vm.stopPrank();
    }

    // --- LIQUIDITY TESTS (Task 3) ---
    function test_AddInitialLiquidity() public {
        vm.prank(alice);
        uint256 lpAmount = amm.addLiquidity(100 * 1e18, 400 * 1e18);
        assertEq(lpAmount, 200 * 1e18); // sqrt(100*400) [cite: 34, 41]
    }

    function test_AddSubsequentLiquidity() public {
        vm.prank(alice);
        amm.addLiquidity(100 * 1e18, 400 * 1e18);
        
        vm.prank(bob);
        uint256 lpAmount = amm.addLiquidity(50 * 1e18, 200 * 1e18);
        assertEq(lpAmount, 100 * 1e18); // Пропорционально вкладу [cite: 41]
    }

    function test_RemoveLiquidity() public {
        vm.startPrank(alice);
        uint256 lp = amm.addLiquidity(100 * 1e18, 100 * 1e18);
        amm.removeLiquidity(lp);
        assertEq(tokenA.balanceOf(alice), 10000 * 1e18); // Вернулось всё [cite: 35, 42]
        vm.stopPrank();
    }

    // --- SWAP TESTS ---
    function test_SwapAtoB() public {
        vm.prank(alice);
        amm.addLiquidity(1000 * 1e18, 1000 * 1e18);

        vm.prank(bob);
        uint256 amountOut = amm.swap(address(tokenA), 100 * 1e18, 0);
        assertTrue(amountOut > 0);
        assertEq(tokenB.balanceOf(bob), 10000 * 1e18 + amountOut); 
    }

    function test_SwapBtoA() public {
        vm.prank(alice);
        amm.addLiquidity(1000 * 1e18, 1000 * 1e18);

        vm.prank(bob);
        uint256 amountOut = amm.swap(address(tokenB), 100 * 1e18, 0);
        assertTrue(amountOut > 0); 
    }

    // --- K INVARIANT & FEES ---
    function test_K_IncreasesDueToFees() public {
        vm.prank(alice);
        amm.addLiquidity(1000 * 1e18, 1000 * 1e18);
        uint256 kBefore = amm.reserveA() * amm.reserveB();

        vm.prank(bob);
        amm.swap(address(tokenA), 100 * 1e18, 0);

        uint256 kAfter = amm.reserveA() * amm.reserveB();
        assertTrue(kAfter > kBefore); 
    }

    // --- SLIPPAGE PROTECTION ---
    function test_RevertSlippageTooHigh() public {
        vm.prank(alice);
        amm.addLiquidity(100 * 1e18, 100 * 1e18);

        vm.prank(bob);
        vm.expectRevert("Slippage: high price impact");
        amm.swap(address(tokenA), 10 * 1e18, 15 * 1e18); 
    }

    // --- EDGE CASES ---
    function test_RevertZeroAmountSwap() public {
        vm.prank(bob);
        vm.expectRevert("Insufficient input amount");
        amm.swap(address(tokenA), 0, 0);
    }

    // --- FUZZ TESTING ---
    function testFuzz_Swap(uint256 amountIn) public {
        vm.assume(amountIn > 1000 && amountIn < 5000 * 1e18);
        vm.prank(alice);
        amm.addLiquidity(10000 * 1e18, 10000 * 1e18);

        vm.prank(bob);
        uint256 out = amm.swap(address(tokenA), amountIn, 0);
        assertTrue(out > 0); 
    }
}