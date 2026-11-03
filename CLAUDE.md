# Design Patterns — Python server + iOS

## 1. The assignment (summary)

Home assignment "Design Patterns" (Eyal Segal). Original PDF targets TypeScript/Node.js;
we implement it in **Python** (server) and **Swift** (iOS). Goal: understand each pattern's
intent, when to use it, its costs and its alternatives — shown on simulated backend scenarios.

General requirements (per pattern, on both sides):
- **One folder per pattern** with the implementation and automated tests.
- A **README** per pattern: design rationale, a usage example, alternatives.
- At least **one failure scenario and one negative test** per pattern.
- Prefer plain code when a pattern would add unnecessary complexity.

The six patterns and their scenarios:

| Pattern | Kind | Scenario | Must show |
|---|---|---|---|
| Singleton | Creational | Shared settings / config | Load once, frozen config, reject conflicting re-init, test-only reset, same instance on repeated calls. Discuss: module-level instance / DI as alternatives; not shared across processes. |
| Builder | Creational | Report export request | Immutable `ReportRequest`, fluent builder: `with_date_range`, `add_filter`, `with_format`, `enable_compression`, `build`. Reject inverted dates and incompatible combos. Built results don't share mutable lists. |
| Adapter | Structural | Two shipping providers | `ShippingRateProvider` interface → `RateQuote`. Provider A `{price:120, currency:"USD"}`, Provider B `{total_amount:12000, currency_code:"USD", minor_units:true}`. Normalise money (integer minor units), errors; app depends only on the interface. Tests: equal outputs, invalid currency, timeout, malformed payload. |
| Flyweight | Structural | Shared port metadata | `PortMetadataFactory` keyed by port code returns the same immutable object; per-rate data stays outside. Measure allocations / memory. Tests: same reference for same code, different for different codes, mutation blocked. |
| Chain of Responsibility | Behavioral | API request checks | `RequestHandler` contract; Auth → Validation → RateLimit → Eligibility. Stop at first rejection with a typed result, fixed order, async handlers, no double `next()`. Tests: success, rejection at each stage, order, side effects skipped. |
| Strategy | Behavioral | Retry policies | `RetryStrategy` with `should_retry(error, attempt)` and `next_delay_ms(attempt)`. NoRetry, FixedDelay, ExponentialBackoff (cap + jitter). `execute_with_retry()` with injected sleep. Tests: exact attempts/delays, max attempts, 429, non-retryable errors. Document attempt indexing. |

**Bonus (at the end):** a small service for shipping quotes and report exports that uses the
six patterns only where they reduce real complexity — config (Singleton or DI), report
options (Builder), two shipping APIs (Adapter), port metadata (Flyweight), request checks
(Chain), per-provider retry (Strategy). Deliver: README, typed contracts, unit tests, one
integration test, a short architecture diagram. The iOS app calls it.

Grading (from the PDF): correctness and edge cases 30, type design and safe error handling 20,
tests and failure scenarios 20, pattern choice and trade-off reasoning 20, clarity and docs 10.

## 2. Decisions

- **Server: Python** (not TypeScript). Python 3.12, Poetry, pytest, strict type hints checked with mypy.
- **iOS: plain Swift + tests** (Swift Testing), plus **one small SwiftUI screen** that shows the patterns working. Keep iOS simple.
- **Scope:** the six patterns first (both sides), then the bonus service.
- Each pattern is self-contained; no pattern depends on another until the bonus.

## 3. Repo structure

```
design-patterns/
  CLAUDE.md              ← this file (applies to both sides)
  server/                ← Python. Rules in server/CLAUDE.md
    patterns/
      singleton/  builder/  adapter/  flyweight/  chain_of_responsibility/  strategy/
        (code + tests + README.md in each)
    bonus/               ← the integrated service (later)
  ios/                   ← Swift. Rules in ios/CLAUDE.md
```

## 4. Bonus API contract

To be defined here **before** building the bonus. Any endpoint, field or status is written
here first, then implemented on the server and in the app.
