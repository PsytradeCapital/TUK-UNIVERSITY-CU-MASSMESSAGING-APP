import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../services/migration_tool.dart';
import '../services/data_migration_service.dart';
import '../services/data_import_service.dart';
import '../services/data_export_service.dart';

class DataMigrationScreen extends StatefulWidget {
  const DataMigrationScreen({Key? key}) : super(key: key);

  @override
  State<DataMigrationScreen> createState() => _DataMigrationScreenState();
}

class _DataMigrationScreenState extends State<DataMigrationScreen> {
  final MigrationTool _migrationTool = MigrationTool();
  
  bool _isLoading = false;
  String? _statusMessage;
  MigrationStatus? _migrationStatus;
  ExportStatistics? _exportStats;
  List<BackupInfo> _cloudBackups = [];

  @override
  void initState() {
    super.initState();
    _loadMigrationStatus();
  }

  Future<void> _loadMigrationStatus() async {
    try {
      setState(() => _isLoading = true);
      
      final status = await _migrationTool.getMigrationStatus();
      setState(() => _migrationStatus = status);

      if (_migrationTool.isAuthenticated) {
        final stats = await _migrationTool.getExportStatistics();
        final backups = await _migrationTool.listCloudBackups();
        setState(() {
          _exportStats = stats;
          _cloudBackups = backups;
        });
      }
    } catch (e) {
      _showError('Failed to load migration status: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _exportLocalData() async {
    try {
      setState(() {
        _isLoading = true;
        _statusMessage = 'Exporting local data...';
      });

      final filePath = await _migrationTool.exportLocalData();
      
      setState(() => _statusMessage = 'Local data exported to: $filePath');
      _showSuccess('Local data exported successfully!');
    } catch (e) {
      _showError('Failed to export local data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _performCompleteMigration() async {
    try {
      setState(() {
        _isLoading = true;
        _statusMessage = 'Performing complete migration...';
      });

      final result = await _migrationTool.performCompleteMigration();
      
      if (result.success) {
        setState(() => _statusMessage = 'Migration completed successfully!');
        _showMigrationResults(result);
        await _loadMigrationStatus(); // Refresh status
      } else {
        _showError('Migration failed: ${result.errorMessage}');
      }
    } catch (e) {
      _showError('Failed to perform migration: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _importFromFile() async {
    try {
      // Pick JSON file
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null || result.files.isEmpty) return;

      final filePath = result.files.first.path!;

      setState(() {
        _isLoading = true;
        _statusMessage = 'Validating import file...';
      });

      // Validate file first
      final validation = await _migrationTool.validateImportFile(filePath);
      if (!validation.isValid) {
        _showError('Invalid import file: ${validation.errorMessage}');
        return;
      }

      // Show validation results and confirm
      final confirmed = await _showImportConfirmation(validation);
      if (!confirmed) return;

      setState(() => _statusMessage = 'Importing data...');

      // Perform import
      final importResult = await _migrationTool.importFromJson(filePath);
      
      if (importResult.success) {
        _showImportResults(importResult);
        await _loadMigrationStatus(); // Refresh status
      } else {
        _showError('Import failed with ${importResult.totalErrors} errors');
      }
    } catch (e) {
      _showError('Failed to import from file: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _createBackup() async {
    try {
      setState(() {
        _isLoading = true;
        _statusMessage = 'Creating backup...';
      });

      final result = await _migrationTool.createFullBackup();
      
      if (result.success && result.localFilePath != null) {
        // Store in cloud
        setState(() => _statusMessage = 'Storing backup in cloud...');
        final cloudUrl = await _migrationTool.storeBackupInCloud(result.localFilePath!);
        
        setState(() => _statusMessage = 'Backup created successfully!');
        _showSuccess('Backup stored in cloud: $cloudUrl');
        await _loadMigrationStatus(); // Refresh backups list
      } else {
        _showError('Failed to create backup');
      }
    } catch (e) {
      _showError('Failed to create backup: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<bool> _showImportConfirmation(ValidationResult validation) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Import'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Import ${validation.totalItems} items?'),
            const SizedBox(height: 8),
            Text('• Attendees: ${validation.attendeesCount}'),
            Text('• Message Logs: ${validation.messageLogsCount}'),
            Text('• Services: ${validation.servicesCount}'),
            const SizedBox(height: 8),
            Text('Exported: ${validation.exportedAt}'),
            Text('Version: ${validation.version}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Import'),
          ),
        ],
      ),
    ) ?? false;
  }

  void _showMigrationResults(CompleteMigrationResult result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Migration Results'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Duration: ${result.duration?.inSeconds}s'),
            const SizedBox(height: 8),
            Text('✓ Export: ${result.exportCompleted ? 'Success' : 'Failed'}'),
            Text('✓ Import: ${result.importCompleted ? 'Success' : 'Failed'}'),
            Text('✓ Backup: ${result.backupCompleted ? 'Success' : 'Failed'}'),
            const SizedBox(height: 8),
            if (result.importResult != null) ...[
              Text('Attendees: ${result.importResult!.attendeesImported}'),
              Text('Message Logs: ${result.importResult!.messageLogsImported}'),
              Text('Services: ${result.importResult!.servicesImported}'),
            ],
            if (result.warnings.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('Warnings:', style: TextStyle(fontWeight: FontWeight.bold)),
              ...result.warnings.map((w) => Text('• $w')),
            ],
          ],
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

  void _showImportResults(ImportResult result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import Results'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Success Rate: ${result.successRate.toStringAsFixed(1)}%'),
            Text('Duration: ${result.duration?.inSeconds}s'),
            const SizedBox(height: 8),
            Text('Attendees: ${result.attendeesImported}/${result.attendeesProcessed}'),
            Text('Message Logs: ${result.messageLogsImported}/${result.messageLogsProcessed}'),
            Text('Services: ${result.servicesImported}/${result.servicesProcessed}'),
            const SizedBox(height: 8),
            Text('Total Errors: ${result.totalErrors}'),
            if (result.warnings.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('Warnings:', style: TextStyle(fontWeight: FontWeight.bold)),
              ...result.warnings.take(3).map((w) => Text('• $w')),
              if (result.warnings.length > 3)
                Text('... and ${result.warnings.length - 3} more'),
            ],
          ],
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

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showError(String message) {
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
        title: const Text('Data Migration'),
        backgroundColor: Colors.blue,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_statusMessage != null) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(_statusMessage!),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  
                  // Migration Status
                  _buildMigrationStatusCard(),
                  const SizedBox(height: 16),
                  
                  // Migration Actions
                  _buildMigrationActionsCard(),
                  const SizedBox(height: 16),
                  
                  // Export Statistics
                  if (_exportStats != null) ...[
                    _buildExportStatisticsCard(),
                    const SizedBox(height: 16),
                  ],
                  
                  // Cloud Backups
                  if (_cloudBackups.isNotEmpty) ...[
                    _buildCloudBackupsCard(),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildMigrationStatusCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Migration Status',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (_migrationStatus != null) ...[
              _buildStatusRow('Authenticated', _migrationStatus!.isAuthenticated),
              _buildStatusRow('Local Data', _migrationStatus!.localDataExists),
              _buildStatusRow('Cloud Data', _migrationStatus!.cloudDataExists),
              const SizedBox(height: 8),
              Text('Local Attendees: ${_migrationStatus!.localAttendeesCount}'),
              Text('Local Messages: ${_migrationStatus!.localMessageLogsCount}'),
              Text('Local Services: ${_migrationStatus!.localServicesCount}'),
            ] else ...[
              const Text('Loading status...'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(String label, bool status) {
    return Row(
      children: [
        Icon(
          status ? Icons.check_circle : Icons.cancel,
          color: status ? Colors.green : Colors.red,
          size: 16,
        ),
        const SizedBox(width: 8),
        Text(label),
      ],
    );
  }

  Widget _buildMigrationActionsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Migration Actions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            // Export Local Data
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _migrationTool.isAuthenticated ? _exportLocalData : null,
                icon: const Icon(Icons.upload),
                label: const Text('Export Local Data'),
              ),
            ),
            const SizedBox(height: 8),
            
            // Complete Migration
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _migrationTool.isAuthenticated ? _performCompleteMigration : null,
                icon: const Icon(Icons.sync),
                label: const Text('Complete Migration'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              ),
            ),
            const SizedBox(height: 8),
            
            // Import from File
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _migrationTool.isAuthenticated ? _importFromFile : null,
                icon: const Icon(Icons.download),
                label: const Text('Import from File'),
              ),
            ),
            const SizedBox(height: 8),
            
            // Create Backup
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _migrationTool.isAuthenticated ? _createBackup : null,
                icon: const Icon(Icons.backup),
                label: const Text('Create Backup'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              ),
            ),
            
            if (!_migrationTool.isAuthenticated) ...[
              const SizedBox(height: 8),
              const Text(
                'Please log in to use migration features',
                style: TextStyle(color: Colors.red),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildExportStatisticsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Export Statistics',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Total Data Items: ${_exportStats!.totalDataItems}'),
            Text('Attendees: ${_exportStats!.totalAttendees}'),
            Text('Message Logs: ${_exportStats!.totalMessageLogs}'),
            Text('Services: ${_exportStats!.totalServices}'),
            const SizedBox(height: 8),
            Text('Available Backups: ${_exportStats!.availableBackups}'),
            Text('Total Backup Size: ${_exportStats!.formattedBackupSize}'),
            if (_exportStats!.lastBackupDate != null)
              Text('Last Backup: ${_exportStats!.lastBackupDate}'),
          ],
        ),
      ),
    );
  }

  Widget _buildCloudBackupsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Cloud Backups',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _cloudBackups.length,
              itemBuilder: (context, index) {
                final backup = _cloudBackups[index];
                return ListTile(
                  leading: const Icon(Icons.backup),
                  title: Text(backup.name),
                  subtitle: Text('${backup.formattedSize} • ${backup.createdAt}'),
                  trailing: PopupMenuButton(
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'download',
                        child: Text('Download'),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete'),
                      ),
                    ],
                    onSelected: (value) async {
                      if (value == 'download') {
                        // Implement download
                      } else if (value == 'delete') {
                        // Implement delete
                        await _migrationTool.deleteCloudBackup(backup.path);
                        await _loadMigrationStatus();
                      }
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}