;; Diamond Authenticity Verification Contract
;; Laser-etched ID verification system for conflict-free diamonds

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u401))
(define-constant ERR_DIAMOND_NOT_FOUND (err u404))
(define-constant ERR_ALREADY_REGISTERED (err u409))
(define-constant ERR_INVALID_DATA (err u400))

;; Data Variables
(define-data-var diamond-counter uint u0)
(define-data-var contract-admin principal CONTRACT_OWNER)

;; Data Maps
(define-map diamonds
    { diamond-id: (string-ascii 64) }
    {
        owner: principal,
        carat-weight: uint,
        color-grade: (string-ascii 16),
        clarity-grade: (string-ascii 16),
        certification-number: (string-ascii 64),
        mine-source-id: uint,
        laser-inscription: (string-ascii 128),
        registration-date: uint,
        active: bool,
        conflict-free: bool
    }
)

;; Private Functions
(define-private (is-contract-admin)
    (is-eq tx-sender (var-get contract-admin))
)

(define-private (is-diamond-owner (diamond-id (string-ascii 64)))
    (match (map-get? diamonds { diamond-id: diamond-id })
        diamond (is-eq tx-sender (get owner diamond))
        false
    )
)

;; Read-only Functions
(define-read-only (get-diamond (diamond-id (string-ascii 64)))
    (map-get? diamonds { diamond-id: diamond-id })
)

(define-read-only (get-diamond-count)
    (var-get diamond-counter)
)

(define-read-only (is-diamond-authentic (diamond-id (string-ascii 64)))
    (match (map-get? diamonds { diamond-id: diamond-id })
        diamond (and 
                    (get active diamond)
                    (get conflict-free diamond)
                )
        false
    )
)

;; Public Functions
(define-public (register-diamond
    (diamond-id (string-ascii 64))
    (carat-weight uint)
    (color-grade (string-ascii 16))
    (clarity-grade (string-ascii 16))
    (certification-number (string-ascii 64))
    (mine-source-id uint)
)
    (let
        (
            (laser-inscription (concat "CF-" diamond-id))
        )
        (asserts! (is-none (map-get? diamonds { diamond-id: diamond-id })) ERR_ALREADY_REGISTERED)
        (asserts! (> (len diamond-id) u0) ERR_INVALID_DATA)
        (asserts! (> carat-weight u0) ERR_INVALID_DATA)
        (asserts! (> mine-source-id u0) ERR_INVALID_DATA)
        
        (map-set diamonds
            { diamond-id: diamond-id }
            {
                owner: tx-sender,
                carat-weight: carat-weight,
                color-grade: color-grade,
                clarity-grade: clarity-grade,
                certification-number: certification-number,
                mine-source-id: mine-source-id,
                laser-inscription: laser-inscription,
                registration-date: stacks-block-height,
                active: true,
                conflict-free: true
            }
        )
        
        (var-set diamond-counter (+ (var-get diamond-counter) u1))
        (ok laser-inscription)
    )
)

(define-public (transfer-diamond 
    (diamond-id (string-ascii 64))
    (new-owner principal)
)
    (let
        (
            (diamond (unwrap! (map-get? diamonds { diamond-id: diamond-id }) ERR_DIAMOND_NOT_FOUND))
        )
        (asserts! (is-diamond-owner diamond-id) ERR_NOT_AUTHORIZED)
        (asserts! (get active diamond) ERR_INVALID_DATA)
        
        (map-set diamonds
            { diamond-id: diamond-id }
            (merge diamond { owner: new-owner })
        )
        
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