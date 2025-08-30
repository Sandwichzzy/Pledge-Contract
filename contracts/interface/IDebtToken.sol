//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IDebtToken {

    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function mint(address account,uint256 amount) external returns (bool);

    function burn(address from,uint256 amount) external returns (bool);
}
