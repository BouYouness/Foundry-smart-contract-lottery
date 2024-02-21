// SPDX-License-Identifier: MIT

import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "../test/uint/mocks/LinkToken.sol";

pragma solidity ^0.8.18;

contract HelperConfig is Script {
    struct NetworkConfig {
        uint256 entranceFee;
        uint256 interval;
        address vrfCoordinator;
        bytes32 gaslane;
        uint64 subscriptionId;
        uint32 callbackGasLimit;
        address link;
    }

    NetworkConfig public activeNetworkConfig;

    constructor(){
        if(block.chainid == 5 /* georli chain id */){
           activeNetworkConfig = getGeorliEthConfig();
        }else { activeNetworkConfig = getOrCreateAnvilEthConfig();}
    }

    function getGeorliEthConfig() public pure returns (NetworkConfig memory){
        return NetworkConfig({
            entranceFee: 0.01 ether,
            interval:30,
            vrfCoordinator:0x2Ca8E0C643bDe4C2E08ab1fA0da3401AdAD7734D,
            gaslane:0x79d3d8832d904592c0bf9818b621522c988bb8b0c05cdc3b15aea1b6e8db0c15,
            subscriptionId:0, // Update this with our subId!
            callbackGasLimit:500000,
            link:0x326C977E6efc84E512bB9C30f76E30c160eD06FB
        });
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory){
      if (activeNetworkConfig.vrfCoordinator != address(0)){
        return activeNetworkConfig;
      }

      uint96 baseFee = 0.025 ether; // 0.25 LINNK
      uint96 gasPriceLink = 1e9; // 1 gwei LINK 

      vm.startBroadcast();
      VRFCoordinatorV2Mock vrfCoordinatorMock = new VRFCoordinatorV2Mock(baseFee, gasPriceLink);
      LinkToken link = new LinkToken();
      vm.stopBroadcast();

        return NetworkConfig({
        entranceFee: 0.01 ether,
        interval:30,
        vrfCoordinator:address(vrfCoordinatorMock),
        gaslane:0x79d3d8832d904592c0bf9818b621522c988bb8b0c05cdc3b15aea1b6e8db0c15,
        subscriptionId:0, // our script will add this!
        callbackGasLimit:500000, //500,000 gas!
        link: address(link)
        });  

    }
}