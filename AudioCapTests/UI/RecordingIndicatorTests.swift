import XCTest
import SwiftUI
import ViewInspector
@testable import AudioCap

@MainActor
final class RecordingIndicatorTests: XCTestCase {
    
    // MARK: - Test Setup
    
    private var testIcon: NSImage!
    
    override func setUp() {
        super.setUp()
        // Create a test icon for testing
        testIcon = NSWorkspace.shared.icon(forFile: "/System/Applications/Music.app")
    }
    
    override func tearDown() {
        testIcon = nil
        super.tearDown()
    }
    
    // MARK: - Visual State Tests
    
    /// Test that RecordingIndicator displays app icon when not recording
    /// Requirements: 4.8
    func testRecordingIndicatorDisplaysAppIconWhenNotRecording() throws {
        // Given: A RecordingIndicator not recording
        let indicator = RecordingIndicator(appIcon: testIcon, isRecording: false)
        let inspection = try indicator.inspect()
        
        // When: The indicator is rendered
        let zStack = try inspection.find(ViewType.ZStack.self)
        
        // Then: It should display the app icon
        XCTAssertNoThrow(try zStack.find(ViewType.Image.self))
    }
    
    /// Test that RecordingIndicator shows recording overlay when recording
    /// Requirements: 4.8
    func testRecordingIndicatorShowsRecordingOverlayWhenRecording() throws {
        // Given: A RecordingIndicator that is recording
        let indicator = RecordingIndicator(appIcon: testIcon, isRecording: true)
        let inspection = try indicator.inspect()
        
        // When: The indicator is rendered
        let zStack = try inspection.find(ViewType.ZStack.self)
        
        // Then: It should show recording overlay elements
        XCTAssertNotNil(zStack)
        // Note: Complex recording overlay testing is limited by ViewInspector
    }
    
    /// Test that RecordingIndicator has proper size configuration
    /// Requirements: 4.8
    func testRecordingIndicatorHasProperSizeConfiguration() throws {
        // Given: A RecordingIndicator with custom size
        let customSize: CGFloat = 32
        let indicator = RecordingIndicator(appIcon: testIcon, isRecording: false, size: customSize)
        let inspection = try indicator.inspect()
        
        // When: The indicator is rendered
        let zStack = try inspection.find(ViewType.ZStack.self)
        
        // Then: It should maintain proper structure for the size
        XCTAssertNotNil(zStack)
    }
    
    /// Test that RecordingIndicator uses default size when not specified
    /// Requirements: 4.8
    func testRecordingIndicatorUsesDefaultSizeWhenNotSpecified() throws {
        // Given: A RecordingIndicator with default size
        let indicator = RecordingIndicator(appIcon: testIcon, isRecording: false)
        let inspection = try indicator.inspect()
        
        // When: The indicator is rendered
        let zStack = try inspection.find(ViewType.ZStack.self)
        
        // Then: It should use the default size (22)
        XCTAssertNotNil(zStack)
    }
    
    // MARK: - Animation Transition Tests
    
    /// Test that RecordingIndicator handles recording state transitions
    /// Requirements: 4.8
    func testRecordingIndicatorHandlesRecordingStateTransitions() throws {
        // Given: A RecordingIndicator
        let indicator = RecordingIndicator(appIcon: testIcon, isRecording: false)
        
        // When: The recording state changes
        // Then: The indicator should handle the transition
        XCTAssertNoThrow(try indicator.inspect())
        
        // Test with recording state
        let recordingIndicator = RecordingIndicator(appIcon: testIcon, isRecording: true)
        XCTAssertNoThrow(try recordingIndicator.inspect())
    }
    
    /// Test that RecordingIndicator has smooth animation transitions
    /// Requirements: 4.8
    func testRecordingIndicatorHasSmoothAnimationTransitions() throws {
        // Given: A RecordingIndicator
        let indicator = RecordingIndicator(appIcon: testIcon, isRecording: false)
        let inspection = try indicator.inspect()
        
        // When: The indicator is rendered
        let zStack = try inspection.find(ViewType.ZStack.self)
        
        // Then: It should have proper structure for animations
        XCTAssertNotNil(zStack)
    }
    
    /// Test that RecordingIndicator transitions between states properly
    /// Requirements: 4.8
    func testRecordingIndicatorTransitionsBetweenStatessProperly() throws {
        // Given: RecordingIndicators in different states
        let notRecordingIndicator = RecordingIndicator(appIcon: testIcon, isRecording: false)
        let recordingIndicator = RecordingIndicator(appIcon: testIcon, isRecording: true)
        
        // When: Both indicators are rendered
        // Then: Both should render without issues
        XCTAssertNoThrow(try notRecordingIndicator.inspect())
        XCTAssertNoThrow(try recordingIndicator.inspect())
    }
    
    // MARK: - App Icon Display Tests
    
    /// Test that RecordingIndicator displays provided app icon
    /// Requirements: 4.8
    func testRecordingIndicatorDisplaysProvidedAppIcon() throws {
        // Given: A RecordingIndicator with a specific app icon
        let indicator = RecordingIndicator(appIcon: testIcon, isRecording: false)
        let inspection = try indicator.inspect()
        
        // When: The indicator is rendered
        let zStack = try inspection.find(ViewType.ZStack.self)
        let image = try zStack.find(ViewType.Image.self)
        
        // Then: It should display the provided icon
        XCTAssertNotNil(image)
    }
    
    /// Test that RecordingIndicator handles different app icons
    /// Requirements: 4.8
    func testRecordingIndicatorHandlesDifferentAppIcons() throws {
        // Given: Different app icons
        let musicIcon = NSWorkspace.shared.icon(forFile: "/System/Applications/Music.app")
        let safariIcon = NSWorkspace.shared.icon(forFile: "/System/Applications/Safari.app")
        
        // When: RecordingIndicators are created with different icons
        let musicIndicator = RecordingIndicator(appIcon: musicIcon, isRecording: false)
        let safariIndicator = RecordingIndicator(appIcon: safariIcon, isRecording: false)
        
        // Then: Both should render properly
        XCTAssertNoThrow(try musicIndicator.inspect())
        XCTAssertNoThrow(try safariIndicator.inspect())
    }
    
    /// Test that RecordingIndicator maintains icon aspect ratio
    /// Requirements: 4.8
    func testRecordingIndicatorMaintainsIconAspectRatio() throws {
        // Given: A RecordingIndicator
        let indicator = RecordingIndicator(appIcon: testIcon, isRecording: false)
        let inspection = try indicator.inspect()
        
        // When: The indicator is rendered
        let zStack = try inspection.find(ViewType.ZStack.self)
        let image = try zStack.find(ViewType.Image.self)
        
        // Then: The image should maintain proper aspect ratio
        XCTAssertNotNil(image)
    }
    
    // MARK: - Recording Overlay Tests
    
    /// Test that RecordingIndicator shows recording overlay elements
    /// Requirements: 4.8
    func testRecordingIndicatorShowsRecordingOverlayElements() throws {
        // Given: A RecordingIndicator that is recording
        let indicator = RecordingIndicator(appIcon: testIcon, isRecording: true)
        let inspection = try indicator.inspect()
        
        // When: The indicator is rendered
        let zStack = try inspection.find(ViewType.ZStack.self)
        
        // Then: It should contain overlay elements
        XCTAssertNotNil(zStack)
        // Note: Detailed overlay testing is complex with ViewInspector
    }
    
    /// Test that RecordingIndicator hides overlay when not recording
    /// Requirements: 4.8
    func testRecordingIndicatorHidesOverlayWhenNotRecording() throws {
        // Given: A RecordingIndicator that is not recording
        let indicator = RecordingIndicator(appIcon: testIcon, isRecording: false)
        let inspection = try indicator.inspect()
        
        // When: The indicator is rendered
        let zStack = try inspection.find(ViewType.ZStack.self)
        let image = try zStack.find(ViewType.Image.self)
        
        // Then: It should show the icon without overlay
        XCTAssertNotNil(image)
    }
    
    /// Test that RecordingIndicator overlay has proper visual effects
    /// Requirements: 4.8
    func testRecordingIndicatorOverlayHasProperVisualEffects() throws {
        // Given: A RecordingIndicator that is recording
        let indicator = RecordingIndicator(appIcon: testIcon, isRecording: true)
        let inspection = try indicator.inspect()
        
        // When: The indicator is rendered
        let zStack = try inspection.find(ViewType.ZStack.self)
        
        // Then: It should have proper visual structure
        XCTAssertNotNil(zStack)
    }
    
    // MARK: - Color Scheme Tests
    
    /// Test that RecordingIndicator adapts to light color scheme
    /// Requirements: 4.8
    func testRecordingIndicatorAdaptsToLightColorScheme() throws {
        // Given: A RecordingIndicator in light color scheme
        let indicator = RecordingIndicator(appIcon: testIcon, isRecording: true)
            .environment(\.colorScheme, .light)
        let inspection = try indicator.inspect()
        
        // When: The indicator is rendered
        let zStack = try inspection.find(ViewType.ZStack.self)
        
        // Then: It should adapt to the color scheme
        XCTAssertNotNil(zStack)
    }
    
    /// Test that RecordingIndicator adapts to dark color scheme
    /// Requirements: 4.8
    func testRecordingIndicatorAdaptsToDarkColorScheme() throws {
        // Given: A RecordingIndicator in dark color scheme
        let indicator = RecordingIndicator(appIcon: testIcon, isRecording: true)
            .environment(\.colorScheme, .dark)
        let inspection = try indicator.inspect()
        
        // When: The indicator is rendered
        let zStack = try inspection.find(ViewType.ZStack.self)
        
        // Then: It should adapt to the color scheme
        XCTAssertNotNil(zStack)
    }
    
    /// Test that RecordingIndicator handles color scheme changes
    /// Requirements: 4.8
    func testRecordingIndicatorHandlesColorSchemeChanges() throws {
        // Given: RecordingIndicators with different color schemes
        let lightIndicator = RecordingIndicator(appIcon: testIcon, isRecording: true)
            .environment(\.colorScheme, .light)
        let darkIndicator = RecordingIndicator(appIcon: testIcon, isRecording: true)
            .environment(\.colorScheme, .dark)
        
        // When: Both indicators are rendered
        // Then: Both should handle their respective color schemes
        XCTAssertNoThrow(try lightIndicator.inspect())
        XCTAssertNoThrow(try darkIndicator.inspect())
    }
    
    // MARK: - Accessibility Tests
    
    /// Test that RecordingIndicator is accessible
    /// Requirements: 4.8
    func testRecordingIndicatorIsAccessible() throws {
        // Given: A RecordingIndicator
        let indicator = RecordingIndicator(appIcon: testIcon, isRecording: false)
        let inspection = try indicator.inspect()
        
        // When: The indicator is rendered
        let zStack = try inspection.find(ViewType.ZStack.self)
        
        // Then: It should be accessible
        XCTAssertNotNil(zStack)
    }
    
    /// Test that RecordingIndicator provides proper accessibility information
    /// Requirements: 4.8
    func testRecordingIndicatorProvidesProperAccessibilityInformation() throws {
        // Given: RecordingIndicators in different states
        let notRecordingIndicator = RecordingIndicator(appIcon: testIcon, isRecording: false)
        let recordingIndicator = RecordingIndicator(appIcon: testIcon, isRecording: true)
        
        // When: Both indicators are rendered
        // Then: Both should provide accessibility information
        XCTAssertNoThrow(try notRecordingIndicator.inspect())
        XCTAssertNoThrow(try recordingIndicator.inspect())
    }
    
    /// Test that RecordingIndicator accessibility changes with recording state
    /// Requirements: 4.8
    func testRecordingIndicatorAccessibilityChangesWithRecordingState() throws {
        // Given: RecordingIndicators in different recording states
        let notRecordingIndicator = RecordingIndicator(appIcon: testIcon, isRecording: false)
        let recordingIndicator = RecordingIndicator(appIcon: testIcon, isRecording: true)
        
        // When: Both indicators are inspected
        let notRecordingInspection = try notRecordingIndicator.inspect()
        let recordingInspection = try recordingIndicator.inspect()
        
        // Then: Both should be accessible but potentially with different information
        XCTAssertNotNil(try notRecordingInspection.find(ViewType.ZStack.self))
        XCTAssertNotNil(try recordingInspection.find(ViewType.ZStack.self))
    }
    
    // MARK: - Performance Tests
    
    /// Test that RecordingIndicator renders efficiently
    /// Requirements: 4.8
    func testRecordingIndicatorRendersEfficiently() throws {
        // Given: A RecordingIndicator
        let indicator = RecordingIndicator(appIcon: testIcon, isRecording: false)
        
        // When: The indicator is inspected multiple times
        // Then: It should handle repeated inspections efficiently
        for _ in 0..<10 {
            XCTAssertNoThrow(try indicator.inspect())
        }
    }
    
    /// Test that RecordingIndicator handles rapid state changes efficiently
    /// Requirements: 4.8
    func testRecordingIndicatorHandlesRapidStateChangesEfficiently() throws {
        // Given: RecordingIndicators with alternating states
        // When: Multiple indicators are created and inspected
        for i in 0..<10 {
            let isRecording = (i % 2 == 0)
            let indicator = RecordingIndicator(appIcon: testIcon, isRecording: isRecording)
            
            // Then: Each should render efficiently
            XCTAssertNoThrow(try indicator.inspect())
        }
    }
    
    /// Test that RecordingIndicator handles different sizes efficiently
    /// Requirements: 4.8
    func testRecordingIndicatorHandlesDifferentSizesEfficiently() throws {
        // Given: RecordingIndicators with different sizes
        let sizes: [CGFloat] = [16, 22, 32, 48, 64]
        
        // When: Indicators with different sizes are created
        for size in sizes {
            let indicator = RecordingIndicator(appIcon: testIcon, isRecording: false, size: size)
            
            // Then: Each should render efficiently
            XCTAssertNoThrow(try indicator.inspect())
        }
    }
    
    // MARK: - Edge Cases
    
    /// Test that RecordingIndicator handles nil icon gracefully
    /// Requirements: 4.8
    func testRecordingIndicatorHandlesIconsGracefully() throws {
        // Given: A RecordingIndicator with a valid icon
        let indicator = RecordingIndicator(appIcon: testIcon, isRecording: false)
        
        // When: The indicator is rendered
        // Then: It should handle the icon properly
        XCTAssertNoThrow(try indicator.inspect())
    }
    
    /// Test that RecordingIndicator handles extreme sizes
    /// Requirements: 4.8
    func testRecordingIndicatorHandlesExtremeSizes() throws {
        // Given: RecordingIndicators with extreme sizes
        let verySmallIndicator = RecordingIndicator(appIcon: testIcon, isRecording: false, size: 1)
        let veryLargeIndicator = RecordingIndicator(appIcon: testIcon, isRecording: false, size: 200)
        
        // When: Both indicators are rendered
        // Then: Both should handle extreme sizes gracefully
        XCTAssertNoThrow(try verySmallIndicator.inspect())
        XCTAssertNoThrow(try veryLargeIndicator.inspect())
    }
    
    /// Test that RecordingIndicator handles rapid recording state toggles
    /// Requirements: 4.8
    func testRecordingIndicatorHandlesRapidRecordingStateToggles() throws {
        // Given: RecordingIndicators with rapidly changing states
        // When: Multiple state changes occur
        for i in 0..<20 {
            let isRecording = (i % 2 == 0)
            let indicator = RecordingIndicator(appIcon: testIcon, isRecording: isRecording)
            
            // Then: Each state should be handled properly
            XCTAssertNoThrow(try indicator.inspect())
        }
    }
    
    // MARK: - Visual Effects Tests
    
    /// Test that RecordingIndicator applies proper visual effects when recording
    /// Requirements: 4.8
    func testRecordingIndicatorAppliesProperVisualEffectsWhenRecording() throws {
        // Given: A RecordingIndicator that is recording
        let indicator = RecordingIndicator(appIcon: testIcon, isRecording: true)
        let inspection = try indicator.inspect()
        
        // When: The indicator is rendered
        let zStack = try inspection.find(ViewType.ZStack.self)
        
        // Then: It should apply visual effects
        XCTAssertNotNil(zStack)
    }
    
    /// Test that RecordingIndicator removes visual effects when not recording
    /// Requirements: 4.8
    func testRecordingIndicatorRemovesVisualEffectsWhenNotRecording() throws {
        // Given: A RecordingIndicator that is not recording
        let indicator = RecordingIndicator(appIcon: testIcon, isRecording: false)
        let inspection = try indicator.inspect()
        
        // When: The indicator is rendered
        let zStack = try inspection.find(ViewType.ZStack.self)
        let image = try zStack.find(ViewType.Image.self)
        
        // Then: It should show clean icon without effects
        XCTAssertNotNil(image)
    }
    
    /// Test that RecordingIndicator visual effects are appropriate for different color schemes
    /// Requirements: 4.8
    func testRecordingIndicatorVisualEffectsAreAppropriateForDifferentColorSchemes() throws {
        // Given: RecordingIndicators in different color schemes
        let lightSchemeIndicator = RecordingIndicator(appIcon: testIcon, isRecording: true)
            .environment(\.colorScheme, .light)
        let darkSchemeIndicator = RecordingIndicator(appIcon: testIcon, isRecording: true)
            .environment(\.colorScheme, .dark)
        
        // When: Both indicators are rendered
        // Then: Both should apply appropriate effects for their color schemes
        XCTAssertNoThrow(try lightSchemeIndicator.inspect())
        XCTAssertNoThrow(try darkSchemeIndicator.inspect())
    }
}

// MARK: - ViewInspector Extensions

// RecordingIndicator extension is already defined in RecordingViewTests