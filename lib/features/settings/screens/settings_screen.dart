// settings_screen.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:securescan/widgets/app_drawer.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:securescan/themes.dart'; // <-- NEW: Theme Controller

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String selectedTheme = 'System Mode';
  final List<String> themeModes = ['Light', 'Dark', 'System Mode'];

  static const _primaryBlue = Color(0xFF0A66FF);

  // ---- Banner Ad fields ----
  BannerAd? _bannerAd;
  bool _isBannerAdReady = false;

  static const String _googleTestBannerAdUnitId =
      'ca-app-pub-3940256099942544/6300978111';

  static const String _productionBannerAdUnitId =
      'ca-app-pub-2961863855425096/5968213716';

  String get _adUnitId =>
      kDebugMode ? _googleTestBannerAdUnitId : _productionBannerAdUnitId;

  int _loadAttempts = 0;
  static const int _maxLoadAttempts = 3;

  @override
  void initState() {
    super.initState();

    // Sync selected theme with saved setting
    selectedTheme = SecureScanThemeController
        .themeModeToString(SecureScanThemeController.instance.themeModeNotifier.value);

    SecureScanThemeController.instance.themeModeNotifier
        .addListener(_listenThemeChanges);

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
    SecureScanThemeController.instance.themeModeNotifier
        .removeListener(_listenThemeChanges);

    _bannerAd?.dispose();
    super.dispose();
  }

  // ---- Banner loader with retries ----
  void _loadBannerAd() {
    _bannerAd?.dispose();
    _bannerAd = BannerAd(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (_) {
          setState(() {
            _isBannerAdReady = true;
            _loadAttempts = 0;
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          _isBannerAdReady = false;
          _loadAttempts += 1;

          if (_loadAttempts <= _maxLoadAttempts) {
            final delay = Duration(seconds: 1 << (_loadAttempts - 1)); // 1,2,4 sec
            Future.delayed(delay, _loadBannerAd);
          }
          setState(() {});
        },
      ),
    );
    _bannerAd!.load();
  }

  // ---- Save Theme ----
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final isDark = theme.brightness == Brightness.dark;

    final adHeight = _isBannerAdReady && _bannerAd != null
        ? _bannerAd!.size.height.toDouble()
        : 0.0;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0.5,
        automaticallyImplyLeading: false,
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
              height: 68,
              decoration: BoxDecoration(
                color: isDark ? Colors.black26 : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? Colors.white24 : const Color(0xFFC0C0C0),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : const Color(0xFFF4F4F4),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        bottomLeft: Radius.circular(12),
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        FontAwesomeIcons.circleHalfStroke,
                        color: Color(0xFF006EFF),
                        size: 18,
                      ),
                    ),
                  ),

                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 16, right: 8),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedTheme,
                          icon: Icon(Icons.arrow_drop_down,
                              color: isDark ? Colors.white : Colors.black),
                          dropdownColor: isDark ? Colors.black : Colors.white,
                          style: textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          items: themeModes.map((String mode) {
                            return DropdownMenuItem<String>(
                              value: mode,
                              child: Text(mode),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) _changeTheme(value);
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // OTHER SETTINGS
          _buildSettingsTile(
            icon: FontAwesomeIcons.userShield,
            title: "Privacy & Permissions Policy",
            onTap: () {},
          ),
          _buildSettingsTile(
            icon: FontAwesomeIcons.lock,
            title: "Security",
            onTap: () {},
          ),
          _buildSettingsTile(
            icon: FontAwesomeIcons.circleInfo,
            title: "App Info & Support",
            onTap: () {},
          ),

          const Spacer(),

          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: "QR & Barcode Scanner Generator ",
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                  TextSpan(
                    text: "©️ 2025",
                    style: textTheme.bodyMedium?.copyWith(
                      color: isDark ? Colors.white38 : Colors.black45,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // BANNER AD
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
        ],
      ),
    );
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
          height: 68,
          decoration: BoxDecoration(
            color: isDark ? Colors.black26 : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? Colors.white24 : const Color(0xFFC0C0C0),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 60,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : const Color(0xFFF4F4F4),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                  ),
                ),
                child: Center(
                  child: Icon(icon, color: const Color(0xFF006EFF), size: 18),
                ),
              ),
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
}