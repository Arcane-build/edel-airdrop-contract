# Airdrop Smart Contract Documentation

## Overview

The `Airdrop` contract distributes a fixed ERC20 allocation to addresses that the owner marks as eligible. Eligible users can claim half of their allocation immediately and decide whether to stake the remaining half to earn an additional reward after a 24-hour lock. The contract also tracks participation statistics and separates users by staking preference.

## Features

- **Fixed Allotment**: Each eligible user receives the same `airdropAmount`.
- **Flexible Claiming**: Users claim half up front and optionally opt into staking the remaining half during the claim.
- **Staking Rewards**: Opted-in users lock the remaining half for 24 hours and withdraw the full `airdropAmount` (principal + reward) once unlocked.
- **Participation Tracking**: The contract records which users claimed, staked, unstaked, and keeps per-group address lists.
- **Owner Controls**: The owner can batch-enable eligibility and withdraw any ERC20 tokens from the contract.
- **Safe Transfers & Guards**: Uses OpenZeppelin `SafeERC20`, `Ownable`, and `ReentrancyGuard`.

## Contract Details

- **License**: MIT
- **Solidity Version**: ^0.8.0
- **Imports**:
  - `Ownable`
  - `ReentrancyGuard`
  - `SafeERC20`
  - `IERC20`

## State Variables

### Public Variables

| Variable | Type | Description |
|----------|------|-------------|
| `token` | `address` | ERC20 token distributed by the airdrop |
| `airdropAmount` | `uint256` | Fixed allocation per eligible claimer |
| `totalUserStaked` | `uint256` | Count of users who have ever staked |
| `totalTokensStaked` | `uint256` | Cumulative tokens locked via staking |
| `stakedUsers` | `address[]` | Addresses that opted into staking |
| `nonStakedUsers` | `address[]` | Addresses that skipped staking |

### Private Constants

| Variable | Type | Value | Description |
|----------|------|-------|-------------|
| `STAKING_DURATION` | `uint256` | `1 days` | Lock period before unstaking |

### Mappings

| Mapping | Type | Description |
|---------|------|-------------|
| `stakingUnlockTime` | `mapping(address => uint256)` | Unlock timestamp for stakers |
| `hasStaked` | `mapping(address => bool)` | Whether the address called `stake()` |
| `hasUnstaked` | `mapping(address => bool)` | Whether the address already withdrew |
| `wantsToStake` | `mapping(address => bool)` | User's staking preference set during `claim()` |
| `isEligibaleForClaim` | `mapping(address => bool)` | Eligibility flag (note spelling matches contract) |
| `hasClaimed` | `mapping(address => bool)` | Claim status |
| `isInStakedList` | `mapping(address => bool)` | Prevents duplicates in `stakedUsers` array |
| `isInNonStakedList` | `mapping(address => bool)` | Prevents duplicates in `nonStakedUsers` array |

## Functions

### Constructor

```solidity
constructor(address _token, uint256 _airdropAmount) Ownable(msg.sender)
```

Initializes the token and the per-user allocation. Reverts if `_token` is the zero address or `_airdropAmount` is zero.

---

### `claim(bool _wantsToStake)`

```solidity
function claim(bool _wantsToStake) public nonReentrant
```

Eligible users call `claim` to receive half of their allocation immediately. They simultaneously signal whether they intend to stake the remaining half.

- **Requirements**
  - Caller is eligible and has not claimed before.
- **Effects**
  - Stores the caller's staking preference in `wantsToStake`.
  - Sends `airdropAmount / 2` tokens to the caller.
  - Adds the caller to `nonStakedUsers` if `_wantsToStake` is false.
  - Emits `AirdropClaimed`.
- **Reverts**
  - `NotEligibaleForClaim()` if not whitelisted.
  - `AlreadyClaimed()` if the caller already claimed.

---

### `stake()`

```solidity
function stake() public nonReentrant
```

Allows a claimer who opted into staking to start the staking period after their claim.

- **Requirements**
  - Caller claimed, opted into staking, has not already staked, and has not unstaked.
- **Effects**
  - Marks the caller as staked, updates totals, sets a 24-hour unlock timestamp, and records the address in `stakedUsers`.
  - Emits `Staked`.
- **Reverts**
  - `NotClaimed()`, `DoesNotWantToStake()`, `AlreadyStaked()`, or `AlreadyUnstaked()` as appropriate.

---

### `unstake()`

```solidity
function unstake() public nonReentrant
```

Lets a staker withdraw the locked half plus rewards (totaling `airdropAmount`) after the lock expires.

- **Requirements**
  - Caller staked, has not already unstaked, and the unlock timestamp has passed.
- **Effects**
  - Transfers `airdropAmount` tokens to the caller (return of principal and reward).
  - Marks the caller as unstaked.
  - Emits `Unstaked`.
- **Reverts**
  - `NotStaked()`, `AlreadyUnstaked()`, or `CanNotUnstakeNow()`.

---

### `setEligibaleForClaim(address[] calldata _addresses)`

```solidity
function setEligibaleForClaim(address[] calldata _addresses) public onlyOwner
```

Owner-only batch method to toggle eligibility for incoming addresses. Reverts with `ZeroAddress()` if any input is the zero address.

---

### `getStakedUsers()` / `getNonStakedUsers()` / `getStakedUsersCount()` / `getNonStakedUsersCount()`

View helpers that return the respective address arrays and counts.

---

### `withdraw(address _token, uint256 _amount)`

```solidity
function withdraw(address _token, uint256 _amount) public onlyOwner
```

Permits the owner to perform emergency withdrawals of any ERC20 token. Reverts on zero address or zero amount and emits `Withdrawn`.

## Events

- `AirdropClaimed(address indexed user, uint256 amount, bool wantsToStake)`
- `Staked(address indexed user, uint256 stakeAmount, uint256 unlockTime)`
- `Unstaked(address indexed user, uint256 totalAmount)`
- `Withdrawn(address indexed token, uint256 amount)`

## Custom Errors

- `NotEligibaleForClaim()`
- `AlreadyClaimed()`
- `AlreadyStaked()`
- `AlreadyUnstaked()`
- `DoesNotWantToStake()`
- `NotClaimed()`
- `NotStaked()`
- `CanNotUnstakeNow()`
- `ZeroAddress()`
- `ZeroAmount()`

## Usage Flow

1. **Owner setup**  
   - Call `setEligibaleForClaim()` with the list of addresses allowed to participate.
   - Fund the contract with enough tokens to cover all expected claims and rewards.
2. **User claim**  
   - Eligible user calls `claim(true)` to opt into staking, or `claim(false)` to skip it.
   - User immediately receives `airdropAmount / 2`.
3. **If staking**  
   - User calls `stake()` to start the 24-hour lock and be counted toward staking totals.
   - After the unlock time, user calls `unstake()` to receive `airdropAmount` (locked half + reward half).
4. **If not staking**  
   - No further interaction is needed after `claim(false)`; the user only receives half the allocation and forgoes the reward.

## Operational Notes

- Each address can claim only once. Staking is optional but must be signaled at claim time.
- Unstaking becomes available exactly 24 hours after `stake()`.
- Ensure the contract maintains sufficient token reserves to fulfill both immediate transfers and future unstake payouts.
- Owner withdrawals should only occur when excess tokens remain; withdrawing active staking liquidity risks failed unstake calls.

## Usage

```shell
forge build
forge test
```

## License

MIT