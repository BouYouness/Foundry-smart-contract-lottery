// SPDX-License-Identifier:MIT

pragma solidity ^0.8.18;

import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

/** 
* @title A sample Raffle Contract
* @author Youness
* @notice This contract is for creating a sample raffle 
* @dev Implement Chainlink VRFv2
 */

contract Raffle is VRFConsumerBaseV2 {

   error Raffle__NotEnoughEthSent();
   error Raffle__NotEnoughTimePass();
   error Raffle__TransferFailed();
   error Raffle__RaffelNotOpen();
   error Raffle__UpKeepNotNeeded(uint256 currentBalance, uint256 numPlayers,uint256 raffleState);

   /** Type declarations  */
    enum RaffleState{
    OPEN, // state 0
    CALCULATING // state 1
    } 

   /** State Variables */
   uint16 private constant REQUEST_CONFIRMATIONS = 3; // all in upercase because its constant and more gas efficiant
   uint32 private constant NUM_WORDS = 1;

   
   uint256 private immutable i_entranceFee;
   VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
   bytes32 private immutable i_gaslane;
   uint64 private immutable i_subscriptionId;
   uint32 private immutable i_callbackGasLimit;
   // duration of the lottery in seconds
   uint256 private immutable i_interval; // immutable mean not changing
   uint256 private s_lastTimeStamp;

   address payable[] private s_players;
   address private s_recentWinner;

   RaffleState private s_raffleState;

   //Events
   event EnteredRaffle(address indexed player);
   event PickedWinner(address indexed winner);
   event RequestedRaffleWinner(uint256 indexed requestId);

   constructor(uint256 entranceFee, uint256 interval, address vrfCoordinator,bytes32 gaslane,uint64 subscriptionId,uint32 callbackGasLimit)VRFConsumerBaseV2(vrfCoordinator){
        i_entranceFee = entranceFee;
        i_interval = interval;
        s_lastTimeStamp=block.timestamp;
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinator);
        i_gaslane = gaslane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
        s_raffleState =RaffleState.OPEN;
    }

   function enterRaffle() external payable {
     //require(msg.value >= i_entranceFee,"more eth required");
     if (msg.value < i_entranceFee){
        revert Raffle__NotEnoughEthSent(); // more gas efficient than require
     }

     if(s_raffleState != RaffleState.OPEN) {
      revert Raffle__RaffelNotOpen();
     }

     s_players.push(payable(msg.sender));

     emit EnteredRaffle(msg.sender);
   }
      // when is the winner supposed to be picked?
      /**
       * @dev this is the function that the chainlink Automation nodes call
       * to see if it's time to perform an upkeep.
       * the following should be true for this to return true:
       * 1. the time interval ha passed between raffle runs 
       * 2. the raffle is in the open state 
       * 3. the contract has ETH (aka, players)
       * 4. (Implicit) The subscripton is funded with LINK 
      */
     function checkUpKeep(bytes memory) public view returns (bool upkeepNeeded, bytes memory /** performData */) {
       // check to see if enough time has passed 
       bool timeHasPassed = (block.timestamp - s_lastTimeStamp) >= i_interval;
       bool isOpen = RaffleState.OPEN == s_raffleState;
       bool hasBalance = address(this).balance > 0;
       bool hasplayers = s_players.length > 0;
       upkeepNeeded = (timeHasPassed && isOpen && hasBalance && hasplayers);
       return ( upkeepNeeded, "0x0"); // 0x0 means blank bytes object
     }

    function performUpkeep(bytes calldata) external {

     (bool upKeepNeeded, ) = checkUpKeep("");   
     if (!upKeepNeeded) { revert Raffle__UpKeepNotNeeded(
        address(this).balance,
        s_players.length,
        uint256(s_raffleState)
      );
     }

     // check to see if enough time has passed
     s_raffleState = RaffleState.CALCULATING;

         uint256 requestId = i_vrfCoordinator.requestRandomWords(
          i_gaslane, //gas lane
          i_subscriptionId, // our specific subscreption to the shainlink vrf
          REQUEST_CONFIRMATIONS, // number of block confirmation for ur random number
          i_callbackGasLimit, // to make sure we don't overspend on this call 
          NUM_WORDS // number of random numbers
        );
        
        emit RequestedRaffleWinner(requestId);
    }
     
    function fulfillRandomWords(uint256 /*requestId*/,uint256[] memory randomWords) internal override{
      uint256 indexOfWinner = randomWords[0] % s_players.length;
      address payable winner = s_players[indexOfWinner];

      s_recentWinner = winner;
      s_raffleState = RaffleState.OPEN;

      s_players = new address payable[](0);
      s_lastTimeStamp = block.timestamp;

      (bool success,) = s_recentWinner.call{value:address(this).balance}("");
      if(!success){ revert Raffle__TransferFailed(); }

      emit PickedWinner(s_recentWinner);
    }

   // Getter Function
   function getEntranceFee() external view returns(uint256){
    return i_entranceFee;
   }

   function getRaffleState() external view returns (RaffleState) {
    return s_raffleState;
   }

   function getPlayer(uint256 indexOfPlayer) external view returns (address){
    return s_players[indexOfPlayer];
   }

}
