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
import 'package:flutter_screenutil/flutter_screenutil.dart';

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
            content: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
            backgroundColor: backgroundColor ?? const Color(0xFF1F1F1F),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
            margin: EdgeInsets.all(16.w),
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
              'bankQrImageUrl': data['bankQrImageUrl'],
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
        fullImageUrl = '${NetworkConfig.getStatus()['cached_url'] ?? 'http://localhost:8080'}$_proofImageUrl';
      }

      return ClipRRect(
        borderRadius: BorderRadius.circular(8.r),
        child: Image.network(
          fullImageUrl,
          width: 80.w,
          height: 80.h,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              width: 80.w,
              height: 80.h,
              color: const Color(0xFF404040),
              child: Center(
                  child: CircularProgressIndicator(
                color: const Color(0xFFFF0000),
                strokeWidth: 2.w,
              )),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: 80.w,
              height: 80.h,
              color: const Color(0xFF404040),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 20),
                  Text('Uploaded',
                      style: TextStyle(fontSize: 8.sp, color: Colors.green)),
                ],
              ),
            );
          },
        ),
      );
    } else if (kIsWeb && _selectedImageFile?.bytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8.r),
        child: Image.memory(
          _selectedImageFile!.bytes!,
          width: 80.w,
          height: 80.h,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: 80.w,
              height: 80.h,
              color: const Color(0xFF404040),
              child: const Icon(Icons.error, color: Colors.red),
            );
          },
        ),
      );
    } else if (!kIsWeb && _selectedImageFile?.path != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8.r),
        child: Image.file(
          File(_selectedImageFile!.path!),
          width: 80.w,
          height: 80.h,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: 80.w,
              height: 80.h,
              color: const Color(0xFF404040),
              child: const Icon(Icons.error, color: Colors.red),
            );
          },
        ),
      );
    } else {
      return Container(
        width: 80.w,
        height: 80.h,
        decoration: BoxDecoration(
          color: const Color(0xFF404040),
          borderRadius: BorderRadius.circular(8.r),
          border: Border.all(color: const Color(0xFF333333)),
        ),
        child: const Icon(
          Icons.image_outlined,
          color: Color(0xFF888888),
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
    return Container(
      padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 12.w),
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F1F),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(
          color: const Color(0xFF333333),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(6.w),
            decoration: BoxDecoration(
              color: const Color(0xFFFF0000),
              borderRadius: BorderRadius.circular(6.r),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF0000).withOpacity(0.4),
                  blurRadius: 8.r,
                  offset: Offset(0, 3.h),
                ),
              ],
            ),
            child: Icon(
              icon,
              size: 16.sp,
              color: Colors.white,
            ),
          ),
          SizedBox(width: 12.w),
          Text(
            '$label: ',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: const Color(0xFF888888),
              fontSize: 14.sp,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey[200],
                fontSize: 14.sp,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showQrImageDialog(String imageUrl) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        String qrUrl = imageUrl;
        if (!qrUrl.startsWith('http')) {
          qrUrl = '${NetworkConfig.getStatus()['cached_url'] ?? 'http://localhost:8080'}$qrUrl';
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
                    color: const Color(0xFF1F1F1F),
                    borderRadius: BorderRadius.circular(12.r),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 8.r,
                        offset: Offset(0, 2.h),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: EdgeInsets.all(16.w),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF0000),
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(12.r),
                            topRight: Radius.circular(12.r),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.qr_code, color: Colors.white, size: 20),
                            SizedBox(width: 8.w),
                            Text(
                              'Mã QR thanh toán',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16.sp,
                                color: Colors.white,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.close, color: Colors.white, size: 20),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.all(16.w),
                        child: InteractiveViewer(
                          child: Image.network(
                            qrUrl,
                            fit: BoxFit.contain,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                height: 300.h,
                                child: Center(
                                  child: CircularProgressIndicator(
                                    color: const Color(0xFFFF0000),
                                    strokeWidth: 2.w,
                                  ),
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                height: 300.h,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.error_outline,
                                      size: 64.sp,
                                      color: const Color(0xFF888888),
                                    ),
                                    SizedBox(height: 16.h),
                                    Text(
                                      'Không thể tải ảnh QR',
                                      style: TextStyle(
                                        color: const Color(0xFF888888),
                                        fontSize: 16.sp,
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
    String base = NetworkConfig.getStatus()['cached_url'] ?? 'http://localhost:8080';
    if (url.startsWith('/')) {
      return base + url;
    }
    return '$base/$url';
  }

  @override
  Widget build(BuildContext context) {
    String qrUrl = '';
    if (_recipientBankInfo != null &&
        _recipientBankInfo!['bankQrImageUrl'] != null) {
      qrUrl = fixImageUrl(_recipientBankInfo!['bankQrImageUrl']);
    }
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8.w),
              decoration: BoxDecoration(
                color: const Color(0xFFFF0000),
                borderRadius: BorderRadius.circular(8.r),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF0000).withOpacity(0.4),
                    blurRadius: 10.r,
                    offset: Offset(0, 4.h),
                  ),
                ],
              ),
              child: const Icon(Icons.favorite, color: Colors.white, size: 20),
            ),
            SizedBox(width: 12.w),
            Text(
              'Donate cho ${widget.toUsername}',
              style: TextStyle(
                fontSize: 20.sp,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
      body: Center(
        child: Container(
          constraints: BoxConstraints(maxWidth: 500.w, maxHeight: 700.h),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(16.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: EdgeInsets.only(bottom: 16.h),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12.r),
                          color: const Color(0xFF1F1F1F),
                          border: Border.all(
                            color: const Color(0xFF333333),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 8.r,
                              offset: Offset(0, 2.h),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(16.w),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(8.w),
                                    decoration: BoxDecoration(
                                      color: _uploadUrl != null
                                          ? const Color(0xFFFF0000)
                                          : Colors.orange,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: (_uploadUrl != null
                                                  ? const Color(0xFFFF0000)
                                                  : Colors.orange)
                                              .withOpacity(0.4),
                                          blurRadius: 10.r,
                                          offset: Offset(0, 4.h),
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      _uploadUrl != null
                                          ? Icons.check_circle
                                          : Icons.warning,
                                      color: Colors.white,
                                      size: 20.sp,
                                    ),
                                  ),
                                  SizedBox(width: 12.w),
                                  Text(
                                    'Connection Status',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey[300],
                                      fontSize: 16.sp,
                                    ),
                                  ),
                                  const Spacer(),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFF0000),
                                      borderRadius: BorderRadius.circular(8.r),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFFFF0000)
                                              .withOpacity(0.4),
                                          blurRadius: 10.r,
                                          offset: Offset(0, 4.h),
                                        ),
                                      ],
                                    ),
                                    child: IconButton(
                                      icon: const Icon(Icons.refresh,
                                          size: 20, color: Colors.white),
                                      onPressed: _refreshConnection,
                                      tooltip: 'Refresh Connection',
                                    ),
                                  ),
                                ],
                              ),
                              if (_debugInfo != null) ...[
                                SizedBox(height: 12.h),
                                Text(
                                  _debugInfo!,
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    color: const Color(0xFF888888),
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 16.h),
                      if (_isLoadingBankInfo) ...[
                        Center(
                            child: CircularProgressIndicator(
                          color: const Color(0xFFFF0000),
                          strokeWidth: 3.w,
                        )),
                      ] else if (_recipientBankInfo != null) ...[
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(20.w),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12.r),
                            color: const Color(0xFF1F1F1F),
                            border: Border.all(
                              color: const Color(0xFF333333),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 8.r,
                                offset: Offset(0, 2.h),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(12.w),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFF0000),
                                      borderRadius: BorderRadius.circular(12.r),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFFFF0000)
                                              .withOpacity(0.4),
                                          blurRadius: 10.r,
                                          offset: Offset(0, 4.h),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(Icons.account_balance,
                                        color: Colors.white, size: 20),
                                  ),
                                  SizedBox(width: 12.w),
                                  Text(
                                    'Thông tin ngân hàng',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18.sp,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 12.h),
                              if (_recipientBankInfo!['bankName'] != null) ...[
                                _buildInfoRow(
                                  icon: Icons.account_balance_wallet,
                                  label: 'Ngân hàng',
                                  value: _recipientBankInfo!['bankName'],
                                ),
                                SizedBox(height: 8.h),
                              ],
                              if (_recipientBankInfo!['bankAccountNumber'] !=
                                  null) ...[
                                _buildInfoRow(
                                  icon: Icons.credit_card,
                                  label: 'Số tài khoản',
                                  value:
                                      _recipientBankInfo!['bankAccountNumber'],
                                ),
                                SizedBox(height: 8.h),
                              ],
                              _buildInfoRow(
                                icon: Icons.person,
                                label: 'Tên tài khoản',
                                value: widget.toUsername,
                              ),
                              SizedBox(height: 20.h),
                              Container(
                                width: double.infinity,
                                padding: EdgeInsets.all(16.w),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12.r),
                                  color: const Color(0xFF1F1F1F),
                                  border: Border.all(
                                    color: const Color(0xFF333333),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      blurRadius: 8.r,
                                      offset: Offset(0, 2.h),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: EdgeInsets.all(8.w),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFF0000),
                                            borderRadius:
                                                BorderRadius.circular(8.r),
                                            boxShadow: [
                                              BoxShadow(
                                                color: const Color(0xFFFF0000)
                                                    .withOpacity(0.4),
                                                blurRadius: 8.r,
                                                offset: Offset(0, 3.h),
                                              ),
                                            ],
                                          ),
                                          child: const Icon(Icons.qr_code,
                                              color: Colors.white, size: 20),
                                        ),
                                        SizedBox(width: 12.w),
                                        Text(
                                          'Mã QR thanh toán',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                            fontSize: 16.sp,
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 12.h),
                                    if (_recipientBankInfo![
                                                'bankQrImageUrl'] !=
                                            null &&
                                        _recipientBankInfo!['bankQrImageUrl']
                                            .toString()
                                            .isNotEmpty) ...[
                                      GestureDetector(
                                        onTap: () => _showQrImageDialog(
                                            _recipientBankInfo!['bankQrImageUrl']),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(12.r),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black
                                                    .withOpacity(0.2),
                                                blurRadius: 8.r,
                                                offset: Offset(0, 2.h),
                                              ),
                                            ],
                                          ),
                                          child: ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(12.r),
                                            child: Image.network(
                                              fixImageUrl(_recipientBankInfo![
                                                  'bankQrImageUrl']),
                                              height: 200.h,
                                              width: 200.w,
                                              fit: BoxFit.contain,
                                              loadingBuilder: (context, child,
                                                  loadingProgress) {
                                                if (loadingProgress == null)
                                                  return child;
                                                return Container(
                                                  height: 200.h,
                                                  width: 200.w,
                                                  color: const Color(0xFF1F1F1F),
                                                  child: Center(
                                                    child:
                                                        CircularProgressIndicator(
                                                      color: const Color(
                                                          0xFFFF0000),
                                                      strokeWidth: 2.w,
                                                    ),
                                                  ),
                                                );
                                              },
                                              errorBuilder:
                                                  (context, error, stackTrace) {
                                                return Container(
                                                  height: 200.h,
                                                  width: 200.w,
                                                  decoration: BoxDecoration(
                                                    color:
                                                        const Color(0xFF1F1F1F),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12.r),
                                                    border: Border.all(
                                                        color: const Color(
                                                            0xFF333333)),
                                                  ),
                                                  child: Column(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment.center,
                                                    children: [
                                                      Icon(
                                                        Icons.broken_image,
                                                        size: 48.sp,
                                                        color: const Color(
                                                            0xFF888888),
                                                      ),
                                                      SizedBox(height: 8.h),
                                                      Text(
                                                        'Không thể tải ảnh QR',
                                                        style: TextStyle(
                                                          color: const Color(
                                                              0xFF888888),
                                                          fontSize: 12.sp,
                                                        ),
                                                        textAlign:
                                                            TextAlign.center,
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                      ),
                                      SizedBox(height: 8.h),
                                      Text(
                                        'Nhấn để xem ảnh QR phóng to',
                                        style: TextStyle(
                                          fontSize: 12.sp,
                                          color: const Color(0xFF888888),
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ] else ...[
                                      Container(
                                        height: 150.h,
                                        width: double.infinity,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF1F1F1F),
                                          borderRadius:
                                              BorderRadius.circular(12.r),
                                          border: Border.all(
                                            color: const Color(0xFF333333),
                                          ),
                                        ),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.qr_code_scanner,
                                              size: 48.sp,
                                              color: const Color(0xFF888888),
                                            ),
                                            SizedBox(height: 8.h),
                                            Text(
                                              'Chưa có ảnh QR ngân hàng',
                                              style: TextStyle(
                                                color: const Color(0xFF888888),
                                                fontSize: 14.sp,
                                                fontWeight: FontWeight.w500,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                            SizedBox(height: 4.h),
                                            Text(
                                              'Vui lòng chuyển khoản theo thông tin trên',
                                              style: TextStyle(
                                                color: const Color(0xFF888888),
                                                fontSize: 12.sp,
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
                              if (_recipientBankInfo!['bankName'] != null ||
                                  _recipientBankInfo!['bankAccountNumber'] !=
                                      null) ...[
                                SizedBox(height: 16.h),
                                Container(
                                  padding: EdgeInsets.all(12.w),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8.r),
                                    color: const Color(0xFF1F1F1F),
                                    border: Border.all(
                                      color: Colors.orange.withOpacity(0.3),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color:
                                            Colors.orange.withOpacity(0.2),
                                        blurRadius: 8.r,
                                        offset: Offset(0, 2.h),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: EdgeInsets.all(8.w),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.withOpacity(0.2),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color:
                                                Colors.orange.withOpacity(0.3),
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.info_outline,
                                          color: Colors.orange,
                                          size: 20.sp,
                                        ),
                                      ),
                                      SizedBox(width: 8.w),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Lưu ý quan trọng:',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                                fontSize: 13.sp,
                                              ),
                                            ),
                                            SizedBox(height: 4.h),
                                            Text(
                                              '• Vui lòng chuyển khoản chính xác theo thông tin trên\n'
                                              '• Quét QR hoặc chuyển khoản thủ công\n'
                                              '• Sau khi chuyển, hãy chụp ảnh màn hình xác nhận\n'
                                              '• Upload ảnh xác nhận để hoàn tất donate',
                                              style: TextStyle(
                                                color: const Color(0xFF888888),
                                                fontSize: 12.sp,
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
                        SizedBox(height: 16.h),
                      ] else ...[
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(16.w),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12.r),
                            color: const Color(0xFF1F1F1F),
                            border: Border.all(
                              color: const Color(0xFF333333),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 8.r,
                                offset: Offset(0, 2.h),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.warning_amber,
                                size: 48.sp,
                                color: Colors.orange,
                              ),
                              SizedBox(height: 12.h),
                              Text(
                                'Chưa có thông tin ngân hàng',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16.sp,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: 8.h),
                              Text(
                                'Người dùng này chưa cập nhật thông tin ngân hàng.\n'
                                'Vui lòng liên hệ trực tiếp để donate.',
                                style: TextStyle(
                                  color: const Color(0xFF888888),
                                  fontSize: 14.sp,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 16.h),
                      ],
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12.r),
                          color: const Color(0xFF1F1F1F),
                          border: Border.all(
                            color: const Color(0xFF333333),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 8.r,
                              offset: Offset(0, 2.h),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _amountController,
                          keyboardType: TextInputType.number,
                          style: TextStyle(color: Colors.white, fontSize: 16.sp),
                          decoration: InputDecoration(
                            labelText: 'Số tiền (VND)',
                            labelStyle: TextStyle(color: const Color(0xFF888888)),
                            prefixIcon: const Icon(Icons.monetization_on,
                                color: Color(0xFFFF0000)),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.r),
                              borderSide: BorderSide.none,
                            ),
                            fillColor: Colors.transparent,
                            filled: true,
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 20.w, vertical: 18.h),
                          ),
                        ),
                      ),
                      SizedBox(height: 16.h),
                      const Text('Ảnh xác nhận chuyển khoản:',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, color: Colors.white)),
                      SizedBox(height: 8.h),
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28.r),
                          color: const Color(0xFFFF0000),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF0000).withOpacity(0.4),
                              blurRadius: 16.r,
                              spreadRadius: 1.r,
                              offset: Offset(0, 6.h),
                            ),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          onPressed: _isUploading ? null : _pickProofImage,
                          icon: const Icon(Icons.add_photo_alternate,
                              color: Colors.white),
                          label: const Text(
                            'Chọn ảnh xác nhận',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(28.r)),
                            padding: EdgeInsets.symmetric(vertical: 16.h),
                          ),
                        ),
                      ),
                      SizedBox(height: 16.h),
                      if (_selectedImageFile != null || _proofImageUrl != null)
                        Container(
                          padding: EdgeInsets.all(12.w),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12.r),
                            color: const Color(0xFF1F1F1F),
                            border: Border.all(
                              color: const Color(0xFF333333),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 8.r,
                                offset: Offset(0, 2.h),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Selected QR Image:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  fontSize: 14.sp,
                                ),
                              ),
                              SizedBox(height: 8.h),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildImagePreview(),
                                  SizedBox(width: 16.w),
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
                                                color: const Color(0xFF888888),
                                                size: 20.sp,
                                              ),
                                              SizedBox(width: 8.w),
                                              Expanded(
                                                child: Text(
                                                  _imageFileName!,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w500,
                                                    fontSize: 15.sp,
                                                    color: Colors.grey[200],
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                          SizedBox(height: 8.h),
                                        ],
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(12.r),
                                                  color:
                                                      const Color(0xFFFF0000),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: const Color(
                                                              0xFFFF0000)
                                                          .withOpacity(0.4),
                                                      blurRadius: 10.r,
                                                      offset: Offset(0, 4.h),
                                                    ),
                                                  ],
                                                ),
                                                child: ElevatedButton.icon(
                                                  icon: const Icon(
                                                      Icons.cloud_upload,
                                                      size: 18,
                                                      color: Colors.white),
                                                  label: Text(
                                                    _proofImageUrl != null
                                                        ? 'Re-upload'
                                                        : 'Upload',
                                                    style: const TextStyle(
                                                        color: Colors.white),
                                                  ),
                                                  onPressed: (_selectedImageFile !=
                                                              null &&
                                                          !_isUploading &&
                                                          _uploadUrl != null)
                                                      ? _uploadProofImage
                                                      : null,
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        Colors.transparent,
                                                    shadowColor:
                                                        Colors.transparent,
                                                    shape:
                                                        RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        12.r)),
                                                    padding: EdgeInsets.symmetric(
                                                        vertical: 8.h),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            SizedBox(width: 8.w),
                                            Container(
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(8.r),
                                                border: Border.all(
                                                    color:
                                                        const Color(0xFF333333)),
                                              ),
                                              child: IconButton(
                                                icon: const Icon(Icons.close,
                                                    size: 18,
                                                    color: Colors.white),
                                                onPressed: _clearSelectedImage,
                                                tooltip: 'Clear Image',
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (_isUploading) ...[
                                          SizedBox(height: 8.h),
                                          const LinearProgressIndicator(
                                            color: Color(0xFFFF0000),
                                            backgroundColor: Color(0xFF333333),
                                          ),
                                          SizedBox(height: 4.h),
                                          Text(
                                            'Uploading image...',
                                            style: TextStyle(
                                                fontSize: 12.sp,
                                                color: const Color(0xFF888888)),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      SizedBox(height: 8.h),
                      Text(
                        'Supported formats: JPG, JPEG, PNG, GIF, WEBP\nMax size: 5MB',
                        style: TextStyle(
                            fontSize: 12.sp, color: const Color(0xFF888888)),
                      ),
                      if (_error != null) ...[
                        SizedBox(height: 8.h),
                        Text(_error!, style: const TextStyle(color: Colors.red)),
                      ],
                    ],
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: const Color(0xFF1F1F1F),
                  border: Border(
                    top: BorderSide(
                      color: const Color(0xFF333333),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(color: const Color(0xFF333333)),
                          color: const Color(0xFF1F1F1F),
                        ),
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            'Hủy',
                            style: TextStyle(
                              color: const Color(0xFF888888),
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 16.w),
                    Expanded(
                      flex: 2,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28.r),
                          color: const Color(0xFFFF0000),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF0000).withOpacity(0.4),
                              blurRadius: 16.r,
                              spreadRadius: 1.r,
                              offset: Offset(0, 6.h),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: _isUploading ? null : _submitDonate,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(28.r)),
                            padding: EdgeInsets.symmetric(vertical: 16.h),
                          ),
                          child: _isUploading
                              ? CircularProgressIndicator(
                                  strokeWidth: 2.w,
                                  color: Colors.white,
                                )
                              : Text(
                                  'Xác nhận Donate',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
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