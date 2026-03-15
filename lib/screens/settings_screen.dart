import 'package:flutter/material.dart';
import '../services/security_service.dart';
import '../services/database_manager.dart';
import '../services/data_management_service.dart';
import '../services/auth_service.dart';
import 'pin_setup_screen.dart';
import 'user_management_screen.dart';
import 'phone_number_fix_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isLoading = false;
  int _autoLockTimeout = 5;
  bool _isPinSet = false;
  Map<String, int> _databaseStats = {};
  int _databaseSize = 0;
  bool _isAdmin = false;
  final DataManagementService _dataManagementService = DataManagementService();
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _checkAdminStatus();
  }

  Future<void> _checkAdminStatus() async {
    try {
      final isAdmin = await _authService.isUserAdmin();
      setState(() {
        _isAdmin = isAdmin;
      });
    } catch (e) {
      // Silently fail
    }
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final isPinSet = await SecurityService.isPinSet();
      final timeout = await SecurityService.getAutoLockTimeout();
      final stats = await DatabaseManager.instance.getDatabaseStats();
      final size = await DatabaseManager.instance.getDatabaseSize();

      setState(() {
        _isPinSet = isPinSet;
        _autoLockTimeout = timeout;
        _databaseStats = stats;
        _databaseSize = size;
      });
    } catch (e) {
      _showErrorSnackBar('Failed to load settings: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                if (_isAdmin) ...[
                  _buildUserManagementSection(),
                  const SizedBox(height: 24),
                ],
                _buildSecuritySection(),
                const SizedBox(height: 24),
                _buildDataManagementSection(),
                const SizedBox(height: 24),
                _buildDatabaseInfoSection(),
                const SizedBox(height: 24),
                _buildAccountSection(),
              ],
            ),
    );
  }

  Widget _buildUserManagementSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.admin_panel_settings, color: Colors.blue[700]),
                const SizedBox(width: 8),
                const Text(
                  'User Management',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.people),
              title: const Text('Manage Users'),
              subtitle: const Text('Approve users and manage permissions'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const UserManagementScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecuritySection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.security, color: Colors.blue[700]),
                const SizedBox(width: 8),
                const Text(
                  'Security',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.lock),
              title: Text(_isPinSet ? 'Change PIN' : 'Set Up PIN'),
              subtitle: Text(_isPinSet 
                  ? 'Update your security PIN' 
                  : 'Create a PIN to secure your app'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: _handlePinSetup,
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.timer),
              title: const Text('Auto-lock Timeout'),
              subtitle: Text('Lock app after $_autoLockTimeout minutes of inactivity'),
              trailing: DropdownButton<int>(
                value: _autoLockTimeout,
                items: [1, 2, 5, 10, 15, 30].map((minutes) {
                  return DropdownMenuItem<int>(
                    value: minutes,
                    child: Text('$minutes min${minutes == 1 ? '' : 's'}'),
                  );
                }).toList(),
                onChanged: _isPinSet ? _updateAutoLockTimeout : null,
              ),
            ),
            if (!_isPinSet) ...[
              const Divider(),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.orange[700]),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Set up a PIN to enable security features and protect your data.',
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDataManagementSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.storage, color: Colors.blue[700]),
                const SizedBox(width: 8),
                const Text(
                  'Data Management',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.phone_android, color: Colors.orange),
              title: const Text('Fix Phone Numbers'),
              subtitle: const Text('Fix invalid phone numbers in database'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const PhoneNumberFixScreen(),
                  ),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.file_download),
              title: const Text('Export Data'),
              subtitle: const Text('Export attendee data to CSV files'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: _showExportOptions,
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.backup),
              title: const Text('Backup Database'),
              subtitle: const Text('Create a backup of your attendee data'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: _backupDatabase,
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.restore),
              title: const Text('Restore Database'),
              subtitle: const Text('Restore data from a backup file'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: _restoreDatabase,
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.cleaning_services),
              title: const Text('Database Maintenance'),
              subtitle: const Text('Optimize and clean up database'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: _performDatabaseMaintenance,
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.delete_sweep),
              title: const Text('Clear Old Data'),
              subtitle: const Text('Remove old services and inactive attendees'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: _showDataClearingOptions,
            ),
            const Divider(),
            ListTile(
              leading: Icon(Icons.delete_forever, color: Colors.red[700]),
              title: Text(
                'Clear All Data',
                style: TextStyle(color: Colors.red[700]),
              ),
              subtitle: const Text('Permanently delete all attendee data'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: _clearAllData,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDatabaseInfoSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info, color: Colors.blue[700]),
                const SizedBox(width: 8),
                const Text(
                  'Database Information',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow('Database Size', _formatFileSize(_databaseSize)),
            _buildInfoRow('Total Attendees', '${_databaseStats['attendees'] ?? 0}'),
            _buildInfoRow('Total Services', '${_databaseStats['services'] ?? 0}'),
            _buildInfoRow('Service Registrations', '${_databaseStats['service_attendees'] ?? 0}'),
            _buildInfoRow('Message Logs', '${_databaseStats['message_log'] ?? 0}'),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _loadSettings,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh Information'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[700],
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          Text(
            value,
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _handlePinSetup() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => PinSetupScreen(isChangingPin: _isPinSet),
      ),
    );

    if (result == true) {
      await _loadSettings();
    }
  }

  Future<void> _updateAutoLockTimeout(int? newTimeout) async {
    if (newTimeout == null) return;

    try {
      await SecurityService.setAutoLockTimeout(newTimeout);
      setState(() {
        _autoLockTimeout = newTimeout;
      });
      _showSuccessSnackBar('Auto-lock timeout updated');
    } catch (e) {
      _showErrorSnackBar('Failed to update timeout: $e');
    }
  }

  Future<void> _backupDatabase() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final backupPath = await DatabaseManager.instance.backupDatabase();
      
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Backup Created'),
            content: Text('Database backup saved to:\n$backupPath'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      _showErrorSnackBar('Failed to create backup: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _restoreDatabase() async {
    // In a real app, you would show a file picker here
    // For now, just show a placeholder dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore Database'),
        content: const Text(
          'This feature would allow you to select a backup file and restore your database. '
          'Implementation requires file picker functionality.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _optimizeDatabase() async {
    try {
      setState(() {
        _isLoading = true;
      });

      await DatabaseManager.instance.vacuumDatabase();
      await _loadSettings(); // Refresh stats
      
      _showSuccessSnackBar('Database optimized successfully');
    } catch (e) {
      _showErrorSnackBar('Failed to optimize database: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _clearAllData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Data'),
        content: const Text(
          'This will permanently delete all attendee data, services, and message logs. '
          'This action cannot be undone.\n\nAre you sure you want to continue?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        setState(() {
          _isLoading = true;
        });

        await DatabaseManager.instance.clearAllData();
        await _loadSettings(); // Refresh stats
        
        _showSuccessSnackBar('All data cleared successfully');
      } catch (e) {
        _showErrorSnackBar('Failed to clear data: $e');
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showExportOptions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.file_download, color: Colors.blue),
            SizedBox(width: 8),
            Text('Export Data'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: _dataManagementService.getDataExportOptions().map((option) {
            return ListTile(
              leading: Icon(_getIconData(option.icon)),
              title: Text(option.title),
              subtitle: Text(option.description),
              onTap: () {
                Navigator.of(context).pop();
                _performExport(option.id);
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showDataClearingOptions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.delete_sweep, color: Colors.orange),
            SizedBox(width: 8),
            Text('Clear Old Data'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: _dataManagementService.getDataClearingOptions().map((option) {
            Color color = option.severity == DataClearingSeverity.high 
                ? Colors.red 
                : option.severity == DataClearingSeverity.medium 
                    ? Colors.orange 
                    : Colors.blue;
            
            return ListTile(
              leading: Icon(_getIconData(option.icon), color: color),
              title: Text(option.title, style: TextStyle(color: color)),
              subtitle: Text(option.description),
              onTap: () {
                Navigator.of(context).pop();
                _performDataClearing(option.id);
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _performExport(String exportType) async {
    setState(() => _isLoading = true);
    
    try {
      String filePath;
      
      switch (exportType) {
        case 'all_attendees':
          filePath = await _dataManagementService.exportAttendeesToCSV(includeAllAttendees: true);
          break;
        case 'current_session':
          // This would need session provider integration
          _showErrorSnackBar('Current session export not yet implemented');
          return;
        case 'service_history':
          _showErrorSnackBar('Service history export not yet implemented');
          return;
        case 'attendance_summary':
          _showErrorSnackBar('Attendance summary export not yet implemented');
          return;
        default:
          _showErrorSnackBar('Unknown export type');
          return;
      }
      
      // Share the exported file
      await _dataManagementService.shareCSVFile(filePath);
      _showSuccessSnackBar('Data exported and shared successfully');
      
    } catch (e) {
      _showErrorSnackBar('Export failed: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _performDataClearing(String clearingType) async {
    // Show confirmation dialog first
    final confirmed = await _showConfirmationDialog(
      'Confirm Data Clearing',
      'Are you sure you want to proceed with this data clearing operation? This action cannot be undone.',
    );
    
    if (!confirmed) return;
    
    setState(() => _isLoading = true);
    
    try {
      DataClearingResult result;
      
      switch (clearingType) {
        case 'old_services':
          // Ask for number of days
          final days = await _askForDays();
          if (days == null) return;
          result = await _dataManagementService.clearOldServiceData(olderThanDays: days);
          break;
        case 'inactive_attendees':
          result = await _dataManagementService.clearInactiveAttendees();
          break;
        case 'all_data':
          result = await _dataManagementService.clearAllData();
          break;
        default:
          _showErrorSnackBar('Unknown clearing type');
          return;
      }
      
      _showSuccessSnackBar(result.details);
      await _loadSettings(); // Refresh stats
      
    } catch (e) {
      _showErrorSnackBar('Data clearing failed: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _performDatabaseMaintenance() async {
    setState(() => _isLoading = true);
    
    try {
      final result = await _dataManagementService.performDatabaseMaintenance();
      
      if (result.success) {
        _showSuccessSnackBar('Database maintenance completed successfully');
        await _loadSettings(); // Refresh stats
      } else {
        _showErrorSnackBar('Database maintenance failed: ${result.operations.join(', ')}');
      }
      
    } catch (e) {
      _showErrorSnackBar('Database maintenance failed: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<bool> _showConfirmationDialog(String title, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Confirm', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    
    return result ?? false;
  }

  Future<int?> _askForDays() async {
    final controller = TextEditingController(text: '30');
    
    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Old Services'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Remove services older than how many days?'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Days',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final days = int.tryParse(controller.text);
              Navigator.of(context).pop(days);
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    
    return result;
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'people': return Icons.people;
      case 'event': return Icons.event;
      case 'history': return Icons.history;
      case 'analytics': return Icons.analytics;
      case 'delete_sweep': return Icons.delete_sweep;
      case 'person_remove': return Icons.person_remove;
      case 'warning': return Icons.warning;
      default: return Icons.help;
    }
  }

  void _showSuccessSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildAccountSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.account_circle, color: Colors.blue[700]),
                const SizedBox(width: 8),
                const Text(
                  'Account',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text(
                'Sign Out',
                style: TextStyle(color: Colors.red),
              ),
              subtitle: const Text('Sign out of your account'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: _handleSignOut,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sign Out', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _authService.signOut();
        // The AuthWrapper will automatically redirect to login screen
      } catch (e) {
        _showErrorSnackBar('Failed to sign out: $e');
      }
    }
  }
}