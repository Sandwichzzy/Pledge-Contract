//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../library/SafeTransfer.sol";

import "../interface/IBscPledgeOracle.sol";
import "../interface/IDebtToken.sol";
import "../multiSignature/multiSignatureClient.sol";

contract PledgePool is ReentrancyGuard,multiSignatureClient {

    using Math for uint256;
    using SafeERC20 for IERC20;
    using Address for address;
    //default decimals
    uint256 constant internal calDecimals=1e18;
    //based on the decimals of the commission and interest
    uint256 constant internal baseDecimals=1e8;
    uint256 public minAmount = 100e18;
    //365days
    uint256 constant internal baseYear=365;

    enum PoolState {
        MATCH, //匹配中 - 用户可以存款
        EXECUTION, //执行中 - 借贷生效，计息开始
        FINISH, //完成  - 正常到期结算
        LIQUIDATIOM, //清算 - 触发风险清算
        UNDONE //未完成- 异常状态，允许紧急提取
    }
    PoolState constant defaultChoice = PoolState.MATCH;
    //全局暂停
    bool public globalPaused =false;
    //pancake swap router UniSwapV2
    address public swapRouter;
    //receiving fee address 
    address public feeAddress;
    //oracle address
    IBscPledgeOracle public oracle;
    //fee
    uint256 public lendFee;
    uint256 public borrowFee;

    struct PoolBaseInfo {
        uint256 settleTime; //结算时间  开始计息的时间点
        uint256 endTime; //结束时间 贷款的期限
        uint256 interestRate; //池子的固定利率 单位是1e8 按年算
        uint256 maxSupply; //池子最大限额 比如100万 投资人最多往里面放100万资金
        uint256 lendSupply; //前出借资金总量 出借人存入的资金总和
        uint256 borrowSupply; //当前实际借出的抵押方代币数量
        uint256 martgageRate; //池的抵押率，单位是1e8
        address lendToken; //借款方借出代币地址（比如BUSD 稳定币）
        address borrowToken; //借款方抵押代币地址（比如BTC 抵押币）
        PoolState state; //池子状态 "MATCH" "EXECUTION" "FINISH" "LIQUIDATIOM" "UNDONE"
        IDebtToken spCoin; //sp_token的ERC20 地址 比如（spBUSD_1..）供应方凭证
        IDebtToken jpCoin; //jp_token的ERC20 地址 比如（jpBTC_1）  抵押凭证
        uint256 autoLiquidateThreshold; //自动清算阈值
    }

    //total pool base info
    PoolBaseInfo[] public poolBaseInfos;

    //每个池的数据信息
    struct PoolDataInfo {
        uint256 settleAmountLend;       // 结算时的实际出借金额
        uint256 settleAmountBorrow;     // 结算时的实际借款金额
        uint256 finishAmountLend;       // 完成时的实际出借金额
        uint256 finishAmountBorrow;     // 完成时的实际借款金额
        uint256 liquidationAmounLend;   // 清算时的实际出借金额
        uint256 liquidationAmounBorrow; // 清算时的实际借款金额
    }

    //total pool data info
    PoolDataInfo[] public poolDataInfos;

    struct BorrowInfo {
        uint256 stakeAmount;        // 用户质押的抵押品金额（如BTC数量）
        uint256 refundAmount;       // 超额质押的退款金额
        bool hasNoRefund;             // 是否已退还超额质押：false=未退款，true=已退款
        bool hasNoClaim;              // 是否已认领JP代币：false=未认领，true=已认领
    }

    //  {user.address : {pool.index : user.borrowInfo}}
    mapping(address =>mapping(uint256 => BorrowInfo)) public userBorrowInfo;

    // 借款用户信息
    struct LendInfo {
        uint256 stakeAmount;          // 用户存入的出借资金金额（如USDC数量）
        uint256 refundAmount;         // 超额存款的退款金额
        bool hasNoRefund;             // 是否已退还超额存款：false=未退款，true=已退款
        bool hasNoClaim;              // 是否已认领SP代币：false=未认领，true=已认领
    }

    //  {user.address : {pool.index : user.lendInfo}}
    mapping(address =>mapping(uint256 => LendInfo)) public userLendInfo;

    // 事件
    // 存款借出事件，from是存款出借者地址，token是存入的代币地址，amount是借出的数量，mintAmount是生成的数量
    event DepositLend(address indexed from,address indexed token,uint256 amount,uint256 mintAmount);
    // 出借退还超额存款事件，from是存款出借者地址，token是存入的代币地址，refund是退款的数量
    event RefundLend(address indexed from,address indexed token,uint256 refund);
    // 出借领取SP代币事件，from是领取者地址，token是存入的代币地址，amount领取的SP代币数量
    event ClaimLend(address indexed from,address indexed token,uint256 amount)
    // 出借方提取存款事件，from是提取者地址，token是提取的代币地址，amount是提取的数量，burnAmount是销毁SP_coin的数量
    event WithdrawLend(address indexed from,address indexed token,uint256 amount,uint256 burnAmount);
    // 出借人紧急提取存款事件，from是提取者地址，token是提取的代币地址，amount是提取的数量
    event EmergencyLendWithdrawal(address indexed from,address indexed token,uint256 amount);
     // 设置费用事件，newLendFee是新的借出费用，newBorrowFee是新的借入费用
    event SetFee(uint256 indexed newLendFee, uint256 indexed newBorrowFee);
    event SetSwapRouterAddress(address indexed oldSwapAddress, address indexed newSwapAddress); 

    constructor(
        address _oracle,
        address _swapRouter,
        address payable _feeAddress, 
        address _multiSignature)
    multiSignatureClient(_multiSignature) {
        require(_oracle != address(0),"PledgePool : oracle is zero address");
        require(_swapRouter != address(0),"PledgePool : swapRouter is zero address");
        require(_feeAddress != address(0),"PledgePool : feeAddress is zero address");
        oracle=IBscPledgeOracle(_oracle);
        swapRouter=_swapRouter;
        feeAddress=_feeAddress;
        lendFee=0;
        borrowFee=0;
    }

    function setFee(uint256 _lendFee,uint256 _borrowFee) validCall external {
        lendFee=_lendFee;
        borrowFee=_borrowFee;
        emit SetFee(_lendFee,_borrowFee);
    }

    function setSwapRouter(address _swapRouter) validCall external {
        require(_swapRouter != address(0),"PledgePool : swapRouter is zero address");
        emit SetSwapRouterAddress(_swapRouter);
        swapRouter=_swapRouter;
    }

    function setMinAmount(uint256 _minAmount) validCall external {
        require(_minAmount > 0,"PledgePool : minAmount is zero");
        minAmount=_minAmount;
    }
    
    function PoolLength() external view returns (uint256) {
        return poolBaseInfos.length;
    }
    /**
     * @dev 创建一个新的借贷池。函数接收一系列参数，
     * 包括结算时间、结束时间、利率、最大供应量、抵押率、存入代币、借出代币、SP代币、JP代币和自动清算阈值。
     *  Can only be called by the owner.
     */
    function createPool(uint256 _settleTime,uint256 _endTime,
        uint256 _interestRate,uint256 _maxSupply,uint256 _martgageRate,
        address _lendToken,address _borrowToken,address _spToken,
        address _jpToken,uint256 _autoLiquidateThreshold) validCall public  {
        //需要结束时间大于结算时间
        require(_endTime > _settleTime,"createPool : endTime must be greater than settleTime");
        require(_jpToken != address(0),"createPool : jpToken is zero address");
        require(_spToken!= address(0),"createPool : spToken is zero address");

        poolBaseInfos.push(PoolBaseInfo({
            settleTime: _settleTime,
            endTime: _endTime,
            interestRate: _interestRate,
            maxSupply: _maxSupply,
            lendSupply: 0,
            borrowSupply: 0,
            martgageRate: _martgageRate,
            lendToken: _lendToken,
            borrowToken: _borrowToken,
            state: defaultChoice,
            spCoin: IDebtToken(_spToken),
            jpCoin: IDebtToken(_jpToken),
            autoLiquidateThreshold: _autoLiquidateThreshold
        }))
        //推入池数据信息
        poolDataInfos.push(PoolDataInfo({
            settleAmountLend: 0,
            settleAmountBorrow: 0,
            finishAmountLend: 0,
            finishAmountBorrow: 0,
            liquidationAmounLend: 0,
            liquidationAmounBorrow: 0
        }));
    }

    function getPoolState(uint256 _pid) public view returns (uint256){
        PoolBaseInfo storage pool = poolBaseInfos[_pid];
        return uint256(pool.state);
    }

    /**
     * @dev 出借人执行存款操作，将资金存入借贷池
     * @notice 池状态必须为MATCH
     * @param _pid 是池索引
     * | 函数 | 状态要求 | 时间要求 | 操作类型 | 代币处理 | 使用场景 |
     * | `depositLend` | MATCH | 结算前 | 存入资金 | 转入池中 | 提供借贷资金 |
     * @param _stakeAmount 是用户的质押金额
     */
    function depositLend(uint256 _pid,uint256 _stakeAmount) external payable nonReentrant notPause timeBeforeSettle(_pid)
        stateMatch(_pid) 
    {
        PoolBaseInfo storage pool =poolBaseInfos[_pid];
        LendInfo storage lendInfo = userLendInfo[msg.sender][_pid];
        // 检查存款金额是否超过池的剩余容量
        require(_stakeAmount<=(pool.maxSupply).trySub(pool.lendSupply),"depositLend : stakeAmount is greater than maxSupply");
        uint256 amount = getPayableAmount(pool.lendToken,_stakeAmount);
        require(amount>minAmount, "depositLend: 少于最小存款金额");

        lendInfo.hasNoClaim=false;  // 重置领取标志，允许用户领取SP代币
        lendInfo.hasNoRefund=false; // 重置退款标志，允许用户申请退款
        //处理资金状态更新
        if(pool.lendToken == address(0)){
            //如果是ETH:使用msg.value 直接更新余额
            lendInfo.stakeAmount=lendInfo.stakeAmount.tryAdd(msg.value);
            pool.lendSupply=pool.lendSupply.tryAdd(msg.value);
        }else{
            //如果是ERC20代币:使用SafeERC20.safeTransferFrom 从用户账户转入
            lendInfo.stakeAmount=lendInfo.stakeAmount.tryAdd(amount);
            pool.lendSupply=pool.lendSupply.tryAdd(amount);
        }
        emit DepositLend(msg.sender,pool.lendToken,_stakeAmount,amount);
    }

    /**
     * @dev 退还过量存款给存款人
     * @notice 池状态不等于匹配和未完成
     * | 函数 | 状态要求 | 提取金额 | 是否计算利息 | 使用场景 |
     * | `refundLend` | EXECUTION/FINISH/LIQUIDATION | 超额部分 | ❌ 不计算利息 | 退还超额存款 |
     * @param _pid 是池索引
     */
    function refundLend(uint256 _pid) external nonReentrant notPause timeAfterSettle(_pid)
    stateNotMatchUndone(_pid)
    {
        PoolBaseInfo storage pool = poolBaseInfos[_pid];
        PoolDataInfo storage data = poolDataInfos[_pid];
        LendInfo storage lendInfo = userLendInfo[msg.sender][_pid];

        require(lendInfo.stakeAmount>0,"refundLend : not pledged"); // 需要用户已经质押了一定数量
        require(pool.lendSupply.trySub(data.settleAmountLend)>0,"refundLend : not refund");// 需要池中还有未退还的金额
        require(!lendInfo.hasNoRefund,"refundLend : already refunded");// 需要用户没有申请过退款

        //用户份额=当前质押金额/总金额
        uint256 userShare=lendInfo.stakeAmount.tryMul(calDecimals).tryDiv(pool.lendSupply);
        // refundAmount = 总退款金额 * 用户份额
        uint256 refundAmount=(pool.lendSupply.trySub(data.settleAmountLend)).tryMul(userShare).tryDiv(calDecimals);

        lendInfo.refundAmount=refundAmount;
        lendInfo.hasNoRefund=true;
        // 退还资金
        _redeem(msg.sender,pool.lendToken,refundAmount);
        // 更新用户信息
        lendInfo.hasNoRefund = true;
        lendInfo.refundAmount = lendInfo.refundAmount.tryAdd(refundAmount);
        emit RefundLend(msg.sender,pool.lendToken,refundAmount);
    }

     /**
     * @dev 存款人接收 sp_token,主要功能是让存款人领取 sp_token
     * @notice 池状态不等于匹配和未完成
     * @param _pid 是池索引 
     * | 函数 | 角色 | 操作 | 目的 |
     * | claimLend | 出借人 | 获得SP代币 | 获得资金凭证 |
     */
    function claimLend(uint256 _pid) external nonReentrant notPause timeAfterSettle(_pid)
    stateNotMatchUndone(_pid)
    {
        PoolBaseInfo storage pool = poolBaseInfos[_pid];
        PoolDataInfo storage data = poolDataInfos[_pid];
        LendInfo storage lendInfo = userLendInfo[msg.sender][_pid];
        //金额限制
        require(lendInfo.stakeAmount>0,"claimLend :cannot get sp_token"); //需要用户的质押金额大于0
        require(lendInfo.hasNoClaim==false,"claimLend :already claimed"); //需要用户没有领取过sp_token
    
        //用户份额=当前质押金额/总金额
        uint256 userShare=lendInfo.stakeAmount.tryMul(calDecimals).tryDiv(pool.lendSupply);
        uint256 totalSpAmount=data.settleAmountLend;// 总的Sp金额等于借款结算金额
        // 用户 sp 金额 = totalSpAmount * 用户份额
        uint256 spAmount=totalSpAmount.tryMul(userShare).tryDiv(calDecimals);
        pool.spCoin.mint(msg.sender,spAmount);        // 铸造 sp token 给存款人
        lendInfo.hasNoClaim=true; // 更新用户信息
        emit ClaimLend(msg.sender, pool.lendToken, spAmount); // 触发领取存款人领取SP代币事件  
    }

    /**
     * @dev 存款人取回本金和利息
     * @notice 池的状态可能是完成或清算
     * @param _pid 是池索引
     * @param _spAmount 是销毁的sp数量
     * | 函数 | 状态要求 | 提取金额 | 是否计算利息 | 使用场景 |
     * | `withdrawLend` | FINISH/LIQUIDATION | 按SP代币比例 | ✅ 计算利息 | 正常到期提取或者清算提取 |
     */
    function withdrawLend(uint256 _pid,uint256 _spAmount) external nonReentrant notPause
    stateFinishLiquidation(_pid)
    {
        PoolBaseInfo storage pool = poolBaseInfos[_pid];
        PoolDataInfo storage data = poolDataInfos[_pid];
        require(_spAmount>0,"withdrawLend : spAmount is zero");
        //销毁sp_token
        pool.spCoin.burn(msg.sender,_spAmount);
        uint256 totalSpAmount=data.settleAmountLend;// 总的Sp金额等于出借人借款结算金额
        // 用户 sp 金额 = totalSpAmount * 用户份额
        uint256 spShare=_spAmount.tryMul(calDecimals).tryDiv(totalSpAmount);
        //完成
        if(pool.state==PoolState.FINISH){
            require(block.timestamp>=pool.endTime,"withdrawLend : not end time");
            //赎回金额 = finishAmountLend * sp份额
            uint256 redeemAmount=data.finishAmountLend.tryMul(spShare).tryDiv(calDecimals);
            //退款
            _redeem(msg.sender,pool.lendToken,redeemAmount);
            emit WithdrawLend(msg.sender,pool.lendToken,redeemAmount,_spAmount);
        }
        //清算
        if (pool.state==PoolState.LIQUIDATIOM){
            require(block.timestamp>=pool.settleTime,"withdrawLend : less than settle time");
            //赎回金额 = liquidationAmounLend * sp份额
            uint256 redeemAmount=data.liquidationAmounLend.tryMul(spShare).tryDiv(calDecimals);
            //退款
            _redeem(msg.sender,pool.lendToken,redeemAmount);
            emit WithdrawLend(msg.sender,pool.lendToken,redeemAmount,_spAmount);
        }
    }
    /**
     * @dev 出借人紧急提取存款，用于处理池异常情况
     * @notice 池状态必须是未完成 
     * 什么情况下会出现UNDONE？
     * 1. **只有存款没有借款**：出借人存入资金，但没有借款人质押抵押品
     * 2. **只有借款没有存款**：借款人质押抵押品，但没有出借人提供资金
     * 3. **池创建失败**：池的配置有问题，无法正常运作
     * | 函数 | 状态要求 | 时间要求 | 操作类型 | 代币处理 | 使用场景 |
     * | `emergencyLendWithdrawal` | UNDONE | 无限制 | 紧急退出 | 转出全部存款 | 异常情况安全退出 |
     * @param _pid 是池索引
     */
    function emergencyLendWithdrawal(uint256 _pid) external nonReentrant notPause stateUndone(_pid)
    {
        PoolBaseInfo storage pool = poolBaseInfos[_pid];//获取池子基本信息
        require(pool.lendSupply>0,"emergencyLendWithdrawal : lendSupply is zero");//验证池的贷款供应量大于0

        LendInfo storage lendInfo = userLendInfo[msg.sender][_pid];
        //验证用户是否有存款记录
        require(lendInfo.stakeAmount>0,"emergencyLendWithdrawal : not pledged");
        //验证用户是否已经进行过退款
        require(lendInfo.hasNoRefund==false,"emergencyLendWithdrawal : already refunded");
        //执行赎回操作，提取全部存款
        _redeem(msg.sender,pool.lendToken,lendInfo.stakeAmount);
        //设置已经退款标志为真
        lendInfo.hasNoRefund=true;
        emit EmergencyLendWithdrawal(msg.sender,pool.lendToken,lendInfo.stakeAmount);
    }

    function setPause() public validCall{
        globalPaused=!globalPaused;
    }

    modifier notPause() {
        require(globalPaused==false,"PledgePool : Stake has been suspended");
        _;
    }

    modifier timeBeforeSettle(uint256 _pid) {
        require(block.timestamp<poolBaseInfos[_pid].settleTime,"PledgePool : Less than settle time");
        _;
    }

    modifier timeAfterSettle(uint256 _pid) {
        require(block.timestamp>=poolBaseInfos[_pid].settleTime,"PledgePool : After settle time");
        _;
    }

    modifier stateMatch(uint256 _pid) {
        require(poolBaseInfo[_pid].state == PoolState.MATCH, "state: Pool status is not equal to match");
        _;
    }

    modifier stateNotMatchUndone(uint256 _pid) {
        require(poolBaseInfo[_pid].state == PoolState.EXECUTION 
        || poolBaseInfo[_pid].state == PoolState.FINISH || 
        poolBaseInfo[_pid].state == PoolState.LIQUIDATION,
        "state: not match and undone");
        _;
    }

    modifier stateFinishLiquidation(uint256 _pid) {
        require(poolBaseInfo[_pid].state == PoolState.FINISH || poolBaseInfo[_pid].state == PoolState.LIQUIDATION,"state: finish liquidation");
        _;
    }

    modifier stateUndone(uint256 _pid) {
        require(poolBaseInfo[_pid].state == PoolState.UNDONE,"state: state must be undone");
        _;
    }
}