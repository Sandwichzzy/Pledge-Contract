/**
 * @title UniswapV2Factory - Uniswap V2 工厂合约和相关接口
 * @dev 这是Uniswap V2的完整实现，包含工厂合约、配对合约、ERC20实现和相关接口
 * @notice 在2020年5月4日提交到Etherscan进行验证
 */
//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title IUniswapV2Factory - Uniswap V2 工厂接口
 * @dev 定义了工厂合约的核心功能接口
 */
interface IUniswapV2Factory {


    /**
     * @dev 获取费用接收地址
     * @return 接收交易费用的地址
     */
    function feeTo() external view returns (address);
    
    /**
     * @dev 获取费用设置者地址
     * @return 可以设置费用接收地址的管理员地址
     */
    function feeToSetter() external view returns (address);

    /**
     * @dev 获取两个代币的交易对地址
     * @param tokenA 第一个代币地址
     * @param tokenB 第二个代币地址
     * @return pair 交易对合约地址，如果不存在则返回零地址
     */
    function getPair(address tokenA, address tokenB) external view returns (address pair);
    

    function allPairs(uint) external view returns (address pair);
    
    /**
     * @dev 获取所有交易对的数量
     * @return 交易对总数
     */
    function allPairsLength() external view returns (uint);

    /**
     * @dev 为两个代币创建新的交易对
     * @param tokenA 第一个代币地址
     * @param tokenB 第二个代币地址
     * @return pair 新创建的交易对地址
     */
    function createPair(address tokenA, address tokenB) external returns (address pair);


    function setFeeTo(address) external;
    

    function setFeeToSetter(address) external;
}

/**
 * @title IUniswapV2Pair - Uniswap V2 交易对接口
 * @dev 定义了交易对合约的所有功能，包括ERC20功能和AMM特定功能
 */
interface IUniswapV2Pair {
    // ERC20 标准事件
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    // ERC20 基础功能
    function name() external pure returns (string memory);
    function symbol() external pure returns (string memory);
    function decimals() external pure returns (uint8);
    function totalSupply() external view returns (uint);
    function balanceOf(address owner) external view returns (uint);
    function allowance(address owner, address spender) external view returns (uint);

    function approve(address spender, uint value) external returns (bool);
    function transfer(address to, uint value) external returns (bool);
    function transferFrom(address from, address to, uint value) external returns (bool);

    // EIP-712 签名相关
    function DOMAIN_SEPARATOR() external view returns (bytes32);
    function PERMIT_TYPEHASH() external pure returns (bytes32);
    function nonces(address owner) external view returns (uint);

    /**
     * @dev 通过签名授权，实现无gas费授权（EIP-2612）
     */
    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external;

    // AMM 特定事件
    event Mint(address indexed sender, uint amount0, uint amount1);
    event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint amount0In,
        uint amount1In,
        uint amount0Out,
        uint amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    // AMM 核心功能
    function MINIMUM_LIQUIDITY() external pure returns (uint);
    function factory() external view returns (address);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function price0CumulativeLast() external view returns (uint);
    function price1CumulativeLast() external view returns (uint);
    function kLast() external view returns (uint);

    /**
     * @dev 添加流动性，铸造LP代币
     * @param to LP代币接收地址
     * @return liquidity 铸造的LP代币数量
     */
    function mint(address to) external returns (uint liquidity);
    
    /**
     * @dev 移除流动性，销毁LP代币
     * @param to 代币接收地址
     * @return amount0 代币0的返还数量
     * @return amount1 代币1的返还数量
     */
    function burn(address to) external returns (uint amount0, uint amount1);
    
    /**
     * @dev 执行代币交换
     * @param amount0Out 代币0的输出数量
     * @param amount1Out 代币1的输出数量
     * @param to 代币接收地址
     * @param data 回调数据
     */
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
    
    /**
     * @dev 强制余额匹配储备量
     * @param to 多余代币的接收地址
     */
    function skim(address to) external;
    
    /**
     * @dev 强制储备量匹配余额
     */
    function sync() external;


    function initialize(address, address) external;
}

/**
 * @title IUniswapV2ERC20 - Uniswap V2 ERC20接口
 * @dev 扩展了标准ERC20接口，添加了permit功能
 */
interface IUniswapV2ERC20 {
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    function name() external pure returns (string memory);
    function symbol() external pure returns (string memory);
    function decimals() external pure returns (uint8);
    function totalSupply() external view returns (uint);
    function balanceOf(address owner) external view returns (uint);
    function allowance(address owner, address spender) external view returns (uint);

    function approve(address spender, uint value) external returns (bool);
    function transfer(address to, uint value) external returns (bool);
    function transferFrom(address from, address to, uint value) external returns (bool);

    function DOMAIN_SEPARATOR() external view returns (bytes32);
    function PERMIT_TYPEHASH() external pure returns (bytes32);
    function nonces(address owner) external view returns (uint);

    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external;
}

/**
 * @title IERC20 - 标准ERC20接口
 * @dev 定义了ERC20代币的基础功能
 */
interface IERC20 {
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    function name() external view returns (string memory);
    function symbol() external pure returns (string memory);
    function decimals() external pure returns (uint8);
    function totalSupply() external view returns (uint);
    function balanceOf(address owner) external view returns (uint);
    function allowance(address owner, address spender) external view returns (uint);

    function approve(address spender, uint value) external returns (bool);
    function transfer(address to, uint value) external returns (bool);
    function transferFrom(address from, address to, uint value) external returns (bool);
}

/**
 * @title IUniswapV2Callee - Uniswap V2 回调接口
 * @dev 用于闪电贷等高级功能的回调接口
 */
interface IUniswapV2Callee {
    /**
     * @dev Uniswap V2回调函数
     * @param sender 调用者地址
     * @param amount0 代币0数量
     * @param amount1 代币1数量
     * @param data 回调数据
     */
    function uniswapV2Call(address sender, uint amount0, uint amount1, bytes calldata data) external;
}

/**
 * @title UniswapV2ERC20 - Uniswap V2 ERC20实现
 * @dev 实现了ERC20功能和permit签名授权功能
 */
contract UniswapV2ERC20 is IUniswapV2ERC20 {
    using SafeMath for uint;

    // 代币基本信息
    string public constant name = 'Uniswap V2';
    string public constant symbol = 'UNI-V2';
    uint8 public constant decimals = 18;
    uint  public totalSupply;                    // 总供应量
    mapping(address => uint) public balanceOf;   // 账户余额
    mapping(address => mapping(address => uint)) public allowance; // 授权额度

    // EIP-712 签名相关
    bytes32 public DOMAIN_SEPARATOR;
    // permit函数的类型哈希
    bytes32 public constant PERMIT_TYPEHASH = 0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9;
    mapping(address => uint) public nonces;     // 防重放攻击的nonce

    constructor() {
        uint chainId;
        assembly {
            chainId := chainid()
        }
        // 初始化EIP-712域分隔符
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256('EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)'),
                keccak256(bytes(name)),
                keccak256(bytes('1')),
                chainId,
                address(this)
            )
        );
    }

    /**
     * @dev 铸造代币
     * @param to 接收地址
     * @param value 铸造数量
     */
    function _mint(address to, uint value) internal {
        totalSupply = totalSupply.add(value);
        balanceOf[to] = balanceOf[to].add(value);
        emit Transfer(address(0), to, value);
    }

    /**
     * @dev 销毁代币
     * @param from 销毁地址
     * @param value 销毁数量
     */
    function _burn(address from, uint value) internal {
        balanceOf[from] = balanceOf[from].sub(value);
        totalSupply = totalSupply.sub(value);
        emit Transfer(from, address(0), value);
    }

    /**
     * @dev 内部授权函数
     * @param owner 授权者
     * @param spender 被授权者
     * @param value 授权数量
     */
    function _approve(address owner, address spender, uint value) private {
        allowance[owner][spender] = value;
        emit Approval(owner, spender, value);
    }

    /**
     * @dev 内部转账函数
     * @param from 发送方
     * @param to 接收方
     * @param value 转账数量
     */
    function _transfer(address from, address to, uint value) private {
        balanceOf[from] = balanceOf[from].sub(value);
        balanceOf[to] = balanceOf[to].add(value);
        emit Transfer(from, to, value);
    }

    /**
     * @dev 授权函数
     * @param spender 被授权地址
     * @param value 授权数量
     * @return 是否成功
     */
    function approve(address spender, uint value) external returns (bool) {
        _approve(msg.sender, spender, value);
        return true;
    }

    /**
     * @dev 转账函数
     * @param to 接收地址
     * @param value 转账数量
     * @return 是否成功
     */
    function transfer(address to, uint value) external returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    /**
     * @dev 授权转账函数
     * @param from 发送方
     * @param to 接收方
     * @param value 转账数量
     * @return 是否成功
     */
    function transferFrom(address from, address to, uint value) external returns (bool) {
        if (allowance[from][msg.sender] != type(uint).max) {
            allowance[from][msg.sender] = allowance[from][msg.sender].sub(value);
        }
        _transfer(from, to, value);
        return true;
    }

    /**
     * @dev 通过签名进行授权（EIP-2612）
     * @param owner 代币拥有者
     * @param spender 被授权者
     * @param value 授权数量
     * @param deadline 截止时间
     * @param v 签名参数v
     * @param r 签名参数r
     * @param s 签名参数s
     */
    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external {
        require(deadline >= block.timestamp, 'UniswapV2: EXPIRED');
        bytes32 digest = keccak256(
            abi.encodePacked(
                '\x19\x01',
                DOMAIN_SEPARATOR,
                keccak256(abi.encode(PERMIT_TYPEHASH, owner, spender, value, nonces[owner]++, deadline))
            )
        );
        address recoveredAddress = ecrecover(digest, v, r, s);
        require(recoveredAddress != address(0) && recoveredAddress == owner, 'UniswapV2: INVALID_SIGNATURE');
        _approve(owner, spender, value);
    }
}

/**
 * @title UniswapV2Pair - Uniswap V2 交易对合约
 * @dev 实现了AMM核心逻辑的交易对合约
 */
contract UniswapV2Pair is UniswapV2ERC20 {
    using SafeMath  for uint;
    using UQ112x112 for uint224;

    uint public constant MINIMUM_LIQUIDITY = 10**3; // 最小流动性
    bytes4 private constant SELECTOR = bytes4(keccak256(bytes('transfer(address,uint256)'))); // transfer函数选择器

    address public factory;    // 工厂合约地址
    address public token0;     // 第一个代币地址
    address public token1;     // 第二个代币地址

    uint112 private reserve0;           // 代币0储备量（打包存储以节省gas）
    uint112 private reserve1;           // 代币1储备量（打包存储以节省gas）
    uint32  private blockTimestampLast; // 最后更新时间戳（打包存储以节省gas）

    uint public price0CumulativeLast;   // 代币0累积价格
    uint public price1CumulativeLast;   // 代币1累积价格
    uint public kLast; // reserve0 * reserve1，用于计算费用

    uint private unlocked = 1; // 重入锁
    modifier lock() {
        require(unlocked == 1, 'UniswapV2: LOCKED');
        unlocked = 0;
        _;
        unlocked = 1;
    }

    /**
     * @dev 获取储备量信息
     * @return _reserve0 代币0储备量
     * @return _reserve1 代币1储备量  
     * @return _blockTimestampLast 最后更新时间戳
     */
    function getReserves() public view returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast) {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
        _blockTimestampLast = blockTimestampLast;
    }

    /**
     * @dev 安全转账函数
     * @param token 代币地址
     * @param to 接收地址
     * @param value 转账数量
     */
    function _safeTransfer(address token, address to, uint value) private {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(SELECTOR, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'UniswapV2: TRANSFER_FAILED');
    }

    event Mint(address indexed sender, uint amount0, uint amount1);
    event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint amount0In,
        uint amount1In,
        uint amount0Out,
        uint amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    constructor() {
        factory = msg.sender;
    }

    /**
     * @dev 初始化交易对（仅工厂调用一次）
     * @param _token0 第一个代币地址
     * @param _token1 第二个代币地址
     */
    function initialize(address _token0, address _token1) external {
        require(msg.sender == factory, 'UniswapV2: FORBIDDEN');
        token0 = _token0;
        token1 = _token1;
    }

    /**
     * @dev 更新储备量和价格累积器
     * @param balance0 代币0当前余额
     * @param balance1 代币1当前余额
     * @param _reserve0 代币0之前储备量
     * @param _reserve1 代币1之前储备量
     */
    function _update(uint balance0, uint balance1, uint112 _reserve0, uint112 _reserve1) private {
        require(balance0 <= type(uint112).max && balance1 <= type(uint112).max, 'UniswapV2: OVERFLOW');
        uint32 blockTimestamp = uint32(block.timestamp % 2**32);
        uint32 timeElapsed = blockTimestamp - blockTimestampLast; // 时间差（允许溢出）
        if (timeElapsed > 0 && _reserve0 != 0 && _reserve1 != 0) {
            // 更新价格累积器，永不溢出，允许+溢出
            price0CumulativeLast += uint(UQ112x112.encode(_reserve1).uqdiv(_reserve0)) * timeElapsed;
            price1CumulativeLast += uint(UQ112x112.encode(_reserve0).uqdiv(_reserve1)) * timeElapsed;
        }
        reserve0 = uint112(balance0);
        reserve1 = uint112(balance1);
        blockTimestampLast = blockTimestamp;
        emit Sync(reserve0, reserve1);
    }

    /**
     * @dev 如果启用费用，铸造等于sqrt(k)增长1/6的流动性
     * @param _reserve0 代币0储备量
     * @param _reserve1 代币1储备量
     * @return feeOn 是否开启费用
     */
    function _mintFee(uint112 _reserve0, uint112 _reserve1) private returns (bool feeOn) {
        address feeTo = IUniswapV2Factory(factory).feeTo();
        feeOn = feeTo != address(0);
        uint _kLast = kLast; // 节省gas
        if (feeOn) {
            if (_kLast != 0) {
                uint rootK = Math.sqrt(uint(_reserve0).mul(_reserve1));
                uint rootKLast = Math.sqrt(_kLast);
                if (rootK > rootKLast) {
                    uint numerator = totalSupply.mul(rootK.sub(rootKLast));
                    uint denominator = rootK.mul(5).add(rootKLast);
                    uint liquidity = numerator / denominator;
                    if (liquidity > 0) _mint(feeTo, liquidity);
                }
            }
        } else if (_kLast != 0) {
            kLast = 0;
        }
    }

    /**
     * @dev 添加流动性，铸造LP代币
     * 这是一个低级函数，应该从执行重要安全检查的合约中调用
     * @param to LP代币接收地址
     * @return liquidity 铸造的LP代币数量
     */
    function mint(address to) external lock returns (uint liquidity) {
        (uint112 _reserve0, uint112 _reserve1,) = getReserves(); // 节省gas
        uint balance0 = IERC20(token0).balanceOf(address(this));
        uint balance1 = IERC20(token1).balanceOf(address(this));
        uint amount0 = balance0.sub(_reserve0);
        uint amount1 = balance1.sub(_reserve1);

        bool feeOn = _mintFee(_reserve0, _reserve1);
        uint _totalSupply = totalSupply; // 必须在这里定义，因为totalSupply可能在_mintFee中更新
        if (_totalSupply == 0) {
            liquidity = Math.sqrt(amount0.mul(amount1)).sub(MINIMUM_LIQUIDITY);
           _mint(address(0), MINIMUM_LIQUIDITY); // 永久锁定第一个MINIMUM_LIQUIDITY代币
        } else {
            liquidity = Math.min(amount0.mul(_totalSupply) / _reserve0, amount1.mul(_totalSupply) / _reserve1);
        }
        require(liquidity > 0, 'UniswapV2: INSUFFICIENT_LIQUIDITY_MINTED');
        _mint(to, liquidity);

        _update(balance0, balance1, _reserve0, _reserve1);
        if (feeOn) kLast = uint(reserve0).mul(reserve1); // reserve0和reserve1是最新的
        emit Mint(msg.sender, amount0, amount1);
    }

    /**
     * @dev 移除流动性，销毁LP代币
     * 这是一个低级函数，应该从执行重要安全检查的合约中调用
     * @param to 代币接收地址
     * @return amount0 代币0返还数量
     * @return amount1 代币1返还数量
     */
    function burn(address to) external lock returns (uint amount0, uint amount1) {
        (uint112 _reserve0, uint112 _reserve1,) = getReserves(); // 节省gas
        address _token0 = token0;                                // 节省gas
        address _token1 = token1;                                // 节省gas
        uint balance0 = IERC20(_token0).balanceOf(address(this));
        uint balance1 = IERC20(_token1).balanceOf(address(this));
        uint liquidity = balanceOf[address(this)];

        bool feeOn = _mintFee(_reserve0, _reserve1);
        uint _totalSupply = totalSupply; // 必须在这里定义，因为totalSupply可能在_mintFee中更新
        amount0 = liquidity.mul(balance0) / _totalSupply; // 使用余额确保按比例分配
        amount1 = liquidity.mul(balance1) / _totalSupply; // 使用余额确保按比例分配
        require(amount0 > 0 && amount1 > 0, 'UniswapV2: INSUFFICIENT_LIQUIDITY_BURNED');
        _burn(address(this), liquidity);
        _safeTransfer(_token0, to, amount0);
        _safeTransfer(_token1, to, amount1);
        balance0 = IERC20(_token0).balanceOf(address(this));
        balance1 = IERC20(_token1).balanceOf(address(this));

        _update(balance0, balance1, _reserve0, _reserve1);
        if (feeOn) kLast = uint(reserve0).mul(reserve1); // reserve0和reserve1是最新的
        emit Burn(msg.sender, amount0, amount1, to);
    }

    /**
     * @dev 执行代币交换
     * 这是一个低级函数，应该从执行重要安全检查的合约中调用
     * @param amount0Out 代币0输出数量
     * @param amount1Out 代币1输出数量
     * @param to 代币接收地址
     * @param data 回调数据
     */
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external lock {
        require(amount0Out > 0 || amount1Out > 0, 'UniswapV2: INSUFFICIENT_OUTPUT_AMOUNT');
        (uint112 _reserve0, uint112 _reserve1,) = getReserves(); // 节省gas
        require(amount0Out < _reserve0 && amount1Out < _reserve1, 'UniswapV2: INSUFFICIENT_LIQUIDITY');

        uint balance0;
        uint balance1;
        { // 作用域限制_token{0,1}，避免堆栈过深错误
        address _token0 = token0;
        address _token1 = token1;
        require(to != _token0 && to != _token1, 'UniswapV2: INVALID_TO');
        if (amount0Out > 0) _safeTransfer(_token0, to, amount0Out); // 乐观转账代币
        if (amount1Out > 0) _safeTransfer(_token1, to, amount1Out); // 乐观转账代币
        if (data.length > 0) IUniswapV2Callee(to).uniswapV2Call(msg.sender, amount0Out, amount1Out, data);
        balance0 = IERC20(_token0).balanceOf(address(this));
        balance1 = IERC20(_token1).balanceOf(address(this));
        }
        uint amount0In = balance0 > _reserve0 - amount0Out ? balance0 - (_reserve0 - amount0Out) : 0;
        uint amount1In = balance1 > _reserve1 - amount1Out ? balance1 - (_reserve1 - amount1Out) : 0;
        require(amount0In > 0 || amount1In > 0, 'UniswapV2: INSUFFICIENT_INPUT_AMOUNT');
        { // 作用域限制reserve{0,1}Adjusted，避免堆栈过深错误
        uint balance0Adjusted = balance0.mul(1000).sub(amount0In.mul(3));
        uint balance1Adjusted = balance1.mul(1000).sub(amount1In.mul(3));
        require(balance0Adjusted.mul(balance1Adjusted) >= uint(_reserve0).mul(_reserve1).mul(1000**2), 'UniswapV2: K');
        }

        _update(balance0, balance1, _reserve0, _reserve1);
        emit Swap(msg.sender, amount0In, amount1In, amount0Out, amount1Out, to);
    }

    /**
     * @dev 强制余额匹配储备量
     * @param to 多余代币的接收地址
     */
    function skim(address to) external lock {
        address _token0 = token0; // 节省gas
        address _token1 = token1; // 节省gas
        _safeTransfer(_token0, to, IERC20(_token0).balanceOf(address(this)).sub(reserve0));
        _safeTransfer(_token1, to, IERC20(_token1).balanceOf(address(this)).sub(reserve1));
    }

    /**
     * @dev 强制储备量匹配余额
     */
    function sync() external lock {
        _update(IERC20(token0).balanceOf(address(this)), IERC20(token1).balanceOf(address(this)), reserve0, reserve1);
    }
}

/**
 * @title UniswapV2Factory - Uniswap V2 工厂合约实现
 * @dev 负责创建和管理所有的交易对合约
 */
contract UniswapV2Factory is IUniswapV2Factory {
    address public feeTo;        // 费用接收地址
    address public feeToSetter;  // 费用设置者地址
    // 添加以避免每次元数据更改时都改变
    bytes32 public initCodeHash; // 初始化代码哈希

    mapping(address => mapping(address => address)) public getPair; // 代币对映射
    address[] public allPairs;   // 所有交易对数组

    event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    constructor(address _feeToSetter) {
        feeToSetter = _feeToSetter;
        initCodeHash = keccak256(abi.encodePacked(type(UniswapV2Pair).creationCode));
    }

    /**
     * @dev 获取所有交易对数量
     * @return 交易对总数
     */
    function allPairsLength() external view returns (uint) {
        return allPairs.length;
    }

    /**
     * @dev 为两个代币创建交易对
     * @param tokenA 第一个代币地址
     * @param tokenB 第二个代币地址
     * @return pair 新创建的交易对地址
     */
    function createPair(address tokenA, address tokenB) external returns (address pair) {
        require(tokenA != tokenB, 'UniswapV2: IDENTICAL_ADDRESSES');
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'UniswapV2: ZERO_ADDRESS');
        require(getPair[token0][token1] == address(0), 'UniswapV2: PAIR_EXISTS'); // 单一检查就足够了
        bytes memory bytecode = type(UniswapV2Pair).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        IUniswapV2Pair(pair).initialize(token0, token1);
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair; // 反向映射
        allPairs.push(pair);

        emit PairCreated(token0, token1, pair, allPairs.length);
    }

    /**
     * @dev 设置费用接收地址
     * @param _feeTo 新的费用接收地址
     */
    function setFeeTo(address _feeTo) external {
        require(msg.sender == feeToSetter, 'UniswapV2: FORBIDDEN');
        feeTo = _feeTo;
    }

    /**
     * @dev 设置费用设置者地址
     * @param _feeToSetter 新的费用设置者地址
     */
    function setFeeToSetter(address _feeToSetter) external {
        require(msg.sender == feeToSetter, 'UniswapV2: FORBIDDEN');
        feeToSetter = _feeToSetter;
    }
}

/**
 * @title SafeMath - 安全数学运算库
 * @dev 提供溢出安全的数学运算，来源于DappHub (https://github.com/dapphub/ds-math)
 */
library SafeMath {
    /**
     * @dev 安全加法
     * @param x 第一个操作数
     * @param y 第二个操作数  
     * @return z 加法结果
     */
    function add(uint x, uint y) internal pure returns (uint z) {
        require((z = x + y) >= x, 'ds-math-add-overflow');
    }

    /**
     * @dev 安全减法
     * @param x 被减数
     * @param y 减数
     * @return z 减法结果
     */
    function sub(uint x, uint y) internal pure returns (uint z) {
        require((z = x - y) <= x, 'ds-math-sub-underflow');
    }

    /**
     * @dev 安全乘法
     * @param x 第一个操作数
     * @param y 第二个操作数
     * @return z 乘法结果
     */
    function mul(uint x, uint y) internal pure returns (uint z) {
        require(y == 0 || (z = x * y) / y == x, 'ds-math-mul-overflow');
    }
}

/**
 * @title Math - 数学运算库
 * @dev 提供各种数学运算函数
 */
library Math {
    /**
     * @dev 返回两个数中的较小值
     * @param x 第一个数
     * @param y 第二个数
     * @return z 较小值
     */
    function min(uint x, uint y) internal pure returns (uint z) {
        z = x < y ? x : y;
    }

    /**
     * @dev 计算平方根（巴比伦方法）
     * @notice 实现参考：https://en.wikipedia.org/wiki/Methods_of_computing_square_roots#Babylonian_method
     * @param y 被开方数
     * @return z 平方根
     */
    function sqrt(uint y) internal pure returns (uint z) {
        if (y > 3) {
            z = y;
            uint x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }
}

/**
 * @title UQ112x112 - 二进制定点数库
 * @dev 处理二进制定点数的库 (https://en.wikipedia.org/wiki/Q_(number_format))
 * @notice 范围: [0, 2**112 - 1]，精度: 1 / 2**112
 */
library UQ112x112 {
    uint224 constant Q112 = 2**112;

    /**
     * @dev 将uint112编码为UQ112x112
     * @param y 输入的uint112数值
     * @return z 编码后的UQ112x112数值
     */
    function encode(uint112 y) internal pure returns (uint224 z) {
        z = uint224(y) * Q112; // 永不溢出
    }

    /**
     * @dev UQ112x112除以uint112，返回UQ112x112
     * @param x 被除数（UQ112x112格式）
     * @param y 除数（uint112格式）
     * @return z 除法结果（UQ112x112格式）
     */
    function uqdiv(uint224 x, uint112 y) internal pure returns (uint224 z) {
        z = x / uint224(y);
    }
}