// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title TokenMinter
 * @dev A contract for minting ERC20 tokens in exchange for Ether. 
 * Implements access control, reentrancy protection, and pausability.
 * Uses an external ERC20 contract (IMyToken) for minting tokens.
 */
interface IMyToken {
    function mint(address to, uint256 amount) external;

    function totalSupply() external view returns (uint256);
}

contract TokenMinter is AccessControl, ReentrancyGuard, Pausable {
    // Define the role for admin-related actions
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    // Reference to the external ERC20 token contract
    IMyToken public token;

    // Maximum token supply that can be minted
    uint256 public constant MAX_SUPPLY = 1000000 * 10 ** 18;

    // Conversion rate: 1 Ether = 1,000,000 tokens
    uint256 public constant ETHER_TO_MYTOKEN_RATE = 1000000;

    /**
     * @dev Initializes the contract by setting the token address and assigning the deployer the admin roles.
     * @param tokenAddress The address of the ERC20 token contract to interact with.
     * 
     * Requirements:
     * - `tokenAddress` cannot be the zero address.
     */
    constructor(address tokenAddress) {
        require(tokenAddress != address(0), "Token address cannot be zero");
        token = IMyToken(tokenAddress);

        // Grant admin roles to the deployer of the contract
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
    }

    /**
     * @dev Pauses the contract, disabling minting.
     * Only callable by accounts with the `ADMIN_ROLE`.
     */
    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }

    /**
     * @dev Unpauses the contract, allowing minting to resume.
     * Only callable by accounts with the `ADMIN_ROLE`.
     */
    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }

    /**
     * @dev Mints tokens in exchange for Ether. The number of tokens minted is proportional to the amount of Ether sent.
     * Callable when the contract is not paused.
     * 
     * @param to The address that will receive the minted tokens.
     *
     * Requirements:
     * - The contract must not be paused.
     * - `msg.value` (amount of Ether sent) must be greater than 0.
     */
    function mintToken(address to) external payable nonReentrant whenNotPaused {
        require(msg.value > 0, "Ether amount must be greater than zero");
        uint256 tokenAmount = msg.value * ETHER_TO_MYTOKEN_RATE;
        _mintToken(to, tokenAmount);
    }

    /**
     * @dev Internal function that mints tokens to the specified address, ensuring that the total supply does not exceed the maximum limit.
     * 
     * @param to The address that will receive the minted tokens.
     * @param amount The amount of tokens to mint.
     *
     * Requirements:
     * - The total token supply after minting must not exceed `MAX_SUPPLY`.
     */
    function _mintToken(address to, uint256 amount) private {
        require(
            token.totalSupply() + amount <= MAX_SUPPLY,
            "Minting would exceed max supply"
        );
        token.mint(to, amount);
    }

    /**
     * @dev Withdraws the accumulated Ether from the contract to the admin's address.
     * Only callable by accounts with the `ADMIN_ROLE`.
     *
     * Requirements:
     * - The contract must have a positive Ether balance.
     */
    function withdraw() external onlyRole(ADMIN_ROLE) nonReentrant {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");

        // Transfer the balance to the admin's address
        (bool sent, ) = msg.sender.call{value: balance}("");
        require(sent, "Failed to send Ether");
    }
}
