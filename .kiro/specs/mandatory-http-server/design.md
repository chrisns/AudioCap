# Design Document

## Overview

This design makes the embedded HTTP server a **first-class, mandatory runtime service** for the AudioCap application. The server will launch automatically during application startup and the application will **terminate immediately** on any server start-up failure (e.g., port already in use, insufficient permissions, bad configuration). All user-facing UI controls and configuration flags that disable the HTTP server are removed.

## Architecture

````mermaid
graph LR
    AppInit(AudioCapApp.init)
    RootView -->|presented| HTTPServerMgr(HTTPServerManager)
    AppInit --> Startup
    Startup((Server Startup))
    Startup -->|if success| Running[Server Running]
    Startup -->|if failure| FatalExit[Log & Terminate]

    style FatalExit fill:#ffdddd,stroke:#d33
````

Key flow changes:
1. `AudioCapApp` triggers `HTTPServerManager.start()` **during application initialisation** (not lazily in `RootView`).
2. If `start()` throws, the error is logged and the app calls `NSApplication.shared.terminate()` with a non-zero exit code via `exit(EXIT_FAILURE)` to ensure fail-fast shutdown.
3. UI elements (`APISettingsView`, `RootView`) no longer gate server start on `configuration.enabled` and no longer expose a switch to toggle it.

## Components and Interfaces

| Component | Change | Details |
|-----------|--------|---------|
| `ServerConfiguration` | Remove `enabled` flag | Always assume server is enabled. The struct stays Codable for persistence. Migration path: ignore persisted `enabled` on load. |
| `HTTPServerManager` | • Update `init()` or new `startIfNeeded()` to attempt start unconditionally<br>• Provide fatal-exit wrapper | The manager continues to expose `start()` / `stop()`. New helper `startOrTerminate()` will wrap `start()` and call fatal exit on error. |
| `AudioCapApp` | Invoke server startup | In `init()`, call `httpServerManager.startOrTerminate()` on a background Task (since `start()` is `async`). |
| `RootView` | Remove enable checks | Delete code paths that toggle server; remove config.enabled dependencies. |
| `APISettingsView` | Remove “Enable HTTP Server” toggle | UI now only shows status information and configuration for port, CORS, etc. |

## Data Models

`ServerConfiguration`
- Delete `enabled: Bool` property.
- While decoding persisted configs, ignore unknown `enabled` key via `JSONDecoder.keyDecodingStrategy`. Provide migration by extending `load()` to discard `enabled` silently.

## Error Handling Strategy

1. **Start-up Failure**  
   *Flow*: `HTTPServerManager.start()` throws → `AudioCapApp` catches → logs critical message via `OSLog` → calls `fatalError()` or `exit(EXIT_FAILURE)`.
2. **Runtime Listener Failure**  
   `listener.stateUpdateHandler` already delivers `.failed` state. Extend handler to log & terminate the app immediately if state becomes `.failed` **after** successfully starting.

## Testing Strategy

1. **Unit Tests**  
   - Modify existing tests that rely on `configuration.enabled` to assume always enabled.  
   - Add `HTTPServerStartupFailureTests` that inject a mock configuration with an occupied port to assert that `start()` throws the correct error.
2. **Integration Tests**  
   - Add `AppFailFastTests` that launch the app in a headless test harness with an occupied port and assert non-zero exit status.
3. **UI Tests**  
   - Update settings view snapshot tests to remove the “Enable HTTP Server” toggle.

## Open Questions / Considerations

- _Graceful user messaging_: For CLI-based launches, terminating with a descriptive log is acceptable. For GUI, do we show an alert before quitting? Current scope chooses immediate exit; can be enhanced later.
- _Backward compatibility_: Existing user defaults that still contain `enabled` will be ignored. No migration is required since the key will be silently dropped.

---

_This design satisfies the following requirements:_
- **R1**: Server is always enabled ‑ it starts during app initialisation with no opt-out.
- **R2**: Any start-up error triggers immediate termination with non-zero exit code. 