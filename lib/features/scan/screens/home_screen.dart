import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:securescan/widgets/app_drawer.dart';

import 'package:securescan/features/generate/screens/generator_screen.dart';
import 'package:securescan/features/scan/screens/scan_screen_qr.dart';

import 'package:google_mobile_ads/google_mobile_ads.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  BannerAd? _bannerAd;
  bool _isBannerAdReady = false;

  // Use Google's test banner id in debug. Replace with your real id for release.
  static const String _googleTestBannerAdUnitId =
      'ca-app-pub-3940256099942544/6300978111';

  // Replace with your real production ad unit id (kept here for clarity)
  static const String _productionBannerAdUnitId =
      'ca-app-pub-2961863855425096/5968213716';

  // Retry logic
  int _loadAttempts = 0;
  static const int _maxLoadAttempts = 3;

  String get _adUnitId =>
      kDebugMode ? _googleTestBannerAdUnitId : _productionBannerAdUnitId;

  @override
  void initState() {
    super.initState();

    // Log screen view to Firebase Analytics
    FirebaseAnalytics.instance.logScreenView(screenName: 'HomeScreen');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Load ad once we have context/MediaQuery available
    if (!_isBannerAdReady && _bannerAd == null) {
      _loadBannerAd();
    }
  }

  void _loadBannerAd() {
    // Calculate 50% height based on available space
    final mediaQuery = MediaQuery.of(context);
    final double fullH = mediaQuery.size.height;
    final double safeTop = mediaQuery.padding.top;
    final double safeBottom = mediaQuery.padding.bottom;
    final double appBarH = kToolbarHeight;
    final double totalH = fullH - safeTop - safeBottom - appBarH;

    final int adH = (totalH * 0.50).toInt();
    final int adW = (mediaQuery.size.width - 48).toInt(); // horizontal padding 24*2

    // Clean up any existing ad
    _bannerAd?.dispose();
    _bannerAd = BannerAd(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      size: AdSize(width: adW, height: adH),
      listener: BannerAdListener(
        onAdLoaded: (Ad ad) {
          debugPrint('[Ads] Banner loaded.');
          setState(() {
            _isBannerAdReady = true;
            _loadAttempts = 0;
          });
        },
        onAdFailedToLoad: (Ad ad, LoadAdError error) {
          ad.dispose();
          _isBannerAdReady = false;
          _loadAttempts += 1;
          debugPrint(
            '[Ads] Banner failed to load: $error (attempt $_loadAttempts)',
          );
          if (_loadAttempts <= _maxLoadAttempts) {
            // Exponential backoff retry
            final delaySeconds = 1 << (_loadAttempts - 1); // 1,2,4
            debugPrint('[Ads] Retrying banner load in $delaySeconds s...');
            Timer(Duration(seconds: delaySeconds), _loadBannerAd);
          } else {
            debugPrint('[Ads] Reached max load attempts. Giving up for now.');
          }
          setState(() {}); // ensure UI hides the ad space
        },
        onAdOpened: (Ad ad) => debugPrint('[Ads] Banner opened.'),
        onAdClosed: (Ad ad) => debugPrint('[Ads] Banner closed.'),
        onAdImpression: (Ad ad) => debugPrint('[Ads] Banner impression.'),
      ),
    );

    _bannerAd!.load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    // If banner not ready, we return a zero-height widget — nothing visible.
    // (Logic moved inside LayoutBuilder)

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      drawer: const AppDrawer(),
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        centerTitle: true,
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(Icons.menu, color: colorScheme.onSurface),
            onPressed: () => Scaffold.of(context).openDrawer(),
            splashRadius: 24,
          ),
        ),
        title: Text(
          'QR & Barcode Scanner Generator',
          style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(flex: 2), // ~2% top spacing
              Expanded(
                flex: 20, // 20% height
                child: PrimaryCTA(
                  label: 'Scan',
                  iconPath: 'assets/icons/misc/scan_qr_icon_white.png',
                  width: double.infinity,
                  // height is controlled by Expanded -> tight constraint
                  onTap: () {
                    if (ModalRoute.of(context)?.settings.name == "ScanScreenQR") {
                      return;
                    }

                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        settings: const RouteSettings(name: "ScanScreenQR"),
                        builder: (_) => ScanScreenQR(),
                      ),
                    );
                  },
                ),
              ),
              const Spacer(flex: 2), // ~2% gap
              Expanded(
                flex: 20, // 20% height
                child: PrimaryCTA(
                  label: 'Create QR',
                  iconPath: 'assets/icons/misc/create_qr_icon_white.png',
                  width: double.infinity,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => CreateQRScreen()),
                    );
                  },
                ),
              ),
              const Spacer(flex: 4), // ~4% gap
              // --- Banner Ad spot: Occupies 50% height ---
              Expanded(
                flex: 50, // 50% height
                child: _isBannerAdReady && _bannerAd != null
                    ? Center(
                        child: SizedBox(
                          width: _bannerAd!.size.width.toDouble(),
                          height: _bannerAd!.size.height.toDouble(),
                          child: AdWidget(ad: _bannerAd!),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              const Spacer(flex: 2), // ~2% bottom spacing
            ],
          ),
        ),
      ),
    );
  }
}

/// Rounded blue CTA with left icon + centered text
class PrimaryCTA extends StatelessWidget {
  const PrimaryCTA({
    required this.label,
    required this.onTap,
    required this.iconPath,
    this.width,
    this.height,
    super.key,
  });

  final String label;
  final String iconPath;
  final VoidCallback onTap;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 28,
            spreadRadius: 2,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: SizedBox(
        width: width ?? 187,
        height: height ?? 88,
        child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            elevation: 0,
            backgroundColor: const Color(0xFF0A66FF),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(iconPath, width: 38, height: 38, fit: BoxFit.contain),
              const SizedBox(width: 12),
              Text(
                label,
                style: textTheme.labelLarge?.copyWith(
                  fontSize: 29,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.2,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
