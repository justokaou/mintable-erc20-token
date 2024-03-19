// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

interface IMyToken {
    function mint(address to, uint256 amount) external;

    function totalSupply() external view returns (uint256);
}

contract TokenMinter is AccessControl, ReentrancyGuard {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    IMyToken public token;

    uint256 public constant MAX_SUPPLY = 1000000 * 10 ** 18;
    uint256 public constant MATIC_TO_MYTOKEN_RATE = 1000000;

    constructor(address tokenAddress) {
        require(tokenAddress != address(0), "Token address cannot be zero");
        token = IMyToken(tokenAddress);

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
    }

    function mintMyToken(address to) public payable nonReentrant {
        uint256 maticAmount = msg.value;
        uint256 tokenAmount = maticAmount * MATIC_TO_MYTOKEN_RATE;
        require(
            token.totalSupply() + tokenAmount <= MAX_SUPPLY,
            "Minting would exceed max supply"
        );
        token.mint(to, tokenAmount);
    }

    function withdraw() public onlyRole(ADMIN_ROLE) nonReentrant {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");
        (bool sent, ) = msg.sender.call{value: balance}("");
        require(sent, "Failed to send Ether");
    }
}
