# Android Lumen Soft-Surface Redesign Execution Plan

## Execution Summary
XL-style serial implementation: tokens → Android theme wiring → shell/surfaces → verification artifacts → commit.

## Frozen Inputs
- docs/requirements/2026-07-16-android-lumen-soft-surface-redesign.md
- .trellis/tasks/07-16-android-lumen-soft-surface-redesign/prd.md
- research/lumen-soft-surface-mapping.md

## Anti-Proxy-Goal-Drift Controls
### Primary Objective
Android soft-surface redesign to Lumen
### Non-Objective Proxy Signals
Merely adding unused color constants
### Validation Material Role
Token tests + static surface inspection
### Declared Tier
T2
### Intended Scope
Android UI only
### Abstraction Layer Target
Theme + soft surfaces
### Completion State Target
Committed Android Lumen soft-surface redesign
### Generalization Evidence Plan
Requirement/plan/research/code

## Internal Grade Decision
L (serial native execution). Large file surface but single agent ownership; no independent parallel units requiring XL fan-out.

## Wave Plan
1. Token/theme foundation
2. Android shell + chat/notes/tools/settings soft surfaces
3. Shared widgets + tests/docs
4. Commit + cleanup receipts

## Ownership Boundaries
- lib/theme/**
- lib/app.dart
- Android-facing pages/widgets soft surfaces
- docs/requirements, docs/plans, task research

## Verification Commands
- Static inspection of theme application path
- `dart`-free local runtime constraint; CI handles flutter test/analyze
- Focused unit test file for token/theme builders (authored, CI-run)

## Rollback Plan
Revert theme wiring in app.dart and token imports if Android regressions appear.

## Phase Cleanup Contract
Leave requirement/plan/session receipts; no temp install residue.
