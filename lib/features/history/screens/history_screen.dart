// history_screen.dart
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../../themes.dart';

import 'created_qr_modal_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  bool isScanSelected = true;
  final GlobalKey _qrGlobalKey = GlobalKey();

  List<String> _scanEncoded = [];
  List<String> _createdEncoded = [];

  List<Map<String, String>> scannedItems = [];
  List<Map<String, String>> createdItems = [];

  // ---- AdMob banner fields ----
  BannerAd? _bannerAd;
  bool _isBannerAdReady = false;

  // Google's test banner id for development
  static const String _googleTestBannerAdUnitId =
      'ca-app-pub-3940256099942544/6300978111';

  // Replace with your production ad unit id
  static const String _productionBannerAdUnitId =
      'ca-app-pub-2961863855425096/5968213716';

  String get _adUnitId =>
      kDebugMode ? _googleTestBannerAdUnitId : _productionBannerAdUnitId;

  // optional retry attempts
  int _loadAttempts = 0;
  static const int _maxLoadAttempts = 3;

  @override
  void initState() {
    super.initState();
    _loadAllHistory();
    _loadBannerAd();
  }

  Future<void> _loadAllHistory() async {
    await Future.wait([_loadScanHistory(), _loadCreatedHistory()]);
  }

  Future<void> _loadScanHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('scan_history') ?? <String>[];
    _scanEncoded = List<String>.from(list);

    final parsed = <Map<String, String>>[];
    for (final s in _scanEncoded) {
      try {
        final map = jsonDecode(s) as Map<String, dynamic>;
        final kind = (map['kind'] ?? 'text').toString();
        final raw = (map['raw'] ?? '').toString();
        final data = map['data'] is Map
            ? Map<String, dynamic>.from(map['data'])
            : <String, dynamic>{};
        final tsStr = (map['ts'] ?? '').toString();
        final ts = DateTime.tryParse(tsStr) ?? DateTime.now();

        parsed.add({
          'type': _labelForKind(kind),
          'value': _displayValueFor(kind, raw, data),
          'time': _formatNice(ts),
          'raw': raw,
          'kind': kind,
          'encoded': s,
        });
      } catch (_) {}
    }

    setState(() {
      scannedItems = parsed.reversed.toList();
    });
  }

  Future<void> _loadCreatedHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('created_history') ?? <String>[];
    _createdEncoded = List<String>.from(list);

    final parsed = <Map<String, String>>[];
    final looksJson =
        _createdEncoded.isNotEmpty &&
        _createdEncoded.first.trim().startsWith('{');

    if (looksJson) {
      for (final s in _createdEncoded) {
        try {
          final map = jsonDecode(s) as Map<String, dynamic>;
          final typeRaw = (map['type'] ?? 'Content').toString();
          final type = _normalizeCreatedType(typeRaw);
          final value = (map['value'] ?? '').toString();
          final time = (map['time'] ?? '').toString();
          parsed.add({
            'type': type,
            'value': value,
            'time': time,
            'display': _displayValueForCreated(typeRaw, value),
            'raw': value,
          });
        } catch (_) {}
      }
    } else {
      for (final raw in _createdEncoded) {
        final s = raw.trim();
        if (s.isEmpty) continue;
        final parts = s.split(',');
        if (parts.length >= 3) {
          final typeRaw = parts.first.trim();
          final time = parts.last.trim();
          final value = parts.sublist(1, parts.length - 1).join(', ').trim();
          final type = _normalizeCreatedType(typeRaw);
          parsed.add({
            'type': type,
            'value': value,
            'time': time,
            'display': _displayValueForCreated(typeRaw, value),
            'raw': value,
          });
        }
      }
    }

    setState(() {
      createdItems = parsed.reversed.toList();
    });
  }

  // ---------- Helpers ----------

  String _labelForKind(String kind) {
    switch (kind) {
      case 'url':
        return 'URL';
      case 'phone':
        return 'Phone';
      case 'email':
        return 'Email';
      case 'wifi':
        return 'Wi-Fi';
      case 'vcard':
        return 'Contact';
      case 'calendar':
        return 'Calendar';
      case 'geo':
        return 'Location';
      case 'json':
        return 'JSON';
      case 'text':
      default:
        return 'Content';
    }
  }

  String _normalizeCreatedType(String raw) {
    final t = raw.trim().toLowerCase();
    if (t == 'url') return 'URL';
    if (t == 'wifi' || t == 'wi-fi') return 'Wi-Fi';
    if (t == 'contact' || t == 'vcard' || t == 'mecard') return 'Contact';
    return raw.isEmpty ? 'Content' : raw;
  }

  String _displayValueFor(String kind, String raw, Map<String, dynamic> data) {
    switch (kind) {
      case 'wifi':
        return data['ssid']?.toString() ?? raw;
      case 'geo':
        final lat = data['lat'];
        final lng = data['lng'];
        if (lat != null && lng != null) return '$lat, $lng';
        return raw;
      default:
        return raw;
    }
  }

  String _displayValueForCreated(String type, String value) {
    switch (type.toLowerCase()) {
      case 'wifi':
      case 'wi-fi':
        return _parseWifiSsid(value) ?? value;
      case 'contact':
      case 'vcard':
      case 'mecard':
        final me = _parseMecard(value);
        return me['name']?.isNotEmpty == true
            ? me['name']!
            : me['tel'] ?? value;
      default:
        return value;
    }
  }

  String? _parseWifiSsid(String wifiPayload) {
    if (!wifiPayload.startsWith('WIFI:')) return null;
    final rest = wifiPayload.substring(5);
    final parts = rest.split(';');
    for (final p in parts) {
      if (p.startsWith('S:')) return p.substring(2);
    }
    return null;
  }

  Map<String, String> _parseMecard(String mecard) {
    final out = <String, String>{};
    if (!mecard.toUpperCase().startsWith('MECARD:')) return out;
    final rest = mecard.substring(7);
    final segs = rest.split(';');
    for (final seg in segs) {
      final idx = seg.indexOf(':');
      if (idx <= 0) continue;
      final k = seg.substring(0, idx).toUpperCase();
      final v = seg.substring(idx + 1);
      out[k] = v;
    }
    return {
      'name': out['N'] ?? '',
      'tel': out['TEL'] ?? '',
      'email': out['EMAIL'] ?? '',
    };
  }

  IconData _getIcon(String type) {
    switch (type) {
      case 'URL':
        return FontAwesomeIcons.globe;
      case 'Email':
        return FontAwesomeIcons.envelope;
      case 'Contact':
        return FontAwesomeIcons.user;
      case 'Phone':
        return FontAwesomeIcons.phone;
      case 'Wi-Fi':
        return FontAwesomeIcons.wifi;
      case 'Calendar':
        return FontAwesomeIcons.calendarDays;
      case 'Location':
        return FontAwesomeIcons.locationDot;
      case 'JSON':
        return FontAwesomeIcons.code;
      default:
        return Icons.info_outline;
    }
  }

  String _formatNice(DateTime dt) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final d = dt.day.toString().padLeft(2, '0');
    final m = months[dt.month - 1];
    final y = dt.year;
    var hh = dt.hour;
    final mm = dt.minute.toString().padLeft(2, '0');
    final am = hh >= 12 ? 'pm' : 'am';
    hh = hh % 12;
    if (hh == 0) hh = 12;
    return '$d $m $y | $hh:$mm $am';
  }

  Future<void> _deleteScanItemByEncoded(String encoded) async {
    final prefs = await SharedPreferences.getInstance();
    _scanEncoded.remove(encoded);
    await prefs.setStringList('scan_history', _scanEncoded);
    await _loadScanHistory();
  }

  Future<void> _deleteCreatedItemByRaw(String raw) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('created_history') ?? [];

    // Each line is stored like: "Type, Value, Time"
    // We must identify the line whose Value matches `raw`
    final updatedList = list.where((entry) {
      final parts = entry.split(',');
      if (parts.length < 2) return true; // malformed, keep it
      final value = parts[1].trim();
      return value != raw.trim();
    }).toList();

    await prefs.setStringList('created_history', updatedList);

    // Reload UI
    await _loadCreatedHistory();
  }

  // ---- Banner ad loader ----
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
          debugPrint(
            '[History] Banner failed to load: $error (attempt $_loadAttempts)',
          );
          if (_loadAttempts <= _maxLoadAttempts) {
            final delaySeconds = 1 << (_loadAttempts - 1); // 1,2,4
            Future.delayed(Duration(seconds: delaySeconds), _loadBannerAd);
          } else {
            debugPrint(
              '[History] Banner: giving up after $_loadAttempts attempts.',
            );
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
    super.dispose();
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final List<Map<String, String>> historyItems = isScanSelected
        ? scannedItems
        : createdItems;

    // Ad height 0 when not ready (so nothing is shown)
    final adHeight = _isBannerAdReady && _bannerAd != null
        ? _bannerAd!.size.height.toDouble()
        : 0.0;

    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: AppBar(
        backgroundColor: colorScheme.background,
        elevation: 1,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: Text(
          "History",
          style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),

      // ---------------- Drawer ----------------
      body: Column(
        children: [
          const SizedBox(height: 12),

          // Toggle
          Container(
            width: MediaQuery.of(context).size.width * 0.7,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark ? Colors.white10 : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => isScanSelected = true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: isScanSelected
                            ? SecureScanTheme.accentBlue
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(25),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        "Scan",
                        style: textTheme.bodyMedium?.copyWith(
                          color: isScanSelected
                              ? Colors.white
                              : colorScheme.onBackground.withOpacity(0.7),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => isScanSelected = false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: !isScanSelected
                            ? SecureScanTheme.accentBlue
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(25),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        "Created",
                        style: textTheme.bodyMedium?.copyWith(
                          color: !isScanSelected
                              ? Colors.white
                              : colorScheme.onBackground.withOpacity(0.7),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadAllHistory,
              child: historyItems.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(height: 160),
                        Center(
                          child: Text(
                            "No history found",
                            style: textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: historyItems.length,
                      itemBuilder: (context, index) {
                        final item = historyItems[index];
                        final showValue = isScanSelected
                            ? (item['value'] ?? '')
                            : (item['display'] ?? item['value'] ?? '');

                        // Always show 3-dots menu (Delete) for both Scan and Created tabs.
                        final trailingWidget = PopupMenuButton<String>(
                          color: isDark ? Colors.black : Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 6,
                          onSelected: (value) async {
                            if (value == 'Delete') {
                              if (isScanSelected) {
                                final encoded = item['encoded'];
                                if (encoded != null) {
                                  await _deleteScanItemByEncoded(encoded);
                                }
                              } else {
                                // For created items we attempt to delete by the raw/value string stored.
                                final raw = item['raw'] ?? item['value'];
                                if (raw != null) {
                                  await _deleteCreatedItemByRaw(raw);
                                }
                              }
                            }
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(
                              value: 'Delete',
                              child: Text(
                                'Delete',
                                style: TextStyle(color: Colors.redAccent),
                              ),
                            ),
                          ],
                          icon: Icon(
                            Icons.more_vert,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        );

                        return InkWell(
                          onTap: () => _onHistoryItemTap(item),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDark
                                    ? Colors.white12
                                    : const Color(0xFFBFBFBF),
                              ),
                            ),
                            child: Row(
                              children: [
                                // Left
                                Container(
                                  width: 68,
                                  alignment: Alignment.center,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 18,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.white10
                                        : const Color(0xFFF4F4F4),
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(12),
                                      bottomLeft: Radius.circular(12),
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        _getIcon(item['type']!),
                                        color: SecureScanTheme.accentBlue,
                                        size: 22,
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        item['type']!,
                                        textAlign: TextAlign.center,
                                        style: textTheme.labelSmall?.copyWith(
                                          color: SecureScanTheme.accentBlue,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Right
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.all(14.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          showValue,
                                          overflow: TextOverflow.ellipsis,
                                          style: textTheme.bodyLarge?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          item['time'] ?? '',
                                          style: textTheme.bodySmall?.copyWith(
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                // trailing
                                const SizedBox(width: 8),
                                trailingWidget,
                                const SizedBox(width: 8),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),

          // ---------- Banner Ad spot: shows nothing until ad is ready ----------
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

  void _onHistoryItemTap(Map<String, String> item) async {
    // If scan tab -> try to open, else (created) -> open full-screen created QR modal screen
    if (isScanSelected) {
      final type = item['type'] ?? '';
      final raw = item['raw'] ?? '';
      final kindLower = (item['kind'] ?? '').toLowerCase();

      try {
        if (kindLower == 'url' || type == 'URL') {
          final uri = Uri.tryParse(raw);
          if (uri != null) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
            return;
          }
        } else if (kindLower == 'phone' || type == 'Phone') {
          final uri = Uri(scheme: 'tel', path: raw);
          await launchUrl(uri);
          return;
        } else if (kindLower == 'email' || type == 'Email') {
          final uri = Uri(scheme: 'mailto', path: raw);
          await launchUrl(uri);
          return;
        } else if (kindLower == 'geo' || type == 'Location') {
          // raw might be "lat,lng" or full geo: uri
          final coords = raw.split(',');
          if (coords.length >= 2) {
            final lat = coords[0].trim();
            final lng = coords[1].trim();
            final google = Uri.parse(
              'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
            );
            await launchUrl(google, mode: LaunchMode.externalApplication);
            return;
          } else {
            final parsed = Uri.tryParse(raw);
            if (parsed != null) {
              await launchUrl(parsed, mode: LaunchMode.externalApplication);
              return;
            }
          }
        }
      } catch (_) {
        // ignore and fallback to showing QR preview
      }

      // fallback: show small QR preview dialog (for items that cannot be opened directly)
      _showQrPreviewDialog(
        item['type'] ?? 'Content',
        item['raw'] ?? item['value'] ?? '',
        item['time'] ?? '',
      );
    } else {
      // Created tab -> open full screen created QR modal screen
      final type = item['type'] ?? 'Content';
      final value = item['raw'] ?? item['value'] ?? '';
      final time = item['time'] ?? '';
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              CreatedQrModalScreen(type: type, value: value, time: time),
          fullscreenDialog: true,
        ),
      );
    }
  }

  // ----------- Dialog -----------

  void _showQrPreviewDialog(String type, String value, String time) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: colorScheme.background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(_getIcon(type), color: SecureScanTheme.accentBlue, size: 22),
              const SizedBox(width: 10),
              Text(
                type,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onBackground,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              children: [
                RepaintBoundary(
                  key: _qrGlobalKey,
                  child: Container(
                    width: 280,
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    decoration: BoxDecoration(
                      color: SecureScanTheme.accentBlue,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Text(
                          "YOUR QR CODE",
                          style: textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Container(
                          width: 180,
                          height: 180,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.all(12),
                          child: QrImageView(
                            data: value,
                            version: QrVersions.auto,
                            backgroundColor: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          "Thank you for using\nQR & Barcode Scanner Generator",
                          textAlign: TextAlign.center,
                          style: textTheme.bodySmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                "Close",
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
