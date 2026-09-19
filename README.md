# ERC-4626 Yield Vault

A tokenized yield vault where users deposit an ERC-20 asset and receive shares representing their proportion of the vault. Built with Foundry.

## What it does

Users deposit an ERC-20 token and receive shares. As yield is added to the vault, each share becomes worth more tokens. Users can withdraw their assets at any time by burning their shares. Share conversion always reflects the current ratio of total assets to total shares ensuring fair distribution of yield. A management fee is applied on yield and collected by the owner.

## Setup

git clone https://github.com/Alike001/erc4626-yield-vault
cd erc4626-yield-vault
forge install
forge build

## Run Tests

forge test -vvv

## Contract Functions

- deposit() — user deposits assets and receives shares
- mint() — user specifies exact shares to receive and pays the required assets
- withdraw() — user specifies exact assets to receive and burns the required shares
- redeem() — user burns exact shares and receives the corresponding assets
- addYield() — adds yield to the vault increasing share value
- collectFees() — owner collects accumulated management fees

## Key Rules

- First deposit: 1 share = 1 asset
- Share value increases as yield is added
- Deposits round down to protect the vault
- Withdrawals round up to protect the vault
- Zero share deposits are rejected
- Withdrawals exceeding user balance are rejected
- Management fee applied only on yield not on deposits
- Only owner can collect fees

## Built with

- Solidity ^0.8.20
- Foundry
- Forge tests with vm.warp, vm.prank, vm.expectRevert
