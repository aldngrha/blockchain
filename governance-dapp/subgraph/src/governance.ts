// AssemblyScript handlers for the governance lifecycle. One data source
// (GovernorContract) emits every event we index. Event signatures match OZ v5.4:
// only VoteCast.voter is indexed, so proposal events carry the proposalId as a
// regular parameter and are read from event.params accordingly.

import {
  ProposalCanceled,
  ProposalCreated,
  ProposalExecuted,
  ProposalQueued,
  VoteCast,
} from "../generated/GovernorContract/Governor"
import { Proposal, Vote, Voter } from "../generated/schema"

const STATUS_PENDING = "Pending"
const STATUS_QUEUED = "Queued"
const STATUS_EXECUTED = "Executed"
const STATUS_CANCELED = "Canceled"

// Governor Bravo ordering used by GovernorCountingSimple.
const SUPPORT_AGAINST = 0
const SUPPORT_FOR = 1
const SUPPORT_ABSTAIN = 2

export function handleProposalCreated(event: ProposalCreated): void {
  let id = event.params.proposalId.toString()
  let proposal = new Proposal(id)
  proposal.proposalId = event.params.proposalId
  proposal.proposer = event.params.proposer
  proposal.targets = event.params.targets
  proposal.values = event.params.values
  proposal.calldatas = event.params.calldatas
  proposal.description = event.params.description
  proposal.voteStart = event.params.voteStart
  proposal.voteEnd = event.params.voteEnd
  proposal.status = STATUS_PENDING
  proposal.forVotes = BigInt.zero()
  proposal.againstVotes = BigInt.zero()
  proposal.abstainVotes = BigInt.zero()
  proposal.createdAtBlock = event.block.number
  proposal.createdAtTimestamp = event.block.timestamp
  proposal.save()
}

export function handleVoteCast(event: VoteCast): void {
  let proposalId = event.params.proposalId.toString()
  let proposal = Proposal.load(proposalId)
  if (proposal == null) {
    // VoteCast for an unknown proposal: nothing sensible to index.
    return
  }

  // Update tallies. Abstain counts toward quorum but not toward the majority,
  // which the frontend must recompute from for/against anyway.
  if (event.params.support == SUPPORT_FOR) {
    proposal.forVotes = proposal.forVotes.plus(event.params.weight)
  } else if (event.params.support == SUPPORT_AGAINST) {
    proposal.againstVotes = proposal.againstVotes.plus(event.params.weight)
  } else if (event.params.support == SUPPORT_ABSTAIN) {
    proposal.abstainVotes = proposal.abstainVotes.plus(event.params.weight)
  }

  let voterId = event.params.voter.toHex()
  let voter = Voter.load(voterId)
  if (voter == null) {
    voter = new Voter(voterId)
    voter.address = event.params.voter
    voter.totalWeightCast = BigInt.zero()
    voter.voteCount = BigInt.zero()
  }
  voter.totalWeightCast = voter.totalWeightCast.plus(event.params.weight)
  voter.voteCount = voter.voteCount.plus(BigInt.fromI32(1))
  voter.save()

  // One vote per voter per proposal is enforced on-chain (GovernorAlreadyCastVote),
  // so the composite id cannot collide.
  let vote = new Vote(proposalId + "-" + voterId)
  vote.proposal = proposalId
  vote.voter = voterId
  vote.support = event.params.support
  vote.weight = event.params.weight
  vote.reason = event.params.reason
  vote.blockNumber = event.block.number
  vote.blockTimestamp = event.block.timestamp
  vote.save()

  proposal.save()
}

export function handleProposalQueued(event: ProposalQueued): void {
  let proposal = Proposal.load(event.params.proposalId.toString())
  if (proposal == null) {
    return
  }
  proposal.status = STATUS_QUEUED
  proposal.etaSeconds = event.params.etaSeconds
  proposal.save()
}

export function handleProposalExecuted(event: ProposalExecuted): void {
  let proposal = Proposal.load(event.params.proposalId.toString())
  if (proposal == null) {
    return
  }
  proposal.status = STATUS_EXECUTED
  proposal.executedAt = event.block.timestamp
  proposal.save()
}

export function handleProposalCanceled(event: ProposalCanceled): void {
  let proposal = Proposal.load(event.params.proposalId.toString())
  if (proposal == null) {
    return
  }
  proposal.status = STATUS_CANCELED
  proposal.canceledAt = event.block.timestamp
  proposal.save()
}
