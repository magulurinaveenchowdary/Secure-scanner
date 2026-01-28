import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'firebase_options.dart';
import 'package:securescan/features/scan/screens/scan_screen_qr.dart';
import 'package:securescan/themes.dart';
import 'package:securescan/services/call_manager.dart';
import 'package:securescan/widgets/call_overlay_widget.dart'; // Import CallOverlayWidget

import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Send Flutter errors to Crashlytics
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

  // Catch async errors
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  // Disable Google Fonts network loading to prevent crashes on offline devices
  GoogleFonts.config.allowRuntimeFetching = false;

  await MobileAds.instance.initialize();
  await SecureScanThemeController.instance.init();
  await CallManager().init(); // <- Initialize CallManager

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]).then((_) => runApp(RestartWidget(child: const SecureScanApp())));
}

// AdMOB UNIT IDS

// BANNER AD 1

// ca-app-pub-4377808055186677~4699164078
// ca-app-pub-4377808055186677/6096672505

// BANNER AD 2
// ca-app-pub-4377808055186677~4699164078
// ca-app-pub-4377808055186677/5086843165

// INTERSTITIAL ADS

// interstitialAd1

// ca-app-pub-4377808055186677~4699164078
// ca-app-pub-4377808055186677/1969725234

// Overlay Entry Point
@pragma("vm:entry-point")
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  MobileAds.instance.initialize(); // Initialize Ads for overlay process
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: CallOverlayWidget(),
    ),
  );
}
