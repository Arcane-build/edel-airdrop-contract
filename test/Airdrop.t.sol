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
        airdrop.claim();
        assertEq(airdrop.hasClaimed(user), true);
        assertEq(testERC20.balanceOf(user), 10_000 * 10 ** 18);
    }

    function test_claimAgain() public {
        address user = getAddressAtIndex(0);
        vm.prank(user);
        airdrop.claim();
        vm.expectRevert(Airdrop.AlreadyClaimed.selector);
        vm.prank(user);
        airdrop.claim();
    }

    function test_claimNotEligibaleForClaim() public {
        address randomAddress = address(4373829);
        assertEq(airdrop.isEligibaleForClaim(randomAddress), false);
        vm.expectRevert(Airdrop.NotEligibaleForClaim.selector);
        vm.prank(randomAddress);
        airdrop.claim();
    }

    function testClaimAll() public {
        assertEq(testERC20.balanceOf(address(airdrop)), 8_000_000 * 10 ** 18);

        address[] memory addresses = _getAddressList();
        for (uint256 i = 0; i < addresses.length; i++) {
            assertEq(testERC20.balanceOf(addresses[i]), 0);
            assertEq(airdrop.hasClaimed(addresses[i]), false);

            vm.prank(addresses[i]);
            airdrop.claim();

            assertEq(airdrop.hasClaimed(addresses[i]), true);
            assertEq(testERC20.balanceOf(addresses[i]), 10_000 * 10 ** 18);

            vm.expectRevert(Airdrop.AlreadyClaimed.selector);
            vm.prank(addresses[i]);
            airdrop.claim();
        }
        assertEq(testERC20.balanceOf(address(airdrop)), 3_000_000 * 10 ** 18);
    }

    function test_claimHalfAndStake() public {
        address user = getAddressAtIndex(0);
        assertEq(airdrop.totalUserStaked(), 0);
        uint256 halfAmount = airdrop.airdropAmount() / 2;

        vm.warp(1_000);
        vm.prank(user);
        airdrop.claimHalfAndStake();

        assertEq(airdrop.hasStaked(user), true);
        assertEq(airdrop.hasClaimed(user), false);
        assertEq(airdrop.totalUserStaked(), 1);
        assertEq(testERC20.balanceOf(user), halfAmount);
        assertEq(airdrop.stakingUnlockTime(user), 1_000 + 1 days);

        vm.expectRevert(Airdrop.AlreadyStaked.selector);
        vm.prank(user);
        airdrop.claimHalfAndStake();
    }

    function test_claimHalfAndStakeNotEligible() public {
        address randomAddress = address(123456);
        vm.expectRevert(Airdrop.NotEligibaleForClaim.selector);
        vm.prank(randomAddress);
        airdrop.claimHalfAndStake();
    }

    function test_claimStakeRewardsSuccess() public {
        address user = getAddressAtIndex(1);
        uint256 halfAmount = airdrop.airdropAmount() / 2;
        uint256 expectedTotal = airdrop.airdropAmount() + halfAmount;

        vm.warp(5_000);
        vm.prank(user);
        airdrop.claimHalfAndStake();
        assertEq(testERC20.balanceOf(user), halfAmount);

        vm.warp(5_000 + 1 days + 1);
        vm.prank(user);
        airdrop.claimStakeRewards();

        assertEq(airdrop.hasClaimed(user), true);
        assertEq(testERC20.balanceOf(user), expectedTotal);
    }

    function test_claimStakeRewardsBeforeUnlockReverts() public {
        address user = getAddressAtIndex(2);

        vm.prank(user);
        airdrop.claimHalfAndStake();

        vm.expectRevert(Airdrop.CanNotClaimNow.selector);
        vm.prank(user);
        airdrop.claimStakeRewards();
    }

    function test_claimStakeRewardsWithoutStakeReverts() public {
        address randomAddress = address(999_999);
        vm.expectRevert(Airdrop.NotStaked.selector);
        vm.prank(randomAddress);
        airdrop.claimStakeRewards();
    }

    function test_claimStakeRewardsAfterClaimReverts() public {
        address user = getAddressAtIndex(3);

        vm.prank(user);
        airdrop.claimHalfAndStake();

        vm.warp(block.timestamp + 1 days + 1);
        vm.prank(user);
        airdrop.claimStakeRewards();

        vm.expectRevert(Airdrop.AlreadyClaimed.selector);
        vm.prank(user);
        airdrop.claimStakeRewards();
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
