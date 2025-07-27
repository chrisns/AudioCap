# Implementation Tasks

## Task 1: Create Device Enumeration and Filtering Infrastructure

**Duration:** 1-2 hours  
**Priority:** High  
**Dependencies:** None

### Description
Implement the core device enumeration system that discovers all audio input devices and filters out virtual/aggregate devices to identify only physical hardware inputs.

### Implementation Steps
1. Create `PhysicalInputDevice` model struct with device metadata
2. Implement `DeviceEnumerator` class with Core Audio integration
3. Add device filtering logic based on transport type properties
4. Create unit tests for device enumeration and filtering logic
5. Add error handling for Core Audio API failures

### Acceptance Criteria
- [ ] `DeviceEnumerator` successfully queries Core Audio for input devices
- [ ] Virtual and aggregate devices are correctly filtered out
- [ ] Physical devices (USB, Built-in, PCI) are correctly identified
- [ ] Device metadata (name, channels, sample rate) is accurately captured
- [ ] Unit tests cover various device type scenarios
- [ ] Graceful handling when no devices are available

### Files to Create/Modify
- `AudioCap/ProcessTap/DeviceEnumerator.swift` (new)
- `AudioCap/ProcessTap/PhysicalInputDevice.swift` (new)
- `AudioCapTests/Core/DeviceEnumeratorTests.swift` (new)

---

## Task 2: Implement Device Recording Infrastructure

**Duration:** 2-3 hours  
**Priority:** High  
**Dependencies:** Task 1

### Description
Create the device recording system that can capture audio from individual physical input devices with sample rate conversion and thread-safe buffer management.

### Implementation Steps
1. Define `AudioInputCapturer` protocol
2. Implement `DeviceRecorder` class using AVAudioEngine
3. Add sample rate conversion using AVAudioConverter
4. Implement thread-safe buffer pulling mechanism
5. Create comprehensive unit tests
6. Add performance monitoring and error recovery

### Acceptance Criteria
- [ ] `DeviceRecorder` can start/stop recording from specific devices
- [ ] Sample rate conversion works correctly for various input rates
- [ ] Thread-safe buffer access with proper synchronization
- [ ] Graceful handling of device disconnection during recording
- [ ] Memory management prevents buffer accumulation
- [ ] Unit tests cover normal operation and error scenarios

### Files to Create/Modify
- `AudioCap/ProcessTap/AudioInputCapturer.swift` (new)
- `AudioCap/ProcessTap/DeviceRecorder.swift` (new)
- `AudioCapTests/Core/DeviceRecorderTests.swift` (new)

---

## Task 3: Create Channel Multiplexing System

**Duration:** 2-3 hours  
**Priority:** High  
**Dependencies:** Task 2

### Description
Implement the channel multiplexing system that combines audio from process-tap and physical devices into a single interleaved stream with proper alignment and synchronization.

### Implementation Steps
1. Create `ChannelDescriptor` model for channel metadata
2. Implement `ChannelMuxer` class for frame alignment and interleaving
3. Add silence padding for buffer alignment
4. Implement deterministic channel ordering logic
5. Create comprehensive unit tests with various timing scenarios
6. Add performance optimization for real-time processing

### Acceptance Criteria
- [ ] Process-tap channels are preserved in original order
- [ ] Physical device channels are added in deterministic order
- [ ] Frame alignment works correctly with varying buffer arrival times
- [ ] Silence padding maintains synchronization when needed
- [ ] No audio dropouts or glitches during normal operation
- [ ] Unit tests cover complex timing and alignment scenarios

### Files to Create/Modify
- `AudioCap/ProcessTap/ChannelDescriptor.swift` (new)
- `AudioCap/ProcessTap/ChannelMuxer.swift` (new)
- `AudioCapTests/Core/ChannelMuxerTests.swift` (new)

---

## Task 4: Extend WAV Writer for Multi-Channel Support

**Duration:** 1-2 hours  
**Priority:** Medium  
**Dependencies:** Task 3

### Description
Extend the existing WAV writer to handle variable channel counts and ensure proper WAV format compliance for multi-channel recordings.

### Implementation Steps
1. Analyze existing WAV writer implementation
2. Modify WAV header generation for variable channel counts
3. Update frame writing logic for interleaved multi-channel data
4. Add validation for channel count consistency
5. Create unit tests for multi-channel WAV generation
6. Verify WAV file compatibility with audio software

### Acceptance Criteria
- [ ] WAV writer accepts variable channel counts at initialization
- [ ] WAV headers correctly reflect total channel count
- [ ] Multi-channel audio data is properly interleaved in output
- [ ] Generated WAV files are playable in standard audio software
- [ ] Backward compatibility maintained for existing single/stereo recordings
- [ ] Unit tests verify WAV format compliance

### Files to Create/Modify
- Existing WAV writer files (location TBD based on codebase analysis)
- New unit tests for multi-channel WAV writing

---

## Task 5: Add Configuration and Settings Integration

**Duration:** 1-2 hours  
**Priority:** Medium  
**Dependencies:** None (can be done in parallel)

### Description
Extend the existing configuration system to include the physical input recording toggle and integrate it with the UI and API.

### Implementation Steps
1. Add `includePhysicalInputs` to `ServerConfiguration`
2. Update settings UI to include toggle control
3. Modify API endpoints to expose the new setting
4. Add configuration persistence
5. Create unit tests for configuration handling
6. Update API documentation

### Acceptance Criteria
- [ ] New setting is properly integrated into existing configuration system
- [ ] UI toggle correctly controls the feature
- [ ] API endpoints allow remote control of the setting
- [ ] Setting persists across application restarts
- [ ] Default value is sensible (likely disabled for privacy)
- [ ] Unit tests cover configuration scenarios

### Files to Create/Modify
- `AudioCap/HTTPServer/ServerConfiguration.swift`
- `AudioCap/HTTPServer/APISettingsView.swift`
- `AudioCap/HTTPServer/APIModels.swift`
- Related test files

---

## Task 6: Create Device Recorder Pool and Orchestration

**Duration:** 2-3 hours  
**Priority:** High  
**Dependencies:** Task 1, Task 2, Task 5

### Description
Implement the orchestration system that manages the lifecycle of device recorders and coordinates their operation with the main recording session.

### Implementation Steps
1. Create `DeviceRecorderPool` class for managing multiple recorders
2. Implement lifecycle management (start/stop/cleanup)
3. Add device change detection and dynamic recorder management
4. Integrate with existing recording session management
5. Create comprehensive integration tests
6. Add proper error handling and recovery

### Acceptance Criteria
- [ ] Pool correctly manages multiple device recorders
- [ ] Recorders start/stop synchronously with main recording
- [ ] Device hotplug/unplug is handled gracefully
- [ ] Clean resource cleanup on recording end
- [ ] Integration with existing AudioProcessController
- [ ] Integration tests verify end-to-end functionality

### Files to Create/Modify
- `AudioCap/ProcessTap/DeviceRecorderPool.swift` (new)
- `AudioCap/ProcessTap/AudioProcessController.swift` (modify)
- `AudioCapTests/Integration/MultiInputRecordingTests.swift` (new)

---

## Task 7: Integration and End-to-End Testing

**Duration:** 2-3 hours  
**Priority:** High  
**Dependencies:** All previous tasks

### Description
Complete the integration of all components and create comprehensive end-to-end tests to ensure the feature works correctly in real-world scenarios.

### Implementation Steps
1. Integrate all components into the main recording pipeline
2. Create end-to-end integration tests
3. Test with various device configurations
4. Performance testing under load
5. Verify backward compatibility
6. Update API documentation with new channel behavior

### Acceptance Criteria
- [ ] Complete feature works end-to-end
- [ ] No regression in existing functionality
- [ ] Performance is acceptable with multiple input devices
- [ ] Error scenarios are handled gracefully
- [ ] API documentation reflects new behavior
- [ ] Integration tests cover realistic usage scenarios

### Files to Create/Modify
- Various existing files for final integration
- `AudioCapTests/Integration/EndToEndMultiInputTests.swift` (new)
- API documentation updates

---

## Implementation Order

1. **Phase 1 (Foundation):** Tasks 1, 2, 5 (can be done in parallel)
2. **Phase 2 (Core Logic):** Tasks 3, 4 (sequential, 3 before 4)
3. **Phase 3 (Integration):** Tasks 6, 7 (sequential)

## Risk Mitigation

- **Device Compatibility:** Test with various USB audio interfaces early
- **Performance Impact:** Monitor CPU usage during development
- **Memory Management:** Profile memory usage with multiple devices
- **Audio Quality:** Verify no quality degradation in existing recordings

## Success Metrics

- [ ] All physical audio input devices are correctly detected
- [ ] Multi-channel WAV files are generated correctly
- [ ] No performance regression in existing functionality
- [ ] Feature can be enabled/disabled via UI and API
- [ ] Comprehensive test coverage (>90%) for new code 