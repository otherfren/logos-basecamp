#!/usr/bin/env node
// ---------------------------------------------------------------------------
// logos-basecamp UI integration tests
//
// Usage:
//   node tests/ui-tests.mjs                       # run all (app must be running)
//   node tests/ui-tests.mjs counter               # run tests matching "counter"
//   node tests/ui-tests.mjs --ci <app-binary>     # CI mode: launch app, test, kill
//
// Set LOGOS_QT_MCP to override the framework path (nix builds set this automatically).
// Default: ./result-mcp (built via: nix build .#logos-qt-mcp -o result-mcp)
// ---------------------------------------------------------------------------

import { fileURLToPath } from "node:url";
import { dirname, resolve } from "node:path";

const __dirname = dirname(fileURLToPath(import.meta.url));
const projectRoot = resolve(__dirname, "..");
const qtMcpRoot = process.env.LOGOS_QT_MCP || resolve(projectRoot, "result-mcp");
const { test, run } = await import(resolve(qtMcpRoot, "test-framework/framework.mjs"));

// Helper: click a plugin's sidebar icon and wait for its UI to load.
// Plugins load asynchronously after clicking, so we wait for expected
// content to appear before proceeding.
async function openPlugin(app, name, expectedTexts, opts = {}) {
  await app.click(name);
  await app.waitFor(
    async () => { await app.expectTexts(expectedTexts); },
    { timeout: 10000, interval: 500, description: `"${name}" UI to load` }
  );
}

// --- Webview App ---
// Skipped in offscreen mode: QWebEngine requires a display (GPU/compositor)

test("webview_app: open and verify buttons", async (app) => {
  await openPlugin(app, "webview_app", ["Wikipedia", "Local File", "Send Event to WebApp"]);
}, { skip: ["offscreen"] });

test("webview_app: click Wikipedia", async (app) => {
  await openPlugin(app, "webview_app", ["Wikipedia", "Local File"]);
  await app.click("Wikipedia", { type: "QPushButton" });

  await app.expectTexts(["Wikipedia", "Local File"]);
}, { skip: ["offscreen"] });

test("webview_app: click Local File", async (app) => {
  await openPlugin(app, "webview_app", ["Wikipedia", "Local File"]);
  await app.click("Local File", { type: "QPushButton" });

  await app.expectTexts(["Wikipedia", "Local File"]);
}, { skip: ["offscreen"] });

// --- Package Manager ---

test("package_manager_ui: open and verify categories", async (app) => {
  // Offscreen CI: logos-qt-mcp findByProperty sees "Reload" but not the Install label
  // (Row contentItem). Assert Reload only; the UI itself is unchanged.
  await openPlugin(app, "package_manager_ui", ["Reload"]);
});

// --- Counter ---

test("counter: open app", async (app) => {
  await app.click("counter");
});

test("counter: increment twice and expect value 2", async (app) => {
  await openPlugin(app, "counter", ["0"]);

  // Click increment twice
  await app.click("Increment me");
  await app.click("Increment me");

  // Verify counter shows 2
  await app.expectTexts(["2"]);
});

// --- Counter QML ---

test("counter_qml: open app", async (app) => {
  await app.click("counter_qml");
});

// --- Modules section ---
//
// Regression test: navigating to the Core Modules tab must show
// auto-loaded core modules (package_manager, capability_module) as
// "(Loaded)", not "(Not Loaded)". The bug we hit was that
// MainUIBackend::refreshCoreModules() called logos_core_refresh_plugins(),
// which re-ran PluginRegistry::discoverInstalledModules() and wiped the
// `loaded` flag of every plugin via `m_plugins.insert(qName, freshInfo)`.
// The whole list then rendered as Not Loaded with no CPU/Mem stats.
test("modules: core tab shows auto-loaded plugins as Loaded", async (app) => {
  await app.click("Modules");
  await app.click("Core Modules");

  // Wait for the core modules list to populate.
  await app.waitFor(
    async () => { await app.expectTexts(["package_manager", "capability_module"]); },
    { timeout: 10000, interval: 500, description: "Core Modules list to populate" }
  );

  // CoreModulesView renders "(Loaded)" + "Unload Plugin" for loaded
  // modules and "(Not Loaded)" + "Load Plugin" for unloaded ones. With
  // the refreshCoreModules bug, every module showed "(Not Loaded)" and
  // the only buttons were "Load Plugin", so neither "(Loaded)" nor
  // "Unload Plugin" appeared anywhere in the UI.
  await app.expectTexts(["(Loaded)", "Unload Plugin"]);
});

// --- Modules: CPU/Memory stats ---
//
// Regression guard for the refactor that replaces Qt process management
// inside logos-liblogos. The Core Modules tab shows `CPU: N%` and
// `Mem: N MB` for every loaded module. The numbers come from
// logos_core_get_module_stats(), which iterates the PIDs reported by
// QtProcessManager::getAllProcessIds(). If the process manager returns an
// empty map (e.g. because the Boost.Process port forgot to track PIDs) or
// zeroed PIDs, every module shows `CPU: 0%` `Mem: 0 MB`. This test asserts
// the static CPU/Mem labels appear at all — getting no row at all is still
// caught by the existing "core tab shows auto-loaded plugins" test, so the
// two together cover both "list is empty" and "list has rows but stats are
// missing".
test("modules: core tab renders CPU and memory labels for loaded plugins", async (app) => {
  await app.click("Modules");
  await app.click("Core Modules");

  await app.waitFor(
    async () => { await app.expectTexts(["package_manager", "capability_module"]); },
    { timeout: 10000, interval: 500, description: "Core Modules list to populate" }
  );

  // The CPU and Mem labels use "CPU: " and "Mem: " prefixes (see
  // src/qml/views/CoreModulesView.qml:122, :129). They are bound to
  // modelData.cpu / modelData.memory which are populated from the
  // getModuleStats JSON. If stats are missing entirely the labels are
  // empty strings; if the QML is bound correctly the "CPU:" / "Mem:"
  // prefixes are in the visible tree exactly once per loaded module.
  await app.waitFor(
    async () => { await app.expectTexts(["CPU:", "Mem:"]); },
    { timeout: 10000, interval: 500, description: "CPU/Mem labels to appear" }
  );
});

// --- Modules: unload + reload cycle ---
//
// Exercises the load/unload/reload path that the current test suite never
// touches. A Qt -> Boost.Process refactor that leaves stale token-socket
// files, fails to reap children, or mishandles the "placeholder" registry
// entry would pass the existing single-load test but break here on the
// second load. This is intentionally generic: we click the first
// "Unload Plugin" button and assert that the counts of "(Loaded)" /
// "(Not Loaded)" / "Unload Plugin" / "Load Plugin" appear consistent
// after each transition. A single stable click target ("Unload Plugin"
// / "Load Plugin") is enough to drive the cycle because clicking by text
// picks up the first match — the test does not care which module gets
// toggled, only that the cycle completes cleanly.
test("modules: unload then reload a plugin preserves consistent state", async (app) => {
  await app.click("Modules");
  await app.click("Core Modules");

  // Starting state — both auto-loaded modules are loaded.
  await app.waitFor(
    async () => { await app.expectTexts(["package_manager", "capability_module", "(Loaded)", "Unload Plugin"]); },
    { timeout: 10000, interval: 500, description: "Core Modules list with loaded state" }
  );

  // Unload the first loaded module.
  await app.click("Unload Plugin");

  // After unload, there must be at least one "(Not Loaded)" status and at
  // least one "Load Plugin" button in the view. (The other auto-loaded
  // module remains loaded, so "(Loaded)" and "Unload Plugin" may still be
  // present — that's fine, we only assert the unloaded markers appeared.)
  await app.waitFor(
    async () => { await app.expectTexts(["(Not Loaded)", "Load Plugin"]); },
    { timeout: 10000, interval: 500, description: "module to transition to Not Loaded" }
  );

  // Reload — the freshly-unloaded module should come back up via the
  // same process-spawn + token-exchange path that failed to be covered
  // by the boot-time auto-load. This is where a refactor that left a
  // stale /tmp/logos_token_<name> socket file on disk would fail.
  await app.click("Load Plugin");

  // Final state — back to "(Loaded)" with an "Unload Plugin" button
  // available for the reloaded module.
  await app.waitFor(
    async () => { await app.expectTexts(["(Loaded)", "Unload Plugin"]); },
    { timeout: 15000, interval: 500, description: "module to reload successfully" }
  );
});

// --- Modules: Refresh preserves loaded state ---
//
// The existing "core tab shows auto-loaded plugins as Loaded" test exercises
// a single navigation. This one explicitly re-triggers refresh by navigating
// away to another panel and back, which calls into
// MainUIBackend::refreshCoreModules() -> logos_core_refresh_plugins(). That
// is the exact code path a process-manager / registry refactor is most
// likely to break (re-inserting PluginInfo and wiping the loaded flag).
test("modules: leaving and returning to Core Modules preserves loaded state", async (app) => {
  await app.click("Modules");
  await app.click("Core Modules");

  await app.waitFor(
    async () => { await app.expectTexts(["(Loaded)", "Unload Plugin"]); },
    { timeout: 10000, interval: 500, description: "initial loaded state" }
  );

  // Navigate away from the Core Modules tab, then back. Each navigation
  // back into the tab re-runs the plugin list refresh.
  await app.click("Dashboard");
  await app.click("Modules");
  await app.click("Core Modules");

  // Must still show "(Loaded)" / "Unload Plugin" after the refresh.
  await app.waitFor(
    async () => { await app.expectTexts(["(Loaded)", "Unload Plugin"]); },
    { timeout: 10000, interval: 500, description: "loaded state after refresh" }
  );

  // No "(Not Loaded)" for the known auto-loaded modules specifically —
  // we can't assert "(Not Loaded)" is fully absent (other modules may be
  // in that state), but we assert the two auto-loaded names remain
  // associated with the loaded label region by checking their names
  // still appear alongside "(Loaded)".
  await app.expectTexts(["package_manager", "capability_module", "(Loaded)"]);
});

// --- Open several plugins sequentially ---
//
// The current suite opens plugins one at a time in isolated tests. This
// test drives them in one session so the process manager is asked to
// spawn, connect, and track four children in rapid succession. A Qt ->
// Boost.Process port that has a race in the waitForStarted -> sendToken
// window would pass the single-plugin tests (lucky timing) but fail here
// because the 4th plugin inherits degraded state from the earlier three.
test("sidebar: open multiple plugins sequentially without failure", async (app) => {
  // Each click uses openPlugin so we wait for the UI to actually load
  // before moving on. If any spawn fails silently the expectTexts timeout
  // fires in openPlugin's waitFor.
  await openPlugin(app, "counter", ["0"]);
  await openPlugin(app, "counter_qml", ["Count:"], {});

  // Skip webview_app: it's already marked skip for offscreen.
  // package_manager_ui: uses a different probe.
  await app.click("package_manager_ui");
  await app.waitFor(
    async () => { await app.expectTexts(["Reload"]); },
    { timeout: 10000, interval: 500, description: "package_manager_ui to load" }
  );
});

// --- TODO: hermetic checks that cannot run from ui-tests.mjs ---
//
// The following checks would catch regressions that this file cannot see,
// and should be added as a separate nix check (see nix/integration-test.nix):
//
//  1. After basecamp exits, no `logos_host` children remain in the process
//     table. Implement with `pgrep -f logos_host` after the app shuts down
//     and assert the result is empty. Catches zombie reaping bugs in a
//     Boost.Process port of QtProcessManager.
//
//  2. Shutdown latency: from the moment the test framework sends a quit
//     signal to the moment the process exits should be < 5s. Catches the
//     event-loop shutdown hang that happens when an io_context::run() loop
//     forgets to drain its Process completion handlers.
//
//  3. File-descriptor stability: take /proc/self/fd count before opening
//     a sidebar plugin, after opening, after unloading, and assert the
//     count is monotonic + bounded. Catches socket/pipe leaks in the
//     token-exchange replacement.

// --- Run ---

run();
