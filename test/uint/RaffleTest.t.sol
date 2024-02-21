// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test,console} from "forge-std/Test.sol";
import {Raffle} from "../../src/Raffle.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";

contract RaffleTest is Test{
    /* Events */
    event EnteredRaffle(address indexed player);

    Raffle raffle;
    HelperConfig helperConfig;

    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gaslane;
    uint64 subscriptionId;
    uint32 callbackGasLimit;
    address link;

    address public PLAYER = makeAddr("player"); // 'makeAddr' one of standard cheats
    uint256 public constant STARTING_USER_BALANCE = 10 ether;
    
    function setUp() external{
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.run();
        (  entranceFee,
           interval,
           vrfCoordinator,
           gaslane,
           subscriptionId,
           callbackGasLimit,
           link             ) = helperConfig.activeNetworkConfig();

           vm.deal(PLAYER, STARTING_USER_BALANCE); // 'deal' cheat code to fund PLAYER with some funds
    }

    function testRaffleInitializesInOpenState() public view{ 
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);

    }

    /////////////////
    ///enterRaffle  /
    /////////////////
    function testRaffleRevertsWhenYouDontPayEnough() public {
         // Arrange
         vm.prank(PLAYER);
         //Act 
         vm.expectRevert(Raffle.Raffle__NotEnoughEthSent.selector);
         raffle.enterRaffle();
    }

    function testRaffleRecordsPlayerWhenTheyEnter() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        address playerRecorded = raffle.getPlayer(0);
        assert(playerRecorded == PLAYER);
    }

    function testEmitsEventOnEntrance() public {
        vm.prank(PLAYER);
        vm.expectEmit(true, false, false, false, address(raffle));
        emit EnteredRaffle(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }

    function testCantEnterWhenRaffleIsCalculating() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");

        vm.expectRevert(Raffle.Raffle__RaffelNotOpen.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }

    ///////////////////
    //checkUpkeep    //
    ///////////////////
    function testCheckUpkeepReturnsFalseIfIthasNoBalance() public {
      // Arrange
      vm.warp(block.timestamp + interval + 1);
      vm.roll(block.number + 1);
      
      // Act
      (bool upkeepNeeded, ) = raffle.checkUpKeep("");

      //assert
      assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsFalseIfRaffleNotOpen() public {
        // Arrange 
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");
        
        //Act 
        (bool upkeepNeeded, ) = raffle.checkUpKeep("");

        //Assert
        assert(upkeepNeeded == false);

    }


    /////////////////////
    // performUpkeep  ///
    /////////////////////

    function testPerformUpkeepCanOnlyRunIfCheckUpkeepIsTrue() public {
        // Arrange 
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        //Act / Assert
        raffle.performUpkeep("");
    }

    function testPerformUpkeepRevertsIfCheckUpkeepIsFalse() public {
      // Arrange  
      uint256 currentBalance = 0;
      uint256 numPlayers = 0;
      uint256 raffleState = 0;

      // Act / Assert
      vm.expectRevert(abi.encodeWithSelector(Raffle.Raffle__UpKeepNotNeeded.selector, currentBalance, numPlayers, raffleState));
      raffle.performUpkeep("");
    }

    modifier raffleEnterdAndTimePassed() {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _; 
    }

    // what if I need to test using the output of an event?
    function testPerformUpkeepUpdatesRaffleStateAndEmitsRequestId() public raffleEnterdAndTimePassed {
      // Act
      vm.recordLogs();
      raffle.performUpkeep(""); // emit requestId
      Vm.Log[] memory entries = vm.getRecordedLogs();
      bytes32 requestId = entries[1].topics[1];

      Raffle.RaffleState rState = raffle.getRaffleState();

      assert(uint256(requestId) > 0);
      assert(uint256(rState) == 1 );

    }

    ///////////////////////////
    // fulfillRandomWords    //
    ///////////////////////////

    modifier skipFork() {
        if(block.chainid != 31337){
            return;
        }
        _;
    }

    function testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep(uint256 randomReuestId) public raffleEnterdAndTimePassed skipFork{
         // Arrange
         vm.expectRevert("nonexistent request");
         VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(randomReuestId, address(raffle));

    }

}   




