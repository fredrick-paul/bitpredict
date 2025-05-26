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