// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/LendingPool.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockToken is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        _mint(msg.sender, 1000000 * 1e18);
    }
}

contract LendingPoolTest is Test {
    LendingPool public pool;
    MockToken public collateral;
    MockToken public borrowToken;
    address public alice = address(0x1);
    address public liquidator = address(0x2);

    function setUp() public {
        collateral = new MockToken("Collateral", "COL");
        borrowToken = new MockToken("BorrowToken", "BTK");
        pool = new LendingPool(address(collateral), address(borrowToken));

        // Даем токены Алисе и Ликвидатору
        collateral.transfer(alice, 1000 * 1e18);
        borrowToken.transfer(address(pool), 10000 * 1e18); // Пул должен иметь средства для выдачи
        borrowToken.transfer(liquidator, 5000 * 1e18);

        vm.startPrank(alice);
        collateral.approve(address(pool), type(uint256).max);
        borrowToken.approve(address(pool), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(liquidator);
        borrowToken.approve(address(pool), type(uint256).max);
        vm.stopPrank();
    }

    function test_DepositAndBorrow() public {
        vm.startPrank(alice);
        pool.deposit(100 * 1e18);
        pool.borrow(75 * 1e18); // Ровно 75% LTV
        
        (uint256 dep, uint256 bor, ) = pool.positions(alice);
        assertEq(dep, 100 * 1e18);
        assertEq(bor, 75 * 1e18);
        vm.stopPrank();
    }

    function test_RevertExceedLTV() public {
        vm.startPrank(alice);
        pool.deposit(100 * 1e18);
        vm.expectRevert("Exceeds LTV");
        pool.borrow(76 * 1e18); // 76% уже нельзя
        vm.stopPrank();
    }

    function test_InterestAccrual() public {
        vm.startPrank(alice);
        pool.deposit(100 * 1e18);
        pool.borrow(50 * 1e18);
        
        // Перематываем время на 1 год вперед
        vm.warp(block.timestamp + 31536000); 
        
        // Пытаемся взять еще 1 токен, что триггерит расчет процентов
        pool.borrow(1 * 1e18);
        
        ( , uint256 borrowed, ) = pool.positions(alice);
        // Долг должен быть: 50 + (50 * 5%) + 1 = 53.5
        assertEq(borrowed, 53.5 * 1e18);
        vm.stopPrank();
    }

    function test_LiquidationScenario() public {
        vm.startPrank(alice);
        pool.deposit(100 * 1e18);
        pool.borrow(75 * 1e18);
        vm.stopPrank();

        // Проходит время, долг растет из-за процентов и превышает порог 80%
        vm.warp(block.timestamp + 31536000 * 2); // 2 года

        vm.prank(liquidator);
        pool.liquidate(alice);

        (uint256 dep, uint256 bor, ) = pool.positions(alice);
        assertEq(dep, 0);
        assertEq(bor, 0);
        assertTrue(collateral.balanceOf(liquidator) >= 100 * 1e18);
    }
}