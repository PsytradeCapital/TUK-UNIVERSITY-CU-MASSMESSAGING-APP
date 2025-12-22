import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/analytics_service.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';
import '../theme/app_theme.dart';
import '../widgets/ui_components.dart';

/// Analytics Dashboard Screen for system monitoring
/// Requirements 8.2, 8.5 - Display user activity metrics and provide filtering
class AnalyticsDashboardScreen extends StatefulWidget {
  const AnalyticsDashboardScreen({Key? key}) : super(key: key);

  @override
  State<AnalyticsDashboardScreen> createState() => _AnalyticsDashboardScreenState();
}

class _AnalyticsDashboardScreenState extends State<AnalyticsDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final AnalyticsService _analyticsService = AnalyticsService();
  final AuthService _authService = AuthService();
  
  bool _isLoading = true;
  String _selectedTimeRange = '7d';
  Map<String, dynamic> _analyticsData = {};
  List<Map<String, dynamic>> _errorLogs = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadAnalyticsData();
    _trackScreenView();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _trackScreenView() async {
    await _analyticsService.trackScreenView(
      screenName: 'Analytics Dashboard',
      screenClass: 'AnalyticsDashboardScreen',
    );
  }

  Future<void> _loadAnalyticsData() async {
    setState(() => _isLoading = true);
    
    try {
      // In a real implementation, this would fetch data from Firebase Analytics
      // For now, we'll simulate the data structure
      await Future.delayed(const Duration(seconds: 1));
      
      setState(() {
        _analyticsData = _generateMockAnalyticsData();
        _errorLogs = _generateMockErrorLogs();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('Failed to load analytics data: $e');
    }
  }

  Map<String, dynamic> _generateMockAnalyticsData() {
    // Mock data - in real implementation, this would come from Firebase Analytics
    return {
      'userActivity': {
        'totalUsers': 45,
        'activeUsers': 32,
        'newUsers': 8,
        'userSessions': 156,
        'averageSessionDuration': '12m 34s',
      },
      'attendeeMetrics': {
        'totalAttendees': 1247,
        'newAttendeesThisWeek': 89,
        'attendeesPerService': 156.2,
        'topLocations': [
          {'name': 'Nairobi', 'count': 456},
          {'name': 'Mombasa', 'count': 234},
          {'name': 'Kisumu', 'count': 178},
          {'name': 'Nakuru', 'count': 145},
        ],
      },
      'messagingMetrics': {
        'totalMessagesSent': 3456,
        'messagesThisWeek': 234,
        'deliveryRate': 94.5,
        'averageResponseTime': '2.3s',
        'messageTypes': [
          {'type': 'Welcome', 'count': 1234},
          {'type': 'Reminder', 'count': 987},
          {'type': 'Custom', 'count': 1235},
        ],
      },
      'syncMetrics': {
        'totalSyncOperations': 2345,
        'successfulSyncs': 2298,
        'failedSyncs': 47,
        'averageSyncTime': '1.8s',
        'offlineOperations': 156,
      },
      'systemHealth': {
        'uptime': '99.8%',
        'errorRate': '0.2%',
        'averageResponseTime': '245ms',
        'activeConnections': 32,
      },
    };
  }

  List<Map<String, dynamic>> _generateMockErrorLogs() {
    // Mock error logs - in real implementation, this would come from Firebase Crashlytics
    return [
      {
        'timestamp': DateTime.now().subtract(const Duration(hours: 2)),
        'level': 'ERROR',
        'message': 'Network timeout during sync operation',
        'context': 'CloudSyncService',
        'userId': 'user123',
        'count': 3,
      },
      {
        'timestamp': DateTime.now().subtract(const Duration(hours: 5)),
        'level': 'WARNING',
        'message': 'SMS delivery failed - invalid phone number',
        'context': 'SMSManager',
        'userId': 'user456',
        'count': 1,
      },
      {
        'timestamp': DateTime.now().subtract(const Duration(days: 1)),
        'level': 'ERROR',
        'message': 'Database connection lost',
        'context': 'DatabaseManager',
        'userId': 'user789',
        'count': 2,
      },
      {
        'timestamp': DateTime.now().subtract(const Duration(days: 2)),
        'level': 'INFO',
        'message': 'User authentication successful',
        'context': 'AuthService',
        'userId': 'user101',
        'count': 45,
      },
    ];
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics Dashboard'),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Overview', icon: Icon(Icons.dashboard)),
            Tab(text: 'Users', icon: Icon(Icons.people)),
            Tab(text: 'Messages', icon: Icon(Icons.message)),
            Tab(text: 'Errors', icon: Icon(Icons.error_outline)),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.access_time),
            onSelected: (value) {
              setState(() {
                _selectedTimeRange = value;
              });
              _loadAnalyticsData();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: '1d', child: Text('Last 24 hours')),
              const PopupMenuItem(value: '7d', child: Text('Last 7 days')),
              const PopupMenuItem(value: '30d', child: Text('Last 30 days')),
              const PopupMenuItem(value: '90d', child: Text('Last 90 days')),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAnalyticsData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildUsersTab(),
                _buildMessagesTab(),
                _buildErrorsTab(),
              ],
            ),
    );
  }

  Widget _buildOverviewTab() {
    final systemHealth = _analyticsData['systemHealth'] as Map<String, dynamic>;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTimeRangeHeader(),
          const SizedBox(height: 16),
          
          // System Health Cards
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  'Uptime',
                  systemHealth['uptime'],
                  Icons.check_circle,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMetricCard(
                  'Error Rate',
                  systemHealth['errorRate'],
                  Icons.error_outline,
                  Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  'Response Time',
                  systemHealth['averageResponseTime'],
                  Icons.speed,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMetricCard(
                  'Active Users',
                  '${systemHealth['activeConnections']}',
                  Icons.people,
                  Colors.purple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Quick Stats
          _buildSectionHeader('Quick Statistics'),
          const SizedBox(height: 16),
          _buildQuickStats(),
        ],
      ),
    );
  }

  Widget _buildUsersTab() {
    final userActivity = _analyticsData['userActivity'] as Map<String, dynamic>;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTimeRangeHeader(),
          const SizedBox(height: 16),
          
          // User Metrics
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  'Total Users',
                  '${userActivity['totalUsers']}',
                  Icons.people,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMetricCard(
                  'Active Users',
                  '${userActivity['activeUsers']}',
                  Icons.person,
                  Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  'New Users',
                  '${userActivity['newUsers']}',
                  Icons.person_add,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMetricCard(
                  'Sessions',
                  '${userActivity['userSessions']}',
                  Icons.access_time,
                  Colors.purple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // User Activity Chart Placeholder
          _buildSectionHeader('User Activity Trend'),
          const SizedBox(height: 16),
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.show_chart, size: 48, color: Colors.grey),
                  SizedBox(height: 8),
                  Text(
                    'User Activity Chart',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                  Text(
                    'Chart implementation would go here',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesTab() {
    final messagingMetrics = _analyticsData['messagingMetrics'] as Map<String, dynamic>;
    final messageTypes = messagingMetrics['messageTypes'] as List<Map<String, dynamic>>;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTimeRangeHeader(),
          const SizedBox(height: 16),
          
          // Message Metrics
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  'Total Messages',
                  '${messagingMetrics['totalMessagesSent']}',
                  Icons.message,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMetricCard(
                  'This Week',
                  '${messagingMetrics['messagesThisWeek']}',
                  Icons.trending_up,
                  Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  'Delivery Rate',
                  '${messagingMetrics['deliveryRate']}%',
                  Icons.check_circle,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMetricCard(
                  'Response Time',
                  messagingMetrics['averageResponseTime'],
                  Icons.speed,
                  Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Message Types
          _buildSectionHeader('Message Types'),
          const SizedBox(height: 16),
          ...messageTypes.map((type) => _buildMessageTypeItem(type)),
        ],
      ),
    );
  }

  Widget _buildErrorsTab() {
    final filteredLogs = _errorLogs.where((log) {
      if (_searchQuery.isEmpty) return true;
      return log['message'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
             log['context'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
    
    return Column(
      children: [
        // Search Bar
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Search error logs...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
        ),
        
        // Error Logs List
        Expanded(
          child: ListView.builder(
            itemCount: filteredLogs.length,
            itemBuilder: (context, index) {
              final log = filteredLogs[index];
              return _buildErrorLogItem(log);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTimeRangeHeader() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primaryBlue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.access_time, color: AppTheme.primaryBlue),
          const SizedBox(width: 8),
          Text(
            'Showing data for: ${_getTimeRangeText()}',
            style: TextStyle(
              color: AppTheme.primaryBlue,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _getTimeRangeText() {
    switch (_selectedTimeRange) {
      case '1d': return 'Last 24 hours';
      case '7d': return 'Last 7 days';
      case '30d': return 'Last 30 days';
      case '90d': return 'Last 90 days';
      default: return 'Last 7 days';
    }
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(Icons.trending_up, color: color, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildQuickStats() {
    final attendeeMetrics = _analyticsData['attendeeMetrics'] as Map<String, dynamic>;
    final syncMetrics = _analyticsData['syncMetrics'] as Map<String, dynamic>;
    
    return Column(
      children: [
        _buildStatRow('Total Attendees', '${attendeeMetrics['totalAttendees']}'),
        _buildStatRow('New This Week', '${attendeeMetrics['newAttendeesThisWeek']}'),
        _buildStatRow('Sync Success Rate', '${((syncMetrics['successfulSyncs'] / syncMetrics['totalSyncOperations']) * 100).toStringAsFixed(1)}%'),
        _buildStatRow('Offline Operations', '${syncMetrics['offlineOperations']}'),
      ],
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16)),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageTypeItem(Map<String, dynamic> type) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.message,
              color: AppTheme.primaryBlue,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  type['type'],
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                  ),
                ),
                Text(
                  '${type['count']} messages',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${type['count']}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorLogItem(Map<String, dynamic> log) {
    Color levelColor;
    IconData levelIcon;
    
    switch (log['level']) {
      case 'ERROR':
        levelColor = Colors.red;
        levelIcon = Icons.error;
        break;
      case 'WARNING':
        levelColor = Colors.orange;
        levelIcon = Icons.warning;
        break;
      case 'INFO':
        levelColor = Colors.blue;
        levelIcon = Icons.info;
        break;
      default:
        levelColor = Colors.grey;
        levelIcon = Icons.help;
    }
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(levelIcon, color: levelColor, size: 20),
              const SizedBox(width: 8),
              Text(
                log['level'],
                style: TextStyle(
                  color: levelColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (log['count'] > 1)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${log['count']}x',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              const SizedBox(width: 8),
              Text(
                _formatTimestamp(log['timestamp']),
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            log['message'],
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                'Context: ${log['context']}',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                'User: ${log['userId']}',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}