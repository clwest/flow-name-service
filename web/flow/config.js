import { config } from "@onflow/fcl";

config({
    // The name of teh Dapp to show when connecting the wallet
    "app.detail.title": "Flow Name Service",
    // An image to use as the icon for our dApp when connectiong to a wallet
    "app.detail.icon": "httpps://placekitten.com/g/200/200",
    // RPC URL for Flow Testnet
    "accessNode.api": "https://rest-testnet.onflow.org",
    // A URL to discover the various wallets compatible with this network
    // FCL automatically adds support for all wallets which support Testnet 
    "discovery.wallet": "https://fcl-discovery.onflow.org/testnet/authn",
    // Alias for the Domains Contractor API
    // UPDATE THIS TO THE ADDRESS OF DEPLOYED CONTRACT
    "0xDomains": "0x2566f24c5d792f8f",
    // Testnet aliases for NonFungibleToken and FungibleToken contracts
    "0xNonFungibleToken": "0x631e88ae7f1d7c20",
    "0xFungibleToken": "0x9a0766d93b6608b7",
});