# 🏛️ Onchain Auctions Protocol

> A decentralized auction protocol enabling transparent and trustless auctions on Ethereum Virtual Machine blockchains using USDT.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Solidity](https://img.shields.io/badge/solidity-^0.8.13-blue)](https://docs.soliditylang.org/en/v0.8.13/)
[![Build Status](https://img.shields.io/badge/build-passing-brightgreen)](https://github.com/GushALKDev/evm-onchain-auctions-protocol)

## 📝 Description

OnchainAuctions is a decentralized protocol for managing auctions on Ethereum Virtual Machine blockchains. It provides a secure and transparent way to create, bid on, and settle auctions using ERC20 as the payment token.

## ⚙️ Features

🔐 **Security Features**
- Reentrancy protection
- Input validation
- Access control mechanisms
- Full test coverage

🛠️ **Core Functionality**
- Create custom auctions with flexible parameters
- Place bids with automatic outbid refunds
- Configurable protocol fees
- Secure withdrawal system
- Auction cancellation capability

## 🏗️ Technical Stack

- **Framework**: Foundry
- **Language**: Solidity ^0.8.13
- **Standards**: ERC20
- **Dependencies**: OpenZeppelin Contracts

## 🚀 Quick Start

### Prerequisites

- [Git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)
- [Foundry](https://book.getfoundry.sh/getting-started/installation)

### Installation

1. Clone the repository:
```bash
git clone https://github.com/GushALKDev/evm-onchain-auctions-protocol.git
cd evm-onchain-auctions-protocol
```

2. Install dependencies:
```bash
forge install
```

3. Run tests:
```bash
forge test
```

## 📖 Core Contracts

### Auctions.sol
Main protocol contract handling all auction logic:
```solidity
function createAuction(string name, string description, uint256 startingPrice, uint256 duration)
function bid(uint256 auctionId, uint256 amount)
function bidRefund(uint256 auctionId)
function withdrawAuction(uint256 auctionId)
```

### USDT.sol
Mock USDT token for testing purposes.

## 🔍 Testing

Run the complete test suite:
```bash
forge test -vvv
```

Coverage includes:
- ✅ Auction creation flows
- ✅ Bidding mechanics
- ✅ Refund system
- ✅ Edge cases
- ✅ Access control
- ✅ Fee calculations

## 🔒 Security Considerations

The protocol implements several security measures:
- NonReentrant modifiers on critical functions
- Comprehensive input validation
- Access control mechanisms
- Edge case handling

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
