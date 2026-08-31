enum AppCommandCategory {
  file('Project'),
  editing('Editing'),
  timeline('Timeline'),
  mixer('Mixer');

  const AppCommandCategory(this.label);

  final String label;
}

const _trackFxKnobTip =
    'Drag knobs vertically to adjust. Hold Shift while dragging for fine '
    'control. Double-click a knob to reset it.';

class AppCommand {
  const AppCommand({
    required this.title,
    required this.description,
    required this.shortcutParts,
    required this.category,
    this.searchTerms = const [],
    this.details,
    this.usageSteps = const [],
    this.tip,
  });

  final String title;
  final String description;
  final List<String> shortcutParts;
  final AppCommandCategory category;
  final List<String> searchTerms;
  final String? details;
  final List<String> usageSteps;
  final String? tip;
}

abstract final class EditorCommands {
  static const saveProject = AppCommand(
    title: 'Save Project',
    description:
        'Save the project and its audio sources as a portable Flaudio Project (.flaudioproject).',
    shortcutParts: ['File', 'Save Project...'],
    category: AppCommandCategory.file,
  );

  static const openProject = AppCommand(
    title: 'Open Project',
    description: 'Open a portable Flaudio Project (.flaudioproject).',
    shortcutParts: ['File', 'Open Project...'],
    category: AppCommandCategory.file,
  );

  static const exportAudio = AppCommand(
    title: 'Export Audio',
    description:
        'Render your project locally as lossless WAV or compressed MP3.',
    shortcutParts: ['File', 'Export...'],
    category: AppCommandCategory.file,
    details: 'MP3 supports multiple quality levels and optional ID3 metadata.',
    searchTerms: [
      'export',
      'wav',
      'mp3',
      'download',
      'render',
      'metadata',
      'bitrate',
      'audio',
    ],
  );

  static const undo = AppCommand(
    title: 'Undo',
    description: 'Undo the most recent editing action.',
    shortcutParts: ['Ctrl', 'Z'],
    category: AppCommandCategory.editing,
  );

  static const redo = AppCommand(
    title: 'Redo',
    description:
        'Redo the most recently undone editing action. Ctrl + Y is also supported.',
    shortcutParts: ['Ctrl', 'Shift', 'Z'],
    category: AppCommandCategory.editing,
  );

  static const copyAudioClip = AppCommand(
    title: 'Copy Clip(s)',
    description: 'Copy all selected audio clips.',
    shortcutParts: ['Ctrl', 'C'],
    category: AppCommandCategory.editing,
  );

  static const pasteAudioClip = AppCommand(
    title: 'Paste Clip(s)',
    description: 'Paste copied audio clips at the playhead.',
    shortcutParts: ['Ctrl', 'V'],
    category: AppCommandCategory.editing,
  );

  static const duplicateAudioClip = AppCommand(
    title: 'Duplicate Clip(s)',
    description: 'Duplicate the selected clip group after its visible end.',
    shortcutParts: ['Ctrl', 'D'],
    category: AppCommandCategory.editing,
  );

  static const playPause = AppCommand(
    title: 'Play / Pause',
    description: 'Start or pause playback at the current playhead position.',
    shortcutParts: ['Space'],
    category: AppCommandCategory.timeline,
  );

  static const toggleLoop = AppCommand(
    title: 'Toggle Loop',
    description:
        'Enable or disable playback looping for the selected cycle region.',
    shortcutParts: ['L'],
    category: AppCommandCategory.timeline,
  );

  static const setLoopRegion = AppCommand(
    title: 'Set Loop Region',
    description: 'Create or resize the playback loop region.',
    shortcutParts: ['Drag Timeline Ruler'],
    category: AppCommandCategory.timeline,
  );

  static const zoomTimeline = AppCommand(
    title: 'Zoom Timeline',
    description: 'Zoom the timeline horizontally around the pointer position.',
    shortcutParts: ['Ctrl', 'Mouse Wheel'],
    category: AppCommandCategory.timeline,
  );

  static const scrollTimeline = AppCommand(
    title: 'Scroll Timeline',
    description: 'Scroll horizontally through the timeline.',
    shortcutParts: ['Shift', 'Mouse Wheel'],
    category: AppCommandCategory.timeline,
  );

  static const panTimeline = AppCommand(
    title: 'Pan Timeline',
    description: 'Grab and pan the timeline horizontally.',
    shortcutParts: ['Middle Mouse', 'Drag'],
    category: AppCommandCategory.timeline,
  );

  static const moveAudioClip = AppCommand(
    title: 'Move Clip(s)',
    description: 'Move selected audio clips in time or between tracks.',
    shortcutParts: ['Left Mouse', 'Drag'],
    category: AppCommandCategory.timeline,
  );

  static const trimAudioClip = AppCommand(
    title: 'Trim Audio Clip',
    description: 'Trim the visible start or end of an audio clip.',
    shortcutParts: ['Drag Clip Edge'],
    category: AppCommandCategory.timeline,
  );

  static const splitAudioClip = AppCommand(
    title: 'Split Clip',
    description: 'Split the selected audio clip at the playhead.',
    shortcutParts: ['S'],
    category: AppCommandCategory.editing,
    details: 'Splits the selected audio clip at the current playhead position.',
    usageSteps: ['Select one clip.', 'Move the playhead.', 'Press S.'],
    tip: 'Snap can be used to position the playhead before splitting.',
  );

  static const deleteAudioClip = AppCommand(
    title: 'Delete Clip(s)',
    description: 'Remove all selected audio clips from the arrangement.',
    shortcutParts: ['Delete / Backspace'],
    category: AppCommandCategory.editing,
  );

  static const createCrossfade = AppCommand(
    title: 'Create Crossfade',
    description:
        'Create a fade transition between two selected overlapping clips.',
    shortcutParts: ['Edit', 'Create Crossfade'],
    category: AppCommandCategory.editing,
  );

  static const removeCrossfade = AppCommand(
    title: 'Remove Crossfade',
    description: 'Remove the crossfade between the selected clips.',
    shortcutParts: ['Edit', 'Remove Crossfade'],
    category: AppCommandCategory.editing,
  );

  static const clipProperties = AppCommand(
    title: 'Clip Properties',
    description:
        'Open Gain and Fade In / Fade Out properties for the audio clip.',
    shortcutParts: ['Double-click Audio Clip'],
    category: AppCommandCategory.editing,
  );

  static const reverseClip = AppCommand(
    title: 'Reverse Clip',
    description:
        "Play the selected clip's visible source range backwards without changing the original audio file.",
    shortcutParts: ['Clip Properties', 'Reverse Audio'],
    category: AppCommandCategory.editing,
    searchTerms: ['reverse', 'backwards', 'flip', 'clip', 'audio'],
  );

  static const multiSelectClip = AppCommand(
    title: 'Multi-Select Clip',
    description: 'Add or remove an audio clip from the current selection.',
    shortcutParts: ['Ctrl', 'Click'],
    category: AppCommandCategory.editing,
  );

  static const marqueeSelect = AppCommand(
    title: 'Marquee Select',
    description: 'Select multiple audio clips with a selection rectangle.',
    shortcutParts: ['Drag Empty Timeline'],
    category: AppCommandCategory.timeline,
  );

  static const renameTrack = AppCommand(
    title: 'Rename Track',
    description: 'Rename a track directly in its header.',
    shortcutParts: ['Double-click Track Name'],
    category: AppCommandCategory.editing,
  );

  static const changeTrackColor = AppCommand(
    title: 'Change Track Color',
    description: 'Choose the color used by a track and all of its clips.',
    shortcutParts: ['Click Track Color'],
    category: AppCommandCategory.editing,
  );

  static const addAudioTrack = AppCommand(
    title: 'Add Audio Track',
    description: 'Create a new empty audio track.',
    shortcutParts: ['Tracks + Button'],
    category: AppCommandCategory.editing,
  );

  static const deleteTrack = AppCommand(
    title: 'Delete Track',
    description: 'Remove a track and its clips from the arrangement.',
    shortcutParts: ['Track Actions', 'Delete Track'],
    category: AppCommandCategory.editing,
  );

  static const duplicateTrack = AppCommand(
    title: 'Duplicate Track',
    description:
        'Create a copy of the track, its mixer settings, and all of its audio clips.',
    shortcutParts: ['Track Actions', 'Duplicate Track'],
    category: AppCommandCategory.editing,
    searchTerms: ['duplicate', 'copy track', 'clone'],
  );

  static const trackFilterFx = AppCommand(
    title: 'Track Filter FX',
    description:
        'Open the track filter rack and shape the track with high-pass and low-pass filters.',
    shortcutParts: ['Track Actions', 'Track FX'],
    category: AppCommandCategory.mixer,
    searchTerms: [
      'filter',
      'fx',
      'effect',
      'high pass',
      'low pass',
      'cutoff',
      'resonance',
      'frequency',
    ],
    usageSteps: [
      'Open Track FX from the track actions menu.',
      'Enable the high-pass or low-pass module.',
      'Drag Cutoff vertically to choose the corner frequency.',
      'Adjust Resonance (Q) around the cutoff.',
      'Use the global FILTER bypass to compare processed and unprocessed audio.',
    ],
    tip: _trackFxKnobTip,
  );

  static const trackEqFx = AppCommand(
    title: '3-Band EQ',
    description: 'Shape the low, mid, and high frequency balance of a track.',
    shortcutParts: ['Track Actions', 'Track FX', '3-Band EQ'],
    category: AppCommandCategory.mixer,
    searchTerms: [
      'eq',
      'equalizer',
      'low',
      'mid',
      'high',
      'frequency',
      'tone',
      '3 band',
    ],
    usageSteps: [
      'Open Track FX.',
      'Select 3-Band EQ.',
      'Enable EQ.',
      'Adjust Low, Mid, and High gain.',
      'Use Mid Frequency and Q to target a specific midrange area.',
    ],
    tip: _trackFxKnobTip,
  );

  static const trackCompressor = AppCommand(
    title: 'Track Compressor',
    description:
        'Control track dynamics by reducing louder signals and optionally restoring level with makeup gain.',
    shortcutParts: ['Track Actions', 'Track FX', 'Compressor'],
    category: AppCommandCategory.mixer,
    searchTerms: [
      'compressor',
      'compression',
      'dynamics',
      'threshold',
      'ratio',
      'attack',
      'release',
      'gain reduction',
      'makeup',
    ],
    usageSteps: [
      'Enable Compressor.',
      'Lower Threshold until gain reduction appears.',
      'Increase Ratio for stronger compression.',
      'Adjust Attack and Release for response speed.',
      'Use Makeup Gain to restore output level.',
    ],
    tip: _trackFxKnobTip,
  );

  static const masterLimiter = AppCommand(
    title: 'Master Limiter',
    description:
        'Control excessive Master peaks before the final output and WAV export.',
    shortcutParts: ['Master Strip', 'Limiter'],
    category: AppCommandCategory.mixer,
    searchTerms: [
      'master',
      'limiter',
      'limit',
      'clipping',
      'peak',
      'ceiling',
      'threshold',
      'gain reduction',
      'mastering',
      'output',
    ],
    usageSteps: [
      'Enable Master Limiter.',
      'Set Ceiling, typically around -1 dB.',
      'Lower Threshold until occasional Gain Reduction appears.',
      'Adjust Release if the limiting sounds too abrupt or too slow.',
      'Watch the GR meter.',
    ],
    tip:
        'Heavy constant gain reduction usually means the mix or Master level is being driven too hard.',
  );

  static const trackDelay = AppCommand(
    title: 'Track Delay',
    description:
        'Create repeating echoes on a track with adjustable time, feedback, mix, and tempo sync.',
    shortcutParts: ['Track Actions', 'Track FX', 'Delay'],
    category: AppCommandCategory.mixer,
    searchTerms: [
      'delay',
      'echo',
      'feedback',
      'wet',
      'dry',
      'tempo sync',
      'bpm',
      'repeat',
      'fx',
    ],
    usageSteps: [
      'Enable Delay.',
      'Adjust Time or enable BPM Sync.',
      'Increase Feedback for more repeats.',
      'Adjust Mix for the desired dry/wet balance.',
      'Reorder Delay in the FX Chain to change how other effects interact with it.',
    ],
    tip:
        'Delay before Compressor sounds different from Compressor before Delay.',
  );

  static const trackReverb = AppCommand(
    title: 'Track Reverb',
    description:
        'Add a sense of room or space with adjustable pre-delay, decay, damping, and mix.',
    shortcutParts: ['Track Actions', 'Track FX', 'Reverb'],
    category: AppCommandCategory.mixer,
    searchTerms: [
      'reverb',
      'room',
      'hall',
      'space',
      'decay',
      'damping',
      'wet',
      'dry',
      'predelay',
      'ambience',
      'fx',
    ],
    usageSteps: [
      'Enable Reverb.',
      'Increase Decay for a larger or longer space.',
      'Use Pre-Delay to separate the source from the room.',
      'Lower Damping for a darker tail.',
      'Adjust Mix.',
      'Reorder Reverb in the FX Chain to change processing behavior.',
    ],
    tip: _trackFxKnobTip,
  );

  static const reorderTrackFx = AppCommand(
    title: 'Reorder Track FX',
    description:
        'Change the order in which built-in effects process the track.',
    shortcutParts: ['Drag FX Slot'],
    category: AppCommandCategory.mixer,
    searchTerms: [
      'fx chain',
      'effect order',
      'reorder',
      'signal flow',
      'insert',
      'rack',
      'filter',
      'eq',
      'compressor',
      'delay',
      'reverb',
    ],
    usageSteps: [
      'Open Track FX.',
      'Drag an FX slot by its grip.',
      'Drop it at the desired position.',
      'Audio processing follows the new top-to-bottom order.',
    ],
    tip:
        'Effect order changes the sound. For example, Compressor before EQ '
        'can behave differently from EQ before Compressor.',
  );

  static const reorderTrack = AppCommand(
    title: 'Reorder Track',
    description: 'Change the vertical order of an audio track.',
    shortcutParts: ['Drag Track Handle'],
    category: AppCommandCategory.editing,
  );

  static const snapToGrid = AppCommand(
    title: 'Snap to Grid',
    description:
        'Align clip movement, trimming, loop boundaries, and timeline seeking to the selected musical grid.',
    shortcutParts: ['Toolbar', 'Snap'],
    category: AppCommandCategory.timeline,
  );

  static const timeSignature = AppCommand(
    title: 'Time Signature',
    description:
        "Change the project's musical meter, such as 4/4, 3/4, or 6/8.",
    shortcutParts: ['Toolbar', 'Time Signature'],
    category: AppCommandCategory.timeline,
    searchTerms: ['time', 'signature', '4/4', '3/4', '6/8', 'meter'],
    details:
        'Changes how bars and beats are interpreted without moving clips, markers, or loop boundaries.',
    usageSteps: [
      'Open Time Signature in the toolbar.',
      'Choose 4/4, 3/4, or 6/8.',
    ],
    tip: 'The ruler, Snap, and metronome update to the selected meter.',
  );

  static const trackMixerControls = AppCommand(
    title: 'Track Mixer Controls',
    description: 'Adjust track volume, pan, mute, and solo.',
    shortcutParts: ['Track Header', 'Mixer Controls'],
    category: AppCommandCategory.mixer,
    searchTerms: ['gain', 'level', 'stereo', 'mute', 'solo', 'volume', 'pan'],
    details:
        'Shapes each track in the mix with level, stereo position, mute, and solo controls.',
    usageSteps: [
      'Locate the track header.',
      'Adjust its volume or pan, or use Mute and Solo.',
    ],
    tip: 'Double-click a volume or pan control to reset it.',
  );

  static const mixerWorkspace = AppCommand(
    title: 'Mixer',
    description:
        'Open a dedicated mixer workspace for controlling track levels, pan, meters, effects, and the Master output.',
    shortcutParts: ['Editor > Mixer'],
    category: AppCommandCategory.mixer,
    searchTerms: [
      'mixer',
      'mix',
      'channel strip',
      'meter',
      'master',
      'console',
    ],
  );

  static const mixerTrackFader = AppCommand(
    title: 'Track Fader',
    description: 'Adjust track volume.',
    shortcutParts: ['Drag Mixer Fader'],
    category: AppCommandCategory.mixer,
    searchTerms: ['mixer', 'mix', 'fader', 'volume', 'level', 'channel strip'],
    tip: 'Double-click the fader to return to 0 dB.',
  );

  static const mixerTrackPan = AppCommand(
    title: 'Track Pan',
    description: 'Place a track in the stereo field.',
    shortcutParts: ['Drag Pan Knob'],
    category: AppCommandCategory.mixer,
    searchTerms: ['mixer', 'mix', 'pan', 'stereo', 'channel strip', 'console'],
    tip: 'Double-click the Pan knob to return to center.',
  );

  static const temporarilyDisableSnap = AppCommand(
    title: 'Temporarily Disable Snap',
    description: 'Temporarily move or trim freely without snapping.',
    shortcutParts: ['Alt', 'Drag'],
    category: AppCommandCategory.timeline,
  );

  static const addMarker = AppCommand(
    title: 'Add Marker',
    description: 'Create a timeline marker at the selected position.',
    shortcutParts: ['Double-click Marker Lane'],
    category: AppCommandCategory.timeline,
    searchTerms: ['verse', 'chorus'],
  );

  static const openMarkerProperties = AppCommand(
    title: 'Open Marker Properties',
    description: 'Rename, recolor, or delete a timeline marker.',
    shortcutParts: ['Double-click Marker'],
    category: AppCommandCategory.editing,
  );

  static const moveMarker = AppCommand(
    title: 'Move Marker',
    description: 'Move a marker along the timeline.',
    shortcutParts: ['Drag Marker'],
    category: AppCommandCategory.timeline,
  );

  static const jumpToMarker = AppCommand(
    title: 'Jump to Marker',
    description: 'Move the playhead to a timeline marker.',
    shortcutParts: ['Click Marker'],
    category: AppCommandCategory.timeline,
  );

  static const createSection = AppCommand(
    title: 'Create Section',
    description: 'Create a named range for part of the arrangement.',
    shortcutParts: ['Drag Section Lane'],
    category: AppCommandCategory.timeline,
    searchTerms: [
      'section',
      'range',
      'intro',
      'verse',
      'chorus',
      'arrangement',
    ],
    usageSteps: [
      'Drag from the beginning to the end of a Verse.',
      'Rename the created section.',
    ],
  );

  static const moveSection = AppCommand(
    title: 'Move Section',
    description: 'Move the complete section while preserving its duration.',
    shortcutParts: ['Drag Section'],
    category: AppCommandCategory.timeline,
    searchTerms: [
      'section',
      'range',
      'intro',
      'verse',
      'chorus',
      'arrangement',
    ],
  );

  static const resizeSection = AppCommand(
    title: 'Resize Section',
    description: 'Adjust the start or end of a section.',
    shortcutParts: ['Drag Section Edge'],
    category: AppCommandCategory.timeline,
    searchTerms: [
      'section',
      'range',
      'intro',
      'verse',
      'chorus',
      'arrangement',
    ],
  );

  static const sectionProperties = AppCommand(
    title: 'Section Properties',
    description: 'Rename, recolor, or delete an arrangement section.',
    shortcutParts: ['Double-click Section'],
    category: AppCommandCategory.editing,
    searchTerms: [
      'section',
      'range',
      'intro',
      'verse',
      'chorus',
      'arrangement',
    ],
  );

  static const all = <AppCommand>[
    undo,
    redo,
    openProject,
    saveProject,
    exportAudio,
    copyAudioClip,
    pasteAudioClip,
    duplicateAudioClip,
    splitAudioClip,
    deleteAudioClip,
    createCrossfade,
    removeCrossfade,
    multiSelectClip,
    clipProperties,
    reverseClip,
    renameTrack,
    changeTrackColor,
    addAudioTrack,
    duplicateTrack,
    trackFilterFx,
    trackEqFx,
    trackCompressor,
    masterLimiter,
    trackDelay,
    trackReverb,
    reorderTrackFx,
    deleteTrack,
    reorderTrack,
    mixerWorkspace,
    mixerTrackFader,
    mixerTrackPan,
    trackMixerControls,
    playPause,
    toggleLoop,
    setLoopRegion,
    timeSignature,
    snapToGrid,
    temporarilyDisableSnap,
    zoomTimeline,
    scrollTimeline,
    panTimeline,
    moveAudioClip,
    marqueeSelect,
    trimAudioClip,
    addMarker,
    openMarkerProperties,
    moveMarker,
    jumpToMarker,
    createSection,
    moveSection,
    resizeSection,
    sectionProperties,
  ];
}
