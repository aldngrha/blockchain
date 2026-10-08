// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {Raffle} from "../src/Raffle.sol";
import {DeployRaffle} from "../script/DeployRaffle.s.sol";
import {HelperConfig} from "../script/HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

contract RaffleTest is Test {
    Raffle public raffle;
    HelperConfig public helperConfig;
    VRFCoordinatorV2_5Mock public vrfCoordinator;

    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinatorAddress;
    bytes32 keyHash;
    uint256 subscriptionId;
    uint32 callbackGasLimit;

    address public PLAYER = makeAddr("player");
    address public PLAYER_2 = makeAddr("player2");
    address public PLAYER_3 = makeAddr("player3");
    uint256 public constant STARTING_PLAYER_BALANCE = 10 ether;

    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.deployContract();

        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        entranceFee = config.entranceFee;
        interval = config.interval;
        vrfCoordinatorAddress = config.vrfCoordinator;
        keyHash = config.keyHash;
        subscriptionId = config.subscriptionId;
        callbackGasLimit = config.callbackGasLimit;
        vrfCoordinator = VRFCoordinatorV2_5Mock(vrfCoordinatorAddress);

        vm.deal(PLAYER, STARTING_PLAYER_BALANCE);
        vm.deal(PLAYER_2, STARTING_PLAYER_BALANCE);
        vm.deal(PLAYER_3, STARTING_PLAYER_BALANCE);
    }

    /*//////////////////////////////////////////////////////////
                            ENTER RAFFLE
    //////////////////////////////////////////////////////////*/

    function testRaffleInitializesInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    function testRaffleRevertsWhenYouDontPayEnough() public {
        vm.prank(PLAYER);
        vm.expectRevert(Raffle.Raffle__SendMoreToEnterRaffle.selector);
        raffle.enterRaffle();
    }

    function testRaffleRecordsPlayerWhenTheyEnter() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        address playerRecorded = raffle.getPlayer(0);
        assert(playerRecorded == PLAYER);
    }

    function testEnteringRaffleEmitsEvent() public {
        vm.prank(PLAYER);
        vm.expectEmit(true, false, false, false, address(raffle));
        emit RaffleEntered(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }

    function testDontAllowPlayersToEnterWhileRaffleIsCalculating() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.pickWinner();

        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }

    function testMultiplePlayersCanEnter() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.prank(PLAYER_2);
        raffle.enterRaffle{value: entranceFee}();
        vm.prank(PLAYER_3);
        raffle.enterRaffle{value: entranceFee}();

        assert(raffle.getNumberOfPlayers() == 3);
        assert(raffle.getPlayer(0) == PLAYER);
        assert(raffle.getPlayer(1) == PLAYER_2);
        assert(raffle.getPlayer(2) == PLAYER_3);
    }

    /*//////////////////////////////////////////////////////////
                            PICK WINNER
    //////////////////////////////////////////////////////////*/

    function testPickWinnerRevertsWhenNotEnoughTimeHasPassed() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();

        vm.expectRevert(Raffle.Raffle__NotEnoughTimeHasPassed.selector);
        raffle.pickWinner();
    }

    function testPickWinnerSetsRaffleStateToCalculating() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();

        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.pickWinner();

        assert(raffle.getRaffleState() == Raffle.RaffleState.CALCULATING);
    }

    /*//////////////////////////////////////////////////////////
                        FULFILL RANDOM WORDS
    //////////////////////////////////////////////////////////*/

    function testFullRaffleFlow() public {
        // 3 players enter
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.prank(PLAYER_2);
        raffle.enterRaffle{value: entranceFee}();
        vm.prank(PLAYER_3);
        raffle.enterRaffle{value: entranceFee}();

        // Verify balance
        assertEq(address(raffle).balance, entranceFee * 3);

        // Time passes, pick winner
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        raffle.pickWinner();

        // State should be CALCULATING
        assert(raffle.getRaffleState() == Raffle.RaffleState.CALCULATING);

        // Fulfill with override: requestId=1 (first request), randomWords[0]=777
        // 777 % 3 = 0 -> PLAYER wins
        uint256[] memory s_randomWords = new uint256[](1);
        s_randomWords[0] = 777;
        vrfCoordinator.fulfillRandomWordsWithOverride(1, address(raffle), s_randomWords);

        // Verify state resets
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
        assertEq(raffle.getNumberOfPlayers(), 0);
        assertEq(raffle.getRecentWinner(), PLAYER);
        assertEq(address(raffle).balance, 0);
        assertEq(PLAYER.balance, STARTING_PLAYER_BALANCE - entranceFee + (entranceFee * 3));
    }

    function testFulfillRandomWordsPicksCorrectWinner() public {
        // 3 players enter
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.prank(PLAYER_2);
        raffle.enterRaffle{value: entranceFee}();
        vm.prank(PLAYER_3);
        raffle.enterRaffle{value: entranceFee}();

        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.pickWinner();

        // randomWords[0] = 1 -> 1 % 3 = 1 -> PLAYER_2 wins
        uint256[] memory s_randomWords = new uint256[](1);
        s_randomWords[0] = 1;
        vrfCoordinator.fulfillRandomWordsWithOverride(1, address(raffle), s_randomWords);

        assertEq(raffle.getRecentWinner(), PLAYER_2);
    }

    function testFulfillRandomWordsResetsPlayers() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.prank(PLAYER_2);
        raffle.enterRaffle{value: entranceFee}();

        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.pickWinner();

        uint256[] memory s_randomWords = new uint256[](1);
        s_randomWords[0] = 0;
        vrfCoordinator.fulfillRandomWordsWithOverride(1, address(raffle), s_randomWords);

        assertEq(raffle.getNumberOfPlayers(), 0);
    }

    /*//////////////////////////////////////////////////////////
                            FUZZ TESTS
    //////////////////////////////////////////////////////////*/

    function testFuzz_EnterRaffle(uint256 _entranceFee) public {
        vm.assume(_entranceFee >= entranceFee);
        vm.assume(_entranceFee <= STARTING_PLAYER_BALANCE);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: _entranceFee}();
        assertEq(raffle.getNumberOfPlayers(), 1);
    }

    function testFuzz_EnterRaffleRevertsWhenNotEnough(uint256 _entranceFee) public {
        vm.assume(_entranceFee < entranceFee);
        vm.prank(PLAYER);
        vm.expectRevert(Raffle.Raffle__SendMoreToEnterRaffle.selector);
        raffle.enterRaffle{value: _entranceFee}();
    }
}
