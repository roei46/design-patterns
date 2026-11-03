import Testing

/// Parent suite for every test that touches SettingsProvider.shared.
/// `.serialized` here covers all nested suites, so they never run at the same time.
@Suite(.serialized)
enum SingletonTests {}
