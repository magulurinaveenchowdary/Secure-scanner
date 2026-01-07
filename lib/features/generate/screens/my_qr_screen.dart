import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MyQrScreen extends StatefulWidget {
  const MyQrScreen({super.key});

  @override
  State<MyQrScreen> createState() => _MyQrScreenState();
}

class _MyQrScreenState extends State<MyQrScreen> {
  static const String _prefsContactKey = 'my_qr_contact_json';
  static const String _prefsQrDataKey = 'my_qr_contact_qr_data';

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _companyController = TextEditingController();

  bool _isLoading = true;
  bool _isEditing = false;
  String? _qrData;
  Map<String, String>? _contact;

  @override
  void initState() {
    super.initState();
    _loadSavedContact();
  }

  Future<void> _loadSavedContact() async {
    final prefs = await SharedPreferences.getInstance();
    final contactJson = prefs.getString(_prefsContactKey);
    final qrData = prefs.getString(_prefsQrDataKey);

    if (contactJson != null && qrData != null) {
      final Map<String, dynamic> decoded = jsonDecode(contactJson);
      _contact = decoded.map((k, v) => MapEntry(k, v.toString()));
      _qrData = qrData;

      _nameController.text = _contact?['name'] ?? '';
      _phoneController.text = _contact?['phone'] ?? '';
      _emailController.text = _contact?['email'] ?? '';
      _companyController.text = _contact?['company'] ?? '';

      _isEditing = false;
    } else {
      // No contact yet: show form
      _isEditing = true;
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _buildVCard(Map<String, String> contact) {
    final name = contact['name'] ?? '';
    final phone = contact['phone'] ?? '';
    final email = contact['email'] ?? '';
    final company = contact['company'] ?? '';

    // Simple vCard 3.0 payload
    return '''
BEGIN:VCARD
VERSION:3.0
N:$name;
FN:$name
TEL;TYPE=CELL:$phone
EMAIL;TYPE=INTERNET:$email
ORG:$company
END:VCARD
'''.trim();
  }

  Future<void> _saveContact() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final email = _emailController.text.trim();
    final company = _companyController.text.trim();

    if (name.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Name and Phone are required'),
        ),
      );
      return;
    }

    final contact = <String, String>{
      'name': name,
      'phone': phone,
      'email': email,
      'company': company,
    };

    final qrData = _buildVCard(contact);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsContactKey, jsonEncode(contact));
    await prefs.setString(_prefsQrDataKey, qrData);

    setState(() {
      _contact = contact;
      _qrData = qrData;
      _isEditing = false;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _companyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My QR'),
        actions: [
          if (!_isLoading && !_isEditing && _contact != null)
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Edit contact',
              onPressed: () {
                setState(() {
                  _isEditing = true;
                });
              },
            ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
          padding: const EdgeInsets.all(20),
          child: _isEditing ? _buildEditForm(textTheme) : _buildQrView(textTheme),
        ),
      ),
    );
  }

  Widget _buildEditForm(TextTheme textTheme) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Contact QR',
            style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Fill your contact details once. Next time you open My QR, your contact QR will be shown automatically.',
            style: textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),

          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Name *',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Phone *',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _companyController,
            decoration: const InputDecoration(
              labelText: 'Company',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saveContact,
              child: const Text('Save & Generate QR', style: TextStyle(color: Colors.white),),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQrView(TextTheme textTheme) {
    if (_qrData == null || _contact == null) {
      // Fallback: if something got corrupted, go back to edit mode
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('No contact QR found'),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _isEditing = true;
                });
              },
              child: const Text('Create Now'),
            ),
          ],
        ),
      );
    }

    final name = _contact!['name'] ?? '';
    final phone = _contact!['phone'] ?? '';
    final email = _contact!['email'] ?? '';
    final company = _contact!['company'] ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'Your Contact QR',
          style: textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),

        // QR code
        Center(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: QrImageView(
              data: _qrData!,
              version: QrVersions.auto,
              size: 230,
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Contact details under QR
        Card(
          elevation: 0,
          color: Colors.grey.shade100,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                if (phone.isNotEmpty)
                  Text(
                    phone,
                    style: textTheme.bodyMedium,
                  ),
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    email,
                    style: textTheme.bodyMedium,
                  ),
                ],
                if (company.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    company,
                    style: textTheme.bodyMedium,
                  ),
                ],
              ],
            ),
          ),
        ),

        const Spacer(),

        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              setState(() {
                _isEditing = true;
              });
            },
            icon: const Icon(Icons.edit),
            label: const Text('Edit Contact'),
          ),
        ),
      ],
    );
  }
}