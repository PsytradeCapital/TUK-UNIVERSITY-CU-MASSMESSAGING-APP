import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/report_generator.dart';
import '../models/attendee_model.dart';
import '../models/service_model.dart';
import '../repositories/service_repository.dart';
import '../repositories/offline_first_attendee_repository.dart';
import 'filtered_members_screen.dart';
import 'messaging_screen.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({Key? key}) : super(key: key);

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> with SingleTickerProviderStateMixin {
  final ReportGenerator _reportGenerator = ReportGenerator();
  final ServiceRepository _serviceRepository = ServiceRepository();
  final OfflineFirstAttendeeRepository _attendeeRepository = OfflineFirstAttendeeRepository();
  
  late TabController _tabController;
  
  // Loading states
  bool _isLoadingOverview = false;
  bool _isLoadingServices = false;
  bool _isLoadingAttendees = false;
  bool _isExporting = false;
  
  // Data
  AttendanceReport? _attendanceReport;
  List<ServiceModel> _recentServices = [];
  List<AttendeeModel> _topAttendees = [];
  List<AttendanceTrend> _attendanceTrends = [];
  
  // Error states
  String? _overviewError;
  String? _servicesError;
  String? _attendeesError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadInitialData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    await Future.wait([
      _loadOverviewData(),
      _loadServicesData(),
      _loadAttendeesData(),
    ]);
  }

  Future<void> _loadOverviewData() async {
    setState(() {
      _isLoadingOverview = true;
      _overviewError = null;
    });

    try {
      final report = await _reportGenerator.generateAttendanceReport();
      final trends = await _reportGenerator.getAttendanceTrends(months: 6);
      
      setState(() {
        _attendanceReport = report;
        _attendanceTrends = trends;
      });
    } catch (e) {
      setState(() {
        _overviewError = 'Failed to load overview data: $e';
      });
    } finally {
      setState(() {
        _isLoadingOverview = false;
      });
    }
  }

  Future<void> _loadServicesData() async {
    setState(() {
      _isLoadingServices = true;
      _servicesError = null;
    });

    try {
      final services = await _serviceRepository.getRecentServices(limit: 20);
      setState(() {
        _recentServices = services;
      });
    } catch (e) {
      setState(() {
        _servicesError = 'Failed to load services data: $e';
      });
    } finally {
      setState(() {
        _isLoadingServices = false;
      });
    }
  }

  Future<void> _loadAttendeesData() async {
    setState(() {
      _isLoadingAttendees = true;
      _attendeesError = null;
    });

    try {
      final attendees = await _attendeeRepository.getAttendeesWithMinAttendance(1);
      attendees.sort((a, b) => b.attendanceCount.compareTo(a.attendanceCount));
      
      setState(() {
        _topAttendees = attendees.take(50).toList();
      });
    } catch (e) {
      setState(() {
        _attendeesError = 'Failed to load attendees data: $e';
      });
    } finally {
      setState(() {
        _isLoadingAttendees = false;
      });
    }
  }

  Future<void> _exportData(String type) async {
    setState(() {
      _isExporting = true;
    });

    try {
      String filePath;
      String fileName;
      
      switch (type) {
        case 'attendees':
          filePath = await _reportGenerator.exportAttendeesToCSV();
          fileName = 'Attendees Export';
          break;
        case 'services':
          filePath = await _reportGenerator.exportServicesToCSV();
          fileName = 'Services Export';
          break;
        case 'report':
          filePath = await _reportGenerator.exportAttendanceReportToCSV();
          fileName = 'Attendance Report';
          break;
        default:
          throw Exception('Unknown export type');
      }
      
      _showExportSuccessDialog(fileName, filePath);
    } catch (e) {
      _showErrorSnackBar('Export failed: $e');
    } finally {
      setState(() {
        _isExporting = false;
      });
    }
  }

  Future<void> _exportServiceAttendees(int serviceId) async {
    setState(() {
      _isExporting = true;
    });

    try {
      final filePath = await _reportGenerator.exportServiceAttendeesToCSV(serviceId);
      _showExportSuccessDialog('Service Attendees', filePath);
    } catch (e) {
      _showErrorSnackBar('Export failed: $e');
    } finally {
      setState(() {
        _isExporting = false;
      });
    }
  }

  /// Resend message to specific service attendees
  Future<void> _resendMessageToService(ServiceModel service) async {
    try {
      // Load attendees for this service
      final attendees = await _serviceRepository.getServiceAttendees(service.serviceId!);
      
      if (attendees.isEmpty) {
        _showErrorSnackBar('No attendees found for this service');
        return;
      }
      
      // Navigate to messaging screen with pre-selected attendees
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MessagingScreen(
            attendees: attendees,
            serviceId: service.serviceId!,
          ),
        ),
      );
    } catch (e) {
      _showErrorSnackBar('Failed to load service attendees: $e');
    }
  }

  void _showExportSuccessDialog(String fileName, String filePath) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Export Successful'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$fileName has been exported successfully.'),
            const SizedBox(height: 8),
            Text(
              'File saved to:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                filePath,
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: filePath));
              Navigator.of(context).pop();
              _showSuccessSnackBar('File path copied to clipboard');
            },
            child: const Text('Copy Path'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showServiceDetails(ServiceModel service) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Service Details'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Date', service.serviceDate.toString().split(' ')[0]),
              _buildDetailRow('Time', service.serviceDate.toString().split(' ')[1].substring(0, 5)),
              _buildDetailRow('Total Attendees', service.totalAttendees.toString()),
              _buildDetailRow('Message Sent', service.messageSent ? 'Yes' : 'No'),
              if (service.messageText != null) ...[
                const SizedBox(height: 8),
                const Text('Message:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(service.messageText!),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          if (service.serviceId != null)
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _exportServiceAttendees(service.serviceId!);
              },
              child: const Text('Export Attendees'),
            ),
          if (service.serviceId != null)
            ElevatedButton.icon(
              icon: const Icon(Icons.send),
              label: const Text('Resend Message'),
              onPressed: () {
                Navigator.of(context).pop();
                _resendMessageToService(service);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports & Analytics'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _loadInitialData,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Data',
          ),
          PopupMenuButton<String>(
            onSelected: _exportData,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'report',
                child: Row(
                  children: [
                    Icon(Icons.assessment),
                    SizedBox(width: 8),
                    Text('Export Full Report'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'attendees',
                child: Row(
                  children: [
                    Icon(Icons.people),
                    SizedBox(width: 8),
                    Text('Export Attendees'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'services',
                child: Row(
                  children: [
                    Icon(Icons.event),
                    SizedBox(width: 8),
                    Text('Export Services'),
                  ],
                ),
              ),
            ],
            child: _isExporting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.download),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: 'Overview'),
            Tab(icon: Icon(Icons.event), text: 'Services'),
            Tab(icon: Icon(Icons.people), text: 'Attendees'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          _buildServicesTab(),
          _buildAttendeesTab(),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    if (_isLoadingOverview) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_overviewError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error, size: 64, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text(_overviewError!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadOverviewData,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_attendanceReport == null) {
      return const Center(child: Text('No data available'));
    }

    final report = _attendanceReport!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary Statistics Cards
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Total Attendees',
                  report.totalAttendees.toString(),
                  Icons.people,
                  Colors.blue,
                  onTap: () => _navigateToFilteredMembers('All Members', 'active'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatCard(
                  'Total Services',
                  report.totalServices.toString(),
                  Icons.event,
                  Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Avg Attendance',
                  report.averageAttendance.toStringAsFixed(1),
                  Icons.trending_up,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatCard(
                  'Messages Sent',
                  report.servicesWithMessagesSent.toString(),
                  Icons.message,
                  Colors.purple,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Top Attendees Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.star, color: Colors.amber),
                      SizedBox(width: 8),
                      Text(
                        'Top Attendees',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ...report.topAttendees.take(5).map((attendee) => ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue.shade100,
                      child: Text(
                        attendee.attendanceCount.toString(),
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(attendee.name),
                    subtitle: Text('${attendee.yearOfStudy} • ${attendee.location}'),
                    trailing: Text(
                      '${attendee.attendanceCount} visits',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  )),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Recent Services Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.history, color: Colors.green),
                      SizedBox(width: 8),
                      Text(
                        'Recent Services',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ...report.recentServices.take(5).map((service) => ListTile(
                    leading: CircleAvatar(
                      backgroundColor: service.messageSent ? Colors.green.shade100 : Colors.grey.shade100,
                      child: Icon(
                        service.messageSent ? Icons.check : Icons.event,
                        color: service.messageSent ? Colors.green.shade700 : Colors.grey.shade700,
                      ),
                    ),
                    title: Text(service.serviceDate.toString().split(' ')[0]),
                    subtitle: Text('${service.totalAttendees} attendees'),
                    trailing: service.messageSent
                        ? const Icon(Icons.message, color: Colors.green)
                        : null,
                    onTap: () => _showServiceDetails(service),
                  )),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Monthly Trends Section
          if (report.monthlyData.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.analytics, color: Colors.purple),
                        SizedBox(width: 8),
                        Text(
                          'Monthly Trends',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ...report.monthlyData.take(6).map((monthData) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 80,
                            child: Text(
                              monthData['month'] as String,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          Expanded(
                            child: Row(
                              children: [
                                Text('${monthData['total_services']} services'),
                                const SizedBox(width: 16),
                                Text('${monthData['total_attendees']} attendees'),
                                const SizedBox(width: 16),
                                Text('Avg: ${(monthData['average_attendees'] as double).toStringAsFixed(1)}'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildServicesTab() {
    if (_isLoadingServices) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_servicesError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error, size: 64, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text(_servicesError!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadServicesData,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_recentServices.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No services found'),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${_recentServices.length} Services',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _exportData('services'),
                icon: const Icon(Icons.download, size: 16),
                label: const Text('Export'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _recentServices.length,
            itemBuilder: (context, index) {
              final service = _recentServices[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: service.messageSent ? Colors.green.shade100 : Colors.blue.shade100,
                    child: Icon(
                      service.messageSent ? Icons.check_circle : Icons.event,
                      color: service.messageSent ? Colors.green.shade700 : Colors.blue.shade700,
                    ),
                  ),
                  title: Text(
                    service.serviceDate.toString().split(' ')[0],
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${service.totalAttendees} attendees'),
                      Text(
                        'Time: ${service.serviceDate.toString().split(' ')[1].substring(0, 5)}',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                      ),
                    ],
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (service.messageSent)
                        const Icon(Icons.message, color: Colors.green, size: 16),
                      const SizedBox(height: 4),
                      Text(
                        service.totalAttendees.toString(),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  onTap: () => _showServiceDetails(service),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAttendeesTab() {
    if (_isLoadingAttendees) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_attendeesError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error, size: 64, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text(_attendeesError!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadAttendeesData,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_topAttendees.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No attendees found'),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${_topAttendees.length} Attendees',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _exportData('attendees'),
                icon: const Icon(Icons.download, size: 16),
                label: const Text('Export'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _topAttendees.length,
            itemBuilder: (context, index) {
              final attendee = _topAttendees[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _getAttendanceColor(attendee.attendanceCount).withOpacity(0.2),
                    child: Text(
                      attendee.attendanceCount.toString(),
                      style: TextStyle(
                        color: _getAttendanceColor(attendee.attendanceCount),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    attendee.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${attendee.yearOfStudy} • ${attendee.location}'),
                      Text(
                        'Phone: ${attendee.phoneNumber}',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                      ),
                    ],
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${attendee.attendanceCount}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _getAttendanceColor(attendee.attendanceCount),
                        ),
                      ),
                      Text(
                        'visits',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, {VoidCallback? onTap}) {
    final card = Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: card,
      );
    }
    return card;
  }

  void _navigateToFilteredMembers(String title, String filterType, {DateTime? startDate, DateTime? endDate}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FilteredMembersScreen(
          title: title,
          filterType: filterType,
          startDate: startDate,
          endDate: endDate,
        ),
      ),
    );
  }

  Color _getAttendanceColor(int count) {
    if (count >= 10) return Colors.green;
    if (count >= 5) return Colors.orange;
    return Colors.blue;
  }
}