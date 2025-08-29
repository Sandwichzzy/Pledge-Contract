//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../multiSignature/multiSignatureClient.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";

/**
 * @title AddressPrivileges - 地址权限管理合约
 * @dev 基于OpenZeppelin的EnumerableSet实现高效的地址权限管理
 * @notice 此合约专门用于管理铸币者(Minter)权限，支持添加、删除、查询和遍历操作
 * 
 * === EnumerableSet核心优势 ===
 * 1. **去重性**: 自动确保地址不会重复添加
 * 2. **高效查询**: O(1)时间复杂度检查地址是否存在
 * 3. **可遍历**: 支持通过索引访问集合中的元素
 * 4. **安全删除**: 删除元素时自动重新排列，避免空隙
 * 5. **Gas优化**: 相比数组+映射的组合，更节省gas
 * 
 * === 与普通数组的对比 ===
 * 普通数组approach:
 * - 需要额外映射检查重复: mapping(address => bool) 
 * - 删除元素复杂，需要移动元素或留空隙
 * - 查询是否存在需要遍历数组 O(n)
 * 
 * EnumerableSet approach:
 * - 内部自动去重，无需额外映射
 * - 删除时自动优化存储结构
 * - 查询时间复杂度 O(1)
 */
contract AddressPrivileges is multiSignatureClient{

    constructor(address multiSignature) multiSignatureClient(multiSignature){
    }

    // 引入EnumerableSet库的AddressSet类型
    using EnumerableSet for EnumerableSet.AddressSet;

    // 私有的铸币者地址集合
    // EnumerableSet.AddressSet内部结构：
    // - Set._inner: bytes32集合存储地址
    // - Set._indexes: 映射地址到索引的关系
    // 这种设计既支持快速查找，又支持索引遍历
    EnumerableSet.AddressSet private _minters;

    /**
     * @notice 添加铸币者地址
     * @dev 使用EnumerableSet.add()确保地址唯一性
     * @param _addMinter 要添加的铸币者地址
     * @return bool 添加成功返回true，地址已存在返回false
     * 
     * === EnumerableSet.add()内部逻辑 ===
     * 1. 检查元素是否已存在
     * 2. 如果不存在，添加到内部数组
     * 3. 更新索引映射
     * 4. 返回操作结果
     */
    function addMinter(address _addMinter) public validCall returns (bool){
        require(_addMinter!=address(0),"Token : _addMinter address is zero!");
        return EnumerableSet.add(_minters,_addMinter);
    }

    /**
     * @notice 删除铸币者地址
     * @dev 使用EnumerableSet.remove()安全删除地址
     * @param _delMinter 要删除的铸币者地址
     * @return bool 删除成功返回true，地址不存在返回false
     * 
     * === EnumerableSet.remove()内部逻辑 ===
     * 1. 检查元素是否存在
     * 2. 如果存在，将最后一个元素移到被删除位置
     * 3. 删除最后一个元素
     * 4. 更新索引映射
     * 5. 返回操作结果
     * 这种"交换删除"方式避免了数组中的空隙，保持存储紧凑
     */
    function delMinter(address _delMinter) public validCall returns (bool){
        require(_delMinter!=address(0),"Token : _delMinter address is zero!");
        return EnumerableSet.remove(_minters,_delMinter);
    }

    /**
     * @notice 获取铸币者列表长度
     * @dev 直接返回EnumerableSet的长度
     * @return uint256 铸币者总数
     */
    function getMinterLength() public view returns (uint256) {
        return EnumerableSet.length(_minters);
    }

    /**
     * @notice 检查地址是否为铸币者
     * @dev 使用EnumerableSet.contains()进行O(1)查询
     * @param account 要检查的地址
     * @return bool 是铸币者返回true，否则返回false
     */
    function isMinter(address account) public view returns (bool){
        return EnumerableSet.contains(_minters,account);
    }

     /**
      * @notice 根据索引获取铸币者地址
      * @dev 使用EnumerableSet.at()通过索引访问元素
      * @param _index 索引位置
      * @return address 对应索引的铸币者地址
      */
    function getMinter(uint256 _index) public view returns (address){
        require(_index<getMinterLength()-1,"Token : index out of bounds");
        return EnumerableSet.at(_minters,_index)
    }

    /**
     * @dev 只有铸币者可以调用的修饰符
     * @notice 使用isMinter()进行权限验证，利用EnumerableSet的高效查询
     */
    modifier onlyMinter(){
        require(isMinter(msg.sender),"Token: caller is not a minter!");
        _;
    }

}
