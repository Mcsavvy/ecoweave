;; EcoWeave: Decentralized Community Clean-up Platform

;; Error constants
(define-constant ERR_UNAUTHORIZED (err u1000))
(define-constant ERR_PROJECT_NOT_FOUND (err u1001))
(define-constant ERR_INVALID_PROJECT_STATE (err u1002))
(define-constant ERR_ALREADY_REGISTERED (err u1003))
(define-constant ERR_NOT_REGISTERED (err u1004))
(define-constant ERR_PROOF_ALREADY_SUBMITTED (err u1005))
(define-constant ERR_INVALID_PROOF (err u1006))
(define-constant ERR_INSUFFICIENT_REPUTATION (err u1007))

;; Project Difficulty Levels
(define-constant PROJECT_DIFFICULTY_EASY u1)
(define-constant PROJECT_DIFFICULTY_MEDIUM u2)
(define-constant PROJECT_DIFFICULTY_HARD u3)

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
        difficulty: uint,
        base-reward-per-participant: uint
    }
)

(define-map project-participants 
    {project-id: uint, participant: principal} 
    {
        has-registered: bool,
        proof-submitted: bool,
        proof-validated: bool,
        contribution-quality: uint
    }
)

;; Reputation tracking map
(define-map user-reputation 
    principal 
    {
        total-score: uint,
        projects-completed: uint,
        validation-count: uint
    }
)

;; Project states
(define-constant PROJECT_STATE_PROPOSED u1)
(define-constant PROJECT_STATE_ACTIVE u2)
(define-constant PROJECT_STATE_COMPLETED u3)

;; Reputation Constants
(define-constant MIN_REPUTATION_THRESHOLD u10)
(define-constant REPUTATION_MULTIPLIER u5)

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

;; Reputation Management Functions

;; Update user reputation based on project contributions
(define-private (update-user-reputation 
    (participant principal)
    (project-id uint)
    (contribution-quality uint)
)
    (let 
        (
            (current-reputation (default-to 
                {total-score: u0, projects-completed: u0, validation-count: u0} 
                (map-get? user-reputation participant)
            ))
            (new-reputation {
                total-score: (+ (get total-score current-reputation) contribution-quality),
                projects-completed: (+ (get projects-completed current-reputation) u1),
                validation-count: (get validation-count current-reputation)
            })
        )
        (map-set user-reputation participant new-reputation)
        new-reputation
    )
)

;; Calculate dynamic reward based on project difficulty and user reputation
(define-private (calculate-dynamic-reward 
    (base-reward uint)
    (difficulty uint)
    (participant principal)
)
    (let 
        (
            (user-rep (default-to 
                {total-score: u0, projects-completed: u0, validation-count: u0} 
                (map-get? user-reputation participant)
            ))
            (difficulty-multiplier (if (is-eq difficulty PROJECT_DIFFICULTY_EASY) u1
                (if (is-eq difficulty PROJECT_DIFFICULTY_MEDIUM) u2 u3)
            ))
            (reputation-factor (/ (get total-score user-rep) 
                (+ (get projects-completed user-rep) u1)
            ))
        )
        (* base-reward (* difficulty-multiplier (+ reputation-factor u1)))
    )
)

;; Get user reputation details
(define-read-only (get-user-reputation (participant principal))
    (map-get? user-reputation participant)
)

;; Validate Project Proof (Community Vote Simulation)
(define-public (validate-project-proof 
    (project-id uint) 
    (participant principal) 
    (is-valid bool)
)
    (let 
        (
            (project (unwrap! (map-get? projects project-id) ERR_PROJECT_NOT_FOUND))
            (participant-key {project-id: project-id, participant: participant})
            (participant-entry (unwrap! (map-get? project-participants participant-key) ERR_NOT_REGISTERED))
            (contribution-quality (get contribution-quality participant-entry))
            (dynamic-reward 
                (if is-valid 
                    (calculate-dynamic-reward 
                        (get base-reward-per-participant project) 
                        (get difficulty project) 
                        participant
                    )
                    u0
                )
            )
        )
        (asserts! (is-eq (get state project) PROJECT_STATE_ACTIVE) ERR_INVALID_PROJECT_STATE)
        (asserts! (get proof-submitted participant-entry) ERR_INVALID_PROOF)
        
        (map-set project-participants participant-key 
            (merge participant-entry {proof-validated: is-valid})
        )
        
        ;; Update user reputation if proof is valid
        (and is-valid 
            (update-user-reputation participant project-id contribution-quality)
        )
        
        (ok dynamic-reward)
    )
)

;; Read-only Functions
(define-read-only (get-project-details (project-id uint))
    (map-get? projects project-id)
)

(define-read-only (get-participant-status (project-id uint) (participant principal))
    (map-get? project-participants {project-id: project-id, participant: participant})
)
