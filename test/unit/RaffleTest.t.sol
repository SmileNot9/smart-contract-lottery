// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Raffle} from "src/Raffle.sol";
import {Test, console} from "forge-std/Test.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "lib/chainlink-evm/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

contract RaffleTest is Test {
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

    function testRaffleRevertsWhenNotOpen() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
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

    function testCheckUpkeepReturnsFalseIfRaffleIsntOpen() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");

        // Act
        (bool upkeepNeeded,) = raffle.checkUpkeep("");

        // Assert
        assert(!upkeepNeeded);
    }

    /*//////////////////////////////////////////////////////////////
                            PERFORM UPKEEP
    //////////////////////////////////////////////////////////////*/
    function testPerformUpkeepCanOnlyRunIfCheckUpIsTrue() public {
        // Arrange
        vm.prank(PLAYER);

        // Act / Assert
        vm.expectPartialRevert(Raffle.Raffle__UpkeepNotNeeded.selector);
        raffle.performUpkeep("");
    }

    /*//////////////////////////////////////////////////////////////
                            FULFILL RANDOMWORDS
    //////////////////////////////////////////////////////////////*/

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

    function testFulfillRandomWordsRevertsWhenNotCalculating() public {
        // Arrange
        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = 0;

        // Act / Assert
        vm.expectRevert(Raffle.Raffle__NotCalculating.selector);
        vm.prank(vrfCoordinator);
        raffle.rawFulfillRandomWords(1, randomWords);
    }

    /*//////////////////////////////////////////////////////////////
                            GETTERS
    //////////////////////////////////////////////////////////////*/
    function testGetEntranceFeeReturnsCorrectValue() public view {
        assert(raffle.getEntranceFee() == entranceFee);
    }

    function testGetRecentWinnerReturnsCorrectPlayer() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fundSubscriptionWithNative{value: 3 ether}(subscriptionId);

        // Act
        raffle.checkUpkeep("");
        raffle.performUpkeep("");
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(1, address(raffle));

        // Assert
        assert(address(PLAYER) == raffle.getRecentWinner());
    }

    function testGetPlayersReturnsCorrectValue() public {
        // Arrange
        vm.prank(PLAYER);

        // Act
        raffle.enterRaffle{value: entranceFee}();

        // Assert
        assert(raffle.getPlayer(0) == PLAYER);
    }
}

contract RejectEther {
    // no receive/fallback — this is what makes it reject ETH

    function enterRaffle(address raffle) external {
        Raffle(raffle).enterRaffle{value: 1 ether}();
    }
}
