# Escrow Smart Contract Documentation

## Overview
This smart contract implements a secure escrow system for facilitating trusted transactions between buyers and sellers, with support for arbitration. The contract handles STX token transfers and includes features such as dispute resolution, timeouts, and transaction ratings.

## Key Features
- Three-party escrow system (buyer, seller, and arbiter)
- Automated fee handling
- Dispute resolution mechanism
- Transaction timeout protection
- Rating system for completed transactions
- Transaction amount limits for security
- Comprehensive participant validation

## Contract Parameters

### Transaction Limits
- Minimum Transaction Amount: 1,000 STX
- Maximum Transaction Amount: 100,000,000,000 STX
- Default Transaction Fee: 1% (configurable by administrator)

### Timeouts
- Minimum Timeout: 144 blocks (~1 day at 10 minutes per block)
- Maximum Timeout: 14,400 blocks (~100 days)
- Default Timeout: 1,440 blocks (~10 days)

## Main Functions

### Creating an Escrow
```clarity
(create-escrow-transaction seller-principal buyer-principal arbiter-principal transaction-amount)
```
Creates a new escrow transaction with specified participants and amount. The buyer must call this function and provide the full amount plus fees.

### Releasing Funds
```clarity
(release-funds-to-seller escrow-id)
```
Releases the escrowed funds to the seller. Can be called by either the buyer or arbiter.

### Refunding
```clarity
(refund-funds-to-buyer escrow-id)
```
Returns the escrowed funds to the buyer. Can be called by either the seller or arbiter.

### Dispute Resolution
```clarity
(initiate-dispute escrow-id)
```
Initiates a dispute for an escrow transaction. Can be called by either buyer or seller.

```clarity
(resolve-dispute-case escrow-id resolve-in-favor-of-seller)
```
Resolves a dispute by releasing funds to either party. Can only be called by the arbiter.

### Transaction Management
```clarity
(cancel-escrow-transaction escrow-id)
```
Cancels an escrow transaction after the timeout period. Can only be called by the buyer.

```clarity
(extend-escrow-timeout escrow-id timeout-extension)
```
Extends the timeout period for an escrow transaction. Can be called by either buyer or seller.

### Rating System
```clarity
(rate-escrow-transaction escrow-id rating-value)
```
Allows participants to rate the transaction after completion. Rating must be between 0 and 5.

## Transaction States
1. `funded`: Initial state after escrow creation
2. `disputed`: Dispute has been raised
3. `completed`: Transaction completed successfully
4. `refunded`: Funds returned to buyer
5. `resolved`: Dispute has been resolved
6. `cancelled`: Transaction cancelled after timeout

## Error Handling
The contract includes comprehensive error checking for:
- Invalid participant combinations
- Unauthorized access attempts
- Invalid transaction amounts
- Incorrect state transitions
- Timeout violations
- Invalid ratings

## Administrative Functions

### Fee Management
```clarity
(set-transaction-fee-percentage new-fee-percentage)
```
Allows the administrator to update the transaction fee percentage.

### Timeout Configuration
```clarity
(set-timeout-duration new-timeout-duration)
```
Allows the administrator to update the default timeout duration.

## Read-Only Functions

### Transaction Information
```clarity
(get-escrow-details escrow-id)
```
Returns complete details of an escrow transaction.

```clarity
(get-escrow-current-status escrow-id)
```
Returns the current status of an escrow transaction.

### Participant Records
```clarity
(get-participant-escrows participant-principal)
```
Returns all escrow transactions associated with a participant.

## Security Considerations

### Participant Validation
- Buyer, seller, and arbiter must be different principals
- Transaction amounts must be within defined limits
- Only authorized participants can perform specific actions

### Timeouts
- Minimum timeout ensures sufficient time for transaction completion
- Maximum timeout prevents indefinite fund locking
- Timeout extensions available for complex transactions

### Fund Security
- Funds are held by the contract until explicit release
- All fund transfers require appropriate authorization
- Fee calculations are automated to prevent errors

## Best Practices for Usage

1. **Before Creating an Escrow:**
   - Ensure all participants are aware of their roles
   - Verify transaction amounts and fees
   - Understand timeout implications

2. **During Active Escrow:**
   - Monitor transaction status regularly
   - Communicate clearly between parties
   - Extend timeout if needed before expiration

3. **Dispute Resolution:**
   - Attempt direct resolution before involving arbiter
   - Provide clear evidence to arbiter
   - Understand arbiter's decision is final

4. **After Completion:**
   - Provide transaction rating
   - Verify fund receipt
   - Document transaction details if needed

## Integration Examples

### Creating a New Escrow
```clarity
;; Example of creating an escrow transaction
(contract-call? .escrow-contract create-escrow-transaction 
  'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM  ;; seller
  'ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6XX4CFRK9AG  ;; buyer
  'ST2JHG361ZXG51QTKY2NQCVBPPRRE2KZB1HR05NNC  ;; arbiter
  u1000000)  ;; amount in uSTX
```

### Releasing Funds
```clarity
;; Example of releasing funds to seller
(contract-call? .escrow-contract release-funds-to-seller u1)  ;; escrow-id
```