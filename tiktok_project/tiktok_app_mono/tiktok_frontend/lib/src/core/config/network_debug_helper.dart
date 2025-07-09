// tiktok_frontend/lib/src/core/config/network_debug_helper.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tiktok_frontend/src/core/config/network_config.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class NetworkDebugHelper {
  static Future<void> showDebugDialog(BuildContext context) async {
    showDialog(
      context: context,
      builder: (context) => const NetworkDebugDialog(),
    );
  }
}

class NetworkDebugDialog extends StatefulWidget {
  const NetworkDebugDialog({super.key});

  @override
  State<NetworkDebugDialog> createState() => _NetworkDebugDialogState();
}

class _NetworkDebugDialogState extends State<NetworkDebugDialog> {
  Map<String, dynamic>? _diagnosticResult;
  bool _isRunning = false;

  @override
  void initState() {
    super.initState();
    _runDiagnostic();
  }

  Future<void> _runDiagnostic() async {
    setState(() {
      _isRunning = true;
    });

    try {
      final result = await NetworkConfig.runDiagnostic();
      setState(() {
        _diagnosticResult = result;
        _isRunning = false;
      });
    } catch (e) {
      setState(() {
        _diagnosticResult = {
          'error': e.toString(),
          'timestamp': DateTime.now().toIso8601String(),
        };
        _isRunning = false;
      });
    }
  }

  Future<void> _testEndpoint(String endpoint) async {
    try {
      final url = await NetworkConfig.getBaseUrl(endpoint);
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$endpoint: ${response.statusCode} (${response.body.length} bytes)'),
          backgroundColor: response.statusCode == 200 ? Colors.green : Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$endpoint: Error - $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildTestButton(String label, String endpoint) {
    return ElevatedButton(
      onPressed: () => _testEndpoint(endpoint),
      child: Text(label),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Network Debug'),
      content: SizedBox(
        width: double.maxFinite,
        height: 500,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isRunning)
              const Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Running diagnostic...'),
                  ],
                ),
              )
            else if (_diagnosticResult != null) ...[
              Text(
                'Platform: ${_diagnosticResult!['platform']}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('Cache: ${_diagnosticResult!['cached_url'] ?? 'None'}'),
              Text('Valid: ${_diagnosticResult!['cache_valid']}'),
              
              const SizedBox(height: 16),
              const Text('Connection Tests:', style: TextStyle(fontWeight: FontWeight.bold)),
              
              if (_diagnosticResult!['tests'] != null) ...[
                const SizedBox(height: 8),
                Expanded(
                  child: ListView(
                    children: (_diagnosticResult!['tests'] as Map<String, dynamic>).entries.map((entry) {
                      final test = entry.value as Map<String, dynamic>;
                      final isSuccess = test['success'] == true;
                      final time = test['response_time_ms']?.toString() ?? 'N/A';
                      
                      return Card(
                        color: isSuccess ? Colors.green.shade50 : Colors.red.shade50,
                        child: ListTile(
                          leading: Icon(
                            isSuccess ? Icons.check_circle : Icons.error,
                            color: isSuccess ? Colors.green : Colors.red,
                          ),
                          title: Text(entry.key),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('URL: ${test['url']}'),
                              Text('Time: ${time}ms'),
                              if (test['error'] != null)
                                Text(
                                  'Error: ${test['error']}',
                                  style: const TextStyle(color: Colors.red),
                                ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
              
              const SizedBox(height: 16),
              const Text('Test Endpoints:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildTestButton('Health', '/health'),
                  _buildTestButton('Users', '/api/users'),
                  _buildTestButton('Search', '/api/search/test'),
                  _buildTestButton('Upload', '/api/videos/upload'),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            NetworkConfig.clearCache();
            Navigator.pop(context);
          },
          child: const Text('Clear Cache & Close'),
        ),
        TextButton(
          onPressed: _runDiagnostic,
          child: const Text('Refresh'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}