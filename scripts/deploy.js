const hre = require("hardhat");

async function main() {
  const ChainOptions = await hre.ethers.getContractFactory("ChainOptions");
  const chainOptions = await ChainOptions.deploy();

  await chainOptions.deployed();
  console.log("ChainOptions contract deployed to:", chainOptions.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("Error deploying contract:", error);
    process.exit(1);
  });
