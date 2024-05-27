# Token Creation, Minting, and Staking Contracts

This project contains three Solidity smart contracts. The first contract creates the token, the second allows the token to be minted, and the third is a staking contract that distributes rewards. There are two deployment scripts: the first script deploys the token and mint contracts, while the second script deploys the staking contract.

<div align="center">

[![](https://img.shields.io/badge/Solidity-red)]()
[![](https://img.shields.io/badge/Node.js-green)]()

</div>

## Environment Variables

To run this project, you will need to add the following environment variables to your .env file

`PRIVATE_KEY="YOUR_PRIVATE_KEY"`

`RPC_URL="YOUR_RPC_URL"`

`ETHERSCAN_API_KEY="YOUR_ETHERSCAN_API_KEY"`

`STAKING_TOKEN_ADDR="YOUR_STAKING_TOKEN_ADDRESS"`
`REWARD_TOKEN_ADDR="YOUR_REWARD_TOKEN_ADDRESS"`

## Installation

Install my-project with npm

```bash
  git clone https://github.com/dyfault-eth/mintable-erc20-token.git
  cd mintable-erc20-token
  npm install
```

## Deployment

Before deployment, make sure to update `hardhat.config.js` with the network you want to deploy to. In this example, I use the Polygon Mumbai network.

Additionally, update the token name in `MyToken.sol`.

To deploy this project run

```bash
  npx hardhat compile
  npx hardhat run scripts/deploy-token.js --network <YOUR_NETWORK> # Deploy the token and mint contracts
  npx hardhat run scripts/deploy-staking.js --network <YOUR_NETWORK> # Deploy the staking contract
```

If you want to verify the contracts, make sure to have your Etherscan API token.

```bash
  npx hardhat verify --network <YOUR_NETWORK> <DEPLOYED_CONTRACT_ADDRESS> <CONSTRUCTOR_ARGUMENTS>
```

For example :

```bash
  npx hardhat verify --network mumbai 0xMyStakingContract "TOKEN_ADDR" "REWARD_TOKEN_ADDR"
```

## Authors

- [@dyfault-eth](https://www.github.com/dyfault-eth)
