// generator_screen.dart
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'dart:async';
import 'package:intl_phone_field/intl_phone_field.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_contact_picker/model/contact.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_native_contact_picker/flutter_native_contact_picker.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../../themes.dart';

class CreateQRScreen extends StatelessWidget {
  final List<Map<String, dynamic>> items = [
    {'icon': Icons.content_paste, 'title': 'Content from clipboard'},
    {'icon': Icons.link, 'title': 'URL'},
    {'icon': Icons.text_fields, 'title': 'Text'},
    {'icon': Icons.person_outline, 'title': 'Contact'},
    {'icon': Icons.email_outlined, 'title': 'Email'},
    {'icon': Icons.phone_outlined, 'title': 'Phone'},
    {'icon': Icons.wifi, 'title': 'Wifi'},
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: colorScheme.onBackground),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text("Create", style: textTheme.titleLarge),
        centerTitle: true,
        backgroundColor: theme.appBarTheme.backgroundColor,
        iconTheme: theme.appBarTheme.iconTheme,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            color: colorScheme.surface,
            child: Text(
              "Create QR",
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          // List
          Expanded(
            child: ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, __) =>
                  Divider(height: 1, color: colorScheme.outline),
              itemBuilder: (context, index) {
                return ListTile(
                  leading: Icon(
                    items[index]['icon'],
                    size: 26,
                    color: colorScheme.primary,
                  ),
                  title: Text(
                    items[index]['title'],
                    style: textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onBackground,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  trailing: Icon(
                    Icons.chevron_right,
                    color: colorScheme.onSurface,
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => (CreateQRCodePage(
                          selectedType: items[index]['title'],
                        )),
                      ),
                    );
                  },
                  tileColor: colorScheme.surface,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                );
              },
            ),
          ),
          Divider(color: colorScheme.outline),
        ],
      ),
    );
  }
}

class CreateQRCodePage extends StatefulWidget {
  const CreateQRCodePage({super.key, required this.selectedType});

  final String selectedType;

  @override
  State<CreateQRCodePage> createState() => _CreateQRCodePageState();
}

class _CreateQRCodePageState extends State<CreateQRCodePage> {
  late String selectedType = widget.selectedType;
  bool isCreated = false;
  String qrData = "";

  // Controllers
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final emailController = TextEditingController();
  final companyController = TextEditingController();
  final designationController = TextEditingController();
  final addressController = TextEditingController();
  final urlNameController = TextEditingController();
  final urlLinkController = TextEditingController();
  final wifiNameController = TextEditingController();
  String encryptionValue = "WPA/WPA2";
  final wifiPasswordController = TextEditingController();

  final GlobalKey _qrKey = GlobalKey();

  // UI state
  bool _wifiPasswordVisible = false;

  // Field error messages (shown below inputs)
  String? _nameError;
  String? _phoneError;
  String? _emailError;
  String? _urlNameError;
  String? _urlLinkError;
  String? _wifiNameError;
  String? _wifiPasswordError;

  // Contact picker instance
  final FlutterNativeContactPicker _contactPicker =
      FlutterNativeContactPicker();

  // ---------------- Ads ----------------
  BannerAd? _bannerAd;
  bool _isBannerAdReady = false;
  int _bannerLoadAttempts = 0;
  static const int _maxBannerLoadAttempts = 3;

  InterstitialAd? _interstitialAd;
  bool _isInterstitialReady = false;
  int _interstitialLoadAttempts = 0;
  static const int _maxInterstitialLoadAttempts = 3;

  // Test and production unit IDs
  static const String _testBannerAdUnitId =
      'ca-app-pub-3940256099942544/6300978111';
  static const String _prodBannerAdUnitId =
      'ca-app-pub-4377808055186677/5698105305'; // replace with your banner id

  static const String _testInterstitialAdUnitId =
      'ca-app-pub-3940256099942544/1033173712';
  static const String _prodInterstitialAdUnitId =
      'ca-app-pub-4377808055186677/2712849317'; // replace with your interstitial id

  String get _bannerUnitId =>
      kDebugMode ? _testBannerAdUnitId : _prodBannerAdUnitId;
  String get _interstitialUnitId =>
      kDebugMode ? _testInterstitialAdUnitId : _prodInterstitialAdUnitId;

  @override
  void initState() {
    super.initState();
    // Add listeners so we validate on change:
    nameController.addListener(_onContactFieldChanged);
    phoneController.addListener(_onContactFieldChanged);
    emailController.addListener(_onContactFieldChanged);
    urlNameController.addListener(_onUrlFieldChanged);
    urlLinkController.addListener(_onUrlFieldChanged);
    wifiNameController.addListener(_onWifiFieldChanged);
    wifiPasswordController.addListener(_onWifiFieldChanged);

    // Ensure URL field has https:// by default if empty and type is URL
    if (selectedType == "URL" && urlLinkController.text.isEmpty) {
      urlLinkController.text = 'https://';
      urlLinkController.selection = TextSelection.fromPosition(
        TextPosition(offset: urlLinkController.text.length),
      );
    }

    // Load ads
    _loadBannerAd();
    _loadInterstitial();
  }

  // -------------------- SharedPreferences helpers --------------------
  Future<void> _saveCreatedEntry({
    required String type,
    required String value,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final nowStr = _formatNow();

    final line = "$type, $value, $nowStr";
    final list = prefs.getStringList('created_history') ?? [];

    list.insert(0, line); // newest first
    await prefs.setStringList('created_history', list);
  }

  String _formatNow() {
    final now = DateTime.now();
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
    final d = now.day.toString().padLeft(2, '0');
    final m = months[now.month - 1];
    final y = now.year.toString();
    int hour = now.hour;
    final min = now.minute.toString().padLeft(2, '0');
    final ampm = hour >= 12 ? 'pm' : 'am';
    hour = hour % 12;
    if (hour == 0) hour = 12;
    return "$d $m $y | $hour:$min $ampm";
  }

  // -------------------- Validation helpers --------------------

  // email: relaxed but practical
  static final RegExp _emailReg = RegExp(
    r"^[\w\.\-+]+@[a-zA-Z0-9\.\-]+\.[a-zA-Z]{2,}$",
  );

  // phone: exactly 10 digits
  String? _completePhoneNumber; // +919876543210
  bool _isPhoneValid = false;

  bool _validateContact({bool setStateErrors = true}) {
    var ok = true;

    final name = nameController.text.trim();
    final email = emailController.text.trim();

    final nameErr = name.isEmpty ? "Name is required" : null;
    final phoneErr = (_completePhoneNumber == null || !_isPhoneValid)
        ? "Valid phone number is required"
        : null;

    final emailErr = email.isEmpty
        ? "Email is required"
        : (!_emailReg.hasMatch(email) ? "Enter a valid email" : null);

    if (setStateErrors) {
      setState(() {
        _nameError = nameErr;
        _phoneError = phoneErr;
        _emailError = emailErr;
      });
    }

    if (nameErr != null || phoneErr != null || emailErr != null) ok = false;
    return ok;
  }

  bool _validateUrl({bool setStateErrors = true}) {
    var ok = true;
    final name = urlNameController.text.trim();
    final link = urlLinkController.text.trim();

    final nameErr = name.isEmpty ? "Name is required" : null;

    String? linkErr;
    if (link.isEmpty) {
      linkErr = "Link is required";
    } else {
      final l = link.toLowerCase();
      if (!l.contains('.') && !l.startsWith('http'))
        linkErr = "Enter a valid link";
    }

    if (setStateErrors) {
      setState(() {
        _urlNameError = nameErr;
        _urlLinkError = linkErr;
      });
    }

    if (nameErr != null || linkErr != null) ok = false;
    return ok;
  }

  bool _validateWifi({bool setStateErrors = true}) {
    var ok = true;
    final ssid = wifiNameController.text.trim();
    final pass = wifiPasswordController.text;

    final ssidErr = ssid.isEmpty ? "SSID is required" : null;

    String? passErr;
    if (encryptionValue.toLowerCase() != 'none') {
      if (pass.isEmpty)
        passErr = "Password is required for selected encryption";
      else if (pass.length < 4)
        passErr = "Password is too short";
    }

    if (setStateErrors) {
      setState(() {
        _wifiNameError = ssidErr;
        _wifiPasswordError = passErr;
      });
    }

    if (ssidErr != null || passErr != null) ok = false;
    return ok;
  }

  void _onContactFieldChanged() {
    // Run live validation for contact fields only
    if (selectedType == "Contact") {
      _validateContact();
    }
    setState(() {}); // refresh button enabled state
  }

  void _onUrlFieldChanged() {
    if (selectedType == "URL") _validateUrl();
    setState(() {});
  }

  void _onWifiFieldChanged() {
    if (selectedType == "Wifi") _validateWifi();
    setState(() {});
  }

  bool get _canCreate {
    if (selectedType == "Contact") {
      return _validateContact(setStateErrors: false);
    } else if (selectedType == "URL") {
      return _validateUrl(setStateErrors: false);
    } else if (selectedType == "Wifi") {
      return _validateWifi(setStateErrors: false);
    } else if (selectedType == "Phone") {
      return _completePhoneNumber != null && _isPhoneValid;
    } else {
      return true;
    }
  }

  // -------------------- Contact picker flow (flutter_native_contact_picker) -----
  /// Opens native contact picker, extracts name & phone, populates form,
  /// immediately builds the MECARD payload, saves to history and navigates
  /// to the QrResultScreen.
  Future<void> _pickContactFromDevice() async {
    try {
      // Show native contact picker (user picks one contact)
      final Contact? contact = await _contactPicker.selectContact();

      if (contact == null) return; // user cancelled

      // Extract best-effort fields from returned contact
      final name = contact.fullName ?? '';
      String phone = '';

      // flutter_native_contact_picker may return phoneNumbers as List<String>
      if (contact.phoneNumbers != null && contact.phoneNumbers!.isNotEmpty) {
        phone = contact.phoneNumbers!.first;
      } else if (contact.selectedPhoneNumber != null &&
          contact.selectedPhoneNumber!.isNotEmpty) {
        phone = contact.selectedPhoneNumber!;
      }

      // Normalize phone: strip non-digits and keep last 10 digits (common approach)
      phoneController.text = phone; // let intl_phone_field handle it
      _completePhoneNumber = phone;

      // Populate form fields (email often isn't provided by this picker)
      if (name.isNotEmpty) nameController.text = name;

      // NOTE: we intentionally DO NOT navigate away.
      // Build MECARD payload (exact same format used by the generator backend)
      final company = companyController.text.trim();
      final designation = designationController.text.trim();
      final address = addressController.text.trim();

      final mec = StringBuffer();
      mec.write('MECARD:');
      mec.write('N:${nameController.text};');
      mec.write('TEL:${phoneController.text};');
      if (emailController.text.trim().isNotEmpty) {
        mec.write('EMAIL:${emailController.text.trim()};');
      }
      if (company.isNotEmpty) mec.write('ORG:${company};');
      if (designation.isNotEmpty) mec.write('TITLE:${designation};');
      if (address.isNotEmpty) mec.write('ADR:${address};');
      mec.write(';'); // terminate

      final payload = mec.toString();

      // Save to created history and update UI just like other create flows
      await _saveCreatedEntry(type: 'Contact', value: payload);

      if (!mounted) return;
      setState(() {
        qrData = payload;
        isCreated = true; // show the generated QR UI in this same screen
      });
    } catch (e) {
      // If user cancelled the picker some implementations throw a PlatformException with code 'CANCELED'
      if (e is PlatformException && e.code == 'CANCELED') {
        return;
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to pick contact: $e')));
      }
    }
  }

  // -------------------- Generate QR --------------------
  // NOTE: This function now shows an interstitial (if ready) before revealing the result.
  void _generateQRCode() async {
    // Clear previous errors
    setState(() {
      _nameError = null;
      _phoneError = null;
      _emailError = null;
      _urlNameError = null;
      _urlLinkError = null;
      _wifiNameError = null;
      _wifiPasswordError = null;
    });

    if (selectedType == "Contact") {
      final ok = _validateContact();
      if (!ok) return;

      final company = companyController.text.trim();
      final designation = designationController.text.trim();
      final address = addressController.text.trim();

      qrData =
          "MECARD:"
          "N:${nameController.text};"
          "TEL:${_completePhoneNumber};"
          "EMAIL:${emailController.text};"
          "ORG:${company};"
          "TITLE:${designation};"
          "ADR:${address};;";
    } else if (selectedType == "Phone") {
      // ✅ Phone-only QR (no name/email validation)
      if (_completePhoneNumber == null || !_isPhoneValid) {
        setState(() {
          _phoneError = "Valid phone number is required";
        });
        return;
      }

      qrData = "tel:${_completePhoneNumber}";
    } else if (selectedType == "URL") {
      final ok = _validateUrl();
      if (!ok) return;

      var link = urlLinkController.text.trim();
      if (!link.toLowerCase().startsWith('http')) {
        link = "https://$link";
      }
      qrData = link;
    } else if (selectedType == "Wifi") {
      final ok = _validateWifi();
      if (!ok) return;

      final enc = encryptionValue == 'WPA/WPA2'
          ? 'WPA'
          : (encryptionValue == 'WEP' ? 'WEP' : 'nopass');
      final pwd = wifiPasswordController.text;
      if (encryptionValue.toLowerCase() == 'none' || enc == 'nopass') {
        qrData = "WIFI:S:${wifiNameController.text};T:;P:;;";
      } else {
        qrData = "WIFI:S:${wifiNameController.text};T:${enc};P:${pwd};;";
      }
    } else if (selectedType == "Email") {
      if (emailController.text.isEmpty) {
        // _showError("Email cannot be empty.");
        return;
      }
      qrData = "mailto:${emailController.text}";
    } else if (selectedType == "Text" ||
        selectedType == "Content from clipboard") {
      if (designationController.text.isEmpty) {
        // _showError("Please enter text.");
        return;
      }
      qrData = designationController.text;
    }

    // Save to created history first (same behaviour as before)
    await _saveCreatedEntry(type: selectedType, value: qrData);

    // Then show interstitial (if available) before revealing result
    await _showInterstitialThenReveal();
  }

  Future<void> _showInterstitialThenReveal() async {
    // If interstitial ready, show it and wait until dismissed (or timeout), then reveal.
    if (_isInterstitialReady && _interstitialAd != null) {
      try {
        final completer = Completer<void>();
        // Setup a temporary listener for dismissal
        _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
          onAdShowedFullScreenContent: (ad) {
            debugPrint('[Ads] interstitial showed');
          },
          onAdDismissedFullScreenContent: (ad) {
            debugPrint('[Ads] interstitial dismissed');
            ad.dispose();
            _interstitialAd = null;
            _isInterstitialReady = false;
            // preload next one
            _loadInterstitial();
            if (!completer.isCompleted) completer.complete();
          },
          onAdFailedToShowFullScreenContent: (ad, error) {
            debugPrint('[Ads] interstitial failed to show: $error');
            ad.dispose();
            _interstitialAd = null;
            _isInterstitialReady = false;
            _loadInterstitial();
            if (!completer.isCompleted) completer.complete();
          },
        );

        _interstitialAd!.show();

        // safety timeout in case ad never dismisses/callback doesn't fire
        final timer = Timer(const Duration(seconds: 10), () {
          if (!completer.isCompleted) completer.complete();
        });

        await completer.future;
        timer.cancel();
      } catch (e) {
        debugPrint('[Ads] error showing interstitial: $e');
      }
    }

    // Reveal the generated QR (same behavior as original)
    if (!mounted) return;
    setState(() {
      isCreated = true;
    });
  }

  void _showInlineError(String msg) {
    // kept for unexpected cases; prefer per-field errors above
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
    );
  }

  // -------------------- Download / Share --------------------
  Future<void> _downloadQR() async {
    try {
      RenderRepaintBoundary boundary =
          _qrKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      Uint8List pngBytes = byteData!.buffer.asUint8List();

      final directory = await getApplicationDocumentsDirectory();
      final file = File(
        '${directory.path}/qr_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(pngBytes);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("QR saved to ${file.path.split('/').last}"),
          backgroundColor: SecureScanTheme.accentBlue,
        ),
      );
    } catch (e) {
      _showInlineError("Error saving file: $e");
    }
  }

  Future<void> _shareQR() async {
    try {
      RenderRepaintBoundary boundary =
          _qrKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      Uint8List pngBytes = byteData!.buffer.asUint8List();

      final tempDir = await getTemporaryDirectory();
      final file = await File('${tempDir.path}/shared_qr.png').create();
      await file.writeAsBytes(pngBytes);
      await Share.shareXFiles([XFile(file.path)], text: "My generated QR Code");
    } catch (e) {
      _showInlineError("Error sharing QR: $e");
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    companyController.dispose();
    designationController.dispose();
    addressController.dispose();
    urlNameController.dispose();
    urlLinkController.dispose();
    wifiNameController.dispose();
    wifiPasswordController.dispose();

    _bannerAd?.dispose();
    _interstitialAd?.dispose();

    super.dispose();
  }

  // -------------------- Ad loading --------------------

  void _loadBannerAd() {
    _bannerAd?.dispose();
    _bannerAd = BannerAd(
      adUnitId: _bannerUnitId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          setState(() {
            _isBannerAdReady = true;
            _bannerLoadAttempts = 0;
          });
        },
        onAdFailedToLoad: (ad, error) {
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

  void _loadInterstitial() {
    _interstitialAd?.dispose();
    _interstitialAd = null;
    _isInterstitialReady = false;

    InterstitialAd.load(
      adUnitId: _interstitialUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) {
          _interstitialLoadAttempts = 0;
          _interstitialAd = ad;
          _isInterstitialReady = true;

          // set a basic fullscreen callback to reload next ad when dismissed
          _interstitialAd!.fullScreenContentCallback =
              FullScreenContentCallback(
                onAdShowedFullScreenContent: (ad) =>
                    debugPrint('[Ads] Interstitial shown.'),
                onAdDismissedFullScreenContent: (ad) {
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
          }
        },
      ),
    );
  }

  // -------------------- UI --------------------
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    final adHeight = _isBannerAdReady && _bannerAd != null
        ? _bannerAd!.size.height.toDouble()
        : 0.0;

    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: AppBar(
        backgroundColor: colorScheme.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: colorScheme.onBackground),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Create QR Code",
          style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        actions: [
          // show contact picker icon only when Contact type is selected
          if (selectedType == 'Contact')
            IconButton(
              tooltip: 'Pick contact',
              icon: Icon(
                Icons.contact_page_outlined,
                color: colorScheme.onBackground,
              ),
              onPressed: _pickContactFromDevice,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Column(
          children: [
            if (!isCreated)
              _buildInputForm(textTheme, colorScheme)
            else
              _buildQRResult(textTheme, colorScheme),
            // add bottom padding so content isn't hidden by banner
            SizedBox(height: adHeight + 12),
          ],
        ),
      ),
      bottomNavigationBar: adHeight > 0 && _bannerAd != null
          ? SizedBox(
              width: double.infinity,
              height: adHeight,
              child: Center(
                child: SizedBox(
                  width: _bannerAd!.size.width.toDouble(),
                  height: _bannerAd!.size.height.toDouble(),
                  child: AdWidget(ad: _bannerAd!),
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }

  // ---------------- UI helper widgets (unchanged logic, theme aware) ----------------

  Widget _buildInputForm(TextTheme textTheme, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "QR Type",
          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Text(
            selectedType,
            style: textTheme.bodyLarge?.copyWith(
              color: colorScheme.onBackground,
            ),
          ),
        ),

        const SizedBox(height: 24),
        if (selectedType == "Contact") ...[
          _buildTextFieldWithError(
            label: "Name *",
            controller: nameController,
            textTheme: textTheme,
            colorScheme: colorScheme,
            error: _nameError,
            keyboard: TextInputType.name,
          ),
          IntlPhoneField(
            decoration: InputDecoration(
              labelText: "Phone Number *",
              errorText: _phoneError,
              border: const OutlineInputBorder(),
              suffixIcon: _phoneError != null
                  ? const Icon(Icons.error, color: Colors.red)
                  : null,
            ),
            initialCountryCode: 'IN',
            keyboardType: TextInputType.phone,
            style: TextStyle(color: colorScheme.onBackground),
            dropdownTextStyle: TextStyle(color: colorScheme.onBackground),

            onChanged: (phone) {
              _completePhoneNumber = phone.completeNumber;
              phoneController.text = phone.completeNumber;

              // basic validity check
              _isPhoneValid = phone.number.isNotEmpty;
              _onContactFieldChanged();
            },

            onCountryChanged: (country) {
              debugPrint('Country changed to: ${country.name}');
            },

            validator: (phone) {
              if (phone == null || phone.number.isEmpty) {
                return 'Phone number is required';
              }
              return null; // intl_phone_field validates length internally
            },
          ),

          _buildTextFieldWithError(
            label: "Email *",
            controller: emailController,
            textTheme: textTheme,
            colorScheme: colorScheme,
            error: _emailError,
            keyboard: TextInputType.emailAddress,
            showTrailingErrorIcon: true,
            onChanged: (_) => _onContactFieldChanged(),
            textStyleColor: colorScheme.onBackground,
          ),
          // optional fields
          _buildTextField("Company", companyController, textTheme, colorScheme),
          _buildTextField(
            "Designation",
            designationController,
            textTheme,
            colorScheme,
          ),
          _buildTextField(
            "Address",
            addressController,
            textTheme,
            colorScheme,
            maxLines: 3,
          ),
        ] else if (selectedType == "Email") ...[
          _buildTextField(
            "Email *",
            emailController,
            textTheme,
            colorScheme,
            keyboard: TextInputType.emailAddress,
          ),
        ] else if (selectedType == "Text" ||
            selectedType == "Content from clipboard") ...[
          _buildTextField(
            "Enter Text",
            designationController,
            textTheme,
            colorScheme,
          ),
        ] else if (selectedType == "Phone") ...[
          IntlPhoneField(
            decoration: InputDecoration(
              labelText: "Phone Number *",
              errorText: _phoneError,
              border: const OutlineInputBorder(),
              suffixIcon: _phoneError != null
                  ? const Icon(Icons.error, color: Colors.red)
                  : null,
            ),
            initialCountryCode: 'IN',
            keyboardType: TextInputType.phone,
            style: TextStyle(color: colorScheme.onBackground),
            dropdownTextStyle: TextStyle(color: colorScheme.onBackground),

            onChanged: (phone) {
              _completePhoneNumber = phone.completeNumber;
              phoneController.text = phone.completeNumber;

              // basic validity check
              _isPhoneValid = phone.number.isNotEmpty;
              _onContactFieldChanged();
            },

            onCountryChanged: (country) {
              debugPrint('Country changed to: ${country.name}');
            },

            validator: (phone) {
              if (phone == null || phone.number.isEmpty) {
                return 'Phone number is required';
              }
              return null; // intl_phone_field validates length internally
            },
          ),
        ] else if (selectedType == "URL") ...[
          _buildTextFieldWithError(
            label: "URL Name *",
            controller: urlNameController,
            textTheme: textTheme,
            colorScheme: colorScheme,
            error: _urlNameError,
            keyboard: TextInputType.text,
            onChanged: (_) => _onUrlFieldChanged(),
            textStyleColor: colorScheme.onBackground,
          ),
          _buildTextFieldWithError(
            label: "URL Link *",
            controller: urlLinkController,
            textTheme: textTheme,
            colorScheme: colorScheme,
            error: _urlLinkError,
            keyboard: TextInputType.url,
            hint: "https://example.com",
            onChanged: (_) => _onUrlFieldChanged(),
            textStyleColor: colorScheme.onBackground,
          ),
        ] else ...[
          _buildTextFieldWithError(
            label: "WiFi Name (SSID) *",
            controller: wifiNameController,
            textTheme: textTheme,
            colorScheme: colorScheme,
            error: _wifiNameError,
            onChanged: (_) => _onWifiFieldChanged(),
            textStyleColor: colorScheme.onBackground,
          ),
          const SizedBox(height: 10),
          // Encryption dropdown
          Text("Encryption Type *", style: textTheme.labelMedium),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            value: encryptionValue,
            dropdownColor: colorScheme.surface,
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              filled: true,
              fillColor: colorScheme.surface,
            ),
            items: ["WPA/WPA2", "WEP", "None"].map((e) {
              return DropdownMenuItem(
                value: e,
                child: Text(e, style: TextStyle(color: colorScheme.onSurface)),
              );
            }).toList(),
            onChanged: (v) => setState(() {
              encryptionValue = v ?? 'WPA/WPA2';
              _onWifiFieldChanged();
            }),
          ),
          const SizedBox(height: 12),
          // Password with show/hide
          Text("Password", style: textTheme.labelMedium),
          const SizedBox(height: 6),
          TextField(
            controller: wifiPasswordController,
            keyboardType: TextInputType.visiblePassword,
            obscureText: !_wifiPasswordVisible,
            style: TextStyle(color: colorScheme.onBackground),
            decoration: InputDecoration(
              hintText: encryptionValue.toLowerCase() == 'none'
                  ? "No password required"
                  : null,
              suffixIcon: IconButton(
                icon: Icon(
                  _wifiPasswordVisible
                      ? Icons.visibility
                      : Icons.visibility_off,
                  color: colorScheme.onSurface,
                ),
                onPressed: () => setState(
                  () => _wifiPasswordVisible = !_wifiPasswordVisible,
                ),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colorScheme.outline),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              filled: true,
              fillColor: colorScheme.surface,
            ),
            onChanged: (_) => _onWifiFieldChanged(),
          ),
          if (_wifiPasswordError != null)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                _wifiPasswordError!,
                style: TextStyle(color: Colors.redAccent),
              ),
            ),
        ],
        const SizedBox(height: 40),
        Center(
          child: ElevatedButton(
            onPressed: _canCreate ? _generateQRCode : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: SecureScanTheme.accentBlue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 80, vertical: 14),
            ),
            child: Text(
              "Create",
              style: textTheme.bodyLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQRResult(TextTheme textTheme, ColorScheme colorScheme) {
    return Column(
      children: [
        RepaintBoundary(
          key: _qrKey,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 16),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border.all(color: SecureScanTheme.accentBlue, width: 2),
              borderRadius: BorderRadius.circular(10),
              color: colorScheme.surface,
            ),
            child: QrImageView(
              data: qrData,
              version: QrVersions.auto,
              size: 180,
              // Keep QR background white to ensure readability even in dark mode
              backgroundColor: Colors.white,
            ),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.verified, color: SecureScanTheme.accentBlue, size: 28),
            const SizedBox(width: 6),
            SizedBox(
              width: MediaQuery.of(context).size.width * 0.7,
              child: Text(
                "$selectedType QR Code has been created successfully!",
                style: textTheme.titleMedium?.copyWith(
                  color: SecureScanTheme.accentBlue,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 40),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          margin: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colorScheme.outline),
          ),
          child: _buildDetailsCard(textTheme, colorScheme),
        ),
        const SizedBox(height: 60),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildActionButton("Download", Icons.download, _downloadQR),
            const SizedBox(width: 16),
            _buildActionButton("Share", Icons.share_outlined, _shareQR),
          ],
        ),
      ],
    );
  }

  Widget _buildDetailsCard(TextTheme textTheme, ColorScheme colorScheme) {
    List<Map<String, dynamic>> fields = [];
    if (selectedType == "Contact") {
      fields = [
        {"label": "Name", "value": nameController.text},
        {"label": "Phone", "value": phoneController.text},
        {"label": "Email", "value": emailController.text},
      ];
      // include optional fields if present
      if (companyController.text.trim().isNotEmpty) {
        fields.add({"label": "Company", "value": companyController.text});
      }
      if (designationController.text.trim().isNotEmpty) {
        fields.add({
          "label": "Designation",
          "value": designationController.text,
        });
      }
      if (addressController.text.trim().isNotEmpty) {
        fields.add({"label": "Address", "value": addressController.text});
      }
    } else if (selectedType == "URL") {
      fields = [
        {"label": "Name", "value": urlNameController.text},
        {"label": "Link", "value": urlLinkController.text},
      ];
    } else if (selectedType == "Phone") {
      fields = [
        {"label": "Phone", "value": phoneController.text},
      ];
    } else if (selectedType == "Email") {
      fields = [
        {"label": "Email", "value": emailController.text},
      ];
    } else if (selectedType == "Text" ||
        selectedType == "Content from clipboard") {
      fields = [
        {"label": "Type Name", "value": designationController.text},
      ];
    } else {
      fields = [
        {"label": "WiFi", "value": wifiNameController.text},
        {"label": "Encryption", "value": encryptionValue},
      ];
      if (encryptionValue.toLowerCase() != 'none') {
        fields.add({"label": "Password", "value": wifiPasswordController.text});
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: fields
          .map(
            (f) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                "${f['label']}: ${f['value']}",
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onBackground,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildActionButton(
    String text,
    IconData icon,
    VoidCallback onPressed,
  ) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, color: Colors.white),
      label: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: SecureScanTheme.accentBlue,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 16),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    TextTheme textTheme,
    ColorScheme colorScheme, {
    TextInputType keyboard = TextInputType.text,
    bool isPassword = false,
    String? hint,
    int maxLines = 1,
    TextStyle? textStyle,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 25),
      child: TextField(
        controller: controller,
        keyboardType: keyboard,
        obscureText: isPassword,
        maxLines: maxLines,
        style:
            textStyle ??
            TextStyle(fontSize: 18, color: colorScheme.onBackground),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: textTheme.labelMedium?.copyWith(
            color: colorScheme.onSurface,
            fontSize: 16,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: SecureScanTheme.accentBlue,
              width: 1.5,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: colorScheme.outline),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          filled: true,
          fillColor: colorScheme.surface,
        ),
      ),
    );
  }

  Widget _buildTextFieldWithError({
    required String label,
    required TextEditingController controller,
    required TextTheme textTheme,
    required ColorScheme colorScheme,
    TextInputType keyboard = TextInputType.text,
    bool isPassword = false,
    String? hint,
    int maxLines = 1,
    String? error,
    List<TextInputFormatter>? inputFormatters,
    bool showTrailingErrorIcon = false,
    ValueChanged<String>? onChanged,
    Color textStyleColor = Colors.black,
  }) {
    final hasError = error != null && error.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: controller,
            keyboardType: keyboard,
            obscureText: isPassword,
            maxLines: maxLines,
            inputFormatters: inputFormatters,
            style: TextStyle(
              fontSize: 18,
              color: colorStyleOrDefault(
                textStyleColor,
                Theme.of(context).colorScheme.onBackground,
              ),
            ),
            decoration: InputDecoration(
              labelText: label,
              hintText: hint,
              labelStyle: textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurface,
                fontSize: 16,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: SecureScanTheme.accentBlue,
                  width: 1.5,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colorScheme.outline),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              suffixIcon: showTrailingErrorIcon && hasError
                  ? const Icon(Icons.error_outline, color: Colors.redAccent)
                  : null,
              filled: true,
              fillColor: colorScheme.surface,
            ),
            onChanged: onChanged,
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 6),
              child: Text(
                error,
                style: const TextStyle(color: Colors.redAccent, fontSize: 13),
              ),
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // small helper to allow optional color param passed as Colors.black in many call sites
  Color colorStyleOrDefault(Color passed, Color fallback) {
    // if passed is Colors.black (default) and fallback is light-on-dark, use fallback
    if (passed == Colors.black) return fallback;
    return passed;
  }
}
