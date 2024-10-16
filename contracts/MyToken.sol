// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title MyToken
 * @dev ERC20 token with burnable and mintable features, controlled via AccessControl.
 * The contract includes a role-based permission system, allowing certain addresses to mint tokens.
 * Inherits from OpenZeppelin's ERC20, ERC20Burnable, and AccessControl contracts.
 */
contract MyToken is ERC20, ERC20Burnable, AccessControl {
    // Define the MINTER_ROLE constant for permissioned minting operations
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    /**
     * @dev Constructor that initializes the token with a name and symbol,
     * and assigns the deployer the default admin role, which can manage other roles.
     * The DEFAULT_ADMIN_ROLE is automatically granted to the deployer of the contract.
     */
    constructor() ERC20("MyToken", "MTK") {
        // Grant the deployer the admin role, allowing them to manage other roles
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /**
     * @dev Mints new tokens to a specified address. 
     * Can only be called by accounts with the MINTER_ROLE.
     * 
     * @param to The address that will receive the minted tokens.
     * @param amount The amount of tokens to be minted.
     *
     * Requirements:
     * - Caller must have the `MINTER_ROLE`.
     * - `to` cannot be the zero address.
     *
     * @notice This function uses role-based access control, ensuring that only authorized accounts can mint tokens.
     * @custom:security Use caution when assigning the MINTER_ROLE, as improper minting could inflate the supply.
     */
    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }
}
