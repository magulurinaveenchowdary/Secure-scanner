import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:securescan/themes.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Disable Google Fonts network loading to prevent crashes on offline devices
  GoogleFonts.config.allowRuntimeFetching = false;

  await MobileAds.instance.initialize();
  await SecureScanThemeController.instance.init(); // <- add this

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]).then((_) => runApp(const SecureScanApp()));
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