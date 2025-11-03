(define-constant contract-owner tx-sender)
(define-constant err-not-found (err u400))
(define-constant err-already-watching (err u401))
(define-constant err-not-watching (err u402))
(define-constant err-invalid-remittance (err u403))

(define-data-var next-notification-id uint u1)

(define-map watchers
  { remittance-id: uint, watcher: principal }
  { 
    watching: bool,
    added-at: uint,
    notification-count: uint
  }
)

(define-map notifications
  { notification-id: uint }
  {
    remittance-id: uint,
    event-type: (string-ascii 30),
    details: (string-ascii 100),
    created-at: uint
  }
)

(define-map watcher-notifications
  { watcher: principal, notification-id: uint }
  { read: bool }
)

(define-read-only (is-watching (remittance-id uint) (watcher principal))
  (default-to false (get watching (map-get? watchers { remittance-id: remittance-id, watcher: watcher })))
)

(define-read-only (get-watcher-info (remittance-id uint) (watcher principal))
  (map-get? watchers { remittance-id: remittance-id, watcher: watcher })
)

(define-read-only (get-notification (notification-id uint))
  (map-get? notifications { notification-id: notification-id })
)

(define-public (watch-remittance (remittance-id uint))
  (begin
    (asserts! (not (is-watching remittance-id tx-sender)) err-already-watching)
    (map-set watchers
      { remittance-id: remittance-id, watcher: tx-sender }
      { watching: true, added-at: stacks-block-height, notification-count: u0 }
    )
    (ok true)
  )
)

(define-public (unwatch-remittance (remittance-id uint))
  (begin
    (asserts! (is-watching remittance-id tx-sender) err-not-watching)
    (map-set watchers
      { remittance-id: remittance-id, watcher: tx-sender }
      (merge (unwrap-panic (get-watcher-info remittance-id tx-sender)) { watching: false })
    )
    (ok true)
  )
)

(define-public (notify-milestone-completed (remittance-id uint) (milestone-index uint))
  (let ((notification-id (var-get next-notification-id)))
    (map-set notifications
      { notification-id: notification-id }
      {
        remittance-id: remittance-id,
        event-type: "milestone_completed",
        details: "Milestone completed successfully",
        created-at: stacks-block-height
      }
    )
    (var-set next-notification-id (+ notification-id u1))
    (ok notification-id)
  )
)

(define-public (mark-notification-read (notification-id uint))
  (begin
    (map-set watcher-notifications
      { watcher: tx-sender, notification-id: notification-id }
      { read: true }
    )
    (ok true)
  )
)
