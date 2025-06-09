# 🌍 Blockchain Remittance Tracker

A decentralized cross-border remittance platform built on Stacks blockchain with milestone-based payments and low transaction fees.

## 🚀 Features

- 💰 **Low-Fee Transfers**: Minimal platform fees for cross-border remittances
- 🎯 **Milestone-Based Payments**: Break down payments into trackable milestones
- 🔒 **Secure Escrow**: Funds held securely until milestones are completed
- 📊 **Real-Time Tracking**: Monitor remittance progress in real-time
- 🏦 **Built-in Wallet**: Deposit and withdraw STX tokens
- ⚡ **Instant Settlement**: Immediate milestone completion and fund release

## 📋 Contract Overview

The Remittance Tracker enables users to send money across borders with milestone-based delivery. Senders create remittances with specific milestones, and recipients can claim funds as they complete each milestone.

## 🛠️ Usage Instructions

### For Senders

1. **Deposit Funds**
   ```clarity
   (contract-call? .remittance-tracker deposit u1000000)
   ```

2. **Create Remittance**
   ```clarity
   (contract-call? .remittance-tracker create-remittance 
     'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7
     u1000000
     (list "Document verification" "Service delivery" "Final confirmation")
     (list u300000 u500000 u200000))
   ```

3. **Cancel Remittance** (if no milestones completed)
   ```clarity
   (contract-call? .remittance-tracker cancel-remittance u1)
   ```

### For Recipients

1. **Complete Milestone**
   ```clarity
   (contract-call? .remittance-tracker complete-milestone u1 u0)
   ```

2. **Withdraw Funds**
   ```clarity
   (contract-call? .remittance-tracker withdraw u300000)
   ```

### Read-Only Functions

- **Check Remittance Status**
  ```clarity
  (contract-call? .remittance-tracker get-remittance u1)
  ```

- **View Progress**
  ```clarity
  (contract-call? .remittance-tracker get-remittance-progress u1)
  ```

- **Check Balance**
  ```clarity
  (contract-call? .remittance-tracker get-user-balance 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7)
  ```

## 💡 How It Works

1. **Sender** deposits STX and creates a remittance with milestones
2. **Platform** holds funds in escrow and charges a small fee (0.25% default)
3. **Recipient** completes milestones to unlock portions of the payment
4. **Funds** are automatically released as milestones are completed
5. **Tracking** provides real-time progress updates

## 🔧 Configuration

- **Platform Fee**: 0.25% (25 basis points) - adjustable by contract owner
- **Maximum Milestones**: 10 per remittance
- **Milestone Descriptions**: Up to 100 characters each

## 🎯 Example Workflow

```clarity
;; 1. Sender deposits 1 STX
(contract-call? .remittance-tracker deposit u1000000)

;; 2. Create remittance with 3 milestones
(contract-call? .remittance-tracker create-remittance 
  'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7
  u1000000
  (list "ID Verification" "Document Processing" "Transfer Complete")
  (list u400000 u400000 u200000))

;; 3. Recipient completes first milestone
(contract-call? .remittance-tracker complete-milestone u1 u0)

;; 4. Recipient withdraws earned amount
(contract-call? .remittance-tracker withdraw u400000)
```

## 🔐 Security Features

- ✅ Sender authorization for remittance creation and cancellation
- ✅ Recipient authorization for milestone completion
- ✅ Escrow protection preventing double-spending
- ✅ Milestone locking prevents cancellation after progress
- ✅ Balance validation for all operations

## 📈 Benefits

- 🌐 **Global Reach**: Send money anywhere on the Stacks network
- 💸 **Low Costs**: Minimal fees compared to traditional remittance services
- 🔍 **Transparency**: All transactions recorded on blockchain
- ⚡ **Speed**: Near-instant milestone completion and fund release
- 🛡️ **Security**: Decentralized and trustless operation

## 🚀 Getting Started

1. Deploy the contract using Clarinet
2. Fund your account with STX
3. Start sending milestone-based remittances!

---

*Built with ❤️ on Stacks blockchain*
```

**Git Commit Message:**
```
feat: implement blockchain remittance tracker with milestone-based payments
```

**GitHub Pull Request Title:**
```
🌍 Add Blockchain Remittance Tracker MVP with Milestone Payments
