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

/// Focus and route rules shared by editor-level keyboard commands.
abstract final class EditorShortcutPolicy {
  static bool get primaryFocusOwnsSpace {
    final focusContext = FocusManager.instance.primaryFocus?.context;
    if (focusContext == null) {
      return false;
    }

    return _hasAncestorMatching(
      focusContext,
      (widget) =>
          widget is EditableText ||
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

    return !_hasAncestorMatching(
      focusContext,
      (widget) => widget is EditableText,
    );
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
}
