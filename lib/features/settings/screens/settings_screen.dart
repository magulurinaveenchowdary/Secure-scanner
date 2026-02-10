// settings_screen.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:securescan/themes.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String selectedTheme = 'System Mode';
  final List<String> themeModes = ['Light', 'Dark', 'System Mode'];

  static const _primaryBlue = Color(0xFF0A66FF);

  BannerAd? _bannerAd;
  bool _isBannerAdReady = false;

  static const _googleTestBannerAdUnitId =
      'ca-app-pub-3940256099942544/6300978111';
  static const _productionBannerAdUnitId =
      'ca-app-pub-2961863855425096/5968213716';

  String get _adUnitId =>
      kDebugMode ? _googleTestBannerAdUnitId : _productionBannerAdUnitId;

  int _loadAttempts = 0;
  static const int _maxLoadAttempts = 3;

  @override
  void initState() {
    super.initState();

    selectedTheme = SecureScanThemeController.themeModeToString(
      SecureScanThemeController.instance.themeModeNotifier.value,
    );

    SecureScanThemeController.instance.themeModeNotifier.addListener(
      _listenThemeChanges,
    );

    _loadBannerAd();
  }

  void _listenThemeChanges() {
    setState(() {
      selectedTheme = SecureScanThemeController.themeModeToString(
        SecureScanThemeController.instance.themeModeNotifier.value,
      );
    });
  }

  @override
  void dispose() {
    SecureScanThemeController.instance.themeModeNotifier.removeListener(
      _listenThemeChanges,
    );
    _bannerAd?.dispose();
    super.dispose();
  }

  void _loadBannerAd() {
    _bannerAd?.dispose();
    _bannerAd = BannerAd(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      size: AdSize.mediumRectangle,
      listener: BannerAdListener(
        onAdLoaded: (_) => setState(() => _isBannerAdReady = true),
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          _isBannerAdReady = false;
          if (++_loadAttempts <= _maxLoadAttempts) {
            Future.delayed(
              Duration(seconds: 1 << (_loadAttempts - 1)),
              _loadBannerAd,
            );
          }
          setState(() {});
        },
      ),
    )..load();
  }

  Future<void> _changeTheme(String mode) async {
    await SecureScanThemeController.instance.setTheme(mode);
    setState(() => selectedTheme = mode);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Theme set to $mode"),
        backgroundColor: _primaryBlue,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  double _tileHeight(BuildContext context) {
    return (MediaQuery.of(context).size.height * 0.08).clamp(56.0, 90.0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final isDark = theme.brightness == Brightness.dark;
    final tileHeight = _tileHeight(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0.5,
        centerTitle: true,
        title: Text(
          "Settings",
          style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      body: Column(
        children: [
          const SizedBox(height: 10),

          // THEME DROPDOWN TILE
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Container(
              height: tileHeight,
              decoration: _tileDecoration(isDark),
              child: Row(
                children: [
                  _tileIcon(FontAwesomeIcons.circleHalfStroke, isDark),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 16, right: 8),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedTheme,
                          dropdownColor: isDark ? Colors.black : Colors.white,
                          icon: Icon(
                            Icons.arrow_drop_down,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                          style: textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          items: themeModes
                              .map(
                                (mode) => DropdownMenuItem(
                                  value: mode,
                                  child: Text(mode),
                                ),
                              )
                              .toList(),
                          onChanged: (v) => v != null ? _changeTheme(v) : null,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          _buildSettingsTile(
            icon: FontAwesomeIcons.userShield,
            title: "Privacy & Permissions Policy",
            onTap: () => _openUrl('https://nanogear.in/privacy'),
          ),
          _buildSettingsTile(
            icon: FontAwesomeIcons.lock,
            title: "Terms & Conditions",
            onTap: () => _openUrl('https://nanogear.in/terms'),
          ),
          _buildSettingsTile(
            icon: FontAwesomeIcons.circleInfo,
            title: "App Info & Support",
            onTap: () => _openUrl(
                'https://play.google.com/store/apps/details?id=com.securescan.securescan'),
          ),

          const SizedBox(height: 16),

          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              "QR & Barcode Scanner Generator ©️ 2026",
              style: textTheme.bodyMedium?.copyWith(
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
          ),

          // ✅ 50% SPACE FOR AD (RESPONSIVE & SAFE)
          Expanded(
            flex: 5,
            child: _isBannerAdReady && _bannerAd != null
                ? Center(
                    child: SizedBox(
                      width: _bannerAd!.size.width.toDouble(),
                      height: _bannerAd!.size.height.toDouble(),
                      child: _BannerAdWidget(ad: _bannerAd!),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw 'Could not launch $url';
    }
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          height: _tileHeight(context),
          decoration: _tileDecoration(isDark),
          child: Row(
            children: [
              _tileIcon(icon, isDark),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tileIcon(IconData icon, bool isDark) {
    return Container(
      width: 60,
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : const Color(0xFFF4F4F4),
        borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
      ),
      child: Center(child: Icon(icon, color: _primaryBlue, size: 18)),
    );
  }

  BoxDecoration _tileDecoration(bool isDark) {
    return BoxDecoration(
      color: isDark ? Colors.black26 : Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: isDark ? Colors.white24 : const Color(0xFFC0C0C0),
      ),
    );
  }
}

class _BannerAdWidget extends StatefulWidget {
  final BannerAd ad;

  const _BannerAdWidget({required this.ad});

  @override
  State<_BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<_BannerAdWidget> {
  late BannerAd _ad;

  @override
  void initState() {
    super.initState();
    _ad = widget.ad;
  }

  @override
  Widget build(BuildContext context) {
    return AdWidget(ad: _ad);
  }
}