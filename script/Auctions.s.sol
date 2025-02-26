// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {Auctions} from "../src/Auctions.sol";

contract AuctionsScript is Script {
    Auctions public auctions;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        // auctions = new Auctions();

        vm.stopBroadcast();
    }
}
