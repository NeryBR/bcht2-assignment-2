// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {MyToken} from "../src/MyToken.sol";

contract MyTokenTest is Test {
    MyToken public token;
    address alice = address(0x1);
    address bob = address(0x2);

    function setUp() public {
        token = new MyToken(1000);
    }

    function test_Name() public view { assertEq(token.name(), "MyToken"); }
    function test_Symbol() public view { assertEq(token.symbol(), "MTK"); }
    function test_InitialSupply() public view { assertEq(token.totalSupply(), 1000 * 10**18); }
    
    function test_Transfer() public {
        token.transfer(alice, 100 * 10**18);
        assertEq(token.balanceOf(alice), 100 * 10**18);
    }

    function test_RevertInsufficientBalance() public {
        vm.prank(alice); 
        vm.expectRevert(); // Мы ожидаем, что следующая строка вызовет ошибку
        token.transfer(bob, 1 ether); 
    }

    function test_ApproveAndAllowance() public {
        token.approve(alice, 500);
        assertEq(token.allowance(address(this), alice), 500);
    }

    function test_TransferFrom() public {
        uint256 amount = 100;
        token.approve(alice, amount);
        vm.prank(alice);
        token.transferFrom(address(this), bob, amount);
        assertEq(token.balanceOf(bob), amount);
    }

    function test_MintByOwner() public {
        token.mint(alice, 200);
        assertEq(token.balanceOf(alice), 200);
    }

    function test_BalanceAfterTransfer() public {
        uint256 startBalance = token.balanceOf(address(this));
        token.transfer(alice, 100);
        assertEq(token.balanceOf(address(this)), startBalance - 100);
    }

    function test_Decimals() public view {
        assertEq(token.decimals(), 18);
    }

    function test_TransferToSelf() public {
        token.transfer(address(this), 100);
        // Баланс не должен измениться итогово
        assertEq(token.balanceOf(address(this)), 1000 * 10**18);
    }

    // --- FUZZ TESTING ---
    function testFuzz_Transfer(uint256 amount) public {
        uint256 maxBalance = token.balanceOf(address(this));
        vm.assume(amount <= maxBalance); 
        
        token.transfer(alice, amount);
        assertEq(token.balanceOf(alice), amount);
    }

    // --- INVARIANT TESTING ---
    function test_InvariantTotalSupply() public view {
        assertEq(token.totalSupply(), 1000 * 10**18);
    }
}