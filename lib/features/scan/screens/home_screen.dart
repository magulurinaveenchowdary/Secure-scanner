import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:securescan/widgets/app_drawer.dart';

import 'package:securescan/features/generate/screens/generator_screen.dart';
import 'package:securescan/features/scan/screens/scan_screen_qr.dart';

import 'package:google_mobile_ads/google_mobile_ads.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();

  static const _primaryBlue = Color(0xFF0A66FF);

  // TODO: Replace with your real Play Store URL
  static const String _playStoreUrl =
      'https://play.google.com/store/apps/details?id=com.securescan.securescan';

  static const String _shareMessage =
      'I am using QR & Barcode Scanner Generator App, the fast and secure QR and Barcode reader. '
      'Try it now! $_playStoreUrl';
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
    _loadBannerAd();
  }

  void _loadBannerAd() {
    // Clean up any existing ad
    _bannerAd?.dispose();
    _bannerAd = BannerAd(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      size: AdSize.banner,
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
    final adHeight = _isBannerAdReady && _bannerAd != null
        ? _bannerAd!.size.height.toDouble()
        : 0.0;

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
          style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 48),
              PrimaryCTA(
                label: 'Scan',
                iconPath: 'assets/icons/misc/scan_qr_icon_white.png',
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
              const SizedBox(height: 24),
              PrimaryCTA(
                label: 'Create QR',
                iconPath: 'assets/icons/misc/create_qr_icon_white.png',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => CreateQRScreen()),
                  );
                },
              ),
              const Spacer(),
              // --- Banner Ad spot: 0 height when not ready, ad widget when ready ---
              SizedBox(
                width: double.infinity,
                height: adHeight,
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
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _divider() =>
      Divider(thickness: 1, color: const Color(0xFF000000).withOpacity(0.1));
}

/// Rounded blue CTA with left icon + centered text
class PrimaryCTA extends StatelessWidget {
  const PrimaryCTA({
    required this.label,
    required this.onTap,
    required this.iconPath,
    super.key,
  });

  final String label;
  final String iconPath;
  final VoidCallback onTap;

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
        width: 187,
        height: 88,
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
              Image.asset(iconPath, width: 28, height: 28, fit: BoxFit.contain),
              const SizedBox(width: 12),
              Text(
                label,
                style: textTheme.labelLarge?.copyWith(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
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

/// Drawer list tile using textTheme and PNG tinting
class _DrawerTile extends StatelessWidget {
  const _DrawerTile({
    required this.title,
    required this.iconPath,
    required this.onTap,
    this.iconTint,
  });

  final String title;
  final String iconPath;
  final VoidCallback onTap;
  final Color? iconTint;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      leading: Image.asset(iconPath, width: 20, height: 20, color: iconTint),
      title: Text(
        title,
        style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      onTap: onTap,
      horizontalTitleGap: 16,
      minLeadingWidth: 28,
    );
  }
}
