// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {GovernanceToken} from "../src/GovernanceToken.sol";
import {GovernorContract} from "../src/GovernorContract.sol";
import {Treasury} from "../src/Treasury.sol";
import {GovernorCountingSimple} from "openzeppelin-contracts/governance/extensions/GovernorCountingSimple.sol";
import {TimelockController} from "openzeppelin-contracts/governance/TimelockController.sol";
import {IGovernor} from "openzeppelin-contracts/governance/IGovernor.sol";

/// @title End-to-end governance flow test (roadmap Kam 24 Sep).
/// @notice Full lifecycle against REAL wiring: token -> timelock -> governor -> treasury.
///         Voting runs on block numbers (token clock), the timelock delay runs on
///         timestamps, so passing states needs vm.roll for votes and vm.warp for the
///         timelock. Test values are tiny (delay 2 blocks, period 10 blocks, min delay
///         1 second); production values live in the deploy script.
contract GovernorFullFlowTest is Test {
    GovernanceToken internal token;
    GovernorContract internal governor;
    TimelockController internal timelock;
    Treasury internal treasury;

    address internal deployer = makeAddr("deployer");
    address internal alice = makeAddr("alice"); // 300k GT, votes FOR
    address internal bob = makeAddr("bob"); // 200k GT, votes FOR
    address internal charlie = makeAddr("charlie"); // 150k GT, votes AGAINST
    address internal dave = makeAddr("dave"); // 50k GT, votes ABSTAIN
    address internal eve = makeAddr("eve"); // 100 wei GT, minor holder
    address internal recipient = makeAddr("recipient");

    // Small values for fast tests. Deploy script uses the roadmap values
    // (delay 7200 blocks, period 50400 blocks, min delay 1 days).
    uint256 internal constant VOTING_DELAY = 2; // blocks
    uint256 internal constant VOTING_PERIOD = 10; // blocks
    uint256 internal constant QUORUM_PERCENT = 4;
    uint256 internal constant MIN_DELAY = 1; // seconds

    uint256 internal constant PAYOUT = 1 ether;
    uint256 internal constant QUORUM = 40_000e18; // 4% of 1M GT

    struct Proposal {
        address[] targets;
        uint256[] values;
        bytes[] calldatas;
        string description;
        uint256 id;
    }

    function setUp() public {
        vm.startPrank(deployer);
        token = new GovernanceToken();
        // Empty proposers/executors: roles are wired explicitly right after,
        // mirroring what the deploy script does (the governor does not exist yet
        // when the timelock is constructed).
        timelock = new TimelockController(MIN_DELAY, new address[](0), new address[](0), deployer);
        governor = new GovernorContract(token, timelock, QUORUM_PERCENT, VOTING_DELAY, VOTING_PERIOD);
        treasury = new Treasury(address(timelock));

        timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));
        timelock.grantRole(timelock.CANCELLER_ROLE(), address(governor));
        timelock.grantRole(timelock.EXECUTOR_ROLE(), address(0));
        // Hand over control: from here nothing on the timelock can be changed
        // outside a passed proposal.
        timelock.renounceRole(timelock.DEFAULT_ADMIN_ROLE(), deployer);
        vm.stopPrank();

        // Distribution. The token was minted to the deployer (the whole setUp runs
        // under that prank), so the deployer sends tokens out. He keeps ~300k GT and
        // NEVER delegates: with proposalThreshold 0 he can still propose, he just
        // cannot vote.
        vm.startPrank(deployer);
        token.transfer(alice, 300_000e18);
        token.transfer(bob, 200_000e18);
        token.transfer(charlie, 150_000e18);
        token.transfer(dave, 50_000e18);
        token.transfer(eve, 100);
        vm.stopPrank();

        vm.prank(alice);
        token.delegate(alice);
        vm.prank(bob);
        token.delegate(bob);
        vm.prank(charlie);
        token.delegate(charlie);
        vm.prank(dave);
        token.delegate(dave);
        vm.prank(eve);
        token.delegate(eve);

        // Fund the vault with plain ETH transfers (exercises receive()).
        (bool ok,) = address(treasury).call{value: 10 ether}("");
        require(ok, "funding treasury failed");
    }

    /*//////////////////////////////////
                WIRING & PARAMETERS
    //////////////////////////////////*/

    function test_TimelockRoleWiring() public view {
        assertTrue(timelock.hasRole(timelock.PROPOSER_ROLE(), address(governor)), "governor proposes");
        assertTrue(timelock.hasRole(timelock.CANCELLER_ROLE(), address(governor)), "governor cancels");
        assertTrue(timelock.hasRole(timelock.EXECUTOR_ROLE(), address(0)), "executor role open");
        assertFalse(timelock.hasRole(timelock.DEFAULT_ADMIN_ROLE(), deployer), "deployer renounced admin");
        assertTrue(timelock.hasRole(timelock.DEFAULT_ADMIN_ROLE(), address(timelock)), "timelock self-admin");
        assertEq(timelock.getMinDelay(), MIN_DELAY);
        assertEq(governor.timelock(), address(timelock));
    }

    function test_GovernorParameters() public view {
        assertEq(governor.name(), "Governance DApp Governor");
        assertEq(governor.votingDelay(), VOTING_DELAY);
        assertEq(governor.votingPeriod(), VOTING_PERIOD);
        assertEq(governor.proposalThreshold(), 0, "threshold 0: any holder may propose");
        assertEq(governor.quorumNumerator(), QUORUM_PERCENT);
        assertEq(address(governor.token()), address(token));
    }

    function test_QuorumIs4PercentOfPastSupply() public {
        vm.roll(block.number + 1); // getPastTotalSupply needs a mined past block
        assertEq(governor.quorum(block.number - 1), QUORUM, "4% of 1M GT");
    }

    function test_TreasuryRejectsNonTimelockCaller() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Treasury.Treasury__OnlyTimelock.selector, alice, address(timelock)));
        treasury.execute(payable(alice), PAYOUT);
    }

    function test_TreasuryAcceptsEthFromAnyone() public {
        Treasury freshTreasury = new Treasury(address(timelock));
        (bool ok,) = address(freshTreasury).call{value: 2 ether}("");
        assertTrue(ok);
        assertEq(freshTreasury.getBalance(), 2 ether);
    }

    /*//////////////////////////////////
                FULL HAPPY PATH
    //////////////////////////////////*/

    function test_FullGovernanceFlow_ProposeVoteQueueExecute() public {
        Proposal memory p = _newProposal("Release 1 ETH to recipient");

        vm.prank(alice);
        governor.propose(p.targets, p.values, p.calldatas, p.description);
        // Deterministic id: recomputing from the same parameters must match.
        assertEq(p.id, governor.hashProposal(p.targets, p.values, p.calldatas, keccak256(bytes(p.description))));

        assertEq(uint8(governor.state(p.id)), uint8(IGovernor.ProposalState.Pending));

        uint256 snapshot = block.number + VOTING_DELAY;
        vm.roll(snapshot + 1); // voting window opens
        assertEq(uint8(governor.state(p.id)), uint8(IGovernor.ProposalState.Active));

        vm.prank(alice);
        governor.castVote(p.id, uint8(GovernorCountingSimple.VoteType.For));
        vm.prank(bob);
        uint256 weight = governor.castVote(p.id, uint8(GovernorCountingSimple.VoteType.For));
        assertEq(weight, 200_000e18, "weight = delegated balance at snapshot");
        vm.prank(charlie);
        governor.castVote(p.id, uint8(GovernorCountingSimple.VoteType.Against));

        (uint256 against, uint256 forVotes, uint256 abstain) = governor.proposalVotes(p.id);
        assertEq(forVotes, 500_000e18);
        assertEq(against, 150_000e18);
        assertEq(abstain, 0);

        vm.roll(snapshot + VOTING_PERIOD + 1); // voting window closed
        assertEq(uint8(governor.state(p.id)), uint8(IGovernor.ProposalState.Succeeded));

        governor.queue(p.targets, p.values, p.calldatas, keccak256(bytes(p.description)));
        assertEq(uint8(governor.state(p.id)), uint8(IGovernor.ProposalState.Queued));
        assertEq(governor.proposalEta(p.id), block.timestamp + MIN_DELAY);

        uint256 treasuryBefore = address(treasury).balance;

        // The timelock delay is in seconds: warp, not roll.
        vm.warp(block.timestamp + MIN_DELAY + 1);

        // Execution is permissionless (EXECUTOR_ROLE is open): anyone may trigger it.
        address executor = makeAddr("executor");
        vm.prank(executor);
        governor.execute(p.targets, p.values, p.calldatas, keccak256(bytes(p.description)));

        assertEq(uint8(governor.state(p.id)), uint8(IGovernor.ProposalState.Executed));
        assertEq(address(treasury).balance, treasuryBefore - PAYOUT, "treasury paid out");
        assertEq(recipient.balance, PAYOUT, "recipient received ETH");
    }

    /*//////////////////////////////////
            DEFEATED / QUORUM PATHS
    //////////////////////////////////*/

    function test_DefeatedWhenQuorumNotReached() public {
        // Deployer holds ~300k GT but never delegated: 0 votes, yet threshold is 0
        // so proposing is allowed. This is the vote that cannot save the proposal.
        Proposal memory p = _newProposal("Defeated: quorum missed");

        vm.prank(deployer);
        governor.propose(p.targets, p.values, p.calldatas, p.description);

        uint256 snapshot = block.number + VOTING_DELAY;
        vm.roll(snapshot + 1);
        vm.prank(eve);
        governor.castVote(p.id, uint8(GovernorCountingSimple.VoteType.For)); // 100 wei, way below quorum

        vm.roll(snapshot + VOTING_PERIOD + 1);
        assertEq(uint8(governor.state(p.id)), uint8(IGovernor.ProposalState.Defeated));

        // A defeated proposal cannot be queued. Queue only accepts the Succeeded state.
        vm.expectRevert(
            abi.encodeWithSelector(
                IGovernor.GovernorUnexpectedProposalState.selector,
                p.id,
                uint8(IGovernor.ProposalState.Defeated),
                bytes32(uint256(1) << uint8(IGovernor.ProposalState.Succeeded))
            )
        );
        governor.queue(p.targets, p.values, p.calldatas, keccak256(bytes(p.description)));
    }

    function test_DefeatedWhenAgainstOutweighsForEvenWithQuorum() public {
        Proposal memory p = _newProposal("Defeated: majority lost");

        vm.prank(alice);
        governor.propose(p.targets, p.values, p.calldatas, p.description);

        uint256 snapshot = block.number + VOTING_DELAY;
        vm.roll(snapshot + 1);
        vm.prank(alice);
        governor.castVote(p.id, uint8(GovernorCountingSimple.VoteType.For)); // 300k
        vm.prank(bob);
        governor.castVote(p.id, uint8(GovernorCountingSimple.VoteType.Against)); // 200k
        vm.prank(charlie);
        governor.castVote(p.id, uint8(GovernorCountingSimple.VoteType.Against)); // 150k

        vm.roll(snapshot + VOTING_PERIOD + 1);
        // Quorum IS reached (300k >= 40k) but FOR (300k) is not > AGAINST (350k).
        assertEq(uint8(governor.state(p.id)), uint8(IGovernor.ProposalState.Defeated));
    }

    function test_AbstainCountsTowardQuorumButNotMajority() public {
        Proposal memory p = _newProposal("Abstain counts for quorum");

        vm.prank(alice);
        governor.propose(p.targets, p.values, p.calldatas, p.description);

        uint256 snapshot = block.number + VOTING_DELAY;
        vm.roll(snapshot + 1);
        vm.prank(bob);
        governor.castVote(p.id, uint8(GovernorCountingSimple.VoteType.For)); // 200k
        vm.prank(dave);
        governor.castVote(p.id, uint8(GovernorCountingSimple.VoteType.Abstain)); // 50k
        vm.prank(charlie);
        governor.castVote(p.id, uint8(GovernorCountingSimple.VoteType.Against)); // 150k

        (uint256 against, uint256 forVotes, uint256 abstain) = governor.proposalVotes(p.id);
        assertEq(forVotes, 200_000e18);
        assertEq(against, 150_000e18);
        assertEq(abstain, 50_000e18);

        vm.roll(snapshot + VOTING_PERIOD + 1);
        // quorum: for + abstain = 250k >= 40k. majority: 200k > 150k.
        assertEq(uint8(governor.state(p.id)), uint8(IGovernor.ProposalState.Succeeded));
    }

    /*//////////////////////////////////
                NEGATIVE PATHS
    //////////////////////////////////*/

    function test_VoteBeforeActiveReverts() public {
        Proposal memory p = _newProposal("Vote before active");
        vm.prank(alice);
        governor.propose(p.targets, p.values, p.calldatas, p.description);

        vm.expectRevert(
            abi.encodeWithSelector(
                IGovernor.GovernorUnexpectedProposalState.selector,
                p.id,
                uint8(IGovernor.ProposalState.Pending),
                bytes32(uint256(1) << uint8(IGovernor.ProposalState.Active))
            )
        );
        vm.prank(alice);
        governor.castVote(p.id, uint8(GovernorCountingSimple.VoteType.For));
    }

    function test_ExecuteWithoutQueueReverts() public {
        Proposal memory p = _newProposal("Execute without queue");
        _reachSucceeded(p);

        // Governor.execute accepts a Succeeded proposal, but the timelock rejects
        // executeBatch for an operation that was never scheduled.
        vm.expectRevert(_timelockUnexpectedState(p));
        governor.execute(p.targets, p.values, p.calldatas, keccak256(bytes(p.description)));

        assertEq(recipient.balance, 0, "no funds moved");
    }

    function test_ExecuteBeforeTimelockDelayReverts() public {
        Proposal memory p = _newProposal("Execute before delay");
        _reachQueued(p);

        vm.expectRevert(_timelockUnexpectedState(p));
        governor.execute(p.targets, p.values, p.calldatas, keccak256(bytes(p.description)));

        assertEq(recipient.balance, 0, "no funds moved");
        assertEq(address(treasury).balance, 10 ether);
    }

    function test_DoubleVoteReverts() public {
        Proposal memory p = _newProposal("Double vote");
        _reachActive(p);
        vm.prank(alice);
        governor.castVote(p.id, uint8(GovernorCountingSimple.VoteType.For));

        vm.expectRevert(abi.encodeWithSelector(IGovernor.GovernorAlreadyCastVote.selector, alice));
        vm.prank(alice);
        governor.castVote(p.id, uint8(GovernorCountingSimple.VoteType.For));
    }

    function test_NonDelegatedHolderVotesWithZeroWeight() public {
        address holder = makeAddr("holder");
        vm.prank(deployer);
        token.transfer(holder, 5_000e18); // real balance, never delegated

        Proposal memory p = _newProposal("Zero weight vote");
        _reachActive(p);

        vm.prank(holder);
        uint256 weight = governor.castVote(p.id, uint8(GovernorCountingSimple.VoteType.For));
        assertEq(weight, 0, "no delegation, no weight");

        (, uint256 forVotes,) = governor.proposalVotes(p.id);
        assertEq(forVotes, 0, "tally unchanged");
    }

    /*//////////////////////////////////
                    CANCEL
    //////////////////////////////////*/

    function test_ProposerCanCancelWhilePending() public {
        Proposal memory p = _newProposal("Cancel by proposer");
        vm.prank(alice);
        governor.propose(p.targets, p.values, p.calldatas, p.description);

        vm.prank(alice);
        governor.cancel(p.targets, p.values, p.calldatas, keccak256(bytes(p.description)));
        assertEq(uint8(governor.state(p.id)), uint8(IGovernor.ProposalState.Canceled));
    }

    function test_NonProposerCannotCancel() public {
        Proposal memory p = _newProposal("Cancel by stranger");
        vm.prank(alice);
        governor.propose(p.targets, p.values, p.calldatas, p.description);

        vm.expectRevert(abi.encodeWithSelector(IGovernor.GovernorUnableToCancel.selector, p.id, bob));
        vm.prank(bob);
        governor.cancel(p.targets, p.values, p.calldatas, keccak256(bytes(p.description)));
    }

    /*//////////////////////////////////
                HELPERS
    //////////////////////////////////*/

    /// @dev Exact revert data of TimelockUnexpectedOperationState for an operation
    ///      derived from proposal p (id = hashOperationBatch with the governor salt).
    ///      forge 1.5.1 compares the full revert data, so a bare selector never matches
    ///      an error that carries arguments.
    function _timelockUnexpectedState(Proposal memory p) internal view returns (bytes memory) {
        bytes32 salt = bytes20(address(governor)) ^ keccak256(bytes(p.description));
        bytes32 timelockId = timelock.hashOperationBatch(p.targets, p.values, p.calldatas, 0, salt);
        return abi.encodeWithSelector(
            TimelockController.TimelockUnexpectedOperationState.selector,
            timelockId,
            bytes32(uint256(1) << uint8(TimelockController.OperationState.Ready))
        );
    }

    /// @dev Proposal that asks the timelock to call Treasury.execute(recipient, PAYOUT).
    function _newProposal(string memory description) internal returns (Proposal memory p) {
        p.targets = new address[](1);
        p.targets[0] = address(treasury);
        p.values = new uint256[](1);
        p.values[0] = 0;
        p.calldatas = new bytes[](1);
        p.calldatas[0] = abi.encodeCall(Treasury.execute, (payable(recipient), PAYOUT));
        p.description = description;
        p.id = governor.hashProposal(p.targets, p.values, p.calldatas, keccak256(bytes(description)));
    }

    function _reachActive(Proposal memory p) internal {
        vm.prank(alice);
        governor.propose(p.targets, p.values, p.calldatas, p.description);
        vm.roll(block.number + VOTING_DELAY + 1);
    }

    function _reachSucceeded(Proposal memory p) internal {
        _reachActive(p);
        vm.prank(alice);
        governor.castVote(p.id, uint8(GovernorCountingSimple.VoteType.For));
        vm.prank(bob);
        governor.castVote(p.id, uint8(GovernorCountingSimple.VoteType.For));
        vm.roll(block.number + VOTING_PERIOD + 1);
    }

    function _reachQueued(Proposal memory p) internal {
        _reachSucceeded(p);
        governor.queue(p.targets, p.values, p.calldatas, keccak256(bytes(p.description)));
    }
}
