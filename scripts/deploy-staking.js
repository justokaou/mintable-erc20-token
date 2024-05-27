require("dotenv").config();

async function main() {
  const [deployer] = await ethers.getSigners();

  console.log("Deploying contracts with the account:", deployer.address);

  const Staking = await ethers.getContractFactory("Staking");
  const contract = await Staking.deploy(
    process.env.STAKING_TOKEN_ADDR,
    process.env.REWARD_TOKEN_ADDR
  );

  const contractAddr = contract.target;
  console.log("Contract deployed to:", contractAddr);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
