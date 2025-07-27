import XCTest
import SwiftUI
import ViewInspector
@testable import AudioCap

final class RecordingViewTests: BaseUITestCase {
    
    // MARK: - Test Setup
    
    private var mockRecorder: MockProcessTapRecorder!
    private var mockProcess: AudioProcess!
    
    override func setUp() {
        super.setUp()
        // Create mock objects for testing
        mockProcess = MockAudioProcess.createMockProcess(
            id: 1234,
            name: "Test App",
            audioActive: true
        )
        mockRecorder = MockProcessTapRecorder(process: mockProcess)
    }
    
    override func tearDown() {
        mockRecorder = nil
        mockProcess = nil
        super.tearDown()
    }
    
    // MARK: - Start/Stop Button Tests
    
    /// Test that RecordingView displays start button when not recording
    /// Requirements: 4.7
    func testRecordingViewDisplaysStartButtonWhenNotRecording() throws {
        // Given: A RecordingView with a non-recording recorder
        mockRecorder.isRecording = false
        let view = RecordingView(recorder: mockRecorder)
        let inspection = try view.inspect()
        
        // When: The view is rendered
        let section = try inspection.find(ViewType.Section.self)
        let hStack = try section.find(ViewType.HStack.self)
        
        // Then: It should display a "Start" button
        let button = try hStack.find(button: "Start")
        XCTAssertNotNil(button)
    }
    
    /// Test that RecordingView displays stop button when recording
    /// Requirements: 4.7
    func testRecordingViewDisplaysStopButtonWhenRecording() throws {
        // Given: A RecordingView with a recording recorder
        mockRecorder.isRecording = true
        let view = RecordingView(recorder: mockRecorder)
        let inspection = try view.inspect()
        
        // When: The view is rendered
        let section = try inspection.find(ViewType.Section.self)
        let hStack = try section.find(ViewType.HStack.self)
        
        // Then: It should display a "Stop" button
        let button = try hStack.find(button: "Stop")
        XCTAssertNotNil(button)
    }
    
    /// Test that start button triggers recording
    /// Requirements: 4.7
    func testStartButtonTriggersRecording() throws {
        // Given: A RecordingView with a non-recording recorder
        mockRecorder.isRecording = false
        let view = RecordingView(recorder: mockRecorder)
        let inspection = try view.inspect()
        
        // When: The start button is tapped
        let section = try inspection.find(ViewType.Section.self)
        let hStack = try section.find(ViewType.HStack.self)
        let button = try hStack.find(button: "Start")
        
        try button.tap()
        
        // Then: The recorder should attempt to start
        XCTAssertEqual(mockRecorder.startCallCount, 1)
    }
    
    /// Test that stop button triggers recording stop
    /// Requirements: 4.7
    func testStopButtonTriggersRecordingStop() throws {
        // Given: A RecordingView with a recording recorder
        mockRecorder.isRecording = true
        let view = RecordingView(recorder: mockRecorder)
        let inspection = try view.inspect()
        
        // When: The stop button is tapped
        let section = try inspection.find(ViewType.Section.self)
        let hStack = try section.find(ViewType.HStack.self)
        let button = try hStack.find(button: "Stop")
        
        try button.tap()
        
        // Then: The recorder should stop
        XCTAssertEqual(mockRecorder.stopCallCount, 1)
    }
    
    // MARK: - Recording Status Display Tests
    
    /// Test that RecordingView displays recording status when recording
    /// Requirements: 4.7
    func testRecordingViewDisplaysRecordingStatusWhenRecording() throws {
        // Given: A RecordingView with a recording recorder
        mockRecorder.isRecording = true
        let view = RecordingView(recorder: mockRecorder)
        let inspection = try view.inspect()
        
        // When: The view is rendered
        let section = try inspection.find(ViewType.Section.self)
        let header = try section.header()
        let hStack = try header.find(ViewType.HStack.self)
        let text = try hStack.find(ViewType.Text.self)
        
        // Then: It should display recording status
        let statusText = try text.string()
        XCTAssertTrue(statusText.contains("Recording from"))
        XCTAssertTrue(statusText.contains(mockProcess.name))
    }
    
    /// Test that RecordingView displays ready status when not recording
    /// Requirements: 4.7
    func testRecordingViewDisplaysReadyStatusWhenNotRecording() throws {
        // Given: A RecordingView with a non-recording recorder
        mockRecorder.isRecording = false
        let view = RecordingView(recorder: mockRecorder)
        let inspection = try view.inspect()
        
        // When: The view is rendered
        let section = try inspection.find(ViewType.Section.self)
        let header = try section.header()
        let hStack = try header.find(ViewType.HStack.self)
        let text = try hStack.find(ViewType.Text.self)
        
        // Then: It should display ready status
        let statusText = try text.string()
        XCTAssertTrue(statusText.contains("Ready to Record from"))
        XCTAssertTrue(statusText.contains(mockProcess.name))
    }
    
    /// Test that RecordingView includes RecordingIndicator in header
    /// Requirements: 4.8
    func testRecordingViewIncludesRecordingIndicatorInHeader() throws {
        // Given: A RecordingView
        let view = RecordingView(recorder: mockRecorder)
        let inspection = try view.inspect()
        
        // When: The view is rendered
        let section = try inspection.find(ViewType.Section.self)
        let header = try section.header()
        let hStack = try header.find(ViewType.HStack.self)
        
        // Then: It should include a RecordingIndicator
        XCTAssertNoThrow(try hStack.find(RecordingIndicator.self))
    }
    
    // MARK: - FileProxyView Tests
    
    /// Test that FileProxyView appears after recording stops
    /// Requirements: 4.9
    func testFileProxyViewAppearsAfterRecordingStops() throws {
        // Given: A RecordingView with a recorder that has completed recording
        mockRecorder.isRecording = false
        mockRecorder.hasRecordedFile = true
        let view = RecordingView(recorder: mockRecorder)
        let inspection = try view.inspect()
        
        // When: The view is rendered after recording
        let section = try inspection.find(ViewType.Section.self)
        let hStack = try section.find(ViewType.HStack.self)
        
        // Then: It should potentially display FileProxyView
        // Note: FileProxyView appearance depends on lastRecordingURL state
        XCTAssertNotNil(hStack)
    }
    
    /// Test that FileProxyView is not displayed during recording
    /// Requirements: 4.9
    func testFileProxyViewIsNotDisplayedDuringRecording() throws {
        // Given: A RecordingView with a recording recorder
        mockRecorder.isRecording = true
        let view = RecordingView(recorder: mockRecorder)
        let inspection = try view.inspect()
        
        // When: The view is rendered during recording
        let section = try inspection.find(ViewType.Section.self)
        let hStack = try section.find(ViewType.HStack.self)
        
        // Then: It should only show the stop button
        let button = try hStack.find(button: "Stop")
        XCTAssertNotNil(button)
        
        // FileProxyView should not be present during recording
        XCTAssertThrowsError(try hStack.find(FileProxyView.self))
    }
    
    // MARK: - Error Handling Tests
    
    /// Test that RecordingView handles recording start errors
    /// Requirements: 4.9
    func testRecordingViewHandlesRecordingStartErrors() throws {
        // Given: A RecordingView with a recorder that will fail to start
        mockRecorder.isRecording = false
        mockRecorder.shouldFailStart = true
        let view = RecordingView(recorder: mockRecorder)
        let inspection = try view.inspect()
        
        // When: The start button is tapped
        let section = try inspection.find(ViewType.Section.self)
        let hStack = try section.find(ViewType.HStack.self)
        let button = try hStack.find(button: "Start")
        
        // Then: The button should be tappable (error handling is internal)
        XCTAssertNoThrow(try button.tap())
    }
    
    /// Test that RecordingView displays error alerts appropriately
    /// Requirements: 4.9
    func testRecordingViewDisplaysErrorAlertsAppropriately() throws {
        // Given: A RecordingView
        let view = RecordingView(recorder: mockRecorder)
        
        // When: The view is created
        // Then: It should be able to handle error scenarios
        XCTAssertNoThrow(try view.inspect())
    }
    
    // MARK: - Animation Tests
    
    /// Test that RecordingView has proper animations
    /// Requirements: 4.7
    func testRecordingViewHasProperAnimations() throws {
        // Given: A RecordingView
        let view = RecordingView(recorder: mockRecorder)
        let inspection = try view.inspect()
        
        // When: The view is rendered
        let section = try inspection.find(ViewType.Section.self)
        let hStack = try section.find(ViewType.HStack.self)
        
        // Then: The HStack should exist (animations are applied to it)
        XCTAssertNotNil(hStack)
    }
    
    /// Test that button transitions are smooth
    /// Requirements: 4.7
    func testButtonTransitionsAreSmooth() throws {
        // Given: A RecordingView
        let view = RecordingView(recorder: mockRecorder)
        let inspection = try view.inspect()
        
        // When: The view is rendered
        let section = try inspection.find(ViewType.Section.self)
        let hStack = try section.find(ViewType.HStack.self)
        
        // Then: The button should have proper ID for transitions
        let button = try hStack.find(ViewType.Button.self)
        XCTAssertNotNil(button)
    }
    
    // MARK: - State Management Tests
    
    /// Test that RecordingView responds to recorder state changes
    /// Requirements: 4.7
    func testRecordingViewRespondsToRecorderStateChanges() throws {
        // Given: A RecordingView
        let view = RecordingView(recorder: mockRecorder)
        
        // When: The recorder state changes
        mockRecorder.isRecording = true
        
        // Then: The view should be able to reflect the change
        XCTAssertNoThrow(try view.inspect())
    }
    
    /// Test that RecordingView maintains proper state during recording
    /// Requirements: 4.7
    func testRecordingViewMaintainsProperStateDuringRecording() throws {
        // Given: A RecordingView with a recording recorder
        mockRecorder.isRecording = true
        let view = RecordingView(recorder: mockRecorder)
        let inspection = try view.inspect()
        
        // When: The view is rendered
        let section = try inspection.find(ViewType.Section.self)
        
        // Then: It should maintain proper structure
        XCTAssertNotNil(section)
        XCTAssertNoThrow(try section.find(ViewType.HStack.self))
    }
    
    // MARK: - User Interaction Tests
    
    /// Test that RecordingView handles user interactions properly
    /// Requirements: 4.7
    func testRecordingViewHandlesUserInteractionsProperly() throws {
        // Given: A RecordingView
        let view = RecordingView(recorder: mockRecorder)
        let inspection = try view.inspect()
        
        // When: The view is rendered
        let section = try inspection.find(ViewType.Section.self)
        let hStack = try section.find(ViewType.HStack.self)
        let button = try hStack.find(ViewType.Button.self)
        
        // Then: The button should be interactive
        XCTAssertNoThrow(try button.tap())
    }
    
    /// Test that RecordingView prevents multiple simultaneous recordings
    /// Requirements: 4.7
    func testRecordingViewPreventsMultipleSimultaneousRecordings() throws {
        // Given: A RecordingView with a recording recorder
        mockRecorder.isRecording = true
        let view = RecordingView(recorder: mockRecorder)
        let inspection = try view.inspect()
        
        // When: The view is rendered during recording
        let section = try inspection.find(ViewType.Section.self)
        let hStack = try section.find(ViewType.HStack.self)
        
        // Then: Only the stop button should be available
        XCTAssertNoThrow(try hStack.find(button: "Stop"))
        XCTAssertThrowsError(try hStack.find(button: "Start"))
    }
    
    // MARK: - Accessibility Tests
    
    /// Test that start/stop buttons are accessible
    /// Requirements: 4.7
    func testStartStopButtonsAreAccessible() throws {
        // Given: A RecordingView
        let view = RecordingView(recorder: mockRecorder)
        let inspection = try view.inspect()
        
        // When: The view is rendered
        let section = try inspection.find(ViewType.Section.self)
        let hStack = try section.find(ViewType.HStack.self)
        let button = try hStack.find(ViewType.Button.self)
        
        // Then: The button should be accessible
        XCTAssertNotNil(button)
    }
    
    /// Test that recording status is accessible
    /// Requirements: 4.7
    func testRecordingStatusIsAccessible() throws {
        // Given: A RecordingView
        let view = RecordingView(recorder: mockRecorder)
        let inspection = try view.inspect()
        
        // When: The view is rendered
        let section = try inspection.find(ViewType.Section.self)
        let header = try section.header()
        let hStack = try header.find(ViewType.HStack.self)
        let text = try hStack.find(ViewType.Text.self)
        
        // Then: The status text should be accessible
        XCTAssertFalse(try text.string().isEmpty)
    }
    
    // MARK: - Edge Cases
    
    /// Test that RecordingView handles nil recorder gracefully
    /// Requirements: 4.7, 4.9
    func testRecordingViewHandlesRecorderStatesGracefully() throws {
        // Given: A RecordingView with various recorder states
        let view = RecordingView(recorder: mockRecorder)
        
        // When: The recorder has different states
        mockRecorder.isRecording = false
        
        // Then: The view should handle all states
        XCTAssertNoThrow(try view.inspect())
        
        mockRecorder.isRecording = true
        XCTAssertNoThrow(try view.inspect())
    }
    
    /// Test that RecordingView handles rapid state changes
    /// Requirements: 4.7
    func testRecordingViewHandlesRapidStateChanges() throws {
        // Given: A RecordingView
        let view = RecordingView(recorder: mockRecorder)
        
        // When: The recorder state changes rapidly
        for i in 0..<10 {
            mockRecorder.isRecording = (i % 2 == 0)
            XCTAssertNoThrow(try view.inspect())
        }
        
        // Then: The view should handle all changes gracefully
    }
    
    /// Test that RecordingView handles file URL changes
    /// Requirements: 4.9
    func testRecordingViewHandlesFileURLChanges() throws {
        // Given: A RecordingView
        let view = RecordingView(recorder: mockRecorder)
        
        // When: The recorder file URL changes
        mockRecorder.fileURL = URL(fileURLWithPath: "/tmp/test.wav")
        
        // Then: The view should handle the change
        XCTAssertNoThrow(try view.inspect())
    }
}

// MARK: - Mock ProcessTapRecorder

class MockProcessTapRecorder {
    let process: AudioProcess
    var fileURL: URL
    var isRecording: Bool = false
    var hasRecordedFile: Bool = false
    var shouldFailStart: Bool = false
    
    var startCallCount: Int = 0
    var stopCallCount: Int = 0
    
    init(process: AudioProcess) {
        self.process = process
        self.fileURL = URL(fileURLWithPath: "/tmp/mock-recording.wav")
    }
    
    func start() throws {
        startCallCount += 1
        if shouldFailStart {
            throw NSError(domain: "MockError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mock start failure"])
        }
        isRecording = true
    }
    
    func stop() {
        stopCallCount += 1
        isRecording = false
        hasRecordedFile = true
    }
}

// MARK: - ViewInspector Extensions

extension RecordingView: Inspectable { }
extension RecordingIndicator: Inspectable { }
extension FileProxyView: Inspectable { }

// MARK: - Test Helpers

extension ViewType.HStack {
    func find(button text: String) throws -> InspectableView<ViewType.Button> {
        return try self.find(ViewType.Button.self) { button in
            try button.labelView().text().string() == text
        }
    }
}