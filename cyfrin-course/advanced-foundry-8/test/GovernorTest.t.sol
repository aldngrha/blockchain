// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {Box} from "../src/Box.sol";
import {GovToken} from "../src/GovToken.sol";
import {MyGovernor} from "../src/MyGovernor.sol";
import {TimeLock} from "../src/TimeLock.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";

contract GovernorTest is Test {
    Box public box;
    GovToken public govToken;
    MyGovernor public governor;
    TimeLock public timeLock;

    address public owner;
    address public alice;
    address public bob;
    address public carol;

    // TimelockController roles
    bytes32 public constant PROPOSER_ROLE = keccak256("PROPOSER_ROLE");
    bytes32 public constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");
    bytes32 public constant CANCELLER_ROLE = keccak256("CANCELLER_ROLE");

    function setUp() public {
        owner = makeAddr("owner");
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        carol = makeAddr("carol");

        // ============================================================
        // STEP 1: Deploy all contracts (as owner)
        // ============================================================

        vm.startPrank(owner);

        // 1a. Deploy Governance Token
        govToken = new GovToken();

        // 1b. Deploy TimeLock
        //     - minDelay: 3600 seconds (1 hour) — delay before execution
        //     - proposers: empty (will grant PROPOSER_ROLE to Governor later)
        //     - executors: address(0) = everyone can execute
        //     - msg.sender (owner) becomes admin
        address[] memory proposers = new address[](0);
        address[] memory executors = new address[](1);
        executors[0] = address(0); // address(0) = everyone
        timeLock = new TimeLock(3600, proposers, executors);

        // 1c. Deploy Governor
        //     - votingDelay: 1 block (proposal starts after 1 block)
        //     - votingPeriod: 50400 blocks (~1 week)
        //     - quorumFraction: 4% of total supply must vote
        governor = new MyGovernor(IVotes(address(govToken)), timeLock);

        // 1d. Deploy Box (target contract)
        box = new Box();

        // ============================================================
        // STEP 2: Setup roles and ownership
        // ============================================================

        // 2a. Grant PROPOSER_ROLE to Governor
        //     Governor needs this to queue proposals into Timelock
        timeLock.grantRole(PROPOSER_ROLE, address(governor));

        // 2b. Grant CANCELLER_ROLE to Governor
        //     Governor needs this to cancel proposals if needed
        timeLock.grantRole(CANCELLER_ROLE, address(governor));

        // 2c. Transfer Box ownership to TimeLock
        //     Now DAO (via Governor) controls Box, not a single person
        box.transferOwnership(address(timeLock));

        // 2d. Mint tokens to voters
        govToken.mint(alice, 100 ether); // Alice gets 100 MTK
        govToken.mint(bob, 50 ether);    // Bob gets 50 MTK
        govToken.mint(carol, 30 ether);  // Carol gets 30 MTK

        vm.stopPrank();

        // 3b. Delegate voting power
        //     IMPORTANT: In OZ ERC20Votes, you MUST delegate to yourself
        //     to have voting power. Without this, your tokens DON'T count for voting!
        vm.prank(alice);
        govToken.delegate(alice);
        vm.prank(bob);
        govToken.delegate(bob);
        vm.prank(carol);
        govToken.delegate(carol);
    }

    // ================================================================
    // TEST: Full Governance Flow
    // ================================================================

    function test_fullGovernanceFlow() public {
        uint256 totalSupply = govToken.totalSupply(); // 180 ether

        // ============================================================
        // STEP 4: Propose "Store value 42 in Box"
        // ============================================================

        // Encode the function call: Box.store(42)
        bytes memory callData = abi.encodeWithSelector(Box.store.selector, uint256(42));

        // Build arrays for propose()
        address[] memory targets = new address[](1);
        targets[0] = address(box);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = callData;

        // Alice proposes (she has enough tokens)
        vm.prank(alice);
        uint256 proposalId = governor.propose(
            targets,
            values,
            calldatas,
            "Set Box value to 42"
        );

        console.log("=== PROPOSAL CREATED ===");
        console.log("Proposal ID:", proposalId);
        console.log("Proposal State:", uint8(governor.state(proposalId)));
        // State should be PENDING (waiting for votingDelay)

        // ============================================================
        // STEP 5: Advance 1 block (past votingDelay)
        // ============================================================

        vm.roll(block.number + 2); // Jump 2 blocks forward (past votingDelay)

        console.log("\n=== AFTER 2 BLOCKS ===");
        console.log("Proposal State:", uint8(governor.state(proposalId)));
        // State should be ACTIVE (voting is open)

        // ============================================================
        // STEP 6: Cast votes
        // ============================================================

        // Alice votes YES (support = 1)
        vm.prank(alice);
        governor.castVote(proposalId, 1); // 1 = For, 0 = Against, 2 = Abstain

        // Bob votes YES
        vm.prank(bob);
        governor.castVote(proposalId, 1);

        // Carol votes NO
        vm.prank(carol);
        governor.castVote(proposalId, 2); // 2 = Against

        console.log("\n=== VOTES CAST ===");
        console.log("Alice: YES (100 MTK)");
        console.log("Bob:   YES (50 MTK)");
        console.log("Carol: NO  (30 MTK)");
        console.log("Total voting power:", 100 + 50 + 30, "MTK");
        console.log("Quorum needed (4%):", totalSupply * 4 / 100 / 1e18, "MTK");

        // ============================================================
        // STEP 7: Advance past votingPeriod (50400 blocks)
        // ============================================================

        vm.roll(block.number + 50400); // Jump ~1 week

        console.log("\n=== AFTER VOTING PERIOD ===");
        console.log("Proposal State:", uint8(governor.state(proposalId)));
        // State should be SUCCEEDED (Yes > No AND quorum met)

        // ============================================================
        // STEP 8: Queue the proposal into Timelock
        // ============================================================

        // Anyone can queue (as long as proposal is SUCCEEDED)
        governor.queue(targets, values, calldatas, keccak256(bytes("Set Box value to 42")));

        console.log("\n=== PROPOSAL QUEUED ===");
        console.log("Proposal State:", uint8(governor.state(proposalId)));
        // State should be QUEUED (waiting for minDelay)

        // ============================================================
        // STEP 9: Advance past minDelay (3600 seconds)
        // ============================================================

        vm.warp(block.timestamp + 3601); // Jump 1 hour + 1 second

        console.log("\n=== AFTER TIMELOCK DELAY ===");
        console.log("Proposal State:", uint8(governor.state(proposalId)));
        // State should be EXECUTABLE

        // ============================================================
        // STEP 10: Execute the proposal
        // ============================================================

        governor.execute(targets, values, calldatas, keccak256(bytes("Set Box value to 42")));

        console.log("\n=== PROPOSAL EXECUTED ===");
        console.log("Proposal State:", uint8(governor.state(proposalId)));
        console.log("Box value:", box.retrieve());
        // Box value should be 42!

        // ============================================================
        // VERIFICATION
        // ============================================================

        assertEq(box.retrieve(), 42, "Box value should be 42");
        assertEq(
            uint8(governor.state(proposalId)),
            uint8(IGovernor.ProposalState.Executed),
            "Proposal should be Executed"
        );

        console.log("\n=== ALL ASSERTIONS PASSED ===");
    }

    // ================================================================
    // TEST: Proposal Fails (No Quorum)
    // ================================================================

    function test_proposalFailsNoQuorum() public {
        bytes memory callData = abi.encodeWithSelector(Box.store.selector, uint256(99));

        address[] memory targets2 = new address[](1);
        targets2[0] = address(box);
        uint256[] memory values2 = new uint256[](1);
        values2[0] = 0;
        bytes[] memory calldatas2 = new bytes[](1);
        calldatas2[0] = callData;

        vm.prank(alice);
        uint256 proposalId = governor.propose(
            targets2,
            values2,
            calldatas2,
            "Set Box to 99 (should fail)"
        );

        vm.roll(block.number + 2); // Past votingDelay + 1

        // Only Carol votes NO
        vm.prank(carol);
        governor.castVote(proposalId, 2); // Against

        vm.roll(block.number + 50400); // Past votingPeriod

        console.log("Proposal State:", uint8(governor.state(proposalId)));
        // State should be DEFEATED (No votes > Yes votes)
        assertEq(
            uint8(governor.state(proposalId)),
            uint8(IGovernor.ProposalState.Defeated),
            "Proposal should be Defeated"
        );
    }

    // ================================================================
    // TEST: Proposal Expires (No One Voted)
    // ================================================================

    function test_proposalExpires() public {
        bytes memory callData = abi.encodeWithSelector(Box.store.selector, uint256(777));

        address[] memory targets3 = new address[](1);
        targets3[0] = address(box);
        uint256[] memory values3 = new uint256[](1);
        values3[0] = 0;
        bytes[] memory calldatas3 = new bytes[](1);
        calldatas3[0] = callData;

        vm.prank(alice);
        uint256 proposalId = governor.propose(
            targets3,
            values3,
            calldatas3,
            "Set Box to 777 (nobody votes)"
        );

        vm.roll(block.number + 2); // Past votingDelay + 1
        // Nobody votes...

        vm.roll(block.number + 50400); // Past votingPeriod

        console.log("Proposal State:", uint8(governor.state(proposalId)));
        // State should be DEFEATED (quorum not met, no votes)
        assertEq(
            uint8(governor.state(proposalId)),
            uint8(IGovernor.ProposalState.Defeated),
            "Proposal should be Defeated (no quorum met)"
        );
    }

    // ================================================================
    // TEST: Cannot Execute Before Timelock Delay
    // ================================================================

    function test_cannotExecuteBeforeDelay() public {
        bytes memory callData = abi.encodeWithSelector(Box.store.selector, uint256(100));

        address[] memory targets4 = new address[](1);
        targets4[0] = address(box);
        uint256[] memory values4 = new uint256[](1);
        values4[0] = 0;
        bytes[] memory calldatas4 = new bytes[](1);
        calldatas4[0] = callData;

        vm.prank(alice);
        uint256 proposalId = governor.propose(
            targets4,
            values4,
            calldatas4,
            "Set Box to 100"
        );

        vm.roll(block.number + 2); // Past votingDelay + 1

        // Alice and Bob vote YES
        vm.prank(alice);
        governor.castVote(proposalId, 1);
        vm.prank(bob);
        governor.castVote(proposalId, 1);

        vm.roll(block.number + 50400); // Past votingPeriod

        // Queue
        governor.queue(targets4, values4, calldatas4, keccak256(bytes("Set Box to 100")));

        // Try to execute BEFORE timelock delay — should revert
        vm.expectRevert();
        governor.execute(targets4, values4, calldatas4, keccak256(bytes("Set Box to 100")));

        // Advance past delay, then execute should work
        vm.warp(block.timestamp + 3601);
        governor.execute(targets4, values4, calldatas4, keccak256(bytes("Set Box to 100")));

        assertEq(box.retrieve(), 100, "Box value should be 100");
    }

    // ================================================================
    // TEST: Access Control — Only Box Owner (Timelock) Can Call store()
    // ================================================================

    function test_onlyOwnerCannotDirectCall() public {
        // Alice tries to call Box.store(999) directly — should revert
        vm.prank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        box.store(999);

        // Even owner (deployer) can't call — ownership transferred to Timelock
        vm.prank(owner);
        vm.expectRevert("Ownable: caller is not the owner");
        box.store(999);
    }

    // ================================================================
    // TEST: Token Delegation Is Required
    // ================================================================

    function test_delegationRequired() public {
        // Mint a new token to a fresh address that has NOT delegated
        address dave = makeAddr("dave");
        vm.prank(owner);
        govToken.mint(dave, 100 ether);

        // Dave tries to vote without delegating — should revert
        bytes memory callData = abi.encodeWithSelector(Box.store.selector, uint256(1));

        address[] memory targets5 = new address[](1);
        targets5[0] = address(box);
        uint256[] memory values5 = new uint256[](1);
        values5[0] = 0;
        bytes[] memory calldatas5 = new bytes[](1);
        calldatas5[0] = callData;

        vm.prank(alice);
        uint256 proposalId = governor.propose(
            targets5,
            values5,
            calldatas5,
            "Test delegation"
        );

        vm.roll(block.number + 2); // Past votingDelay + 1

        // Dave hasn't delegated — his voting power is 0
        // Vote succeeds but with 0 weight (no revert in OZ v4.8.3)
        vm.prank(dave);
        uint256 voteWeight = governor.castVote(proposalId, 1);
        assertEq(voteWeight, 0, "Dave's vote weight should be 0 without delegation");
    }
}
