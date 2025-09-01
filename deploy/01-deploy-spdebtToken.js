let spTokenName = "spBTC_1";
let spTokenSymbol = "spBTC_1";

module.exports = async ({ getNamedAccounts, deployments, network }) => {
  const { deployer } = await getNamedAccounts();
  const { deploy } = deployments;

  console.log("Deploying SP DebtToken with deployer:", deployer);

  const multiSignatureDeployment = await deployments.get("multiSignature");
  const multiSignatureAddress = multiSignatureDeployment.address;

  // 部署 SP DebtToken 合约 (供应方凭证)
  const spDebtToken = await deploy("spDebtToken", {
    from: deployer,
    args: [spTokenName, spTokenSymbol, multiSignatureAddress],
    log: true,
    contract: "DebtToken",
  });

  // 验证合约（如果在Sepolia网络上）
  if (network.config.chainId === 11155111 && process.env.ETHERSCAN_API_KEY) {
    console.log("Verifying SP DebtToken");
    try {
      await run("verify:verify", {
        address: spDebtToken.address,
        constructorArguments: [
          spTokenName,
          spTokenSymbol,
          multiSignatureAddress,
        ],
      });
      console.log("SP DebtToken verified");
    } catch (error) {
      console.error("Error verifying SP DebtToken", error.message);
    }
  } else {
    console.log("Network is not sepolia, skipping verification");
  }

  return spDebtToken;
};

module.exports.dependencies = ["multiSignature"];
module.exports.tags = ["spDebtToken", "all"];
