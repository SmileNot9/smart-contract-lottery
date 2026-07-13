// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Raffle} from "src/Raffle.sol";
import {Test, console} from "forge-std/Test.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {HelperConfig, CodeConstants} from "script/HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "lib/chainlink-evm/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {Vm} from "forge-std/Vm.sol";

contract RaffleTest is Test, CodeConstants {
    Raffle public raffle;
    HelperConfig public helperConfig;

    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint256 subscriptionId;
    uint32 callbackGasLimit;

    address public PLAYER = makeAddr("testPlayer");
    uint256 public constant STARTING_BALANCE = 1 ether;

    /* Events */
    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);

    function setUp() external {
        DeployRaffle deploy = new DeployRaffle();
        (raffle, helperConfig) = deploy.deployContract();
        HelperConfig.NetworkConfig memory networkConfig = helperConfig.getConfig();
        entranceFee = networkConfig.entranceFee;
        interval = networkConfig.interval;
        vrfCoordinator = networkConfig.vrfCoordinator;
        gasLane = networkConfig.gasLane;
        subscriptionId = networkConfig.subscriptionId;
        callbackGasLimit = networkConfig.callbackGasLimit;

        vm.deal(PLAYER, STARTING_BALANCE);
    }

    modifier raffleEntered() {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    modifier skipFork() {
        if (block.chainid != LOCAL_CHAIN_ID) {
            return;
        }
        _;
    }

    function testRaffleStateInitializesIsOpen() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    /*//////////////////////////////////////////////////////////////
                                ENTER RAFFLE
    //////////////////////////////////////////////////////////////*/
    function testRaffleRevertsWhenNotEnoughtETH() public {
        // Arrange
        vm.prank(PLAYER);

        // Act / Assert
        vm.expectRevert(Raffle.Raffle__NotEnoughETHEntered.selector);
        raffle.enterRaffle();
    }

    function testRaffleRecordsPlayersWhenTheyEnter() public {
        // Arrange
        vm.prank(PLAYER);

        // Act
        raffle.enterRaffle{value: entranceFee}();

        // Assert
        assert(raffle.getPlayer(0) == PLAYER);
    }

    function testEnterRaffleEmitsEvent() public {
        // Arrange
        vm.prank(PLAYER);

        // Act / Assert
        vm.expectEmit(true, false, false, false, address(raffle));
        emit RaffleEntered(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }

    function testRaffleRevertsWhenNotOpen() public raffleEntered {
        // Arrange
        raffle.performUpkeep("");

        // Act / Assert
        vm.prank(PLAYER);
        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        raffle.enterRaffle{value: entranceFee}();
    }

    /*//////////////////////////////////////////////////////////////
                            CHECK UPKEEP
    //////////////////////////////////////////////////////////////*/
    function testCheckUpkeepReturnsFalseIfItHasNoBalance() public {
        // Arrange
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        // Act
        (bool upkeepNeeded,) = raffle.checkUpkeep("");

        // Assert
        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsFalseIfRaffleIsntOpen() public raffleEntered {
        // Arrange
        raffle.performUpkeep("");

        // Act
        (bool upkeepNeeded,) = raffle.checkUpkeep("");

        // Assert
        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsFalseIfEnoughTimeHasPassed() public {
        // Arrange
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        //Act
        (bool upkeepNeeded,) = raffle.checkUpkeep("");

        // Assert
        assert(!upkeepNeeded);
    }

    /*//////////////////////////////////////////////////////////////
                            PERFORM UPKEEP
    //////////////////////////////////////////////////////////////*/
    function testPerformUpkeepCanOnlyRunIfCheckUpIsTrue() public raffleEntered {
        // Act / Assert
        raffle.performUpkeep("");
    }

    function testPerformUpkeepRevertIfCheckUpkeepIsFalse() public {
        // Act / Assert
        vm.expectPartialRevert(Raffle.Raffle__UpkeepNotNeeded.selector);
        raffle.performUpkeep("");
    }

    function testPerformUpkeepUpdatesRaffleStateAndEmitsRequestId() public raffleEntered {
        // Act
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        // Assert
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        assert(uint256(requestId) > 0);
        assert(raffle.getRaffleState() == Raffle.RaffleState.CALCULATING);
    }

    /*//////////////////////////////////////////////////////////////
                            FULFILL RANDOM WORDS
    //////////////////////////////////////////////////////////////*/
    function testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep(uint256 randomRequestId)
        public
        raffleEntered
        skipFork
    {
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(randomRequestId, address(raffle));
    }

    function testFulfillRandomWordsRevertsWhenNotCalculating() public {
        // Arrange
        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = 0;

        // Act / Assert
        vm.expectRevert(Raffle.Raffle__NotCalculating.selector);
        vm.prank(vrfCoordinator);
        raffle.rawFulfillRandomWords(1, randomWords);
    }

    function testFulfillRandomWordsRevertsWhenTransferFails() public {
        // Arrange
        RejectEther rejectEther = new RejectEther();
        vm.deal(address(rejectEther), STARTING_BALANCE);
        rejectEther.enterRaffle(address(raffle));
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");

        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = 0;

        // Act / Assert
        vm.expectRevert(Raffle.Raffle__TransferFailed.selector);
        vm.prank(vrfCoordinator);
        raffle.rawFulfillRandomWords(1, randomWords);
    }

    function testFulfillRandomWordsUpdatesRaffleStateAndEmitsWinnerPicked() public raffleEntered {
        // Arrange
        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = 0;

        raffle.performUpkeep("");
        vm.prank(vrfCoordinator);

        // Act
        vm.recordLogs();
        raffle.rawFulfillRandomWords(1, randomWords);
        Vm.Log[] memory emittedLogs = vm.getRecordedLogs();

        // Assert
        bytes32 winnerPickedEventTopic = emittedLogs[0].topics[1];
        address recentWinner = raffle.getRecentWinner();
        assert(winnerPickedEventTopic == bytes32(uint256(uint160(recentWinner))));
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    function testFulfillRandomWordsPicksAWinnerResetsAndSendsMoney() public raffleEntered skipFork {
        // Arrange
        uint256 additionalEntrants = 3; // 4 total
        uint256 startingIndex = 1; // 0 is for PLAYER
        address expectedWinner = address(1);

        for (uint256 i = startingIndex; i < startingIndex + additionalEntrants; i++) {
            address newPlayer = address(uint160(i));
            hoax(newPlayer, STARTING_BALANCE);
            raffle.enterRaffle{value: entranceFee}();
        }

        VRFCoordinatorV2_5Mock(vrfCoordinator).fundSubscriptionWithNative{value: 3 ether}(subscriptionId);

        uint256 startingTimeStamp = raffle.getLastTimeStamp();
        uint256 winnerStartingBalance = expectedWinner.balance;

        // Act
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(uint256(requestId), address(raffle));

        // Assert
        address recentWinner = raffle.getRecentWinner();
        uint256 winnerBalance = recentWinner.balance;
        uint256 endingLastTimeStamp = raffle.getLastTimeStamp();
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        uint256 prize = entranceFee * (additionalEntrants + 1);

        assert(recentWinner == expectedWinner);
        assert(winnerBalance == winnerStartingBalance + prize);
        assert(endingLastTimeStamp > startingTimeStamp);
        assert(raffleState == Raffle.RaffleState.OPEN);
    }

    /*//////////////////////////////////////////////////////////////
                            GETTERS
    //////////////////////////////////////////////////////////////*/
    function testGetEntranceFeeReturnsCorrectValue() public view {
        assert(raffle.getEntranceFee() == entranceFee);
    }

    function testGetRecentWinnerReturnsCorrectPlayer() public raffleEntered skipFork {
        // Arrange
        VRFCoordinatorV2_5Mock(vrfCoordinator).fundSubscriptionWithNative{value: 3 ether}(subscriptionId);

        // Act
        raffle.checkUpkeep("");
        raffle.performUpkeep("");
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(1, address(raffle));

        // Assert
        assert(address(PLAYER) == raffle.getRecentWinner());
    }

    function testGetPlayersReturnsCorrectValue() public raffleEntered {
        // Act
        raffle.enterRaffle{value: entranceFee}();

        // Assert
        assert(raffle.getPlayer(0) == PLAYER);
    }

    function testGetLastTimeStampReturnsCorrectValue() public {
        // Act
        uint256 lastTimeStamp = raffle.getLastTimeStamp();

        // Assert
        assert(lastTimeStamp == block.timestamp);
    }
}

contract RejectEther {
    // no receive/fallback — this is what makes it reject ETH

    function enterRaffle(address raffle) external {
        Raffle(raffle).enterRaffle{value: 1 ether}();
    }
}
