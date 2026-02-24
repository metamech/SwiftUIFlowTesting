**Yes, snapshot images are usually stored in git**—they live in `__Snapshots__/` folders alongside your test files (e.g. `ProfileViewTests.swift` → `ProfileViewTests/ProfileViewTests.test_profile_loaded.png`). This is the standard SnapshotTesting pattern and aligns with how Jest snapshots work: baselines are source-controlled so tests are self-contained and diffs are reviewable in PRs.[1][3]

## Claude Code + image snapshots: Minimal token impact

**Claude Code will handle this fine**—it doesn't "load and visualize" images at all. Here's why:

### 1. Claude Code only sees *code*, never images

```swift
// Claude Code reads/writes this:
func test_profile_loaded() {
    let model = ProfileModel(user: .fixtureLoaded)
    let view = ProfileView(model: model)
    
    assertSnapshot(  // ← Claude understands this line
        of: view, 
        as: .image(layout: .device(config: .iPhoneX)), 
        named: "profile-loaded"
    )
}
```

- The **`.png` reference image** lives on disk, compared *by XCTest at runtime*.
- Claude Code only needs to **reason about the test code** and snapshot **names**.
- No image data enters Claude's context window—ever.

**Token cost**: Same as any other test assertion (`XCTAssertEqual`). Zero image processing.

### 2. Claude can iterate/update snapshots easily

When UI changes break snapshots, Claude sees:

```
✗ test_profile_loaded (123.4ms)
  • Recorded image does not match reference
  • Reference: ProfileViewTests.test_profile_loaded.png
  • Run with `--update` to overwrite
```

**Claude's natural response**: "Run `swift test --update` to accept new snapshots, or delete specific ones." No vision needed.

With your `FlowTester`, Claude just updates **step names** and **model actions**:

```swift
// Before (broken):
.step("payment") { model in
    model.proceedToPayment()  // Changed to `advanceToPayment()`
}

// Claude proposes:
.step("payment") { model in
    model.advanceToPayment()  // Fixed method name
}
```

Tests regenerate images automatically. Claude never touches the PNGs directly.

### 3. Git storage: Practical workflow

**For solo dev/small teams** (your use case), **store images in git with Git LFS**:

```bash
# .gitattributes
*__Snapshots__/*.png filter=lfs diff=lfs merge=lfs -text

# Initial setup
git lfs track "*__Snapshots__/*.png"
git add .gitattributes
```

- **Repo bloat**: Minimal (~100-500KB per screen/flow with good naming). Your macOS apps won't hit GBs.
- **PR diffs**: GitHub/GitLab show image diffs inline. Designers/marketers can review.
- **CI**: `git lfs checkout` before tests (one line in workflow).

**Alternatives if LFS feels heavy**:
- `.gitignore` `__Snapshots__/` + `--update` on CI only (loses PR reviewability).
- External service (ScreenshotBot, etc.) for hosted diffs.[1]

## CLAUDE.md addition for your framework

Add this to ensure Claude Code handles snapshots correctly:

```markdown
## Snapshot workflow

When snapshot tests fail after UI/model changes:

1. **Always run `swift test --update`** first to see new images
2. **Review diffs** in Xcode or `open __Snapshots__/`
3. **Commit new snapshots** if changes are intentional
4. **Delete obsolete snapshots** if tests were removed

**Never** manually edit/delete PNG files—let `--update` manage them.

Example Claude response to failures:
```
Snapshot `ProfileViewTests.test_profile_loaded` failed.

1. Run: `swift test --update`
2. Review: `open Tests/__Snapshots__/ProfileViewTests/`
3. If good → `git add Tests/__Snapshots__/ && git commit`
4. If bad → fix model/view, repeat
```
```

## Bottom line

- **Git storage**: Yes, with LFS (simple setup, low overhead).
- **Claude impact**: None—Claude only sees Swift code + filenames.
- **Workflow**: Smoother than XCTest because failures are **local**, **fast**, and **deterministic**.

Your `FlowTester` + SnapshotTesting combo is actually **more AI-friendly** than XCUITest because:
1. No simulator/process state to reason about.
2. Failures are simple image diffs, not flaky timing issues.
3. Claude can propose exact line changes to fix model actions.

This is production-ready for agentic development across all your macOS apps.

Sources
[1] Strategy for storing snapshots #504 - GitHub https://github.com/pointfreeco/swift-snapshot-testing/discussions/504
[2] Question: how are people storing their snapshot images? #92 - GitHub https://github.com/americanexpress/jest-image-snapshot/issues/92
[3] Snapshot Testing - Jest https://jestjs.io/docs/snapshot-testing
[4] How to Fix 'Snapshot Test' Failures - OneUptime https://oneuptime.com/blog/post/2026-01-24-snapshot-test-failures/view
[5] Screenshot testing | Test your app on Android - Android Developers https://developer.android.com/training/testing/ui-tests/screenshot
[6] How to gitignore snapshot folders? - Stack Overflow https://stackoverflow.com/questions/53230363/how-to-gitignore-snapshot-folders
[7] Avoid calls to `.onAppear` for snapshot testing? - Swift Forums https://forums.swift.org/t/avoid-calls-to-onappear-for-snapshot-testing/62114
[8] Playwright and Github Actions: How to configure screenshots the ... https://www.reddit.com/r/Playwright/comments/1dn82qp/playwright_and_github_actions_how_to_configure/

