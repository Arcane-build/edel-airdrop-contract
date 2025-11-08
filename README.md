# Airdrop Smart Contract Documentation

## Overview

The `Airdrop` contract is an ERC20 token distribution system that allows eligible addresses to claim a fixed amount of tokens. It provides two claiming mechanisms: immediate full claim or a claim-and-stake option where users can claim half immediately and stake the remaining half for rewards.

## Features

- **Fixed Amount Airdrop**: Each eligible address can claim a fixed, predetermined amount of tokens
- **Dual Claim Options**:
  - **Immediate Claim**: Claim the full airdrop amount instantly
  - **Claim and Stake**: Claim half immediately and stake the remaining half for 1 day to receive 1.5x rewards
- **Owner Controls**: Contract owner can manage eligibility and perform emergency withdrawals
- **Safe Token Transfers**: Uses OpenZeppelin's SafeERC20 for secure token transfers

## Contract Details

- **License**: MIT
- **Solidity Version**: ^0.8.0
- **Inherits**: `Ownable` from OpenZeppelin
- **Dependencies**: 
  - OpenZeppelin `Ownable`
  - OpenZeppelin `SafeERC20`
  - OpenZeppelin `IERC20`

## State Variables

### Public Variables

| Variable | Type | Description |
|----------|------|-------------|
| `token` | `address` | The ERC20 token address that will be distributed |
| `airdropAmount` | `uint256` | Fixed amount of tokens each eligible address can claim |
| `totalUserStaked` | `uint256` | Total number of users who have opted into the staking flow |

### Private Constants

| Variable | Type | Value | Description |
|----------|------|-------|-------------|
| `STAKING_DURATION` | `uint256` | `1 days` | Duration users must wait before claiming staking rewards |

### Mappings

| Mapping | Type | Description |
|---------|------|-------------|
| `stakingUnlockTime` | `mapping(address => uint256)` | Tracks when each address can claim their staked rewards |
| `hasStaked` | `mapping(address => bool)` | Tracks whether an address has staked tokens |
| `isEligibaleForClaim` | `mapping(address => bool)` | Tracks whether an address is eligible to claim |
| `hasClaimed` | `mapping(address => bool)` | Tracks whether an address has already claimed |

## Functions

### Constructor

```solidity
constructor(address _token, uint256 _airdropAmount) Ownable(msg.sender)
```

**Description**: Initializes the airdrop contract with the token address and fixed claim amount.

**Parameters**:
- `_token` (address): The ERC20 token address to distribute
- `_airdropAmount` (uint256): The fixed number of tokens sent per claim

**Requirements**:
- None

**Effects**:
- Sets the contract owner to the deployer
- Sets the token address
- Sets the airdrop amount

---

### `claim()`

```solidity
function claim() public
```

**Description**: Allows eligible addresses to claim the full airdrop amount immediately.

**Parameters**: None

**Requirements**:
- Caller must be eligible (`isEligibaleForClaim[msg.sender] == true`)
- Caller must not have already claimed (`hasClaimed[msg.sender] == false`)
- Caller must not have staked (`hasStaked[msg.sender] == false`)

**Effects**:
- Marks the caller as claimed (`hasClaimed[msg.sender] = true`)
- Transfers `airdropAmount` tokens to the caller
- Emits `AirdropClaimed` event

**Reverts**:
- `NotEligibaleForClaim()`: If caller is not eligible
- `AlreadyClaimed()`: If caller has already claimed
- `AlreadyStaked()`: If caller has already staked

**Events**:
- `AirdropClaimed(address indexed user, uint256 amount)`

---

### `claimHalfAndStake()`

```solidity
function claimHalfAndStake() public
```

**Description**: Claims half of the airdrop immediately and stakes the remaining half for a fixed duration (1 day). After the staking period, users can claim the staked portion plus rewards (total of full airdrop amount).

**Parameters**: None

**Requirements**:
- Caller must be eligible (`isEligibaleForClaim[msg.sender] == true`)
- Caller must not have already claimed (`hasClaimed[msg.sender] == false`)
- Caller must not have already staked (`hasStaked[msg.sender] == false`)
- Caller must not have an active staking period (`stakingUnlockTime[msg.sender] == 0`)

**Effects**:
- Transfers `airdropAmount / 2` tokens immediately to the caller
- Marks the caller as staked (`hasStaked[msg.sender] = true`)
- Increments `totalUserStaked`
- Sets `stakingUnlockTime[msg.sender] = block.timestamp + 1 days`
- Emits `AirdropClaimAndStake` event

**Reverts**:
- `NotEligibaleForClaim()`: If caller is not eligible
- `AlreadyClaimed()`: If caller has already claimed
- `AlreadyStaked()`: If caller has already staked or has an active staking period

**Events**:
- `AirdropClaimAndStake(address indexed user, uint256 claimAMount, uint256 stakeAmount)`

**Note**: The staked amount is `airdropAmount - (airdropAmount / 2)`, which equals half the airdrop amount.

---

### `claimStakeRewards()`

```solidity
function claimStakeRewards() public
```

**Description**: Claims the staked portion of the airdrop after the staking duration has elapsed. Users receive the full airdrop amount (the remaining half plus rewards equal to half the airdrop amount).

**Parameters**: None

**Requirements**:
- Caller must not have already claimed (`hasClaimed[msg.sender] == false`)
- Caller must have staked (`hasStaked[msg.sender] == true`)
- Staking unlock time must have passed (`stakingUnlockTime[msg.sender] <= block.timestamp`)

**Effects**:
- Marks the caller as claimed (`hasClaimed[msg.sender] = true`)
- Transfers `airdropAmount` tokens to the caller (remaining half + reward)
- Emits `AirdropClaimed` event

**Reverts**:
- `AlreadyClaimed()`: If caller has already claimed
- `NotStaked()`: If caller never staked
- `CanNotClaimNow()`: If staking unlock time has not yet passed

**Events**:
- `AirdropClaimed(address indexed user, uint256 amount)`

**Reward Calculation**: 
- User receives `airdropAmount` total (the staked half + reward equal to half)
- Effective reward: 100% APY for 1 day staking period

---

### `setEligibaleForClaim()`

```solidity
function setEligibaleForClaim(address[] calldata _addresses) public onlyOwner
```

**Description**: Batch-updates claim eligibility for a list of addresses. Only the contract owner can call this function.

**Parameters**:
- `_addresses` (address[]): Array of addresses to mark as eligible for claiming

**Requirements**:
- Caller must be the contract owner
- None (addresses can be set as eligible multiple times without error)

**Effects**:
- Sets `isEligibaleForClaim[_addresses[i]] = true` for each address in the array

**Reverts**:
- Reverts if caller is not the owner (via `onlyOwner` modifier)

---

## Events

### `AirdropClaimed`

```solidity
event AirdropClaimed(address indexed user, uint256 amount)
```

**Description**: Emitted when a user successfully claims airdrop tokens.

**Parameters**:
- `user` (address, indexed): The address that claimed the airdrop
- `amount` (uint256): The amount of tokens transferred

---

### `AirdropClaimAndStake`

```solidity
event AirdropClaimAndStake(address indexed user, uint256 claimAMount, uint256 stakeAmount)
```

**Description**: Emitted when a user claims half the airdrop immediately and stakes the remaining share.

**Parameters**:
- `user` (address, indexed): The address that initiated the claim-and-stake flow
- `claimAMount` (uint256): The portion of tokens transferred instantly (half of airdrop)
- `stakeAmount` (uint256): The portion of tokens locked for staking (half of airdrop)

---

## Custom Errors

### `NotEligibaleForClaim()`

**Description**: Thrown when a caller attempts to claim without being eligible.

**Triggered by**: `claim()`, `claimHalfAndStake()`

---

### `AlreadyClaimed()`

**Description**: Thrown when a caller attempts to claim again after already claiming.

**Triggered by**: `claim()`, `claimHalfAndStake()`, `claimStakeRewards()`

---

### `AlreadyStaked()`

**Description**: Thrown when a caller attempts to stake again or has an active staking period.

**Triggered by**: `claim()`, `claimHalfAndStake()`

---

### `NotStaked()`

**Description**: Thrown when a caller attempts to claim staking rewards without having staked.

**Triggered by**: `claimStakeRewards()`

---

### `CanNotClaimNow()`

**Description**: Thrown when a caller attempts to claim staking rewards before the staking duration has elapsed.

**Triggered by**: `claimStakeRewards()`

---

## Usage Flow

### Standard Claim Flow

1. Owner calls `setEligibaleForClaim()` to whitelist addresses
2. Eligible user calls `claim()` to receive full airdrop immediately
3. User receives `airdropAmount` tokens

### Staking Flow

1. Owner calls `setEligibaleForClaim()` to whitelist addresses
2. Eligible user calls `claimHalfAndStake()` to:
   - Receive `airdropAmount / 2` tokens immediately
   - Lock remaining `airdropAmount / 2` for 1 day
3. After 1 day, user calls `claimStakeRewards()` to receive:
   - The remaining `airdropAmount / 2` (staked portion)
   - Reward of `airdropAmount / 2` (equal to the staked amount)
   - Total: `airdropAmount` tokens

## Important Notes

1. **One-Time Claim**: Each address can only claim once, either via `claim()` or `claimStakeRewards()` after staking
2. **Staking Duration**: Fixed at 1 day (86400 seconds)
3. **Staking Reward**: Users who stake receive double the amount (100% reward) after the staking period
4. **Eligibility**: Addresses must be whitelisted by the owner before they can claim
5. **Token Balance**: The contract must have sufficient token balance to fulfill all claims
6. **Owner Privileges**: The owner can withdraw tokens at any time, so ensure trust in the owner


## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

## License

MIT