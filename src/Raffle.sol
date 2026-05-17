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

/**
 * @title A sample Raffle Contract
 * @author :):
 * @notice Contract that creates a sample raffle using ChainLink VRF
 * @dev It implements Chainlink VRFv2.5
 */
contract Raffle {
    /** Errors */
    error Raffle__NotEnoughETHEntered();

    uint256 private immutable i_entraceFee;
    uint256 private immutable i_interval;
    uint256 private s_lastTimeStamp;
    address payable[] private s_players;

    /** Events */
    event RaffleEntered(address indexed player);

    constructor(uint256 _entraceFee, uint256 _interval) {
        i_entraceFee = _entraceFee;
        i_interval = _interval;
        s_lastTimeStamp = block.timestamp;
    }

    function enterRaffle() external payable {
        // require(msg.value >= entraceFee, "Not enough ETH");
        // This version ⭣⭣⭣ more gas efficient than ⭡⭡⭡
        if (msg.value < i_entraceFee) {
            revert Raffle__NotEnoughETHEntered();
        }
        s_players.push(payable(msg.sender));
        emit RaffleEntered(msg.sender);
    }

    function pickWinner() external {
        if(block.timestamp - s_lastTimeStamp > i_interval) {
            revert();
        }
    }

    /** Getter functions */
    function getEntranceFee() external view returns (uint256) {
        return i_entraceFee;
    }
}
