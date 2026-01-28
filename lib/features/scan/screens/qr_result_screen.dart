// lib/features/scan/screens/qr_result_screen.dart
// Full-screen result page with CTAs, Ad space, and captured image.
//
// UPDATED: show Brand / Product name (when available) instead of the
// generic "Scanned value" for product barcodes. Falls back to product
// code / raw value when brand/product name are not available.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

import 'scan_screen_qr.dart'; // for QrResultData model

class QrResultScreen extends StatelessWidget {
  final QrResultData result;

  static const Color _primaryBlue = Color(0xFF0A66FF);

  const QrResultScreen({super.key, required this.result});

  // Heuristic: sometimes barcode scanners mark barcodes as "phone".
  // Prefer product/book when the payload clearly looks like a product code / ISBN.
  bool _looksLikeProductBarcode() {
    try {
      // 1) explicit hints from parsed data
      if (result.data != null) {
        if (result.data!['isIsbn'] == true) return true;
        if (result.data!['isProduct'] == true) return true;
      }

      // 2) format hint (e.g. EAN_13, UPC_A, ISBN)
      final fmt = (result.format ?? '').toLowerCase();
      if (fmt.contains('ean') || fmt.contains('upc') || fmt.contains('isbn')) {
        return true;
      }

      // 3) raw value looks like pure digits of common barcode lengths (8,12,13,14)
      final raw = result.raw.trim();
      final digitOnly = RegExp(r'^\d+$').hasMatch(raw);
      if (digitOnly &&
          (raw.length == 8 ||
              raw.length == 12 ||
              raw.length == 13 ||
              raw.length == 14)) {
        return true;
      }
    } catch (_) {
      // ignore heuristic failures
    }
    return false;
  }

  bool get _isUrl => result.kind == 'url';
  // treat product either when kind == 'product' OR the heuristic detects it
  bool get _isProduct => result.kind == 'product' || _looksLikeProductBarcode();
  bool get _isPhone => result.kind == 'phone' && !_looksLikeProductBarcode();
  bool get _isEmail => result.kind == 'email';
  bool get _isWifi => result.kind == 'wifi';
  bool get _isVCard => result.kind == 'vcard';
  bool get _isCalendar => result.kind == 'calendar';
  bool get _isGeo => result.kind == 'geo';
  bool get _isJson => result.kind == 'json';
  bool get _isText => result.kind == 'text';

  // Test banner (Google’s recommended test ID)
  static const String _testBannerId = 'ca-app-pub-3940256099942544/6300978111';

  // Replace with YOUR production unit ID
  static const String _prodBannerId = 'ca-app-pub-4377808055186677/5171383893';

  String get _bannerUnitId => kDebugMode ? _testBannerId : _prodBannerId;

  @override
  Widget build(BuildContext context) {
    // Log screen view to Firebase Analytics
    FirebaseAnalytics.instance.logScreenView(
      screenName: 'QrResultScreen',
      parameters: {'result_type': result.kind},
    );

    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: _primaryBlue,
        foregroundColor: Colors.white,
        title: const Text('Scan result', style: TextStyle(color: Colors.white)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _headerCard(textTheme),
              const SizedBox(height: 16),
              _valueCard(textTheme),
              const SizedBox(height: 16),
              _ctaRow(context, textTheme),
              const SizedBox(height: 16),
              _adSpace(),
              const SizedBox(height: 16),
              if (result.imageBytes != null)
                _capturedImageSection(textTheme, result.imageBytes!),
            ],
          ),
        ),
      ),
    );
  }

  // -------------------- Header --------------------

  Widget _headerCard(TextTheme textTheme) {
    final typeLabel = _typeLabel();
    final formatLabel = result.format ?? 'Unknown format';
    final timeStr = _formatTimestamp(result.timestamp);

    IconData leadingIcon;
    if (_isProduct) {
      leadingIcon = Icons.inventory_2;
    } else {
      switch (result.kind) {
        case 'url':
          leadingIcon = Icons.public;
          break;
        case 'phone':
          leadingIcon = Icons.phone;
          break;
        case 'email':
          leadingIcon = Icons.email_outlined;
          break;
        case 'wifi':
          leadingIcon = Icons.wifi;
          break;
        case 'vcard':
          leadingIcon = Icons.person;
          break;
        case 'calendar':
          leadingIcon = Icons.event;
          break;
        case 'geo':
          leadingIcon = Icons.location_on;
          break;
        case 'json':
          leadingIcon = Icons.data_object;
          break;
        default:
          leadingIcon = Icons.qr_code_2;
      }
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _primaryBlue.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _primaryBlue.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _primaryBlue,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(leadingIcon, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  typeLabel,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: _primaryBlue,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$timeStr • $formatLabel',
                  style: textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _typeLabel() {
    // If it's an ISBN, prefer "Book"
    final isIsbn = (result.data?['isIsbn'] == true);
    if (isIsbn) return 'Book';

    if (_isProduct) return 'Product';

    switch (result.kind) {
      case 'url':
        return 'Website';
      case 'phone':
        return 'Phone number';
      case 'email':
        return 'Email address';
      case 'wifi':
        return 'Wi-Fi network';
      case 'vcard':
        return 'Contact';
      case 'calendar':
        return 'Calendar event';
      case 'geo':
        return 'Location';
      case 'json':
        return 'JSON data';
      default:
        return 'Content';
    }
  }

  String _formatTimestamp(DateTime dt) {
    final local = dt.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$d/$m/$y • $hh:$mm';
  }

  // -------------------- Value card --------------------
  //
  // UPDATED: prefer result.data['brand'] / ['product_name'] for products.
  // Show a clear fallback order:
  //  - brand (primary)
  //  - product_name (secondary)
  //  - code (if product)
  //  - raw scanned value

  Widget _valueCard(TextTheme textTheme) {
    final bool isProductIsbn = _isProduct && (result.data?['isIsbn'] == true);

    // Compute title and main display lines
    String title;
    String mainLine;
    String? subLine; // optional smaller subtitle (e.g., code or product_name)

    if (_isProduct) {
      // Prefer brand if available
      final brand = (result.data?['brand'] as String?)?.trim();
      final productName = (result.data?['product_name'] as String?)?.trim();
      final code = result.data?['code'] ?? result.raw;

      if (brand != null && brand.isNotEmpty) {
        title = 'Brand';
        mainLine = brand;
        // show product name or code as subtitle if present
        if (productName != null && productName.isNotEmpty) {
          subLine = productName;
        } else {
          subLine = code?.toString();
        }
      } else if (productName != null && productName.isNotEmpty) {
        title = 'Product';
        mainLine = productName;
        subLine = code?.toString();
      } else {
        // fallback to showing code
        title = isProductIsbn ? 'Scanned ISBN' : 'Scanned Product Code';
        mainLine = (code ?? '').toString();
      }
    } else if (_isEmail && result.data?['mailto'] is String) {
      title = 'Email';
      mainLine = result.data!['mailto'] as String;
    } else {
      title = 'Scanned value';
      mainLine = result.raw;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          SelectableText(
            mainLine,
            style: textTheme.bodyLarge?.copyWith(color: Colors.black87),
          ),
          if (subLine != null) ...[
            const SizedBox(height: 8),
            Text(
              subLine,
              style: textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade700,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // -------------------- CTA Row --------------------

  Widget _ctaRow(BuildContext context, TextTheme textTheme) {
    final List<_CtaConfig> ctas = [];

    if (_isProduct) {
      ctas.addAll([
        _CtaConfig(
          icon: Icons.storefront,
          label: 'Shop now',
          onTap: () => _onShopNow(context),
        ),
        _CtaConfig(
          icon: Icons.search,
          label: 'Web search',
          onTap: () => _onWebSearch(context),
        ),
        _CtaConfig(
          icon: Icons.share,
          label: 'Share',
          onTap: () => _onShare(context),
        ),
        _CtaConfig(
          icon: Icons.copy_all,
          label: 'Copy',
          onTap: () => _onCopy(context),
        ),
      ]);
    } else if (_isUrl) {
      ctas.addAll([
        _CtaConfig(
          icon: Icons.open_in_browser,
          label: 'Open',
          onTap: () => _onOpenUrl(context),
        ),
        _CtaConfig(
          icon: Icons.share,
          label: 'Share',
          onTap: () => _onShare(context),
        ),
        _CtaConfig(
          icon: Icons.copy_all,
          label: 'Copy',
          onTap: () => _onCopy(context),
        ),
      ]);
    } else if (_isPhone) {
      ctas.addAll([
        _CtaConfig(
          icon: Icons.call,
          label: 'Call',
          onTap: () => _onCall(context),
        ),
        _CtaConfig(icon: Icons.sms, label: 'SMS', onTap: () => _onSms(context)),
        _CtaConfig(
          icon: Icons.share,
          label: 'Share',
          onTap: () => _onShare(context),
        ),
        _CtaConfig(
          icon: Icons.copy_all,
          label: 'Copy',
          onTap: () => _onCopy(context),
        ),
      ]);
    } else if (_isEmail) {
      ctas.addAll([
        _CtaConfig(
          icon: Icons.email,
          label: 'Email',
          onTap: () => _onComposeEmail(context),
        ),
        _CtaConfig(
          icon: Icons.share,
          label: 'Share',
          onTap: () => _onShare(context),
        ),
        _CtaConfig(
          icon: Icons.copy_all,
          label: 'Copy',
          onTap: () => _onCopy(context),
        ),
      ]);
    } else if (_isWifi) {
      ctas.addAll([
        _CtaConfig(
          icon: Icons.lock_open,
          label: 'Copy pass',
          onTap: () => _onCopyWifiPassword(context),
        ),
        _CtaConfig(
          icon: Icons.share,
          label: 'Share',
          onTap: () => _onShare(context),
        ),
        _CtaConfig(
          icon: Icons.copy_all,
          label: 'Copy',
          onTap: () => _onCopy(context),
        ),
      ]);
    } else if (_isVCard) {
      ctas.addAll([
        _CtaConfig(
          icon: Icons.call,
          label: 'Call',
          onTap: () => _onCall(context),
        ),
        _CtaConfig(
          icon: Icons.person_add,
          label: 'Add contact',
          onTap: () => _onAddContact(context),
        ),
        _CtaConfig(
          icon: Icons.share,
          label: 'Share',
          onTap: () => _onShare(context),
        ),
        _CtaConfig(
          icon: Icons.copy_all,
          label: 'Copy',
          onTap: () => _onCopy(context),
        ),
      ]);
    } else if (_isCalendar) {
      ctas.addAll([
        _CtaConfig(
          icon: Icons.event_available,
          label: 'Add event',
          onTap: () => _onAddCalendar(context),
        ),
        _CtaConfig(
          icon: Icons.share,
          label: 'Share',
          onTap: () => _onShare(context),
        ),
        _CtaConfig(
          icon: Icons.copy_all,
          label: 'Copy',
          onTap: () => _onCopy(context),
        ),
      ]);
    } else if (_isGeo) {
      ctas.addAll([
        _CtaConfig(
          icon: Icons.map,
          label: 'Open map',
          onTap: () => _onOpenMap(context),
        ),
        _CtaConfig(
          icon: Icons.share,
          label: 'Share',
          onTap: () => _onShare(context),
        ),
        _CtaConfig(
          icon: Icons.copy_all,
          label: 'Copy',
          onTap: () => _onCopy(context),
        ),
      ]);
    } else if (_isJson || _isText) {
      ctas.addAll([
        _CtaConfig(
          icon: Icons.search,
          label: 'Web search',
          onTap: () => _onWebSearch(context),
        ),
        _CtaConfig(
          icon: Icons.share,
          label: 'Share',
          onTap: () => _onShare(context),
        ),
        _CtaConfig(
          icon: Icons.copy_all,
          label: 'Copy',
          onTap: () => _onCopy(context),
        ),
      ]);
    } else {
      ctas.addAll([
        _CtaConfig(
          icon: Icons.share,
          label: 'Share',
          onTap: () => _onShare(context),
        ),
        _CtaConfig(
          icon: Icons.copy_all,
          label: 'Copy',
          onTap: () => _onCopy(context),
        ),
      ]);
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: _primaryBlue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _primaryBlue.withOpacity(0.15)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: ctas
            .map((c) => _ctaItem(icon: c.icon, label: c.label, onTap: c.onTap))
            .toList(),
      ),
    );
  }

  Widget _ctaItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: _primaryBlue,
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }

  // ---- CTA behaviour ----

  Future<void> _onShopNow(BuildContext context) async {
    final query = _isProduct
        ? (result.data?['code'] ?? result.raw).toString()
        : result.raw;

    final uri = Uri.https('www.google.com', '/search', {
      'q': query,
      'tbm': 'shop',
    });

    await _launchOrSnack(context, uri);
  }

  Future<void> _onWebSearch(BuildContext context) async {
    final q = _displayValueForSearch();
    final uri = Uri.https('www.google.com', '/search', {'q': q});
    await _launchOrSnack(context, uri);
  }

  Future<void> _onOpenUrl(BuildContext context) async {
    final uri = Uri.parse(_displayValueForSearch());
    await _launchOrSnack(context, uri, openDirect: true);
  }

  Future<void> _onShare(BuildContext context) async {
    await Share.share(_displayValueForSearch());
  }

  Future<void> _onCopy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: _displayValueForSearch()));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Copied to clipboard')));
  }

  Future<void> _onCall(BuildContext context) async {
    String value = _displayValueForSearch();
    String? phoneToCall;

    // If this is a vCard payload, try to extract the first phone number
    if (_isVCard || value.contains('BEGIN:VCARD')) {
      final lines = value.split(RegExp(r'\r?\n'));
      for (final line in lines) {
        final upper = line.toUpperCase();
        if (upper.startsWith('TEL')) {
          // vCard TEL;TYPE=CELL:+123456789 or TEL:+123456789
          final parts = line.split(':');
          if (parts.length > 1) {
            final candidate = parts.last.trim();
            if (candidate.isNotEmpty) {
              phoneToCall = candidate;
              break;
            }
          }
        }
      }
    }

    // Fallback: if we didn’t find a phone in vCard, use the scanned value
    phoneToCall ??= value;

    final uri = Uri.parse('tel:$phoneToCall');
    await _launchOrSnack(context, uri, openDirect: true);
  }

  Future<void> _onSms(BuildContext context) async {
    final uri = Uri.parse('sms:${_displayValueForSearch()}');
    await _launchOrSnack(context, uri, openDirect: true);
  }

  Future<void> _onComposeEmail(BuildContext context) async {
    final addr = _displayValueForSearch();
    final uri = Uri.parse('mailto:$addr');
    await _launchOrSnack(context, uri, openDirect: true);
  }

  Future<void> _onCopyWifiPassword(BuildContext context) async {
    final pass = (result.data?['password'] ?? '') as String;
    final text = pass.isEmpty ? _displayValueForSearch() : pass;
    await Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Wi-Fi password copied')));
  }

  /// Create a .vcf file from the vCard text and let the OS
  /// open it with the default Contacts app (via share sheet).
  Future<void> _onAddContact(BuildContext context) async {
    try {
      final vcard =
          _displayValueForSearch(); // should be full BEGIN:VCARD ... text

      if (!vcard.contains('BEGIN:VCARD')) {
        // Fallback: just copy text if this isn't a vCard payload
        await Clipboard.setData(ClipboardData(text: vcard));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Contact data copied – paste it into Contacts.'),
          ),
        );
        return;
      }

      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/contact_${DateTime.now().millisecondsSinceEpoch}.vcf',
      );
      await file.writeAsString(vcard);

      final xFile = XFile(file.path, mimeType: 'text/x-vcard');

      // This will show the system share sheet; on phones, Contacts
      // app will usually appear as an option to directly import.
      await Share.shareXFiles(
        [xFile],
        subject: 'Add contact',
        text: 'Import this contact into your Contacts app.',
      );
    } catch (_) {
      // Last-resort fallback
      await Clipboard.setData(ClipboardData(text: _displayValueForSearch()));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not open Contacts – contact data copied instead.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _onAddCalendar(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: _displayValueForSearch()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Event data copied – import it into your Calendar app.'),
      ),
    );
  }

  Future<void> _onOpenMap(BuildContext context) async {
    double? lat = result.data?['lat'] is num
        ? (result.data!['lat'] as num).toDouble()
        : null;
    double? lng = result.data?['lng'] is num
        ? (result.data!['lng'] as num).toDouble()
        : null;

    Uri uri;
    if (lat != null && lng != null) {
      uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
      );
    } else {
      final q = _displayValueForSearch();
      uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$q');
    }

    await _launchOrSnack(context, uri, openDirect: true);
  }

  Future<void> _launchOrSnack(
    BuildContext context,
    Uri uri, {
    bool openDirect = false,
  }) async {
    try {
      if (openDirect) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          throw Exception('Cannot open URL');
        }
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Could not open link')));
      }
    }
  }

  // -------------------- Ad + image --------------------

  Widget _adSpace() {
    final BannerAd banner = BannerAd(
      adUnitId: _bannerUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
        },
      ),
    );

    banner.load();

    return Container(
      width: double.infinity,
      height: banner.size.height.toDouble(),
      alignment: Alignment.center,
      child: AdWidget(ad: banner),
    );
  }

  Widget _capturedImageSection(TextTheme textTheme, Uint8List bytes) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Keep captured image section (user still may want to see the frame),
        // but the main value card now emphasizes Brand/Product instead.
        Text(
          'Captured image',
          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: double.infinity,
            height: 220, // fixed height to avoid long scroll
            child: Image.memory(
              bytes,
              fit: BoxFit.cover, // visually crops so code area is prominent
            ),
          ),
        ),
      ],
    );
  }

  // -------------------- Utilities --------------------

  // Value used for sharing / web search / copy etc. Prefer brand/product_name
  // for product results because that is more useful to users when searching.
  String _displayValueForSearch() {
    if (_isProduct) {
      final brand = (result.data?['brand'] as String?)?.trim();
      final productName = (result.data?['product_name'] as String?)?.trim();
      final code = result.data?['code'] ?? result.raw;

      if (brand != null &&
          brand.isNotEmpty &&
          productName != null &&
          productName.isNotEmpty) {
        return '$brand $productName';
      }
      if (brand != null && brand.isNotEmpty) return brand;
      if (productName != null && productName.isNotEmpty) return productName;
      return code?.toString() ?? result.raw;
    }

    if (_isEmail && result.data?['mailto'] is String) {
      return result.data!['mailto'] as String;
    }

    return result.raw;
  }
}

// Simple config holder for CTAs
class _CtaConfig {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  _CtaConfig({required this.icon, required this.label, required this.onTap});
}
