module.exports = async ({ getNamedAccounts, deployments, network }) => {
  const { deployer } = await getNamedAccounts();
  const { deploy } = deployments;

  console.log("Deploying Mock Contracts with deployer:", deployer);

  // 只在本地网络部署模拟合约
  if (network.name === "hardhat" || network.name === "localhost") {
    console.log("Deploying mock contracts for local development...");

    // 部署 Mock WETH
    const mockWETH = await deploy("MockWETH", {
      from: deployer,
      args: [],
      log: true,
    });
    console.log("MockWETH deployed to", mockWETH.address);

    // 部署 UniswapV2Factory
    const uniswapFactory = await deploy("UniswapV2Factory", {
      from: deployer,
      args: [deployer], // feeToSetter 设置为部署者
      log: true,
    });
    console.log("UniswapV2Factory deployed to", uniswapFactory.address);

    // 部署 UniswapV2Router02
    const uniswapRouter = await deploy("UniswapV2Router02", {
      from: deployer,
      args: [uniswapFactory.address, mockWETH.address],
      log: true,
    });
    console.log("UniswapV2Router02 deployed to", uniswapRouter.address);

    // 部署测试用的ERC20代币

    // Mock USDT (6位小数)
    const mockUSDT = await deploy("MockUSDT", {
      from: deployer,
      args: ["Mock Tether USD", "USDT", 6, "1000000000000"], // 1,000,000 USDT
      log: true,
      contract: "MockERC20",
    });
    console.log("MockUSDT deployed to", mockUSDT.address);

    // Mock BTC (8位小数)
    const mockBTC = await deploy("MockBTC", {
      from: deployer,
      args: ["Mock Bitcoin", "BTC", 8, "2100000000000000"], // 21,000,000 BTC
      log: true,
      contract: "MockERC20",
    });
    console.log("MockBTC deployed to", mockBTC.address);

    // Mock USDC (6位小数)
    const mockUSDC = await deploy("MockUSDC", {
      from: deployer,
      args: ["Mock USD Coin", "USDC", 6, "1000000000000"], // 1,000,000 USDC
      log: true,
      contract: "MockERC20",
    });
    console.log("MockUSDC deployed to", mockUSDC.address);

    return {
      mockWETH: mockWETH.address,
      uniswapFactory: uniswapFactory.address,
      uniswapRouter: uniswapRouter.address,
      mockUSDT: mockUSDT.address,
      mockBTC: mockBTC.address,
      mockUSDC: mockUSDC.address,
    };
  } else {
    console.log("Not a local network, skipping mock contract deployment");
    return {};
  }
};

module.exports.tags = ["mockSwapRouter", "all"];
module.exports.skip = async ({ network }) => {
  // 只在本地网络运行
  return network.name !== "hardhat" && network.name !== "localhost";
};
