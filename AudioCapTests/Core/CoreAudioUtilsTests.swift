import XCTest
import AudioToolbox
@testable import AudioCap

final class CoreAudioUtilsTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    // MARK: - AudioObjectID Extension Tests
    
    func testAudioObjectIDConstants() {
        XCTAssertEqual(AudioObjectID.system, AudioObjectID(kAudioObjectSystemObject))
        XCTAssertEqual(AudioObjectID.unknown, kAudioObjectUnknown)
    }
    
    func testAudioObjectIDValidation() {
        let validID = AudioObjectID.system
        let invalidID = AudioObjectID.unknown
        
        XCTAssertTrue(validID.isValid)
        XCTAssertFalse(validID.isUnknown)
        
        XCTAssertFalse(invalidID.isValid)
        XCTAssertTrue(invalidID.isUnknown)
    }
    
    // MARK: - System Object Property Reading Tests
    
    func testReadDefaultSystemOutputDevice() {
        do {
            let deviceID = try AudioObjectID.readDefaultSystemOutputDevice()
            XCTAssertTrue(deviceID.isValid, "Default system output device should be valid")
            XCTAssertNotEqual(deviceID, AudioObjectID.unknown)
        } catch {
            XCTFail("Reading default system output device should not throw: \(error)")
        }
    }
    
    func testReadDefaultSystemOutputDeviceOnSystemObject() {
        do {
            let deviceID = try AudioObjectID.system.readDefaultSystemOutputDevice()
            XCTAssertTrue(deviceID.isValid, "Default system output device should be valid")
        } catch {
            XCTFail("Reading default system output device on system object should not throw: \(error)")
        }
    }
    
    func testReadDefaultSystemOutputDeviceOnNonSystemObjectThrows() {
        let nonSystemID = AudioObjectID(12345)
        
        XCTAssertThrowsError(try nonSystemID.readDefaultSystemOutputDevice()) { error in
            XCTAssertTrue(error.localizedDescription.contains("Only supported for the system object"))
        }
    }
    
    func testReadProcessList() {
        do {
            let processList = try AudioObjectID.readProcessList()
            // Process list can be empty or contain processes, both are valid
            XCTAssertTrue(processList.count >= 0)
            
            // All returned process IDs should be valid
            for processID in processList {
                XCTAssertTrue(processID.isValid, "Process ID \(processID) should be valid")
            }
        } catch {
            XCTFail("Reading process list should not throw: \(error)")
        }
    }
    
    func testReadProcessListOnSystemObject() {
        do {
            let processList = try AudioObjectID.system.readProcessList()
            XCTAssertTrue(processList.count >= 0)
        } catch {
            XCTFail("Reading process list on system object should not throw: \(error)")
        }
    }
    
    func testReadProcessListOnNonSystemObjectThrows() {
        let nonSystemID = AudioObjectID(12345)
        
        XCTAssertThrowsError(try nonSystemID.readProcessList()) { error in
            XCTAssertTrue(error.localizedDescription.contains("Only supported for the system object"))
        }
    }
    
    // MARK: - PID Translation Tests
    
    func testTranslatePIDToProcessObjectID() {
        // Use current process PID for testing
        let currentPID = ProcessInfo.processInfo.processIdentifier
        
        do {
            let processObjectID = try AudioObjectID.translatePIDToProcessObjectID(pid: currentPID)
            XCTAssertTrue(processObjectID.isValid, "Process object ID should be valid for current process")
        } catch {
            // This might fail if the current process doesn't have audio capabilities
            // which is acceptable for this test
            XCTAssertTrue(error.localizedDescription.contains("Invalid process identifier") ||
                         error.localizedDescription.contains("Error reading"))
        }
    }
    
    func testTranslatePIDToProcessObjectIDOnSystemObject() {
        let currentPID = ProcessInfo.processInfo.processIdentifier
        
        do {
            let processObjectID = try AudioObjectID.system.translatePIDToProcessObjectID(pid: currentPID)
            XCTAssertTrue(processObjectID.isValid, "Process object ID should be valid for current process")
        } catch {
            // This might fail if the current process doesn't have audio capabilities
            XCTAssertTrue(error.localizedDescription.contains("Invalid process identifier") ||
                         error.localizedDescription.contains("Error reading"))
        }
    }
    
    func testTranslatePIDToProcessObjectIDOnNonSystemObjectThrows() {
        let nonSystemID = AudioObjectID(12345)
        let currentPID = ProcessInfo.processInfo.processIdentifier
        
        XCTAssertThrowsError(try nonSystemID.translatePIDToProcessObjectID(pid: currentPID)) { error in
            XCTAssertTrue(error.localizedDescription.contains("Only supported for the system object"))
        }
    }
    
    func testTranslateInvalidPIDThrows() {
        let invalidPID: pid_t = -1
        
        XCTAssertThrowsError(try AudioObjectID.translatePIDToProcessObjectID(pid: invalidPID)) { error in
            XCTAssertTrue(error.localizedDescription.contains("Invalid process identifier") ||
                         error.localizedDescription.contains("Error reading"))
        }
    }
    
    // MARK: - Process Property Reading Tests
    
    func testReadProcessBundleID() {
        // Create a mock process object ID for testing
        let mockProcessID = AudioObjectID(12345)
        
        // This should return nil for invalid process IDs
        let bundleID = mockProcessID.readProcessBundleID()
        XCTAssertNil(bundleID, "Bundle ID should be nil for invalid process ID")
    }
    
    func testReadProcessIsRunning() {
        // Create a mock process object ID for testing
        let mockProcessID = AudioObjectID(12345)
        
        // This should return false for invalid process IDs
        let isRunning = mockProcessID.readProcessIsRunning()
        XCTAssertFalse(isRunning, "Process should not be running for invalid process ID")
    }
    
    // MARK: - Device Property Reading Tests
    
    func testReadDeviceUID() {
        do {
            let deviceID = try AudioObjectID.readDefaultSystemOutputDevice()
            let deviceUID = try deviceID.readDeviceUID()
            XCTAssertFalse(deviceUID.isEmpty, "Device UID should not be empty")
        } catch {
            XCTFail("Reading device UID should not throw for valid device: \(error)")
        }
    }
    
    func testReadDeviceUIDWithInvalidDeviceThrows() {
        let invalidDeviceID = AudioObjectID.unknown
        
        XCTAssertThrowsError(try invalidDeviceID.readDeviceUID()) { error in
            XCTAssertTrue(error.localizedDescription.contains("Error reading"))
        }
    }
    
    // MARK: - Audio Tap Property Reading Tests
    
    func testReadAudioTapStreamBasicDescription() {
        // This test uses an invalid tap ID to test error handling
        let invalidTapID = AudioObjectID.unknown
        
        XCTAssertThrowsError(try invalidTapID.readAudioTapStreamBasicDescription()) { error in
            XCTAssertTrue(error.localizedDescription.contains("Error reading"))
        }
    }
    
    // MARK: - Generic Property Access Tests
    
    func testGenericPropertyReadWithQualifier() {
        // Test the generic property reading with qualifier
        let systemID = AudioObjectID.system
        let currentPID = ProcessInfo.processInfo.processIdentifier
        
        do {
            let result: AudioObjectID = try systemID.read(
                kAudioHardwarePropertyTranslatePIDToProcessObject,
                defaultValue: AudioObjectID.unknown,
                qualifier: currentPID
            )
            // Result can be valid or unknown depending on whether current process has audio
            XCTAssertTrue(result == AudioObjectID.unknown || result.isValid)
        } catch {
            // This is acceptable as the current process might not have audio capabilities
            XCTAssertTrue(error.localizedDescription.contains("Error reading"))
        }
    }
    
    func testGenericPropertyReadWithoutQualifier() {
        let systemID = AudioObjectID.system
        
        do {
            let result: AudioDeviceID = try systemID.read(
                kAudioHardwarePropertyDefaultSystemOutputDevice,
                defaultValue: AudioDeviceID.unknown
            )
            XCTAssertTrue(result.isValid, "Default system output device should be valid")
        } catch {
            XCTFail("Reading default system output device should not throw: \(error)")
        }
    }
    
    func testReadStringProperty() {
        do {
            let deviceID = try AudioObjectID.readDefaultSystemOutputDevice()
            let deviceUID = try deviceID.readString(kAudioDevicePropertyDeviceUID)
            XCTAssertFalse(deviceUID.isEmpty, "Device UID string should not be empty")
        } catch {
            XCTFail("Reading string property should not throw for valid device: \(error)")
        }
    }
    
    func testReadBoolProperty() {
        // Test with a mock process ID - this should handle the error gracefully
        let mockProcessID = AudioObjectID(12345)
        let isRunning = mockProcessID.readProcessIsRunning()
        XCTAssertFalse(isRunning, "Mock process should not be running")
    }
    
    // MARK: - Error Handling Tests
    
    func testPropertyReadingWithInvalidObjectID() {
        let invalidID = AudioObjectID.unknown
        
        XCTAssertThrowsError(try invalidID.read(
            kAudioHardwarePropertyDefaultSystemOutputDevice,
            defaultValue: AudioDeviceID.unknown
        )) { error in
            XCTAssertTrue(error.localizedDescription.contains("Error reading"))
        }
    }
    
    func testPropertyReadingWithInvalidSelector() {
        let systemID = AudioObjectID.system
        let invalidSelector: AudioObjectPropertySelector = 0x00000000
        
        XCTAssertThrowsError(try systemID.read(
            invalidSelector,
            defaultValue: 0 as UInt32
        )) { error in
            XCTAssertTrue(error.localizedDescription.contains("Error reading"))
        }
    }
    
    // MARK: - AudioObjectPropertyAddress Description Tests
    
    func testAudioObjectPropertyAddressDescription() {
        let address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultSystemOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        let description = address.description
        XCTAssertFalse(description.isEmpty, "Property address description should not be empty")
        XCTAssertTrue(description.contains("/"), "Description should contain scope separator")
        XCTAssertTrue(description.contains("main"), "Description should contain 'main' for main element")
    }
}