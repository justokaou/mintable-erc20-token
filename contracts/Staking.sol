// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

contract Staking is ReentrancyGuard, AccessControl, Pausable {
    // VAR

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    struct Stake {
        uint256 amount;
        uint256 since;
        uint256 rewards;
        uint256 rewardPerTokenPaid;
    }

    mapping(address => Stake) public stakes;

    uint256 public lastRewardTime;
    uint public dailyEmissionsRate = 1000 * 1e18;
    uint256 public rewardPerTokenStored;
    uint256 public totalTokenStaked;

    IERC20 internal stakingToken;
    IERC20 internal rewardToken;

    // Constructor

    constructor(address _stakingToken, address _rewardToken) {
        stakingToken = IERC20(_stakingToken);
        rewardToken = IERC20(_rewardToken);
        lastRewardTime = block.timestamp;

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
    }

    // Modifiers

    modifier isStaker() {
        require(stakes[msg.sender].amount > 0, "not active staker");
        _;
    }

    // EVENTS

    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);

    // Staking

    function stake(uint256 _amount) external nonReentrant whenNotPaused {
        require(_amount > 0, "Amount should be greater than 0");
        require(
            stakingToken.balanceOf(msg.sender) >= _amount,
            "amount exceeds balance"
        );

        stakes[msg.sender] = Stake({
            amount: _amount,
            since: block.timestamp,
            rewards: 0,
            rewardPerTokenPaid: 0
        });

        totalTokenStaked += _amount;

        stakingToken.transferFrom(msg.sender, address(this), _amount);
        emit Staked(msg.sender, _amount);
    }

    function unstake(
        uint256 _amount
    ) external nonReentrant whenNotPaused isStaker {
        require(_amount > 0, "Cannot remove 0");
        require(
            _amount <= stakes[msg.sender].amount,
            "Can't unstake more than your stake!"
        );
        Stake storage userStake = stakes[msg.sender];

        userStake.amount -= _amount;
        totalTokenStaked -= _amount;

        stakingToken.transfer(msg.sender, _amount);

        emit Withdrawn(msg.sender, _amount);
    }

    // Rewards

    function getRewards() external nonReentrant whenNotPaused {
        getRewardsInternal();
    }

    function getRewardsInternal() internal {
        updateRewardsPerToken();
        uint rewardsToSend = userPendingRewards(msg.sender);

        require(
            rewardsToSend <=
                rewardToken.balanceOf(address(this)) - totalTokenStaked,
            "Not enough tokens for reward"
        );

        if (rewardsToSend > 0) {
            stakes[msg.sender].rewards = 0;
            stakes[msg.sender].rewardPerTokenPaid = rewardPerTokenStored;
            stakingToken.transfer(msg.sender, rewardsToSend);
            emit RewardPaid(msg.sender, rewardsToSend);
        }
    }

    function updateAddressRewardsBalance(
        address _address
    ) internal returns (uint) {
        updateRewardsPerToken();
        uint pendingRewards = userPendingRewards(_address);
        return pendingRewards;
    }

    function userPendingRewards(
        address _address
    ) public view returns (uint256) {
        Stake storage userStake = stakes[_address];
        uint256 totalReward = rewardPerToken();
        uint256 earnedReward = ((totalReward - userStake.rewardPerTokenPaid) *
            userStake.amount) / 1e18;
        return earnedReward + userStake.rewards;
    }

    function updateRewardsPerToken() public {
        if (timeSinceLastReward() > 0 && totalTokenStaked != 0) {
            uint rewardSeconds = timeSinceLastReward();
            lastRewardTime = block.timestamp;
            uint emissionsPerSecond = dailyEmissionsRate / 86400;
            uint newEmissionsToAdd = emissionsPerSecond * rewardSeconds * 1e18;
            uint newRewardsPerToken = (newEmissionsToAdd / totalTokenStaked) /
                1e18;
            rewardPerTokenStored += newRewardsPerToken;
        }
    }

    // view

    function timeSinceLastReward() public view returns (uint) {
        return block.timestamp - lastRewardTime;
    }

    function rewardPerToken() internal view returns (uint256) {
        if (totalTokenStaked == 0) {
            return rewardPerTokenStored;
        }

        uint256 ratePerSecond = dailyEmissionsRate / 86400;

        return
            rewardPerTokenStored +
            (((block.timestamp - lastRewardTime) * ratePerSecond) /
                totalTokenStaked);
    }

    function rewardsBalance() external view returns (uint256) {
        return rewardToken.balanceOf(address(this)) - totalTokenStaked;
    }

    // ADMIN

    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }

    function updateDailyEmission(
        uint256 newEmission
    ) external onlyRole(ADMIN_ROLE) {
        dailyEmissionsRate = newEmission;
    }

    function depositRewards(uint256 _amount) external onlyRole(ADMIN_ROLE) {
        rewardToken.transferFrom(msg.sender, address(this), _amount);
    }

    function withdrawRewards(uint256 _amount) external onlyRole(ADMIN_ROLE) {
        rewardToken.transferFrom(msg.sender, address(this), _amount);
    }
}
