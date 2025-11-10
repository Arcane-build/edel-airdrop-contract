// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title Airdrop
 * @notice ERC20 airdrop contract that allows eligible addresses to claim half the airdrop amount.
 * Users can optionally stake the remaining half to earn rewards after a 24-hour lock period.
 */
contract Airdrop is Ownable, ReentrancyGuard {
    /// @notice ERC20 token distributed by this airdrop.
    address public token;

    /// @notice Fixed amount of tokens sent to each eligible claimer.
    uint256 public airdropAmount;

    /// @notice Total number of users who have staked.
    uint256 public totalUserStaked;

    /// @notice Total amount of tokens that have been staked (cumulative, not current balance).
    uint256 public totalTokensStaked;

    /// @notice Staking duration in seconds (24 hours).
    uint256 private constant STAKING_DURATION = 1 days;

    /// @notice Tracks the staking unlock time for each address.
    mapping(address => uint256) public stakingUnlockTime;

    /// @notice Tracks whether an address has staked or not.
    mapping(address => bool) public hasStaked;

    /// @notice Tracks whether an address has unstaked after staking.
    mapping(address => bool) public hasUnstaked;

    /// @notice Tracks whether an address indicated they want to stake during claim.
    mapping(address => bool) public wantsToStake;

    /// @notice Tracks whether an address is currently eligible to claim.
    mapping(address => bool) public isEligibaleForClaim;

    /// @notice Tracks whether an address has already claimed.
    mapping(address => bool) public hasClaimed;

    /// @notice Tracks whether an address is in the staked users list.
    mapping(address => bool) public isInStakedList;

    /// @notice Tracks whether an address is in the non-staked users list.
    mapping(address => bool) public isInNonStakedList;

    /// @notice List of addresses who have staked.
    address[] public stakedUsers;

    /// @notice List of addresses who have not staked.
    address[] public nonStakedUsers;

    /// @notice Thrown when a caller attempts to claim without eligibility.
    error NotEligibaleForClaim();

    /// @notice Thrown when a caller attempts to claim again.
    error AlreadyClaimed();

    /// @notice Thrown when a caller attempts to stake again.
    error AlreadyStaked();

    /// @notice Thrown when a caller attempts to stake but has already unstaked.
    error AlreadyUnstaked();

    /// @notice Thrown when a caller attempts to stake but didn't indicate they want to stake.
    error DoesNotWantToStake();

    /// @notice Thrown when a caller attempts to stake but hasn't claimed yet.
    error NotClaimed();

    /// @notice Thrown when a caller attempts when stake is not active.
    error NotStaked();

    /// @notice Thrown when a caller attempts to unstake before the unlock time.
    error CanNotUnstakeNow();

    /// @notice Thrown when zero address is provided.
    error ZeroAddress();

    /// @notice Thrown when zero amount is provided.
    error ZeroAmount();

    /// @notice Emitted after a successful claim.
    /// @param user The address that claimed the airdrop.
    /// @param amount The amount of tokens transferred to the claimer.
    /// @param wantsToStake Whether the user indicated they want to stake.
    event AirdropClaimed(address indexed user, uint256 amount, bool wantsToStake);

    /// @notice Emitted when a user stakes their remaining airdrop portion.
    /// @param user The address that staked.
    /// @param stakeAmount The amount of tokens staked.
    /// @param unlockTime The timestamp when staking unlocks.
    event Staked(address indexed user, uint256 stakeAmount, uint256 unlockTime);

    /// @notice Emitted when a user unstakes and receives their staked tokens plus rewards.
    /// @param user The address that unstaked.
    /// @param totalAmount The total amount transferred (staked + rewards).
    event Unstaked(address indexed user, uint256 totalAmount);

    /// @notice Emitted when owner withdraws tokens.
    /// @param token The token address that was withdrawn.
    /// @param amount The amount of tokens withdrawn.
    event Withdrawn(address indexed token, uint256 amount);

    /**
     * @notice Initializes the airdrop with the ERC20 token and the fixed claim amount.
     * @dev Sets the initial owner to the deployer via Ownable(msg.sender).
     * @param _token The ERC20 token address to distribute.
     * @param _airdropAmount The fixed number of tokens sent per claim.
     */
    constructor(address _token, uint256 _airdropAmount) Ownable(msg.sender) {
        if (_token == address(0)) revert ZeroAddress();
        if (_airdropAmount == 0) revert ZeroAmount();
        token = _token;
        airdropAmount = _airdropAmount;
    }

    /**
     * @notice Claims half of the airdrop amount if the caller is eligible.
     * @dev Reverts with {NotEligibaleForClaim} if the caller is not eligible.
     * Reverts with {AlreadyClaimed} if the caller has already claimed.
     * Transfers half the airdrop amount and records whether the user wants to stake.
     * If user doesn't want to stake, they are added to the non-staked users list.
     * @param _wantsToStake Whether the user wants to stake the remaining half (true) or not (false).
     */
    function claim(bool _wantsToStake) public nonReentrant {
        if (!isEligibaleForClaim[msg.sender]) revert NotEligibaleForClaim();
        if (hasClaimed[msg.sender]) revert AlreadyClaimed();

        uint256 transferAmount = airdropAmount / 2;
        hasClaimed[msg.sender] = true;
        wantsToStake[msg.sender] = _wantsToStake;

        // Add to non-staked list if user doesn't want to stake
        if (!_wantsToStake) {
            if (!isInNonStakedList[msg.sender]) {
                nonStakedUsers.push(msg.sender);
                isInNonStakedList[msg.sender] = true;
            }
        }

        SafeERC20.safeTransfer(IERC20(token), msg.sender, transferAmount);
        emit AirdropClaimed(msg.sender, transferAmount, _wantsToStake);
    }

    /**
     * @notice Stakes the remaining half of the airdrop amount for a 24-hour period.
     * @dev Reverts if the caller hasn't claimed, doesn't want to stake, has already staked, or has already unstaked.
     * Sets up staking with unlock time after 24 hours and adds user to staked users list.
     * Updates total tokens staked and total user staked counters.
     */
    function stake() public nonReentrant {
        if (!hasClaimed[msg.sender]) revert NotClaimed();
        if (!wantsToStake[msg.sender]) revert DoesNotWantToStake();
        if (hasUnstaked[msg.sender]) revert AlreadyUnstaked();
        if (hasStaked[msg.sender]) revert AlreadyStaked();

        uint256 stakeAmount = airdropAmount / 2;
        hasStaked[msg.sender] = true;
        totalUserStaked++;
        totalTokensStaked += stakeAmount;
        stakingUnlockTime[msg.sender] = block.timestamp + STAKING_DURATION;

        // Add to staked users list
        if (!isInStakedList[msg.sender]) {
            stakedUsers.push(msg.sender);
            isInStakedList[msg.sender] = true;
        }

        emit Staked(msg.sender, stakeAmount, stakingUnlockTime[msg.sender]);
    }

    /**
     * @notice Unstakes and receives the staked tokens plus rewards after the 24-hour lock period.
     * @dev Reverts if the caller hasn't staked, the unlock time hasn't passed, or has already unstaked.
     * Transfers the staked amount (half airdrop) plus rewards (half airdrop) = full airdrop amount.
     * Updates total tokens staked counter and marks the user as unstaked.
     */
    function unstake() public nonReentrant {
        if (!hasStaked[msg.sender]) revert NotStaked();
        if (hasUnstaked[msg.sender]) revert AlreadyUnstaked();
        if (stakingUnlockTime[msg.sender] > block.timestamp) revert CanNotUnstakeNow();

        uint256 totalAmount = airdropAmount; // Total = full airdrop amount (half staking amount + half reward amount)

        hasUnstaked[msg.sender] = true;
        SafeERC20.safeTransfer(IERC20(token), msg.sender, totalAmount);
        emit Unstaked(msg.sender, totalAmount);
    }

    /**
     * @notice Batch-updates claim eligibility for a list of addresses.
     * @dev Only callable by the contract owner.
     * @param _addresses The list of addresses whose eligibility will be updated.
     */
    function setEligibaleForClaim(address[] calldata _addresses) public onlyOwner {
        for (uint256 i = 0; i < _addresses.length; i++) {
            if (_addresses[i] == address(0)) revert ZeroAddress();
            isEligibaleForClaim[_addresses[i]] = true;
        }
    }

    /**
     * @notice Returns the list of addresses who have staked.
     * @return Array of addresses who have staked.
     */
    function getStakedUsers() public view returns (address[] memory) {
        return stakedUsers;
    }

    /**
     * @notice Returns the list of addresses who have not staked.
     * @return Array of addresses who have not staked.
     */
    function getNonStakedUsers() public view returns (address[] memory) {
        return nonStakedUsers;
    }

    /**
     * @notice Returns the number of users who have staked.
     * @return The count of staked users.
     */
    function getStakedUsersCount() public view returns (uint256) {
        return stakedUsers.length;
    }

    /**
     * @notice Returns the number of users who have not staked.
     * @return The count of non-staked users.
     */
    function getNonStakedUsersCount() public view returns (uint256) {
        return nonStakedUsers.length;
    }

    /**
     * @notice Perform emergency token withdraw by owner.
     * @dev Only callable by the contract owner.
     * @param _token The token address to withdraw.
     * @param _amount The amount of tokens to withdraw.
     */
    function withdraw(address _token, uint256 _amount) public onlyOwner {
        if (_token == address(0)) revert ZeroAddress();
        if (_amount == 0) revert ZeroAmount();
        SafeERC20.safeTransfer(IERC20(_token), owner(), _amount);
        emit Withdrawn(_token, _amount);
    }
}
