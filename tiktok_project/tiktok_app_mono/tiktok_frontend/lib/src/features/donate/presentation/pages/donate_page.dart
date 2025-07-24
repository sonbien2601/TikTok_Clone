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
import 'package:intl/intl.dart';

class DonatePage extends StatefulWidget {
  final String toUserId;
  final String toUsername;
  const DonatePage({Key? key, required this.toUserId, required this.toUsername})
      : super(key: key);
  @override
  State<DonatePage> createState() => _DonatePageState();
}

class _DonatePageState extends State<DonatePage> {
  final _amountController = TextEditingController();

  PlatformFile? _selectedImageFile;
  String? _imageFileName;
  String? _uploadUrl;
  String? _proofImageUrl;
  String? _debugInfo;
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

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {Color? backgroundColor}) {
    if (!mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      try {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: backgroundColor,
            duration: const Duration(seconds: 3),
          ),
        );
      } catch (e) {
        print('[DonatePage] SnackBar error: $e - Message: $message');
      }
    });
  }

  Future<void> _initializeUploadUrl() async {
    try {
      _uploadUrl = await NetworkConfig.getBaseUrl('/api/users/upload-image');
      final status = NetworkConfig.getStatus();

      if (mounted) {
        setState(() {
          _debugInfo = 'Platform: ${_getPlatformName()}\n'
              'Upload URL: $_uploadUrl\n'
              'Cached URL: ${status['cached_url']}\n'
              'Cache Valid: ${status['cache_valid']}';
        });
      }

    } catch (e) {
      print('[DonatePage] Error initializing upload URL: $e');
      if (mounted) {
        setState(() {
          _debugInfo = 'Error: Could not initialize upload URL\n$e';
        });
      }
    }
  }

  String _getPlatformName() {
    if (kIsWeb) return 'Web';
    if (!kIsWeb) {
      try {
        if (Platform.isAndroid) return 'Android';
        if (Platform.isIOS) return 'iOS';
        return Platform.operatingSystem;
      } catch (e) {
        return 'Unknown';
      }
    }
    return 'Unknown';
  }

// Trong DonatePage, sửa method _loadRecipientBankInfo()
  Future<void> _loadRecipientBankInfo() async {
    try {
      final baseUrl = await NetworkConfig.getBaseUrl('/api/users');
      final url = Uri.parse('$baseUrl/${widget.toUserId}');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _recipientBankInfo = {
              'bankAccountNumber': data['bankAccountNumber'],
              'bankName': data['bankName'],
              'bankQrImageUrl': data['bankQrImageUrl'], // Chỉ lấy QR image
            };
            _isLoadingBankInfo = false;
          });
        }
      } else {
        if (mounted) {
          setState(() => _isLoadingBankInfo = false);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingBankInfo = false);
      }
    }
  }

  String _getFileSize(PlatformFile file) {
    int bytes = kIsWeb ? (file.bytes?.length ?? 0) : file.size;
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  bool _isValidImageFile(PlatformFile file) {
    final String fileName = file.name.toLowerCase();
    final List<String> validExtensions = ['jpg', 'jpeg', 'png', 'gif', 'webp'];

    bool hasValidExtension =
        validExtensions.any((ext) => fileName.endsWith('.$ext'));
    if (!hasValidExtension) {
      _showSnackBar('Chỉ hỗ trợ file ảnh: ${validExtensions.join(', ')}',
          backgroundColor: Colors.red);
      return false;
    }

    int fileSize = kIsWeb ? (file.bytes?.length ?? 0) : (file.size);
    if (fileSize > _maxFileSize) {
      _showSnackBar(
          'File quá lớn. Giới hạn: ${_maxFileSize ~/ (1024 * 1024)}MB',
          backgroundColor: Colors.red);
      return false;
    }

    if (fileSize == 0) {
      _showSnackBar('File rỗng hoặc không hợp lệ', backgroundColor: Colors.red);
      return false;
    }

    return true;
  }

  Future<void> _pickProofImage() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'gif', 'webp'],
        allowMultiple: false,
      );

      if (result != null) {
        final file = result.files.single;

        if (!_isValidImageFile(file)) {
          return;
        }

        if (mounted) {
          setState(() {
            _selectedImageFile = file;
            _imageFileName = file.name;
            _proofImageUrl = null;
            _error = null;
            if (!kIsWeb && file.path != null) {
            } else if (kIsWeb && file.bytes != null) {
            }
          });
        }

        await _uploadProofImage();
      } else {
        if (mounted) {
          setState(() {
            _selectedImageFile = null;
            _imageFileName = null;
          });
        }
      }
    } catch (e) {
      print('[DonatePage] Error picking image: $e');
      _showSnackBar('Lỗi khi chọn ảnh: $e', backgroundColor: Colors.red);
      if (mounted) {
        setState(() => _error = 'Error selecting image: $e');
      }
    }
  }

  Future<void> _uploadProofImage() async {
    if (_selectedImageFile == null) {
      _showSnackBar('Vui lòng chọn ảnh để upload.');
      return;
    }

    if (_uploadUrl == null) {
      await _initializeUploadUrl();
      if (_uploadUrl == null) {
        _showSnackBar('Không xác định được upload URL.');
        return;
      }
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
      _error = null;
    });

    var request = http.MultipartRequest('POST', Uri.parse(_uploadUrl!));
    final currentUserId =
        Provider.of<AuthService>(context, listen: false).currentUser?.id;
    if (currentUserId != null) {
      request.fields['userId'] = currentUserId;
    }

    if (kIsWeb && _selectedImageFile!.bytes != null) {
      request.files.add(http.MultipartFile.fromBytes(
        'imageFile',
        _selectedImageFile!.bytes!,
        filename: _imageFileName ?? 'image_from_web.png',
        contentType:
            MediaType('image', _imageFileName?.split('.').last ?? 'png'),
      ));
    } else if (!kIsWeb && _selectedImageFile!.path != null) {
      request.files.add(
        await http.MultipartFile.fromPath(
          'imageFile',
          _selectedImageFile!.path!,
          filename: _imageFileName ??
              _selectedImageFile!.path!.split(Platform.pathSeparator).last,
          contentType:
              MediaType('image', _selectedImageFile!.path!.split('.').last),
        ),
      );
    } else {
      _showSnackBar('Không tìm thấy file ảnh hợp lệ để upload.');
      if (mounted) {
        setState(() => _isUploading = false);
      }
      return;
    }

    try {
      final streamedResponse =
          await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamedResponse);

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['imageUrl'] != null) {
          final imageUrl = data['imageUrl'].toString().trim();

          if (imageUrl.isNotEmpty) {
            setState(() {
              _proofImageUrl = imageUrl;
              _selectedImageFile = null;
              _imageFileName = null;
            });
            _showSnackBar('Ảnh đã upload thành công!',
                backgroundColor: Colors.green);
          } else {
            _showSnackBar('Server trả về URL rỗng',
                backgroundColor: Colors.red);
          }
        } else {
          _showSnackBar('Server không trả về link ảnh',
              backgroundColor: Colors.red);
        }
      } else {
        String errorMessage =
            'Upload ảnh thất bại. Status: ${response.statusCode}';
        try {
          final errorData = jsonDecode(response.body);
          errorMessage = errorData['error'] ?? errorMessage;
        } catch (_) {}
        _showSnackBar(errorMessage, backgroundColor: Colors.red);
      }
    } catch (e) {
      print('[DonatePage] Error uploading image: $e');
      String errorMessage = 'Lỗi upload ảnh: $e';
      if (e.toString().contains('Connection refused') ||
          e.toString().contains('Failed host lookup') ||
          e.toString().contains('No address associated with hostname')) {
        errorMessage =
            'Cannot connect to server. Please check your network connection.';
        NetworkConfig.clearCache();
      }
      _showSnackBar(errorMessage, backgroundColor: Colors.red);
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadProgress = 0.0;
        });
      }
    }
  }

  Widget _buildImagePreview() {
    if (_proofImageUrl != null) {
      String fullImageUrl = _proofImageUrl!;
      if (!fullImageUrl.startsWith('http')) {
        fullImageUrl = 'http://localhost:8080$_proofImageUrl';
      }

      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          fullImageUrl,
          width: 80,
          height: 80,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              width: 80,
              height: 80,
              color: Colors.grey[200],
              child: const Center(child: CircularProgressIndicator()),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: 80,
              height: 80,
              color: Colors.grey[200],
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 20),
                  Text('Uploaded',
                      style: TextStyle(fontSize: 8, color: Colors.green)),
                ],
              ),
            );
          },
        ),
      );
    } else if (kIsWeb && _selectedImageFile?.bytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(
          _selectedImageFile!.bytes!,
          width: 80,
          height: 80,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: 80,
              height: 80,
              color: Colors.grey[200],
              child: const Icon(Icons.error, color: Colors.red),
            );
          },
        ),
      );
    } else if (!kIsWeb && _selectedImageFile?.path != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          File(_selectedImageFile!.path!),
          width: 80,
          height: 80,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: 80,
              height: 80,
              color: Colors.grey[200],
              child: const Icon(Icons.error, color: Colors.red),
            );
          },
        ),
      );
    } else {
      return Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: const Icon(
          Icons.image_outlined,
          color: Colors.grey,
          size: 40,
        ),
      );
    }
  }

  Future<void> _refreshConnection() async {
    if (mounted) {
      setState(() {
        _debugInfo = 'Refreshing connection...';
      });
    }

    NetworkConfig.clearCache();
    await _initializeUploadUrl();

    _showSnackBar('Connection refreshed');
  }

  void _clearSelectedImage() {
    if (mounted) {
      setState(() {
        _selectedImageFile = null;
        _imageFileName = null;
        _proofImageUrl = null;
      });
    }
  }

  Future<void> _submitDonate() async {
    if (mounted) {
      setState(() {
        _error = null;
      });
    }

    final amount = int.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      if (mounted) {
        setState(() {
          _error = 'Vui lòng nhập số tiền hợp lệ';
        });
      }
      return;
    }

    if (_proofImageUrl == null) {
      if (mounted) {
        setState(() {
          _error = 'Vui lòng upload ảnh xác nhận';
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isUploading = true;
      });
    }

    try {
      final baseUrl = await NetworkConfig.getBaseUrl('/api/users');
      final url = Uri.parse('$baseUrl/donate');
      final fromUserId =
          Provider.of<AuthService>(context, listen: false).currentUser?.id;

      if (fromUserId == null) {
        if (mounted) {
          setState(() {
            _error = 'Không xác định được tài khoản của bạn';
          });
        }
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

      if (!mounted) return;

      if (response.statusCode == 200) {
        Navigator.of(context).pop(true);
      } else {
        setState(() {
          _error = 'Donate thất bại';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Lỗi: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 16,
          color: Colors.blue.shade600,
        ),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade700,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  void _showQrImageDialog(String imageUrl) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        String qrUrl = imageUrl;
        if (!qrUrl.startsWith('http')) {
          qrUrl = 'http://localhost:8080$qrUrl';
        }
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Stack(
            children: [
              Center(
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.9,
                    maxHeight: MediaQuery.of(context).size.height * 0.8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(12),
                            topRight: Radius.circular(12),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.qr_code, color: Colors.blue.shade700),
                            const SizedBox(width: 8),
                            Text(
                              'Mã QR thanh toán',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.blue.shade700,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: InteractiveViewer(
                          child: Image.network(
                            qrUrl,
                            fit: BoxFit.contain,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                height: 300,
                                child: const Center(
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                height: 300,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.error_outline,
                                      size: 64,
                                      color: Colors.grey[400],
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Không thể tải ảnh QR',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String fixImageUrl(String url) {
    if (url.isEmpty) return url;
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    // Nếu là đường dẫn tương đối, nối domain phù hợp
    String base;
    if (kIsWeb) {
      base = 'http://localhost:8080';
    } else {
      base = 'http://10.0.2.2:8080';
    }
    if (url.startsWith('/')) {
      return base + url;
    }
    return base + '/' + url;
  }

  @override
  Widget build(BuildContext context) {
    String qrUrl = '';
    if (_recipientBankInfo != null && _recipientBankInfo!['bankQrImageUrl'] != null) {
      qrUrl = _recipientBankInfo!['bankQrImageUrl'];
      if (!qrUrl.startsWith('http')) {
        qrUrl = 'http://localhost:8080$qrUrl';
      }
    }
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
                      Card(
                        color: _uploadUrl != null
                            ? Colors.green.shade50
                            : Colors.orange.shade50,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    _uploadUrl != null
                                        ? Icons.check_circle
                                        : Icons.warning,
                                    color: _uploadUrl != null
                                        ? Colors.green
                                        : Colors.orange,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Connection Status',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: _uploadUrl != null
                                          ? Colors.green.shade700
                                          : Colors.orange.shade700,
                                    ),
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    icon: const Icon(Icons.refresh, size: 20),
                                    onPressed: _refreshConnection,
                                    tooltip: 'Refresh Connection',
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              if (_debugInfo != null)
                                Text(
                                  _debugInfo!,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: _uploadUrl != null
                                        ? Colors.green.shade600
                                        : Colors.orange.shade600,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
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
                              Row(
                                children: [
                                  Icon(Icons.account_balance,
                                      color: Colors.blue.shade700),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Thông tin ngân hàng',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Colors.blue.shade700,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              if (_recipientBankInfo!['bankName'] != null) ...[
                                _buildInfoRow(
                                  icon: Icons.account_balance_wallet,
                                  label: 'Ngân hàng',
                                  value: _recipientBankInfo!['bankName'],
                                ),
                                const SizedBox(height: 8),
                              ],
                              if (_recipientBankInfo!['bankAccountNumber'] !=
                                  null) ...[
                                _buildInfoRow(
                                  icon: Icons.credit_card,
                                  label: 'Số tài khoản',
                                  value:
                                      _recipientBankInfo!['bankAccountNumber'],
                                ),
                                const SizedBox(height: 8),
                              ],
                              _buildInfoRow(
                                icon: Icons.person,
                                label: 'Tên tài khoản',
                                value: widget.toUsername,
                              ),
                              const SizedBox(height: 20),
                              // CHỈ GIỮ phần QR - BỎ TOÀN BỘ phần bankImageUrl
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.blue.shade200),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.qr_code, color: Colors.blue.shade700),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Mã QR thanh toán',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: Colors.blue.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    if (_recipientBankInfo!['bankQrImageUrl'] != null &&
                                        _recipientBankInfo!['bankQrImageUrl'].toString().isNotEmpty) ...[
                                      GestureDetector(
                                        onTap: () => _showQrImageDialog(_recipientBankInfo!['bankQrImageUrl']),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(12),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(0.1),
                                                blurRadius: 8,
                                                offset: const Offset(0, 4),
                                              ),
                                            ],
                                          ),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(12),
                                            child: Image.network(
                                              fixImageUrl(_recipientBankInfo!['bankQrImageUrl']),
                                              height: 200,
                                              width: 200,
                                              fit: BoxFit.contain,
                                              loadingBuilder: (context, child, loadingProgress) {
                                                if (loadingProgress == null) return child;
                                                return Container(
                                                  height: 200,
                                                  width: 200,
                                                  color: Colors.grey[100],
                                                  child: const Center(
                                                    child: CircularProgressIndicator(),
                                                  ),
                                                );
                                              },
                                              errorBuilder: (context, error, stackTrace) {
                                                return Container(
                                                  height: 200,
                                                  width: 200,
                                                  decoration: BoxDecoration(
                                                    color: Colors.grey[100],
                                                    borderRadius: BorderRadius.circular(12),
                                                    border: Border.all(color: Colors.grey[300]!),
                                                  ),
                                                  child: Column(
                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                    children: [
                                                      Icon(
                                                        Icons.broken_image,
                                                        size: 48,
                                                        color: Colors.grey[400],
                                                      ),
                                                      const SizedBox(height: 8),
                                                      Text(
                                                        'Không thể tải ảnh QR',
                                                        style: TextStyle(
                                                          color: Colors.grey[600],
                                                          fontSize: 12,
                                                        ),
                                                        textAlign: TextAlign.center,
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Nhấn để xem ảnh QR phóng to',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ] else ...[
                                      Container(
                                        height: 150,
                                        width: double.infinity,
                                        decoration: BoxDecoration(
                                          color: Colors.grey[100],
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: Colors.grey[300]!,
                                            style: BorderStyle.solid,
                                          ),
                                        ),
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.qr_code_scanner,
                                              size: 48,
                                              color: Colors.grey[400],
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              'Chưa có ảnh QR ngân hàng',
                                              style: TextStyle(
                                                color: Colors.grey[600],
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Vui lòng chuyển khoản theo thông tin trên',
                                              style: TextStyle(
                                                color: Colors.grey[500],
                                                fontSize: 12,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              // Lưu ý quan trọng 
                              if (_recipientBankInfo!['bankName'] != null ||
                                  _recipientBankInfo!['bankAccountNumber'] != null) ...[
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.amber.shade200),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        Icons.info_outline,
                                        color: Colors.amber.shade700,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Lưu ý quan trọng:',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.amber.shade700,
                                                fontSize: 13,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '• Vui lòng chuyển khoản chính xác theo thông tin trên\n'
                                              '• Quét QR hoặc chuyển khoản thủ công\n'
                                              '• Sau khi chuyển, hãy chụp ảnh màn hình xác nhận\n'
                                              '• Upload ảnh xác nhận để hoàn tất donate',
                                              style: TextStyle(
                                                color: Colors.amber.shade700,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ] else ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.orange.shade200),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.warning_amber,
                                size: 48,
                                color: Colors.orange.shade600,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Chưa có thông tin ngân hàng',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.orange.shade700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Người dùng này chưa cập nhật thông tin ngân hàng.\n'
                                'Vui lòng liên hệ trực tiếp để donate.',
                                style: TextStyle(
                                  color: Colors.orange.shade600,
                                  fontSize: 14,
                                ),
                                textAlign: TextAlign.center,
                              ),
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
                      const Text('Ảnh xác nhận chuyển khoản:',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: _isUploading ? null : _pickProofImage,
                        icon: const Icon(Icons.add_photo_alternate),
                        label: const Text('Chọn ảnh'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          textStyle: const TextStyle(fontSize: 16),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_selectedImageFile != null || _proofImageUrl != null)
                        Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Selected QR Image:',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildImagePreview(),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          if (_imageFileName != null) ...[
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.image,
                                                  color: Theme.of(context)
                                                      .hintColor,
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    _imageFileName!,
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      fontSize: 15,
                                                    ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                          ],
                                          Row(
                                            children: [
                                              Expanded(
                                                child: ElevatedButton.icon(
                                                  icon: const Icon(
                                                      Icons.cloud_upload,
                                                      size: 18),
                                                  label: Text(
                                                      _proofImageUrl != null
                                                          ? 'Re-upload'
                                                          : 'Upload'),
                                                  onPressed:
                                                      (_selectedImageFile !=
                                                                  null &&
                                                              !_isUploading &&
                                                              _uploadUrl !=
                                                                  null)
                                                          ? _uploadProofImage
                                                          : null,
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        Theme.of(context)
                                                            .primaryColor,
                                                    foregroundColor:
                                                        Colors.white,
                                                    padding: const EdgeInsets
                                                        .symmetric(vertical: 8),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              IconButton(
                                                icon: const Icon(Icons.close,
                                                    size: 18),
                                                onPressed: _clearSelectedImage,
                                                tooltip: 'Clear Image',
                                              ),
                                            ],
                                          ),
                                          if (_isUploading) ...[
                                            const SizedBox(height: 8),
                                            const LinearProgressIndicator(),
                                            const SizedBox(height: 4),
                                            const Text('Uploading image...',
                                                style: TextStyle(fontSize: 12)),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),
                      Text(
                        'Supported formats: JPG, JPEG, PNG, GIF, WEBP\nMax size: 5MB',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 8),
                        Text(_error!,
                            style: const TextStyle(color: Colors.red)),
                      ],
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                        child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Hủy'))),
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
