# EcoWeave: Decentralized Community Clean-up Platform

## Overview
EcoWeave is a blockchain-based platform that incentivizes and organizes community clean-up projects using the Stacks blockchain and Clarity smart contracts.

## Smart Contract Features

### Project Lifecycle Management
- Project Creation: Users can propose clean-up projects
- Project Registration: Community members can register for projects
- Proof Submission: Participants submit evidence of completed work
- Community Validation: Proof validation through community consensus

### Key Contract Functions
- `create-project`: Initiate a new clean-up project
- `register-for-project`: Join a proposed project
- `submit-project-proof`: Upload evidence of project completion
- `validate-project-proof`: Community verification of submitted proofs

## Project States
- `PROJECT_STATE_PROPOSED`: Initial project state
- `PROJECT_STATE_ACTIVE`: Project is ongoing
- `PROJECT_STATE_COMPLETED`: Project has been finished and validated

## Error Handling
The contract includes comprehensive error management with specific error codes for various scenarios:
- `ERR_UNAUTHORIZED`: Invalid permissions
- `ERR_PROJECT_NOT_FOUND`: Project does not exist
- `ERR_INVALID_PROJECT_STATE`: Operation not allowed in current project state
- `ERR_ALREADY_REGISTERED`: Duplicate project registration
- `ERR_NOT_REGISTERED`: User not registered for project
- `ERR_PROOF_ALREADY_SUBMITTED`: Duplicate proof submission
- `ERR_INVALID_PROOF`: Proof does not meet requirements

## Development
- Language: Clarity (Stacks Blockchain)
- Testing Framework: Clarinet
- Test Coverage: Full contract functionality tested

## Future Improvements
- Implement actual token rewards
- Enhanced proof validation mechanisms
- More granular project state management

## License
[Insert License Information]