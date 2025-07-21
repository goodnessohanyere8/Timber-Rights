;; Timber Rights Tokenization Smart Contract
;; This contract manages the tokenization of timber rights with comprehensive functionality

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_NOT_FOUND (err u101))
(define-constant ERR_ALREADY_EXISTS (err u102))
(define-constant ERR_INVALID_AMOUNT (err u103))
(define-constant ERR_INSUFFICIENT_BALANCE (err u104))
(define-constant ERR_INVALID_PERIOD (err u105))
(define-constant ERR_EXPIRED (err u106))
(define-constant ERR_NOT_MATURE (err u107))
(define-constant ERR_INVALID_COORDINATES (err u108))
(define-constant ERR_INVALID_SPECIES (err u109))
(define-constant ERR_TRANSFER_FAILED (err u110))

;; Token name and symbol
(define-fungible-token timber-rights-token)

;; Data Variables
(define-data-var total-parcels uint u0)
(define-data-var contract-paused bool false)
(define-data-var base-token-price uint u1000000) ;; Base price in microSTX

;; Data Maps
(define-map timber-parcels uint {
    owner: principal,
    location-lat: int,
    location-lng: int,
    area-hectares: uint,
    tree-species: (string-ascii 50),
    estimated-volume: uint,
    planting-date: uint,
    harvest-date: uint,
    certification: (string-ascii 100),
    token-supply: uint,
    available-tokens: uint,
    price-per-token: uint,
    is-verified: bool,
    is-harvested: bool,
    metadata-uri: (optional (string-ascii 256))
})

(define-map user-balances { user: principal, parcel-id: uint } uint)

(define-map parcel-transactions uint {
    buyer: principal,
    seller: principal,
    token-amount: uint,
    price: uint,
    timestamp: uint
})

(define-map harvest-reports uint {
    parcel-id: uint,
    actual-volume: uint,
    harvest-date: uint,
    certifier: principal,
    sustainability-score: uint,
    report-uri: (string-ascii 256)
})

(define-map user-profiles principal {
    reputation-score: uint,
    total-transactions: uint,
    verified-status: bool,
    join-date: uint
})

(define-map authorized-verifiers principal bool)

;; Read-only functions
(define-read-only (get-parcel-info (parcel-id uint))
    (map-get? timber-parcels parcel-id)
)

(define-read-only (get-user-balance (user principal) (parcel-id uint))
    (default-to u0 (map-get? user-balances { user: user, parcel-id: parcel-id }))
)

(define-read-only (get-total-parcels)
    (var-get total-parcels)
)

(define-read-only (get-contract-paused)
    (var-get contract-paused)
)

(define-read-only (get-user-profile (user principal))
    (map-get? user-profiles user)
)

(define-read-only (get-harvest-report (parcel-id uint))
    (map-get? harvest-reports parcel-id)
)

(define-read-only (is-authorized-verifier (verifier principal))
    (default-to false (map-get? authorized-verifiers verifier))
)

(define-read-only (calculate-token-value (parcel-id uint) (token-amount uint))
    (match (map-get? timber-parcels parcel-id)
        parcel-data (ok (* token-amount (get price-per-token parcel-data)))
        ERR_NOT_FOUND
    )
)

(define-read-only (get-parcel-maturity (parcel-id uint))
    (match (map-get? timber-parcels parcel-id)
        parcel-data 
        (let ((current-time (unwrap-panic (get-block-info? time (- block-height u1)))))
            (if (>= current-time (get harvest-date parcel-data))
                (ok true)
                (ok false)
            )
        )
        ERR_NOT_FOUND
    )
)

;; Private functions
(define-private (is-valid-coordinates (lat int) (lng int))
    (and (>= lat (- 90000000)) (<= lat 90000000) (>= lng (- 180000000)) (<= lng 180000000))
)

(define-private (is-valid-tree-species (species (string-ascii 50)))
    (> (len species) u0)
)

(define-private (update-user-profile (user principal))
    (let ((current-profile (default-to 
            { reputation-score: u0, total-transactions: u0, verified-status: false, join-date: (unwrap-panic (get-block-info? time (- block-height u1))) }
            (map-get? user-profiles user))))
        (map-set user-profiles user (merge current-profile {
            total-transactions: (+ (get total-transactions current-profile) u1)
        }))
    )
)

;; Public functions

;; Initialize user profile
(define-public (initialize-profile)
    (let ((current-time (unwrap-panic (get-block-info? time (- block-height u1)))))
        (begin
            (if (is-none (map-get? user-profiles tx-sender))
                (map-set user-profiles tx-sender {
                    reputation-score: u100,
                    total-transactions: u0,
                    verified-status: false,
                    join-date: current-time
                })
                true
            )
            (ok true)
        )
    )
)

;; Create a new timber parcel
(define-public (create-timber-parcel 
    (location-lat int)
    (location-lng int)
    (area-hectares uint)
    (tree-species (string-ascii 50))
    (estimated-volume uint)
    (planting-date uint)
    (harvest-date uint)
    (certification (string-ascii 100))
    (token-supply uint)
    (price-per-token uint)
    (metadata-uri (optional (string-ascii 256)))
)
    (let ((parcel-id (+ (var-get total-parcels) u1))
          (current-time (unwrap-panic (get-block-info? time (- block-height u1)))))
        (asserts! (not (var-get contract-paused)) ERR_UNAUTHORIZED)
        (asserts! (is-valid-coordinates location-lat location-lng) ERR_INVALID_COORDINATES)
        (asserts! (is-valid-tree-species tree-species) ERR_INVALID_SPECIES)
        (asserts! (> area-hectares u0) ERR_INVALID_AMOUNT)
        (asserts! (> estimated-volume u0) ERR_INVALID_AMOUNT)
        (asserts! (> token-supply u0) ERR_INVALID_AMOUNT)
        (asserts! (> price-per-token u0) ERR_INVALID_AMOUNT)
        (asserts! (> harvest-date current-time) ERR_INVALID_PERIOD)
        (asserts! (> harvest-date planting-date) ERR_INVALID_PERIOD)
        
        ;; Initialize user profile if not exists
        (unwrap-panic (initialize-profile))
        
        ;; Create the parcel
        (map-set timber-parcels parcel-id {
            owner: tx-sender,
            location-lat: location-lat,
            location-lng: location-lng,
            area-hectares: area-hectares,
            tree-species: tree-species,
            estimated-volume: estimated-volume,
            planting-date: planting-date,
            harvest-date: harvest-date,
            certification: certification,
            token-supply: token-supply,
            available-tokens: token-supply,
            price-per-token: price-per-token,
            is-verified: false,
            is-harvested: false,
            metadata-uri: metadata-uri
        })
        
        ;; Set initial balance for owner
        (map-set user-balances { user: tx-sender, parcel-id: parcel-id } token-supply)
        
        ;; Update total parcels
        (var-set total-parcels parcel-id)
        
        (ok parcel-id)
    )
)

;; Purchase timber tokens
(define-public (purchase-tokens (parcel-id uint) (token-amount uint))
    (let ((parcel-data (unwrap! (map-get? timber-parcels parcel-id) ERR_NOT_FOUND))
          (total-cost (* token-amount (get price-per-token parcel-data)))
          (seller (get owner parcel-data))
          (buyer-balance (get-user-balance tx-sender parcel-id))
          (seller-balance (get-user-balance seller parcel-id)))
        
        (asserts! (not (var-get contract-paused)) ERR_UNAUTHORIZED)
        (asserts! (> token-amount u0) ERR_INVALID_AMOUNT)
        (asserts! (<= token-amount (get available-tokens parcel-data)) ERR_INSUFFICIENT_BALANCE)
        (asserts! (not (is-eq tx-sender seller)) ERR_UNAUTHORIZED)
        
        ;; Initialize profiles
        (unwrap-panic (initialize-profile))
        
        ;; Transfer STX from buyer to seller
        (try! (stx-transfer? total-cost tx-sender seller))
        
        ;; Update balances
        (map-set user-balances { user: tx-sender, parcel-id: parcel-id } (+ buyer-balance token-amount))
        (map-set user-balances { user: seller, parcel-id: parcel-id } (- seller-balance token-amount))
        
        ;; Update available tokens
        (map-set timber-parcels parcel-id (merge parcel-data {
            available-tokens: (- (get available-tokens parcel-data) token-amount)
        }))
        
        ;; Record transaction
        (map-set parcel-transactions parcel-id {
            buyer: tx-sender,
            seller: seller,
            token-amount: token-amount,
            price: total-cost,
            timestamp: (unwrap-panic (get-block-info? time (- block-height u1)))
        })
        
        ;; Update user profiles
        (update-user-profile tx-sender)
        (update-user-profile seller)
        
        (ok true)
    )
)

;; Transfer tokens between users
(define-public (transfer-tokens (recipient principal) (parcel-id uint) (token-amount uint))
    (let ((sender-balance (get-user-balance tx-sender parcel-id))
          (recipient-balance (get-user-balance recipient parcel-id)))
        
        (asserts! (not (var-get contract-paused)) ERR_UNAUTHORIZED)
        (asserts! (> token-amount u0) ERR_INVALID_AMOUNT)
        (asserts! (>= sender-balance token-amount) ERR_INSUFFICIENT_BALANCE)
        (asserts! (not (is-eq tx-sender recipient)) ERR_UNAUTHORIZED)
        
        ;; Update balances
        (map-set user-balances { user: tx-sender, parcel-id: parcel-id } (- sender-balance token-amount))
        (map-set user-balances { user: recipient, parcel-id: parcel-id } (+ recipient-balance token-amount))
        
        ;; Update user profiles
        (update-user-profile tx-sender)
        (update-user-profile recipient)
        
        (ok true)
    )
)

;; Verify a timber parcel (only authorized verifiers)
(define-public (verify-parcel (parcel-id uint))
    (let ((parcel-data (unwrap! (map-get? timber-parcels parcel-id) ERR_NOT_FOUND)))
        (asserts! (is-authorized-verifier tx-sender) ERR_UNAUTHORIZED)
        
        (map-set timber-parcels parcel-id (merge parcel-data {
            is-verified: true
        }))
        
        (ok true)
    )
)

;; Submit harvest report
(define-public (submit-harvest-report 
    (parcel-id uint)
    (actual-volume uint)
    (sustainability-score uint)
    (report-uri (string-ascii 256))
)
    (let ((parcel-data (unwrap! (map-get? timber-parcels parcel-id) ERR_NOT_FOUND))
          (current-time (unwrap-panic (get-block-info? time (- block-height u1)))))
        
        (asserts! (is-authorized-verifier tx-sender) ERR_UNAUTHORIZED)
        (asserts! (>= current-time (get harvest-date parcel-data)) ERR_NOT_MATURE)
        (asserts! (> actual-volume u0) ERR_INVALID_AMOUNT)
        (asserts! (<= sustainability-score u100) ERR_INVALID_AMOUNT)
        
        ;; Create harvest report
        (map-set harvest-reports parcel-id {
            parcel-id: parcel-id,
            actual-volume: actual-volume,
            harvest-date: current-time,
            certifier: tx-sender,
            sustainability-score: sustainability-score,
            report-uri: report-uri
        })
        
        ;; Mark parcel as harvested
        (map-set timber-parcels parcel-id (merge parcel-data {
            is-harvested: true
        }))
        
        (ok true)
    )
)

;; Claim harvest proceeds (for token holders)
(define-public (claim-harvest-proceeds (parcel-id uint))
    (let ((parcel-data (unwrap! (map-get? timber-parcels parcel-id) ERR_NOT_FOUND))
          (harvest-data (unwrap! (map-get? harvest-reports parcel-id) ERR_NOT_FOUND))
          (user-token-balance (get-user-balance tx-sender parcel-id))
          (total-supply (get token-supply parcel-data)))
        
        (asserts! (get is-harvested parcel-data) ERR_NOT_MATURE)
        (asserts! (> user-token-balance u0) ERR_INSUFFICIENT_BALANCE)
        
        ;; Calculate proportional proceeds
        (let ((user-share (* user-token-balance u100))
              (total-share (* total-supply u100))
              (proceeds-percentage (/ user-share total-share))
              (base-proceeds (* (get actual-volume harvest-data) (var-get base-token-price)))
              (user-proceeds (/ (* base-proceeds proceeds-percentage) u100)))
            
            ;; Transfer proceeds to user
            (try! (stx-transfer? user-proceeds (as-contract tx-sender) tx-sender))
            
            ;; Reset user balance (tokens are consumed)
            (map-set user-balances { user: tx-sender, parcel-id: parcel-id } u0)
            
            (ok user-proceeds)
        )
    )
)

;; Admin functions
(define-public (add-authorized-verifier (verifier principal))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (map-set authorized-verifiers verifier true)
        (ok true)
    )
)

(define-public (remove-authorized-verifier (verifier principal))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (map-set authorized-verifiers verifier false)
        (ok true)
    )
)

(define-public (pause-contract)
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (var-set contract-paused true)
        (ok true)
    )
)

(define-public (unpause-contract)
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (var-set contract-paused false)
        (ok true)
    )
)

(define-public (update-base-token-price (new-price uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (asserts! (> new-price u0) ERR_INVALID_AMOUNT)
        (var-set base-token-price new-price)
        (ok true)
    )
)

;; Emergency function to update parcel metadata
(define-public (update-parcel-metadata (parcel-id uint) (new-metadata-uri (string-ascii 256)))
    (let ((parcel-data (unwrap! (map-get? timber-parcels parcel-id) ERR_NOT_FOUND)))
        (asserts! (is-eq tx-sender (get owner parcel-data)) ERR_UNAUTHORIZED)
        
        (map-set timber-parcels parcel-id (merge parcel-data {
            metadata-uri: (some new-metadata-uri)
        }))
        
        (ok true)
    )
)