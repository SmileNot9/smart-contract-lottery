// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {CreateSubscription, FundSubscription, AddConsumer} from "script/Interactions.s.sol";
import {Test, console} from "../../lib/forge-std/src/Test.sol";
import {HelperConfig, CodeConstants} from "script/HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "lib/chainlink-evm/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

contract InteractionsTest is Test, CodeConstants {
    HelperConfig public helperConfig;
    address vrfCoordinator;
    address account;
    address link;
    uint256 subscriptionId;

    function setUp() external {
        helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory networkConfig = helperConfig.getConfig();
        vrfCoordinator = networkConfig.vrfCoordinator;
        subscriptionId = networkConfig.subscriptionId;
        account = networkConfig.account;
        link = networkConfig.link;
    }

    modifier skipFork() {
        if (block.chainid != LOCAL_CHAIN_ID) {
            return;
        }
        _;
    }

    function testCreateSubscriptionReturnsValidSubId() public {
        // Arrange
        CreateSubscription createSubscription = new CreateSubscription();

        // Act
        (uint256 subId,) = createSubscription.createSubscription(vrfCoordinator, account);

        // Assert
        assert(subId != 0);
    }

    function testFundSubscriptionGetFunded() public skipFork {
        //Arrange
        FundSubscription fundSubscription = new FundSubscription();

        // Act
        fundSubscription.fundSubscription(vrfCoordinator, subscriptionId, link, account);

        // Assert
        (uint96 balance,,,,) = VRFCoordinatorV2_5Mock(vrfCoordinator).getSubscription(subscriptionId);
        assert(balance > 0);
    }

    function testAddConsumerWorks() public skipFork {
        // Arrange
        AddConsumer addConsumer = new AddConsumer();
        address fakeConsumer = makeAddr("fakeConsumer");

        // Act
        addConsumer.addConsumer(fakeConsumer, subscriptionId, vrfCoordinator, account);

        // Assert
        (,,,, address[] memory consumers) = VRFCoordinatorV2_5Mock(vrfCoordinator).getSubscription(subscriptionId);
        assert(consumers[0] == fakeConsumer);
    }
}
