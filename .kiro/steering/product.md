# AudioCap Product Overview

AudioCap is a macOS sample application that demonstrates how to use the new CoreAudio API introduced in macOS 14.4 for capturing audio from other applications or the entire system.

## Purpose
- Educational/documentation project for the new CoreAudio process tap API
- Shows developers how to implement audio capture from other processes
- Demonstrates proper permission handling for audio recording

## Key Features
- Process selection UI for choosing which app to record from
- Audio recording with proper CoreAudio tap setup
- Permission management for audio capture
- File export functionality for recorded audio

## Target Platform
- macOS 14.4+ (required for the new CoreAudio API)
- Swift/SwiftUI application
- Requires audio recording permissions from the user

## Use Case
This is primarily a reference implementation and learning tool for developers who need to implement similar audio capture functionality in their own applications.