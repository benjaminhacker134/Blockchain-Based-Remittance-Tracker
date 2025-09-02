(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-invalid-amount (err u103))
(define-constant err-already-completed (err u104))
(define-constant err-insufficient-funds (err u105))
(define-constant err-invalid-milestone (err u106))
(define-constant err-remittance-locked (err u107))

(define-constant err-not-expired (err u112))
(define-constant err-expired (err u113))

(define-data-var default-expiration-blocks uint u144)

(define-constant err-dispute-exists (err u108))
(define-constant err-no-dispute (err u109))
(define-constant err-arbitrator-only (err u110))
(define-constant err-cannot-dispute (err u111))

(define-data-var contract-arbitrator principal tx-sender)
(define-data-var dispute-fee uint u100)

(define-data-var next-remittance-id uint u1)
(define-data-var platform-fee-rate uint u25)
(define-data-var total-platform-fees uint u0)

(define-map remittances
  { remittance-id: uint }
  {
    sender: principal,
    recipient: principal,
    amount: uint,
    fee: uint,
    status: (string-ascii 20),
    milestone-count: uint,
    completed-milestones: uint,
    created-at: uint,
    completed-at: (optional uint),
    expires-at: (optional uint)
  }
)

(define-map milestones
  { remittance-id: uint, milestone-index: uint }
  {
    description: (string-ascii 100),
    amount: uint,
    completed: bool,
    completed-at: (optional uint)
  }
)

(define-map user-balances
  { user: principal }
  { balance: uint }
)

(define-read-only (get-remittance (remittance-id uint))
  (map-get? remittances { remittance-id: remittance-id })
)

(define-read-only (get-milestone (remittance-id uint) (milestone-index uint))
  (map-get? milestones { remittance-id: remittance-id, milestone-index: milestone-index })
)

(define-read-only (get-user-balance (user principal))
  (default-to u0 (get balance (map-get? user-balances { user: user })))
)

(define-read-only (get-platform-fee-rate)
  (var-get platform-fee-rate)
)

(define-read-only (get-total-platform-fees)
  (var-get total-platform-fees)
)

(define-read-only (calculate-fee (amount uint))
  (/ (* amount (var-get platform-fee-rate)) u10000)
)

(define-private (update-user-balance (user principal) (amount uint) (add bool))
  (begin
    (if add
      (map-set user-balances { user: user } { balance: (+ (get-user-balance user) amount) })
      (map-set user-balances { user: user } { balance: (- (get-user-balance user) amount) })
    )
    true
  )
)

(define-private (sum-list (amounts (list 10 uint)))
  (fold + amounts u0)
)

(define-public (deposit (amount uint))
  (begin
    (asserts! (> amount u0) err-invalid-amount)
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (update-user-balance tx-sender amount true)
    (ok amount)
  )
)

(define-public (withdraw (amount uint))
  (begin
    (asserts! (> amount u0) err-invalid-amount)
    (asserts! (>= (get-user-balance tx-sender) amount) err-insufficient-funds)
    (try! (as-contract (stx-transfer? amount tx-sender tx-sender)))
    (update-user-balance tx-sender amount false)
    (ok amount)
  )
)

(define-public (create-milestone 
  (remittance-id uint) 
  (milestone-index uint) 
  (description (string-ascii 100)) 
  (amount uint)
)
  (begin
    (map-set milestones
      { remittance-id: remittance-id, milestone-index: milestone-index }
      {
        description: description,
        amount: amount,
        completed: false,
        completed-at: none
      }
    )
    (ok true)
  )
)

(define-public (create-remittance-step1 
  (recipient principal) 
  (amount uint) 
  (milestone-count uint)
)
  (begin
    (asserts! (> amount u0) err-invalid-amount)
    (asserts! (> milestone-count u0) err-invalid-milestone)
    (asserts! (<= milestone-count u10) err-invalid-milestone)
    
    (ok (var-get next-remittance-id))
  )
)

(define-public (create-remittance-step2
  (recipient principal)
  (amount uint)
  (fee uint)
  (milestone-count uint)
)
  (begin
    (asserts! (>= (get-user-balance tx-sender) (+ amount fee)) err-insufficient-funds)
    (update-user-balance tx-sender (+ amount fee) false)
    (var-set total-platform-fees (+ (var-get total-platform-fees) fee))
    
    (map-set remittances
      { remittance-id: (var-get next-remittance-id) }
      {
        sender: tx-sender,
        recipient: recipient,
        amount: amount,
        fee: fee,
        status: "pending",
        milestone-count: milestone-count,
        completed-milestones: u0,
        created-at: stacks-block-height,
        completed-at: none,
        expires-at: none
      }
    )
    
    (var-set next-remittance-id (+ (var-get next-remittance-id) u1))
    (ok (- (var-get next-remittance-id) u1))
  )
)

(define-public (create-simple-remittance
  (recipient principal)
  (amount uint)
  (description1 (string-ascii 100))
  (amount1 uint)
  (description2 (string-ascii 100))
  (amount2 uint)
)
  (begin
    (asserts! (> amount u0) err-invalid-amount)
    (asserts! (is-eq amount (+ amount1 amount2)) err-invalid-amount)
    (asserts! (>= (get-user-balance tx-sender) (+ amount (calculate-fee amount))) err-insufficient-funds)
    
    (update-user-balance tx-sender (+ amount (calculate-fee amount)) false)
    (var-set total-platform-fees (+ (var-get total-platform-fees) (calculate-fee amount)))
    
    (map-set remittances
      { remittance-id: (var-get next-remittance-id) }
      {
        sender: tx-sender,
        recipient: recipient,
        amount: amount,
        fee: (calculate-fee amount),
        status: "pending",
        milestone-count: u2,
        completed-milestones: u0,
        created-at: stacks-block-height,
        completed-at: none,
        expires-at: none
      }
    )
    
    (map-set milestones
      { remittance-id: (var-get next-remittance-id), milestone-index: u0 }
      {
        description: description1,
        amount: amount1,
        completed: false,
        completed-at: none
      }
    )
    
    (map-set milestones
      { remittance-id: (var-get next-remittance-id), milestone-index: u1 }
      {
        description: description2,
        amount: amount2,
        completed: false,
        completed-at: none
      }
    )
    
    (var-set next-remittance-id (+ (var-get next-remittance-id) u1))
    (ok (- (var-get next-remittance-id) u1))
  )
)

(define-public (create-triple-remittance
  (recipient principal)
  (amount uint)
  (description1 (string-ascii 100))
  (amount1 uint)
  (description2 (string-ascii 100))
  (amount2 uint)
  (description3 (string-ascii 100))
  (amount3 uint)
)
  (begin
    (asserts! (> amount u0) err-invalid-amount)
    (asserts! (is-eq amount (+ (+ amount1 amount2) amount3)) err-invalid-amount)
    (asserts! (>= (get-user-balance tx-sender) (+ amount (calculate-fee amount))) err-insufficient-funds)
    
    (update-user-balance tx-sender (+ amount (calculate-fee amount)) false)
    (var-set total-platform-fees (+ (var-get total-platform-fees) (calculate-fee amount)))
    
    (map-set remittances
      { remittance-id: (var-get next-remittance-id) }
      {
        sender: tx-sender,
        recipient: recipient,
        amount: amount,
        fee: (calculate-fee amount),
        status: "pending",
        milestone-count: u3,
        completed-milestones: u0,
        created-at: stacks-block-height,
        completed-at: none,
        expires-at: none
      }
    )
    
    (map-set milestones
      { remittance-id: (var-get next-remittance-id), milestone-index: u0 }
      {
        description: description1,
        amount: amount1,
        completed: false,
        completed-at: none
      }
    )
    
    (map-set milestones
      { remittance-id: (var-get next-remittance-id), milestone-index: u1 }
      {
        description: description2,
        amount: amount2,
        completed: false,
        completed-at: none
      }
    )
    
    (map-set milestones
      { remittance-id: (var-get next-remittance-id), milestone-index: u2 }
      {
        description: description3,
        amount: amount3,
        completed: false,
        completed-at: none
      }
    )
    
    (var-set next-remittance-id (+ (var-get next-remittance-id) u1))
    (ok (- (var-get next-remittance-id) u1))
  )
)

(define-public (complete-milestone (remittance-id uint) (milestone-index uint))
  (begin
    (asserts! (is-some (get-remittance remittance-id)) err-not-found)
    (asserts! (is-some (get-milestone remittance-id milestone-index)) err-not-found)
    
    (asserts! (is-eq tx-sender (get recipient (unwrap-panic (get-remittance remittance-id)))) err-unauthorized)
    (asserts! (is-eq (get status (unwrap-panic (get-remittance remittance-id))) "pending") err-already-completed)
    (asserts! (not (get completed (unwrap-panic (get-milestone remittance-id milestone-index)))) err-already-completed)
    
    (map-set milestones
      { remittance-id: remittance-id, milestone-index: milestone-index }
      (merge (unwrap-panic (get-milestone remittance-id milestone-index)) 
             { completed: true, completed-at: (some stacks-block-height) })
    )
    
    (update-user-balance 
      (get recipient (unwrap-panic (get-remittance remittance-id))) 
      (get amount (unwrap-panic (get-milestone remittance-id milestone-index))) 
      true
    )
    
    (map-set remittances
      { remittance-id: remittance-id }
      (merge (unwrap-panic (get-remittance remittance-id)) 
             { completed-milestones: (+ (get completed-milestones (unwrap-panic (get-remittance remittance-id))) u1) })
    )
    
    (if (is-eq 
          (+ (get completed-milestones (unwrap-panic (get-remittance remittance-id))) u1)
          (get milestone-count (unwrap-panic (get-remittance remittance-id))))
      (map-set remittances
        { remittance-id: remittance-id }
        (merge (unwrap-panic (get-remittance remittance-id)) 
               { 
                 status: "completed", 
                 completed-at: (some stacks-block-height),
                 completed-milestones: (+ (get completed-milestones (unwrap-panic (get-remittance remittance-id))) u1)
               })
      )
      true
    )
    
    (ok true)
  )
)

(define-public (cancel-remittance (remittance-id uint))
  (begin
    (asserts! (is-some (get-remittance remittance-id)) err-not-found)
    (asserts! (is-eq tx-sender (get sender (unwrap-panic (get-remittance remittance-id)))) err-unauthorized)
    (asserts! (is-eq (get status (unwrap-panic (get-remittance remittance-id))) "pending") err-already-completed)
    (asserts! (is-eq (get completed-milestones (unwrap-panic (get-remittance remittance-id))) u0) err-remittance-locked)
    
    (update-user-balance (get sender (unwrap-panic (get-remittance remittance-id))) (get amount (unwrap-panic (get-remittance remittance-id))) true)
    (var-set total-platform-fees (- (var-get total-platform-fees) (get fee (unwrap-panic (get-remittance remittance-id)))))
    
    (map-set remittances
      { remittance-id: remittance-id }
      (merge (unwrap-panic (get-remittance remittance-id)) { status: "cancelled" })
    )
    
    (ok true)
  )
)

(define-public (set-platform-fee-rate (new-rate uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (<= new-rate u1000) err-invalid-amount)
    (var-set platform-fee-rate new-rate)
    (ok new-rate)
  )
)

(define-public (withdraw-platform-fees)
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (> (var-get total-platform-fees) u0) err-invalid-amount)
    (try! (as-contract (stx-transfer? (var-get total-platform-fees) tx-sender contract-owner)))
    (var-set total-platform-fees u0)
    (ok (var-get total-platform-fees))
  )
)

(define-read-only (get-remittance-progress (remittance-id uint))
  (match (get-remittance remittance-id)
    remittance
    (ok {
      progress: (/ (* (get completed-milestones remittance) u100) (get milestone-count remittance)),
      completed: (get completed-milestones remittance),
      total: (get milestone-count remittance),
      status: (get status remittance)
    })
    err-not-found
  )
)

(define-map remittance-disputes
  { remittance-id: uint }
  {
    disputer: principal,
    reason: (string-ascii 200),
    created-at: uint,
    resolved: bool,
    resolution: (optional (string-ascii 200)),
    resolved-at: (optional uint)
  }
)

(define-read-only (get-dispute (remittance-id uint))
  (map-get? remittance-disputes { remittance-id: remittance-id })
)

(define-read-only (has-active-dispute (remittance-id uint))
  (match (get-dispute remittance-id)
    dispute (not (get resolved dispute))
    false
  )
)

(define-public (initiate-dispute (remittance-id uint) (reason (string-ascii 200)))
  (begin
    (asserts! (is-some (get-remittance remittance-id)) err-not-found)
    (asserts! (is-none (get-dispute remittance-id)) err-dispute-exists)
    
    (let ((remittance-data (unwrap-panic (get-remittance remittance-id))))
      (asserts! (is-eq tx-sender (get sender remittance-data)) err-unauthorized)
      (asserts! (is-eq (get status remittance-data) "pending") err-cannot-dispute)
      (asserts! (> (get completed-milestones remittance-data) u0) err-cannot-dispute)
      (asserts! (>= (get-user-balance tx-sender) (var-get dispute-fee)) err-insufficient-funds)
      
      (update-user-balance tx-sender (var-get dispute-fee) false)
      (var-set total-platform-fees (+ (var-get total-platform-fees) (var-get dispute-fee)))
      
      (map-set remittance-disputes
        { remittance-id: remittance-id }
        {
          disputer: tx-sender,
          reason: reason,
          created-at: stacks-block-height,
          resolved: false,
          resolution: none,
          resolved-at: none
        }
      )
      
      (ok true)
    )
  )
)

(define-public (resolve-dispute 
  (remittance-id uint) 
  (favor-sender bool) 
  (resolution (string-ascii 200))
)
  (begin
    (asserts! (is-eq tx-sender (var-get contract-arbitrator)) err-arbitrator-only)
    (asserts! (is-some (get-dispute remittance-id)) err-no-dispute)
    (asserts! (not (get resolved (unwrap-panic (get-dispute remittance-id)))) err-already-completed)
    
    (let ((remittance-data (unwrap-panic (get-remittance remittance-id))))
      (if favor-sender
        (begin
          (update-user-balance (get sender remittance-data) (get amount remittance-data) true)
          (map-set remittances
            { remittance-id: remittance-id }
            (merge remittance-data { status: "refunded" })
          )
        )
        (map-set remittances
          { remittance-id: remittance-id }
          (merge remittance-data { status: "completed" })
        )
      )
      
      (map-set remittance-disputes
        { remittance-id: remittance-id }
        (merge (unwrap-panic (get-dispute remittance-id))
               { resolved: true, resolution: (some resolution), resolved-at: (some stacks-block-height) })
      )
      
      (ok favor-sender)
    )
  )
)

(define-public (set-arbitrator (new-arbitrator principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set contract-arbitrator new-arbitrator)
    (ok new-arbitrator)
  )
)

(define-read-only (get-default-expiration-blocks)
  (var-get default-expiration-blocks)
)

(define-read-only (is-remittance-expired (remittance-id uint))
  (match (get-remittance remittance-id)
    remittance
    (match (get expires-at remittance)
      expiry-block (>= stacks-block-height expiry-block)
      false)
    false
  )
)

(define-read-only (get-expiration-info (remittance-id uint))
  (match (get-remittance remittance-id)
    remittance
    (match (get expires-at remittance)
      expiry-block
      (ok {
        expires-at: expiry-block,
        current-block: stacks-block-height,
        blocks-remaining: (if (> expiry-block stacks-block-height)
                           (- expiry-block stacks-block-height)
                           u0),
        is-expired: (>= stacks-block-height expiry-block)
      })
      (ok {
        expires-at: u0,
        current-block: stacks-block-height,
        blocks-remaining: u0,
        is-expired: false
      }))
    err-not-found
  )
)

(define-public (create-remittance-with-expiration
  (recipient principal)
  (amount uint)
  (milestone-count uint)
  (expiration-blocks uint)
)
  (begin
    (asserts! (> amount u0) err-invalid-amount)
    (asserts! (> milestone-count u0) err-invalid-milestone)
    (asserts! (<= milestone-count u10) err-invalid-milestone)
    (asserts! (> expiration-blocks u0) err-invalid-amount)
    (asserts! (>= (get-user-balance tx-sender) (+ amount (calculate-fee amount))) err-insufficient-funds)
    
    (update-user-balance tx-sender (+ amount (calculate-fee amount)) false)
    (var-set total-platform-fees (+ (var-get total-platform-fees) (calculate-fee amount)))
    
    (map-set remittances
      { remittance-id: (var-get next-remittance-id) }
      {
        sender: tx-sender,
        recipient: recipient,
        amount: amount,
        fee: (calculate-fee amount),
        status: "pending",
        milestone-count: milestone-count,
        completed-milestones: u0,
        created-at: stacks-block-height,
        completed-at: none,
        expires-at: (some (+ stacks-block-height expiration-blocks))
      }
    )
    
    (var-set next-remittance-id (+ (var-get next-remittance-id) u1))
    (ok (- (var-get next-remittance-id) u1))
  )
)

(define-public (reclaim-expired-remittance (remittance-id uint))
  (begin
    (asserts! (is-some (get-remittance remittance-id)) err-not-found)
    (let ((remittance-data (unwrap-panic (get-remittance remittance-id))))
      (asserts! (is-eq tx-sender (get sender remittance-data)) err-unauthorized)
      (asserts! (is-eq (get status remittance-data) "pending") err-already-completed)
      (asserts! (is-remittance-expired remittance-id) err-not-expired)
      
      (let ((total-amount (get amount remittance-data))
            (completed-count (get completed-milestones remittance-data))
            (milestone-count (get milestone-count remittance-data)))
        (let ((avg-milestone-amount (/ total-amount milestone-count))
              (paid-amount (* avg-milestone-amount completed-count))
              (remaining-amount (- total-amount paid-amount)))
          (update-user-balance (get sender remittance-data) remaining-amount true)
          (map-set remittances
            { remittance-id: remittance-id }
            (merge remittance-data { status: "expired" })
          )
          (ok remaining-amount)
        )
      )
    )
  )
)

(define-public (set-default-expiration (blocks uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (> blocks u0) err-invalid-amount)
    (var-set default-expiration-blocks blocks)
    (ok blocks)
  )
)
