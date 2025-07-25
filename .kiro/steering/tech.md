# Technology Stack

## Build System
- **Xcode Project**: Standard iOS/macOS Xcode project structure
- **Build Configuration**: Uses `.xcconfig` files for build settings
- **Target**: macOS application with minimum deployment target of macOS 14.4

## Frameworks & Technologies
- **SwiftUI**: Primary UI framework for all views
- **CoreAudio**: Core framework for audio processing and process tapping
- **AVFoundation**: Used for audio file writing (`AVAudioFile`, `AVAudioPCMBuffer`)
- **AudioToolbox**: Low-level audio APIs for device management
- **OSLog**: Structured logging throughout the application
- **TCC Framework**: Private API usage for permission checking (optional, can be disabled)

## Language & Version
- **Swift 5.0**: Primary programming language
- **@Observable**: Uses Swift's new observation framework for state management
- **@MainActor**: Proper concurrency handling with MainActor annotations

## Key Dependencies
- No external package dependencies
- Uses only system frameworks
- Optional private API usage (TCC) controlled by build flag

## Build Commands
```bash
# Build from command line
xcodebuild -project AudioCap.xcodeproj -scheme AudioCap -configuration Debug build

# Clean build
xcodebuild -project AudioCap.xcodeproj -scheme AudioCap clean

# Archive for distribution
xcodebuild -project AudioCap.xcodeproj -scheme AudioCap archive -archivePath AudioCap.xcarchive
```

## Configuration
- Build settings managed through `AudioCap/Config/Main.xcconfig`
- Bundle identifier and versioning configured in xcconfig
- Private API usage controlled by `ENABLE_TCC_SPI` build flag
- Manual code signing configuration

## Task Completion Requirements
- **CRITICAL**: At the end of EVERY task, you MUST verify that the build works with Xcode
- **CRITICAL**: At the end of EVERY task, you MUST ensure that all existing tests pass
- **CRITICAL**: NO warnings are allowed - treat ALL warnings as errors and failures
- Use `xcodebuild -project AudioCap.xcodeproj -scheme AudioCap -configuration Debug build` to verify build
- Use `xcodebuild -project AudioCap.xcodeproj -scheme AudioCap test` to run tests
- If build fails, has warnings, or tests fail, you MUST fix ALL issues before considering the task complete
- No task is complete until build is warning-free and all tests pass successfully
- Zero tolerance for warnings - they must be resolved just like errors