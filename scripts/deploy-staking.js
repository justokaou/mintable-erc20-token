async function main() {
    const [deployer] = await ethers.getSigners();

    console.log("Deploying contracts with the account:", deployer.address);

    const Staking = await ethers.getContractFactory("Staking");
    const contract = await Staking.deploy(
        "0x9C6C848d0c610c4b4087b2c93Ad19b58f1De649a"
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