require("dotenv").config();

const owners = [
  0x523df39cae18ea125930da730628213e4b147cdc,
  0xcafd18c0c33676a17fb3bf63bd46f8ffcbff9039,
  0x6002bad747afd5690f543a670f3e3bd30e033084,
];

const limitedSignNum = 2;

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deployer } = await getNamedAccounts();
  const { deploy } = deployments;

  const multiSignature = await deploy("MultiSignature", {
    from: deployer,
    args: [[owners], limitedSignNum],
    log: true,
  });

  console.log("MultiSignature deployed to", multiSignature.address);
};

module.exports.tags = ["MultiSignature", "all"];
