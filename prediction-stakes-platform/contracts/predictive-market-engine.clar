;; Policy Prediction Market Smart Contract
;; This contract enables the creation and management of decentralized prediction markets
;; for policy outcomes. Users can create markets, place bets on outcomes, resolve markets
;; when outcomes are known, claim winnings for correct predictions, and manage market
;; lifecycle including expiration and cleanup.

;; Error Constants
(define-constant ERR-INVALID-CLOSING-HEIGHT (err u1))
(define-constant ERR-MARKET-ALREADY-CLOSED (err u2))
(define-constant ERR-MARKET-ALREADY-RESOLVED (err u3))
(define-constant ERR-INVALID-BET-PARAMETERS (err u4))
(define-constant ERR-MARKET-DOES-NOT-EXIST (err u5))
(define-constant ERR-INSUFFICIENT-BALANCE (err u6))
(define-constant ERR-MARKET-STILL-OPEN (err u7))
(define-constant ERR-NO-BET-FOUND (err u8))
(define-constant ERR-MARKET-NOT-RESOLVED-YET (err u9))
(define-constant ERR-PREDICTION-INCORRECT (err u10))
(define-constant ERR-MARKET-ALREADY-EXPIRED (err u11))
(define-constant ERR-MARKET-NOT-EXPIRED-YET (err u12))
(define-constant ERR-UNAUTHORIZED-ACCESS (err u13))
(define-constant ERR-BET-AMOUNT-TOO-SMALL (err u14))
(define-constant ERR-BET-AMOUNT-TOO-LARGE (err u15))
(define-constant ERR-INVALID-INPUT-PARAMETER (err u16))
(define-constant ERR-INVALID-MARKET-ID (err u17))

;; Validation Constants
(define-constant MAX-ALLOWED-CLOSING-DELAY u52560) ;; ~1 year in blocks
(define-constant MIN-REQUIRED-CLOSING-DELAY u144)  ;; ~1 day in blocks
(define-constant MAX-ALLOWED-EXPIRY-WINDOW u105120) ;; ~2 years in blocks
(define-constant MIN-DESCRIPTION-CHARS u10) ;; Minimum required description length

;; Data Variables
(define-data-var platform-name (string-ascii 50) "PolicyPrediction: Decentralized Policy Markets")
(define-data-var market-id-counter uint u1)
(define-data-var platform-administrator principal tx-sender)

;; Configuration Parameters
(define-data-var market-expiration-period uint u10000)
(define-data-var minimum-bet-amount uint u10)
(define-data-var maximum-bet-amount uint u1000000)

;; Data Structures
(define-map prediction-markets
  { market-id: uint }
  {
    market-description: (string-ascii 256),
    actual-outcome: (optional bool),
    closing-height: uint,
    expiration-height: uint,
    market-creator: principal
  }
)

(define-map user-bets
  { market-id: uint, better: principal }
  { bet-amount: uint, predicted-outcome: bool }
)

;; Validation Helpers
(define-private (is-valid-market-id? (market-id uint))
  (< market-id (var-get market-id-counter))
)

(define-private (is-market-expired? (market-id uint))
  (let ((market-data (unwrap! (map-get? prediction-markets { market-id: market-id }) false)))
    (>= block-height (get expiration-height market-data))
  )
)

(define-private (is-valid-description-length? (description (string-ascii 256)))
  (and 
    (>= (len description) MIN-DESCRIPTION-CHARS)
    (<= (len description) u256)
  )
)

(define-private (is-valid-closing-height? (closing-height uint))
  (let 
    (
      (height-difference (- closing-height block-height))
    )
    (and
      (>= height-difference MIN-REQUIRED-CLOSING-DELAY)
      (<= height-difference MAX-ALLOWED-CLOSING-DELAY)
    )
  )
)

(define-private (is-valid-expiration-height? (closing-height uint) (expiration-height uint))
  (let
    (
      (expiration-window (- expiration-height closing-height))
    )
    (and
      (> expiration-height closing-height)
      (<= expiration-window MAX-ALLOWED-EXPIRY-WINDOW)
    )
  )
)

(define-private (is-valid-bet-amount? (amount uint))
  (and
    (>= amount (var-get minimum-bet-amount))
    (<= amount (var-get maximum-bet-amount))
  )
)

;; Verify market ID exists before deletion
(define-private (validate-market-id-before-delete (market-id uint))
  (match (map-get? prediction-markets { market-id: market-id })
    market-data true
    false)
)

;; Verify user bet exists before deletion
(define-private (validate-user-bet-before-delete (market-id uint) (user principal))
  (match (map-get? user-bets { market-id: market-id, better: user })
    bet-data true
    false)
)

;; Market Creation & Management
;; Create a new prediction market with validation
(define-public (create-prediction-market (description (string-ascii 256)) (closing-height uint))
  (let
    (
      (new-market-id (var-get market-id-counter))
      (calculated-expiration-height (+ closing-height (var-get market-expiration-period)))
    )
    ;; Input validation
    (asserts! (is-valid-description-length? description) ERR-INVALID-INPUT-PARAMETER)
    (asserts! (is-valid-closing-height? closing-height) ERR-INVALID-CLOSING-HEIGHT)
    (asserts! (is-valid-expiration-height? closing-height calculated-expiration-height) ERR-INVALID-INPUT-PARAMETER)
    
    (map-set prediction-markets
      { market-id: new-market-id }
      {
        market-description: description,
        actual-outcome: none,
        closing-height: closing-height,
        expiration-height: calculated-expiration-height,
        market-creator: tx-sender
      }
    )
    (var-set market-id-counter (+ new-market-id u1))
    (ok new-market-id)
  )
)

;; Betting Functions
;; Place a bet on a market outcome
(define-public (place-prediction-bet (market-id uint) (predicted-outcome bool) (bet-amount uint))
  (let
    (
      (existing-bet (default-to { bet-amount: u0, predicted-outcome: false } 
                      (map-get? user-bets { market-id: market-id, better: tx-sender })))
    )
    ;; Input validation
    (asserts! (is-valid-market-id? market-id) ERR-MARKET-DOES-NOT-EXIST)
    (asserts! (is-valid-bet-amount? bet-amount) ERR-INVALID-BET-PARAMETERS)
    (let
      (
        (market-data (unwrap! (map-get? prediction-markets { market-id: market-id }) ERR-MARKET-DOES-NOT-EXIST))
        (total-bet-amount (+ bet-amount (get bet-amount existing-bet)))
      )
      ;; Additional validation
      (asserts! (<= total-bet-amount (var-get maximum-bet-amount)) ERR-BET-AMOUNT-TOO-LARGE)
      (asserts! (< block-height (get closing-height market-data)) ERR-MARKET-ALREADY-CLOSED)
      (asserts! (is-none (get actual-outcome market-data)) ERR-MARKET-ALREADY-RESOLVED)
      (asserts! (>= (stx-get-balance tx-sender) bet-amount) ERR-INSUFFICIENT-BALANCE)
      
      ;; Update the bet record
      (map-set user-bets
        { market-id: market-id, better: tx-sender }
        { bet-amount: total-bet-amount, predicted-outcome: predicted-outcome }
      )
      ;; Transfer funds to contract
      (stx-transfer? bet-amount tx-sender (as-contract tx-sender))
    )
  )
)

;; Market Resolution Functions

;; Resolve a market with the actual outcome
(define-public (resolve-market-outcome (market-id uint) (outcome bool))
  (let 
    (
      (market-data (unwrap! (map-get? prediction-markets { market-id: market-id }) ERR-MARKET-DOES-NOT-EXIST))
    )
    (asserts! (is-valid-market-id? market-id) ERR-INVALID-MARKET-ID)
    (asserts! (>= block-height (get closing-height market-data)) ERR-MARKET-STILL-OPEN)
    (asserts! (is-none (get actual-outcome market-data)) ERR-MARKET-ALREADY-RESOLVED)
    (asserts! (not (is-market-expired? market-id)) ERR-MARKET-ALREADY-EXPIRED)
    (asserts! (or 
                (is-eq tx-sender (get market-creator market-data))
                (is-eq tx-sender (var-get platform-administrator))
              ) ERR-UNAUTHORIZED-ACCESS)
    
    (map-set prediction-markets
      { market-id: market-id }
      (merge market-data { actual-outcome: (some outcome) })
    )
    (ok true)
  )
)

;; Claim winnings for a correct prediction
(define-public (claim-prediction-winnings (market-id uint))
  (begin
    ;; Validate market-id first
    (asserts! (is-valid-market-id? market-id) ERR-INVALID-MARKET-ID)
    
    (let
      (
        (market-data (unwrap! (map-get? prediction-markets { market-id: market-id }) ERR-MARKET-DOES-NOT-EXIST))
        (user-bet (unwrap! (map-get? user-bets { market-id: market-id, better: tx-sender }) ERR-NO-BET-FOUND))
        (market-outcome (unwrap! (get actual-outcome market-data) ERR-MARKET-NOT-RESOLVED-YET))
      )
      (asserts! (is-eq (get predicted-outcome user-bet) market-outcome) ERR-PREDICTION-INCORRECT)
      
      ;; Verify user bet exists before deletion
      (asserts! (validate-user-bet-before-delete market-id tx-sender) ERR-NO-BET-FOUND)
      
      ;; Process payment - could implement more complex payout logic here
      (let ((payout-amount (get bet-amount user-bet)))
        ;; Delete the bet record to prevent double-claiming
        (map-delete user-bets { market-id: market-id, better: tx-sender })
        ;; Transfer winnings
        (as-contract (stx-transfer? payout-amount tx-sender tx-sender))
      )
    )
  )
)

;; Market Cleanup Functions

;; Refund bets for expired markets
(define-public (refund-bet-from-expired-market (market-id uint))
  (begin
    ;; Validate market-id first
    (asserts! (is-valid-market-id? market-id) ERR-INVALID-MARKET-ID)
    
    (let
      (
        (market-data (unwrap! (map-get? prediction-markets { market-id: market-id }) ERR-MARKET-DOES-NOT-EXIST))
        (user-bet (unwrap! (map-get? user-bets { market-id: market-id, better: tx-sender }) ERR-NO-BET-FOUND))
      )
      (asserts! (>= block-height (get expiration-height market-data)) ERR-MARKET-NOT-EXPIRED-YET)
      (asserts! (is-none (get actual-outcome market-data)) ERR-MARKET-ALREADY-RESOLVED)
      
      ;; Verify user bet exists before deletion
      (asserts! (validate-user-bet-before-delete market-id tx-sender) ERR-NO-BET-FOUND)
      
      (let ((refund-amount (get bet-amount user-bet)))
        ;; Delete the bet record
        (map-delete user-bets { market-id: market-id, better: tx-sender })
        ;; Return funds to user
        (as-contract (stx-transfer? refund-amount tx-sender tx-sender))
      )
    )
  )
)

;; Clean up expired market data
(define-public (cleanup-expired-market (market-id uint))
  (begin
    ;; Validate market-id first
    (asserts! (is-valid-market-id? market-id) ERR-INVALID-MARKET-ID)
    
    (let
      (
        (market-data (unwrap! (map-get? prediction-markets { market-id: market-id }) ERR-MARKET-DOES-NOT-EXIST))
      )
      (asserts! (>= block-height (get expiration-height market-data)) ERR-MARKET-NOT-EXPIRED-YET)
      (asserts! (or 
                  (is-eq tx-sender (get market-creator market-data))
                  (is-eq tx-sender (var-get platform-administrator))
                ) ERR-UNAUTHORIZED-ACCESS)
      
      ;; Verify market exists before deletion
      (asserts! (validate-market-id-before-delete market-id) ERR-MARKET-DOES-NOT-EXIST)
      
      ;; Delete the market record
      (map-delete prediction-markets { market-id: market-id })
      (ok true)
    )
  )
)

;; Configuration Management

;; Update the expiration period with validation
(define-public (update-expiration-period (new-period uint))
  (begin
    (asserts! (is-eq tx-sender (var-get platform-administrator)) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (and 
      (>= new-period u1000)  ;; Minimum ~1 day in blocks
      (<= new-period u52560) ;; Maximum ~1 year in blocks
    ) ERR-INVALID-INPUT-PARAMETER)
    (ok (var-set market-expiration-period new-period))
  )
)

;; Update the minimum allowed bet amount
(define-public (update-minimum-bet-amount (new-minimum uint))
  (begin
    (asserts! (is-eq tx-sender (var-get platform-administrator)) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (and 
      (>= new-minimum u1)
      (< new-minimum (var-get maximum-bet-amount))
      (<= new-minimum u1000000) ;; Upper limit for minimum bet
    ) ERR-INVALID-INPUT-PARAMETER)
    (ok (var-set minimum-bet-amount new-minimum))
  )
)

;; Update the maximum allowed bet amount
(define-public (update-maximum-bet-amount (new-maximum uint))
  (begin
    (asserts! (is-eq tx-sender (var-get platform-administrator)) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (and 
      (> new-maximum (var-get minimum-bet-amount))
      (<= new-maximum u1000000000000)
      (>= new-maximum u1000) ;; Lower limit for maximum bet
    ) ERR-INVALID-INPUT-PARAMETER)
    (ok (var-set maximum-bet-amount new-maximum))
  )
)

;; Administrative Functions
;; Get the current contract administrator
(define-read-only (get-platform-administrator)
  (ok (var-get platform-administrator))
)

;; Transfer administrative control
(define-public (transfer-administrative-rights (new-administrator principal))
  (begin
    (asserts! (is-eq tx-sender (var-get platform-administrator)) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (not (is-eq new-administrator (var-get platform-administrator))) ERR-INVALID-INPUT-PARAMETER)
    (ok (var-set platform-administrator new-administrator))
  )
)

;; Update platform name
(define-public (update-platform-name (new-name (string-ascii 50)))
  (begin
    (asserts! (is-eq tx-sender (var-get platform-administrator)) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (> (len new-name) u0) ERR-INVALID-INPUT-PARAMETER)
    (ok (var-set platform-name new-name))
  )
)

;; Read-only Functions

;; Get market details
(define-read-only (get-market-details (market-id uint))
  (map-get? prediction-markets { market-id: market-id })
)

;; Get user bet information
(define-read-only (get-user-bet (market-id uint) (user principal))
  (map-get? user-bets { market-id: market-id, better: user })
)

;; Get platform configuration
(define-read-only (get-platform-configuration)
  {
    platform-name: (var-get platform-name),
    market-expiration-period: (var-get market-expiration-period),
    minimum-bet-amount: (var-get minimum-bet-amount),
    maximum-bet-amount: (var-get maximum-bet-amount)
  }
)