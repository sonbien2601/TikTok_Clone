// tiktok_frontend/lib/src/features/upload/presentation/pages/upload_video_page.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:provider/provider.dart';
import 'package:tiktok_frontend/src/features/auth/domain/services/auth_service.dart';
import 'package:tiktok_frontend/src/core/config/network_config.dart';

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
  String? _uploadUrl;
  String? _debugInfo;

  @override
  void initState() {
    super.initState();
    _initializeUploadUrl();
  }

  Future<void> _initializeUploadUrl() async {
    try {
      _uploadUrl = await NetworkConfig.getBaseUrl('/api/videos/upload');
      final status = NetworkConfig.getStatus();
      
      setState(() {
        _debugInfo = 'Platform: ${_getPlatformName()}\n'
                   'Upload URL: $_uploadUrl\n'
                   'Cached URL: ${status['cached_url']}\n'
                   'Cache Valid: ${status['cache_valid']}';
      });
      
      print('[UploadPage] Initialized upload URL: $_uploadUrl');
    } catch (e) {
      print('[UploadPage] Error initializing upload URL: $e');
      setState(() {
        _debugInfo = 'Error: Could not initialize upload URL\n$e';
      });
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
          print('[UploadPage] Video selected: $_videoFileName');
          if (!kIsWeb && _selectedPlatformFile!.path != null) {
             print('[UploadPage] Video path (mobile/desktop): ${_selectedPlatformFile!.path}');
          } else if (kIsWeb && _selectedPlatformFile!.bytes != null) {
             print('[UploadPage] Video bytes selected (web): ${_selectedPlatformFile!.bytes!.length}');
          }
        });
      } else {
        print('[UploadPage] No video selected.');
        setState(() {
          _selectedPlatformFile = null;
          _videoFileName = null;
        });
      }
    } catch (e) {
      print('[UploadPage] Error picking video: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error selecting video: $e')),
        );
      }
    }
  }

  Future<void> _uploadVideo() async {
    if (_selectedPlatformFile == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a video to upload.')),
        );
      }
      return;
    }
    if (_descriptionController.text.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a description for the video.')),
        );
      }
      return;
    }

    // Ensure upload URL is available
    if (_uploadUrl == null) {
      await _initializeUploadUrl();
      if (_uploadUrl == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not determine upload URL. Please try again.')),
          );
        }
        return;
      }
    }

    setState(() => _isLoading = true);

    String userIdToUpload;
    try {
      final authService = Provider.of<AuthService>(context, listen: false); 
      if (!authService.isAuthenticated || authService.currentUser == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('You need to login to upload video.')),
          );
        }
        setState(() => _isLoading = false);
        return;
      }
      userIdToUpload = authService.currentUser!.id; 
    } catch (e) {
      print('[UploadPage] Error getting user from AuthService: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not authenticate user. Please try logging in again.')),
        );
      }
      setState(() => _isLoading = false);
      return;
    }

    var request = http.MultipartRequest('POST', Uri.parse(_uploadUrl!));
    request.fields['description'] = _descriptionController.text;
    request.fields['userId'] = userIdToUpload;

    print('[UploadPage] Upload URL: $_uploadUrl');
    print('[UploadPage] Platform: ${_getPlatformName()}');
    print('[UploadPage] Fields: ${request.fields}');

    // Add file based on platform
    if (kIsWeb && _selectedPlatformFile!.bytes != null) {
      request.files.add(http.MultipartFile.fromBytes(
        'videoFile', 
        _selectedPlatformFile!.bytes!,
        filename: _videoFileName ?? 'video_from_web.mp4',
        contentType: MediaType('video', _videoFileName?.split('.').last ?? 'mp4'), 
      ));
      print('[UploadPage] Added file from bytes (web)');
    } else if (!kIsWeb && _selectedPlatformFile!.path != null) {
      request.files.add(
        await http.MultipartFile.fromPath(
          'videoFile',
          _selectedPlatformFile!.path!,
          filename: _videoFileName ?? _selectedPlatformFile!.path!.split(Platform.pathSeparator).last,
          contentType: MediaType('video', _selectedPlatformFile!.path!.split('.').lastOrNull ?? 'mp4'),
        ),
      );
      print('[UploadPage] Added file from path (mobile/desktop)');
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not find valid video file to upload.')),
        );
      }
      setState(() => _isLoading = false);
      return;
    }
    
    try {
      print('[UploadPage] Sending upload request to $_uploadUrl');
      final streamedResponse = await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamedResponse);

      print('[UploadPage] Upload Response status: ${response.statusCode}');
      print('[UploadPage] Upload Response body: ${response.body}');

      if (!mounted) return; 

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Video uploaded successfully!'), 
            backgroundColor: Colors.green
          ),
        );
        setState(() {
          _selectedPlatformFile = null;
          _videoFileName = null;
          _descriptionController.clear();
        });
        Navigator.of(context).pop(); 
      } else {
        String errorMessage = 'Video upload failed. Status: ${response.statusCode}';
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
        String errorMessage = 'Error uploading video: $e';
        if (e.toString().contains('Connection refused') || 
            e.toString().contains('Failed host lookup') ||
            e.toString().contains('No address associated with hostname')) {
          errorMessage = 'Cannot connect to server. Please check your network connection.';
          // Clear cache and try to refresh URL for next attempt
          NetworkConfig.clearCache();
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

  Future<void> _refreshConnection() async {
    setState(() {
      _debugInfo = 'Refreshing connection...';
    });
    
    NetworkConfig.clearCache();
    await _initializeUploadUrl();
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Connection refreshed'),
        duration: Duration(seconds: 1),
      ),
    );
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
        title: const Text('Upload New Video'),
        actions: [
          if (!_isLoading)
            IconButton(
              icon: const Icon(Icons.check_circle_outline),
              onPressed: (_selectedPlatformFile != null && 
                        _descriptionController.text.isNotEmpty &&
                        _uploadUrl != null) ? _uploadVideo : null,
              tooltip: 'Upload Video',
            )
          else
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20, 
                height: 20, 
                child: CircularProgressIndicator(
                  strokeWidth: 2, 
                  color: Colors.white
                )
              ),
            )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Connection Status Card
            Card(
              color: _uploadUrl != null ? Colors.green.shade50 : Colors.orange.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _uploadUrl != null ? Icons.check_circle : Icons.warning,
                          color: _uploadUrl != null ? Colors.green : Colors.orange,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Connection Status',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _uploadUrl != null ? Colors.green.shade700 : Colors.orange.shade700,
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
                          color: _uploadUrl != null ? Colors.green.shade600 : Colors.orange.shade600,
                          fontFamily: 'monospace',
                        ),
                      ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Video Selection
            ElevatedButton.icon(
              onPressed: _pickVideo,
              icon: const Icon(Icons.video_library_outlined),
              label: const Text('Select Video from Device'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                textStyle: const TextStyle(fontSize: 16)
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Selected Video Display
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
                        'Selected Video:',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.movie_creation_outlined, 
                            color: Theme.of(context).hintColor
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _videoFileName ?? 'No filename',
                              style: const TextStyle(
                                fontWeight: FontWeight.w500, 
                                fontSize: 15
                              ),
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
                        child: Center(
                          child: Icon(
                            Icons.play_circle_fill_rounded, 
                            size: 60, 
                            color: Colors.grey[400]
                          )
                        ),
                      ),
                    ],
                  ),
                ),
              ),
             
            if (_selectedPlatformFile != null) const SizedBox(height: 20),
            
            // Description Input
            TextFormField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: 'Video Description',
                hintText: 'Add description, #hashtags...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
                prefixIcon: const Icon(Icons.notes_outlined),
              ),
              maxLines: 4,
              maxLength: 250,
              onChanged: (_) => setState(() {}), // Update upload button state
            ),
            
            const SizedBox(height: 30),
            
            // Upload Button or Loading
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 8),
                      Text('Uploading video...'),
                    ],
                  ),
                )
              )
            else 
              ElevatedButton.icon(
                icon: const Icon(Icons.cloud_upload_rounded),
                label: const Text('Upload Video'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  textStyle: const TextStyle(
                    fontSize: 16, 
                    fontWeight: FontWeight.bold
                  )
                ),
                onPressed: (_selectedPlatformFile != null && 
                          _descriptionController.text.isNotEmpty &&
                          _uploadUrl != null) ? _uploadVideo : null,
              ),
          ],
        ),
      ),
    );
  }
}