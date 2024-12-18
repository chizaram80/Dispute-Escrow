;; Escrow Smart Contract

;; Constants for validation
(define-constant MINIMUM-TIMEOUT-BLOCKS u144)  ;; Minimum 1 day (assuming ~10min per block)
(define-constant MAXIMUM-TIMEOUT-BLOCKS u14400)  ;; Maximum 100 days
(define-constant MINIMUM-TRANSACTION-AMOUNT u1000)  ;; Minimum transaction amount
(define-constant MAXIMUM-TRANSACTION-AMOUNT u100000000000)  ;; Maximum transaction amount

;; Core Constants
(define-constant contract-administrator tx-sender)
(define-constant ERROR-NOT-ADMINISTRATOR (err u100))
(define-constant ERROR-NOT-AUTHORIZED (err u101))
(define-constant ERROR-ESCROW-ALREADY-INITIALIZED (err u102))
(define-constant ERROR-ESCROW-NOT-INITIALIZED (err u103))
(define-constant ERROR-ESCROW-ALREADY-FUNDED (err u104))
(define-constant ERROR-ESCROW-NOT-FUNDED (err u105))
(define-constant ERROR-ESCROW-ALREADY-COMPLETED (err u106))
(define-constant ERROR-INVALID-TRANSACTION-AMOUNT (err u107))
(define-constant ERROR-EXCESSIVE-FEE-PERCENTAGE (err u108))
(define-constant ERROR-ESCROW-NOT-DISPUTED (err u109))
(define-constant ERROR-ESCROW-TIMEOUT-NOT-REACHED (err u110))
(define-constant ERROR-INVALID-RATING-STATUS (err u111))
(define-constant ERROR-INVALID-RATING-VALUE (err u112))
(define-constant ERROR-USER-ESCROW-LIST-FULL (err u113))
(define-constant ERROR-INVALID-TIMEOUT-VALUE (err u114))
(define-constant ERROR-INVALID-PARTICIPANT-PRINCIPALS (err u115))
(define-constant ERROR-AMOUNT-OUTSIDE-BOUNDS (err u116))
(define-constant ERROR-INVALID-ESCROW-ID (err u117))

;; Data Variables
(define-data-var transaction-fee-percentage uint u10) ;; 1% fee
(define-data-var escrow-counter uint u0)
(define-data-var escrow-timeout-duration uint u1440) ;; Default timeout of 1440 blocks

;; Data Maps
(define-map escrow-records
  { escrow-id: uint }
  {
    seller-principal: principal,
    buyer-principal: principal,
    arbiter-principal: principal,
    transaction-amount: uint,
    transaction-fee: uint,
    escrow-status: (string-ascii 20),
    creation-block-height: uint,
    transaction-rating: (optional uint)
  }
)

(define-map participant-escrow-records
  principal
  (list 100 uint)
)

;; Validation Functions
(define-private (is-valid-timeout-duration (block-count uint))
  (and (>= block-count MINIMUM-TIMEOUT-BLOCKS)
       (<= block-count MAXIMUM-TIMEOUT-BLOCKS))
)

(define-private (is-valid-transaction-amount (transaction-amount uint))
  (and (>= transaction-amount MINIMUM-TRANSACTION-AMOUNT)
       (<= transaction-amount MAXIMUM-TRANSACTION-AMOUNT))
)

(define-private (are-valid-participant-principals (seller-principal principal) (buyer-principal principal) (arbiter-principal principal))
  (and
    (not (is-eq seller-principal buyer-principal))
    (not (is-eq seller-principal arbiter-principal))
    (not (is-eq buyer-principal arbiter-principal))
  )
)

(define-private (is-valid-escrow-identifier (escrow-id uint))
  (< escrow-id (var-get escrow-counter))
)

;; Private Functions
(define-private (calculate-transaction-fee (transaction-amount uint))
  (/ (* transaction-amount (var-get transaction-fee-percentage)) u1000)
)

(define-private (transfer-stx-tokens (recipient-principal principal) (transfer-amount uint))
  (if (> transfer-amount u0)
    (stx-transfer? transfer-amount tx-sender recipient-principal)
    (ok true)
  )
)

(define-private (add-escrow-to-participant-record (participant-principal principal) (escrow-id uint))
  (let
    (
      (participant-escrow-list (default-to (list) (map-get? participant-escrow-records participant-principal)))
    )
    (if (< (len participant-escrow-list) u100)
      (ok (map-set participant-escrow-records 
                   participant-principal 
                   (unwrap! (as-max-len? (concat participant-escrow-list (list escrow-id)) u100) ERROR-USER-ESCROW-LIST-FULL)))
      ERROR-USER-ESCROW-LIST-FULL
    )
  )
)

;; Read-only Functions
(define-read-only (get-escrow-details (escrow-id uint))
  (match (map-get? escrow-records { escrow-id: escrow-id })
    entry (ok entry)
    (err u404)
  )
)

(define-read-only (get-escrow-current-status (escrow-id uint))
  (match (map-get? escrow-records { escrow-id: escrow-id })
    entry (ok (get escrow-status entry))
    (err u404)
  )
)

(define-read-only (get-participant-escrows (participant-principal principal))
  (default-to (list) (map-get? participant-escrow-records participant-principal))
)

(define-read-only (get-current-timeout-duration)
  (ok (var-get escrow-timeout-duration))
)

;; Public Functions
(define-public (set-transaction-fee-percentage (new-fee-percentage uint))
  (begin
    (asserts! (is-eq tx-sender contract-administrator) ERROR-NOT-ADMINISTRATOR)
    (asserts! (< new-fee-percentage u1000) ERROR-EXCESSIVE-FEE-PERCENTAGE)
    (ok (var-set transaction-fee-percentage new-fee-percentage))
  )
)

(define-public (set-timeout-duration (new-timeout-duration uint))
  (begin
    (asserts! (is-eq tx-sender contract-administrator) ERROR-NOT-ADMINISTRATOR)
    (asserts! (is-valid-timeout-duration new-timeout-duration) ERROR-INVALID-TIMEOUT-VALUE)
    (ok (var-set escrow-timeout-duration new-timeout-duration))
  )
)

(define-public (create-escrow-transaction (seller-principal principal) (buyer-principal principal) (arbiter-principal principal) (transaction-amount uint))
  (begin
    (asserts! (are-valid-participant-principals seller-principal buyer-principal arbiter-principal) ERROR-INVALID-PARTICIPANT-PRINCIPALS)
    (asserts! (is-valid-transaction-amount transaction-amount) ERROR-AMOUNT-OUTSIDE-BOUNDS)
    (let
      (
        (escrow-id (var-get escrow-counter))
        (transaction-fee (calculate-transaction-fee transaction-amount))
        (total-transaction-amount (+ transaction-amount transaction-fee))
      )
      (asserts! (> transaction-amount u0) ERROR-INVALID-TRANSACTION-AMOUNT)
      (asserts! (is-eq tx-sender buyer-principal) ERROR-NOT-AUTHORIZED)
      (try! (stx-transfer? total-transaction-amount tx-sender (as-contract tx-sender)))
      (map-set escrow-records
        { escrow-id: escrow-id }
        {
          seller-principal: seller-principal,
          buyer-principal: buyer-principal,
          arbiter-principal: arbiter-principal,
          transaction-amount: transaction-amount,
          transaction-fee: transaction-fee,
          escrow-status: "funded",
          creation-block-height: block-height,
          transaction-rating: none
        }
      )
      (var-set escrow-counter (+ escrow-id u1))
      (try! (add-escrow-to-participant-record seller-principal escrow-id))
      (try! (add-escrow-to-participant-record buyer-principal escrow-id))
      (try! (add-escrow-to-participant-record arbiter-principal escrow-id))
      (ok escrow-id)
    )
  )
)

(define-public (release-funds-to-seller (escrow-id uint))
  (begin
    (asserts! (is-valid-escrow-identifier escrow-id) ERROR-INVALID-ESCROW-ID)
    (let
      (
        (escrow-record (unwrap! (map-get? escrow-records { escrow-id: escrow-id }) ERROR-ESCROW-NOT-INITIALIZED))
        (current-status (get escrow-status escrow-record))
      )
      (asserts! (or (is-eq tx-sender (get buyer-principal escrow-record)) (is-eq tx-sender (get arbiter-principal escrow-record))) ERROR-NOT-AUTHORIZED)
      (asserts! (is-eq current-status "funded") ERROR-ESCROW-NOT-FUNDED)
      (try! (as-contract (transfer-stx-tokens (get seller-principal escrow-record) (get transaction-amount escrow-record))))
      (try! (as-contract (transfer-stx-tokens contract-administrator (get transaction-fee escrow-record))))
      (map-set escrow-records
        { escrow-id: escrow-id }
        (merge escrow-record { escrow-status: "completed" })
      )
      (ok true)
    )
  )
)

(define-public (refund-funds-to-buyer (escrow-id uint))
  (begin
    (asserts! (is-valid-escrow-identifier escrow-id) ERROR-INVALID-ESCROW-ID)
    (let
      (
        (escrow-record (unwrap! (map-get? escrow-records { escrow-id: escrow-id }) ERROR-ESCROW-NOT-INITIALIZED))
        (current-status (get escrow-status escrow-record))
      )
      (asserts! (or (is-eq tx-sender (get seller-principal escrow-record)) (is-eq tx-sender (get arbiter-principal escrow-record))) ERROR-NOT-AUTHORIZED)
      (asserts! (is-eq current-status "funded") ERROR-ESCROW-NOT-FUNDED)
      (try! (as-contract (transfer-stx-tokens (get buyer-principal escrow-record) (+ (get transaction-amount escrow-record) (get transaction-fee escrow-record)))))
      (map-set escrow-records
        { escrow-id: escrow-id }
        (merge escrow-record { escrow-status: "refunded" })
      )
      (ok true)
    )
  )
)

(define-public (initiate-dispute (escrow-id uint))
  (begin
    (asserts! (is-valid-escrow-identifier escrow-id) ERROR-INVALID-ESCROW-ID)
    (let
      (
        (escrow-record (unwrap! (map-get? escrow-records { escrow-id: escrow-id }) ERROR-ESCROW-NOT-INITIALIZED))
        (current-status (get escrow-status escrow-record))
      )
      (asserts! (or (is-eq tx-sender (get buyer-principal escrow-record)) (is-eq tx-sender (get seller-principal escrow-record))) ERROR-NOT-AUTHORIZED)
      (asserts! (is-eq current-status "funded") ERROR-ESCROW-NOT-FUNDED)
      (map-set escrow-records
        { escrow-id: escrow-id }
        (merge escrow-record { escrow-status: "disputed" })
      )
      (ok true)
    )
  )
)

(define-public (resolve-dispute-case (escrow-id uint) (resolve-in-favor-of-seller bool))
  (begin
    (asserts! (is-valid-escrow-identifier escrow-id) ERROR-INVALID-ESCROW-ID)
    (let
      (
        (escrow-record (unwrap! (map-get? escrow-records { escrow-id: escrow-id }) ERROR-ESCROW-NOT-INITIALIZED))
        (current-status (get escrow-status escrow-record))
      )
      (asserts! (is-eq tx-sender (get arbiter-principal escrow-record)) ERROR-NOT-AUTHORIZED)
      (asserts! (is-eq current-status "disputed") ERROR-ESCROW-NOT-DISPUTED)
      (if resolve-in-favor-of-seller
        (begin
          (try! (as-contract (transfer-stx-tokens (get seller-principal escrow-record) (get transaction-amount escrow-record))))
          (try! (as-contract (transfer-stx-tokens contract-administrator (get transaction-fee escrow-record))))
        )
        (try! (as-contract (transfer-stx-tokens (get buyer-principal escrow-record) (+ (get transaction-amount escrow-record) (get transaction-fee escrow-record)))))
      )
      (map-set escrow-records
        { escrow-id: escrow-id }
        (merge escrow-record { escrow-status: "resolved" })
      )
      (ok true)
    )
  )
)

(define-public (cancel-escrow-transaction (escrow-id uint))
  (begin
    (asserts! (is-valid-escrow-identifier escrow-id) ERROR-INVALID-ESCROW-ID)
    (let
      (
        (escrow-record (unwrap! (map-get? escrow-records { escrow-id: escrow-id }) ERROR-ESCROW-NOT-INITIALIZED))
        (current-status (get escrow-status escrow-record))
        (creation-timestamp (get creation-block-height escrow-record))
      )
      (asserts! (is-eq tx-sender (get buyer-principal escrow-record)) ERROR-NOT-AUTHORIZED)
      (asserts! (is-eq current-status "funded") ERROR-ESCROW-NOT-FUNDED)
      (asserts! (> block-height (+ creation-timestamp (var-get escrow-timeout-duration))) ERROR-ESCROW-TIMEOUT-NOT-REACHED)
      (try! (as-contract (transfer-stx-tokens (get buyer-principal escrow-record) (+ (get transaction-amount escrow-record) (get transaction-fee escrow-record)))))
      (map-set escrow-records
        { escrow-id: escrow-id }
        (merge escrow-record { escrow-status: "cancelled" })
      )
      (ok true)
    )
  )
)

(define-public (extend-escrow-timeout (escrow-id uint) (timeout-extension uint))
  (begin
    (asserts! (is-valid-escrow-identifier escrow-id) ERROR-INVALID-ESCROW-ID)
    (let
      (
        (escrow-record (unwrap! (map-get? escrow-records { escrow-id: escrow-id }) ERROR-ESCROW-NOT-INITIALIZED))
        (current-status (get escrow-status escrow-record))
      )
      (asserts! (or (is-eq tx-sender (get buyer-principal escrow-record)) (is-eq tx-sender (get seller-principal escrow-record))) ERROR-NOT-AUTHORIZED)
      (asserts! (is-eq current-status "funded") ERROR-ESCROW-NOT-FUNDED)
      (map-set escrow-records
        { escrow-id: escrow-id }
        (merge escrow-record { creation-block-height: (+ block-height timeout-extension) })
      )
      (ok true)
    )
  )
)

(define-public (rate-escrow-transaction (escrow-id uint) (rating-value uint))
  (begin
    (asserts! (is-valid-escrow-identifier escrow-id) ERROR-INVALID-ESCROW-ID)
    (let
      (
        (escrow-record (unwrap! (map-get? escrow-records { escrow-id: escrow-id }) ERROR-ESCROW-NOT-INITIALIZED))
        (current-status (get escrow-status escrow-record))
      )
      (asserts! (or (is-eq tx-sender (get buyer-principal escrow-record)) (is-eq tx-sender (get seller-principal escrow-record))) ERROR-NOT-AUTHORIZED)
      (asserts! (or (is-eq current-status "completed") (is-eq current-status "refunded") (is-eq current-status "resolved")) ERROR-INVALID-RATING-STATUS)
      (asserts! (<= rating-value u5) ERROR-INVALID-RATING-VALUE)
      (map-set escrow-records
        { escrow-id: escrow-id }
        (merge escrow-record { transaction-rating: (some rating-value) })
      )
      (ok true)
    )
  )
)