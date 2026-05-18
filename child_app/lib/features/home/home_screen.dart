import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';
import '../../core/network/api_client.dart';
import '../auth/auth_service.dart';
import '../sos/sos_provider.dart';
import '../family/bind_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> _elderlyList = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadElderly();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<SosProvider>(context, listen: false).startPolling();
    });
  }

  @override
  void dispose() {
    Provider.of<SosProvider>(context, listen: false).stopPolling();
    super.dispose();
  }

  Future<void> _loadElderly() async {
    setState(() { _loading = true; _error = null; });
    try {
      final list = await ApiClient.getList('/family-links/');
      final myLinks = list?.cast<Map<String, dynamic>>().where((link) => link['status'] == 'active').toList() ?? [];
      setState(() {
        _elderlyList = myLinks;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (e.isUnauthorized) return; // auto-logout handled by ApiClient
      setState(() { _loading = false; _error = e.message; });
    } catch (e) {
      setState(() { _loading = false; _error = '网络错误，请检查网络连接'; });
    }
  }

  Future<void> _onBindElderly() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const BindScreen()),
    );
    if (result == true) {
      _loadElderly();
    }
  }

  Future<void> _onAcceptSos() async {
    final sos = Provider.of<SosProvider>(context, listen: false);
    if (sos.latestAlert == null) return;
    final sosId = sos.latestAlert!['id']?.toString();
    if (sosId == null) return;

    final ok = await sos.acceptSos(sosId);
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已接受求助')),
      );
      // Navigate to co-screen with the elderly who sent SOS
      final elderlyId = sos.latestAlert!['elderly_id']?.toString();
      if (elderlyId != null) {
        _startCoScreen(elderlyId);
      }
    }
  }

  void _onCallElderly() {
    launchUrl(Uri.parse('tel:13800000001'));
  }

  void _startCoScreen(String elderlyId) {
    Navigator.pushNamed(context, '/coscreen', arguments: {'elderlyId': elderlyId});
  }

  @override
  Widget build(BuildContext context) {
    final sosProvider = Provider.of<SosProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('银发陪驾 · 子女版'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              Provider.of<AuthService>(context, listen: false).logout();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadElderly,
        child: ListView(
          padding: const EdgeInsets.all(AppTheme.paddingMedium),
          children: [
            // SOS Alert Banner
            if (sosProvider.hasAlert)
              _buildSosBanner(sosProvider),

            if (_loading)
              const Padding(
                padding: EdgeInsets.all(48),
                child: Center(child: CircularProgressIndicator()),
              )

            else if (_error != null)
              _buildErrorState()

            else if (_elderlyList.isEmpty)
              _buildEmptyState()

            else
              ..._buildElderlyCards(),
          ],
        ),
      ),
    );
  }

  Widget _buildSosBanner(SosProvider sos) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.paddingMedium),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE53935), Color(0xFFC62828)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _onAcceptSos,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.warning, color: Colors.white, size: 28),
                    SizedBox(width: 8),
                    Text('SOS 求助警报！', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                const Text('您的家人正在求助，点击立即响应', style: TextStyle(color: Color(0xCCFFFFFF), fontSize: 16)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: _onAcceptSos,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFFE53935),
                      ),
                      child: const Text('接受求助', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton(
                      onPressed: _onCallElderly,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Color(0xFFFFFFFF33)),
                      ),
                      child: const Text('拨打电话'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 32),
      child: Column(
        children: [
          const Icon(Icons.cloud_off, size: 64, color: AppTheme.textSecondary),
          const SizedBox(height: 16),
          Text(_error ?? '加载失败', style: const TextStyle(fontSize: 18, color: AppTheme.textSecondary), textAlign: TextAlign.center),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadElderly,
            icon: const Icon(Icons.refresh),
            label: const Text('重试'),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 32),
      child: Column(
        children: [
          const Icon(Icons.people_outline, size: 64, color: AppTheme.textSecondary),
          const SizedBox(height: 16),
          const Text('还没有绑定老人', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          const Text('请在老人手机上打开"银发陪驾"App，获取邀请码后输入', style: TextStyle(color: AppTheme.textSecondary), textAlign: TextAlign.center),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _onBindElderly,
            icon: const Icon(Icons.link),
            label: const Text('输入邀请码绑定'),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildElderlyCards() {
    return [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('我的守护', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          TextButton.icon(
            onPressed: _onBindElderly,
            icon: const Icon(Icons.add, size: 20),
            label: const Text('绑定'),
          ),
        ],
      ),
      const SizedBox(height: 8),
      ..._elderlyList.map((link) => _buildElderlyCard(link)),
    ];
  }

  Widget _buildElderlyCard(Map<String, dynamic> link) {
    final elderlyId = link['elderly_id']?.toString() ?? '';
    return Card(
      margin: const EdgeInsets.only(bottom: AppTheme.paddingMedium),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.paddingMedium),
        child: Row(
          children: [
            const CircleAvatar(
              backgroundColor: AppTheme.primary,
              child: Icon(Icons.person, color: Colors.white),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(elderlyId.length > 8 ? '${elderlyId.substring(0, 8)}...' : elderlyId, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  const Text('已绑定', style: TextStyle(color: AppTheme.secondary, fontSize: 14)),
                ],
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => _startCoScreen(elderlyId),
              icon: const Icon(Icons.screen_share, size: 18),
              label: const Text('共屏指引'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.secondary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
