import 'dart:ui';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:securescan/widgets/bottom_nav_shell.dart';
import 'package:securescan/themes.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AppEntry extends StatelessWidget {
  const AppEntry({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'QR & Barcode Scanner Generator',
      theme: SecureScanTheme.lightTheme,
      darkTheme: SecureScanTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const OnboardingScreen(),
    );
  }
}

/// ------------------------------
/// Onboarding Section
/// ------------------------------

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, String>> onboardingData = [
    {
      'title': 'Quick scan QR & Barcodes',
      'subtitle': 'Quick scan any QR codes /barcodes and get results instantly',
      'image': 'assets/1.png', // Phone scanning QR (e.g. product)
    },
    {
      'title': 'Get product information',
      'subtitle':
      'Scan product barcode to get product information and other products information',
      'image': 'assets/2.png', // QR + blue shield/checkmark
    },
    {
      'title': 'Create Multiple QR codes',
      'subtitle':
      'A powerful generator meets all your needs for creating QR codes',
      'image': 'assets/3.png', // Phone + share icons
    },
  ];


  // ---------------- Banner ad fields ----------------
  BannerAd? _bannerAd;
  bool _isBannerAdReady = false;
  int _loadAttempts = 0;
  static const int _maxLoadAttempts = 3;

  // Google's test banner id for development
  static const String _googleTestBannerAdUnitId =
      'ca-app-pub-3940256099942544/6300978111';

  // Replace with your production ad unit id
  static const String _productionBannerAdUnitId =
      'ca-app-pub-2961863855425096/5968213716';

  String get _adUnitId => kDebugMode ? _googleTestBannerAdUnitId : _productionBannerAdUnitId;

  @override
  void initState() {
    super.initState();
    _loadBannerAd();
  }

  void _loadBannerAd() {
    _bannerAd?.dispose();
    _bannerAd = BannerAd(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          setState(() {
            _isBannerAdReady = true;
            _loadAttempts = 0;
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          _isBannerAdReady = false;
          _loadAttempts += 1;
          debugPrint('[Onboarding] Banner failed to load: $error (attempt $_loadAttempts)');
          if (_loadAttempts <= _maxLoadAttempts) {
            final delaySeconds = 1 << (_loadAttempts - 1); // 1,2,4
            Future.delayed(Duration(seconds: delaySeconds), _loadBannerAd);
          } else {
            debugPrint('[Onboarding] Banner: giving up after $_loadAttempts attempts.');
          }
          setState(() {});
        },
      ),
    );

    _bannerAd!.load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < onboardingData.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => BottomNavShell()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final isDark = theme.brightness == Brightness.dark;

    // Ad height (0 if not ready)
    final adHeight = _isBannerAdReady && _bannerAd != null
        ? _bannerAd!.size.height.toDouble()
        : 0.0;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            // MAIN ONBOARDING CONTENT
            Column(
              children: [
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (value) {
                      setState(() => _currentPage = value);
                    },
                    itemCount: onboardingData.length,
                    itemBuilder: (context, index) {
                      final data = onboardingData[index];
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment:
                        CrossAxisAlignment.start, // Ensures left alignment
                        children: [
                          // Graphic Placeholder (illustration)
                          Container(
                            width: double.infinity,
                            height: 450,
                            decoration: BoxDecoration(
                              image: DecorationImage(
                                image: Image.asset(data['image']!).image,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),

                          // Apply left padding ONLY to text section
                          Padding(
                            padding: const EdgeInsets.only(left: 20.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  data['title']!,
                                  style: const TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF000000),
                                  ),
                                ),
                                const SizedBox(height: 14),

                                Text(
                                  data['subtitle']!,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    color: Colors.black54,
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );

                    },
                  ),
                ),

                // leave space equal to bottom banner + adHeight so content won't be hidden
                SizedBox(height: 120 + adHeight),
              ],
            ),

            // 🔵 Bottom Banner + Controls — positioned ABOVE the ad
            Positioned(
              left: 0,
              right: 0,
              bottom: adHeight, // sits above the ad
              child: Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1A1A1A)
                      : const Color(0xFF006EFF),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                padding:
                const EdgeInsets.symmetric(horizontal: 30.0, vertical: 22),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Page Indicator Dots
                    Row(
                      children: List.generate(
                        onboardingData.length,
                            (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 5),
                          width: _currentPage == index ? 18 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(
                                _currentPage == index ? 1 : 0.5),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),

                    // Next / Get Started Button
                    InkWell(
                      onTap: _nextPage,
                      borderRadius: BorderRadius.circular(50),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Row(
                          children: [
                            Text(
                              _currentPage == onboardingData.length - 1
                                  ? "Get Started"
                                  : "Next",
                              style: textTheme.labelLarge?.copyWith(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: SecureScanTheme.accentBlue,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.arrow_forward_rounded,
                              color: SecureScanTheme.accentBlue,
                              size: 22,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ---------- Banner Ad spot: shows nothing until ad is ready ----------
            if (adHeight > 0 && _bannerAd != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SizedBox(
                  width: double.infinity,
                  height: adHeight,
                  child: Center(
                    child: SizedBox(
                      width: _bannerAd!.size.width.toDouble(),
                      height: _bannerAd!.size.height.toDouble(),
                      child: AdWidget(ad: _bannerAd!),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}