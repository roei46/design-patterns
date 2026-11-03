# iOS conventions (Swift)

The assignment, decisions and structure are in the root `CLAUDE.md`.

## This project
- Show the six patterns in **plain Swift**, one folder (Xcode group) per pattern, each with tests and a short README.
- Tests with **Swift Testing** (`@Test`, `#expect`, `#require`): happy path, at least one failure scenario and one negative test per pattern.
- **One list screen** of the six patterns. Each row opens a **small demo page** (a "Run" button + a few lines of output) backed by its own ViewModel that calls the real pattern code. Keep the UI minimal; tests are the proof, the UI is just a demo.
- Build each pattern's demo page right after that pattern's code and tests are done.

## Singleton exception
My general rule is "no singletons; inject dependencies". Here the Singleton exists **only in its own pattern folder**, as the exercise requires. Its README explains why DI is usually preferable. No other code uses it.

## General conventions
- **MVVM.** Views are dumb; ViewModels hold state and orchestration; logic lives below.
- **Dependency injection** via a composition root (`App.init`), behind protocols so things are mockable.
- **Stateless logic = structs; shared mutable state = classes.**
- Swift concurrency (`async/await`), `@Observable` + `@MainActor` for ViewModels.
- Naming: protocols `...Protocol`, display structs `...State`.
- Test the real component, mock its dependencies; assert behavior (use spies), not just return values.
- Avoid "Manager" catch-all types, heavy logic in views, and global state.
