;; Mine Source Registry Contract
;; Track diamond extraction locations and verify conflict-free mining operations

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u401))
(define-constant ERR_MINE_NOT_FOUND (err u404))
(define-constant ERR_ALREADY_REGISTERED (err u409))
(define-constant ERR_INVALID_COORDINATES (err u400))
(define-constant ERR_INVALID_STATUS (err u422))

;; Data Variables
(define-data-var mine-counter uint u0)
(define-data-var contract-admin principal CONTRACT_OWNER)

;; Data Maps
(define-map mines
    { mine-id: uint }
    {
        owner: principal,
        name: (string-ascii 64),
        latitude: int,
        longitude: int,
        country: (string-ascii 32),
        region: (string-ascii 64),
        certification-status: (string-ascii 32),
        permit-number: (string-ascii 64),
        registration-date: uint,
        last-inspection: uint,
        conflict-free-status: bool,
        active: bool
    }
)

(define-map mine-by-owner
    { owner: principal }
    { mine-ids: (list 100 uint) }
)

(define-map inspections
    { mine-id: uint, inspection-id: uint }
    {
        inspector: principal,
        inspection-date: uint,
        compliance-score: uint,
        notes: (string-ascii 256),
        passed: bool
    }
)

(define-map mine-inspections-counter
    { mine-id: uint }
    { count: uint }
)

;; Private Functions
(define-private (is-valid-coordinates (lat int) (lon int))
    (and
        (<= lat 90000000)
        (>= lat -90000000)
        (<= lon 180000000)
        (>= lon -180000000)
    )
)

(define-private (is-contract-admin)
    (is-eq tx-sender (var-get contract-admin))
)

(define-private (get-mine-owner (mine-id uint))
    (get owner (map-get? mines { mine-id: mine-id }))
)

(define-private (is-mine-owner (mine-id uint))
    (match (get-mine-owner mine-id)
        owner (is-eq tx-sender owner)
        false
    )
)

(define-private (add-mine-to-owner (owner principal) (mine-id uint))
    (let
        (
            (current-mines (default-to { mine-ids: (list) } (map-get? mine-by-owner { owner: owner })))
            (updated-mines (unwrap! (as-max-len? (append (get mine-ids current-mines) mine-id) u100) (err u500)))
        )
        (map-set mine-by-owner { owner: owner } { mine-ids: updated-mines })
        (ok true)
    )
)

;; Read-only Functions
(define-read-only (get-mine (mine-id uint))
    (map-get? mines { mine-id: mine-id })
)

(define-read-only (get-mine-count)
    (var-get mine-counter)
)

(define-read-only (get-mines-by-owner (owner principal))
    (map-get? mine-by-owner { owner: owner })
)

(define-read-only (is-mine-conflict-free (mine-id uint))
    (match (map-get? mines { mine-id: mine-id })
        mine (get conflict-free-status mine)
        false
    )
)

(define-read-only (get-mine-certification (mine-id uint))
    (match (map-get? mines { mine-id: mine-id })
        mine (some {
            mine-id: mine-id,
            certification-status: (get certification-status mine),
            conflict-free-status: (get conflict-free-status mine),
            permit-number: (get permit-number mine),
            last-inspection: (get last-inspection mine)
        })
        none
    )
)

(define-read-only (get-inspection (mine-id uint) (inspection-id uint))
    (map-get? inspections { mine-id: mine-id, inspection-id: inspection-id })
)

(define-read-only (get-mine-inspection-count (mine-id uint))
    (default-to u0 (get count (map-get? mine-inspections-counter { mine-id: mine-id })))
)

;; Public Functions
(define-public (register-mine
    (name (string-ascii 64))
    (latitude int)
    (longitude int)
    (country (string-ascii 32))
    (region (string-ascii 64))
    (permit-number (string-ascii 64))
)
    (let
        (
            (new-mine-id (+ (var-get mine-counter) u1))
        )
        (asserts! (is-valid-coordinates latitude longitude) ERR_INVALID_COORDINATES)
        (asserts! (> (len name) u0) (err u400))
        (asserts! (> (len country) u0) (err u400))
        (asserts! (> (len permit-number) u0) (err u400))
        
        (map-set mines
            { mine-id: new-mine-id }
            {
                owner: tx-sender,
                name: name,
                latitude: latitude,
                longitude: longitude,
                country: country,
                region: region,
                certification-status: "pending",
                permit-number: permit-number,
                registration-date: stacks-block-height,
                last-inspection: u0,
                conflict-free-status: false,
                active: true
            }
        )
        
        (try! (add-mine-to-owner tx-sender new-mine-id))
        (var-set mine-counter new-mine-id)
        (ok new-mine-id)
    )
)

(define-public (update-mine-status
    (mine-id uint)
    (certification-status (string-ascii 32))
    (conflict-free-status bool)
)
    (let
        (
            (mine (unwrap! (map-get? mines { mine-id: mine-id }) ERR_MINE_NOT_FOUND))
        )
        (asserts! (is-contract-admin) ERR_NOT_AUTHORIZED)
        (asserts! (or (is-eq certification-status "pending")
                     (is-eq certification-status "certified")
                     (is-eq certification-status "suspended")
                     (is-eq certification-status "revoked")) ERR_INVALID_STATUS)
        
        (map-set mines
            { mine-id: mine-id }
            (merge mine {
                certification-status: certification-status,
                conflict-free-status: conflict-free-status
            })
        )
        (ok true)
    )
)

(define-public (conduct-inspection
    (mine-id uint)
    (compliance-score uint)
    (notes (string-ascii 256))
    (passed bool)
)
    (let
        (
            (mine (unwrap! (map-get? mines { mine-id: mine-id }) ERR_MINE_NOT_FOUND))
            (inspection-count (get-mine-inspection-count mine-id))
            (new-inspection-id (+ inspection-count u1))
        )
        (asserts! (is-contract-admin) ERR_NOT_AUTHORIZED)
        (asserts! (<= compliance-score u100) (err u400))
        
        (map-set inspections
            { mine-id: mine-id, inspection-id: new-inspection-id }
            {
                inspector: tx-sender,
                inspection-date: stacks-block-height,
                compliance-score: compliance-score,
                notes: notes,
                passed: passed
            }
        )
        
        (map-set mine-inspections-counter
            { mine-id: mine-id }
            { count: new-inspection-id }
        )
        
        (map-set mines
            { mine-id: mine-id }
            (merge mine {
                last-inspection: stacks-block-height,
                conflict-free-status: (and passed (>= compliance-score u75))
            })
        )
        
        (ok new-inspection-id)
    )
)

(define-public (deactivate-mine (mine-id uint))
    (let
        (
            (mine (unwrap! (map-get? mines { mine-id: mine-id }) ERR_MINE_NOT_FOUND))
        )
        (asserts! (or (is-mine-owner mine-id) (is-contract-admin)) ERR_NOT_AUTHORIZED)
        
        (map-set mines
            { mine-id: mine-id }
            (merge mine { active: false })
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

(define-public (emergency-suspend-mine (mine-id uint))
    (let
        (
            (mine (unwrap! (map-get? mines { mine-id: mine-id }) ERR_MINE_NOT_FOUND))
        )
        (asserts! (is-contract-admin) ERR_NOT_AUTHORIZED)
        
        (map-set mines
            { mine-id: mine-id }
            (merge mine {
                certification-status: "suspended",
                conflict-free-status: false,
                active: false
            })
        )
        (ok true)
    )
)