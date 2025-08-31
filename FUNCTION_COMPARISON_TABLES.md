# PledgePool 函数功能对比表

## 📊 出借人操作函数

| 函数                      | 状态要求                     | 时间要求 | 操作类型 | 代币处理              | 使用场景         | 返回值 |
| ------------------------- | ---------------------------- | -------- | -------- | --------------------- | ---------------- | ------ |
| `depositLend`             | MATCH                        | 结算前   | 存入资金 | 转入池中              | 提供借贷资金     | 无     |
| `refundLend`              | EXECUTION/FINISH/LIQUIDATION | 结算后   | 退还超额 | 转出超额部分          | 退还未匹配资金   | 无     |
| `claimLend`               | EXECUTION/FINISH/LIQUIDATION | 结算后   | 领取凭证 | 铸造 SP 代币          | 获得资金凭证     | 无     |
| `withdrawLend`            | FINISH/LIQUIDATION           | 到期后   | 提取本息 | 销毁 SP 代币+转出资金 | 取回本金和利息   | 无     |
| `emergencyLendWithdrawal` | UNDONE                       | 无限制   | 紧急退出 | 转出全部存款          | 异常情况安全退出 | 无     |

## 💰 借款人操作函数

| 函数                        | 状态要求                     | 时间要求 | 操作类型   | 代币处理                | 使用场景         | 返回值 |
| --------------------------- | ---------------------------- | -------- | ---------- | ----------------------- | ---------------- | ------ |
| `depositBorrow`             | MATCH                        | 结算前   | 质押抵押品 | 转入抵押品              | 提供借款担保     | 无     |
| `refundBorrow`              | EXECUTION/FINISH/LIQUIDATION | 结算后   | 退还超额   | 转出超额抵押品          | 退还超额质押     | 无     |
| `claimBorrow`               | EXECUTION/FINISH/LIQUIDATION | 结算后   | 领取资金   | 铸造 JP 代币+转出借款   | 获得借款资金     | 无     |
| `withdrawBorrow`            | FINISH/LIQUIDATION           | 到期后   | 赎回抵押品 | 销毁 JP 代币+转出抵押品 | 取回质押的抵押品 | 无     |
| `emergencyBorrowWithdrawal` | UNDONE                       | 无限制   | 紧急退出   | 转出全部抵押品          | 异常情况安全退出 | 无     |

## ⚙️ 管理员操作函数

| 函数                   | 权限要求  | 操作内容     | 影响范围   | 使用场景         | 返回值 |
| ---------------------- | --------- | ------------ | ---------- | ---------------- | ------ |
| `createPool`           | validCall | 创建新池     | 新增借贷池 | 部署新的借贷产品 | 无     |
| `settle`               | validCall | 结算池       | 池状态变更 | 完成资金匹配     | 无     |
| `finish`               | validCall | 完成池       | 池状态变更 | 计算利息并完成   | 无     |
| `liquidate`            | validCall | 清算池       | 池状态变更 | 处理风险池       | 无     |
| `setFee`               | validCall | 设置费用     | 全局费用   | 调整协议费用     | 无     |
| `setSwapRouterAddress` | validCall | 设置路由器   | 交换功能   | 更换 DEX 路由器  | 无     |
| `setFeeAddress`        | validCall | 设置费用地址 | 费用接收   | 更换费用接收地址 | 无     |
| `setMinAmount`         | validCall | 设置最小金额 | 存款限制   | 调整参与门槛     | 无     |
| `setPause`             | validCall | 暂停/恢复    | 全局状态   | 紧急情况控制     | 无     |

## 🔍 查询函数

| 函数                     | 返回类型   | 查询内容   | 使用场景       | 权限要求 |
| ------------------------ | ---------- | ---------- | -------------- | -------- |
| `poolLength`             | uint256    | 池数量     | 获取池总数     | 公开     |
| `getPoolState`           | uint256    | 池状态     | 查询池当前状态 | 公开     |
| `checkoutSettle`         | bool       | 是否可结算 | 检查结算条件   | 公开     |
| `checkoutFinish`         | bool       | 是否可完成 | 检查完成条件   | 公开     |
| `checkoutLiquidate`      | bool       | 是否可清算 | 检查清算条件   | 公开     |
| `getUnderlyingPriceView` | uint256[2] | 代币价格   | 获取预言机价格 | 公开     |

## 🏗️ 池生命周期管理

| 阶段            | 状态     | 可执行操作                                         | 用户行为         | 状态说明                                 |
| --------------- | -------- | -------------------------------------------------- | ---------------- | ---------------------------------------- |
| **MATCH**       | 匹配阶段 | depositLend, depositBorrow                         | 存款和质押       | 用户可以向池中存入资金或质押抵押品       |
| **EXECUTION**   | 执行阶段 | claimLend, claimBorrow, refundLend, refundBorrow   | 领取凭证和资金   | 资金匹配完成，用户可以领取凭证或申请退款 |
| **FINISH**      | 完成阶段 | withdrawLend, withdrawBorrow                       | 提取本息和抵押品 | 借贷周期结束，用户可以取回资金和抵押品   |
| **LIQUIDATION** | 清算阶段 | withdrawLend, withdrawBorrow                       | 清算后提取       | 风险触发清算，用户按清算价格提取         |
| **UNDONE**      | 异常阶段 | emergencyLendWithdrawal, emergencyBorrowWithdrawal | 紧急退出         | 池无法正常运作，用户紧急退出             |

## 🔄 状态转换流程

```
正常流程：
创建池 → MATCH → 用户操作 → 结算 → EXECUTION → 完成/清算 → FINISH/LIQUIDATION
   ↓         ↓         ↓         ↓         ↓           ↓
池配置   存款质押   资金匹配   状态变更   业务执行   资金返还

异常情况：
MATCH → UNDONE (当存款或借款为0时)
```

## 📋 函数修饰符说明

| 修饰符                         | 作用                               | 使用场景               |
| ------------------------------ | ---------------------------------- | ---------------------- |
| `external`                     | 只能从外部调用                     | 所有用户交互函数       |
| `payable`                      | 支持 ETH 支付                      | 存款和质押函数         |
| `nonReentrant`                 | 防止重入攻击                       | 所有涉及资金转移的函数 |
| `notPause`                     | 检查全局暂停状态                   | 所有用户操作函数       |
| `timeBefore(_pid)`             | 必须在结算时间之前                 | 存款和质押函数         |
| `timeAfter(_pid)`              | 必须在结算时间之后                 | 领取和退款函数         |
| `stateMatch(_pid)`             | 池状态必须是 MATCH                 | 存款和质押函数         |
| `stateNotMatchUndone(_pid)`    | 池状态不能是 MATCH 或 UNDONE       | 领取和退款函数         |
| `stateFinishLiquidation(_pid)` | 池状态必须是 FINISH 或 LIQUIDATION | 提取函数               |
| `stateUndone(_pid)`            | 池状态必须是 UNDONE                | 紧急退出函数           |
| `validCall`                    | 多签名验证                         | 管理员操作函数         |

## 💡 使用建议

### 1. **用户操作流程**

```
存款 → 等待结算 → 领取凭证 → 等待到期 → 提取本息
质押 → 等待结算 → 领取资金 → 等待到期 → 赎回抵押品
```

### 2. **异常处理**

- 如果池状态异常，使用紧急退出函数
- 如果资金超额，使用退款函数
- 如果时间未到，等待相应阶段

### 3. **安全注意事项**

- 所有操作都有状态和时间限制
- 使用 nonReentrant 防止重入攻击
- 多签名保护管理员操作

---

_这个表格提供了 PledgePool 合约中所有主要函数的完整对比，帮助用户和开发者快速理解每个函数的作用和使用条件。_
