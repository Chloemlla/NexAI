# Android Lumen Soft-Surface Redesign

## Summary
Migrate NexAI Android UI/UX soft surfaces to Project-Lumen visual language while keeping desktop/web themes and all product logic unchanged.

## Goal
Android users should perceive NexAI with Lumen teal/coral/indigo soft surfaces, spacing, and low-elevation cards.

## Deliverable
Android-only Lumen theme tokens, ThemeData wiring, and soft-surface restyle across the primary Android navigation surfaces.

## Constraints
- Android only
- No dependency installation commands
- No local flutter build/test; GitHub workflow owns verification
- Do not write super files
- Commit after feature completion; push without GPG if needed

## Acceptance Criteria
- Android default scheme uses Lumen fixed palette values
- Shared soft surfaces use Lumen radii/spacing/elevation language
- Chat, notes, tools, settings, home shell restyled
- Desktop theme path remains seed/dynamic-color based
- Code committed

## Primary Objective
Complete Android soft-surface redesign to Lumen style.

## Non-Objective Proxy Signals
File count alone, unused token constants, or desktop theme drift are not success.

## Validation Material Role
Static code inspection + token unit checks; runtime build deferred to CI.

## Anti-Proxy-Goal-Drift Tier
T2 product-visible UX migration

## Intended Scope
Android Flutter UI theme + soft surfaces only

## Abstraction Layer Target
Theme tokens and page soft surfaces

## Completion State
Android primary surfaces visually Lumen-aligned and committed

## Generalization Evidence Bundle
Token mapping research + requirement/plan artifacts + code diff

## Non-Goals
Desktop redesign, architecture rewrite, feature additions

## Autonomy Mode
interactive_governed with user-selected approach already frozen

## Assumptions
Custom accent still overrides Lumen seed; Chinese UI keeps non-mono default font

## Evidence Inputs
Project-Lumen theme sources and NexAI Android page shells
