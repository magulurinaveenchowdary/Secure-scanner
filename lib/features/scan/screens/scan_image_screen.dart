import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ScanImageScreen extends StatefulWidget {
  const ScanImageScreen({super.key});

  @override
  State<ScanImageScreen> createState() => _ScanImageScreenState();
}

class _ScanImageScreenState extends State<ScanImageScreen> {
  final ImagePicker _picker = ImagePicker();
  final MobileScannerController _controller = MobileScannerController();

  XFile? _selectedImage;
  bool _isScanning = false;
  String? _resultText;

  Future<void> _pickAndScanImage() async {
    setState(() {
      _resultText = null;
    });

    final image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    setState(() {
      _selectedImage = image;
      _isScanning = true;
    });

    try {
      final capture = await _controller.analyzeImage(image.path);
      if (capture != null && capture.barcodes.isNotEmpty) {
        final first = capture.barcodes.first;
        final value = first.rawValue ?? '';
        setState(() {
          _resultText = value.isEmpty
              ? 'QR / Barcode detected, but has no data.'
              : value;
        });
      } else {
        setState(() {
          _resultText = 'No QR / Barcode found in this image.';
        });
      }
    } catch (e) {
      setState(() {
        _resultText = 'Failed to scan image: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan from Image'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Text(
                'Pick an image from your gallery and we will try to detect any QR or Barcode present in it.',
                style: textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),

              // Pick button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isScanning ? null : _pickAndScanImage,
                  icon: const Icon(Icons.photo_library_outlined,color: Colors.white,),
                  label: Text(
                    _isScanning ? 'Scanning...' : 'Choose Image from Gallery',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Preview selected image
              if (_selectedImage != null)
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      File(_selectedImage!.path),
                      fit: BoxFit.contain,
                    ),
                  ),
                )
              else
                Expanded(
                  child: Center(
                    child: Text(
                      'No image selected yet.',
                      style: textTheme.bodyMedium?.copyWith(
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 16),

              // Result
              if (_resultText != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.grey.shade300,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Result',
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SelectableText(
                        _resultText!,
                        style: textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}