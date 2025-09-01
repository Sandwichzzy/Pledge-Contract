# Pledge Solidity - 质押借贷协议

## 📋 项目概述

Pledge Solidity 是一个基于以太坊的智能合约质押借贷协议，采用多签名治理机制，支持多种代币的质押借贷业务。系统通过智能合约实现去中心化的资金匹配、利息计算和风险管理。

## 🏗️ 系统架构

### 核心合约组件

```
PledgePool (主合约)
├── MultiSignature (多签名治理)
├── BscPledgeOracle (价格预言机)
├── DebtToken (债务代币)
├── AddressPrivileges (权限管理)
└── SafeTransfer (安全转账库)
```

### 合约继承关系

- **PledgePool**: 继承 `ReentrancyGuard` 和 `multiSignatureClient`
- **BscPledgeOracle**: 继承 `MultiSignatureClient`
- **DebtToken**: 继承 `ERC20` 和 `AddressPrivileges`
- **AddressPrivileges**: 继承 `multiSignatureClient`

## 🔐 多签名治理系统

### MultiSignature 合约

- **功能**: 实现多签名治理机制，要求多个签名者同意才能执行重要操作
- **特性**:
  - 白名单地址管理
  - 可配置签名阈值
  - 支持申请创建、签名、撤销
  - 自动验证签名数量

### MultiSignatureClient 合约

- **功能**: 为其他合约提供多签名验证功能的基础合约
- **使用**: 任何需要多签名保护的合约都应该继承此合约

## 💰 质押借贷池系统

### PledgePool 合约

- **核心功能**: 管理多个借贷池，处理用户存款、借款、结算等操作
- **池状态管理**:
  - `MATCH`: 匹配阶段 - 用户可以存款和质押
  - `EXECUTION`: 执行阶段 - 借贷生效，计息开始
  - `FINISH`: 完成阶段 - 正常到期结算
  - `LIQUIDATION`: 清算阶段 - 触发风险清算
  - `UNDONE`: 异常阶段 - 允许紧急提取

### 用户操作流程

#### 出借人流程

```
存款 → 等待结算 → 领取凭证 → 等待到期 → 提取本息
```

#### 借款人流程

```
质押抵押品 → 等待结算 → 领取资金 → 等待到期 → 赎回抵押品
```

### 主要函数

| 用户类型 | 函数             | 功能描述         |
| -------- | ---------------- | ---------------- |
| 出借人   | `depositLend`    | 存入借贷资金     |
| 出借人   | `claimLend`      | 领取 SP 代币凭证 |
| 出借人   | `withdrawLend`   | 提取本息         |
| 借款人   | `depositBorrow`  | 质押抵押品       |
| 借款人   | `claimBorrow`    | 领取借款资金     |
| 借款人   | `withdrawBorrow` | 赎回抵押品       |

## 🔮 价格预言机系统

### BscPledgeOracle 合约

- **功能**: 提供资产价格数据，支持多种价格源
- **特性**:
  - 支持 Chainlink 聚合器价格
  - 支持手动设置价格（备用）
  - 统一 18 位小数精度
  - 多签名控制价格设置

### 价格查询优先级

1. Chainlink 聚合器价格（优先）
2. 手动设置价格（备用）
3. 无价格时返回 0

## 🪙 代币系统

### DebtToken 合约

- **功能**: 代表用户权益的 ERC20 代币
- **类型**:
  - **SP 代币**: 出借人凭证，代表存款权益
  - **JP 代币**: 借款人凭证，代表抵押品权益

### AddressPrivileges 合约

- **功能**: 管理铸币者权限
- **特性**: 基于 OpenZeppelin 的 EnumerableSet 实现高效权限管理

## 🛡️ 安全特性

### 重入攻击防护

- 使用 `ReentrancyGuard` 修饰符
- 所有涉及资金转移的函数都有重入保护

### 多签名验证

- 重要操作需要多签名验证
- 可配置签名阈值
- 防止单点故障

### 状态检查

- 严格的状态转换控制
- 时间限制验证
- 金额限制检查

## 🚀 部署和配置

### 环境要求

- Node.js 16+
- Hardhat 2.26.3+
- Solidity 0.8.20+

### 网络支持

- **BSC 测试网**: ChainID 97
- **Sepolia 测试网**: ChainID 11155111
- **Hardhat 本地网络**

### 部署脚本

```bash
# 部署多签名合约
npx hardhat run deploy/00-deploy-multiSignature.js --network bscTestnet

# 部署债务代币
npx hardhat run deploy/01-deploy-debtToken.js --network bscTestnet

# 部署预言机
npx hardhat run deploy/02-deploy-oracle.js --network bscTestnet
```

### 环境变量配置

```env
# BSC测试网
BSC_TESTNET_URL=https://data-seed-prebsc-1-s1.binance.org:8545/
PRIVATE_KEY=your_private_key
PRIVATE_KEY_2=your_private_key_2
PRIVATE_KEY_3=your_private_key_3

# Sepolia测试网
SEPOLIA_URL=https://sepolia.infura.io/v3/your_project_id
ETHERSCAN_API_KEY=your_etherscan_api_key
```

## 🧪 测试和验证

### 运行测试

```bash
# 运行所有测试
npx hardhat test

# 运行测试并显示gas报告
REPORT_GAS=true npx hardhat test

# 运行覆盖率测试
npx hardhat coverage
```

### 本地开发

```bash
# 启动本地节点
npx hardhat node

# 部署到本地网络
npx hardhat run deploy/00-deploy-multiSignature.js --network localhost
```

## 📊 合约状态管理

### 池生命周期

```
创建池 → MATCH → 用户操作 → 结算 → EXECUTION → 完成/清算 → FINISH/LIQUIDATION
```

### 状态转换条件

- **MATCH → EXECUTION**: 达到结算时间，资金匹配完成
- **EXECUTION → FINISH**: 借贷期限到期，计算利息
- **EXECUTION → LIQUIDATION**: 触发风险阈值，启动清算
- **MATCH → UNDONE**: 存款或借款为 0，池无法正常运作

## 🔧 开发指南

### 添加新功能

1. 在相应合约中添加新函数
2. 使用适当的修饰符（如 `validCall`、`nonReentrant`）
3. 添加事件记录
4. 编写测试用例
5. 更新文档

### 合约升级

- 使用代理模式进行合约升级
- 通过多签名验证升级操作
- 保持数据兼容性

multiSignatureAddr=0xc4F817a1541ae1c98c72e016c58c9121e8AB3A24
spDebtToken =0x4Ec6D33EE55A0cdA224a86FB48013809B5763a27
JPDebtToken =0x523df39cAe18ea125930DA730628213e4b147CDc
BscPledgeOracle=0xdb6D3b4CEB2aD839bdBD9A55833bac56212F1c94
PledgePool=0x31F64Fa2588e70614eD7E7C16d5C492cedc09F72
