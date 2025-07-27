# Requirements Document

## Introduction

The Multi-Input Channel Recording feature extends AudioCap so that, in addition to its current audio capture sources, it automatically detects and records every physical (non-virtual, non-aggregate) audio input device connected to the system. Audio from each detected device will be captured in real-time and written into extra channels of the resulting WAV file, preserving channel integrity, synchronisation, and existing functionality.

## Requirements

### Requirement 1

**User Story:** As a recording user, I want the application to detect all physical audio input devices (excluding virtual or aggregate devices), so that they can be recorded automatically.

#### Acceptance Criteria

1. WHEN the recording session starts THEN the system SHALL enumerate all available audio input devices.
2. IF an audio input device is identified as virtual OR aggregate THEN the system SHALL exclude it from the enumerated list.
3. WHEN enumeration completes THEN the system SHALL maintain an internal list of eligible physical audio input devices for recording.

### Requirement 2

**User Story:** As a recording user, I want the audio from each eligible physical input device to be captured, so that it is included as additional channels in the output WAV file.

#### Acceptance Criteria

1. WHEN recording is active THEN the system SHALL capture audio samples from each eligible physical audio input device.
2. WHEN writing the output WAV file THEN the system SHALL interleave the captured audio samples as distinct channels corresponding to their source devices.
3. IF no eligible physical audio input devices are detected THEN the system SHALL produce a WAV file identical in channel structure to the current implementation.

### Requirement 3

**User Story:** As a recording user, I want the original process-tap audio to remain intact, so that existing functionality is preserved alongside the new input channels.

#### Acceptance Criteria

1. WHEN physical input device recording is enabled THEN the system SHALL still record process-tap audio exactly as before.
2. WHEN interleaving channels for output THEN the system SHALL preserve the original channel ordering first, followed by physical input device channels.

### Requirement 4

**User Story:** As a recording user, I want all recorded channels to be time-synchronised and sample-rate consistent, so that the output WAV plays back correctly.

#### Acceptance Criteria

1. WHEN capturing from devices with differing sample rates THEN the system SHALL perform real-time sample-rate conversion to match the recording session’s sample rate.
2. WHEN writing the WAV file THEN the system SHALL ensure all channels have aligned frame counts across the entire recording duration.

### Requirement 5

**User Story:** As a recording user, I want to be able to enable or disable inclusion of physical input devices, so that I can control file size and privacy.

#### Acceptance Criteria

1. WHEN starting a recording session THEN the system SHALL provide a configuration option to toggle physical input device recording on or off.
2. IF the user disables physical input device recording THEN the system SHALL behave identically to the current implementation. 