//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title MockERC20
 * @dev 模拟的ERC20代币合约，用于测试
 * 任何人都可以铸造代币用于测试
 */
contract MockERC20 is ERC20 {
    
    uint8 private _decimals;
    
    constructor(
        string memory name,
        string memory symbol,
        uint8 decimals_,
        uint256 initialSupply
    ) ERC20(name, symbol) {
        _decimals = decimals_;
        if (initialSupply > 0) {
            _mint(msg.sender, initialSupply);
        }
    }
    
    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }
    
    // 任何人都可以铸造代币用于测试
    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
    
    // 铸造代币给调用者
    function faucet(uint256 amount) public {
        _mint(msg.sender, amount);
    }
} 