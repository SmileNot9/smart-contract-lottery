// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Raffle} from "src/Raffle.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "script/Interactions.s.sol";
import {Test, console} from "../../lib/forge-std/src/Test.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {HelperConfig, CodeConstants} from "script/HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "lib/chainlink-evm/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

contract InteractionsTest is Test {
    HelperConfig public helperConfig;
    Raffle public raffle;
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

    function testCreateSubscriptionReturnsValidSubId() public {
        CreateSubscription createSubscription = new CreateSubscription();
        (uint256 subId,) = createSubscription.createSubscription(vrfCoordinator, account);
        assert(subId != 0);
    }

    function testFundSubscriptionGetFunded() public {
        CreateSubscription createSubscription = new CreateSubscription();
        (uint256 subId,) = createSubscription.createSubscription(vrfCoordinator, account);
        FundSubscription fundSubscription = new FundSubscription();
        fundSubscription.fundSubscription(vrfCoordinator, subId, link, account);
        (uint96 balance,,,,) = VRFCoordinatorV2_5Mock(vrfCoordinator).getSubscription(subId);
        assert(balance > 0);
    }

    function testAddConsumerWorks() public {}
}
