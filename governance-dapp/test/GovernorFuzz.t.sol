// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {GovernanceToken} from "../src/GovernanceToken.sol";
import {GovernorContract} from "../src/GovernorContract.sol";
import {TimelockController} from "openzeppelin-contracts/governance/TimelockController.sol";
import {IGovernor} from "openzeppelin-contracts/governance/IGovernor.sol";
import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";

/// @title Lightweight stateless fuzz tests for the governance stack (SPEC section 7).
/// @notice Two properties:
///         1. Governor voting weight at any past timepoint is exactly the token
///            checkpoint value there and never exceeds the past total supply.
///         2. Proposal ids are a pure function of (targets, values, calldatas,
///            descriptionHash): same inputs, same id; a changed description, a new id.
contract GovernorFuzzTest is Test {
    GovernanceToken internal token;
    GovernorContract internal governor;
    TimelockController internal timelock;

    address internal alice = makeAddr("alice");

    function setUp() public {
        token = new GovernanceToken();
        timelock = new TimelockController(1, new address[](0), new address[](0), address(this));
        // Tiny parameters: this suite never reaches a real vote, it only checks
        // vote-weight and id-derivation properties.
        governor = new GovernorContract(token, timelock, 4, 1, 5);
    }

    function testFuzz_GovernorWeightMirrorsTokenCheckpoints(uint256 amount, uint256 jump, uint256 timepointSeed)
        public
    {
        amount = bound(amount, 0, token.INITIAL_SUPPLY());
        jump = bound(jump, 1, 64);

        uint256 before = block.number;
        token.transfer(alice, amount);
        vm.prank(alice);
        token.delegate(alice);

        vm.roll(before + jump + 1); // mine the delegation, then move on
        uint256 timepoint = bound(timepointSeed, 1, block.number - 1); // must be a mined block

        assertEq(
            governor.getVotes(alice, timepoint),
            token.getPastVotes(alice, timepoint),
            "governor reads token checkpoints"
        );
        assertLe(
            token.getPastVotes(alice, timepoint),
            token.getPastTotalSupply(timepoint),
            "weight can never exceed total voting supply"
        );
    }

    function testFuzz_ProposalIdDeterministic(uint256 amount, string memory description) public {
        (address[] memory targets, uint256[] memory values, bytes[] memory calldatas) = _buildTransfer(amount);
        bytes32 descHash = keccak256(bytes(description));

        uint256 id1 = governor.hashProposal(targets, values, calldatas, descHash);
        uint256 id2 = governor.hashProposal(targets, values, calldatas, descHash);
        assertEq(id1, id2, "same parameters, same proposal id");

        uint256 id3 =
            governor.hashProposal(targets, values, calldatas, keccak256(bytes(string.concat(description, " "))));
        assertTrue(id3 != id1, "a different description yields a different id");
    }

    function testFuzz_DuplicateProposalReverts(uint256 amount, string memory description) public {
        (address[] memory targets, uint256[] memory values, bytes[] memory calldatas) = _buildTransfer(amount);

        uint256 id = governor.hashProposal(targets, values, calldatas, keccak256(bytes(description)));

        vm.prank(alice); // threshold is 0, alice has 0 delegated votes and still proposes
        governor.propose(targets, values, calldatas, description);

        // forge 1.5.1 compares the FULL revert data, so an error with arguments
        // must be expected with its complete encoding (a bare selector never matches).
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                IGovernor.GovernorUnexpectedProposalState.selector,
                id,
                uint8(IGovernor.ProposalState.Pending),
                bytes32(0) // _propose passes a zero sentinel, not a state bitmap
            )
        );
        governor.propose(targets, values, calldatas, description);
    }

    function _buildTransfer(uint256 amount)
        internal
        pure
        returns (address[] memory targets, uint256[] memory values, bytes[] memory calldatas)
    {
        targets = new address[](1);
        targets[0] = address(0x1); // never called during the fuzz, only hashed
        values = new uint256[](1);
        calldatas = new bytes[](1);
        calldatas[0] = abi.encodeCall(IERC20.transfer, (address(0x2), amount));
    }
}
