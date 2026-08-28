import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'project_autosave.dart';
import 'project_autosave_store_stub.dart'
    if (dart.library.js_interop) 'project_autosave_store_web.dart';

export 'project_autosave.dart';

final projectAutosaveStoreProvider = Provider<ProjectAutosaveStore>(
  (ref) => createProjectAutosaveStore(),
);
