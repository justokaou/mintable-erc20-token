// Load environment variables from a `.env` file, such as STAKING_TOKEN_ADDR and REWARD_TOKEN_ADDR
require("dotenv").config();

async function main() {
  // Get the first signer (deployer) account from the available signers
  const [deployer] = await ethers.getSigners();

  // Log the address of the deployer for traceability during the deployment process
  console.log("Deploying contracts with the account:", deployer.address);

  // Get the contract factory for the `Staking` contract
  const Staking = await ethers.getContractFactory("Staking");

  // Deploy the `Staking` contract, passing the staking and reward token addresses from environment variables
  const contract = await Staking.deploy(
    process.env.STAKING_TOKEN_ADDR,  // Address of the token to be staked
    process.env.REWARD_TOKEN_ADDR    // Address of the token used for rewards
  );

  // Retrieve the deployed contract address and log it for future reference
  const contractAddr = contract.target; // Could also be `contract.address` depending on the version of ethers.js
  console.log("Contract deployed to:", contractAddr);
}

// Execute the `main` function and handle any errors
main()
  .then(() => process.exit(0))  // Exit the process successfully when everything completes
  .catch((error) => {           // Catch and log any errors that occur during the execution of the script
    console.error(error);
    process.exit(1);            // Exit the process with a failure code (1) in case of an error
  });