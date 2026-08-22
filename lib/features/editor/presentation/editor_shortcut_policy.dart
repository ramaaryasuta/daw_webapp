import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Matches an unmodified Space key only when editor transport may own it.
///
/// Rejecting the key at activation time is important: it lets focused text and
/// controls continue receiving Space instead of merely suppressing the action
/// after the shortcut system has already consumed the event.
class PlayPauseShortcutActivator extends ShortcutActivator {
  const PlayPauseShortcutActivator();

  @override
  String debugDescribeKeys() => 'Space';

  @override
  bool accepts(KeyEvent event, HardwareKeyboard state) {
    return event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.space &&
        !state.isAltPressed &&
        !state.isControlPressed &&
        !state.isMetaPressed &&
        !state.isShiftPressed &&
        !EditorShortcutPolicy.primaryFocusOwnsSpace;
  }
}

/// Ctrl-based editing shortcut which yields to focused text editors.
class EditorHistoryShortcutActivator extends ShortcutActivator {
  const EditorHistoryShortcutActivator(this.key, {this.shift = false});

  final LogicalKeyboardKey key;
  final bool shift;

  @override
  String debugDescribeKeys() {
    return 'Ctrl + ${shift ? 'Shift + ' : ''}${key.keyLabel}';
  }

  @override
  bool accepts(KeyEvent event, HardwareKeyboard state) {
    return event is KeyDownEvent &&
        event.logicalKey == key &&
        state.isControlPressed &&
        !state.isMetaPressed &&
        !state.isAltPressed &&
        state.isShiftPressed == shift &&
        !EditorShortcutPolicy.primaryFocusIsEditable;
  }
}

/// Unmodified editing shortcut which yields to focused text and editor controls.
class EditorCommandShortcutActivator extends ShortcutActivator {
  const EditorCommandShortcutActivator(this.key);

  final LogicalKeyboardKey key;

  @override
  String debugDescribeKeys() => key.keyLabel;

  @override
  bool accepts(KeyEvent event, HardwareKeyboard state) {
    return event is KeyDownEvent &&
        event.logicalKey == key &&
        !state.isAltPressed &&
        !state.isControlPressed &&
        !state.isMetaPressed &&
        !state.isShiftPressed &&
        !EditorShortcutPolicy._primaryFocusOwnsEditorCommands;
  }
}

/// Focus and route rules shared by editor-level keyboard commands.
abstract final class EditorShortcutPolicy {
  static bool get primaryFocusIsEditable {
    final focusContext = FocusManager.instance.primaryFocus?.context;
    return focusContext != null &&
        _hasAncestorMatching(focusContext, (widget) => widget is EditableText);
  }

  static bool get primaryFocusOwnsSpace {
    final focusContext = FocusManager.instance.primaryFocus?.context;
    if (focusContext == null) {
      return false;
    }

    return _hasAncestorMatching(
      focusContext,
      (widget) =>
          widget is EditableText ||
          widget is EditorShortcutScope ||
          widget is ButtonStyleButton ||
          widget is IconButton ||
          widget is PopupMenuButton ||
          widget is DropdownButton ||
          widget is Slider ||
          widget is Checkbox ||
          widget is Radio ||
          widget is Switch,
    );
  }

  static bool canHandleEditorCommand(BuildContext editorContext) {
    if (ModalRoute.of(editorContext)?.isCurrent != true) {
      return false;
    }

    final focusContext = FocusManager.instance.primaryFocus?.context;
    if (focusContext == null) {
      return true;
    }

    return !_primaryFocusOwnsEditorCommands;
  }

  static bool canHandleTransportShortcut(BuildContext editorContext) {
    if (!canHandleEditorCommand(editorContext)) {
      return false;
    }

    return !primaryFocusOwnsSpace;
  }

  static bool _hasAncestorMatching(
    BuildContext context,
    bool Function(Widget widget) matches,
  ) {
    var found = matches(context.widget);
    (context as Element).visitAncestorElements((element) {
      found = found || matches(element.widget);
      return !found;
    });
    return found;
  }

  static bool get _primaryFocusOwnsEditorCommands {
    final focusContext = FocusManager.instance.primaryFocus?.context;
    return focusContext != null &&
        _hasAncestorMatching(
          focusContext,
          (widget) =>
              widget is EditableText ||
              widget is EditorShortcutScope ||
              widget is ButtonStyleButton ||
              widget is IconButton ||
              widget is PopupMenuButton ||
              widget is DropdownButton ||
              widget is Slider ||
              widget is Checkbox ||
              widget is Radio ||
              widget is Switch,
        );
  }
}

/// Marks an interactive editor popover as owning keyboard input while focused.
class EditorShortcutScope extends StatelessWidget {
  const EditorShortcutScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}
