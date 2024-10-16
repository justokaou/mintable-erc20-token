async function main() {
  // Get the first account (signer) available to deploy the contracts
  const [deployer] = await ethers.getSigners();

  // Log the address of the deployer for traceability
  console.log("Deploying contracts with the account:", deployer.address);

  // Create a factory for the `MyToken` contract (ERC20 token)
  const Token = await ethers.getContractFactory("MyToken");

  // Deploy the `MyToken` contract and wait for the deployment to complete
  const tokenContract = await Token.deploy();

  // Retrieve the deployed contract address and log it
  const tokenAddr = tokenContract.target; // In some versions, this could be `tokenContract.address`
  console.log("MyToken deployed to:", tokenAddr);

  // Create a factory for the `TokenMinter` contract
  const Minter = await ethers.getContractFactory("TokenMinter");

  // Deploy the `TokenMinter` contract and pass the `MyToken` contract address as a parameter
  const myContractMinter = await Minter.deploy(tokenAddr);

  // Retrieve the deployed `TokenMinter` contract address and log it
  const minterAddr = myContractMinter.target; // Similarly, this could be `myContractMinter.address`
  console.log("Minter deployed to:", minterAddr);

  // Grant the `MINTER_ROLE` to the `TokenMinter` contract so it can mint tokens
  const grantRoleTx = await tokenContract.grantRole(
    tokenContract.MINTER_ROLE(), // Get the `MINTER_ROLE` identifier from the `MyToken` contract
    minterAddr                   // Specify the `TokenMinter` contract address that will receive the role
  );

  // Wait for the transaction to be mined and retrieve the transaction receipt
  const roleTx = await grantRoleTx.wait();

  // Log the transaction hash confirming the role was successfully granted
  console.log("Minter role granted to the Minter contract : ", roleTx.hash);
}

// Main function execution with promise handling and error capturing
main()
  .then(() => process.exit(0))  // Exit the process successfully when everything completes
  .catch((error) => {           // Catch and log any errors that occur during execution
    console.error(error);
    process.exit(1);            // Exit the process with a failure code (1) in case of an error
  });
