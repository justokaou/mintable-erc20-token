// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

interface IMyToken {
    function mint(address to, uint256 amount) external;

    function totalSupply() external view returns (uint256);
}

contract TokenMinter is AccessControl, ReentrancyGuard, Pausable {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    IMyToken public token;

    uint256 public constant MAX_SUPPLY = 1000000 * 10 ** 18;
    uint256 public constant ETHER_TO_MYTOKEN_RATE = 1000000;

    constructor(address tokenAddress) {
        require(tokenAddress != address(0), "Token address cannot be zero");
        token = IMyToken(tokenAddress);

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
    }

    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }

    function mintToken(address to) external payable nonReentrant whenNotPaused {
        uint256 tokenAmount = msg.value * ETHER_TO_MYTOKEN_RATE;
        _mintToken(to, tokenAmount);
    }

    function _mintToken(address to, uint256 amount) private {
        require(
            token.totalSupply() + amount <= MAX_SUPPLY,
            "Minting would exceed max supply"
        );
        token.mint(to, amount);
    }

    function withdraw() external onlyRole(ADMIN_ROLE) nonReentrant {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");
        (bool sent, ) = msg.sender.call{value: balance}("");
        require(sent, "Failed to send Ether");
    }
}
