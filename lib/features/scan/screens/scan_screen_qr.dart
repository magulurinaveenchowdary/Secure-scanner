// lib/features/scan/screens/scan_screen_qr.dart
// Auto-detect QR & barcodes, navigate to QrResultScreen on hit,
// supports zoom slider, pinch-to-zoom, "scan from gallery", drawer,
// and captures the scanned frame.
//
// UPDATED: when a barcode is classified as a product, attempt to fetch
// product metadata (brand/product_name) using a chain of product
// lookup services so coverage includes not only foods but general
// retail products (e.g. notebooks like "Classmate").
//
// NOTES:
// - You should provide a BARCODE_LOOKUP_API_KEY (optional) for best
//   coverage. If not provided, the code falls back to OpenProductFacts
//   (community data) and then OpenFoodFacts as a last resort.
// - Replace placeholder keys with your real keys if you have them.
// - For quick local debugging there's a sample image path (included by
//   developer): /mnt/data/WhatsApp Image 2025-11-23 at 22.00.17.jpeg
//   (this path is included purely as a reference for local testing).

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:native_device_orientation/native_device_orientation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'package:securescan/features/scan/screens/qr_result_screen.dart';
import 'package:securescan/widgets/app_drawer.dart';
import 'package:securescan/widgets/restart_widget.dart';
import 'package:securescan/app.dart';

class ScanScreenQR extends StatefulWidget {
  const ScanScreenQR({Key? key}) : super(key: key);

  @override
  State<ScanScreenQR> createState() => _ScanScreenQRState();
}

// -------------------- Result model for navigation --------------------

class QrResultData {
  final String raw;
  final String? format; // e.g., "qrCode", "ean13"
  final String kind; // "url", "phone", "product", "text", "wifi", "vcard", etc.
  final Map<String, dynamic>? data;
  final Uint8List? imageBytes; // captured frame
  final DateTime timestamp;

  const QrResultData({
    required this.raw,
    required this.kind,
    this.format,
    this.data,
    this.imageBytes,
    required this.timestamp,
  });
}

// -------------------- Internal classification --------------------

enum _PayloadKind {
  url,
  phone,
  email,
  wifi,
  vcard,
  calendar,
  geo,
  json,
  text,
  product,
}

class _Payload {
  final _PayloadKind kind;
  final String raw;
  final Map<String, dynamic>? data;
  final String? symbology;
  final DateTime ts;

  _Payload(this.kind, this.raw, {this.data, this.symbology, DateTime? ts})
    : ts = ts ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'kind': kind.name,
    'raw': raw,
    'data': data,
    'symbology': symbology,
    'ts': ts.toIso8601String(),
  };
}

// -------------------- Screen --------------------

class _ScanScreenQRState extends State<ScanScreenQR>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const Color _brandBlue = Color(0xFF0A66FF);
  static const _prefsKey = 'scan_history';
  static const _historyCap = 200;

  /// Safe Browsing API key (optional)
  String kSafeBrowsingApiKey = '';

  // Product lookup API keys / configs (set these to your keys if you have them)
  // Best coverage: BarcodeLookup (https://www.barcodelookup.com/) — requires API key
  // Fallback: OpenProductFacts / OpenFoodFacts (community datasets)
  static const String BARCODE_LOOKUP_API_KEY =
      ''; // <-- set your key here (optional)
  static const Duration _productLookupTimeout = Duration(seconds: 6);

  // Torch + zoom state
  bool _torchOn = false;
  double _zoom = 1.0; // 1x .. ~4x
  double _baseZoomOnScaleStart = 1.0;

  // Scanner controller
  final MobileScannerController _cameraController = MobileScannerController(
    facing: CameraFacing.back,
    detectionSpeed: DetectionSpeed.unrestricted,
    detectionTimeoutMs: 100,
    returnImage: true,
    autoStart: true,
  );

  final ImagePicker _picker = ImagePicker();

  // Scan state
  String? _lastScanned;
  bool _isProcessing = false;
  Map<String, dynamic>? _parsedJson;
  Uint8List? _lastImageBytes;
  Timer? _scanTimeoutTimer;

  // Sweep animation
  late final AnimationController _sweepController;
  late final Animation<double> _sweep;

  // --------- Interstitial Ad Fields ----------
  InterstitialAd? _interstitialAd;
  bool _isInterstitialReady = false;
  int _interstitialLoadAttempts = 0;
  static const int _maxInterstitialLoadAttempts = 3;

  // Test interstitial provided by Google
  static const String _googleTestInterstitialAdUnitId =
      'ca-app-pub-3940256099942544/1033173712';

  // Replace with your production interstitial unit id for release
  static const String _productionInterstitialAdUnitId =
      'ca-app-pub-2961863855425096/8982046403';

  String get _interstitialAdUnitId => kDebugMode
      ? _googleTestInterstitialAdUnitId
      : _productionInterstitialAdUnitId;             

  // --------- Banner Ad Fields ----------
  BannerAd? _bannerAd;
  bool _isBannerAdReady = false;
  int _bannerLoadAttempts = 0;
  static const int _maxBannerLoadAttempts = 3;

  // Test banner provided by Google
  static const String _googleTestBannerAdUnitId =
      'ca-app-pub-3940256099942544/6300978111';

  // Replace with your production banner id
  static const String _productionBannerAdUnitId =
      'ca-app-pub-2961863855425096/5968213716';

  String get _bannerAdUnitId =>
      kDebugMode ? _googleTestBannerAdUnitId : _productionBannerAdUnitId;

  @override
  void initState() {
    super.initState();

    // Log screen view to Firebase Analytics
    FirebaseAnalytics.instance.logScreenView(screenName: 'ScanScreenQR');

    // Lock to portrait while scanning
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _scanTimeoutTimer = Timer(const Duration(seconds: 12), () async {
      if (!mounted || _isProcessing) return;

      final prefs = await SharedPreferences.getInstance();
      final hasAnyData = prefs.getKeys().isEmpty;

      if (hasAnyData) {
        _showScanFailureDialog();
      }
    });
    _sweepController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _sweep = CurvedAnimation(parent: _sweepController, curve: Curves.easeInOut);

    // load ads
    _loadInterstitial();
    _loadBannerAd();

    // Start camera (autoStart handles initial start, but this ensures it's running)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        if (!_cameraController.value.isInitialized) {
          await _cameraController.start();
        }
        _checkAndShowFocusToast();
      } catch (e) {
        debugPrint('Camera start failed: $e');
      }
    });

    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (!_cameraController.value.isInitialized) return;

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        _cameraController.stop();
        break;
      case AppLifecycleState.resumed:
        _cameraController.start();
        break;
      case AppLifecycleState.inactive:
        // Keep camera running on inactive (e.g. notification shade) to avoid black screen
        break;
    }
  }

  Future<void> _checkAndShowFocusToast() async {
    final prefs = await SharedPreferences.getInstance();
    final hasShown = prefs.getBool('first_scan_toast_shown') ?? false;
    if (!hasShown) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Camera lens not focusing. Please restart the app"),
          duration: const Duration(seconds: 4),
          backgroundColor: Colors.redAccent,
          action: SnackBarAction(
            label: 'OK',
            textColor: Colors.white,
            onPressed: () {},
          ),
        ),
      );
      await prefs.setBool('first_scan_toast_shown', true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sweepController.dispose();
    _cameraController.dispose();

    _interstitialAd?.dispose();
    _bannerAd?.dispose();
    _scanTimeoutTimer?.cancel();

    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

    super.dispose();
  }

  // -------------------- Interstitial handling --------------------

  void _loadInterstitial() {
    // dispose previous if any
    _interstitialAd?.dispose();
    _interstitialAd = null;
    _isInterstitialReady = false;

    InterstitialAd.load(
      adUnitId: _interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) {
          _interstitialLoadAttempts = 0;
          _interstitialAd = ad;
          _isInterstitialReady = true;

          // set full screen content callbacks
          _interstitialAd!.fullScreenContentCallback =
              FullScreenContentCallback(
                onAdShowedFullScreenContent: (ad) =>
                    debugPrint('[Ads] Interstitial shown.'),
                onAdDismissedFullScreenContent: (ad) {
                  debugPrint('[Ads] Interstitial dismissed.');
                  // dispose and preload next
                  ad.dispose();
                  _interstitialAd = null;
                  _isInterstitialReady = false;
                  _loadInterstitial();
                },
                onAdFailedToShowFullScreenContent: (ad, error) {
                  debugPrint('[Ads] Interstitial failed to show: $error');
                  ad.dispose();
                  _interstitialAd = null;
                  _isInterstitialReady = false;
                  _loadInterstitial();
                },
              );

          debugPrint('[Ads] Interstitial loaded.');
        },
        onAdFailedToLoad: (LoadAdError error) {
          _interstitialLoadAttempts += 1;
          _isInterstitialReady = false;
          debugPrint(
            '[Ads] Interstitial failed to load: $error (attempt $_interstitialLoadAttempts)',
          );
          if (_interstitialLoadAttempts <= _maxInterstitialLoadAttempts) {
            final backoff = Duration(
              seconds: 1 << (_interstitialLoadAttempts - 1),
            );
            Future.delayed(backoff, _loadInterstitial);
          } else {
            debugPrint(
              '[Ads] Interstitial: giving up after $_interstitialLoadAttempts attempts.',
            );
          }
        },
      ),
    );
  }

  void _showScanFailureDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Camera issue',
            style: TextStyle(color: Colors.black),
          ),
          content: const Text(
            'Camera is unable to scan.\n\n'
            'Please restart the app to continue scanning.',
            style: TextStyle(color: Colors.black87),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (context)=>SecureScanApp()));
              },
              child:  Text('Restart app',style:TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showInterstitialThenNavigate(QrResultData result) async {
    // Log scan event to Firebase Analytics
    FirebaseAnalytics.instance.logEvent(
      name: 'scan_success',
      parameters: {'type': result.kind, 'format': result.format ?? 'unknown'},
    );

    if (_isInterstitialReady && _interstitialAd != null) {
      try {
        _interstitialAd!.show();

        // Wait for dismissal (poll for _isInterstitialReady becoming false and ad being null)
        final completer = Completer<void>();
        final timeout = Timer(const Duration(seconds: 10), () {
          if (!completer.isCompleted) completer.complete();
        });

        Timer.periodic(const Duration(milliseconds: 300), (timer) {
          if (!mounted) {
            if (!completer.isCompleted) completer.complete();
            timer.cancel();
            return;
          }
          if (!_isInterstitialReady && _interstitialAd == null) {
            if (!completer.isCompleted) completer.complete();
            timer.cancel();
          }
        });

        await completer.future;
        timeout.cancel();

        if (!mounted) return;
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => QrResultScreen(result: result)),
        );
      } catch (e) {
        debugPrint(
          '[Ads] Error showing interstitial: $e — navigating immediately.',
        );
        if (!mounted) return;
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => QrResultScreen(result: result)),
        );
      }
    } else {
      // No interstitial ready — fall back to immediate navigation
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => QrResultScreen(result: result)),
      );
    }
  }

  // -------------------- Banner handling --------------------

  void _loadBannerAd() {
    _bannerAd?.dispose();
    _bannerAd = BannerAd(
      adUnitId: _bannerAdUnitId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (Ad ad) {
          setState(() {
            _isBannerAdReady = true;
            _bannerLoadAttempts = 0;
          });
          debugPrint('[Ads] Banner loaded.');
        },
        onAdFailedToLoad: (Ad ad, LoadAdError error) {
          ad.dispose();
          _isBannerAdReady = false;
          _bannerLoadAttempts += 1;
          debugPrint(
            '[Ads] Banner failed to load: $error (attempt $_bannerLoadAttempts)',
          );
          if (_bannerLoadAttempts <= _maxBannerLoadAttempts) {
            final delaySeconds = 1 << (_bannerLoadAttempts - 1);
            Future.delayed(Duration(seconds: delaySeconds), _loadBannerAd);
          }
        },
      ),
    );

    _bannerAd!.load();
  }

  // -------------------- Detect & handle --------------------

  void _onDetect(BarcodeCapture capture) async {
    _scanTimeoutTimer?.cancel();

    if (_isProcessing || capture.barcodes.isEmpty) return;
    _isProcessing = true;

    final picked = capture.barcodes.first;
    final imageBytes = capture.image;

    if (!mounted) return;

    // Proceed immediately with normal flow
    await _handleBarcode(picked, imageBytes);
  }

  void _applyZoom() {
    // _zoom is UI value in range [1.0, 4.0]
    final normalized = ((_zoom - 1.0) / 3.0).clamp(0.0, 1.0);
    _cameraController.setZoomScale(normalized);
  }

  /// Try multiple product lookup services (in order) to maximize chance of finding
  /// general retail product metadata (brand / product_name) for the scanned code.
  ///
  /// The function will:
  ///  1) Query BarcodeLookup (if BARCODE_LOOKUP_API_KEY is set) — good commercial coverage
  ///  2) Query OpenProductFacts (community product registry) — broad non-food coverage in some regions
  ///  3) Query OpenFoodFacts as a final fallback (mostly food items but useful sometimes)
  ///
  /// Returns a map with keys like {'brand': 'BrandName', 'product_name': 'Name'} if found,
  /// otherwise returns null.
  Future<Map<String, dynamic>?> _fetchProductInfo(String code) async {
    // normalize code
    final normalizedCode = code.trim();

    // 1) BarcodeLookup (commercial) — best coverage for general retail products.
    if (BARCODE_LOOKUP_API_KEY.isNotEmpty) {
      try {
        final uri = Uri.https('api.barcodelookup.com', '/v3/products', {
          'barcode': normalizedCode,
          'key': BARCODE_LOOKUP_API_KEY,
        });
        final resp = await http.get(uri).timeout(_productLookupTimeout);
        if (resp.statusCode == 200) {
          final map = jsonDecode(resp.body) as Map<String, dynamic>;
          if (map['products'] != null && (map['products'] as List).isNotEmpty) {
            final p = (map['products'] as List).first as Map<String, dynamic>;
            final brand = (p['brand'] as String?)?.trim();
            final title = (p['title'] as String?)?.trim();
            final manufacturer = (p['manufacturer'] as String?)?.trim();
            final out = <String, dynamic>{};
            if (brand != null && brand.isNotEmpty) out['brand'] = brand;
            if (title != null && title.isNotEmpty) out['product_name'] = title;
            if (manufacturer != null &&
                manufacturer.isNotEmpty &&
                out['brand'] == null) {
              out['brand'] = manufacturer;
            }
            if (out.isNotEmpty) return out;
          }
        }
      } catch (e) {
        debugPrint('[ProductLookup] BarcodeLookup failed: $e');
      }
    }

    // 2) OpenProductFacts (community dataset for generic products)
    //    (Note: endpoint and dataset coverage can vary by country)
    try {
      final uri = Uri.https(
        'world.openproductfacts.org',
        '/api/v0/product/$normalizedCode.json',
      );
      final resp = await http.get(uri).timeout(_productLookupTimeout);
      if (resp.statusCode == 200) {
        final map = jsonDecode(resp.body) as Map<String, dynamic>;
        if (map['status'] == 1 && map['product'] != null) {
          final product = map['product'] as Map<String, dynamic>;
          final brandCandidates = <String>[];
          if (product['brands'] is String &&
              (product['brands'] as String).trim().isNotEmpty) {
            brandCandidates.add((product['brands'] as String).trim());
          }
          if (product['brand'] is String &&
              (product['brand'] as String).trim().isNotEmpty) {
            brandCandidates.add((product['brand'] as String).trim());
          }
          final name = (product['product_name'] as String?)?.trim();
          final out = <String, dynamic>{};
          if (brandCandidates.isNotEmpty) out['brand'] = brandCandidates.first;
          if (name != null && name.isNotEmpty) out['product_name'] = name;
          if (out.isNotEmpty) return out;
        }
      }
    } catch (e) {
      debugPrint('[ProductLookup] OpenProductFacts failed: $e');
    }

    // 3) OpenFoodFacts fallback
    try {
      final uri = Uri.https(
        'world.openfoodfacts.org',
        '/api/v0/product/$normalizedCode.json',
      );
      final resp = await http.get(uri).timeout(_productLookupTimeout);
      if (resp.statusCode == 200) {
        final map = jsonDecode(resp.body) as Map<String, dynamic>;
        if (map['status'] == 1 && map['product'] != null) {
          final product = map['product'] as Map<String, dynamic>;
          final brands = (product['brands'] as String?)?.trim();
          final productName = (product['product_name'] as String?)?.trim();
          final out = <String, dynamic>{};
          if (brands != null && brands.isNotEmpty) out['brand'] = brands;
          if (productName != null && productName.isNotEmpty)
            out['product_name'] = productName;
          if (out.isNotEmpty) return out;
        }
      }
    } catch (e) {
      debugPrint('[ProductLookup] OpenFoodFacts failed: $e');
    }

    // No useful info found
    return null;
  }

  Future<void> _handleBarcode(Barcode barcode, Uint8List? imageBytes) async {
    final raw = barcode.rawValue;
    if (raw == null) return;

    if (raw == _lastScanned) return;

    setState(() {
      _lastScanned = raw;
      _parsedJson = null;
      _lastImageBytes = imageBytes;
    });

    // Try parsing JSON (for QR payloads)
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        _parsedJson = decoded;
      }
    } catch (_) {
      _parsedJson = null;
    }

    // We don't stop the camera here anymore to avoid black frames.
    // Instead, _isProcessing guard at the top of _onDetect handles it.
    // await _cameraController.stop();

    // Classify payload
    final payload = _classifyPayload(raw, symbology: barcode.format.name);

    // Save to history
    await _saveScan(payload);

    // If it's a product barcode, attempt to fetch brand/product info
    Map<String, dynamic>? mergedData;
    if (payload.data != null)
      mergedData = Map<String, dynamic>.from(payload.data!);
    mergedData ??= {};

    if (payload.kind == _PayloadKind.product) {
      final codeCandidate = mergedData['code']?.toString() ?? payload.raw;
      final timer = Stopwatch()..start();
      try {
        final productInfo = await _fetchProductInfo(codeCandidate);
        if (productInfo != null) {
          mergedData.addAll(productInfo);
        }
      } catch (e) {
        debugPrint('[ProductLookup] error: $e');
      } finally {
        timer.stop();
        debugPrint(
          '[ProductLookup] lookup took ${timer.elapsedMilliseconds}ms for $codeCandidate',
        );
      }
    }

    setState(() => _isProcessing = false);

    // Prepare result - include brand/product_name if available in data
    final result = QrResultData(
      raw: payload.raw,
      kind: payload.kind.name,
      format: payload.symbology,
      data: mergedData.isNotEmpty ? mergedData : null,
      imageBytes: _lastImageBytes,
      timestamp: payload.ts,
    );

    // --- show interstitial (if ready) and then navigate ---
    await _showInterstitialThenNavigate(result);
  }

  // Scan from gallery
  Future<void> _scanFromGallery() async {
    if (_isProcessing) return;

    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    setState(() => _isProcessing = true);

    try {
      final capture = await _cameraController.analyzeImage(picked.path);

      if (capture == null || capture.barcodes.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No code found in this image')),
          );
        }
        setState(() => _isProcessing = false);
        return;
      }

      // Use frame image from capture if present, otherwise fallback to file bytes
      Uint8List? frameBytes = capture.image;
      frameBytes ??= await picked.readAsBytes();

      final barcode = capture.barcodes.first;
      await _handleBarcode(barcode, frameBytes);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to scan image: $e')));
      }
      setState(() => _isProcessing = false);
    }
  }

  // -------------------- Classification --------------------

  static final _urlRegex = RegExp(
    r'^(https?:\/\/)[^\s]+$',
    caseSensitive: false,
  );
  static final _phoneRegex = RegExp(r'^\+?[0-9]{6,15}$');
  static final _geoRegex = RegExp(
    r'^(?:geo:)?\s*(-?\d{1,2}\.\d+)\s*,\s*(-?\d{1,3}\.\d+)(?:,.*)?$',
    caseSensitive: false,
  );

  _Payload _classifyPayload(String raw, {String? symbology}) {
    final s = raw.trim();
    final sym = symbology?.toLowerCase() ?? '';

    final bool isQr = sym.contains('qr');
    final bool isBarcode = !isQr && sym.isNotEmpty;

    // ----- Barcodes → treat as product / ISBN (never as phone) -----
    if (isBarcode) {
      final code = s;
      bool isIsbn = false;

      if ((code.length == 13 &&
              (code.startsWith('978') || code.startsWith('979')) &&
              RegExp(r'^\d{13}$').hasMatch(code)) ||
          (code.length == 10 && RegExp(r'^\d{9}[\dX]$').hasMatch(code))) {
        isIsbn = true;
      }

      return _Payload(
        _PayloadKind.product,
        s,
        symbology: symbology,
        data: {'code': code, 'isIsbn': isIsbn},
      );
    }

    // ----- QR & generic classification -----

    // URL
    if (_urlRegex.hasMatch(s)) {
      return _Payload(_PayloadKind.url, s, symbology: symbology);
    }

    // Phone
    if (s.startsWith('tel:')) {
      return _Payload(_PayloadKind.phone, s.substring(4), symbology: symbology);
    }
    if (_phoneRegex.hasMatch(s)) {
      return _Payload(_PayloadKind.phone, s, symbology: symbology);
    }

    // Email
    if (s.toLowerCase().startsWith('mailto:')) {
      final addr = s.substring(7);
      return _Payload(
        _PayloadKind.email,
        addr,
        data: {'mailto': s},
        symbology: symbology,
      );
    }
    if (RegExp(r'^[\w\.\-+]+@[\w\.\-]+\.[A-Za-z]{2,}\$').hasMatch(s)) {
      return _Payload(_PayloadKind.email, s, symbology: symbology);
    }

    // Wi-Fi
    if (s.startsWith('WIFI:')) {
      final parts = <String, String>{};
      for (final seg in s.substring(5).split(';')) {
        if (seg.trim().isEmpty) continue;
        final idx = seg.indexOf(':');
        if (idx == -1) continue;
        parts[seg.substring(0, idx)] = seg.substring(idx + 1);
      }
      return _Payload(
        _PayloadKind.wifi,
        s,
        data: {
          'ssid': parts['S'] ?? '',
          'auth': parts['T'] ?? '',
          'password': parts['P'] ?? '',
          'hidden': parts['H'] == 'true',
        },
        symbology: symbology,
      );
    }

    // vCard
    if (s.contains('BEGIN:VCARD')) {
      return _Payload(_PayloadKind.vcard, s, symbology: symbology);
    }

    // Calendar
    if (s.contains('BEGIN:VEVENT') || s.contains('BEGIN:VCALENDAR')) {
      return _Payload(_PayloadKind.calendar, s, symbology: symbology);
    }

    // Geo
    final gm = _geoRegex.firstMatch(s);
    if (gm != null) {
      final lat = double.tryParse(gm.group(1)!);
      final lng = double.tryParse(gm.group(2)!);
      return _Payload(
        _PayloadKind.geo,
        s,
        data: {'lat': lat, 'lng': lng},
        symbology: symbology,
      );
    }

    // JSON
    if (_parsedJson != null) {
      return _Payload(
        _PayloadKind.json,
        s,
        data: _parsedJson,
        symbology: symbology,
      );
    }

    // Plain text
    return _Payload(_PayloadKind.text, s, symbology: symbology);
  }

  // -------------------- History --------------------

  Future<void> _saveScan(_Payload payload) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_prefsKey) ?? <String>[];

      list.add(jsonEncode(payload.toJson()));

      final pruned = list.length > _historyCap
          ? list.sublist(list.length - _historyCap)
          : list;

      await prefs.setStringList(_prefsKey, pruned);
    } catch (_) {
      // ignore
    }
  }

  // -------------------- UI --------------------

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    final double frameW = size.width * 0.86;
    final double frameH = frameW;

    // compute banner height (if ready) to avoid overlaps (approx + margin)
    final double adHeight = _isBannerAdReady && _bannerAd != null
        ? _bannerAd!.size.height.toDouble() + 12
        : 0.0;

    return Scaffold(
      backgroundColor: Colors.black,
      drawer: const AppDrawer(),
      body: Stack(
        children: [
          // Camera preview with pinch-to-zoom
          Positioned.fill(
            child: NativeDeviceOrientationReader(
              useSensor: true,
              builder: (context) {
                final orientation = NativeDeviceOrientationReader.orientation(
                  context,
                );

                int quarterTurns = 0;
                switch (orientation) {
                  case NativeDeviceOrientation.portraitUp:
                    quarterTurns = 0;
                    break;
                  case NativeDeviceOrientation.landscapeLeft:
                    quarterTurns = 1;
                    break;
                  case NativeDeviceOrientation.landscapeRight:
                    quarterTurns = 3;
                    break;
                  case NativeDeviceOrientation.portraitDown:
                    quarterTurns = 2;
                    break;
                  case NativeDeviceOrientation.unknown:
                    quarterTurns = 0;
                }

                return GestureDetector(
                  onScaleStart: (details) {
                    _baseZoomOnScaleStart = _zoom;
                  },
                  onScaleUpdate: (details) {
                    if (details.pointerCount < 2) return;
                    final newZoom = (_baseZoomOnScaleStart * details.scale)
                        .clamp(1.0, 4.0);
                    setState(() {
                      _zoom = newZoom;
                    });
                    _applyZoom();
                  },
                  child: RotatedBox(
                    quarterTurns: quarterTurns,
                    child: MobileScanner(
                      controller: _cameraController,
                      fit: BoxFit.cover,
                      onDetect: _onDetect,
                    ),
                  ),
                );
              },
            ),
          ),

          // Top controls (drawer, flash, gallery, switch camera)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: Row(
                children: [
                  Builder(
                    builder: (ctx) => _roundIconButton(
                      icon: Icons.menu,
                      onTap: () => Scaffold.of(ctx).openDrawer(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _roundIconButton(
                    icon: _torchOn ? Icons.flash_on : Icons.flash_off,
                    onTap: () async {
                      try {
                        await _cameraController.toggleTorch();
                      } catch (_) {}
                      setState(() => _torchOn = !_torchOn);
                    },
                  ),
                  const SizedBox(width: 8),
                  _roundIconButton(
                    icon: Icons.photo_library_outlined,
                    onTap: _scanFromGallery,
                  ),
                  const Spacer(),
                  _roundIconButton(
                    icon: Icons.cameraswitch,
                    onTap: () => _cameraController.switchCamera(),
                  ),
                ],
              ),
            ),
          ),
          // Safe Scan overlay (3s animation)

          // Framing + sweep
          Align(
            alignment: Alignment.center,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: frameW,
              height: frameH,
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white70, width: 2),
                    ),
                  ),
                  _cornerGuide(top: true, left: true),
                  _cornerGuide(top: true, right: true),
                  _cornerGuide(bottom: true, left: true),
                  _cornerGuide(bottom: true, right: true),
                  AnimatedBuilder(
                    animation: _sweep,
                    builder: (context, _) {
                      final bandH = frameH * 0.42;
                      final y = (_sweep.value * (frameH - bandH));
                      return Positioned(
                        left: 0,
                        right: 0,
                        top: y,
                        child: IgnorePointer(
                          child: Container(
                            height: bandH,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  _brandBlue.withOpacity(0.55),
                                  _brandBlue.withOpacity(0.30),
                                  _brandBlue.withOpacity(0.10),
                                  Colors.transparent,
                                ],
                                stops: const [0, 0.45, 0.8, 1],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // Hint text (lifted up by banner height to avoid overlap)
          Positioned(
            left: 0,
            right: 0,
            bottom: 130 + (adHeight > 0 ? adHeight - 12 : 0),
            child: const _HintBubble(text: 'Point camera at a code to scan'),
          ),

          // Zoom slider (also lifted)
          Positioned(
            left: 16,
            right: 16,
            bottom: 80 + (adHeight > 0 ? adHeight - 12 : 0),
            child: Row(
              children: [
                Icon(
                  Icons.zoom_out,
                  color: _zoom > 1.0 ? Colors.white : Colors.white38,
                  size: 20,
                ),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: Colors.white,
                      inactiveTrackColor: Colors.white24,
                      thumbColor: Colors.white,
                      overlayColor: Colors.white24,
                      trackHeight: 3,
                    ),
                    child: Slider(
                      min: 1.0,
                      max: 4.0,
                      value: _zoom,
                      onChanged: (value) {
                        setState(() {
                          _zoom = value;
                        });
                        _applyZoom();
                      },
                    ),
                  ),
                ),
                Icon(
                  Icons.zoom_in,
                  color: _zoom < 4.0 ? Colors.white : Colors.white38,
                  size: 20,
                ),
              ],
            ),
          ),

          // Banner Ad at bottom (shows only when loaded)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _isBannerAdReady && _bannerAd != null
                ? Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SafeArea(
                      top: false,
                      child: SizedBox(
                        height: _bannerAd!.size.height.toDouble(),
                        child: Center(
                          child: SizedBox(
                            width: _bannerAd!.size.width.toDouble(),
                            height: _bannerAd!.size.height.toDouble(),
                            child: AdWidget(ad: _bannerAd!),
                          ),
                        ),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  // -------------------- Widget helpers --------------------

  Widget _roundIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.black54,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }

  Widget _cornerGuide({
    bool top = false,
    bool left = false,
    bool right = false,
    bool bottom = false,
  }) {
    const double len = 28;
    const double thick = 5;
    return Positioned(
      top: top ? 0 : null,
      bottom: bottom ? 0 : null,
      left: left ? 0 : null,
      right: right ? 0 : null,
      child: CustomPaint(
        size: const Size(len, len),
        painter: _CornerPainter(
          color: _brandBlue,
          thickness: thick,
          top: top,
          left: left,
          right: right,
          bottom: bottom,
        ),
      ),
    );
  }
}

class _HintBubble extends StatelessWidget {
  final String text;
  const _HintBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white),
      ),
    );
  }
}

// Painter for blue corner brackets
class _CornerPainter extends CustomPainter {
  final Color color;
  final double thickness;
  final bool top, left, right, bottom;

  _CornerPainter({
    required this.color,
    required this.thickness,
    required this.top,
    required this.left,
    required this.right,
    required this.bottom,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    if (top && left) {
      path.moveTo(0, size.height * 0.6);
      path.lineTo(0, 0);
      path.lineTo(size.width * 0.6, 0);
    } else if (top && right) {
      path.moveTo(size.width * 0.4, 0);
      path.lineTo(size.width, 0);
      path.lineTo(size.width, size.height * 0.6);
    } else if (bottom && left) {
      path.moveTo(0, size.height * 0.4);
      path.lineTo(0, size.height);
      path.lineTo(size.width * 0.6, size.height);
    } else if (bottom && right) {
      path.moveTo(size.width * 0.4, size.height);
      path.lineTo(size.width, size.height);
      path.lineTo(size.width, size.height * 0.4);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CornerPainter old) =>
      old.color != color || old.thickness != thickness;
}
