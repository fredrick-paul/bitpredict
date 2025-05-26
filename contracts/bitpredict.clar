;; Title: BitPredict - Trustless Bitcoin Price Prediction Markets on Stacks L2

;; Summary:
;; Decentralized derivatives protocol enabling speculators to hedge/predict BTC price movements
;; through non-custodial, transparent contracts settled via Bitcoin oracle data

;; Description:
;; BitPredict implements autonomous prediction markets for BTC/USD price action, combining:
;; - Bitcoin-native settlement via Stacks L2 atomic transactions
;; - Transparent capital pools with verifiable bull/bear commitments
;; - Decentralized resolution via programmable oracle integration
;; - Self-custody design preserving user control of funds
;;
;; Key Features:
;; 1. Market Creation: Permissionless initiation of prediction windows with custom parameters
;; 2. Price Exposure: Users take leveraged positions with STX collateralization
;; 3. Oracle Settlement: Trust-minimized resolution via Bitcoin price feeds
;; 4. Automated Payouts: Instant reward distribution using verifiable outcome math
;; 5. Protocol Economics: Sustainable fee model aligning operator incentives
;;
;; Compliance Framework:
;; - Pure Bitcoin-denominated outcomes (sats/USD)
;; - No synthetic asset creation
;; - Non-custodial architecture
;; - Transparent on-chain audit trail
;; - STX-based fee structure avoiding security classification

;; CONSTANTS & ERROR CODES

;; Administrative constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-OWNER-ONLY (err u100))
(define-constant ERR-INVALID-PARAMETER (err u101))
(define-constant ERR-NOT-FOUND (err u102))
(define-constant ERR-MARKET-CLOSED (err u103))
(define-constant ERR-INVALID-PREDICTION (err u104))
(define-constant ERR-INSUFFICIENT-BALANCE (err u105))
(define-constant ERR-ALREADY-CLAIMED (err u106))

;; PROTOCOL CONFIGURATION

;; Oracle configuration for price feeds
(define-data-var oracle-address principal 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)

;; Market participation parameters
(define-data-var minimum-stake uint u1000000) ;; 1.0 STX minimum stake
(define-data-var protocol-fee uint u2) ;; 2% protocol fee on winnings
(define-data-var market-counter uint u0) ;; Global market ID counter

;; DATA STRUCTURES

;; Market definition and state tracking
(define-map markets
  uint ;; Market ID
  {
    opening-price: uint, ;; BTC/USD opening price (satoshis)
    closing-price: uint, ;; BTC/USD closing price (satoshis)
    bull-commitment: uint, ;; Total bullish positions (STX)
    bear-commitment: uint, ;; Total bearish positions (STX)
    activation-block: uint, ;; Market start block height
    expiration-block: uint, ;; Market end block height
    resolution-status: bool, ;; Settlement completion flag
  }
)

;; User position tracking
(define-map positions
  {
    market: uint,
    participant: principal,
  } ;; Composite key
  {
    direction: (string-ascii 4), ;; Position type: "bull" or "bear"
    amount: uint, ;; STX amount committed
    claimed: bool, ;; Reward claim status
  }
)

;; MARKET CREATION & MANAGEMENT

;; Creates a new Bitcoin price prediction market
(define-public (create-market
    (opening-price uint)
    (activation-block uint)
    (expiration-block uint)
  )
  (let ((new-market-id (var-get market-counter)))
    ;; Authorization check
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
    ;; Parameter validation
    (asserts! (> expiration-block activation-block) ERR-INVALID-PARAMETER)
    (asserts! (> opening-price u0) ERR-INVALID-PARAMETER)
    ;; Initialize new market
    (map-set markets new-market-id {
      opening-price: opening-price,
      closing-price: u0,
      bull-commitment: u0,
      bear-commitment: u0,
      activation-block: activation-block,
      expiration-block: expiration-block,
      resolution-status: false,
    })
    ;; Increment market counter
    (var-set market-counter (+ new-market-id u1))
    (ok new-market-id)
  )
)

;; MARKET PARTICIPATION

;; Allows users to take positions on Bitcoin price direction
(define-public (take-position
    (market-id uint)
    (position (string-ascii 4))
    (stake uint)
  )
  (let (
      (market (unwrap! (map-get? markets market-id) ERR-NOT-FOUND))
      (current-block stacks-block-height)
    )
    ;; Market timing validation
    (asserts!
      (and
        (>= current-block (get activation-block market))
        (< current-block (get expiration-block market))
      )
      ERR-MARKET-CLOSED
    )
    ;; Position validation
    (asserts! (or (is-eq position "bull") (is-eq position "bear"))
      ERR-INVALID-PREDICTION
    )
    (asserts! (>= stake (var-get minimum-stake)) ERR-INVALID-PARAMETER)
    ;; Balance verification
    (asserts! (<= stake (stx-get-balance tx-sender)) ERR-INSUFFICIENT-BALANCE)
    ;; Transfer stake to contract
    (try! (stx-transfer? stake tx-sender (as-contract tx-sender)))
    ;; Record user position
    (map-set positions {
      market: market-id,
      participant: tx-sender,
    } {
      direction: position,
      amount: stake,
      claimed: false,
    })
    ;; Update market commitments
    (map-set markets market-id
      (merge market {
        bull-commitment: (if (is-eq position "bull")
          (+ (get bull-commitment market) stake)
          (get bull-commitment market)
        ),
        bear-commitment: (if (is-eq position "bear")
          (+ (get bear-commitment market) stake)
          (get bear-commitment market)
        ),
      })
    )
    (ok true)
  )
)