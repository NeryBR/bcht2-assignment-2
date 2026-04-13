// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract LendingPool {
    struct UserPosition {
        uint256 deposited;
        uint256 borrowed;
        uint256 lastUpdate; // Время последнего действия для расчета процентов
    }

    IERC20 public collateralToken;
    IERC20 public borrowToken;
    
    mapping(address => UserPosition) public positions;
    
    uint256 public constant LTV = 75; 
    uint256 public constant INTEREST_RATE = 5; // 5% годовых
    uint256 public constant SECONDS_IN_YEAR = 31536000;

    constructor(address _collateral, address _borrow) {
        collateralToken = IERC20(_collateral);
        borrowToken = IERC20(_borrow);
    }

    // Вспомогательная функция для начисления процентов
    function _accrueInterest(address user) internal {
        UserPosition storage pos = positions[user];
        if (pos.borrowed > 0 && pos.lastUpdate < block.timestamp) {
            uint256 timePassed = block.timestamp - pos.lastUpdate;
            uint256 interest = (pos.borrowed * INTEREST_RATE * timePassed) / (100 * SECONDS_IN_YEAR);
            pos.borrowed += interest;
        }
        pos.lastUpdate = block.timestamp;
    }

    function deposit(uint256 amount) external {
        _accrueInterest(msg.sender);
        collateralToken.transferFrom(msg.sender, address(this), amount);
        positions[msg.sender].deposited += amount;
    }

    function borrow(uint256 amount) external {
        _accrueInterest(msg.sender);
        uint256 maxBorrow = (positions[msg.sender].deposited * LTV) / 100;
        require(positions[msg.sender].borrowed + amount <= maxBorrow, "Exceeds LTV");
        
        positions[msg.sender].borrowed += amount;
        borrowToken.transfer(msg.sender, amount);
    }

    function repay(uint256 amount) external {
        _accrueInterest(msg.sender);
        borrowToken.transferFrom(msg.sender, address(this), amount);
        positions[msg.sender].borrowed -= amount;
    }

    function withdraw(uint256 amount) external {
        _accrueInterest(msg.sender);
        require(positions[msg.sender].deposited >= amount, "Not enough collateral");
        
        // Проверка, чтобы после вывода LTV не нарушился
        uint256 remainingCollateral = positions[msg.sender].deposited - amount;
        uint256 maxBorrow = (remainingCollateral * LTV) / 100;
        require(positions[msg.sender].borrowed <= maxBorrow, "Still have debt");

        positions[msg.sender].deposited -= amount;
        collateralToken.transfer(msg.sender, amount);
    }
    function liquidate(address user) external {
        _accrueInterest(user);
        uint256 collateralValue = positions[user].deposited;
        uint256 debtValue = positions[user].borrowed;

        // Ликвидация возможна, если долг > 80% от залога
        require(debtValue * 100 > collateralValue * 80, "Position is healthy");

        // Ликвидатор гасит долг пользователя
        borrowToken.transferFrom(msg.sender, address(this), debtValue);
        
        // Ликвидатор забирает весь залог (в реальных протоколах остается бонус, но тут упростим)
        collateralToken.transfer(msg.sender, collateralValue);

        delete positions[user];
    }
}