# Wakil (वकील) – Sprint 1: Core Compliance & Authentication

Wakil is an AI-powered legal intelligence assistant tailored for the legal framework of Nepal (Constitution of Nepal 2072, Muluki Civil Code 2074, Muluki Criminal Code 2074, Company Act 2063, and Labor Act 2074).

## Sprint 1 Deliverables
Sprint 1 establishes the legal compliance foundation, brand identity, and credential authentication:

| User Story | Module | Description | Primary Lead |
|---|---|---|---|
| **US-01** | Onboarding | Splash screen, brand emblem, and status pill | Prasiddha Gautam |
| **US-02** | Compliance | Bilingual mandatory legal disclaimer bottom sheet | Rishav Bhattarai |
| **US-03** | Compliance | Agreement consent checkbox enabling Continue | Prashna Bharati |
| **US-04** | Authentication | Email & Phone credential authentication form | Bhugol Gautam |
| **US-05** | Authentication | Password visibility trailing icon eye toggle | Prasiddha Gautam |
| **US-06** | Authentication | Google OAuth One-Tap sign-in with Credential Manager | Rishav Bhattarai |
| **US-07** | Authentication | Session persistence & Skip Auth test mode | Prashna Bharati |

## Agile Team Allocation
- **Bhugol Gautam (250283)**: Scrum Master (Sprint 1), Backend & Testing
- **Prasiddha Gautam (250298)**: Frontend Architecture & Security
- **Prashna Bharati**: Compliance Engine & Full-Stack
- **Rishav Bhattarai**: QA Automation & Identity

## Running Tests
Execute the local Robolectric test suite:
```bash
gradle :app:testDebugUnitTest
```
