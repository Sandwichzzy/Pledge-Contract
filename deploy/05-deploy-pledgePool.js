module.exports = async ({ getNamedAccounts, deployments, network }) => {
  const { deployer } = await getNamedAccounts();
  const { deploy } = deployments;

  console.log("Deploying PledgePool with deployer:", deployer);

  // 获取必要的合约地址
  const multiSignatureDeployment = await deployments.get("multiSignature");
  const multiSignatureAddress = multiSignatureDeployment.address;

  // 选择本地或测试网的预言机
  let oracleDeployment;
  const isLocal = network.name === "hardhat" || network.name === "localhost";
  if (isLocal) {
    oracleDeployment = await deployments.get("MockOracle");
  } else {
    oracleDeployment = await deployments.get("BscPledgeOracle");
  }
  const oracleAddress = oracleDeployment.address;

  console.log("Using multiSignature address:", multiSignatureAddress);
  console.log("Using oracle address:", oracleAddress);

  // 根据网络选择不同的SwapRouter地址
  let swapRouterAddress;
  let feeAddress;

  if (network.name === "hardhat" || network.name === "localhost") {
    // 本地网络使用Mock合约
    try {
      const uniswapRouterDeployment = await deployments.get(
        "UniswapV2Router02"
      );
      swapRouterAddress = uniswapRouterDeployment.address;
      console.log("Using UniswapV2Router02:", swapRouterAddress);
    } catch (error) {
      console.error(
        "UniswapV2Router02 not found, please deploy mock contracts first"
      );
      throw error;
    }
    feeAddress = deployer; // 本地测试使用部署者地址作为手续费地址
  } else if (network.name === "sepolia") {
    // Sepolia测试网使用Uniswap V2官方路由器地址
    swapRouterAddress = "0xeE567Fe1712Faf6149d80dA1E6934E354124CfE3"; // Uniswap V2 Router on Sepolia (更新地址)
    feeAddress = deployer; // 可以设置为特定的手续费收取地址
  } else if (network.name === "bscTestnet") {
    // BSC测试网使用PancakeSwap路由器地址
    swapRouterAddress = "0xD99D1c33F9fC3444f8101754aBC46c52416550D1"; // PancakeSwap Router on BSC Testnet
    feeAddress = deployer; // 可以设置为特定的手续费收取地址
  } else {
    throw new Error(`Unsupported network: ${network.name}`);
  }

  console.log("Using swapRouter:", swapRouterAddress);
  console.log("Using feeAddress:", feeAddress);

  // 部署 PledgePool 主合约
  const pledgePool = await deploy("PledgePool", {
    from: deployer,
    args: [
      oracleAddress, // oracle地址
      swapRouterAddress, // swapRouter地址
      feeAddress, // 手续费地址
      multiSignatureAddress, // 多签名地址
    ],
    log: true,
  });

  console.log("PledgePool deployed to", pledgePool.address);

  // 验证合约（如果在Sepolia网络上）
  if (network.config.chainId === 11155111 && process.env.ETHERSCAN_API_KEY) {
    console.log("Verifying PledgePool");
    try {
      await run("verify:verify", {
        address: pledgePool.address,
        constructorArguments: [
          oracleAddress,
          swapRouterAddress,
          feeAddress,
          multiSignatureAddress,
        ],
      });
      console.log("PledgePool verified");
    } catch (error) {
      console.error("Error verifying PledgePool", error.message);
    }
  } else {
    console.log("Network is not sepolia, skipping verification");
  }

  return {
    pledgePool: pledgePool.address,
    oracle: oracleAddress,
    swapRouter: swapRouterAddress,
    feeAddress: feeAddress,
    multiSignature: multiSignatureAddress,
  };
};

module.exports.dependencies = ["multiSignature"];
module.exports.tags = ["PledgePool", "all"];
