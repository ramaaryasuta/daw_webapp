# DAW Flutter Web

## Stack

- Flutter Web
- Riverpod without code generation
- go_router
- desktop_drop
- file_picker
- package:web
- Web Audio API

## Architecture

Feature-first architecture.

Editor:

lib/features/editor/
- application/
- domain/
- infrastructure/
- presentation/

## Audio architecture

Flutter/Riverpod state must not contain Web Audio API browser objects.

EditorState stores:
- track metadata
- playhead
- mute/solo/volume
- waveform peak data

WebAudioEngine stores:
- AudioContext
- AudioBuffer
- AudioBufferSourceNode
- GainNode

Audio playback must use AudioContext.currentTime for scheduling.
Do not use Flutter Timer as the audio clock.

Flutter Timer may only be used to update the visual playhead.

## Import

Audio can be imported through:
- File Picker
- Drag and drop using desktop_drop

Both should go through AudioImportService.

Supported initially:
- WAV
- MP3

## Current goal

Build a simple multi-track DAW:
1. Import multiple audio tracks
2. Waveform
3. Synchronized playback
4. Play/pause/stop
5. Volume/mute/solo
6. Timeline seek
7. Drag clips
8. Timeline zoom/scroll