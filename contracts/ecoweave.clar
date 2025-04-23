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

;; Disputes Map
(define-map disputes
    uint 
    {
        project-id: uint,
        initiator: principal,
        disputed-participant: principal,
        state: uint,
        description: (string-utf8 500),
        votes-for: uint,
        votes-against: uint,
        resolved-in-favor: bool
    }
)

;; Dispute Votes Map
(define-map dispute-votes
    {dispute-id: uint, voter: principal}
    {
        vote: bool,
        voting-power: uint
    }
)

;; Project states
(define-constant PROJECT_STATE_PROPOSED u1)
(define-constant PROJECT_STATE_ACTIVE u2)
(define-constant PROJECT_STATE_COMPLETED u3)

;; Reputation Constants
(define-constant MIN_REPUTATION_THRESHOLD u10)
(define-constant REPUTATION_MULTIPLIER u5)

;; Dispute Constants
(define-constant DISPUTE_STATE_OPEN u1)
(define-constant DISPUTE_STATE_IN_VOTING u2)
(define-constant DISPUTE_STATE_RESOLVED u3)

;; Error Constants
(define-constant ERR_DISPUTE_NOT_FOUND (err u1008))
(define-constant ERR_INVALID_DISPUTE_STATE (err u1009))
(define-constant ERR_INSUFFICIENT_VOTES (err u1010))
(define-constant ERR_ALREADY_VOTED (err u1011))

;; Counters
(define-data-var next-project-id uint u1)
(define-data-var next-dispute-id uint u1)

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

;; Initiate a dispute for a project
(define-public (initiate-dispute 
    (project-id uint)
    (disputed-participant principal)
    (description (string-utf8 500))
)
    (let 
        (
            (project (unwrap! (map-get? projects project-id) ERR_PROJECT_NOT_FOUND))
            (participant-key {project-id: project-id, participant: disputed-participant})
            (participant-entry (unwrap! (map-get? project-participants participant-key) ERR_NOT_REGISTERED))
            (dispute-id (var-get next-dispute-id))
        )
        ;; Validate dispute initiation
        (asserts! (is-eq (get state project) PROJECT_STATE_ACTIVE) ERR_INVALID_PROJECT_STATE)
        
        ;; Create dispute entry
        (map-set disputes dispute-id {
            project-id: project-id,
            initiator: tx-sender,
            disputed-participant: disputed-participant,
            state: DISPUTE_STATE_OPEN,
            description: description,
            votes-for: u0,
            votes-against: u0,
            resolved-in-favor: false
        })
        
        (var-set next-dispute-id (+ dispute-id u1))
        
        (ok dispute-id)
    )
)

;; Vote on a dispute
(define-public (vote-on-dispute 
    (dispute-id uint)
    (vote bool)
)
    (let 
        (
            (dispute (unwrap! (map-get? disputes dispute-id) ERR_DISPUTE_NOT_FOUND))
            (voter-reputation (default-to 
                {total-score: u0, projects-completed: u0, validation-count: u0} 
                (map-get? user-reputation tx-sender)
            ))
            (voting-power (/ (get total-score voter-reputation) 
                (+ (get projects-completed voter-reputation) u1)
            ))
            (vote-key {dispute-id: dispute-id, voter: tx-sender})
        )
        ;; Validate voting conditions
        (asserts! (is-eq (get state dispute) DISPUTE_STATE_OPEN) ERR_INVALID_DISPUTE_STATE)
        (asserts! (is-none (map-get? dispute-votes vote-key)) ERR_ALREADY_VOTED)
        
        ;; Record vote
        (map-set dispute-votes vote-key {
            vote: vote,
            voting-power: voting-power
        })
        
        ;; Update dispute vote counts
        (if vote 
            (map-set disputes dispute-id 
                (merge dispute {
                    votes-for: (+ (get votes-for dispute) voting-power),
                    state: DISPUTE_STATE_IN_VOTING
                })
            )
            (map-set disputes dispute-id 
                (merge dispute {
                    votes-against: (+ (get votes-against dispute) voting-power),
                    state: DISPUTE_STATE_IN_VOTING
                })
            )
        )
        
        (ok true)
    )
)

;; Resolve a dispute
(define-public (resolve-dispute (dispute-id uint))
    (let 
        (
            (dispute (unwrap! (map-get? disputes dispute-id) ERR_DISPUTE_NOT_FOUND))
            (total-votes (+ (get votes-for dispute) (get votes-against dispute)))
            (dispute-resolved-in-favor (> (get votes-for dispute) (get votes-against dispute)))
        )
        ;; Validate dispute resolution
        (asserts! (is-eq (get state dispute) DISPUTE_STATE_IN_VOTING) ERR_INVALID_DISPUTE_STATE)
        (asserts! (>= total-votes u10) ERR_INSUFFICIENT_VOTES)
        
        ;; Resolve dispute
        (map-set disputes dispute-id (merge dispute {
            state: DISPUTE_STATE_RESOLVED,
            resolved-in-favor: dispute-resolved-in-favor
        }))
        
        ;; Adjust reputation or penalize based on dispute resolution
        (if dispute-resolved-in-favor
            ;; If dispute resolved against the participant, penalize reputation
            (let 
                (
                    (current-reputation (default-to 
                        {total-score: u0, projects-completed: u0, validation-count: u0} 
                        (map-get? user-reputation (get disputed-participant dispute))
                    ))
                    (reduced-reputation {
                        total-score: (/ (get total-score current-reputation) u2),
                        projects-completed: (get projects-completed current-reputation),
                        validation-count: (get validation-count current-reputation)
                    })
                )
                (map-set user-reputation (get disputed-participant dispute) reduced-reputation)
            )
            ;; If dispute resolved in favor of the participant, do nothing
            true
        )
        
        (ok dispute-resolved-in-favor)
    )
)

;; Read-only function to get dispute details
(define-read-only (get-dispute-details (dispute-id uint))
    (map-get? disputes dispute-id)
)
