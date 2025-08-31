module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deployer } = await getNamedAccounts();

  // 获取 StakeToken 合约
  const stakeTokenDeployment = await deployments.get("StakeTokenERC20");
  const stakeToken = await ethers.getContractAt(
    "StakeTokenERC20",
    stakeTokenDeployment.address
  );
};
