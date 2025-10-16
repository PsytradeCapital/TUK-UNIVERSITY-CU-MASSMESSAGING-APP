import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../models/attendee_model.dart';
import '../models/service_model.dart';
import '../repositories/attendee_repository.dart';
import '../repositories/service_repository.dart';
import '../repositories/message_log_repository.dart';

class ReportGenerator {
  final AttendeeRepository _attendeeRepository = AttendeeRepository();
  final ServiceRepository _serviceRepository = ServiceRepository();
  final MessageLogRepository _messageLogRepository = MessageLogRepository();

  // Generate comprehensive attendance statistics
  Future<AttendanceReport> generateAttendanceReport() async {
    try {
      // Get basic statistics
      final attendeeStats = await _attendeeRepository.getAttendanceStatistics();
      final serviceStats = await _serviceRepository.getServiceStatistics();
      
      // Get detailed data
      final allAttendees = await _attendeeRepository.getAllAttendees();
      final recentServices = await _serviceRepository.getRecentServices(limit: 10);
      final monthlyData = await _serviceRepository.getMonthlyAttendanceSummary();
      
      // Calculate additional metrics
      final topAttendees = await _attendeeRepository.getAttendeesWithMinAttendance(1);
      topAttendees.sort((a, b) => b.attendanceCount.compareTo(a.attendanceCount));
      
      // Get attendance trends
      final attendanceHistory = await _serviceRepository.getAttendanceHistory(limit: 20);
      
      return AttendanceReport(
        totalAttendees: attendeeStats['totalAttendees'] ?? 0,
        totalServices: serviceStats['totalServices'] ?? 0,
        averageAttendance: attendeeStats['averageAttendance'] ?? 0.0,
        averageAttendeesPerService: serviceStats['averageAttendeesPerService'] ?? 0.0,
        maxAttendance: attendeeStats['maxAttendance'] ?? 0,
        maxAttendeesInService: serviceStats['maxAttendeesInService'] ?? 0,
        totalUniqueAttendees: serviceStats['totalUniqueAttendees'] ?? 0,
        servicesWithMessagesSent: serviceStats['servicesWithMessagesSent'] ?? 0,
        mostRecentServiceDate: serviceStats['mostRecentServiceDate'],
        topAttendees: topAttendees.take(10).toList(),
        recentServices: recentServices,
        monthlyData: monthlyData,
        attendanceHistory: attendanceHistory,
        generatedAt: DateTime.now(),
      );
    } catch (e) {
      throw ReportGeneratorException('Failed to generate attendance report: $e');
    }
  }

  // Generate service-specific report
  Future<ServiceReport> generateServiceReport(int serviceId) async {
    try {
      final service = await _serviceRepository.getServiceById(serviceId);
      if (service == null) {
        throw ReportGeneratorException('Service not found');
      }

      final attendees = await _serviceRepository.getServiceAttendees(serviceId);
      final messageLogs = await _messageLogRepository.getMessageLogsByService(serviceId);
      
      // Calculate statistics for this service
      final yearDistribution = <String, int>{};
      final locationDistribution = <String, int>{};
      
      for (final attendee in attendees) {
        yearDistribution[attendee.yearOfStudy] = (yearDistribution[attendee.yearOfStudy] ?? 0) + 1;
        locationDistribution[attendee.location] = (locationDistribution[attendee.location] ?? 0) + 1;
      }

      // Calculate message statistics
      final messageStats = _calculateMessageStatistics(messageLogs);

      return ServiceReport(
        service: service,
        attendees: attendees,
        totalAttendees: attendees.length,
        yearDistribution: yearDistribution,
        locationDistribution: locationDistribution,
        messageStats: messageStats,
        messageLogs: messageLogs,
        generatedAt: DateTime.now(),
      );
    } catch (e) {
      throw ReportGeneratorException('Failed to generate service report: $e');
    }
  }

  // Generate individual attendee report
  Future<AttendeeReport> generateAttendeeReport(int attendeeId) async {
    try {
      final attendee = await _attendeeRepository.getAttendeeById(attendeeId);
      if (attendee == null) {
        throw ReportGeneratorException('Attendee not found');
      }

      final servicesAttended = await _serviceRepository.getServicesAttendedByAttendee(attendeeId);
      final messageLogs = await _messageLogRepository.getMessageLogsByAttendee(attendeeId);
      
      // Calculate attendance patterns
      final attendancePattern = _calculateAttendancePattern(servicesAttended);
      
      return AttendeeReport(
        attendee: attendee,
        servicesAttended: servicesAttended,
        totalServicesAttended: servicesAttended.length,
        attendancePattern: attendancePattern,
        messageLogs: messageLogs,
        generatedAt: DateTime.now(),
      );
    } catch (e) {
      throw ReportGeneratorException('Failed to generate attendee report: $e');
    }
  }

  // Export attendees to CSV
  Future<String> exportAttendeesToCSV({List<AttendeeModel>? attendees}) async {
    try {
      attendees ??= await _attendeeRepository.getAllAttendees();
      
      final csvData = StringBuffer();
      
      // CSV Header
      csvData.writeln('ID,Name,Phone Number,Year of Study,Location,Attendance Count,First Registered,Last Updated');
      
      // CSV Data
      for (final attendee in attendees) {
        csvData.writeln([
          attendee.id,
          _escapeCsvField(attendee.name),
          _escapeCsvField(attendee.phoneNumber),
          _escapeCsvField(attendee.yearOfStudy),
          _escapeCsvField(attendee.location),
          attendee.attendanceCount,
          attendee.firstRegistered.toIso8601String(),
          attendee.lastUpdated.toIso8601String(),
        ].join(','));
      }
      
      // Save to file
      final fileName = 'attendees_export_${DateTime.now().millisecondsSinceEpoch}.csv';
      final filePath = await _saveToFile(fileName, csvData.toString());
      
      return filePath;
    } catch (e) {
      throw ReportGeneratorException('Failed to export attendees to CSV: $e');
    }
  }

  // Export services to CSV
  Future<String> exportServicesToCSV({List<ServiceModel>? services}) async {
    try {
      services ??= await _serviceRepository.getAllServices();
      
      final csvData = StringBuffer();
      
      // CSV Header
      csvData.writeln('Service ID,Service Date,Total Attendees,Message Sent,Message Text,Created At');
      
      // CSV Data
      for (final service in services) {
        csvData.writeln([
          service.serviceId,
          service.serviceDate.toIso8601String(),
          service.totalAttendees,
          service.messageSent ? 'Yes' : 'No',
          _escapeCsvField(service.messageText ?? ''),
          service.createdAt.toIso8601String(),
        ].join(','));
      }
      
      // Save to file
      final fileName = 'services_export_${DateTime.now().millisecondsSinceEpoch}.csv';
      final filePath = await _saveToFile(fileName, csvData.toString());
      
      return filePath;
    } catch (e) {
      throw ReportGeneratorException('Failed to export services to CSV: $e');
    }
  }

  // Export service attendees to CSV
  Future<String> exportServiceAttendeesToCSV(int serviceId) async {
    try {
      final service = await _serviceRepository.getServiceById(serviceId);
      if (service == null) {
        throw ReportGeneratorException('Service not found');
      }

      final attendees = await _serviceRepository.getServiceAttendees(serviceId);
      
      final csvData = StringBuffer();
      
      // CSV Header with service info
      csvData.writeln('Service Date: ${service.serviceDate.toIso8601String()}');
      csvData.writeln('Total Attendees: ${attendees.length}');
      csvData.writeln('Message Sent: ${service.messageSent ? "Yes" : "No"}');
      csvData.writeln('');
      csvData.writeln('ID,Name,Phone Number,Year of Study,Location,Total Attendance Count');
      
      // CSV Data
      for (final attendee in attendees) {
        csvData.writeln([
          attendee.id,
          _escapeCsvField(attendee.name),
          _escapeCsvField(attendee.phoneNumber),
          _escapeCsvField(attendee.yearOfStudy),
          _escapeCsvField(attendee.location),
          attendee.attendanceCount,
        ].join(','));
      }
      
      // Save to file
      final fileName = 'service_${serviceId}_attendees_${DateTime.now().millisecondsSinceEpoch}.csv';
      final filePath = await _saveToFile(fileName, csvData.toString());
      
      return filePath;
    } catch (e) {
      throw ReportGeneratorException('Failed to export service attendees to CSV: $e');
    }
  }

  // Export comprehensive attendance report to CSV
  Future<String> exportAttendanceReportToCSV() async {
    try {
      final report = await generateAttendanceReport();
      
      final csvData = StringBuffer();
      
      // Report Header
      csvData.writeln('Christian Union Attendance Report');
      csvData.writeln('Generated: ${report.generatedAt.toIso8601String()}');
      csvData.writeln('');
      
      // Summary Statistics
      csvData.writeln('SUMMARY STATISTICS');
      csvData.writeln('Total Registered Attendees,${report.totalAttendees}');
      csvData.writeln('Total Services Held,${report.totalServices}');
      csvData.writeln('Average Individual Attendance,${report.averageAttendance.toStringAsFixed(2)}');
      csvData.writeln('Average Attendees Per Service,${report.averageAttendeesPerService.toStringAsFixed(2)}');
      csvData.writeln('Highest Individual Attendance,${report.maxAttendance}');
      csvData.writeln('Highest Service Attendance,${report.maxAttendeesInService}');
      csvData.writeln('Services with Messages Sent,${report.servicesWithMessagesSent}');
      csvData.writeln('');
      
      // Top Attendees
      csvData.writeln('TOP ATTENDEES');
      csvData.writeln('Rank,Name,Phone Number,Attendance Count');
      for (int i = 0; i < report.topAttendees.length; i++) {
        final attendee = report.topAttendees[i];
        csvData.writeln([
          i + 1,
          _escapeCsvField(attendee.name),
          _escapeCsvField(attendee.phoneNumber),
          attendee.attendanceCount,
        ].join(','));
      }
      csvData.writeln('');
      
      // Monthly Summary
      csvData.writeln('MONTHLY SUMMARY');
      csvData.writeln('Month,Total Services,Total Attendees,Average Attendees,Services with Messages');
      for (final monthData in report.monthlyData) {
        csvData.writeln([
          monthData['month'],
          monthData['total_services'],
          monthData['total_attendees'],
          (monthData['average_attendees'] as double).toStringAsFixed(2),
          monthData['services_with_messages'],
        ].join(','));
      }
      
      // Save to file
      final fileName = 'attendance_report_${DateTime.now().millisecondsSinceEpoch}.csv';
      final filePath = await _saveToFile(fileName, csvData.toString());
      
      return filePath;
    } catch (e) {
      throw ReportGeneratorException('Failed to export attendance report to CSV: $e');
    }
  }

  // Get attendance trends for charts/graphs
  Future<List<AttendanceTrend>> getAttendanceTrends({int months = 12}) async {
    try {
      final monthlyData = await _serviceRepository.getMonthlyAttendanceSummary();
      
      return monthlyData.take(months).map((data) => AttendanceTrend(
        month: data['month'] as String,
        totalServices: data['total_services'] as int,
        totalAttendees: data['total_attendees'] as int,
        averageAttendees: (data['average_attendees'] as double).round(),
        servicesWithMessages: data['services_with_messages'] as int,
      )).toList();
    } catch (e) {
      throw ReportGeneratorException('Failed to get attendance trends: $e');
    }
  }

  // Private helper methods
  String _escapeCsvField(String field) {
    if (field.contains(',') || field.contains('"') || field.contains('\n')) {
      return '"${field.replaceAll('"', '""')}"';
    }
    return field;
  }

  Future<String> _saveToFile(String fileName, String content) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final reportsDir = Directory(path.join(directory.path, 'reports'));
      
      if (!await reportsDir.exists()) {
        await reportsDir.create(recursive: true);
      }
      
      final file = File(path.join(reportsDir.path, fileName));
      await file.writeAsString(content);
      
      return file.path;
    } catch (e) {
      throw ReportGeneratorException('Failed to save file: $e');
    }
  }

  Map<String, dynamic> _calculateMessageStatistics(List<dynamic> messageLogs) {
    int totalMessages = messageLogs.length;
    int sentMessages = 0;
    int failedMessages = 0;
    int pendingMessages = 0;
    
    for (final log in messageLogs) {
      final status = log.sendStatus ?? 'pending';
      switch (status) {
        case 'sent':
          sentMessages++;
          break;
        case 'failed':
          failedMessages++;
          break;
        default:
          pendingMessages++;
      }
    }
    
    return {
      'totalMessages': totalMessages,
      'sentMessages': sentMessages,
      'failedMessages': failedMessages,
      'pendingMessages': pendingMessages,
      'successRate': totalMessages > 0 ? (sentMessages / totalMessages * 100).toStringAsFixed(2) : '0.00',
    };
  }

  Map<String, dynamic> _calculateAttendancePattern(List<ServiceModel> services) {
    if (services.isEmpty) {
      return {
        'totalServices': 0,
        'averageGapDays': 0.0,
        'longestGapDays': 0,
        'mostRecentAttendance': null,
        'attendanceFrequency': 'Never',
      };
    }
    
    services.sort((a, b) => a.serviceDate.compareTo(b.serviceDate));
    
    List<int> gaps = [];
    for (int i = 1; i < services.length; i++) {
      final gap = services[i].serviceDate.difference(services[i-1].serviceDate).inDays;
      gaps.add(gap);
    }
    
    final averageGap = gaps.isNotEmpty ? gaps.reduce((a, b) => a + b) / gaps.length : 0.0;
    final longestGap = gaps.isNotEmpty ? gaps.reduce((a, b) => a > b ? a : b) : 0;
    
    String frequency = 'Irregular';
    if (averageGap <= 7) frequency = 'Weekly';
    else if (averageGap <= 14) frequency = 'Bi-weekly';
    else if (averageGap <= 30) frequency = 'Monthly';
    
    return {
      'totalServices': services.length,
      'averageGapDays': averageGap,
      'longestGapDays': longestGap,
      'mostRecentAttendance': services.last.serviceDate.toIso8601String(),
      'attendanceFrequency': frequency,
    };
  }
}

// Data classes for reports
class AttendanceReport {
  final int totalAttendees;
  final int totalServices;
  final double averageAttendance;
  final double averageAttendeesPerService;
  final int maxAttendance;
  final int maxAttendeesInService;
  final int totalUniqueAttendees;
  final int servicesWithMessagesSent;
  final String? mostRecentServiceDate;
  final List<AttendeeModel> topAttendees;
  final List<ServiceModel> recentServices;
  final List<Map<String, dynamic>> monthlyData;
  final List<Map<String, dynamic>> attendanceHistory;
  final DateTime generatedAt;

  AttendanceReport({
    required this.totalAttendees,
    required this.totalServices,
    required this.averageAttendance,
    required this.averageAttendeesPerService,
    required this.maxAttendance,
    required this.maxAttendeesInService,
    required this.totalUniqueAttendees,
    required this.servicesWithMessagesSent,
    this.mostRecentServiceDate,
    required this.topAttendees,
    required this.recentServices,
    required this.monthlyData,
    required this.attendanceHistory,
    required this.generatedAt,
  });
}

class ServiceReport {
  final ServiceModel service;
  final List<AttendeeModel> attendees;
  final int totalAttendees;
  final Map<String, int> yearDistribution;
  final Map<String, int> locationDistribution;
  final Map<String, dynamic> messageStats;
  final List<dynamic> messageLogs;
  final DateTime generatedAt;

  ServiceReport({
    required this.service,
    required this.attendees,
    required this.totalAttendees,
    required this.yearDistribution,
    required this.locationDistribution,
    required this.messageStats,
    required this.messageLogs,
    required this.generatedAt,
  });
}

class AttendeeReport {
  final AttendeeModel attendee;
  final List<ServiceModel> servicesAttended;
  final int totalServicesAttended;
  final Map<String, dynamic> attendancePattern;
  final List<dynamic> messageLogs;
  final DateTime generatedAt;

  AttendeeReport({
    required this.attendee,
    required this.servicesAttended,
    required this.totalServicesAttended,
    required this.attendancePattern,
    required this.messageLogs,
    required this.generatedAt,
  });
}

class AttendanceTrend {
  final String month;
  final int totalServices;
  final int totalAttendees;
  final int averageAttendees;
  final int servicesWithMessages;

  AttendanceTrend({
    required this.month,
    required this.totalServices,
    required this.totalAttendees,
    required this.averageAttendees,
    required this.servicesWithMessages,
  });
}

// Custom exception for report generator operations
class ReportGeneratorException implements Exception {
  final String message;
  
  ReportGeneratorException(this.message);
  
  @override
  String toString() => 'ReportGeneratorException: $message';
}