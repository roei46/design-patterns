# Design Patterns — iOS (Swift)

Six design patterns from the "Design Patterns" home assignment, implemented in plain Swift with
Swift Testing, plus a small SwiftUI app that runs each one.

## Run and test
- Open `DesignPatterns/DesignPatterns.xcodeproj` in Xcode.
- **⌘R** runs the app: a list of the six patterns. Each page has a **Run** button that calls the
  real pattern code and shows green/red result lines.
- **⌘U** runs all tests.

## Layout
```
DesignPatterns/
  DesignPatterns/              app target
    Singleton/ Builder/ Adapter/ Flyweight/ ChainOfResponsibility/ Strategy/
                               pattern code + its demo ViewModel and View
    Demo/                      list screen and the shared output row
    DesignPatternsApp.swift    composition root: creates every ViewModel and injects it
  DesignPatternsTests/         one folder per pattern, same names
```

## Conventions
- **MVVM.** Views only display; each demo page has an `@Observable @MainActor` ViewModel that
  is created in `DesignPatternsApp` and passed in.
- **Swift 6, no default main-actor isolation.** Pattern code isn't tied to the main thread; the
  compiler checks thread safety (`Sendable`). Shared mutable state sits behind a `Mutex`.
- **Typed errors.** Each pattern has its own error enum and uses `throws(SomeError)`, so callers
  know every possible failure.
- **Tests** cover the happy path, at least one failure scenario and one negative test per pattern.

---

## Singleton — shared settings
**What:** one `SettingsProvider` per process holds the app settings. Settings are loaded once and
then frozen.

```swift
try SettingsProvider.shared.load(AppSettings(apiBaseURL: url, requestTimeoutMs: 5_000, maxRetries: 3))
let timeout = try SettingsProvider.shared.current().requestTimeoutMs
```

**Design**
- `private init()` + `static let shared`. Swift's `static let` is lazy and thread-safe, so this is
  the whole `getInstance()`.
- `AppSettings` is a struct with only `let`s, so loaded settings can't change.
- Loading the same values again is a no-op; different values throw `.conflictingReinit` and keep
  the original. Reading before loading throws `.notLoaded`.
- The value sits in a `Mutex`, because every thread shares the instance.
- `resetForTesting()` exists only in Debug builds.

**Tests:** same instance on repeated calls, stable reads, re-loading the same values, **conflicting
re-init rejected (negative)**, **read before load (failure)**, reset, and 100 concurrent loads with
exactly one winner. All Singleton tests run `.serialized` under one parent suite, because they
share one instance.

**Risks of global mutable state:** hidden dependencies (any code can reach `.shared`), tests leaking
into each other (hence the reset hook), it can't be swapped for a fake, and reading before loading
fails at runtime, not compile time.

**Threads vs processes:** all threads in a process share the instance (Swift threads share memory,
unlike Node.js workers), so it needs a lock. App extensions and widgets are separate processes and
each gets its own copy.

**Interview discussion: module-level constant or DI instead?** A global `let appSettings = ...` is
lazy, thread-safe and immutable, which is simpler when values are known at startup. Dependency
injection is usually better still: create `AppSettings` in `App.init` and pass it on, so
dependencies are visible and tests pass their own values. With many processes or instances (the
serverless question), each starts with an empty singleton, so shared settings must come from
outside (bundle, App Group, remote config).

---

## Builder — report export request
**What:** set report options step by step; `build()` checks them all together and returns an
immutable `ReportRequest`, or a typed error.

```swift
let report = try ReportRequestBuilder()
    .withDateRange(from: jan1, to: jan31)
    .addFilter(field: "country", value: "IL")
    .withFormat(.json)
    .enableCompression()
    .build()
```

**Design**
- `ReportRequest` is a struct with only `let`s, and its init is `fileprivate`, so only the builder
  can create one and nobody can skip the checks.
- `build()` rejects a missing date range, an inverted date range, and PDF + compression (a PDF is
  already compressed). A one-day range is valid.
- The builder is a **struct**: each step returns an updated copy. A built report therefore never
  shares its `filters` array with the builder or with later builds. (TypeScript needs `readonly` +
  `Object.freeze` for this; Swift value types give it for free.)

**Tests:** chaining with all options, two different reports from the same API, defaults, one-day
range, **inverted dates and PDF + compression rejected (negative)**, **missing date range
(failure)**, and changing the builder after `build()` leaves the built report unchanged.

**Interview discussion: when is something simpler than a Builder?** For a few fields with no rules
between them, a plain struct with default values is enough; Swift's default arguments remove most
of the problem Builder solves elsewhere. A throwing `init` can run the same checks when all values
are known at once. An enum with associated values (Swift's discriminated union) can make invalid
combinations impossible to write. Builder pays off with many optional steps, options collected in
different places, or one base configuration reused for several results.

---

## Adapter — two shipping providers
**What:** two providers return prices in different shapes. One adapter per provider translates its
format into the app's `RateQuote`. App code only knows `ShippingRateProviderProtocol`.

| Provider | Raw response | Normalized |
|---|---|---|
| A | `{"price":120,"currency":"USD"}` (dollars, wants kg) | `RateQuote(amountMinor: 12000, currency: .usd)` |
| B | `{"total_amount":12000,"currency_code":"USD","minor_units":true}` (wants grams) | same |

**Design**
- Money is always integer minor units (`Int` cents). Prices are decoded as `Decimal`, never
  `Double`, so `19.99` becomes exactly `1999`.
- Units are converted in the adapter (grams → kg for A).
- Each provider's errors are mapped to one `ShippingError`: A's `URLError(.timedOut)` and B's own
  `ProviderBError.requestTimedOut` both become `.timeout`. Unknown currency → `.invalidCurrency`,
  bad JSON / negative / fractional cents → `.malformedPayload`, anything else →
  `.providerUnavailable`.
- Each provider's JSON shape is a `private` type inside its adapter, so no other code can depend on it.
- The provider clients are protocols only so tests can fake them. With many HTTP providers you'd use
  one shared HTTP client protocol and one adapter per provider instead.

**Tests:** both providers normalize to an **equal** `RateQuote`, cents conversion (incl. `19.99`),
units sent to each client (spies), **invalid currency (negative)**, **timeout (failure)** for each
provider, other client errors, and malformed payloads (parameterized).

**Interview discussion: where do retries and currency conversion live? Adapter vs anti-corruption
layer?** Retries belong outside the adapter (the Strategy pattern below wraps any provider call), so
every provider gets the same policy and the adapter stays a pure translator. Currency conversion is
business logic that needs rates, so it belongs in a service above the adapters; the adapter only
normalizes format, units and errors. An anti-corruption layer is the bigger idea: a boundary that
keeps a whole external model out of your domain. Adapters are one building block of it.

---

## Flyweight — shared port metadata
**What:** many shipping rates point to the same port. Instead of each rate copying "Haifa, Israel,
Asia/Jerusalem", the factory hands out one shared, immutable `PortMetadata` per port code.

```swift
let port = try factory.metadata(for: "ILHFA")
let rate = ShippingRate(shipmentID: "S1", priceMinor: 12_000, timestamp: .now, port: port)
```

**Design**
- `PortMetadata` is an immutable `final class` (only `let`s), so it can be shared by reference.
  Its init is `fileprivate`, so only the factory creates one.
- Per-rate data (`shipmentID`, `priceMinor`, `timestamp`) lives in `ShippingRate`, outside the
  flyweight. No customer data goes into the shared object.
- Codes are canonicalized (trimmed, uppercased): `" ilhfa "` and `"ILHFA"` give the same object.
- The cache sits in a `Mutex`, so concurrent lookups can't create two objects for one code.
- **Measuring:** `createdCount` is the allocation count. The demo also shows the app's memory
  footprint before/after creating 100,000 rates (illustrative only; it varies per run).

**Tests:** same object (`===`) for the same code, canonical codes, different objects for different
codes, 10,000 lookups → 3 created, changing a rate doesn't touch the shared port, concurrent lookups
→ one object, **unknown port (negative)**, **invalid code (failure)**.

**Interview discussion: when can a cache cost more than it saves? How to cap it?** When most keys
are unique (nothing gets reused), each cached object costs memory plus dictionary overhead and saves
nothing, and the cache never shrinks. Here it's safe because the set of ports is small and fixed.
For an open-ended key set, cap the cache: an LRU with a max size, or `NSCache`, which evicts under
memory pressure.

---

## Chain of Responsibility — API request checks
**What:** a request passes through ordered handlers: **Auth → Validation → RateLimit →
Eligibility**. Each one passes it on or rejects it; the first rejection stops the chain.

```swift
let chain = RequestChain(handlers: [AuthHandler(), ValidationHandler(), RateLimitHandler(limit: 10), EligibilityHandler()])
let result = await chain.run(request)   // .accepted or .rejected(.unauthorized / ...)
```

**Design**
- Handlers implement `RequestHandlerProtocol.check(_:) async -> Rejection?` (`nil` = pass on).
- The order is the array order, so it's deterministic.
- Handlers don't call `next()`; the chain's loop moves on. So "calling `next()` twice" is
  impossible by design.
- The result is typed: `ChainResult.accepted` or `.rejected(Rejection)`.
- `RateLimitHandler` is the only handler with state (a per-user counter in a `Mutex`).

**Tests:** valid request accepted, rejection at each of the 4 stages, handlers run in order (spies),
the chain stops at the first rejection (later spies never run), and **side effects are skipped**: a
request rejected at Auth doesn't increase the rate-limit count.

**Interview discussion: when is middleware enough? What if several handlers may process the
request?** For a fixed list of yes/no checks, plain middleware (or a few `guard`s) is enough, and
this chain is essentially that. The pattern matters more when handlers are added, removed or
reordered at runtime. If several handlers may independently act on the same request, it's no longer
"first one wins": you'd run all of them and collect results (closer to an observer or pipeline), and
you have to define how their outcomes combine. iOS's responder chain is the same pattern: an event
travels up until someone handles it.

---

## Strategy — retry policies
**What:** one retry loop, several interchangeable policies. The caller passes a strategy;
`executeWithRetry` doesn't know which one it got.

```swift
let data = try await executeWithRetry(
    strategy: ExponentialBackoffRetry(maxAttempts: 4, baseDelayMs: 100, maxDelayMs: 2_000, jitterMs: 50),
    sleep: { ms in try? await Task.sleep(for: .milliseconds(ms)) }
) {
    try await api.fetchQuote()
}
```

**Design**
- `RetryStrategyProtocol` has `shouldRetry(_:attempt:)` and `nextDelayMs(attempt:)`.
- **Attempt indexing is 1-based:** attempt 1 is the first call. After attempt N fails, the loop asks
  `shouldRetry(error, attempt: N)` and waits `nextDelayMs(attempt: N)`.
- `NoRetry` never retries. `FixedDelayRetry` waits the same time each time. `ExponentialBackoffRetry`
  waits `base × 2^(attempt−1)`, capped at `maxDelayMs`, plus random `0...jitterMs`.
- Only 429 and 5xx (`HTTPError.isRetryable`) are retried; other errors are thrown right away.
- `sleep` is injected, so tests record delays instead of waiting.

**Tests:** exact attempts and delays for each strategy (`[200, 200]`, `[100, 200, 400, 500]` with
the cap), max-attempt limit, jitter range, **429 retried**, **400 not retried (negative)**,
non-HTTP errors not retried, and no sleep on first-try success.

**Interview discussion: idempotency, circuit breakers, retry budgets.** Only retry calls that are
safe to repeat: a GET or a request with an idempotency key. Retrying a non-idempotent POST can
charge a customer twice. A **circuit breaker** stops calling a provider for a while after many
failures, so retries don't hammer a service that's down. A **retry budget** caps retries across all
calls (e.g. at most 10% extra traffic), so one bad dependency can't multiply load. Strategy decides
how one call retries; breakers and budgets decide whether retrying is allowed at all.
