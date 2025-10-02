;; Ethical Mining Rewards Contract
;; Token incentives for miners and dealers maintaining conflict-free certification standards

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u401))
(define-constant ERR_INSUFFICIENT_BALANCE (err u402))
(define-constant ERR_INVALID_AMOUNT (err u400))
(define-constant ERR_REWARD_NOT_FOUND (err u404))
(define-constant ERR_ALREADY_CLAIMED (err u409))

;; Token Constants
(define-constant TOKEN_NAME "Ethical Diamond Token")
(define-constant TOKEN_SYMBOL "EDT")
(define-constant TOKEN_DECIMALS u6)
(define-constant TOTAL_SUPPLY u100000000000000)

;; Data Variables
(define-data-var contract-admin principal CONTRACT_OWNER)
(define-data-var reward-counter uint u0)
(define-data-var base-mining-reward uint u1000000)

;; Data Maps
(define-map token-balances principal uint)

(define-map participant-profiles
    { participant: principal }
    {
        participant-type: (string-ascii 32),
        registration-date: uint,
        total-earned: uint,
        active: bool
    }
)

(define-map mining-rewards
    { reward-id: uint }
    {
        recipient: principal,
        mine-id: uint,
        reward-type: (string-ascii 32),
        amount: uint,
        award-date: uint,
        claimed: bool
    }
)

;; Private Functions
(define-private (is-contract-admin)
    (is-eq tx-sender (var-get contract-admin))
)

(define-private (get-balance (account principal))
    (default-to u0 (map-get? token-balances account))
)

(define-private (set-balance (account principal) (amount uint))
    (map-set token-balances account amount)
)

(define-private (is-participant-active (participant principal))
    (default-to false (get active (map-get? participant-profiles { participant: participant })))
)

;; Read-only Functions
(define-read-only (get-token-name)
    TOKEN_NAME
)

(define-read-only (get-token-symbol)
    TOKEN_SYMBOL
)

(define-read-only (get-decimals)
    TOKEN_DECIMALS
)

(define-read-only (get-total-supply)
    TOTAL_SUPPLY
)

(define-read-only (get-balance-of (account principal))
    (ok (get-balance account))
)

(define-read-only (get-participant-profile (participant principal))
    (map-get? participant-profiles { participant: participant })
)

(define-read-only (get-mining-reward (reward-id uint))
    (map-get? mining-rewards { reward-id: reward-id })
)

;; Public Functions
(define-public (transfer (amount uint) (recipient principal))
    (let
        (
            (sender-balance (get-balance tx-sender))
        )
        (asserts! (>= sender-balance amount) ERR_INSUFFICIENT_BALANCE)
        (asserts! (> amount u0) ERR_INVALID_AMOUNT)
        
        (set-balance tx-sender (- sender-balance amount))
        (set-balance recipient (+ (get-balance recipient) amount))
        (ok true)
    )
)

(define-public (register-participant
    (participant principal)
    (participant-type (string-ascii 32))
)
    (begin
        (asserts! (is-contract-admin) ERR_NOT_AUTHORIZED)
        
        (map-set participant-profiles
            { participant: participant }
            {
                participant-type: participant-type,
                registration-date: stacks-block-height,
                total-earned: u0,
                active: true
            }
        )
        
        (set-balance participant u1000000)
        (ok true)
    )
)

(define-public (award-mining-reward
    (recipient principal)
    (mine-id uint)
    (reward-type (string-ascii 32))
)
    (let
        (
            (new-reward-id (+ (var-get reward-counter) u1))
            (reward-amount (var-get base-mining-reward))
        )
        (asserts! (is-contract-admin) ERR_NOT_AUTHORIZED)
        (asserts! (is-participant-active recipient) ERR_INVALID_AMOUNT)
        
        (map-set mining-rewards
            { reward-id: new-reward-id }
            {
                recipient: recipient,
                mine-id: mine-id,
                reward-type: reward-type,
                amount: reward-amount,
                award-date: stacks-block-height,
                claimed: false
            }
        )
        
        (var-set reward-counter new-reward-id)
        (ok new-reward-id)
    )
)

(define-public (claim-reward (reward-id uint))
    (let
        (
            (reward (unwrap! (map-get? mining-rewards { reward-id: reward-id }) ERR_REWARD_NOT_FOUND))
        )
        (asserts! (is-eq tx-sender (get recipient reward)) ERR_NOT_AUTHORIZED)
        (asserts! (not (get claimed reward)) ERR_ALREADY_CLAIMED)
        
        (set-balance tx-sender (+ (get-balance tx-sender) (get amount reward)))
        
        (map-set mining-rewards
            { reward-id: reward-id }
            (merge reward { claimed: true })
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

;; Initialize contract with admin balance
(set-balance CONTRACT_OWNER TOTAL_SUPPLY)