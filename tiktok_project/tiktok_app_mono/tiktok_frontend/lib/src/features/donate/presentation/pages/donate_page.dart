import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:http_parser/http_parser.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:tiktok_frontend/src/core/config/network_config.dart';
import 'package:tiktok_frontend/src/features/auth/domain/services/auth_service.dart';

class DonatePage extends StatefulWidget {
  final String toUserId;
  final String toUsername;
  const DonatePage({Key? key, required this.toUserId, required this.toUsername}) : super(key: key);
  @override
  State<DonatePage> createState() => _DonatePageState();
}

class _DonatePageState extends State<DonatePage> {
  final _amountController = TextEditingController();
  PlatformFile? _selectedImageFile;
  String? _imageFileName;
  String? _uploadUrl;
  String? _proofImageUrl;
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String? _error;
  Map<String, dynamic>? _recipientBankInfo;
  bool _isLoadingBankInfo = true;
  final List<String> _supportedFormats = ['jpg', 'jpeg', 'png', 'gif', 'webp'];
  final int _maxFileSize = 5 * 1024 * 1024; // 5MB

  @override
  void initState() {
    super.initState();
    _initializeUploadUrl();
    _loadRecipientBankInfo();
  }

  Future<void> _loadRecipientBankInfo() async {
    try {
      final baseUrl = await NetworkConfig.getBaseUrl('/api/users');
      final url = Uri.parse('$baseUrl/${widget.toUserId}/bank-info');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _recipientBankInfo = data;
          _isLoadingBankInfo = false;
        });
      } else {
        setState(() => _isLoadingBankInfo = false);
      }
    } catch (e) {
      setState(() => _isLoadingBankInfo = false);
    }
  }

  Future<void> _initializeUploadUrl() async {
    try {
      _uploadUrl = await NetworkConfig.getBaseUrl('/api/users/upload-image');
    } catch (e) {
      print('Error initializing upload URL: $e');
    }
  }

  Future<void> _pickProofImage() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      if (result != null) {
        final file = result.files.single;
        final extension = file.name.split('.').last.toLowerCase();
        if (!_supportedFormats.contains(extension)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Unsupported format. Use:  [1m${_supportedFormats.join(', ')}')));
          return;
        }
        if (file.size > _maxFileSize) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('File too large. Max 5MB')));
          return;
        }
        setState(() {
          _selectedImageFile = file;
          _imageFileName = file.name;
          _uploadProgress = 0.0;
        });
        await _uploadProofImage();
      }
    } catch (e) {
      setState(() => _error = 'Error selecting image: $e');
    }
  }

  Future<void> _uploadProofImage() async {
    if (_selectedImageFile == null || _uploadUrl == null) return;
    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
      _error = null;
    });
    try {
      var request = http.MultipartRequest('POST', Uri.parse(_uploadUrl!));
      final currentUserId = Provider.of<AuthService>(context, listen: false).currentUser?.id;
      if (currentUserId != null) {
        request.fields['userId'] = currentUserId;
      }
      if (kIsWeb && _selectedImageFile!.bytes != null) {
        request.files.add(http.MultipartFile.fromBytes(
          'imageFile', 
          _selectedImageFile!.bytes!,
          filename: _imageFileName ?? 'image.png',
          contentType: MediaType('image', _imageFileName?.split('.').last ?? 'png'), 
        ));
      } else if (!kIsWeb && _selectedImageFile!.path != null) {
        request.files.add(await http.MultipartFile.fromPath(
          'imageFile',
          _selectedImageFile!.path!,
          filename: _imageFileName,
        ));
      }
      setState(() => _uploadProgress = 0.3);
      final streamedResponse = await request.send().timeout(const Duration(seconds: 30));
      setState(() => _uploadProgress = 0.7);
      final response = await http.Response.fromStream(streamedResponse);
      setState(() => _uploadProgress = 1.0);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['imageUrl'] != null) {
          setState(() {
            _proofImageUrl = data['imageUrl'];
            _error = null;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Upload successful!'), backgroundColor: Colors.green));
        }
      } else {
        throw Exception('Upload failed: ${response.statusCode}');
      }
    } catch (e) {
      setState(() => _error = 'Upload failed: $e');
    } finally {
      setState(() {
        _isUploading = false;
        _uploadProgress = 0.0;
      });
    }
  }

  Future<void> _submitDonate() async {
    setState(() { _error = null; });
    final amount = int.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      setState(() { _error = 'Vui lòng nhập số tiền hợp lệ'; });
      return;
    }
    if (_proofImageUrl == null) {
      setState(() { _error = 'Vui lòng upload ảnh xác nhận'; });
      return;
    }
    setState(() { _isUploading = true; });
    try {
      final baseUrl = await NetworkConfig.getBaseUrl('/api/users');
      final url = Uri.parse('$baseUrl/donate');
      final fromUserId = Provider.of<AuthService>(context, listen: false).currentUser?.id;
      if (fromUserId == null) {
        setState(() { _error = 'Không xác định được tài khoản của bạn'; });
        return;
      }
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'fromUserId': fromUserId,
          'toUserId': widget.toUserId,
          'amount': amount,
          'donateProofImageUrl': _proofImageUrl,
        }),
      );
      if (response.statusCode == 200) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Donate thành công!'), backgroundColor: Colors.green));
      } else {
        setState(() { _error = 'Donate thất bại'; });
      }
    } catch (e) {
      setState(() { _error = 'Lỗi: $e'; });
    } finally {
      setState(() { _isUploading = false; });
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Donate cho ${widget.toUsername}'),
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_isLoadingBankInfo) ...[
                        const Center(child: CircularProgressIndicator()),
                      ] else if (_recipientBankInfo != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Thông tin ngân hàng', 
                                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade700)),
                              const SizedBox(height: 12),
                              if (_recipientBankInfo!['bankName'] != null)
                                Text('Ngân hàng: ${_recipientBankInfo!['bankName']}'),
                              if (_recipientBankInfo!['bankAccountNumber'] != null)
                                Text('Số TK: ${_recipientBankInfo!['bankAccountNumber']}'),
                              Text('Tên TK: ${widget.toUsername}'),
                              if (_recipientBankInfo!['bankQrImageUrl'] != null) ...[
                                const SizedBox(height: 12),
                                Center(
                                  child: Image.network(
                                    _recipientBankInfo!['bankQrImageUrl'],
                                    height: 200,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      TextField(
                        controller: _amountController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Số tiền (VND)',
                          prefixIcon: Icon(Icons.monetization_on),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text('Ảnh xác nhận chuyển khoản:', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: _pickProofImage,
                        icon: const Icon(Icons.add_photo_alternate),
                        label: const Text('Chọn ảnh'),
                      ),
                      if (_selectedImageFile != null || _proofImageUrl != null) ...[
                        const SizedBox(height: 16),
                        if (_proofImageUrl != null)
                          Image.network(_proofImageUrl!, height: 100, fit: BoxFit.cover)
                        else if (kIsWeb && _selectedImageFile!.bytes != null)
                          Image.memory(_selectedImageFile!.bytes!, height: 100, fit: BoxFit.cover)
                        else if (!kIsWeb && _selectedImageFile!.path != null)
                          Image.file(File(_selectedImageFile!.path!), height: 100, fit: BoxFit.cover),
                      ],
                      if (_isUploading) ...[
                        const SizedBox(height: 8),
                        LinearProgressIndicator(value: _uploadProgress),
                        Text('Uploading... ${(_uploadProgress * 100).toInt()}%'),
                      ],
                      if (_error != null) ...[
                        const SizedBox(height: 8),
                        Text(_error!, style: const TextStyle(color: Colors.red)),
                      ],
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(child: TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy'))),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _isUploading ? null : _submitDonate,
                        child: _isUploading 
                          ? const CircularProgressIndicator(strokeWidth: 2) 
                          : const Text('Xác nhận'),
                      ),
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