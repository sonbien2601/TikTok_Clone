import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tiktok_frontend/src/features/auth/domain/services/auth_service.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:tiktok_frontend/src/core/config/network_config.dart';

class DonateHistoryPage extends StatefulWidget {
  const DonateHistoryPage({Key? key}) : super(key: key);

  @override
  State<DonateHistoryPage> createState() => _DonateHistoryPageState();
}

class _DonateHistoryPageState extends State<DonateHistoryPage> {
  bool _isLoading = true;
  List<dynamic> _donateHistory = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchDonateHistory();
  }

  Future<void> _fetchDonateHistory() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final userId = authService.currentUser?.id;
      if (userId == null) {
        setState(() {
          _error = 'Không xác định được người dùng.';
          _isLoading = false;
        });
        return;
      }
      final baseUrl = await NetworkConfig.getBaseUrl('/api/donate-history/user/');
      final url = Uri.parse('$baseUrl$userId');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _donateHistory = data;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Lỗi khi lấy lịch sử donate.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Lỗi: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lịch sử Donate'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _donateHistory.isEmpty
                  ? const Center(child: Text('Chưa có lịch sử donate.'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _donateHistory.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final item = _donateHistory[index];
                        return Card(
                          child: ListTile(
                            leading: item['recipientAvatarUrl'] != null
                                ? CircleAvatar(
                                    backgroundImage: NetworkImage(item['recipientAvatarUrl']),
                                  )
                                : const CircleAvatar(child: Icon(Icons.person)),
                            title: Text('Đã donate cho: ${item['recipientUsername'] ?? 'Unknown'}'),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Số tiền: ${item['amount']}'),
                                if (item['donateProofImageUrl'] != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4.0),
                                    child: Image.network(
                                      item['donateProofImageUrl'],
                                      height: 60,
                                      width: 60,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                Text('Thời gian: ${_formatDate(item['createdAt'])}'),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    final date = DateTime.tryParse(dateStr);
    if (date == null) return dateStr;
    return DateFormat('dd/MM/yyyy HH:mm').format(date);
  }
} 