const owners = [
  "0x523df39cae18ea125930da730628213e4b147cdc",
  "0xcafd18c0c33676a17fb3bf63bd46f8ffcbff9039",
  "0x6002bad747afd5690f543a670f3e3bd30e033084",
];

const limitedSignNum = 2;

module.exports = async ({ getNamedAccounts, deployments, network }) => {
  const { deployer } = await getNamedAccounts();
  const { deploy } = deployments;

  const multiSignature = await deploy("multiSignature", {
    from: deployer,
    args: [owners, limitedSignNum],
    log: true,
  });

  if (network.config.chainId === 11155111 && process.env.ETHERSCAN_API_KEY) {
    console.log("Verifying multiSignature");
    try {
      await run("verify:verify", {
        address: multiSignature.address,
        constructorArguments: [owners, limitedSignNum],
      });
      console.log("multiSignature verified");
    } catch (error) {
      console.error("Error verifying multiSignature", error.message);
    }
  } else {
    console.log("Network is not sepolia, skipping verification");
  }

  return {
    multiSignature: multiSignature.address,
  };
};

module.exports.tags = ["multiSignature", "all"];
