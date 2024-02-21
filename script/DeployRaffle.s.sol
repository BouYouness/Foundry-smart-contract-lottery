// SPDX-License-Identifier: MIT

import {Script} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {CreateSubscription,FundSubscription, AddConsumer} from "./Interactions.s.sol";

pragma solidity ^0.8.18;

contract DeployRaffle is Script {
  
  function run() external returns (Raffle, HelperConfig) {
    HelperConfig helperConfig = new HelperConfig();
     (   uint256 entranceFee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 gaslane,
        uint64 subscriptionId,
        uint32 callbackGasLimit,
        address link ) = helperConfig.activeNetworkConfig();

    if(subscriptionId == 0){
      // we need to create a subscription!
      CreateSubscription createSubscription = new CreateSubscription();
      subscriptionId = createSubscription.createSubscription(vrfCoordinator);

      // Fund it!
      FundSubscription fundSubsription = new FundSubscription();
      fundSubsription.fundSubscription(vrfCoordinator, subscriptionId, link);
    }  

    vm.startBroadcast();
     Raffle raffle = new Raffle(
      entranceFee,
      interval,
      vrfCoordinator,
      gaslane,
      subscriptionId,
      callbackGasLimit
     );
    vm.stopBroadcast();

    AddConsumer addConsumer = new AddConsumer();
    addConsumer.addConsumer(address(raffle), vrfCoordinator, subscriptionId);
    return (raffle,helperConfig);
  }
}