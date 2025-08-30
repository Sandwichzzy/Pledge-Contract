//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

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
        uint256 maxSupply; //池子最大限额 比如100万投资人最多往里面放100万资金
        uint256 lendSupply; //当前实际存款的借款方代币数量
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
        bool hasNoClaim;              // 是否已认领资金：false=未认领，true=已认领
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
    // 存款借出事件，from是借出者地址，token是借出的代币地址，amount是借出的数量，mintAmount是生成的数量
    event DepositLend(address indexed from,address indexed token,uint256 amount,uint256 mintAmount);
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
     * 包括结算时间、结束时间、利率、最大供应量、抵押率、借款代币、借出代币、SP代币、JP代币和自动清算阈值。
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
     * @dev 存款人执行存款操作
     * @notice 池状态必须为MATCH
     * @param _pid 是池索引
     * @param _stakeAmount 是用户的质押金额
     */
    function depositLend(uint256 _pid,uint256 _stakeAmount) external payable nonReentrant notPause timeBefore(_pid)
        stateMatch(_pid) 
    {
        PoolBaseInfo storage pool =poolBaseInfos[_pid];
        LendInfo storage lendInfo = userLendInfo[msg.sender][_pid];
        require(_stakeAmount<=(pool.maxSupply).sub(pool.lendSupply),"depositLend : stakeAmount is greater than maxSupply");
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