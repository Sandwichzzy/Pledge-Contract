//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title MockWETH
 * @dev 模拟的WETH合约，用于测试
 */
contract MockWETH is ERC20 {
    
    event Deposit(address indexed dst, uint wad);
    event Withdrawal(address indexed src, uint wad);
    
    constructor() ERC20("Wrapped Ether", "WETH") {}
    
    // 存入ETH并铸造WETH
    function deposit() public payable {
        _mint(msg.sender, msg.value);
        emit Deposit(msg.sender, msg.value);
    }
    
    // 销毁WETH并提取ETH
    function withdraw(uint wad) public {
        require(balanceOf(msg.sender) >= wad, "MockWETH: insufficient balance");
        _burn(msg.sender, wad);
        payable(msg.sender).transfer(wad);
        emit Withdrawal(msg.sender, wad);
    }
    
    // 允许直接向合约发送ETH来铸造WETH
    receive() external payable {
        deposit();
    }
    
    fallback() external payable {
        deposit();
    }
} 