// tiktok_frontend/lib/src/features/upload/presentation/pages/upload_video_page.dart
import 'dart:convert'; // Cho jsonDecode (nếu cần xử lý response lỗi)
import 'dart:io';     // Cho File (chỉ dùng cho mobile/desktop)
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart'; // Cho MediaType
import 'package:provider/provider.dart';
import 'package:tiktok_frontend/src/features/auth/domain/services/auth_service.dart'; // Để lấy userId

class UploadVideoPage extends StatefulWidget {
  const UploadVideoPage({super.key});

  @override
  State<UploadVideoPage> createState() => _UploadVideoPageState();
}

class _UploadVideoPageState extends State<UploadVideoPage> {
  PlatformFile? _selectedPlatformFile; 
  String? _videoFileName;
  final TextEditingController _descriptionController = TextEditingController();
  bool _isLoading = false;

  // CẤU HÌNH IP CHO ANDROID THẬT
  static const String _backendPort = "8080";
  static const String _realDeviceIP = '10.21.12.255'; // IP thực của máy tính
  static const String _apiPath = "/api/videos/upload";

  // Hàm kiểm tra xem có phải Android emulator không
  bool _isAndroidEmulator() {
    try {
      return Platform.environment.containsKey('ANDROID_EMULATOR') ||
             Platform.environment['ANDROID_EMULATOR'] == 'true';
    } catch (e) {
      print("[UploadPage] Cannot determine if emulator, assuming real device: $e");
      return false;
    }
  }

  String get _uploadUrl {
    if (kIsWeb) {
      return 'http://localhost:$_backendPort$_apiPath';
    } else {
      try {
        if (Platform.isAndroid) {
          // KIỂM TRA XEM CÓ PHẢI ANDROID EMULATOR KHÔNG
          final host = _isAndroidEmulator() ? '10.0.2.2' : _realDeviceIP;
          return 'http://$host:$_backendPort$_apiPath';
        } else if (Platform.isIOS) {
          return 'http://$_realDeviceIP:$_backendPort$_apiPath';
        }
      } catch (e) { 
        print("[UploadPage] Error checking platform for URL: $e");
      }
      return 'http://localhost:$_backendPort$_apiPath';
    }
  }

  Future<void> _pickVideo() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: false,
      );

      if (result != null) {
        setState(() {
          _selectedPlatformFile = result.files.single;
          _videoFileName = _selectedPlatformFile!.name;
          print('Video selected: $_videoFileName');
          if (!kIsWeb && _selectedPlatformFile!.path != null) {
             print('Video path (mobile/desktop): ${_selectedPlatformFile!.path}');
          } else if (kIsWeb && _selectedPlatformFile!.bytes != null) {
             print('Video bytes selected (web): ${_selectedPlatformFile!.bytes!.length}');
          }
        });
      } else {
        print('No video selected.');
        setState(() {
          _selectedPlatformFile = null;
          _videoFileName = null;
        });
      }
    } catch (e) {
      print('Error picking video: $e');
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi chọn video: $e')),
        );
      }
    }
  }

  Future<void> _uploadVideo() async {
    if (_selectedPlatformFile == null) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn một video để upload.')),
      );
      }
      return;
    }
    if (_descriptionController.text.isEmpty) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập mô tả cho video.')),
      );
      }
      return;
    }

    setState(() => _isLoading = true);

    String userIdToUpload;
    try {
        final authService = Provider.of<AuthService>(context, listen: false); 
        if (!authService.isAuthenticated || authService.currentUser == null) {
          if(mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Bạn cần đăng nhập để upload video.')),
          );
          }
          setState(() => _isLoading = false);
          return;
        }
        userIdToUpload = authService.currentUser!.id; 
    } catch (e) {
        print("[UploadPage] Error getting user from AuthService: $e. Upload aborted.");
         if(mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Không thể xác thực người dùng. Vui lòng thử đăng nhập lại.')),
        );
         }
        setState(() => _isLoading = false);
        return;
    }

    var request = http.MultipartRequest('POST', Uri.parse(_uploadUrl));
    request.fields['description'] = _descriptionController.text;
    request.fields['userId'] = userIdToUpload;

    print('[UploadPage] Upload URL: $_uploadUrl');
    print('[UploadPage] Platform info: ${kIsWeb ? "Web" : Platform.operatingSystem}, isEmulator: ${!kIsWeb ? _isAndroidEmulator() : "N/A"}');

    if (kIsWeb && _selectedPlatformFile!.bytes != null) {
      request.files.add(http.MultipartFile.fromBytes(
        'videoFile', 
        _selectedPlatformFile!.bytes!,
        filename: _videoFileName ?? 'video_from_web.mp4',
        contentType: MediaType('video', _videoFileName?.split('.').last ?? 'mp4'), 
      ));
    } else if (!kIsWeb && _selectedPlatformFile!.path != null) {
      request.files.add(
        await http.MultipartFile.fromPath(
          'videoFile',
          _selectedPlatformFile!.path!,
          filename: _videoFileName ?? _selectedPlatformFile!.path!.split(Platform.pathSeparator).last,
          contentType: MediaType('video', _selectedPlatformFile!.path!.split('.').lastOrNull ?? 'mp4'),
        ),
      );
    } else {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không tìm thấy file video hợp lệ để upload.')),
      );
      }
      setState(() => _isLoading = false);
      return;
    }
    
    try {
      print('[UploadPage] Sending upload request to $_uploadUrl with fields: ${request.fields} and file: ${request.files.isNotEmpty ? request.files.first.filename : "no file"}');
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      print('[UploadPage] Upload Response status: ${response.statusCode}');
      print('[UploadPage] Upload Response body: ${response.body}');

      if (!mounted) return; 

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Video đã được upload thành công!'), backgroundColor: Colors.green),
        );
        setState(() {
          _selectedPlatformFile = null;
          _videoFileName = null;
          _descriptionController.clear();
        });
        Navigator.of(context).pop(); 
      } else {
        String errorMessage = 'Upload video thất bại. Status: ${response.statusCode}';
        try {
          final errorData = jsonDecode(response.body);
          errorMessage = errorData['error'] ?? errorMessage;
        } catch (_) {} 
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      print('[UploadPage] Error uploading video: $e');
      if (mounted) {
        String errorMessage = 'Lỗi khi upload video: $e';
        if (e.toString().contains('Connection refused') || 
            e.toString().contains('Failed host lookup')) {
          errorMessage = 'Không thể kết nối đến server. Kiểm tra kết nối mạng.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Video Mới'),
        actions: [
          if (!_isLoading)
            IconButton(
              icon: const Icon(Icons.check_circle_outline),
              onPressed: (_selectedPlatformFile != null && _descriptionController.text.isNotEmpty) ? _uploadVideo : null, // Chỉ enable khi có file và mô tả
              tooltip: 'Upload Video',
            )
          else
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
            )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Debug info for connection
            if (!kIsWeb) ...[
              Container(
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Debug Info:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Platform: ${Platform.operatingSystem}',
                      style: TextStyle(fontSize: 12, color: Colors.blue.shade600),
                    ),
                    Text(
                      'Is Emulator: ${_isAndroidEmulator()}',
                      style: TextStyle(fontSize: 12, color: Colors.blue.shade600),
                    ),
                    Text(
                      'Upload URL: $_uploadUrl',
                      style: TextStyle(fontSize: 12, color: Colors.blue.shade600),
                    ),
                  ],
                ),
              ),
            ],
            
            ElevatedButton.icon(
              onPressed: _pickVideo,
              icon: const Icon(Icons.video_library_outlined),
              label: const Text('Chọn Video từ Thiết Bị'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                textStyle: const TextStyle(fontSize: 16)
              ),
            ),
            const SizedBox(height: 20),
            if (_selectedPlatformFile != null)
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Video đã chọn:',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.movie_creation_outlined, color: Theme.of(context).hintColor),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _videoFileName ?? 'Không có tên file',
                              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        height: 200,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.black12,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(child: Icon(Icons.play_circle_fill_rounded, size: 60, color: Colors.grey[400])),
                        // TODO: Hiển thị video preview thực tế bằng video_player nếu là web (cho bytes)
                        // hoặc nếu là mobile và có path. Điều này sẽ phức tạp hơn.
                      ),
                    ],
                  ),
                ),
              ),
             if (_selectedPlatformFile != null) const SizedBox(height: 20),
            TextFormField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: 'Mô tả video',
                hintText: 'Thêm mô tả, #hashtags...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
                prefixIcon: const Icon(Icons.notes_outlined),
              ),
              maxLines: 4,
              maxLength: 250,
              onChanged: (_) => setState(() {}), // Để cập nhật trạng thái nút Upload
            ),
            const SizedBox(height: 30),
            if (_isLoading)
              const Center(child: Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(),
              ))
            else 
              ElevatedButton.icon(
                icon: const Icon(Icons.cloud_upload_rounded),
                label: const Text('Đăng Video'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                ),
                // Chỉ bật nút khi đã chọn file và có mô tả
                onPressed: (_selectedPlatformFile != null && _descriptionController.text.isNotEmpty) ? _uploadVideo : null,
              ),
          ],
        ),
      ),
    );
  }
}