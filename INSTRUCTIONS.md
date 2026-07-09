# Assessment Project Instructions — Blockchain, Smart Contracts, and Web3 Full Stack

## Overview

This repository is a multi-track assessment project for candidates applying to roles in:

- Blockchain Engineering
- Smart Contract Engineering
- Web3 Full Stack Development

The project now combines a simplified blockchain backend, a React-based explorer, and a Solidity smart contract example. Candidates are expected to demonstrate architecture sense, backend engineering quality, frontend integration, and documentation discipline.

## Suggested Time Budget

- 6–10 hours for a strong submission
- 10–14 hours for a polished, production-minded implementation

---

## Project Goals

Your submission should demonstrate that you can:

1. Understand and extend a layered backend architecture.
2. Implement and explain blockchain primitives such as blocks, transactions, mining, and validation.
3. Build a simple wallet flow and demonstrate transaction handling.
4. Add a smart contract artifact and show how it can be deployed and reasoned about.
5. Create a clean, documented web application that connects the frontend to the backend.

---

## Assessment Tracks

### 1. Blockchain Engineer

Focus on core blockchain correctness and architecture.

Requirements:
- Explain how block hashing, proof-of-work, and chain validation work.
- Make sure invalid transactions are rejected.
- Demonstrate persistence and recovery behavior.
- Show understanding of the difference between pending and confirmed transactions.

### 2. Smart Contract Engineer

Focus on solidity design and deployment readiness.

Requirements:
- Review the Solidity contract in [contracts/AssessmentToken.sol](contracts/AssessmentToken.sol).
- Explain the contract’s state, events, and transfer flow.
- Extend or improve the contract with additional meaningful functionality if desired.
- If using Hardhat, make sure deployment scripts are coherent and documented.

### 3. Web3 Full Stack Engineer

Focus on end-to-end experience and product quality.

Requirements:
- Connect the React UI to the Express API.
- Create a wallet flow that feels realistic and understandable.
- Improve the dashboard experience for blockchain interaction.
- Ensure the app is usable, error-tolerant, and documented.

---

## Expected Deliverables

Candidates should be able to show evidence of:

- Backend API routes and controllers for chain, transactions, mining, balance, stats, and wallets
- A frontend experience that lets a user explore the chain and interact with it
- A persistence layer that survives restarts
- A smart contract artifact in the [contracts](contracts) directory
- Updated documentation in [README.md](README.md) and [INSTRUCTIONS.md](INSTRUCTIONS.md)

---

## Recommended Setup

```bash
npm install
cp .env.example .env

# Terminal 1
npm start

# Terminal 2
npm run dev
```

Then open the app in the browser and verify:
- the blockchain explorer renders
- transaction creation works
- wallet generation works
- the API responds correctly
- the contract source exists and is documented

---

## Technical Expectations

### Backend

- Follow the existing layered structure: routes → controllers → models → services
- Keep business logic out of route files
- Handle errors gracefully and return consistent API payloads
- Persist blockchain state in a safe and recoverable way

### Frontend

- Keep components focused and reusable
- Avoid direct API calls from UI components when a helper layer already exists
- Provide useful loading and error states
- Make the interaction flow understandable for someone unfamiliar with the system

### Smart Contracts

- Write Solidity that is clear and readable
- Document important assumptions and limitations
- Use appropriate visibility and events
- Avoid unnecessary complexity

---

## Documentation Requirements

Your final submission should include:

- A polished [README.md](README.md) describing the project, architecture, features, and run instructions
- Clear JSDoc comments for new services and helpers
- A short explanation of any known limitations or trade-offs

---

## Evaluation Rubric

| Area | Weight | What is assessed |
|---|---:|---|
| Architecture | 30% | Structure, separation of concerns, code organization |
| Blockchain correctness | 25% | Validation, mining flow, persistence, transaction handling |
| Smart contract quality | 20% | Solidity quality, clarity, deployment readiness |
| Full stack integration | 15% | Frontend/backend cohesion and usability |
| Documentation | 10% | Readability, setup clarity, maintainability |

---

## Suggested Improvement Areas

Candidates may strengthen the submission by adding any of the following:

- better wallet signing and verification flow
- richer blockchain explorer UI
- contract deployment scripts and a test suite
- improved error handling and visual feedback
- persistent storage with a more robust format

---

## Final Note

This project is intentionally designed to be extensible. Strong submissions demonstrate not only that the features work, but that the implementation is thoughtful, documented, and easy to explain during an interview.
