import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phone_state/phone_state.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:share_plus/share_plus.dart';

class CallOverlayWidget extends StatefulWidget {
  const CallOverlayWidget({Key? key}) : super(key: key);

  @override
  State<CallOverlayWidget> createState() => _CallOverlayWidgetState();
}

class _CallOverlayWidgetState extends State<CallOverlayWidget> {
  String _message = ""; // Start empty to avoid flashing
  StreamSubscription<PhoneState>?
  _phoneStateSubscription; // Phone state listener
  Timer? _autoDismissTimer; // Timer for auto-closing call ended popup

  BannerAd? _bannerAd;
  bool _isAdLoaded = false;
  String? _phoneNumber;

  @override
  void initState() {
    super.initState();
    _loadBannerAd();

    // Listen to data from main app
    FlutterOverlayWindow.overlayListener.listen((event) {
      if (!mounted) return;

      final eventStr = event.toString().toLowerCase();
      if (eventStr == 'incoming') {
        setState(() {
          _message = "Incoming Call...";
        });
        _resizeOverlay(true);
      } else if (eventStr == 'outgoing') {
        setState(() {
          _message = "In Call";
        });
        _resizeOverlay(false); // Minimize logic
      } else if (eventStr == 'ended') {
        debugPrint('[Overlay] Received ended event');
        setState(() {
          _message = "Call Ended";
        });
        _resizeOverlay(true);
        _startAutoDismissTimer();
      }
    });

    // Listen to Phone State independently (Persistent Overlay)
    _phoneStateSubscription = PhoneState.stream.listen((event) {
      if (!mounted) return;

      setState(() {
        _phoneNumber = event.number;
      });
      if (event.status == PhoneStateStatus.CALL_STARTED) {
        // Minimize overlay during call
        _resizeOverlay(false);
        setState(() {
          _message = "In Call";
        });
      } else if (event.status == PhoneStateStatus.NOTHING) {
        // Call Ended -> Show Full Screen
        debugPrint('[PhoneState] Call ended, showing popup');
        _resizeOverlay(true);
        setState(() {
          _message = "Call Ended";
        });
        // Auto-dismiss after 5 seconds
        _startAutoDismissTimer();
      }
    });
  }

  void _loadBannerAd() {
    try {
      _bannerAd = BannerAd(
        adUnitId:
            'ca-app-pub-4377808055186677/6096672505', // Use provided ID or test ID for dev
        size: AdSize.mediumRectangle, // 300x250 for Option 3
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (ad) {
            if (mounted) {
              setState(() {
                _isAdLoaded = true;
              });
            }
          },
          onAdFailedToLoad: (ad, error) {
            ad.dispose();
            debugPrint('Ad failed to load: $error');
          },
        ),
      )..load();
    } catch (e) {
      debugPrint('Error loading banner ad: $e');
      _isAdLoaded = false;
    }
  }

  void _startAutoDismissTimer() {
    debugPrint('[Timer] Starting auto-dismiss timer for 5 seconds');
    _autoDismissTimer?.cancel(); // Cancel any existing timer
    _autoDismissTimer = Timer(const Duration(seconds: 5), () {
      debugPrint('[Timer] Auto-dismissing overlay');
      if (mounted) {
        FlutterOverlayWindow.closeOverlay();
      }
    });
  }

  Future<void> _shareQRCode() async {
    try {
      await Share.share(
        'Check out my contact QR code: https://securescan.com/contact',
        subject: 'SecureScan Contact QR',
      );
    } catch (e) {
      debugPrint('Error sharing: $e');
      // Don't use ScaffoldMessenger in overlay context
    }
  }

  void _createOtherQR() {
    if (!mounted) return;
    // TODO: Navigate to QR creation screen or handle in main app
    debugPrint('QR Creation feature - Coming soon!');
  }

  @override
  void dispose() {
    _phoneStateSubscription?.cancel();
    _autoDismissTimer?.cancel();
    _bannerAd?.dispose();
    super.dispose();
  }

  Future<void> _resizeOverlay(bool isFull) async {
    try {
      if (isFull) {
        debugPrint('[Resize] Making overlay full screen and visible');
        await FlutterOverlayWindow.resizeOverlay(
          WindowSize.matchParent,
          WindowSize.matchParent,
          false, // Changed to false - make it visible/interactive
        );
      } else {
        // Minimize to a small hidden usage
        debugPrint('[Resize] Minimizing overlay');
        await FlutterOverlayWindow.resizeOverlay(1, 1, false);
      }
    } catch (e) {
      debugPrint('[Resize] Error resizing overlay: $e');
      // Continue if resize fails
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(color: Colors.black45, blurRadius: 16, spreadRadius: 4),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey),
                      onPressed: () => FlutterOverlayWindow.closeOverlay(),
                    ),
                    Row(
                      children: [
                        Icon(
                          Icons.shield_outlined,
                          color: Colors.blue[700],
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "SecureScan",
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            color: Colors.blue[900],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 48), // Balance spacing
                  ],
                ),
              ),

              const Divider(height: 1),

              // Content
              // Content - Only show full UI if persistent full screen
              if (_message == "Call Ended" ||
                  _message == "Incoming Call...") ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    children: [
                      if (_message == "Incoming Call...") ...[
                        const SizedBox(height: 32),
                        const Icon(
                          Icons.ring_volume,
                          size: 64,
                          color: Colors.green,
                        ),
                        Text(
                          _phoneNumber ?? "Unknown Number",
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 32),
                      ] else ...[
                        Text(
                          "Call Ended",
                          style: GoogleFonts.inter(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        Text(
                          "Share Info with ${_phoneNumber ?? "Contact"}",
                          style: GoogleFonts.inter(color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 24),

                        // Option 3 Card UI
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 10,
                                offset: Offset(0, 4),
                              ),
                            ],
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: Column(
                            children: [
                              Text(
                                "Share Your Contact QR",
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                              const SizedBox(height: 16),
                              QrImageView(
                                data:
                                    "https://securescan.com/contact", // Placeholder
                                version: QrVersions.auto,
                                size: 180.0,
                              ),
                              const SizedBox(height: 24),
                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: ElevatedButton(
                                  onPressed: _shareQRCode,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(
                                      0xFF1E293B,
                                    ), // Dark slate
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text(
                                    "Share",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: TextButton(
                            onPressed: _createOtherQR,
                            style: TextButton.styleFrom(
                              backgroundColor: Colors.grey[100],
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              "Create Other QR (Text, URL)",
                              style: GoogleFonts.inter(
                                color: Colors.black87,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],

              const Spacer(),

              // Ad Section
              if (_isAdLoaded && _bannerAd != null)
                Container(
                  width: _bannerAd!.size.width.toDouble(),
                  height: _bannerAd!.size.height.toDouble(),
                  alignment: Alignment.center,
                  child: AdWidget(ad: _bannerAd!),
                )
              else
                Container(
                  width: double.infinity,
                  height: 250, // Medium Rectangle height
                  decoration: const BoxDecoration(color: Color(0xFF475569)),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Advertisement",
                          style: GoogleFonts.inter(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Icon(
                          Icons.ad_units,
                          color: Colors.white24,
                          size: 48,
                        ),
                        Text(
                          "Loading Ad...",
                          style: GoogleFonts.inter(color: Colors.white24),
                        ),
                      ],
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
