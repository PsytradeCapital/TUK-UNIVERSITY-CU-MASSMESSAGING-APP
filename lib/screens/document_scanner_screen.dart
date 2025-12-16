import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/document_scanner_service.dart';
import '../services/analytics_service.dart';
import '../models/scanned_attendee_model.dart';
import '../theme/app_theme.dart';
import '../widgets/ui_components.dart';
import 'scanned_attendees_review_screen.dart';

/// Screen for scanning attendance documents
class DocumentScannerScreen extends StatefulWidget {
  const DocumentScannerScreen({Key? key}) : super(key: key);

  @override
  State<DocumentScannerScreen> createState() => _DocumentScannerScreenState();
}

class _DocumentScannerScreenState extends State<DocumentScannerScreen>
    with SingleTickerProviderStateMixin {
  final DocumentScannerService _scannerService = DocumentScannerService();
  final AnalyticsService _analyticsService = AnalyticsService();
  
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  
  bool _isScanning = false;
  String _scanStatus = '';
  List<ScannedAttendee> _recentScans = [];

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _trackScreenView();
    _loadRecentScans();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _trackScreenView() async {
    await _analyticsService.trackScreenView(
      screenName: 'Document Scanner',
      screenClass: 'DocumentScannerScreen',
    );
  }

  Future<void> _loadRecentScans() async {
    try {
      final scans = await ScannedAttendeeRepository.loadScannedAttendees();
      setState(() {
        _recentScans = scans.take(5).toList(); // Show last 5 scans
      });
    } catch (e) {
      debugPrint('Error loading recent scans: $e');
    }
  }

  Future<void> _scanFromCamera() async {
    await _performScan(() => _scannerService.scanFromCamera(), 'Camera');
  }

  Future<void> _scanFromGallery() async {
    await _performScan(() => _scannerService.scanFromGallery(), 'Gallery');
  }

  Future<void> _scanMultipleImages() async {
    await _performScan(() => _scannerService.scanMultipleImages(), 'Multiple Images');
  }

  Future<void> _scanFromDocument() async {
    await _performScan(() => _scannerService.scanFromDocument(), 'Document Upload');
  }

  Future<void> _performScan(Future<ScanResult> Function() scanFunction, String source) async {
    setState(() {
      _isScanning = true;
      _scanStatus = 'Initializing scanner...';
    });

    _animationController.repeat();

    try {
      setState(() {
        _scanStatus = 'Processing image...';
      });

      final result = await scanFunction();

      _animationController.stop();
      _animationController.reset();

      if (result.success && result.attendees.isNotEmpty) {
        setState(() {
          _isScanning = false;
          _scanStatus = 'Scan completed successfully!';
        });

        // Track successful scan
        await _analyticsService.trackPerformance(
          operation: 'document_scan_$source',
          durationMs: result.processingTime?.inMilliseconds ?? 0,
          success: true,
        );

        // Navigate to review screen
        if (mounted) {
          final shouldSave = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (context) => ScannedAttendeesReviewScreen(
                scannedAttendees: result.attendees,
                scanSource: source,
              ),
            ),
          );

          if (shouldSave == true) {
            _loadRecentScans(); // Refresh recent scans
            _showSuccessSnackBar('${result.attendees.length} attendees saved successfully!');
          }
        }
      } else {
        setState(() {
          _isScanning = false;
          _scanStatus = '';
        });

        _showErrorDialog(
          'Scan Failed',
          result.error ?? 'No attendees found in the document. Please ensure the image is clear and contains names with phone numbers.',
        );
      }
    } catch (e) {
      _animationController.stop();
      _animationController.reset();
      
      setState(() {
        _isScanning = false;
        _scanStatus = '';
      });

      _showErrorDialog('Scan Error', 'An error occurred while scanning: $e');
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showScanTips() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Scanning Tips'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'For best results:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 12),
              Text('📄 Use clear, well-lit images'),
              SizedBox(height: 8),
              Text('📱 Ensure phone numbers are visible (0712345678 or +254712345678)'),
              SizedBox(height: 8),
              Text('👤 Names should be clearly written'),
              SizedBox(height: 8),
              Text('📍 Include location/region information if available'),
              SizedBox(height: 8),
              Text('📐 Keep the document straight and avoid shadows'),
              SizedBox(height: 8),
              Text('🔍 Higher resolution images work better'),
              SizedBox(height: 8),
              Text('📄 For digital documents, use PDF upload for best accuracy'),
              SizedBox(height: 12),
              Text(
                'Supported formats:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('📷 Images: JPG, PNG, WebP'),
              Text('📄 Documents: PDF, TXT'),
              Text('📝 Handwritten attendance sheets'),
              Text('🖨️ Printed registration forms'),
              Text('📊 Table formats with Name | Phone | Location'),
              Text('📋 List formats with contact information'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Document Scanner'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: _showScanTips,
            tooltip: 'Scanning Tips',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryColor.withOpacity(0.1),
                    AppTheme.primaryColor.withOpacity(0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.document_scanner,
                    size: 48,
                    color: AppTheme.primaryColor,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Scan Attendance Sheets',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Automatically extract names, phone numbers, and locations from physical attendance documents',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Scanning status
            if (_isScanning) ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.primaryColor.withOpacity(0.3),
                  ),
                ),
                child: Column(
                  children: [
                    AnimatedBuilder(
                      animation: _scaleAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _scaleAnimation.value,
                          child: Icon(
                            Icons.scanner,
                            size: 48,
                            color: AppTheme.primaryColor,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _scanStatus,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      backgroundColor: Colors.white.withOpacity(0.3),
                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Scan options
            if (!_isScanning) ...[
              _buildScanOption(
                icon: Icons.camera_alt,
                title: 'Scan with Camera',
                subtitle: 'Take a photo of the attendance sheet',
                onTap: _scanFromCamera,
                color: Colors.blue,
              ),
              
              const SizedBox(height: 16),
              
              _buildScanOption(
                icon: Icons.photo_library,
                title: 'Select from Gallery',
                subtitle: 'Choose an existing photo from your device',
                onTap: _scanFromGallery,
                color: Colors.green,
              ),
              
              const SizedBox(height: 16),
              
              _buildScanOption(
                icon: Icons.photo_library_outlined,
                title: 'Scan Multiple Images',
                subtitle: 'Process multiple attendance sheets at once',
                onTap: _scanMultipleImages,
                color: Colors.orange,
              ),
              
              const SizedBox(height: 16),
              
              _buildScanOption(
                icon: Icons.upload_file,
                title: 'Upload Document',
                subtitle: 'Upload PDF, Word, or text file',
                onTap: _scanFromDocument,
                color: Colors.purple,
              ),

              const SizedBox(height: 32),

              // Recent scans
              if (_recentScans.isNotEmpty) ...[
                Row(
                  children: [
                    Icon(
                      Icons.history,
                      color: Colors.grey[600],
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Recent Scans',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                ...._recentScans.map((attendee) => _buildRecentScanItem(attendee)),
                
                const SizedBox(height: 16),
                
                TextButton.icon(
                  onPressed: () {
                    // Navigate to full scanned attendees list
                  },
                  icon: const Icon(Icons.list),
                  label: const Text('View All Scanned Attendees'),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildScanOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.grey[400],
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentScanItem(ScannedAttendee attendee) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: attendee.confidenceColor.withOpacity(0.1),
          child: Icon(
            Icons.person,
            color: attendee.confidenceColor,
          ),
        ),
        title: Text(
          attendee.name,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(attendee.phoneNumber),
            Text(
              '${attendee.location} • ${attendee.confidenceLevel} confidence',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        trailing: Icon(
          attendee.isVerified ? Icons.verified : Icons.pending,
          color: attendee.isVerified ? Colors.green : Colors.orange,
          size: 20,
        ),
        isThreeLine: true,
      ),
    );
  }
}