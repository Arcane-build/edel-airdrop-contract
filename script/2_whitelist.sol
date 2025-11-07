// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";
import {Script} from "forge-std/Script.sol";

import {Airdrop} from "../src/Airdrop.sol";

contract Deploy is Script {
    struct Entry {
        uint256 rank;
        address walletAddress;
    }

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        address airdropContractAddress = 0x0000000000000000000000000000000000000000;
        Airdrop airdrop = Airdrop(airdropContractAddress);

        // Read and parse the JSON list at script/top-500-nov5.json
        string memory jsonPath = string.concat(vm.projectRoot(), "/script/top-500-nov5.json");
        string memory json = vm.readFile(jsonPath);

        // Decode JSON array into Entry[] then extract addresses
        Entry[] memory entries = abi.decode(vm.parseJson(json, "."), (Entry[]));
        address[] memory addresses = new address[](entries.length);
        for (uint256 i = 0; i < entries.length; i++) {
            addresses[i] = entries[i].walletAddress;
            console2.log("Address", i, ":", addresses[i]);
        }

        console2.log(addresses.length);

        vm.startBroadcast(deployerPrivateKey);

        // airdrop.setEligibaleForClaim(addresses);

        vm.stopBroadcast();
    }
}

// forge script script/2_whitelist.sol:Deploy --rpc-url https://1rpc.io/base --private-key $PRIVATE_KEY --broadcast
