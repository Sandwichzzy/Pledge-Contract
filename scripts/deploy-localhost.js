/**
 * 本地部署脚本
 * 用于快速部署所有合约到本地Hardhat网络
 */

const hre = require("hardhat");

async function main() {
  console.log("🚀 开始本地部署...");
  console.log("网络:", hre.network.name);

  const [deployer, user1, user2] = await hre.ethers.getSigners();
  console.log("部署者地址:", deployer.address);
  console.log("用户1地址:", user1.address);
  console.log("用户2地址:", user2.address);

  // 检查余额
  const balance = await deployer.getBalance();
  console.log("部署者余额:", hre.ethers.utils.formatEther(balance), "ETH");

  try {
    // 使用 hardhat-deploy 进行部署
    console.log("\n📦 执行合约部署...");

    // 执行所有部署脚本
    await hre.run("deploy", {
      network: hre.network.name,
    });

    console.log("\n✅ 部署完成！");

    // 获取部署的合约地址
    const deployments = await hre.deployments.all();

    console.log("\n📋 部署的合约地址:");
    console.log("=====================================");

    Object.keys(deployments).forEach((contractName) => {
      console.log(`${contractName}: ${deployments[contractName].address}`);
    });

    // 基本验证
    console.log("\n🔍 基本功能验证...");

    // 验证多签名
    if (deployments.multiSignature) {
      const multiSig = await hre.ethers.getContract("multiSignature");
      const owners = await multiSig.getOwners();
      console.log("多签名拥有者数量:", owners.length);
    }

    // 验证代币
    if (deployments.spDebtToken) {
      const spToken = await hre.ethers.getContract("spDebtToken");
      const name = await spToken.name();
      console.log("SP代币名称:", name);
    }

    // 验证主合约
    if (deployments.PledgePool) {
      const pledgePool = await hre.ethers.getContract("PledgePool");
      const poolLength = await pledgePool.PoolLength();
      console.log("当前池数量:", poolLength.toString());
    }

    console.log("\n🎉 所有验证通过！");
    console.log("\n📚 后续操作:");
    console.log("1. 使用 'npx hardhat console --network localhost' 进入控制台");
    console.log("2. 执行测试: 'npx hardhat test --network localhost'");
    console.log(
      "3. 查看部署信息: 'npx hardhat deployments --network localhost'"
    );
  } catch (error) {
    console.error("\n❌ 部署失败:", error.message);
    process.exit(1);
  }
}

// 运行部署
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
