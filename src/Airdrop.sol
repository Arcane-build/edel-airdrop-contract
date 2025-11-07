// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title Airdrop
 * @notice Simple ERC20 airdrop contract that lets eligible addresses claim a fixed amount.
 */
contract Airdrop is Ownable {
    /// @notice ERC20 token distributed by this airdrop.
    address public token;

    /// @notice Fixed amount of tokens sent to each eligible claimer.
    uint256 public airdropAmount;

    /// @notice Total number of users who have opted into the staking flow.
    uint256 public totalUserStaked;

    /// @notice Staking duration in days.
    uint256 private constant STAKING_DURATION = 1 days;

    /// @notice Tracks the staking unlock time for each address.
    mapping(address => uint256) public stakingUnlockTime;

    /// @notice Tracks whether an address has staked or not.
    mapping(address => bool) public hasStaked;

    /// @notice Tracks whether an address is currently eligible to claim.
    mapping(address => bool) public isEligibaleForClaim;

    /// @notice Tracks whether an address has already claimed.
    mapping(address => bool) public hasClaimed;

    /// @notice Thrown when a caller attempts to claim without eligibility.
    error NotEligibaleForClaim();

    /// @notice Thrown when a caller attempts to claim again.
    error AlreadyClaimed();

    /// @notice Thrown when a caller attempts to stake again.
    error AlreadyStaked();

    /// @notice Thrown when a caller attempts when stake is not active.
    error NotStaked();

    /// @notice Thrown when a caller attempts to withdraw stake rewards before timeline
    error CanNotClaimNow();

    /// @notice Emitted after a successful claim.
    /// @param user The address that claimed the airdrop.
    /// @param amount The amount of tokens transferred to the claimer.
    event AirdropClaimed(address indexed user, uint256 amount);

    /// @notice Emitted when a user claims half the airdrop immediately and stakes the remaining share.
    /// @param user The address that initiated the claim-and-stake flow.
    /// @param claimAMount The portion of tokens transferred instantly to the user.
    /// @param stakeAmount The portion of tokens locked for staking rewards.
    event AirdropClaimAndStake(address indexed user, uint256 claimAMount, uint256 stakeAmount);

    /**
     * @notice Initializes the airdrop with the ERC20 token and the fixed claim amount.
     * @dev Sets the initial owner to the deployer via Ownable(msg.sender).
     * @param _token The ERC20 token address to distribute.
     * @param _airdropAmount The fixed number of tokens sent per claim.
     */
    constructor(address _token, uint256 _airdropAmount) Ownable(msg.sender) {
        token = _token;
        airdropAmount = _airdropAmount;
    }

    /**
     * @notice Claims the airdrop tokens if the caller is eligible.
     * @dev Reverts with {NotEligibaleForClaim} if the caller is not eligible.
     * Marks the caller as ineligible after a successful transfer and emits {AirdropClaimed}.
     */
    function claim() public {
        if (!isEligibaleForClaim[msg.sender]) revert NotEligibaleForClaim();
        if (hasClaimed[msg.sender]) revert AlreadyClaimed();
        if (hasStaked[msg.sender]) revert AlreadyStaked();

        hasClaimed[msg.sender] = true;
        SafeERC20.safeTransfer(IERC20(token), msg.sender, airdropAmount);
        emit AirdropClaimed(msg.sender, airdropAmount);
    }

    /**
     * @notice Claims half of the airdrop immediately and stakes the remaining half for a fixed duration.
     * @dev Reverts if the caller has already claimed, staked, or is currently in an active staking period.
     * Marks the caller as staked, records the unlock timestamp, and transfers half the airdrop amount.
     */
    function claimHalfAndStake() public {
        if (!isEligibaleForClaim[msg.sender]) revert NotEligibaleForClaim();
        if (hasClaimed[msg.sender]) revert AlreadyClaimed();
        if (hasStaked[msg.sender]) revert AlreadyStaked();
        if (stakingUnlockTime[msg.sender] > 0) revert AlreadyStaked();

        uint256 transferAmount = airdropAmount / 2;
        hasStaked[msg.sender] = true;
        totalUserStaked++;
        stakingUnlockTime[msg.sender] = block.timestamp + STAKING_DURATION;
        SafeERC20.safeTransfer(IERC20(token), msg.sender, transferAmount);

        emit AirdropClaimAndStake(msg.sender, transferAmount, airdropAmount - transferAmount);
    }

    /**
     * @notice Claims the staked portion of the airdrop after the staking duration has elapsed.
     * @dev Reverts if the caller has already claimed, never staked, or the staking unlock time has not passed.
     * Marks the caller as claimed and transfers the remanimg airdrop amount + reward worth of half airdrop amount.
     */
    function claimStakeRewards() public {
        if (hasClaimed[msg.sender]) revert AlreadyClaimed();
        if (!hasStaked[msg.sender]) revert NotStaked();
        if (stakingUnlockTime[msg.sender] > block.timestamp) revert CanNotClaimNow();
        hasClaimed[msg.sender] = true;
        SafeERC20.safeTransfer(IERC20(token), msg.sender, airdropAmount);
        emit AirdropClaimed(msg.sender, airdropAmount);
    }

    /**
     * @notice Batch-updates claim eligibility for a list of addresses.
     * @dev Only callable by the contract owner.
     * @param _addresses The list of addresses whose eligibility will be updated.
     */
    function setEligibaleForClaim(address[] calldata _addresses) public onlyOwner {
        for (uint256 i = 0; i < _addresses.length; i++) {
            isEligibaleForClaim[_addresses[i]] = true;
        }
    }

    /**
     * @notice Perform emergency token withdraw by owner
     */
    function withdraw(address _token, uint256 _amount) public onlyOwner {
        SafeERC20.safeTransfer(IERC20(_token), owner(), _amount);
    }
}
