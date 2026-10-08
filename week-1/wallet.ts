import { generateMnemonic, mnemonicToAccount, english } from "viem/accounts";

const mnemonic = generateMnemonic(english);
const account = mnemonicToAccount(mnemonic);

console.log("Mnemonic :", mnemonic);
console.log("Address  :", account.address);
