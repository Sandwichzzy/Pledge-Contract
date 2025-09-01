module.exports = async ({ getNamedAccounts, deployments, network }) => {
  const { deployer } = await getNamedAccounts();
  const { deploy } = deployments;

  const isLocal = network.name === "hardhat" || network.name === "localhost";

  if (isLocal) {
    console.log("Deploying MockOracle with deployer:", deployer);

    // 本地：部署 MockOracle（无需多签）
    const mockOracle = await deploy("MockOracle", {
      from: deployer,
      args: [],
      log: true,
    });

    return mockOracle;
  }

  console.log("Deploying BscPledgeOracle with deployer:", deployer);

  const multiSignatureDeployment = await deployments.get("multiSignature");
  const multiSignatureAddress = multiSignatureDeployment.address;

  // 测试/公链：部署 BscPledgeOracle
  const bscPledgeOracle = await deploy("BscPledgeOracle", {
    from: deployer,
    args: [multiSignatureAddress],
    log: true,
  });

  if (network.config.chainId === 11155111 && process.env.ETHERSCAN_API_KEY) {
    console.log("Verifying BscPledgeOracle");
    try {
      await run("verify:verify", {
        address: bscPledgeOracle.address,
        constructorArguments: [multiSignatureAddress],
      });
      console.log("BscPledgeOracle verified");
    } catch (error) {
      console.error("Error verifying BscPledgeOracle", error.message);
    }
  } else {
    console.log("Network is not sepolia, skipping verification");
  }

  return bscPledgeOracle;
};

module.exports.dependencies = ["multiSignature"];
module.exports.tags = ["BscPledgeOracle", "MockOracle", "all"];
