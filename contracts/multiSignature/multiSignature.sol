// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./multiSignatureClient.sol";

/**
 * @title whiteListAddress - 白名单地址管理库
 * @dev 提供地址数组的增删查功能，用于管理签名者白名单
 */
library whiteListAddress {
    //add whiteList
    function addWhiteListAddress(address[] storage whiteList,address temp) internal {
        if(!isEligibleAddress(whiteList,temp)){
            whiteList.push(temp);
        }
    }
    /**
     * @dev 从白名单中移除地址
     * @param whiteList 白名单地址数组（存储引用）
     * @param temp 要移除的地址
     * @return bool 返回是否成功移除
     * @notice 使用交换删除法，将最后一个元素移到被删除位置，然后删除最后一个元素
     */
    function removeWhiteListAddress(address[] storage whiteList,address temp) internal returns (bool) {
        uint256 len=whiteList.length;
        uint256 i=0;
        for (;i<len;i++){
            if(whiteList[i]==temp){
                break;
            }
        }
        if(i<len){
            // 如果删除的不是最后一个元素，将最后一个元素移到被删除位置
            if(i<len-1){
                whiteList[i]=whiteList[len-1];
            }
            // 删除最后一个元素
            whiteList.pop();
            return true;
        }
        return false;
    }

    //check if the address is in the whiteList
    function isEligibleAddress(address[] storage whiteList,address temp) internal view returns (bool) {
        uint256 len=whiteList.length;
        for (uint256 i=0;i<len;i++){
            if(whiteList[i]==temp){
                return true;
            }
        }
        return false;
    }
}

/**
 * @title multiSignature - 多签名合约
 * @dev 实现多签名治理机制，要求多个签名者同意才能执行重要操作
 * @notice 这是整个系统的核心治理合约，所有重要操作都需要通过多签名验证
 */
contract multiSignature is multiSignatureClient {

    uint256 private constant defaultIndex=0; // 默认申请索引
    using whiteListAddress for address[];  // 使用白名单地址库
    address[] public signatureOwners; // 签名者地址数组
    uint256 public threshold; // 签名阈值（需要多少个签名才能通过）
    
    struct signatureInfo{
        address applicant; // 申请人地址
        address[] signatures; // 签名者列表
    }
    // 消息哈希 => 签名信息数组的映射
    mapping(bytes32=>signatureInfo[]) signatureMap;

    event TransferOwner(address indexed sender, address indexed oldOwner, address indexed newOwner);
    event CreateApplication(address indexed from,address indexed to,bytes32 indexed msgHash);
    /**
     * @dev 签名申请事件
     * @param from 签名者地址
     * @param msgHash 消息哈希
     * @param index 申请索引
     */
    event SignApplication(address indexed from, bytes32 indexed msgHash,uint256 index); 
    event RevokeApplication(address indexed from,bytes32 indexed msgHash,uint256 index);

    /**
     * @dev 构造函数
     * @param owners 初始签名者地址数组
     * @param limitedSignNum 签名阈值
     * @notice 签名者数量必须大于等于签名阈值
     */
    constructor(address[] memory owners, uint256 limitedSignNum) multiSignatureClient(address(this)) {
        require(owners.length>=limitedSignNum,"Multiple Signature : Signature threshold is greater than owners' length!");
        signatureOwners=owners;
        threshold=limitedSignNum;
    }
    /**
     * @dev 转移签名者所有权
     * @param index 要替换的签名者在数组中的索引
     * @param newOwner 新的签名者地址
     * @notice 只有现有签名者且通过多签名验证才能调用
     */
    function transferOwner(uint256 index, address newOwner) public onlyOwner validCall{
        require(index<signatureOwners.length,"Multiple Signature : Owner index is overflow!");
        emit TransferOwner(msg.sender,signatureOwners[index],newOwner);
        signatureOwners[index]=newOwner;
    }

    /**
     * @dev 创建多签名申请
     * @param to 申请目标合约地址
     * @return uint256 返回申请的索引
     * @notice 任何人都可以创建申请，但需要足够的签名才能生效
     */
    function createApplication(address to) external returns (uint256) {
        // 生成唯一的消息哈希
        bytes32 msgHash =getApplicationHash(msg.sender,to);
        uint256 index=signatureMap[msgHash].length;
        //创建新的签名消息，初始时签名数组为空
        signatureMap[msgHash].push(signatureInfo(msg.sender,new address[](0)));
        emit CreateApplication(msg.sender,to,msgHash);
        return index;
    }

    /**
     * @dev 对申请进行签名
     * @param msghash 申请的消息哈希
     * @notice 只有签名者可以调用，且会自动添加到签名列表中
     *  === defaultIndex使用说明 ===
     * 当前实现中总是使用defaultIndex(0)，表示：
     * 1. 只对第一个申请进行签名（简化实现）
     * 2. 一个msgHash在当前版本中只有一个有效申请
     * 3. 未来可扩展为支持多个申请，用户可选择对哪个申请签名
     */
    function signApplication(bytes32 msghash) external onlyOwner validIndex(msghash,defaultIndex){
        emit SignApplication(msg.sender,msghash,defaultIndex);
        // 将签名者地址添加到该申请的签名列表中
        signatureMap[msghash][defaultIndex].signatures.push(msg.sender);
    }

    /**
     * @dev 撤销对申请的签名
     * @param msghash 申请的消息哈希
     * @notice 只有已签名的签名者可以撤销自己的签名
     * 同signApplication，当前只支持对索引0的申请撤销签名
     * 这与signApplication保持一致，确保操作的对称性
     */
    function revokeApplication(bytes32 msghash)external onlyOwner validIndex(msghash,defaultIndex){
        emit RevokeApplication(msg.sender,msghash,defaultIndex);
        signatureMap[msghash][defaultIndex].signatures.removeWhiteListAddress(msg.sender);
    }

    /**
     * @dev 获取有效的签名索引
     * @param msghash 消息哈希
     * @param lastIndex 上次检查的索引
     * @return uint256 返回达到阈值的申请索引+1，如果没有则返回0
     * @notice 这是多签名验证的核心函数，由客户端合约调用
     */
   function getValidSignature(bytes32 msghash,uint256 lastIndex) external view returns (uint256){
        signatureInfo[] storage signInfo=signatureMap[msghash];
         // 从lastIndex开始检查每个申请
        for (uint256 i=lastIndex;i<signInfo.length;i++){
            // 如果签名数量达到阈值，返回索引+1
            if(signInfo[i].signatures.length>=threshold){
                return i+1;
            }
        }
        return 0;// 没有达到阈值的申请
   }

    /**
     * @dev 生成申请哈希
     * @param from 申请发起者地址
     * @param to 申请目标地址
     * @return bytes32 生成的消息哈希
     * @notice 哈希由发起者和目标地址组成，确保唯一性
     */
    function getApplicationHash(address from,address to) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(from,to));
    }
    /**
     * @dev 获取申请信息
     * @param msghash 消息哈希
     * @param index 申请索引
     * @return address 申请者地址
     * @return address[] 签名者地址数组
     */
    function getApplicationInfo(bytes32 msghash,uint256 index) validIndex(msghash,index) public view returns (address,address[] memory){
        signatureInfo memory info=signatureMap[msghash][index];
        return (info.applicant,info.signatures);
    }

    /**
     * @dev 获取某个消息哈希的申请数量
     * @param msghash 消息哈希
     * @return uint256 申请数量
     */
    function getApplicationCount(bytes32 msghash) public view returns (uint256){
        return signatureMap[msghash].length;
    }


    // === 修饰符 ===
    /**
     * @dev 只有签名者可以调用的修饰符
     * @notice 检查调用者是否在签名者白名单中
     */
    modifier onlyOwner{
        require(signatureOwners.isEligibleAddress(msg.sender),"Multiple Signature : caller is not in the ownerList!");
        _;
    }
    /**
     * @dev 验证申请索引是否有效的修饰符
     * @param msghash 消息哈希
     * @param index 申请索引
     * @notice 确保索引不会越界
     */
    modifier validIndex(bytes32 msghash,uint256 index){
        require(index<signatureMap[msghash].length,"Multiple Signature : Message index is overflow!");
        _;
    }
}