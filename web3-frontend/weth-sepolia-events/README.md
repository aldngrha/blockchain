# WETH Sepolia Events — The Graph Subgraph

Subgraph untuk index Transfer events dari WETH contract di Ethereum Sepolia.

## Contract

- **Network:** Ethereum Sepolia
- **Contract:** WETH (`0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9`)
- **Start Block:** 5,000,000

## Entities

| Entity | Deskripsi | Immutable |
|--------|-----------|-----------|
| `Transfer` | Log setiap WETH transfer | ✅ Yes |
| `TokenHolder` | Balance summary per address | ❌ No (di-update) |

## Setup

### 1. Install Dependencies

```bash
npm install
```

### 2. Codegen

Generate TypeScript types dari schema:

```bash
npx graph codegen
```

### 3. Build

Compile ke WebAssembly:

```bash
npx graph build
```

## Deploy ke Graph Studio

### Step 1: Create Subgraph di Studio

1. Buka https://thegraph.com/studio/
2. Connect wallet (MetaMask)
3. Klik **"Create a Subgraph"**
4. Name: `weth-sepolia-events`
5. Klik **Create**

### Step 2: Copy Deploy Key

1. Di halaman subgraph, cari **DEPLOY KEY**
2. Copy key-nya (contoh: `789b7c-32516d`)

### Step 3: Deploy

```bash
npx graph deploy \
  --node https://api.studio.thegraph.com/deploy/ \
  --deploy-key <DEPLOY_KEY> \
  weth-sepolia-events
```

Ganti `<DEPLOY_KEY>` dengan key dari Studio.

### Step 4: Version Label

Diminta input version label, ketik:
```
v0.0.1
```

### Step 5: Tunggu Indexing

- Buka https://thegraph.com/studio/subgraph/weth-sepolia-events
- Lihat progress indexing (SYNCING → FULLY SYNCED)
- Entity Count akan naik terus

### Step 6: Query di Playground

1. Klik tab **Playground**
2. Paste query:

```graphql
{
  transfers(orderBy: blockNumber, orderDirection: desc, first: 10) {
    from
    to
    value
    blockNumber
    timestamp
    txHash
  }
}
```

3. Klik **Run** ▶️

## Query Examples

### Semua Transfer (terbaru)

```graphql
{
  transfers(orderBy: blockNumber, orderDirection: desc, first: 10) {
    from
    to
    value
    blockNumber
    timestamp
  }
}
```

### Transfer dari Address Tertentu

```graphql
{
  transfers(
    where: { from: "0x14a88FA01d5EEe6AcA04656dFc5e57D78F2F5bA0" }
    orderBy: blockNumber
    orderDirection: desc
  ) {
    from
    to
    value
    blockNumber
  }
}
```

### Top Holders

```graphql
{
  tokenHolders(orderBy: balance, orderDirection: desc, first: 10) {
    address
    balance
    totalReceived
    totalSent
    transferCount
  }
}
```

### Total Volume (Top 5 Transfer Terbesar)

```graphql
{
  transfers(orderBy: value, orderDirection: desc, first: 5) {
    from
    to
    value
    txHash
    blockNumber
  }
}
```

### Filter by Block Range

```graphql
{
  transfers(
    where: { blockNumber_gte: "5280000", blockNumber_lte: "5290000" }
    orderBy: blockNumber
    first: 20
  ) {
    from
    to
    value
    blockNumber
  }
}
```

## Query dari Frontend (React)

```javascript
import { useQuery, gql } from "@apollo/client";

const GET_TRANSFERS = gql`
  query GetTransfers($first: Int!) {
    transfers(
      orderBy: blockNumber
      orderDirection: desc
      first: $first
    ) {
      from
      to
      value
      blockNumber
      timestamp
    }
  }
`;

function TransferList() {
  const { loading, error, data } = useQuery(GET_TRANSFERS, {
    variables: { first: 10 },
  });

  if (loading) return <p>Loading...</p>;
  if (error) return <p>Error: {error.message}</p>;

  return (
    <ul>
      {data.transfers.map((t) => (
        <li key={t.blockNumber}>
          {t.from.slice(0, 8)}... → {t.to.slice(0, 8)}... : {t.value} WETH
        </li>
      ))}
    </ul>
  );
}
```

## Query dari Terminal (curl)

```bash
curl -X POST \
  https://api.studio.thegraph.com/query/1758382/weth-sepolia-events/v0.0.1 \
  -H "Content-Type: application/json" \
  -d '{"query": "{ transfers(first: 5, orderBy: blockNumber, orderDirection: desc) { from to value blockNumber } }"}'
```

## Redeploy (Update Schema/Mapping)

Kalau ada perubahan di schema atau mapping:

```bash
# 1. Codegen ulang
npx graph codegen

# 2. Build ulang
npx graph build

# 3. Deploy ulang (version label baru)
npx graph deploy \
  --node https://api.studio.thegraph.com/deploy/ \
  --deploy-key <DEPLOY_KEY> \
  weth-sepolia-events
```

Input version label baru (contoh: `v0.0.2`).

## Project Structure

```
weth-sepolia-events/
├── subgraph.yaml        ← Manifest: contract, events, handlers
├── schema.graphql       ← Entity definitions (Transfer, TokenHolder)
├── abis/
│   └── WETH.json        ← ABI untuk decode events
├── src/
│   └── mapping.ts       ← Event handler logic (AssemblyScript)
├── query_example.graphql ← Contoh queries
├── package.json
└── README.md
```

## Links

- **Subgraph Studio:** https://thegraph.com/studio/subgraph/weth-sepolia-events
- **Query URL:** https://api.studio.thegraph.com/query/1758382/weth-sepolia-events/v0.0.1
- **WETH on Sepolia:** https://sepolia.etherscan.io/address/0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9
- **The Graph Docs:** https://thegraph.com/docs/
