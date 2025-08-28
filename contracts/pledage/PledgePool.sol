//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract PledgePool is ReentrancyGuard {

    enum PoolState {
        MATCH, //匹配中
        EXECUTION, //执行中
        FINISH, //完成
        LIQUIDATIOM, //清算
        UNDONE //未完成
    }
    PoolState constant defaultChoice = PoolState.MATCH;
    //全局暂停
    bool public globalPaused =false;
    //pancake swap router
    address public swapRouter;
    //receiving fee address
    address public feeAddress;
    //oracle address
    //fee
    uint256 public lendFee;
    uint256 public borrowFee;

    struct PoolBaseInfo {
        uint256 settleTime; //结算时间 
        uint256 endTime; //结束时间 贷款的期限
        uint256 interestRate; //池子的固定利率 单位是1e8 按年算
        uint256 maxSupply; //池子最大限额 比如100万投资人最多往里面放100万资金
        uint256 lendSupply; //当前实际存款的借款方代币数量
        uint256 borrowSupply; //当前实际借出的抵押方代币数量
        uint256 martgageRate; //池的抵押率，单位是1e8
        address lendToken; //借款方借出代币地址（比如BUSD 稳定币）
        address borrowToken; //借款方抵押代币地址（比如BTC 抵押币）
        PoolState state; //池子状态 "MATCH" "EXECUTION" "FINISH" "LIQUIDATIOM" "UNDONE"
        // IDebtToken spCoin; //sp_token的ERC20 地址 比如（spBUSD_1..）投资人借出的凭证
        // IDebtToken jpCoin; //jp_token的ERC20 地址 比如（jpBTC_1）  抵押人抵押后的凭证
        uint256 autoLiquidateThreshold; //自动清算阈值
    }

    struct PoolInfo {
        uint256 totalSupply; //池子总供应量
        uint256 totalBorrow; //池子总借出量
        uint256 totalInterest; //池子总利息
    }
}