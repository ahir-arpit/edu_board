import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Safe Firebase Initialization
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint("Firebase Initialized Successfully.");
  } catch (e) {
    debugPrint("Firebase initialization failed/skipped (missing config files). Using offline local simulation services.");
    debugPrint("Error details: $e");
  }

  runApp(
    const ProviderScope(
      child: SmartBoardApp(),
    ),
  );
}
