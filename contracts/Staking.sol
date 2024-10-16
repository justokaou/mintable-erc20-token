// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title Staking
 * @dev A contract that allows users to stake tokens and earn rewards over time.
 * Supports pausing, reentrancy protection, and role-based access control.
 * Uses an emission rate to distribute rewards based on the staked amount.
 */
contract Staking is ReentrancyGuard, AccessControl, Pausable {
    // Define the admin role for managing critical contract functions
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    // Struct to track each staker's data: amount staked, reward status, etc.
    struct Stake {
        uint256 amount;               // Amount of tokens staked by the user
        uint256 since;                // Timestamp when the staking started
        uint256 pendingRewards;       // Rewards pending for the user
        uint256 rewardPerTokenPaid;   // Amount of reward per token paid out to the staker
    }

    // Mapping to track stakes by user address
    mapping(address => Stake) public stakes;

    // Variables related to reward distribution
    uint256 public lastRewardTime;                    // Last timestamp when rewards were calculated
    uint public dailyEmissionsRate = 1000 * 1e18;     // Daily reward emissions rate
    uint256 public bigRewardPerTokenStored;           // Accumulated rewards per token
    uint256 public totalTokenStaked;                  // Total tokens staked in the contract
    uint256 internal bigMultiplier = 1e18;            // Multiplier used for reward calculation

    // References to staking and reward tokens (ERC20)
    IERC20 internal stakingToken;
    IERC20 internal rewardToken;

    /**
     * @dev Initializes the staking and reward tokens, and sets up the admin roles.
     * @param _stakingToken The address of the token to be staked.
     * @param _rewardToken The address of the token to be rewarded.
     */
    constructor(address _stakingToken, address _rewardToken) {
        stakingToken = IERC20(_stakingToken);
        rewardToken = IERC20(_rewardToken);
        lastRewardTime = block.timestamp;

        // Grant the deployer admin roles
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);

        updateBigRewardsPerToken();
    }

    // MODIFIERS

    /**
     * @dev Modifier to check if the caller is an active staker.
     * Reverts if the caller has no active stake.
     */
    modifier isStaker() {
        require(stakes[msg.sender].amount > 0, "not active staker");
        _;
    }

    // EVENTS

    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);

    // STAKING FUNCTIONS

    /**
     * @dev Allows a user to stake a specified amount of tokens.
     * @param _amount The amount of tokens to stake.
     * Emits a `Staked` event.
     *
     * Requirements:
     * - The staking amount must be greater than 0.
     * - The user must have enough tokens in their balance to stake.
     */
    function stake(uint256 _amount) external nonReentrant whenNotPaused {
        require(_amount > 0, "Amount should be greater than 0");
        require(
            stakingToken.balanceOf(msg.sender) >= _amount,
            "amount exceeds balance"
        );

        totalTokenStaked += _amount;

        // Transfer the staked tokens to the contract
        stakingToken.transferFrom(msg.sender, address(this), _amount);

        if (isUserStaker(msg.sender)) {
            _getRewards();  // Update rewards before staking more
            stakes[msg.sender].amount += _amount;
        } else {
            stakes[msg.sender] = Stake({
                amount: _amount,
                since: block.timestamp,
                pendingRewards: 0,
                rewardPerTokenPaid: 0
            });
        }

        emit Staked(msg.sender, _amount);
    }

    /**
     * @dev Allows a user to unstake a specified amount of tokens.
     * @param _amount The amount of tokens to unstake.
     * Emits a `Withdrawn` event.
     *
     * Requirements:
     * - The unstaking amount must be greater than 0 and less than or equal to the staked amount.
     */
    function unstake(
        uint256 _amount
    ) external nonReentrant whenNotPaused isStaker {
        require(_amount > 0, "Cannot remove 0");
        require(
            _amount <= stakes[msg.sender].amount,
            "Can't unstake more than your stake!"
        );
        Stake storage userStake = stakes[msg.sender];

        // Update the staked amount and transfer tokens back to the user
        userStake.amount -= _amount;
        totalTokenStaked -= _amount;

        stakingToken.transfer(msg.sender, _amount);
        _getRewards();  // Update and distribute rewards after unstaking

        emit Withdrawn(msg.sender, _amount);
    }

    // REWARD FUNCTIONS

    /**
     * @dev Allows a user to claim their accumulated rewards.
     * Emits a `RewardPaid` event.
     */
    function getRewards() external nonReentrant whenNotPaused {
        _getRewards();
    }

    /**
     * @dev Internal function to calculate and distribute rewards to the caller.
     */
    function _getRewards() internal {
        uint256 rewardsToSend = updateAddressRewardsBalance(msg.sender);

        // Ensure the contract has enough tokens for the reward
        require(
            rewardToken.balanceOf(address(this)) - totalTokenStaked > 0,
            "Not enough tokens for reward"
        );

        if (rewardsToSend > 0) {
            rewardToken.transfer(msg.sender, rewardsToSend);
            emit RewardPaid(msg.sender, rewardsToSend);
        }
    }

    /**
     * @dev Updates the reward balance for the specified address.
     * @param _address The address to update rewards for.
     * @return The pending rewards for the address.
     */
    function updateAddressRewardsBalance(
        address _address
    ) internal returns (uint) {
        updateBigRewardsPerToken();
        uint pendingRewards = userPendingRewards(_address);
        stakes[_address].rewardPerTokenPaid = bigRewardPerTokenStored;
        return pendingRewards;
    }

    /**
     * @dev Updates the global reward per token variable based on the emissions rate.
     * This function should be called periodically to update the reward distribution.
     */
    function updateBigRewardsPerToken() public {
        if (timeSinceLastReward() > 0) {
            uint rewardSeconds = timeSinceLastReward();
            lastRewardTime = block.timestamp;
            uint emissionsPerSecond = dailyEmissionsRate / 86400;
            uint newEmissionsToAdd = emissionsPerSecond * rewardSeconds;
            uint newBigRewardsPerToken = ((newEmissionsToAdd * bigMultiplier) /
                totalTokenStaked);
            bigRewardPerTokenStored += newBigRewardsPerToken;
        }
    }

    /**
     * @dev Calculates the pending rewards for a specific user based on their staked amount.
     * @param _address The address of the user.
     * @return The pending rewards for the user.
     */
    function userPendingRewards(address _address) public view returns (uint) {
        uint earnedBigRewardPerToken = bigRewardPerTokenStored -
            stakes[_address].rewardPerTokenPaid;
        if (earnedBigRewardPerToken > 0) {
            uint rewardsToSend = (earnedBigRewardPerToken *
                stakes[_address].amount) / bigMultiplier;

            return rewardsToSend;
        } else {
            return 0;
        }
    }

    // VIEW FUNCTIONS

    /**
     * @dev Returns the number of seconds since the last reward calculation.
     */
    function timeSinceLastReward() public view returns (uint) {
        return block.timestamp - lastRewardTime;
    }

    /**
     * @dev Returns the balance of reward tokens held by the contract, excluding the staked tokens.
     */
    function rewardsBalance() external view returns (uint256) {
        return rewardToken.balanceOf(address(this)) - totalTokenStaked;
    }

    /**
     * @dev Checks if an address is currently staking tokens.
     * @param _address The address to check.
     * @return True if the address has staked tokens, false otherwise.
     */
    function isUserStaker(address _address) public view returns (bool) {
        return stakes[_address].amount > 0;
    }

    // ADMIN FUNCTIONS

    /**
     * @dev Pauses the contract, disabling staking and unstaking functions.
     * Can only be called by an admin.
     */
    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }

    /**
     * @dev Unpauses the contract, enabling staking and unstaking functions.
     * Can only be called by an admin.
     */
    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }

    /**
     * @dev Updates the daily emission rate for rewards.
     * Can only be called by an admin.
     * @param newEmission The new daily emission rate.
     */
    function updateDailyEmission(
        uint256 newEmission
    ) external onlyRole(ADMIN_ROLE) {
        dailyEmissionsRate = newEmission;
    }

    /**
     * @dev Deposits reward tokens into the contract.
     * Can only be called by an admin.
     * @param _amount The amount of tokens to deposit.
     */
    function depositRewards(uint256 _amount) external onlyRole(ADMIN_ROLE) {
        rewardToken.transferFrom(msg.sender, address(this), _amount);
    }

    /**
     * @dev Withdraws reward tokens from the contract.
     * Can only be called by an admin.
     * @param _amount The amount of tokens to withdraw.
     *
     * Requirements:
     * - The withdrawal amount must not exceed the available reward tokens.
     */
    function withdrawRewards(uint256 _amount) external onlyRole(ADMIN_ROLE) {
        require(
            _amount <= rewardToken.balanceOf(address(this)) - totalTokenStaked,
            "Not enough tokens for reward"
        );
        rewardToken.transfer(msg.sender, _amount);
    }
}
