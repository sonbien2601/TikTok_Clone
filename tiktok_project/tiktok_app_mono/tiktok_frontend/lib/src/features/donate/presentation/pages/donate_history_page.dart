import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tiktok_frontend/src/features/auth/domain/services/auth_service.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:tiktok_frontend/src/core/config/network_config.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class DonateHistoryPage extends StatefulWidget {
  const DonateHistoryPage({Key? key}) : super(key: key);

  @override
  State<DonateHistoryPage> createState() => _DonateHistoryPageState();
}

class _DonateHistoryPageState extends State<DonateHistoryPage> with TickerProviderStateMixin {
  bool _isLoadingSent = true;
  bool _isLoadingReceived = true;
  List<dynamic> _donateHistorySent = [];
  List<dynamic> _donateHistoryReceived = [];
  String? _errorSent;
  String? _errorReceived;
  late TabController _tabController;

  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _listController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // Initialize animation controllers
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _listController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));

    _fetchDonateHistorySent();
    _fetchDonateHistoryReceived();

    // Start animations
    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _listController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchDonateHistorySent() async {
    setState(() {
      _isLoadingSent = true;
      _errorSent = null;
    });
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final userId = authService.currentUser?.id;
      if (userId == null) {
        setState(() {
          _errorSent = 'Không xác định được người dùng.';
          _isLoadingSent = false;
        });
        return;
      }
      final baseUrl = await NetworkConfig.getBaseUrl('/api/users');
      final url = Uri.parse('$baseUrl/$userId/donate-history');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _donateHistorySent = data;
          _isLoadingSent = false;
        });
        
        // Start list animation after data loads
        _listController.forward();
      } else {
        setState(() {
          _errorSent = 'Lỗi khi lấy lịch sử donate.';
          _isLoadingSent = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorSent = 'Lỗi: $e';
        _isLoadingSent = false;
      });
    }
  }

  Future<void> _fetchDonateHistoryReceived() async {
    setState(() {
      _isLoadingReceived = true;
      _errorReceived = null;
    });
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final userId = authService.currentUser?.id;
      if (userId == null) {
        setState(() {
          _errorReceived = 'Không xác định được người dùng.';
          _isLoadingReceived = false;
        });
        return;
      }
      final baseUrl = await NetworkConfig.getBaseUrl('/api/users');
      final url = Uri.parse('$baseUrl/$userId/received-donate-history');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _donateHistoryReceived = data;
          _isLoadingReceived = false;
        });
        
        // Start list animation after data loads
        if (!_listController.isCompleted) {
          _listController.forward();
        }
      } else {
        setState(() {
          _errorReceived = 'Lỗi khi lấy lịch sử nhận donate.';
          _isLoadingReceived = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorReceived = 'Lỗi: $e';
        _isLoadingReceived = false;
      });
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    final date = DateTime.tryParse(dateStr);
    if (date == null) return dateStr;
    return DateFormat('dd/MM/yyyy HH:mm').format(date);
  }

  String _buildImageUrl(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) return '';
    
    if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
      return imageUrl;
    }
    
    if (imageUrl.startsWith('/')) {
      return 'http://localhost:8080$imageUrl';
    }
    
    return 'http://localhost:8080/$imageUrl';
  }

  String fixImageUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
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
                    color: const Color(0xFF1F1F1F),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF333333),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: const BoxDecoration(
                          color: Color(0xFFFF0000),
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(12),
                            topRight: Radius.circular(12),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.receipt_long, color: Colors.white, size: 24),
                            const SizedBox(width: 12),
                            const Text(
                              'Ảnh xác nhận chuyển khoản',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: Colors.white,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.close, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: InteractiveViewer(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              fixImageUrl(imageUrl),
                              fit: BoxFit.contain,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Container(
                                  height: 300,
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                      color: Color(0xFFFF0000),
                                    ),
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  height: 300,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2A2A2A),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFF333333)),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.broken_image,
                                        size: 48,
                                        color: const Color(0xFF888888),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Không thể tải ảnh QR',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'URL: $imageUrl',
                                        style: TextStyle(
                                          color: Color(0xFF888888),
                                          fontSize: 10,
                                          fontFamily: 'monospace',
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

  void _showDonateDetailDialog(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.9,
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF1F1F1F),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF333333),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with gradient
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFF0000),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.receipt_long, color: Colors.white, size: 24),
                      const SizedBox(width: 12),
                      const Text(
                        'Chi tiết giao dịch',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.white,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                // Content
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Recipient info container
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: const Color(0xFF2A2A2A),
                            border: Border.all(
                              color: const Color(0xFF333333),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFF0000),
                                      borderRadius: BorderRadius.circular(8),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFFFF0000).withOpacity(0.4),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(Icons.person, color: Colors.white, size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Thông tin người nhận',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: const Color(0xFFFF0000),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFFFF0000).withOpacity(0.4),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    padding: const EdgeInsets.all(2),
                                    child: CircleAvatar(
                                      radius: 25,
                                      backgroundColor: const Color(0xFF404040),
                                      backgroundImage: item['recipientAvatarUrl'] != null
                                          ? NetworkImage(fixImageUrl(item['recipientAvatarUrl']))
                                          : null,
                                      child: item['recipientAvatarUrl'] == null
                                          ? const Icon(Icons.person, color: Colors.white)
                                          : null,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Người nhận',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF888888),
                                          ),
                                        ),
                                        Text(
                                          item['recipientUsername'] ?? 'Unknown',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Transaction info container
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: const Color(0xFF2A2A2A),
                            border: Border.all(
                              color: const Color(0xFF333333),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF0000),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFFF0000).withOpacity(0.4),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.monetization_on, color: Colors.white, size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${item['amount']} VND',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Icon(Icons.access_time, size: 16, color: Color(0xFF888888)),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Thời gian: ${_formatDate(item['createdAt'])}',
                                    style: TextStyle(color: Color(0xFF888888)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(Icons.confirmation_number, size: 16, color: Color(0xFF888888)),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Mã giao dịch: ${item['id']?.toString() ?? 'N/A'}',
                                    style: TextStyle(color: Color(0xFF888888)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Proof image container
                        if (item['donateProofImageUrl'] != null) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: const Color(0xFF2A2A2A),
                              border: Border.all(
                                color: const Color(0xFF333333),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFF0000),
                                        borderRadius: BorderRadius.circular(8),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFFFF0000).withOpacity(0.4),
                                            blurRadius: 8,
                                            offset: const Offset(0, 3),
                                          ),
                                        ],
                                      ),
                                      child: const Icon(Icons.image, color: Colors.white, size: 20),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Ảnh xác nhận chuyển khoản',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                GestureDetector(
                                  onTap: () => _showQrImageDialog(item['donateProofImageUrl']!),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: const Color(0xFF333333),
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.2),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.network(
                                        fixImageUrl(item['donateProofImageUrl']),
                                        height: 200,
                                        width: 200,
                                        fit: BoxFit.contain,
                                        loadingBuilder: (context, child, loadingProgress) {
                                          if (loadingProgress == null) return child;
                                          return Container(
                                            height: 200,
                                            width: 200,
                                            color: const Color(0xFF404040),
                                            child: const Center(
                                              child: CircularProgressIndicator(
                                                color: Color(0xFFFF0000),
                                              ),
                                            ),
                                          );
                                        },
                                        errorBuilder: (context, error, stackTrace) {
                                          return Container(
                                            height: 200,
                                            width: 200,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF404040),
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(color: const Color(0xFF333333)),
                                            ),
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.broken_image,
                                                  size: 48,
                                                  color: Color(0xFF888888),
                                                ),
                                                const SizedBox(height: 8),
                                                Text(
                                                  'Không thể tải ảnh',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 14,
                                                  ),
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
                                  'Nhấn để xem ảnh phóng to',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF888888),
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: const Color(0xFF2A2A2A),
                              border: Border.all(
                                color: Colors.orange.withOpacity(0.3),
                              ),
                            ),
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withOpacity(0.2),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.orange.withOpacity(0.3),
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.image_not_supported_outlined,
                                    size: 48,
                                    color: Colors.orange,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Không có ảnh xác nhận',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
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
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFF0000),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF0000).withOpacity(0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.history, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            const Text(
              'Lịch sử Donate',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1F1F1F),
              border: Border.all(
                color: const Color(0xFF333333),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorColor: const Color(0xFFFF0000),
              labelColor: const Color(0xFFFF0000),
              unselectedLabelColor: const Color(0xFF888888),
              labelStyle: const TextStyle(fontWeight: FontWeight.bold),
              tabs: const [
                Tab(text: 'Đã donate'),
                Tab(text: 'Được donate'),
              ],
            ),
          ),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildDonateHistoryList(_isLoadingSent, _errorSent, _donateHistorySent, isReceived: false),
              _buildDonateHistoryList(_isLoadingReceived, _errorReceived, _donateHistoryReceived, isReceived: true),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDonateHistoryList(bool isLoading, String? error, List<dynamic> history, {required bool isReceived}) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFFFF0000),
          strokeWidth: 3,
        ),
      );
    }
    
    if (error != null) {
      return Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: const Color(0xFF1F1F1F),
            border: Border.all(
              color: Colors.red.withOpacity(0.3),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.error_outline, size: 48, color: Colors.red),
              ),
              const SizedBox(height: 16),
              Text(
                error,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  color: const Color(0xFFFF0000),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF0000).withOpacity(0.4),
                      blurRadius: 16,
                      spreadRadius: 1,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: isReceived ? _fetchDonateHistoryReceived : _fetchDonateHistorySent,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  ),
                  child: const Text(
                    'Thử lại',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    if (history.isEmpty) {
      return Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: const Color(0xFF1F1F1F),
            border: Border.all(
              color: const Color(0xFF333333),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF0000).withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFFF0000).withOpacity(0.3),
                  ),
                ),
                child: Icon(
                  isReceived ? Icons.card_giftcard : Icons.volunteer_activism,
                  size: 64,
                  color: const Color(0xFFFF0000),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                isReceived ? 'Chưa ai donate cho bạn' : 'Chưa có lịch sử donate',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                isReceived 
                    ? 'Khi ai đó donate cho bạn, lịch sử sẽ hiển thị ở đây!' 
                    : 'Hãy donate cho ai đó để tạo lịch sử đầu tiên!',
                style: const TextStyle(
                  color: Color(0xFF888888),
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    
    return RefreshIndicator(
      onRefresh: isReceived ? _fetchDonateHistoryReceived : _fetchDonateHistorySent,
      backgroundColor: const Color(0xFF1F1F1F),
      color: const Color(0xFFFF0000),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: history.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final item = history[index];
          return AnimatedBuilder(
            animation: _listController,
            builder: (context, child) {
              final animationDelay = (index * 0.1).clamp(0.0, 1.0);
              final animation = Tween<Offset>(
                begin: const Offset(-1.0, 0),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(
                  parent: _listController,
                  curve: Interval(
                    animationDelay,
                    (animationDelay + 0.3).clamp(0.0, 1.0),
                    curve: Curves.easeOutBack,
                  ),
                ),
              );
              
              final fadeAnimation = Tween<double>(
                begin: 0.0,
                end: 1.0,
              ).animate(
                CurvedAnimation(
                  parent: _listController,
                  curve: Interval(
                    animationDelay,
                    (animationDelay + 0.5).clamp(0.0, 1.0),
                    curve: Curves.easeOut,
                  ),
                ),
              );
              
              return SlideTransition(
                position: animation,
                child: FadeTransition(
                  opacity: fadeAnimation,
                  child: Card(
                    elevation: 0,
                    color: Colors.transparent,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: const Color(0xFF1F1F1F),
                        border: Border.all(
                          color: const Color(0xFF333333),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _showDonateDetailDialog(item),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    // Avatar with gradient border
                                    Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: const Color(0xFFFF0000),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFFFF0000).withOpacity(0.4),
                                            blurRadius: 15,
                                            offset: const Offset(0, 6),
                                          ),
                                        ],
                                      ),
                                      padding: const EdgeInsets.all(3),
                                      child: CircleAvatar(
                                        radius: 25,
                                        backgroundColor: const Color(0xFF404040),
                                        backgroundImage: (isReceived ? item['senderAvatarUrl'] : item['recipientAvatarUrl']) != null
                                            ? NetworkImage(fixImageUrl(isReceived ? item['senderAvatarUrl'] : item['recipientAvatarUrl']))
                                            : null,
                                        child: (isReceived ? item['senderAvatarUrl'] : item['recipientAvatarUrl']) == null
                                            ? const Icon(Icons.person, color: Colors.white)
                                            : null,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    // Main info
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            isReceived
                                                ? 'Được donate từ: ${item['senderUsername'] ?? 'Unknown'}'
                                                : 'Đã donate cho: ${item['recipientUsername'] ?? 'Unknown'}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFF0000),
                                              borderRadius: BorderRadius.circular(12),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: const Color(0xFFFF0000).withOpacity(0.4),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 3),
                                                ),
                                              ],
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.monetization_on, size: 16, color: Colors.white),
                                                const SizedBox(width: 4),
                                                Text(
                                                  '${item['amount']} VND',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 15,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              Icon(Icons.access_time, size: 14, color: const Color(0xFF888888)),
                                              const SizedBox(width: 4),
                                              Text(
                                                _formatDate(item['createdAt']),
                                                style: const TextStyle(
                                                  color: Color(0xFF888888),
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Image preview
                                    if (item['donateProofImageUrl'] != null) ...[
                                      const SizedBox(width: 12),
                                      Container(
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: const Color(0xFF333333),
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.2),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: Image.network(
                                            fixImageUrl(item['donateProofImageUrl']),
                                            height: 50,
                                            width: 50,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) {
                                              return Container(
                                                height: 50,
                                                width: 50,
                                                color: const Color(0xFF404040),
                                                child: Icon(
                                                  Icons.image,
                                                  color: const Color(0xFF888888),
                                                  size: 20,
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                    ],
                                    const SizedBox(width: 8),
                                    const Icon(
                                      Icons.arrow_forward_ios,
                                      size: 16,
                                      color: Color(0xFFFF0000),
                                    ),
                                  ],
                                ),
                                // Status indicator with dark theme
                                const SizedBox(height: 16),
                                if (item['donateProofImageUrl'] != null) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.green.withOpacity(0.3),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.verified, size: 14, color: Colors.green),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Đã xác nhận',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.white,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ] else ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.orange.withOpacity(0.3),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.pending, size: 14, color: Colors.orange),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Chưa có ảnh xác nhận',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.white,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}