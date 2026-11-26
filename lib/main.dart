import 'dart:async';

import 'package:flutter/material.dart';

import 'app.dart';
import 'core/services/call_log_service.dart';
import 'core/services/call_notes_service.dart';
import 'core/services/contacts_service.dart';
import 'core/services/warm_call_log_store.dart';
import 'core/services/warm_contacts_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Independent cache reads: run together, a ringing call may be waiting for the first frame.
  await Future.wait<void>(<Future<void>>[
    CallNotesService.init(),
    CallLogService.loadWarmSnapshot(WarmCallLogStore.read),
    ContactsService.loadWarmSnapshot(WarmContactsStore.read),
  ]);

  runApp(const MyApp());

  // Names now; photos (a thumbnail per contact) once the first frames are out.
  unawaited(
    ContactsService.warmCache(withPhoto: false).then((_) {
      return Future<void>.delayed(
        const Duration(seconds: 3),
        () => ContactsService.warmCache(withPhoto: true),
      );
    }),
  );
}
