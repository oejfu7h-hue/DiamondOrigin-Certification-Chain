;; Mining Violation Tracking Contract
;; Report and track human rights violations or illegal mining activities

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u401))
(define-constant ERR_VIOLATION_NOT_FOUND (err u404))
(define-constant ERR_INVALID_DATA (err u400))
(define-constant ERR_INVALID_SEVERITY (err u423))

;; Data Variables
(define-data-var violation-counter uint u0)
(define-data-var contract-admin principal CONTRACT_OWNER)

;; Data Maps
(define-map violations
    { violation-id: uint }
    {
        reporter: principal,
        mine-id: uint,
        violation-type: (string-ascii 64),
        severity-level: uint,
        description: (string-ascii 512),
        location: (string-ascii 128),
        report-date: uint,
        status: (string-ascii 32),
        verified: bool
    }
)

(define-map blacklisted-mines
    { mine-id: uint }
    {
        blacklist-date: uint,
        reason: (string-ascii 256),
        permanent: bool
    }
)

;; Private Functions
(define-private (is-contract-admin)
    (is-eq tx-sender (var-get contract-admin))
)

(define-private (is-valid-severity (level uint))
    (and (>= level u1) (<= level u5))
)

;; Read-only Functions
(define-read-only (get-violation (violation-id uint))
    (map-get? violations { violation-id: violation-id })
)

(define-read-only (get-violation-count)
    (var-get violation-counter)
)

(define-read-only (is-mine-blacklisted (mine-id uint))
    (is-some (map-get? blacklisted-mines { mine-id: mine-id }))
)

(define-read-only (get-blacklist-info (mine-id uint))
    (map-get? blacklisted-mines { mine-id: mine-id })
)

;; Public Functions
(define-public (report-violation
    (mine-id uint)
    (violation-type (string-ascii 64))
    (severity-level uint)
    (description (string-ascii 512))
    (location (string-ascii 128))
)
    (let
        (
            (new-violation-id (+ (var-get violation-counter) u1))
        )
        (asserts! (> mine-id u0) ERR_INVALID_DATA)
        (asserts! (is-valid-severity severity-level) ERR_INVALID_SEVERITY)
        (asserts! (> (len violation-type) u0) ERR_INVALID_DATA)
        (asserts! (> (len description) u0) ERR_INVALID_DATA)
        
        (map-set violations
            { violation-id: new-violation-id }
            {
                reporter: tx-sender,
                mine-id: mine-id,
                violation-type: violation-type,
                severity-level: severity-level,
                description: description,
                location: location,
                report-date: stacks-block-height,
                status: "pending",
                verified: false
            }
        )
        
        (var-set violation-counter new-violation-id)
        (ok new-violation-id)
    )
)

(define-public (update-violation-status
    (violation-id uint)
    (new-status (string-ascii 32))
)
    (let
        (
            (violation (unwrap! (map-get? violations { violation-id: violation-id }) ERR_VIOLATION_NOT_FOUND))
        )
        (asserts! (is-contract-admin) ERR_NOT_AUTHORIZED)
        
        (map-set violations
            { violation-id: violation-id }
            (merge violation { 
                status: new-status,
                verified: true
            })
        )
        (ok true)
    )
)

(define-public (blacklist-mine
    (mine-id uint)
    (reason (string-ascii 256))
    (permanent bool)
)
    (begin
        (asserts! (is-contract-admin) ERR_NOT_AUTHORIZED)
        (asserts! (> mine-id u0) ERR_INVALID_DATA)
        (asserts! (> (len reason) u0) ERR_INVALID_DATA)
        
        (map-set blacklisted-mines
            { mine-id: mine-id }
            {
                blacklist-date: stacks-block-height,
                reason: reason,
                permanent: permanent
            }
        )
        (ok true)
    )
)

(define-public (remove-from-blacklist (mine-id uint))
    (begin
        (asserts! (is-contract-admin) ERR_NOT_AUTHORIZED)
        (map-delete blacklisted-mines { mine-id: mine-id })
        (ok true)
    )
)

(define-public (set-contract-admin (new-admin principal))
    (begin
        (asserts! (is-contract-admin) ERR_NOT_AUTHORIZED)
        (var-set contract-admin new-admin)
        (ok true)
    )
)