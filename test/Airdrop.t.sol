// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {Airdrop} from "../src/Airdrop.sol";
import {TestERC20} from "./TestERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract AirdropTest is Test {
    Airdrop public airdrop;
    TestERC20 public testERC20;

    struct Entry {
        uint256 rank;
        address walletAddress;
    }

    function setUp() public {
        testERC20 = new TestERC20();
        airdrop = new Airdrop(address(testERC20), 10_000 * 10 ** 18);
        testERC20.transfer(address(airdrop), 8_000_000 * 10 ** 18);

        airdrop.setEligibaleForClaim(_getAddressList());
    }

    function test_constructor() public {
        assertEq(airdrop.token(), address(testERC20));
        assertEq(airdrop.airdropAmount(), 10_000 * 10 ** 18);
    }

    function test_setEligibaleForClaim() public {
        address[] memory addresses = _getAddressList();
        airdrop.setEligibaleForClaim(addresses);
        for (uint256 i = 0; i < addresses.length; i++) {
            assertEq(airdrop.isEligibaleForClaim(addresses[i]), true);
        }
    }

    function test_randomeAddressIsEligibaleForClaim() public {
        address randomAddress = address(4373829);
        assertEq(airdrop.isEligibaleForClaim(randomAddress), false);
    }

    function test_claim() public {
        address user = getAddressAtIndex(0);
        assertEq(testERC20.balanceOf(user), 0);
        assertEq(airdrop.hasClaimed(user), false);

        vm.prank(user);
        airdrop.claim(false); // User doesn't want to stake
        assertEq(airdrop.hasClaimed(user), true);
        assertEq(testERC20.balanceOf(user), 5_000 * 10 ** 18); // Half amount
    }

    function test_claimAgain() public {
        address user = getAddressAtIndex(0);
        vm.prank(user);
        airdrop.claim(false);
        vm.expectRevert(Airdrop.AlreadyClaimed.selector);
        vm.prank(user);
        airdrop.claim(false);
    }

    function test_claimNotEligibaleForClaim() public {
        address randomAddress = address(4373829);
        assertEq(airdrop.isEligibaleForClaim(randomAddress), false);
        vm.expectRevert(Airdrop.NotEligibaleForClaim.selector);
        vm.prank(randomAddress);
        airdrop.claim(false);
    }

    function testClaimAll() public {
        assertEq(testERC20.balanceOf(address(airdrop)), 8_000_000 * 10 ** 18);

        address[] memory addresses = _getAddressList();
        for (uint256 i = 0; i < addresses.length; i++) {
            assertEq(testERC20.balanceOf(addresses[i]), 0);
            assertEq(airdrop.hasClaimed(addresses[i]), false);

            vm.prank(addresses[i]);
            airdrop.claim(false); // Users don't want to stake

            assertEq(airdrop.hasClaimed(addresses[i]), true);
            assertEq(testERC20.balanceOf(addresses[i]), 5_000 * 10 ** 18); // Half amount

            vm.expectRevert(Airdrop.AlreadyClaimed.selector);
            vm.prank(addresses[i]);
            airdrop.claim(false);
        }
        // After 500 users claim half, contract should have: 8_000_000 - (500 * 5_000) = 5_500_000
        assertEq(testERC20.balanceOf(address(airdrop)), 5_500_000 * 10 ** 18);
    }

    function test_claimAndStake() public {
        address user = getAddressAtIndex(0);
        assertEq(airdrop.totalUserStaked(), 0);
        uint256 halfAmount = airdrop.airdropAmount() / 2;

        vm.warp(1_000);
        vm.prank(user);
        airdrop.claim(true); // User wants to stake
        assertEq(airdrop.hasClaimed(user), true);
        assertEq(airdrop.wantsToStake(user), true);
        assertEq(testERC20.balanceOf(user), halfAmount);

        vm.prank(user);
        airdrop.stake();

        assertEq(airdrop.hasStaked(user), true);
        assertEq(airdrop.totalUserStaked(), 1);
        assertEq(airdrop.totalTokensStaked(), halfAmount);
        assertEq(airdrop.stakingUnlockTime(user), 1_000 + 1 days);

        vm.expectRevert(Airdrop.AlreadyStaked.selector);
        vm.prank(user);
        airdrop.stake();
    }

    function test_stakeWithoutClaimingReverts() public {
        address randomAddress = address(123456);
        vm.expectRevert(Airdrop.NotClaimed.selector);
        vm.prank(randomAddress);
        airdrop.stake();
    }

    function test_stakeWithoutWantingToStakeReverts() public {
        address user = getAddressAtIndex(0);
        vm.prank(user);
        airdrop.claim(false); // User doesn't want to stake

        vm.expectRevert(Airdrop.DoesNotWantToStake.selector);
        vm.prank(user);
        airdrop.stake();
    }

    function test_unstakeSuccess() public {
        address user = getAddressAtIndex(1);
        uint256 halfAmount = airdrop.airdropAmount() / 2;
        // User receives half from claim, then full airdrop from unstake (half staked + half rewards)
        uint256 expectedTotal = halfAmount + airdrop.airdropAmount(); // 1.5x airdrop amount

        vm.warp(5_000);
        vm.prank(user);
        airdrop.claim(true); // User wants to stake
        assertEq(testERC20.balanceOf(user), halfAmount);

        vm.prank(user);
        airdrop.stake();
        assertEq(airdrop.totalTokensStaked(), halfAmount);

        vm.warp(5_000 + 1 days + 1);
        vm.prank(user);
        airdrop.unstake();

        assertEq(airdrop.hasUnstaked(user), true);
        assertEq(testERC20.balanceOf(user), expectedTotal); // Half from claim + full from unstake
    }

    function test_unstakeBeforeUnlockReverts() public {
        address user = getAddressAtIndex(2);

        vm.prank(user);
        airdrop.claim(true);
        vm.prank(user);
        airdrop.stake();

        vm.expectRevert(Airdrop.CanNotUnstakeNow.selector);
        vm.prank(user);
        airdrop.unstake();
    }

    function test_unstakeWithoutStakeReverts() public {
        address randomAddress = address(999_999);
        vm.expectRevert(Airdrop.NotStaked.selector);
        vm.prank(randomAddress);
        airdrop.unstake();
    }

    function test_unstakeMultipleTimesReverts() public {
        address user = getAddressAtIndex(3);
        uint256 halfAmount = airdrop.airdropAmount() / 2;
        uint256 initialBalance = testERC20.balanceOf(user);

        vm.warp(10_000);
        vm.prank(user);
        airdrop.claim(true); // User wants to stake
        assertEq(testERC20.balanceOf(user), initialBalance + halfAmount);

        vm.prank(user);
        airdrop.stake();
        assertEq(airdrop.totalTokensStaked(), halfAmount);

        vm.warp(10_000 + 1 days + 1);
        vm.prank(user);
        airdrop.unstake();

        uint256 balanceAfterFirstUnstake = testERC20.balanceOf(user);
        assertEq(airdrop.hasUnstaked(user), true); // Should be set to true after unstaking

        // Try to unstake again - should revert
        vm.expectRevert(Airdrop.AlreadyUnstaked.selector);
        vm.prank(user);
        airdrop.unstake();

        // Try to stake again - should revert because hasUnstaked is true
        vm.expectRevert(Airdrop.AlreadyUnstaked.selector);
        vm.prank(user);
        airdrop.stake();

        // Verify balance hasn't changed
        assertEq(testERC20.balanceOf(user), balanceAfterFirstUnstake);
    }

    function test_withdrawByOwner() public {
        uint256 amount = 500 * 10 ** 18;
        uint256 ownerBalanceBefore = testERC20.balanceOf(address(this));
        uint256 contractBalanceBefore = testERC20.balanceOf(address(airdrop));

        airdrop.withdraw(address(testERC20), amount);

        assertEq(testERC20.balanceOf(address(this)), ownerBalanceBefore + amount);
        assertEq(testERC20.balanceOf(address(airdrop)), contractBalanceBefore - amount);
    }

    function test_withdrawByNonOwnerReverts() public {
        uint256 amount = 100 * 10 ** 18;
        address attacker = address(8888);

        vm.prank(attacker);
        vm.expectRevert();
        airdrop.withdraw(address(testERC20), amount);
    }

    function _getAddressList() internal view returns (address[] memory) {
        // Read and parse the JSON list at script/top-500-nov5.json
        string memory jsonPath = string.concat(vm.projectRoot(), "/script/top-500-nov5.json");
        string memory json = vm.readFile(jsonPath);

        // Decode JSON array into Entry[] then extract addresses
        Entry[] memory entries = abi.decode(vm.parseJson(json, "."), (Entry[]));
        address[] memory addresses = new address[](entries.length);
        for (uint256 i = 0; i < entries.length; i++) {
            addresses[i] = entries[i].walletAddress;
        }
        return addresses;
    }

    function getAddressAtIndex(uint256 index) internal view returns (address) {
        // Read and parse the JSON list at script/top-500-nov5.json
        string memory jsonPath = string.concat(vm.projectRoot(), "/script/top-500-nov5.json");
        string memory json = vm.readFile(jsonPath);

        // Decode JSON array into Entry[] then extract addresses
        Entry[] memory entries = abi.decode(vm.parseJson(json, "."), (Entry[]));

        return entries[index].walletAddress;
    }
}
