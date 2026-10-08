import React from "react";
import ReactDOM from "react-dom/client";
import { WagmiProvider } from "wagmi";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { RainbowKitProvider, darkTheme } from "@rainbow-me/rainbowkit";
import { ApolloClient, InMemoryCache, HttpLink } from "@apollo/client";
import { ApolloProvider } from "@apollo/client/react";
import { config } from "./config/wagmi";
import App from "./App.jsx";

const apolloClient = new ApolloClient({
  link: new HttpLink({
    uri: "https://api.studio.thegraph.com/query/1758382/weth-sepolia-events/v0.0.1",
  }),
  cache: new InMemoryCache(),
});

// RainbowKit CSS — wajib import buat modal + connect button
import "@rainbow-me/rainbowkit/styles.css";

import "./index.css";

// TanStack Query client — handle caching, refetch, loading states
const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      refetchOnWindowFocus: false,
      retry: 2,
    },
  },
});

ReactDOM.createRoot(document.getElementById("root")).render(
  <React.StrictMode>
    <WagmiProvider config={config}>
      <QueryClientProvider client={queryClient}>
        <ApolloProvider client={apolloClient}>
          <RainbowKitProvider theme={darkTheme({ accentColor: "#e94560" })}>
            <App />
          </RainbowKitProvider>
        </ApolloProvider>
      </QueryClientProvider>
    </WagmiProvider>
  </React.StrictMode>
);
