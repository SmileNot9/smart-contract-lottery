// Layout of Contract:
// license
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// internal & private view & pure functions
// external & public view & pure functions

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

/**
 * @title A sample Raffle Contract
 * @author :):
 * @notice Contract that creates a sample raffle using ChainLink VRF
 * @dev It implements Chainlink VRFv2.5
 */
contract Raffle is VRFConsumerBaseV2Plus {
    /* Errors */
    error Raffle__NotEnoughETHEntered();
    error Raffle__TransferFailed();
    error Raffle__RaffleNotOpen();
    error Raffle__UpkeepNotNeeded(uint256 remainingTime, RaffleState currentState, uint256 balance, uint256 numPlayers);

    /* Type declarations */
    enum RaffleState {
        OPEN, // 0
        CALCULATING // 1
    }

    /* State variables */
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;
    uint256 private immutable I_ENTRANCE_FEE;
    uint256 private immutable I_INTERVAL;
    bytes32 private immutable I_KEY_HASH;
    uint256 private immutable I_SUBSCRIPTION_ID;
    uint32 private immutable I_CALLBACK_GAS_LIMIT;
    uint256 private s_lastTimeStamp;
    address payable[] private s_players;
    address private s_recentWinner;
    RaffleState private s_raffleState;

    /* Events */
    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);

    constructor(
        uint256 _entraceFee,
        uint256 _interval,
        address _vrfCoordinator,
        bytes32 _gasLane,
        uint256 _subscriptionId,
        uint32 _callbackGasLimit
    ) VRFConsumerBaseV2Plus(_vrfCoordinator) {
        I_ENTRANCE_FEE = _entraceFee;
        I_INTERVAL = _interval;
        I_KEY_HASH = _gasLane;
        I_SUBSCRIPTION_ID = _subscriptionId;
        I_CALLBACK_GAS_LIMIT = _callbackGasLimit;

        s_lastTimeStamp = block.timestamp;
        s_raffleState = RaffleState.OPEN; // or: s_raffleState = RaffleState(0);
    }

    function enterRaffle() external payable {
        //Checks (require, condicionals, etc)
        // require(msg.value >= entraceFee, "Not enough ETH");
        // This version ⭣⭣⭣ more gas efficient than ⭡⭡⭡
        if (msg.value < I_ENTRANCE_FEE) {
            revert Raffle__NotEnoughETHEntered();
        }
        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__RaffleNotOpen();
        }

        // Effects (Internal Contract State changes)
        s_players.push(payable(msg.sender));
        emit RaffleEntered(msg.sender);
    }

    // When should the winner be picked?
    /**
     * @dev This is the function that the Chainlink nodes will check
     * to see if the lottery is ready to look for a winner.
     * The following should be true for this to return true:
     * 1. The time interval has passed between raffle runs.
     * 2. The lottery is open.
     * 3. The contract has ETH (= has players).
     * 4. Implicity, your subscription is funded with LINK.
     * @param - ignored (null)
     * @return unkeepNeeded true if it's time to restart the lottery
     * @return - ignored (null)
     */
    function checkUpkeep(
        bytes memory /* checkData */
    )
        public
        view
        returns (
            bool unkeepNeeded,
            bytes memory /* performData */
        )
    {
        bool timeHasPassed = ((block.timestamp - s_lastTimeStamp) >= I_INTERVAL);
        bool lotteryIsOpen = s_raffleState == RaffleState.OPEN;
        bool hasEth = address(this).balance > 0;
        bool hasPlayers = s_players.length > 0;
        unkeepNeeded = timeHasPassed && lotteryIsOpen && hasEth && hasPlayers;
        return (unkeepNeeded, bytes(""));
    }

    function performUpkeep(
        bytes calldata /* performData */
    )
        external
    {
        // Checks (require, condicionals, etc)
        (bool upkeepNeeded,) = checkUpkeep(bytes(""));
        if (!upkeepNeeded) {
            uint256 timeSinceLastRun = block.timestamp - s_lastTimeStamp;
            revert Raffle__UpkeepNotNeeded(
                (I_INTERVAL - timeSinceLastRun), s_raffleState, address(this).balance, s_players.length
            );
        }

        // Effects (Internal Contract State changes)
        s_raffleState = RaffleState.CALCULATING;

        VRFV2PlusClient.RandomWordsRequest memory request = VRFV2PlusClient.RandomWordsRequest({
            keyHash: I_KEY_HASH,
            subId: I_SUBSCRIPTION_ID,
            requestConfirmations: REQUEST_CONFIRMATIONS,
            callbackGasLimit: I_CALLBACK_GAS_LIMIT,
            numWords: NUM_WORDS,
            // Set nativePayment to true to pay for VRF requests with Sepolia ETH instead of LINK
            extraArgs: VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: true}))
        });

        // Interactions (External Contract Interactions)
        s_vrfCoordinator.requestRandomWords(request);
    }

    // CEI: Checks-Effects-Interactions pattern
    function fulfillRandomWords(
        uint256,
        /* requestId */
        uint256[] calldata randomWords
    )
        internal
        override
    {
        // Checks (require, condicionals, etc)

        // Effects (Internal Contract State changes)
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable recentWinner = s_players[indexOfWinner];
        s_recentWinner = recentWinner;
        emit WinnerPicked(s_recentWinner);

        s_raffleState = RaffleState.OPEN;
        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;

        // Interactions (External Contract Interactions)
        (bool success,) = recentWinner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle__TransferFailed();
        }
    }

    /* Getter functions */
    function getEntranceFee() external view returns (uint256) {
        return I_ENTRANCE_FEE;
    }

    function getRecentWinner() external view returns (address) {
        return s_recentWinner;
    }

    function getRaffleState() public view returns (RaffleState) {
        return s_raffleState;
    }

    function getPlayer(uint256 index) public view returns (address) {
        return s_players[index];
    }
}
