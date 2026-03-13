# KaTeX Chemical Equation Rendering — Technical Specification

**Version:** 1.0.0  
**Project:** NexAI (Flutter)  
**Scope:** `lib/widgets/rich_content_view.dart`  
**Rendering Stack:** `flutter_math_fork` ≥ 0.7.4 · `gpt_markdown` ≥ 1.1.5  
**Last Updated:** 2026-03-13

---

## Table of Contents

1. [Overview](#1-overview)
2. [Dependency Stack](#2-dependency-stack)
3. [Rendering Pipeline](#3-rendering-pipeline)
4. [Input Syntax Specification](#4-input-syntax-specification)
5. [Pre-processing Rules (`_preprocessChemical`)](#5-pre-processing-rules-_preprocesschemical)
6. [Chemical-to-LaTeX Conversion Rules (`_convertChemical`)](#6-chemical-to-latex-conversion-rules-_convertchemical)
7. [Regex Definitions & Semantics](#7-regex-definitions--semantics)
8. [Supported Chemical Notation](#8-supported-chemical-notation)
9. [Known Limitations & Edge Cases](#9-known-limitations--edge-cases)
10. [Testing Matrix](#10-testing-matrix)
11. [Extension Guidelines](#11-extension-guidelines)

---

## 1. Overview

NexAI renders AI-generated Markdown content that may contain:

- Standard LaTeX math: `$...$` (inline) and `$$...$$` (block)
- IUPAC/mhchem-style chemical notation: `\ce{...}` embedded in Markdown text
- Mermaid diagrams (handled by a separate pipeline)

The chemical rendering subsystem **intercepts** raw `\ce{...}` strings, **converts** them into standard KaTeX-compatible LaTeX notation, then **delegates** final rendering to `flutter_math_fork` via `gpt_markdown`.

This document defines the full technical contract for that conversion pipeline.

---

## 2. Dependency Stack

| Layer | Package | Version Constraint | Role |
|---|---|---|---|
| Math Typesetting | `flutter_math_fork` | `>=0.7.4` | KaTeX-based TeX → Flutter Widget renderer |
| Markdown + LaTeX | `gpt_markdown` | `>=1.1.5` | Parses Markdown, delegates `$...$` blocks to `flutter_math_fork` |
| State / Settings | `provider` | `>=6.1.5` | Font size / font family injection |
| Link Launching | `url_launcher` | `>=6.3.2` | Handles hyperlinks inside rendered content |

### Key Configuration

```dart
// GptMarkdown must be configured with dollar-sign LaTeX delimiters:
GptMarkdown(
  processedText,
  useDollarSignsForLatex: true,   // ← REQUIRED for \$...\$ → Math.tex()
  style: TextStyle(...),
)
```

> **Critical:** `useDollarSignsForLatex: true` is **mandatory**. Without it, `gpt_markdown`
> will not forward inline math segments to `flutter_math_fork`, causing literal `$...$`
> text to appear instead of rendered equations.

---

## 3. Rendering Pipeline

```
Raw Markdown from AI
        │
        ▼
 _parseContent()          ← Splits into [Mermaid | Markdown] segments
        │
        ├──[mermaid]──► FlowchartWidget (Mermaid renderer, separate pipeline)
        │
        └──[markdown]──► _preprocessChemical()
                                 │
                                 ▼
                       _convertChemical()  ← Converts \ce{...} body → LaTeX tokens
                                 │
                                 ▼
                       "$  <latex>  $"     ← Wrapped in inline-math delimiters
                                 │
                                 ▼
                        GptMarkdown()      ← Full Markdown parse
                                 │
                                 ▼
                       flutter_math_fork   ← KaTeX rendering → Flutter Widget
```

### Step-by-step

| Step | Function | Input Example | Output Example |
|---|---|---|---|
| 1 | `_parseContent` | `"Text \$\\ce{H2O}\$ more"` | `[_Segment(markdown, ...)]` |
| 2 | `_preprocessChemical` | `"\\ce{H2O}"` | `"$ H_{2}O $"` |
| 3 | `_convertChemical` | `"H2O"` | `"H_{2}O"` |
| 4 | `GptMarkdown` | `"$ H_{2}O $"` | Calls `Math.tex("H_{2}O")` |
| 5 | `flutter_math_fork` | `"H_{2}O"` | Rendered Flutter Widget |

---

## 4. Input Syntax Specification

### 4.1 Accepted Raw Formats

The pre-processor accepts `\ce{...}` in any of the following surface forms:

| Format | Example | Notes |
|---|---|---|
| Bare (no dollar signs) | `\ce{H2SO4}` | Pure `\ce{}` in prose |
| Inline math wrapped | `$\ce{H2SO4}$` | Standard mhchem syntax |
| With leading/trailing spaces | `$ \ce{H2SO4} $` | Tolerant of whitespace |
| Multi-step reactions | `\ce{2H2 + O2 -> 2H2O}` | Arrow conversion applied |
| Equilibrium reactions | `\ce{N2 + 3H2 <-> 2NH3}` | `<->` handled |

> **Not supported natively:** `\ce{...}` nested inside `$$...$$` block math, or `\ce{}` with
> `mhchem` package extensions (phase annotations like `_(s)`, `_(aq)` etc.) — see
> [§9 Limitations](#9-known-limitations--edge-cases).

### 4.2 Delimiter Regex

```dart
final _cePattern = RegExp(r'\$?\s*\\ce\{([^}]+)\}\s*\$?');
```

**Match behavior:**

- `\$?` — optionally consume a leading `$`
- `\s*` — allow arbitrary whitespace before/after `\ce`
- `\\ce\{` — literal `\ce{`
- `([^}]+)` — capture group 1: everything up to the first `}`
- `\}\s*\$?` — closing brace, optional trailing `$`

> **Important:** `[^}]+` is **greedy and non-recursive**. Nested braces inside `\ce{...}` (e.g.,
> `\ce{Fe^{3+}}`) will be **truncated at the first inner `}`**. This is a known limitation.
> Use `\ce{Fe^3+}` instead.

---

## 5. Pre-processing Rules (`_preprocessChemical`)

**Function signature:**

```dart
static String _preprocessChemical(String text)
```

**Algorithm:**

1. Apply `_cePattern.replaceAllMapped` across the entire input string.
2. For each match, extract capture group 1 (the chemical formula body).
3. Pass the body through `_convertChemical()`.
4. Wrap the result: `'$ ${converted} $'` (inline math with surrounding spaces).
5. Return the fully substituted string; all other content is left unchanged.

**Whitespace contract:**

The output always wraps the converted formula with a single space on each side inside the dollar signs: `$ formula $`. This ensures `gpt_markdown`'s inline math tokenizer correctly identifies the boundaries. Do **not** remove these spaces.

---

## 6. Chemical-to-LaTeX Conversion Rules (`_convertChemical`)

**Function signature:**

```dart
static String _convertChemical(String formula)
```

Conversions are applied **sequentially in the following order**. Order is significant.

### Rule 1 — Subscript Numerals

```dart
result.replaceAllMapped(
  RegExp(r'([A-Za-z)])(\d+)'),
  (m) => '${m.group(1)}_{${m.group(2)}}',
)
```

| Input | Output | Notes |
|---|---|---|
| `H2O` | `H_{2}O` | Digit after letter → subscript |
| `C6H12O6` | `C_{6}H_{12}O_{6}` | Multiple subscripts in sequence |
| `Ca(OH)2` | `Ca(OH)_{2}` | Digit after `)` also subscripted |
| `Fe2O3` | `Fe_{2}O_{3}` | Multi-letter element name |

**Regex:** `([A-Za-z)])(\d+)` captures a letter OR closing parenthesis followed by one or more digits.

> **Note:** Only **single run** of digits is captured per match. `H12` produces `H_{12}`, not `H_{1}` + `2`.

### Rule 2 — Superscript Charges

```dart
result.replaceAllMapped(
  RegExp(r'\^?(\d*[+-])(?!\})'),
  (m) => '^{${m.group(1)}}',
)
```

| Input | Output | Notes |
|---|---|---|
| `Na+` | `Na^{+}` | Simple positive charge |
| `Cl-` | `Cl^{-}` | Simple negative charge |
| `Fe3+` | `Fe_{3}^{+}` | After Rule 1, `3` → `_{3}` first, then `+` → `^{+}` |
| `SO4^2-` | `SO_{4}^{2-}` | Explicit caret with numeric charge |
| `^2-` | `^{2-}` | Bare caret consumed |

**Negative lookahead `(?!\})`:** Prevents double-processing of already-converted `^{...}` groups.

**Regex:** `\^?(\d*[+-])(?!\})` — optional leading `^`, then optional digits, then `+` or `-`, not followed by `}`.

### Rule 3 — Reversible Reaction Arrow

```dart
result.replaceAll('<->', '\\rightleftharpoons ');
```

| Input | Output |
|---|---|
| `N2 + 3H2 <-> 2NH3` | `N_{2} + 3H_{2} \rightleftharpoons  2NH_{3}` |

> **Must be applied before Rule 4** (forward arrow) to prevent `<->` being partially matched
> as `->`. The current implementation correctly applies `<->` first.

### Rule 4 — Forward Reaction Arrow

```dart
result.replaceAll('->', '\\rightarrow ');
```

| Input | Output |
|---|---|
| `2H2 + O2 -> 2H2O` | `2H_{2} + O_{2} \rightarrow  2H_{2}O` |

> Trailing space after `\rightarrow` is intentional — prevents accidental concatenation with
> the following token.

### Rule 5 — Gas Evolution Symbol `↑`

```dart
result.replaceAllMapped(
  RegExp(r'\^(?!\{)'),
  (m) => '\\uparrow ',
)
```

| Input | Output | Notes |
|---|---|---|
| `CO2^` | `CO_{2}\uparrow ` | Bare `^` not followed by `{` |
| `Fe^{3+}` | *(unchanged)* | `^{` is excluded by lookahead |

> After Rule 2 has converted `^2-` → `^{2-}`, any remaining bare `^` is treated as a
> gas-evolution marker (↑ symbol in traditional Chinese chemistry notation).

---

## 7. Regex Definitions & Semantics

All regexes are **pre-compiled at module top-level** (outside any widget class) to avoid
reallocation on every `build()` call. This is a performance-critical requirement.

```dart
// File: lib/widgets/rich_content_view.dart — top-level declarations

final _cePattern = RegExp(r'\$?\s*\\ce\{([^}]+)\}\s*\$?');
final _subscriptPattern = RegExp(r'([A-Za-z)])(\d+)');
final _chargePattern = RegExp(r'\^?(\d*[+-])(?!\})');
final _mermaidBlockPattern = RegExp(
  r'```mermaid\s*\n([\s\S]*?)```',
  multiLine: true,
  caseSensitive: false,
);
```

| Constant | Purpose | Multiline | Case-Insensitive |
|---|---|---|---|
| `_cePattern` | Match `\ce{...}` with optional `$` wrappers | No | No |
| `_subscriptPattern` | Subscript numerals in formula body | No | No |
| `_chargePattern` | Ion charges (+ / −) with optional `^` prefix | No | No |
| `_mermaidBlockPattern` | Extract mermaid fenced code blocks | **Yes** | **Yes** |

---

## 8. Supported Chemical Notation

### 8.1 Fully Supported

| Notation Type | Example Input | Rendered Output |
|---|---|---|
| Simple molecule | `\ce{H2O}` | H₂O |
| Compound with parentheses | `\ce{Ca(OH)2}` | Ca(OH)₂ |
| Organic molecule | `\ce{C6H12O6}` | C₆H₁₂O₆ |
| Simple ion charge | `\ce{Na+}` | Na⁺ |
| Multivalent ion | `\ce{Fe3+}` | Fe³⁺ |
| Anion | `\ce{SO4^2-}` | SO₄²⁻ |
| Forward reaction | `\ce{2H2 + O2 -> 2H2O}` | 2H₂ + O₂ → 2H₂O |
| Equilibrium reaction | `\ce{N2 + 3H2 <-> 2NH3}` | N₂ + 3H₂ ⇌ 2NH₃ |
| Gas evolution | `\ce{CaCO3 -> CaO + CO2^}` | CaCO₃ → CaO + CO₂↑ |

### 8.2 Partially Supported (Manual Workaround Required)

| Notation | Issue | Workaround |
|---|---|---|
| Phase labels `(s)`, `(aq)` | Not converted, rendered as plain text | Use `\text{(s)}` directly in LaTeX |
| Nested braces `Fe^{3+}` | `_cePattern` truncates at first `}` | Write `\ce{Fe3+}` instead |
| Isotopes `^{14}C` | Caret consumed before subscript Rule | Write `\ce{{}^{14}C}` in raw LaTeX |
| Electron dot formulas | No conversion rule | Use inline image or Unicode |
| Reaction conditions (e.g., `\overset{\Delta}{\rightarrow}`) | Not supported | Write raw LaTeX `$...$` manually |

---

## 9. Known Limitations & Edge Cases

### 9.1 Non-Recursive Brace Matching

`_cePattern` uses `[^}]+` which cannot match nested braces. Input like:

```
\ce{Fe^{3+}(OH)2}
```

will be captured as `Fe^{3` (truncated at the first inner `}`). This is a structural limitation of the regex approach.

**Mitigation:** Avoid nested braces in `\ce{...}`. Use flat charge notation instead:

```
\ce{Fe3+}  ✓
\ce{Fe^{3+}}  ✗
```

### 9.2 Ordering Dependency Between Rules 3 and 4

If `<->` were processed after `->`, the `<-` fragment would remain unconverted.
The current implementation in `_convertChemical` applies `<->` replacement **first** (Rule 3),
guaranteeing correct output. Any future refactoring that changes this order will break
equilibrium arrow rendering.

### 9.3 Numeric Coefficients Before Elements

The subscript pattern `([A-Za-z)])(\d+)` does **not** subscript leading stoichiometric
coefficients (e.g., `2H2` → `2H_{2}`, not `_{2}H_{2}`). This is the correct behavior as
coefficients should remain as regular-size text, not subscripts.

### 9.4 GptMarkdown Version Compatibility

`useDollarSignsForLatex` is a parameter introduced in `gpt_markdown ≥ 1.1.5`. If this
parameter is absent (older versions), inline `$...$` math **will not render**. Always enforce:

```yaml
# pubspec.yaml
gpt_markdown: ^1.1.5
```

### 9.5 SelectionArea Wrapping

The root widget is wrapped in `SelectionArea`, enabling text selection across markdown and
math segments. `flutter_math_fork` widgets inside `SelectionArea` should render correctly,
but `SelectionArea` may conflict with some custom gesture handlers on interactive math content.

### 9.6 Performance Constraint: `RepaintBoundary`

Both the outer `SelectionArea` column and individual mermaid segments are wrapped with
`RepaintBoundary`. Math-heavy content should also independently be wrapped if it causes
unnecessary repaints. Profile with Flutter DevTools before adding more boundaries.

---

## 10. Testing Matrix

The following test cases MUST pass for any modification to `_convertChemical` or `_preprocessChemical`.

### Unit Test Cases

```dart
// Expected: _convertChemical('H2O') == 'H_{2}O'
// Expected: _convertChemical('C6H12O6') == 'C_{6}H_{12}O_{6}'
// Expected: _convertChemical('Ca(OH)2') == 'Ca(OH)_{2}'
// Expected: _convertChemical('Na+') == 'Na^{+}'
// Expected: _convertChemical('Fe3+') == 'Fe_{3}^{+}'
// Expected: _convertChemical('SO4^2-') == 'SO_{4}^{2-}'
// Expected: _convertChemical('2H2 + O2 -> 2H2O') == '2H_{2} + O_{2} \\rightarrow  2H_{2}O'
// Expected: _convertChemical('N2 + 3H2 <-> 2NH3') == 'N_{2} + 3H_{2} \\rightleftharpoons  2NH_{3}'
// Expected: _convertChemical('CO2^') == 'CO_{2}\\uparrow '
```

### Integration (Widget) Test Cases

| Input Markdown | Expected Rendered Behavior |
|---|---|
| `\ce{H2O}` | Renders inline math with H subscript 2 O |
| `$\ce{H2SO4}$` | Same as above, dollar-wrapped variant |
| `\ce{2H2 + O2 -> 2H2O}` | Forward arrow (→) rendered |
| `\ce{N2 + 3H2 <-> 2NH3}` | Double-headed equilibrium arrow (⇌) rendered |
| `\ce{Na+}` and `\ce{Cl-}` | Superscript charges rendered |
| Text before `\ce{H2O}` and after | Non-formula text unaffected |

---

## 11. Extension Guidelines

### 11.1 Adding a New Conversion Rule

1. Add the new regex as a top-level `final` constant (pre-compiled) in `rich_content_view.dart`.
2. Insert the transformation inside `_convertChemical()` at the **correct position** relative
   to existing rules (order matters — see §6).
3. Add test cases to the testing matrix (§10).
4. Update §8 (Supported Notation) and §6 (Conversion Rules) in this document.

### 11.2 Adding Phase Labels (e.g., `_(s)`, `_(aq)`)

Phase labels must be added **before** the subscript rule to avoid digit-in-phase-label conflicts:

```dart
// Proposed Rule 0 — Phase labels (insert BEFORE subscript rule)
result = result.replaceAllMapped(
  RegExp(r'_\((s|l|g|aq)\)'),
  (m) => '_{\\text{(${m.group(1)})}}',
);
```

### 11.3 Replacing the Pre-processor with mhchem

If `flutter_math_fork` adds native `mhchem` support (`\ce{}` recognized as a built-in command),
the entire `_preprocessChemical()` / `_convertChemical()` pipeline can be removed.
The raw `\ce{H2SO4}` string would then be passed directly into `$...$` delimiters without
custom conversion. Monitor the `flutter_math_fork` changelog for `mhchem` package inclusion.

### 11.4 Block-Level Chemical Equations

Currently all chemical equations render inline (`$ ... $`). To support block-level display:

1. Add a separate regex that matches `$$\ce{...}$$` or a custom `\[ce{...}\]` notation.
2. Wrap the conversion result in `$$` instead of `$`.
3. Ensure `gpt_markdown` correctly handles `$$...$$` block mode (already supported in ≥ 1.1.5).

---

## Appendix A — Full `_convertChemical` Implementation (Reference)

```dart
// Pre-compiled regexes (top-level, outside any class)
final _cePattern       = RegExp(r'\$?\s*\\ce\{([^}]+)\}\s*\$?');
final _subscriptPattern = RegExp(r'([A-Za-z)])(\d+)');
final _chargePattern   = RegExp(r'\^?(\d*[+-])(?!\})');

// Preprocessing entry point
static String _preprocessChemical(String text) {
  return text.replaceAllMapped(_cePattern, (m) {
    final converted = _convertChemical(m.group(1)!);
    return '$ $converted $';
  });
}

// Chemical formula → LaTeX conversion
static String _convertChemical(String formula) {
  var result = formula;
  // Rule 1: Subscript numerals
  result = result.replaceAllMapped(
    _subscriptPattern,
    (m) => '${m.group(1)}_{${m.group(2)}}',
  );
  // Rule 2: Superscript charges
  result = result.replaceAllMapped(
    _chargePattern,
    (m) => '^{${m.group(1)}}',
  );
  // Rule 3: Equilibrium arrow (MUST precede Rule 4)
  result = result.replaceAll('<->', '\\rightleftharpoons ');
  // Rule 4: Forward reaction arrow
  result = result.replaceAll('->', '\\rightarrow ');
  // Rule 5: Gas evolution (bare ^ not followed by {)
  result = result.replaceAllMapped(
    RegExp(r'\^(?!\{)'),
    (m) => '\\uparrow ',
  );
  return result;
}
```

---

## Appendix B — Glossary

| Term | Definition |
|---|---|
| KaTeX | A JavaScript math typesetting library; `flutter_math_fork` implements an equivalent rendering engine in Flutter |
| mhchem | A LaTeX package providing `\ce{}` for chemical equations — NexAI emulates a subset of it via pre-processing |
| `\ce{}` | mhchem command for chemical equations, e.g., `\ce{H2O}` |
| LHS / RHS | Left-hand side / Right-hand side of a chemical reaction |
| Subscript | Characters below the baseline, e.g., the "2" in H₂O |
| Superscript | Characters above the baseline, e.g., the "+" in Na⁺ |
| `flutter_math_fork` | Flutter port of the KaTeX rendering engine |
| `gpt_markdown` | Flutter package providing Markdown parsing with integrated LaTeX math rendering |
| Segment | An internal parse unit in `RichContentView` — either `_SegmentType.markdown` or `_SegmentType.mermaid` |
