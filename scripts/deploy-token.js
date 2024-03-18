async function main() {
  const [deployer] = await ethers.getSigners();

  console.log("Deploying contracts with the account:", deployer.address);

  const Token = await ethers.getContractFactory("MyToken");
  const tokenContract = await Token.deploy();

  const tokenAddr = tokenContract.target;
  console.log("MyToken deployed to:", tokenAddr);

  const Minter = await ethers.getContractFactory("TokenMinter");
  const myContractMinter = await Minter.deploy(tokenAddr);

  const minterAddr = myContractMinter.target;
  console.log("Minter deployed to:", minterAddr);

  const grantRoleTx = await tokenContract.grantRole(
    tokenContract.MINTER_ROLE(),
    minterAddr
  );
  const roleTx = await grantRoleTx.wait();
  console.log("Minter role granted to the Minter contract : ", roleTx.hash);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
