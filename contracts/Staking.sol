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
        uint256 pendingRewards;
        uint256 rewardPerTokenPaid;
    }

    mapping(address => Stake) public stakes;

    uint256 public lastRewardTime;
    uint public dailyEmissionsRate = 1000 * 1e18;
    uint256 public bigRewardPerTokenStored;
    uint256 public totalTokenStaked;
    uint256 internal bigMultiplier = 1e18;

    IERC20 internal stakingToken;
    IERC20 internal rewardToken;

    // Constructor

    constructor(address _stakingToken, address _rewardToken) {
        stakingToken = IERC20(_stakingToken);
        rewardToken = IERC20(_rewardToken);
        lastRewardTime = block.timestamp;

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);

        updateBigRewardsPerToken();
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

        totalTokenStaked += _amount;

        stakingToken.transferFrom(msg.sender, address(this), _amount);

        if (isUserStaker(msg.sender)) {
            _getRewards();
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
        _getRewards();

        emit Withdrawn(msg.sender, _amount);
    }

    // Rewards

    function getRewards() external nonReentrant whenNotPaused {
        _getRewards();
    }

    function _getRewards() internal {
        uint256 rewardsToSend = updateAddressRewardsBalance(msg.sender);

        require(
            rewardToken.balanceOf(address(this)) - totalTokenStaked > 0,
            "Not enough tokens for reward"
        );

        if (rewardsToSend > 0) {
            rewardToken.transfer(msg.sender, rewardsToSend);
            emit RewardPaid(msg.sender, rewardsToSend);
        }
    }

    function updateAddressRewardsBalance(
        address _address
    ) internal returns (uint) {
        updateBigRewardsPerToken();
        uint pendingRewards = userPendingRewards(_address);
        stakes[_address].rewardPerTokenPaid = bigRewardPerTokenStored;
        return pendingRewards;
    }

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

    // view

    function timeSinceLastReward() public view returns (uint) {
        return block.timestamp - lastRewardTime;
    }

    function rewardsBalance() external view returns (uint256) {
        return rewardToken.balanceOf(address(this)) - totalTokenStaked;
    }

    function isUserStaker(address _address) public view returns (bool) {
        return stakes[_address].amount > 0;
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
        require(
            _amount <= rewardToken.balanceOf(address(this)) - totalTokenStaked,
            "Not enough tokens for reward"
        );
        rewardToken.transfer(msg.sender, _amount);
    }
}
