//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../multiSignature/MultiSignatureClient.sol";
import "@chainlink/contracts/src/v0.6/interfaces/AggregatorV3Interface.sol";

/**
 * @title BscPledgeOracle - BSC质押协议价格预言机
 * @dev 混合价格预言机系统，支持Chainlink聚合器和手动价格设置
 * @notice 为Pledge系统提供可靠的价格数据，支持多种资产的价格查询
 * 
 * === 核心设计特性 ===
 * 1. **双重价格源**：Chainlink聚合器（优先） + 手动设置价格（备用）
 * 2. **精度统一**：所有价格统一转换为18位小数精度
 * 3. **多签名控制**：价格设置和聚合器配置需要多签名验证
 * 4. **灵活配置**：支持动态添加/修改资产的价格源
 * 
 * === 价格查询优先级 ===
 * 1. 如果配置了Chainlink聚合器 → 使用链上实时价格
 * 2. 如果没有聚合器 → 使用手动设置的价格
 * 3. 如果都没有 → 返回0（表示价格不可用）
 * 
 * === 精度处理逻辑 ===
 * - Chainlink价格通常是8位小数（如BTC/USD $50000.12345678）
 * - 本系统统一使用18位小数（以太坊标准）
 * - 自动进行精度转换以确保计算准确性
 */
contract BscPledgeOracle is MultiSignatureClient {

    /**
     * @dev 资产到Chainlink聚合器的映射
     * key: 资产标识符（地址转uint256或自定义ID）
     * value: Chainlink聚合器接口
     */
    mapping(uint256 => AggregatorV3Interface) internal assetsMap;

    /**
     * @dev 资产精度映射
     * key: 资产标识符
     * value: 该资产的小数位数（如USDC=6, WETH=18）
     */
    mapping(uint256 => uint256) internal decimalsMap;

    /**
     * @dev 手动设置的价格映射（备用价格源）
     * key: 资产标识符
     * value: 手动设置的价格（18位小数精度）
     */
    mapping(uint256 => uint256) internal pricesMap;

    /**
     * @dev 全局精度除数，用于Chainlink价格调整
     * 默认为1，可通过setDecimals调整
     */
    uint256 internal decimals = 1;

    constructor(address _multiSignature) MultiSignatureClient(_multiSignature) {
         // === BSC测试网聚合器地址示例 ===
        // 这些地址在实际部署时可以启用，配置常用资产的Chainlink聚合器
        
        // BNB/USD聚合器
        // assetsMap[uint256(0x0000000000000000000000000000000000000000)] = AggregatorV3Interface(0x2514895c72f50D8bd4B4F9b1110F0D6bD2c97526);
        
        // DAI/USD聚合器  
        // assetsMap[uint256(0xf2bDB4ba16b7862A1bf0BE03CD5eE25147d7F096)] = AggregatorV3Interface(0xE4eE17114774713d2De0eC0f035d4F7665fc025D);
        
        // BTC/USD聚合器
        // assetsMap[uint256(0xF592aa48875a5FDE73Ba64B527477849C73787ad)] = AggregatorV3Interface(0x5741306c21795FdCBb9b265Ea0255F499DFe515C);
        
        // BUSD/USD聚合器
        // assetsMap[uint256(0xDc6dF65b2fA0322394a8af628Ad25Be7D7F413c2)] = AggregatorV3Interface(0x9331b55D9830EF609A2aBCfAc0FBCE050A52fdEa);

        // === 对应的资产精度配置 ===
        // decimalsMap[uint256(0x0000000000000000000000000000000000000000)] = 18; // BNB
        // decimalsMap[uint256(0xf2bDB4ba16b7862A1bf0BE03CD5eE25147d7F096)] = 18; // DAI
        // decimalsMap[uint256(0xF592aa48875a5FDE73Ba64B527477849C73787ad)] = 18; // BTC
        // decimalsMap[uint256(0xDc6dF65b2fA0322394a8af628Ad25Be7D7F413c2)] = 18; // BUSD
    }

    /**
     * @notice 设置全局精度参数
     * @dev 用于调整Chainlink价格的精度转换
     * @param newDecimals 新的精度除数
     * 
     * === 使用场景 ===
     * - Chainlink聚合器返回8位小数，设置为1e8进行标准化
     * - 特殊情况下需要全局调整价格精度
     */
    function setDecimals(uint256 newDecimals) public validCall{
        decimals=newDecimals;
    }
    /**
     * @notice 批量设置资产价格
     * @dev 手动设置多个资产的价格（备用价格源）
     * @param assets 资产ID数组
     * @param prices 对应的价格数组（18位小数精度）
     */
    function setPrices(uint256[] memory assets, uint256[] memory prices) external validCall{
        require(assets.length==prices.length,"input arrays length are not equal");
        uint256 len=assets.length;
        for (uint256 i=0;i<len;i++){
            pricesMap[assets[i]]=prices[i];
        }
    }

    // === 价格获取流程 ===
    /**
     * @notice 批量获取资产价格
     * @dev 返回多个资产的当前价格
     * @param assets 资产ID数组
     * @return uint256[] 对应的价格数组（18位小数精度）
     */
    function getPrices(uint256[] memory assets) external view returns (uint256[] memory){
        uint256 len=assets.length;
        uint256[] memory prices=new uint256[](len);
        for (uint256 i=0;i<len;i++){
            prices[i]=getUnderlyingPrice(assets[i]);
        }
        return prices;
    }
    /**
     * @notice 获取单个资产价格（通过地址）
     * @dev 将资产地址转换为uint256后获取价格
     * @param asset 资产合约地址
     * @return uint256 资产价格（18位小数精度）
     */
    function getPrice(address asset) public view returns (uint256){
        return getUnderlyingPrice(uint256(asset));
    }

    /**
     * @notice 获取单个资产价格（核心函数）
     * @dev 实现双重价格源的价格获取逻辑
     * @param underlying 资产标识符（地址转uint256或自定义ID）
     * @return uint256 资产价格（18位小数精度）
     */
    function getUnderlyingPrice(uint256 underlying) public view returns (uint256){
        //获取配置的chainlink聚合器
        AggregatorV3Interface assetsPrice=assetsMap[underlying];
        //优先使用chainlink聚合器价格
        if (address(assetsPrice)!=address(0)){
            // 调用Chainlink聚合器获取最新价格数据
            (,int256 price,,,) = assetsPrice.latestRoundData();
            // 根据资产精度进行转换
            uint256 tokenDecimals=decimalsMap[underlying];
            if (tokenDecimals<18){
                // 例如：USDC(6位) → 18位
                // price: $1.000000 (8位小数) → 需要补足到18位
                return uint256(price)/decimals*(10**(18-tokenDecimals));
            }else if (tokenDecimals>18){
                // 理论情况：如果代币精度超过18位 → 需要降低精度
                return uint256(price)/decimals/(10**(tokenDecimals-18));
            }else{
                // 如果精度正好是18位 → 直接除以精度
                return uint256(price)/decimals;
            }
        }else{
            // 如果没有聚合器 → 返回手动设置的价格
            return pricesMap[underlying];
        }
    }

        /**
     * @notice 设置单个资产的手动价格（通过地址）
     * @dev 为资产设置备用价格
     * @param asset 资产合约地址
     * @param price 价格值（18位小数精度）
     */
    function setPrice(address asset,uint256 price) public validCall {
        pricesMap[uint256(asset)] = price;
    }

    /**
     * @notice 设置单个资产的手动价格（通过ID）
     * @dev 为资产设置备用价格
     * @param underlying 资产标识符
     * @param price 价格值（18位小数精度）
     */
    function setUnderlyingPrice(uint256 underlying,uint256 price) public validCall {
        require(underlying>0 , "underlying cannot be zero");
        pricesMap[underlying] = price;
    }

    /**
     * @notice 设置资产的Chainlink聚合器（通过地址）
     * @dev 为资产配置Chainlink价格源
     * @param asset 资产合约地址
     * @param aggergator Chainlink聚合器地址
     * @param _decimals 资产的小数位数
     */
    function setAssetAggregator(address asset,address aggregator,uint256 _decimals) public validCall{
        assetsMap[uint256(asset)]=AggregatorV3Interface(aggregator);
        decimalsMap[uint256(asset)]=_decimals;
    }

        /**
     * @notice 设置资产的Chainlink聚合器（通过ID）
     * @dev 为资产配置Chainlink价格源
     * @param underlying 资产标识符
     * @param aggergator Chainlink聚合器地址
     * @param _decimals 资产的小数位数
     */
    function setUnderlyingAggregator(uint256 underlying,address aggergator,uint256 _decimals) public validCall {
        require(underlying>0 , "underlying cannot be zero");
        assetsMap[underlying] = AggregatorV3Interface(aggergator);
        decimalsMap[underlying] = _decimals;
    }
    /**
     * @notice 获取资产的聚合器信息（通过地址）
     * @dev 查询资产配置的Chainlink聚合器和精度
     * @param asset 资产合约地址
     * @return address 聚合器地址
     * @return uint256 资产精度
     */
    function getAssetsAggregator(address asset) public view returns (address,uint256) {
        return (address(assetsMap[uint256(asset)]),decimalsMap[uint256(asset)]);
    }

     /**
       * @notice 获取资产的聚合器信息（通过ID）
       * @dev 查询资产配置的Chainlink聚合器和精度
       * @param underlying 资产标识符
       * @return address 聚合器地址
       * @return uint256 资产精度
       */
    function getUnderlyingAggregator(uint256 underlying) public view returns (address,uint256) {
        return (address(assetsMap[underlying]),decimalsMap[underlying]);
    }
}