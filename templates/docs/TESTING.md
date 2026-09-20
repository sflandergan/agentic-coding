# Testing

## Behavior-Focused Tests

Write tests that describe behavior the system exhibits, not the implementation details. A test should still pass after an internal refactor that preserves behavior, and fail when the behavior changes.

## Arrange-Act-Assert

Structure each test in three phases:

1. **Arrange** — set up preconditions and inputs.
2. **Act** — call the system under test.
3. **Assert** — verify the observable outcome.

Keep the Act phase to a single call when possible. Multiple assertions in one test are fine when they describe a single behavior.

## Exact Assertions

- Prefer exact-value assertions over loose checks.
- Assert on the specific value, not just the shape (`expect(x).toBe(3)` over `expect(x).toBeGreaterThan(0)`).
- Avoid `toMatchObject` and similar partial matchers when an exact match is possible.

## TDD

- For behavior changes, write a failing test first, then implement the minimum code to make it pass, then refactor.
- Skip TDD for docs-only, config-only, or trivial wiring changes.

## Test Layout

Follow the conventions of the package's chosen test framework and language (for example, JUnit/Maven for Java, Jest/Vitest for TypeScript, pytest for Python, Go's `*_test.go` co-location). Production source and test code must be clearly separated, but the exact directory shape, file suffix, and discovery rules are framework-defined — do not invent a custom layout when a framework convention already exists.
