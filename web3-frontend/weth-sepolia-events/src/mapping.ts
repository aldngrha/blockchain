import { BigInt, BigDecimal, Bytes } from "@graphprotocol/graph-ts";
import { Transfer } from "../generated/WETH/WETH";
import { Transfer as TransferEntity, TokenHolder } from "../generated/schema";

// Convert wei to WETH (18 decimals)
function weiToEth(wei: BigInt): BigDecimal {
  const divider = BigDecimal.fromString("1000000000000000000");
  return wei.toBigDecimal().div(divider);
}

// Get or create TokenHolder entity
function getOrCreateHolder(address: Bytes): TokenHolder {
  let holder = TokenHolder.load(address);
  if (!holder) {
    holder = new TokenHolder(address);
    holder.address = address;
    holder.balance = BigDecimal.fromString("0");
    holder.totalReceived = BigDecimal.fromString("0");
    holder.totalSent = BigDecimal.fromString("0");
    holder.transferCount = 0;
    holder.lastTransferBlock = BigInt.fromI32(0);
  }
  return holder;
}

// Handle Transfer event
export function handleTransfer(event: Transfer): void {
  // 1. Create Transfer entity
  const id = event.transaction.hash.concatI32(event.logIndex.toI32());
  const transfer = new TransferEntity(id);
  transfer.from = event.params.src;
  transfer.to = event.params.dst;
  transfer.value = weiToEth(event.params.wad);
  transfer.blockNumber = event.block.number;
  transfer.timestamp = event.block.timestamp;
  transfer.txHash = event.transaction.hash;
  transfer.save();

  // 2. Update sender
  const sender = getOrCreateHolder(event.params.src);
  sender.totalSent = sender.totalSent.plus(transfer.value);
  sender.balance = sender.balance.minus(transfer.value);
  sender.transferCount += 1;
  sender.lastTransferBlock = event.block.number;
  sender.save();

  // 3. Update receiver
  const receiver = getOrCreateHolder(event.params.dst);
  receiver.totalReceived = receiver.totalReceived.plus(transfer.value);
  receiver.balance = receiver.balance.plus(transfer.value);
  receiver.transferCount += 1;
  receiver.lastTransferBlock = event.block.number;
  receiver.save();
}
