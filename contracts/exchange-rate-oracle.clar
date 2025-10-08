(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u200))
(define-constant err-invalid-currency (err u201))
(define-constant err-rate-too-old (err u202))
(define-constant err-invalid-rate (err u203))
(define-constant err-unauthorized-oracle (err u204))

(define-data-var rate-validity-blocks uint u144)

(define-map exchange-rates
  { from-currency: (string-ascii 10), to-currency: (string-ascii 10) }
  { 
    rate: uint,
    decimals: uint,
    updated-at: uint,
    oracle: principal
  }
)

(define-map authorized-oracles
  { oracle: principal }
  { authorized: bool, currency-pairs: (list 20 (string-ascii 10)) }
)

(define-map currency-info
  { currency: (string-ascii 10) }
  { decimals: uint, symbol: (string-ascii 10), active: bool }
)

(define-read-only (get-exchange-rate (from-currency (string-ascii 10)) (to-currency (string-ascii 10)))
  (map-get? exchange-rates { from-currency: from-currency, to-currency: to-currency })
)

(define-read-only (is-rate-valid (from-currency (string-ascii 10)) (to-currency (string-ascii 10)))
  (match (get-exchange-rate from-currency to-currency)
    rate-data 
    (let ((blocks-since-update (- stacks-block-height (get updated-at rate-data))))
      (<= blocks-since-update (var-get rate-validity-blocks)))
    false
  )
)

(define-read-only (calculate-conversion (amount uint) (from-currency (string-ascii 10)) (to-currency (string-ascii 10)))
  (match (get-exchange-rate from-currency to-currency)
    rate-data
    (if (is-rate-valid from-currency to-currency)
      (ok (/ (* amount (get rate rate-data)) (pow u10 (get decimals rate-data))))
      err-rate-too-old)
    err-invalid-currency
  )
)

(define-public (register-currency (currency (string-ascii 10)) (decimals uint) (symbol (string-ascii 10)))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (map-set currency-info
      { currency: currency }
      { decimals: decimals, symbol: symbol, active: true }
    )
    (ok currency)
  )
)

(define-public (authorize-oracle (oracle principal) (currency-pairs (list 20 (string-ascii 10))))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (map-set authorized-oracles
      { oracle: oracle }
      { authorized: true, currency-pairs: currency-pairs }
    )
    (ok oracle)
  )
)

(define-public (update-exchange-rate 
  (from-currency (string-ascii 10)) 
  (to-currency (string-ascii 10))
  (rate uint)
  (decimals uint)
)
  (begin
    (asserts! (> rate u0) err-invalid-rate)
    (asserts! (<= decimals u18) err-invalid-rate)
    (asserts! (is-some (map-get? authorized-oracles { oracle: tx-sender })) err-unauthorized-oracle)
    
    (map-set exchange-rates
      { from-currency: from-currency, to-currency: to-currency }
      {
        rate: rate,
        decimals: decimals,
        updated-at: stacks-block-height,
        oracle: tx-sender
      }
    )
    (ok rate)
  )
)

(define-public (set-rate-validity-blocks (blocks uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set rate-validity-blocks blocks)
    (ok blocks)
  )
)

