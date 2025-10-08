(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u300))
(define-constant err-not-found (err u301))
(define-constant err-unauthorized (err u302))
(define-constant err-invalid-amount (err u303))
(define-constant err-insufficient-balance (err u304))
(define-constant err-schedule-inactive (err u305))
(define-constant err-execution-failed (err u306))
(define-constant err-too-soon (err u307))
(define-constant err-invalid-interval (err u308))

(define-data-var next-schedule-id uint u1)
(define-data-var min-interval-blocks uint u144)

(define-map schedules
  { schedule-id: uint }
  {
    creator: principal,
    recipient: principal,
    amount: uint,
    interval-blocks: uint,
    next-execution: uint,
    total-executions: uint,
    active: bool,
    created-at: uint,
    last-executed: (optional uint)
  }
)

(define-map execution-history
  { schedule-id: uint, execution-index: uint }
  { executed-at: uint, amount: uint, success: bool }
)

(define-map user-schedule-balances
  { user: principal, schedule-id: uint }
  { balance: uint }
)

(define-read-only (get-schedule (schedule-id uint))
  (map-get? schedules { schedule-id: schedule-id })
)

(define-read-only (get-execution (schedule-id uint) (execution-index uint))
  (map-get? execution-history { schedule-id: schedule-id, execution-index: execution-index })
)

(define-read-only (get-schedule-balance (user principal) (schedule-id uint))
  (default-to u0 (get balance (map-get? user-schedule-balances { user: user, schedule-id: schedule-id })))
)

(define-public (create-schedule (recipient principal) (amount uint) (interval-blocks uint))
  (begin
    (asserts! (> amount u0) err-invalid-amount)
    (asserts! (>= interval-blocks (var-get min-interval-blocks)) err-invalid-interval)
    
    (map-set schedules
      { schedule-id: (var-get next-schedule-id) }
      {
        creator: tx-sender,
        recipient: recipient,
        amount: amount,
        interval-blocks: interval-blocks,
        next-execution: (+ stacks-block-height interval-blocks),
        total-executions: u0,
        active: true,
        created-at: stacks-block-height,
        last-executed: none
      }
    )
    (var-set next-schedule-id (+ (var-get next-schedule-id) u1))
    (ok (- (var-get next-schedule-id) u1))
  )
)

(define-public (fund-schedule (schedule-id uint) (amount uint))
  (begin
    (asserts! (> amount u0) err-invalid-amount)
    (asserts! (is-some (get-schedule schedule-id)) err-not-found)
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (map-set user-schedule-balances
      { user: tx-sender, schedule-id: schedule-id }
      { balance: (+ (get-schedule-balance tx-sender schedule-id) amount) }
    )
    (ok amount)
  )
)

(define-public (execute-payment (schedule-id uint))
  (begin
    (asserts! (is-some (get-schedule schedule-id)) err-not-found)
    (let ((schedule-data (unwrap-panic (get-schedule schedule-id))))
      (asserts! (get active schedule-data) err-schedule-inactive)
      (asserts! (>= stacks-block-height (get next-execution schedule-data)) err-too-soon)
      (asserts! (>= (get-schedule-balance (get creator schedule-data) schedule-id) (get amount schedule-data)) err-insufficient-balance)
      
      (map-set user-schedule-balances
        { user: (get creator schedule-data), schedule-id: schedule-id }
        { balance: (- (get-schedule-balance (get creator schedule-data) schedule-id) (get amount schedule-data)) }
      )
      (try! (as-contract (stx-transfer? (get amount schedule-data) tx-sender (get recipient schedule-data))))
      
      (map-set execution-history
        { schedule-id: schedule-id, execution-index: (get total-executions schedule-data) }
        { executed-at: stacks-block-height, amount: (get amount schedule-data), success: true }
      )
      
      (map-set schedules
        { schedule-id: schedule-id }
        (merge schedule-data {
          next-execution: (+ stacks-block-height (get interval-blocks schedule-data)),
          total-executions: (+ (get total-executions schedule-data) u1),
          last-executed: (some stacks-block-height)
        })
      )
      (ok true)
    )
  )
)

(define-public (pause-schedule (schedule-id uint))
  (begin
    (asserts! (is-some (get-schedule schedule-id)) err-not-found)
    (let ((schedule-data (unwrap-panic (get-schedule schedule-id))))
      (asserts! (is-eq tx-sender (get creator schedule-data)) err-unauthorized)
      (map-set schedules { schedule-id: schedule-id } (merge schedule-data { active: false }))
      (ok true)
    )
  )
)

(define-public (resume-schedule (schedule-id uint))
  (begin
    (asserts! (is-some (get-schedule schedule-id)) err-not-found)
    (let ((schedule-data (unwrap-panic (get-schedule schedule-id))))
      (asserts! (is-eq tx-sender (get creator schedule-data)) err-unauthorized)
      (map-set schedules { schedule-id: schedule-id } (merge schedule-data { active: true }))
      (ok true)
    )
  )
)

(define-public (withdraw-from-schedule (schedule-id uint) (amount uint))
  (begin
    (asserts! (> amount u0) err-invalid-amount)
    (asserts! (>= (get-schedule-balance tx-sender schedule-id) amount) err-insufficient-balance)
    (map-set user-schedule-balances
      { user: tx-sender, schedule-id: schedule-id }
      { balance: (- (get-schedule-balance tx-sender schedule-id) amount) }
    )
    (try! (as-contract (stx-transfer? amount tx-sender tx-sender)))
    (ok amount)
  )
)

(define-public (set-min-interval (blocks uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set min-interval-blocks blocks)
    (ok blocks)
  )
)
