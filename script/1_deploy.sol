// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";
import {Script} from "forge-std/Script.sol";

import {Airdrop} from "../src/Airdrop.sol";

contract Deploy is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address token = 0x0000000000000000000000000000000000000000;
        uint256 airdropAmount = 10_000 * 10 ** 18;

        Airdrop airdrop = new Airdrop(token, airdropAmount);
        console2.log("Airdrop deployed to:", address(airdrop));

        vm.stopBroadcast();
    }
}

// forge script script/1_Deploy.sol:Deploy \
//   --rpc-url https://1rpc.io/base \
//   --private-key $PRIVATE_KEY \
//   --broadcast \
//   --verify \
//   --verifier etherscan \
//   --chain 56 \
//   --etherscan-api-key 83H94GSKM9MBM3BKI1URPQAE5VN4U5XEVC
