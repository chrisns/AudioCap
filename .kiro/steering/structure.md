# Project Structure

## Root Level
- `AudioCap.xcodeproj/` - Xcode project files and configuration
- `AudioCap/` - Main application source code
- `README.md` - Project documentation and API usage guide
- `LICENSE` - Project license file

## Application Structure (`AudioCap/`)

### Core Application Files
- `AudioCapApp.swift` - Main app entry point with `@main` attribute
- `RootView.swift` - Root SwiftUI view handling permission states
- `Info.plist` - App configuration including `NSAudioCaptureUsageDescription`
- `AudioCap.entitlements` - App entitlements for system access

### UI Components
- `ProcessSelectionView.swift` - Interface for selecting which process to record
- `RecordingView.swift` - Main recording interface and controls
- `RecordingIndicator.swift` - Visual indicator for recording state
- `FileProxyView.swift` - File handling and export functionality

### Core Audio Implementation (`ProcessTap/`)
- `ProcessTap.swift` - Main process tap implementation and recorder
- `AudioProcessController.swift` - Process management and enumeration
- `AudioRecordingPermission.swift` - Permission handling (with optional TCC usage)
- `CoreAudioUtils.swift` - Utility functions for CoreAudio operations

### Configuration (`Config/`)
- `Main.xcconfig` - Build configuration settings and flags

### Resources
- `Assets.xcassets/` - App icons and visual assets
- `Preview Content/` - SwiftUI preview assets

## Code Organization Patterns

### Naming Conventions
- Swift files use PascalCase
- Views end with "View" suffix
- Controllers end with "Controller" suffix
- Use descriptive, self-documenting names

### Architecture
- SwiftUI-based MVVM pattern
- `@Observable` classes for state management
- `@MainActor` annotations for UI-related code
- Separation of concerns: UI, business logic, and CoreAudio operations

### Logging
- Consistent use of `OSLog` with subsystem `kAppSubsystem`
- Category-based logging per component
- Privacy-aware logging with `.public` annotations where appropriate

### Error Handling
- String-based error throwing for simplicity
- Graceful error handling with user-facing messages
- Proper cleanup in deinit and error paths