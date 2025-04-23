;; EcoWeave: Decentralized Community Clean-up Platform

;; Error constants
(define-constant ERR_UNAUTHORIZED (err u1000))
(define-constant ERR_PROJECT_NOT_FOUND (err u1001))
(define-constant ERR_INVALID_PROJECT_STATE (err u1002))
(define-constant ERR_ALREADY_REGISTERED (err u1003))
(define-constant ERR_NOT_REGISTERED (err u1004))
(define-constant ERR_PROOF_ALREADY_SUBMITTED (err u1005))
(define-constant ERR_INVALID_PROOF (err u1006))

;; Data maps
(define-map projects 
    uint 
    {
        creator: principal,
        location: (string-utf8 100),
        date: uint,
        required-participants: uint,
        current-participants: uint,
        state: uint,
        reward-per-participant: uint
    }
)

(define-map project-participants 
    {project-id: uint, participant: principal} 
    {
        has-registered: bool,
        proof-submitted: bool,
        proof-validated: bool
    }
)

;; Project states
(define-constant PROJECT_STATE_PROPOSED u1)
(define-constant PROJECT_STATE_ACTIVE u2)
(define-constant PROJECT_STATE_COMPLETED u3)

;; Counters
(define-data-var next-project-id uint u1)

;; Project Creation
(define-public (create-project 
    (location (string-utf8 100))
    (date uint)
    (required-participants uint)
    (reward-per-participant uint)
)
    (let 
        (
            (project-id (var-get next-project-id))
        )
        ;; Input validations
        (asserts! (> (len location) u0) ERR_UNAUTHORIZED)
        (asserts! (> date block-height) ERR_UNAUTHORIZED)
        (asserts! (> required-participants u0) ERR_UNAUTHORIZED)
        (asserts! (> reward-per-participant u0) ERR_UNAUTHORIZED)
        
        (map-set projects project-id {
            creator: tx-sender,
            location: location,
            date: date,
            required-participants: required-participants,
            current-participants: u0,
            state: PROJECT_STATE_PROPOSED,
            reward-per-participant: reward-per-participant
        })
        
        (var-set next-project-id (+ project-id u1))
        
        (ok project-id)
    )
)

;; Project Registration
(define-public (register-for-project (project-id uint))
    (let 
        (
            (project (unwrap! (map-get? projects project-id) ERR_PROJECT_NOT_FOUND))
            (participant-key {project-id: project-id, participant: tx-sender})
        )
        (asserts! (is-eq (get state project) PROJECT_STATE_PROPOSED) ERR_INVALID_PROJECT_STATE)
        (asserts! (< (get current-participants project) (get required-participants project)) ERR_UNAUTHORIZED)
        (asserts! (is-none (map-get? project-participants participant-key)) ERR_ALREADY_REGISTERED)
        
        (map-set project-participants participant-key {
            has-registered: true,
            proof-submitted: false,
            proof-validated: false
        })
        
        (map-set projects project-id (merge project {
            current-participants: (+ (get current-participants project) u1)
        }))
        
        (ok true)
    )
)

;; Submit Clean-up Proof
(define-public (submit-project-proof (project-id uint) (proof-uri (string-utf8 256)))
    (let 
        (
            (project (unwrap! (map-get? projects project-id) ERR_PROJECT_NOT_FOUND))
            (participant-key {project-id: project-id, participant: tx-sender})
            (participant-entry (unwrap! (map-get? project-participants participant-key) ERR_NOT_REGISTERED))
        )
        (asserts! (is-eq (get state project) PROJECT_STATE_ACTIVE) ERR_INVALID_PROJECT_STATE)
        (asserts! (not (get proof-submitted participant-entry)) ERR_PROOF_ALREADY_SUBMITTED)
        (asserts! (> (len proof-uri) u0) ERR_UNAUTHORIZED)
        
        (map-set project-participants participant-key (merge participant-entry {
            proof-submitted: true
        }))
        
        (ok true)
    )
)

;; Validate Project Proof (Community Vote Simulation)
(define-public (validate-project-proof (project-id uint) (participant principal) (is-valid bool))
    (let 
        (
            (project (unwrap! (map-get? projects project-id) ERR_PROJECT_NOT_FOUND))
            (participant-key {project-id: project-id, participant: participant})
            (participant-entry (unwrap! (map-get? project-participants participant-key) ERR_NOT_REGISTERED))
        )
        (asserts! (is-eq (get state project) PROJECT_STATE_ACTIVE) ERR_INVALID_PROJECT_STATE)
        (asserts! (get proof-submitted participant-entry) ERR_INVALID_PROOF)
        
        (map-set project-participants participant-key (merge participant-entry {
            proof-validated: is-valid
        }))
        
        (ok true)
    )
)

;; Read-only Functions
(define-read-only (get-project-details (project-id uint))
    (map-get? projects project-id)
)

(define-read-only (get-participant-status (project-id uint) (participant principal))
    (map-get? project-participants {project-id: project-id, participant: participant})
)