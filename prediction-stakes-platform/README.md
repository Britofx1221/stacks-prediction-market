# PolicyPrediction: Decentralized Policy Markets

A Clarity smart contract for creating and managing decentralized prediction markets focused on policy outcomes.

## Overview

This smart contract enables users to create prediction markets for policy-related outcomes, place bets, resolve markets, and claim winnings in a decentralized manner. The system handles the entire lifecycle of prediction markets including creation, betting, resolution, payout, and cleanup of expired markets.

## Features

- Create prediction markets with custom descriptions and timeframes
- Place bets on binary (yes/no) outcomes of policy decisions
- Resolve markets with actual outcomes once they are known
- Claim winnings for correct predictions
- Automatic market expiration and refund mechanism
- Administrative controls for platform management

## Contract Structure

The contract is organized into the following components:

1. **Error Constants**: Define all possible error conditions with descriptive codes
2. **Validation Constants**: Constants used for input validation
3. **Data Variables**: Core contract state variables
4. **Configuration Parameters**: Adjustable settings for the platform
5. **Data Structures**: Maps storing market and bet information
6. **Validation Helpers**: Private functions for input validation
7. **Market Functions**: Functions for creating and managing markets
8. **Betting Functions**: Functions for placing bets
9. **Resolution Functions**: Functions for resolving markets and claiming winnings
10. **Cleanup Functions**: Functions for handling expired markets
11. **Configuration Management**: Functions for updating platform settings
12. **Administrative Functions**: Functions for platform administration
13. **Read-only Functions**: Functions for querying contract state

## Key Functions

### Market Creation & Management

- **create-prediction-market**: Create a new prediction market with a specified description and closing block height.

```clarity
(create-prediction-market "Will legislation X pass before the end of the year?" u100000)
```

### Betting

- **place-prediction-bet**: Place a bet on a market outcome (true/false).

```clarity
(place-prediction-bet u1 true u1000)  ;; Market ID, Prediction (yes/no), Amount in uSTX
```

### Market Resolution

- **resolve-market-outcome**: Resolve a market with the actual outcome.

```clarity
(resolve-market-outcome u1 false)  ;; Market ID, Outcome (yes/no)
```

- **claim-prediction-winnings**: Claim winnings for a correct prediction.

```clarity
(claim-prediction-winnings u1)  ;; Market ID
```

### Market Cleanup

- **refund-bet-from-expired-market**: Refund a bet from an expired market.

```clarity
(refund-bet-from-expired-market u1)  ;; Market ID
```

- **cleanup-expired-market**: Clean up an expired market's data.

```clarity
(cleanup-expired-market u1)  ;; Market ID
```

### Configuration

- **update-expiration-period**: Update the market expiration period.
- **update-minimum-bet-amount**: Update the minimum allowed bet amount.
- **update-maximum-bet-amount**: Update the maximum allowed bet amount.

### Administration

- **transfer-administrative-rights**: Transfer administrative control of the contract.
- **update-platform-name**: Update the platform name.

## Error Codes

| Error Code | Description |
|------------|-------------|
| ERR-INVALID-CLOSING-HEIGHT | The closing height is invalid (too soon or too far in the future) |
| ERR-MARKET-ALREADY-CLOSED | The market has already closed for betting |
| ERR-MARKET-ALREADY-RESOLVED | The market outcome has already been resolved |
| ERR-INVALID-BET-PARAMETERS | The betting parameters are invalid |
| ERR-MARKET-DOES-NOT-EXIST | The specified market ID does not exist |
| ERR-INSUFFICIENT-BALANCE | User has insufficient balance to place the bet |
| ERR-MARKET-STILL-OPEN | Attempt to resolve a market that is still open for betting |
| ERR-NO-BET-FOUND | No bet found for the user on this market |
| ERR-MARKET-NOT-RESOLVED-YET | The market has not been resolved yet |
| ERR-PREDICTION-INCORRECT | The user's prediction was incorrect |
| ERR-MARKET-ALREADY-EXPIRED | The market has already expired |
| ERR-MARKET-NOT-EXPIRED-YET | The market has not expired yet |
| ERR-UNAUTHORIZED-ACCESS | User is not authorized to perform this action |
| ERR-BET-AMOUNT-TOO-SMALL | Bet amount is below the minimum |
| ERR-BET-AMOUNT-TOO-LARGE | Bet amount exceeds the maximum |
| ERR-INVALID-INPUT-PARAMETER | An input parameter is invalid |

## Market Lifecycle

1. **Creation**: A user creates a market by providing a description and a closing block height.
2. **Open for Betting**: Users can place bets until the closing block height is reached.
3. **Closed for Betting**: After the closing block height, no more bets can be placed.
4. **Resolution**: The market creator or administrator resolves the market with the actual outcome.
5. **Payout**: Users with correct predictions can claim their winnings.
6. **Expiration**: If a market is not resolved before its expiration height, it expires.
7. **Cleanup**: Expired markets can be cleaned up, and users can claim refunds for their bets.

## Configuration Parameters

- **market-expiration-period**: Number of blocks after the closing height before a market expires.
- **minimum-bet-amount**: Minimum allowed bet amount in uSTX.
- **maximum-bet-amount**: Maximum allowed bet amount in uSTX.

## Getting Started

### Prerequisites

- A Stacks blockchain node
- Clarity CLI for testing

### Deployment

Deploy the contract to the Stacks blockchain using the Stacks CLI:

```
stacks-cli deploy predictive-market-engine.clar
```

### Creating Your First Market

1. Call the `create-prediction-market` function with a description and closing block height.
2. Note the returned market ID for future reference.

### Placing a Bet

1. Call the `place-prediction-bet` function with the market ID, your prediction, and the bet amount.
2. Ensure you have enough STX to cover the bet.

### Checking Market Status

Use the read-only functions to check market details:

```
(get-market-details u1)  ;; Replace u1 with your market ID
```

## Security Considerations

- The contract uses asserts to validate inputs and prevent invalid state changes.
- Administrative functions are protected by ownership checks.
- Bet amounts are limited to prevent excessive exposure.
- Markets have a finite lifespan to prevent dead markets from persisting.

## Customization

The contract can be customized by:

1. Adjusting validation constants to change allowed timeframes.
2. Modifying configuration parameters to change bet limits and expiration periods.
3. Extending data structures to capture additional market information.

## Best Practices

- Create markets with sufficient time for users to place bets.
- Set reasonable closing heights based on when policy outcomes are expected.
- Resolve markets promptly once outcomes are known.
- Use appropriate bet amounts to manage risk.

## Developer Notes

- Block heights are used for timing rather than absolute timestamps.
- The contract assumes proper operation of the Stacks blockchain's STX token for bet handling.
- Additional functions can be added to support more complex betting mechanisms.