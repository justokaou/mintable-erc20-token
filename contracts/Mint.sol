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
    uint256 public constant RATE_SMALL = 1000000 * 10 ** 18;
    uint256 public constant RATE_LARGE = 1000 * 10 ** 18;

    constructor(address tokenAddress) {
        require(tokenAddress != address(0), "Token address cannot be zero");
        token = IMyToken(tokenAddress);

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
    }

    function mintSmall(address to) public payable nonReentrant {
        require(
            msg.value == 0.000001 ether,
            "Incorrect payment amount for small mint."
        );
        uint256 amount = RATE_SMALL;
        require(
            token.totalSupply() + amount <= MAX_SUPPLY,
            "Minting would exceed max supply"
        );
        token.mint(to, amount);
    }

    function mintLarge(address to) public payable nonReentrant {
        require(
            msg.value == 1 ether,
            "Incorrect payment amount for large mint."
        );
        uint256 amount = RATE_LARGE;
        require(
            token.totalSupply() + amount <= MAX_SUPPLY,
            "Minting would exceed max supply"
        );
        token.mint(to, amount);
    }

    function withdraw() public onlyRole(ADMIN_ROLE) nonReentrant {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");
        (bool sent, ) = msg.sender.call{value: balance}("");
        require(sent, "Failed to send Ether");
    }
}
