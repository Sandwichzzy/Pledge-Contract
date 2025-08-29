//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title IMultiSignature - 多签名合约接口
 * @dev 定义了多签名合约需要实现的核心功能接口
 */
interface IMultiSignature {
    /**
     * @dev 获取有效签名索引
     * @param msghash 消息哈希
     * @param lastIndex 上次检查的索引
     * @return uint256 返回有效的签名索引，如果没有达到阈值则返回0
     */
    function getValidSignature(bytes32 msghash, uint256 lastIndex) external view returns (uint256);
}

/**
 * @title multiSignatureClient - 多签名客户端合约
 * @dev 为其他合约提供多签名验证功能的基础合约
 * @notice 任何需要多签名保护的合约都应该继承此合约，并使用validCall修饰符
 * 
 * === 工作原理 ===
 * 1. 客户端合约继承此合约，获得多签名验证能力
 * 2. 重要函数使用validCall修饰符进行保护
 * 3. 调用时会自动检查对应的多签名申请是否已获得足够签名
 * 4. 只有通过多签名验证的调用才能执行
 */
contract multiSignatureClient {
    uint256 public constant multiSignaturePosition = uint256(keccak256("org.multiSignature.storage"));// 多签名合约地址的存储位置
    uint256 private constant defaultIndex = 0;// 默认索引

    /**
     * @dev 构造函数
     * @param multiSignature 多签名合约地址
     * @notice 将多签名合约地址保存到固定的存储位置
     */
    constructor(address multiSignature) {
        require(multiSignature != address(0), "multiSignatureClient : Multiple signature contract address is zero!");
        saveValue(multiSignaturePosition, uint256(uint160(multiSignature)));
    }

    //从存储中读取多签名合约地址
    function getMultiSignatureAddress() public view returns (address){
        return address(uint160(getValue(multiSignaturePosition)));
    }

    /**
     * @dev 多签名验证修饰符
     * @notice 使用此修饰符的函数只有在多签名验证通过后才能执行
     * @notice 这是整个多签名系统的核心验证机制
     */
    modifier validCall(){
        checkMultiSignature();
        _;
    }

    /**
     * @dev 检查多签名验证
     * @notice 核心验证逻辑：
     * 1. 生成消息哈希（调用者地址 + 当前合约地址）
     * 2. 向多签名合约查询该哈希是否有足够的签名
     * 3. 如果没有足够签名，交易将回滚
     */
    function checkMultiSignature() internal view {
        uint256 value;
        // 获取调用的以太币值（当前未使用，为未来扩展预留）
        assembly {
            value:=callvalue()
        }
        // 生成唯一的消息哈希：调用者地址 + 目标合约地址
        // 这确保了每个(调用者, 目标合约)组合都有唯一的哈希
        bytes32 msghash = keccak256(abi.encodePacked(msg.sender, address(this)));
        // 获取多签名合约地址
        address multiSign=getMultiSignatureAddress();

        // 查询多签名合约，检查是否有足够的签名
        // getValidSignature的实现逻辑（在multiSignature.sol中）：
        // 1. 遍历该msgHash对应的所有申请
        // 2. 检查每个申请的签名数量是否 >= threshold
        // 3. 如果找到达到阈值的申请，返回其索引+1（确保非零）
        // 4. 如果没有找到，返回0
        uint256 newIndex=IMultiSignature(multiSign).getValidSignature(msghash,defaultIndex);
        require(newIndex>defaultIndex,"multiSignatureClient : This tx is not aprroved");
    }

    /**
     * @dev 保存值到指定存储位置
     * @param position 存储位置（使用keccak256生成的唯一位置）
     * @param value 要保存的值
     * @notice 使用内联汇编直接操作存储，提高gas效率
     */
    function saveValue(uint256 position, uint256 value) internal {
        assembly {
            sstore(position, value)
        }
    }

    /**
     * @dev 从指定存储位置读取值
     * @param position 存储位置（使用keccak256生成的唯一位置）
     * @return value 读取的值
     * @notice 使用内联汇编直接操作存储，提高gas效率
     */
    function getValue(uint256 position) internal view returns (uint256 value) {
        assembly {
            value := sload(position)
        }
    }


}