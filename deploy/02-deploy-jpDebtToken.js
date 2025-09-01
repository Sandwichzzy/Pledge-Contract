let jpTokenName = "jpBTC_1";
let jpTokenSymbol = "jpBTC_1";

module.exports = async ({ getNamedAccounts, deployments, network }) => {
  const { deployer } = await getNamedAccounts();
  const { deploy } = deployments;

  console.log("Deploying JP DebtToken with deployer:", deployer);

  const multiSignatureDeployment = await deployments.get("multiSignature");
  const multiSignatureAddress = multiSignatureDeployment.address;

  console.log("Using multiSignature address:", multiSignatureAddress);

  // 部署 JP DebtToken 合约 (抵押凭证)
  const jpDebtToken = await deploy("jpDebtToken", {
    from: deployer,
    args: [jpTokenName, jpTokenSymbol, multiSignatureAddress],
    log: true,
    contract: "DebtToken",
  });

  console.log("JP DebtToken deployed to", jpDebtToken.address);

  // 验证合约（如果在Sepolia网络上）
  if (network.config.chainId === 11155111 && process.env.ETHERSCAN_API_KEY) {
    console.log("Verifying JP DebtToken");
    try {
      await run("verify:verify", {
        address: jpDebtToken.address,
        constructorArguments: [
          jpTokenName,
          jpTokenSymbol,
          multiSignatureAddress,
        ],
      });
      console.log("JP DebtToken verified");
    } catch (error) {
      console.error("Error verifying JP DebtToken", error.message);
    }
  } else {
    console.log("Network is not sepolia, skipping verification");
  }

  return jpDebtToken;
};

module.exports.dependencies = ["multiSignature"];
module.exports.tags = ["jpDebtToken", "all"];
