import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:file_picker/file_picker.dart';
// import 'package:pdf_text/pdf_text.dart'; // Commented out - package not available
import '../models/scanned_attendee_model.dart';
import '../models/attendee_model.dart';
import 'analytics_service.dart';

/// Service for scanning and processing attendance sheets
/// Extracts names, phone numbers, and regions from physical documents
class DocumentScannerService {
  static final DocumentScannerService _instance = DocumentScannerService._internal();
  factory DocumentScannerService() => _instance;
  DocumentScannerService._internal();

  final ImagePicker _imagePicker = ImagePicker();
  final TextRecognizer _textRecognizer = TextRecognizer();
  final AnalyticsService _analyticsService = AnalyticsService();

  /// Scan attendance sheet from camera
  Future<ScanResult> scanFromCamera() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 90,
        preferredCameraDevice: CameraDevice.rear,
      );

      if (image == null) {
        return ScanResult(
          success: false,
          error: 'No image captured',
        );
      }

      await _analyticsService.trackScreenView(
        screenName: 'Document Scanner - Camera',
      );

      return await _processImage(image);
    } catch (e) {
      debugPrint('Camera scan error: $e');
      return ScanResult(
        success: false,
        error: 'Camera error: $e',
      );
    }
  }

  /// Scan attendance sheet from gallery
  Future<ScanResult> scanFromGallery() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );

      if (image == null) {
        return ScanResult(
          success: false,
          error: 'No image selected',
        );
      }

      await _analyticsService.trackScreenView(
        screenName: 'Document Scanner - Gallery',
      );

      return await _processImage(image);
    } catch (e) {
      debugPrint('Gallery scan error: $e');
      return ScanResult(
        success: false,
        error: 'Gallery error: $e',
      );
    }
  }

  /// Scan document from file (PDF, Word, etc.)
  Future<ScanResult> scanFromDocument() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'txt'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        return ScanResult(
          success: false,
          error: 'No document selected',
        );
      }

      final file = result.files.first;
      
      await _analyticsService.trackScreenView(
        screenName: 'Document Scanner - File',
      );

      return await _processDocument(file);
    } catch (e) {
      debugPrint('Document scan error: $e');
      return ScanResult(
        success: false,
        error: 'Document scan error: $e',
      );
    }
  }

  /// Process multiple images at once
  Future<ScanResult> scanMultipleImages() async {
    try {
      final List<XFile> images = await _imagePicker.pickMultiImage(
        imageQuality: 90,
      );

      if (images.isEmpty) {
        return ScanResult(
          success: false,
          error: 'No images selected',
        );
      }

      List<ScannedAttendee> allAttendees = [];
      List<String> errors = [];

      for (int i = 0; i < images.length; i++) {
        try {
          final result = await _processImage(images[i]);
          if (result.success) {
            allAttendees.addAll(result.attendees);
          } else {
            errors.add('Image ${i + 1}: ${result.error}');
          }
        } catch (e) {
          errors.add('Image ${i + 1}: Processing failed - $e');
        }
      }

      return ScanResult(
        success: allAttendees.isNotEmpty,
        attendees: allAttendees,
        error: errors.isNotEmpty ? errors.join('\n') : null,
        totalImages: images.length,
      );
    } catch (e) {
      debugPrint('Multiple image scan error: $e');
      return ScanResult(
        success: false,
        error: 'Multiple image scan error: $e',
      );
    }
  }

  /// Process a document file (PDF, Word, etc.)
  Future<ScanResult> _processDocument(PlatformFile file) async {
    final startTime = DateTime.now();
    
    try {
      String text = '';
      
      // Extract text based on file type
      switch (file.extension?.toLowerCase()) {
        case 'pdf':
          text = await _extractTextFromPDF(file);
          break;
        case 'doc':
        case 'docx':
          text = await _extractTextFromWord(file);
          break;
        case 'txt':
          text = await _extractTextFromTxt(file);
          break;
        default:
          throw Exception('Unsupported file format: ${file.extension}');
      }

      if (text.isEmpty) {
        return ScanResult(
          success: false,
          error: 'No text found in document',
        );
      }

      // Extract attendee data from text
      final attendees = _extractAttendeeDataFromText(text);
      
      final duration = DateTime.now().difference(startTime);

      // Track document processing analytics
      await _analyticsService.trackPerformance(
        operation: 'document_process_${file.extension}',
        durationMs: duration.inMilliseconds,
        success: true,
      );

      // TODO: Replace with appropriate analytics tracking
      // await _analyticsService.logEvent(
      //   name: 'document_processed',
      //   parameters: {
      //     'attendees_found': attendees.length,
      //     'processing_time_ms': duration.inMilliseconds,
      //     'file_type': file.extension ?? 'unknown',
      //     'file_size_bytes': file.size,
      //   },
      // );

      return ScanResult(
        success: true,
        attendees: attendees,
        processingTime: duration,
      );

    } catch (e) {
      final duration = DateTime.now().difference(startTime);
      
      debugPrint('Document processing error: $e');
      
      await _analyticsService.logError(
        error: 'DocumentProcessError',
        context: 'Document Processing',
        additionalData: {
          'error_message': e.toString(),
          'file_type': file.extension ?? 'unknown',
          'file_size_bytes': file.size,
          'processing_time_ms': duration.inMilliseconds,
        },
      );

      return ScanResult(
        success: false,
        error: 'Document processing failed: $e',
        processingTime: duration,
      );
    }
  }

  /// Extract text from PDF file
  Future<String> _extractTextFromPDF(PlatformFile file) async {
    try {
      // PDF functionality disabled - pdf_text package not available
      throw UnimplementedError('PDF scanning not available - pdf_text package missing');
      
      // final pdfDoc = await PDFDoc.fromPath(file.path!);
      // final pages = await pdfDoc.length;
      // 
      // String fullText = '';
      // for (int i = 1; i <= pages; i++) {
      //   final pageText = await pdfDoc.pageAt(i).text;
      //   fullText += pageText + '\n';
      // }
      // 
      // return fullText;
    } catch (e) {
      throw Exception('Failed to extract text from PDF: $e');
    }
  }

  /// Extract text from Word document
  Future<String> _extractTextFromWord(PlatformFile file) async {
    // Note: For Word documents, you might need additional packages
    // For now, we'll return an error message
    throw Exception('Word document processing not yet implemented. Please convert to PDF or use image scan.');
  }

  /// Extract text from text file
  Future<String> _extractTextFromTxt(PlatformFile file) async {
    try {
      final fileContent = await File(file.path!).readAsString();
      return fileContent;
    } catch (e) {
      throw Exception('Failed to read text file: $e');
    }
  }

  /// Extract attendee data from plain text
  List<ScannedAttendee> _extractAttendeeDataFromText(String text) {
    // Enhanced patterns for better accuracy
    final phonePatterns = [
      RegExp(r'(\+?254[17]\d{8})'), // International format
      RegExp(r'(0[17]\d{8})'), // Local format
      RegExp(r'(254[17]\d{8})'), // Without plus
      RegExp(r'(\+254\s?[17]\d{2}\s?\d{3}\s?\d{3})'), // Spaced format
      RegExp(r'(0[17]\d{2}\s?\d{3}\s?\d{3})'), // Local spaced
    ];
    
    // Enhanced name patterns
    final namePatterns = [
      RegExp(r'^([A-Z][a-z]+(?:\s+[A-Z][a-z]+)+)'), // Standard names
      RegExp(r'Name:\s*([A-Z][a-z]+(?:\s+[A-Z][a-z]+)+)', caseSensitive: false),
      RegExp(r'Student:\s*([A-Z][a-z]+(?:\s+[A-Z][a-z]+)+)', caseSensitive: false),
      RegExp(r'\d+\.\s*([A-Z][a-z]+(?:\s+[A-Z][a-z]+)+)'), // Numbered list
    ];
    
    // Comprehensive Kenya locations
    final kenyanLocations = [
      // Counties
      'Nairobi', 'Mombasa', 'Kisumu', 'Nakuru', 'Eldoret', 'Thika', 'Malindi',
      'Kitale', 'Garissa', 'Kakamega', 'Machakos', 'Meru', 'Nyeri', 'Kericho',
      'Embu', 'Migori', 'Homa Bay', 'Bungoma', 'Vihiga', 'Siaya', 'Kisii',
      'Bomet', 'Kajiado', 'Kiambu', 'Murang\'a', 'Kirinyaga', 'Nyandarua',
      'Laikipia', 'Isiolo', 'Tharaka Nithi', 'Marsabit', 'Samburu',
      'Trans Nzoia', 'Uasin Gishu', 'Elgeyo Marakwet', 'Nandi', 'Baringo',
      'West Pokot', 'Turkana', 'Mandera', 'Wajir', 'Tana River', 'Lamu',
      'Taita Taveta', 'Kwale', 'Kilifi',
    ];

    final lines = text.split('\n').where((line) => line.trim().isNotEmpty).toList();
    
    // Process text with multiple strategies
    List<ScannedAttendee> attendees = [];
    
    // Strategy 1: Line-by-line analysis
    attendees.addAll(_extractFromLines(lines, phonePatterns, namePatterns, kenyanLocations));

    // Strategy 2: Pattern-based extraction for forms
    attendees.addAll(_extractFromPatterns(text, phonePatterns, namePatterns, kenyanLocations));

    // Remove duplicates and merge similar entries
    return _deduplicateAndMerge(attendees);
  }

  /// Process a single image and extract attendee data
  Future<ScanResult> _processImage(XFile imageFile) async {
    final startTime = DateTime.now();
    
    try {
      // Load and preprocess image
      final inputImage = InputImage.fromFilePath(imageFile.path);
      
      // Enhance image quality for better OCR
      final enhancedImage = await _enhanceImageForOCR(imageFile.path);
      final enhancedInputImage = enhancedImage != null 
          ? InputImage.fromFilePath(enhancedImage.path)
          : inputImage;

      // Perform text recognition
      final RecognizedText recognizedText = await _textRecognizer.processImage(enhancedInputImage);
      
      // Extract attendee data from recognized text
      final attendees = _extractAttendeeData(recognizedText);
      
      // Clean up enhanced image
      if (enhancedImage != null) {
        await enhancedImage.delete();
      }

      final duration = DateTime.now().difference(startTime);

      // Track scanning analytics
      await _analyticsService.trackPerformance(
        operation: 'document_scan',
        durationMs: duration.inMilliseconds,
        success: true,
      );

      // TODO: Replace with appropriate analytics tracking
      // await _analyticsService.logEvent(
      //   name: 'document_scanned',
      //   parameters: {
      //     'attendees_found': attendees.length,
      //     'processing_time_ms': duration.inMilliseconds,
      //     'image_source': 'camera_or_gallery',
      //   },
      // );

      return ScanResult(
        success: true,
        attendees: attendees,
        processingTime: duration,
      );

    } catch (e) {
      final duration = DateTime.now().difference(startTime);
      
      debugPrint('Image processing error: $e');
      
      await _analyticsService.logError(
        error: 'DocumentScanError',
        context: 'Image Processing',
        additionalData: {
          'error_message': e.toString(),
          'processing_time_ms': duration.inMilliseconds,
        },
      );

      return ScanResult(
        success: false,
        error: 'Processing failed: $e',
        processingTime: duration,
      );
    }
  }

  /// Enhance image quality for better OCR results
  Future<File?> _enhanceImageForOCR(String imagePath) async {
    try {
      final bytes = await File(imagePath).readAsBytes();
      final image = img.decodeImage(bytes);
      
      if (image == null) return null;

      // Apply image enhancements
      var enhanced = image;
      
      // 1. Increase contrast
      enhanced = img.adjustColor(enhanced, contrast: 1.2);
      
      // 2. Increase brightness slightly
      enhanced = img.adjustColor(enhanced, brightness: 1.1);
      
      // 3. Convert to grayscale for better text recognition
      enhanced = img.grayscale(enhanced);
      
      // 4. Apply sharpening (fixed convolution call)
      final kernel = [
        0, -1, 0,
        -1, 5, -1,
        0, -1, 0
      ];
      enhanced = img.convolution(enhanced, filter: kernel);

      // Save enhanced image
      final enhancedBytes = img.encodeJpg(enhanced, quality: 95);
      final enhancedFile = File('${imagePath}_enhanced.jpg');
      await enhancedFile.writeAsBytes(enhancedBytes);
      
      return enhancedFile;
    } catch (e) {
      debugPrint('Image enhancement error: $e');
      return null;
    }
  }

  /// Extract attendee data from recognized text with enhanced accuracy
  List<ScannedAttendee> _extractAttendeeData(RecognizedText recognizedText) {
    List<ScannedAttendee> attendees = [];
    
    // Enhanced patterns for better accuracy
    final phonePatterns = [
      RegExp(r'(\+?254[17]\d{8})'), // International format
      RegExp(r'(0[17]\d{8})'), // Local format
      RegExp(r'(254[17]\d{8})'), // Without plus
      RegExp(r'(\+254\s?[17]\d{2}\s?\d{3}\s?\d{3})'), // Spaced format
      RegExp(r'(0[17]\d{2}\s?\d{3}\s?\d{3})'), // Local spaced
    ];
    
    // Enhanced name patterns
    final namePatterns = [
      RegExp(r'^([A-Z][a-z]+(?:\s+[A-Z][a-z]+)+)'), // Standard names
      RegExp(r'Name:\s*([A-Z][a-z]+(?:\s+[A-Z][a-z]+)+)', caseSensitive: false),
      RegExp(r'Student:\s*([A-Z][a-z]+(?:\s+[A-Z][a-z]+)+)', caseSensitive: false),
      RegExp(r'\d+\.\s*([A-Z][a-z]+(?:\s+[A-Z][a-z]+)+)'), // Numbered list
    ];
    
    // Comprehensive Kenya locations
    final kenyanLocations = [
      // Counties
      'Nairobi', 'Mombasa', 'Kisumu', 'Nakuru', 'Eldoret', 'Thika', 'Malindi',
      'Kitale', 'Garissa', 'Kakamega', 'Machakos', 'Meru', 'Nyeri', 'Kericho',
      'Embu', 'Migori', 'Homa Bay', 'Bungoma', 'Vihiga', 'Siaya', 'Kisii',
      'Bomet', 'Kajiado', 'Kiambu', 'Murang\'a', 'Kirinyaga', 'Nyandarua',
      'Laikipia', 'Isiolo', 'Tharaka Nithi', 'Marsabit', 'Samburu',
      'Trans Nzoia', 'Uasin Gishu', 'Elgeyo Marakwet', 'Nandi', 'Baringo',
      'West Pokot', 'Turkana', 'Mandera', 'Wajir', 'Tana River', 'Lamu',
      'Taita Taveta', 'Kwale', 'Kilifi',
      // Major towns
      'Mtwapa', 'Diani', 'Watamu', 'Lamu Town', 'Malindi Town', 'Kilifi Town',
      'Mombasa Island', 'Likoni', 'Changamwe', 'Nyali', 'Bamburi',
      'Kisauni', 'Jomvu', 'Port Reitz', 'Tudor', 'Shimanzi',
      // Nairobi areas
      'Westlands', 'Karen', 'Langata', 'Kasarani', 'Embakasi', 'Dagoretti',
      'Kibra', 'Mathare', 'Starehe', 'Kamukunji', 'Makadara', 'Njiru',
    ];

    // Process text with multiple strategies
    final allText = recognizedText.text;
    final blocks = recognizedText.blocks;
    final lines = allText.split('\n').where((line) => line.trim().isNotEmpty).toList();

    // Strategy 1: Line-by-line analysis
    attendees.addAll(_extractFromLines(lines, phonePatterns, namePatterns, kenyanLocations));

    // Strategy 2: Block-based analysis for table structures
    attendees.addAll(_extractFromBlocks(blocks, phonePatterns, namePatterns, kenyanLocations));

    // Strategy 3: Pattern-based extraction for forms
    attendees.addAll(_extractFromPatterns(allText, phonePatterns, namePatterns, kenyanLocations));

    // Remove duplicates and merge similar entries
    return _deduplicateAndMerge(attendees);
  }

  /// Extract from individual lines
  List<ScannedAttendee> _extractFromLines(
    List<String> lines, 
    List<RegExp> phonePatterns, 
    List<RegExp> namePatterns, 
    List<String> locations
  ) {
    List<ScannedAttendee> attendees = [];
    
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      // Find phone numbers in current line
      final phones = <String>[];
      for (final pattern in phonePatterns) {
        phones.addAll(pattern.allMatches(line).map((m) => m.group(0)!));
      }

      if (phones.isNotEmpty) {
        // Look for name in current line or nearby lines
        String? name = _findNameInContext(line, i, lines, namePatterns);
        String? location = _findLocationInContext(line, i, lines, locations);
        
        if (name != null) {
          for (final phone in phones) {
            final normalizedPhone = AttendeeModel.normalizePhoneNumber(phone);
            if (normalizedPhone.isNotEmpty) {
              attendees.add(ScannedAttendee(
                name: name,
                phoneNumber: normalizedPhone,
                location: location ?? 'Unknown',
                confidence: _calculateAdvancedConfidence(name, normalizedPhone, location, line),
                sourceText: line,
                boundingBox: null,
              ));
            }
          }
        }
      }
    }
    
    return attendees;
  }

  /// Extract from text blocks (for table structures)
  List<ScannedAttendee> _extractFromBlocks(
    List<TextBlock> blocks,
    List<RegExp> phonePatterns,
    List<RegExp> namePatterns,
    List<String> locations
  ) {
    List<ScannedAttendee> attendees = [];
    
    for (final block in blocks) {
      final blockText = block.text;
      final blockLines = blockText.split('\n');
      
      // Check if this looks like a table row
      if (_isTableRow(blockText)) {
        final extracted = _extractFromTableRow(blockText, phonePatterns, namePatterns, locations);
        if (extracted != null) {
          attendees.add(extracted.copyWith(boundingBox: block.boundingBox));
        }
      }
    }
    
    return attendees;
  }

  /// Extract using pattern matching for forms
  List<ScannedAttendee> _extractFromPatterns(
    String text,
    List<RegExp> phonePatterns,
    List<RegExp> namePatterns,
    List<String> locations
  ) {
    List<ScannedAttendee> attendees = [];
    
    // Form-style patterns
    final formPatterns = [
      RegExp(r'Name:\s*([A-Z][a-z]+(?:\s+[A-Z][a-z]+)+).*?(?:Phone|Tel|Mobile):\s*([+\d\s]+).*?(?:Location|Address|County):\s*([A-Za-z\s]+)', 
             caseSensitive: false, dotAll: true),
      RegExp(r'([A-Z][a-z]+(?:\s+[A-Z][a-z]+)+).*?([+\d\s]{10,15}).*?([A-Za-z\s]+)', 
             dotAll: true),
    ];
    
    for (final pattern in formPatterns) {
      final matches = pattern.allMatches(text);
      for (final match in matches) {
        if (match.groupCount >= 2) {
          final name = match.group(1)?.trim();
          final phone = match.group(2)?.trim();
          final location = match.groupCount >= 3 ? match.group(3)?.trim() : null;
          
          if (name != null && phone != null) {
            final normalizedPhone = AttendeeModel.normalizePhoneNumber(phone);
            if (normalizedPhone.isNotEmpty) {
              attendees.add(ScannedAttendee(
                name: name,
                phoneNumber: normalizedPhone,
                location: _validateLocation(location, locations) ?? 'Unknown',
                confidence: _calculateAdvancedConfidence(name, normalizedPhone, location, match.group(0)!),
                sourceText: match.group(0)!,
                boundingBox: null,
              ));
            }
          }
        }
      }
    }
    
    return attendees;
  }

  /// Check if text looks like a table row
  bool _isTableRow(String text) {
    // Look for separators that indicate table structure
    final separators = ['|', '\t', '  ', ' - ', ' : '];
    int separatorCount = 0;
    
    for (final sep in separators) {
      separatorCount += sep.allMatches(text).length;
    }
    
    return separatorCount >= 2;
  }

  /// Extract data from a table row
  ScannedAttendee? _extractFromTableRow(
    String row,
    List<RegExp> phonePatterns,
    List<RegExp> namePatterns,
    List<String> locations
  ) {
    // Split by common separators
    final parts = row.split(RegExp(r'[|\t]|  +'));
    
    String? name;
    String? phone;
    String? location;
    
    for (final part in parts) {
      final trimmed = part.trim();
      if (trimmed.isEmpty) continue;
      
      // Check if this part is a phone number
      if (phone == null) {
        for (final pattern in phonePatterns) {
          final match = pattern.firstMatch(trimmed);
          if (match != null) {
            phone = match.group(0);
            break;
          }
        }
      }
      
      // Check if this part is a name
      if (name == null) {
        for (final pattern in namePatterns) {
          final match = pattern.firstMatch(trimmed);
          if (match != null) {
            name = match.group(1) ?? match.group(0);
            break;
          }
        }
      }
      
      // Check if this part is a location
      if (location == null) {
        location = _validateLocation(trimmed, locations);
      }
    }
    
    if (name != null && phone != null) {
      final normalizedPhone = AttendeeModel.normalizePhoneNumber(phone);
      if (normalizedPhone.isNotEmpty) {
        return ScannedAttendee(
          name: name,
          phoneNumber: normalizedPhone,
          location: location ?? 'Unknown',
          confidence: _calculateAdvancedConfidence(name, normalizedPhone, location, row),
          sourceText: row,
          boundingBox: null,
        );
      }
    }
    
    return null;
  }

  /// Find name in context (current line and nearby lines)
  String? _findNameInContext(String currentLine, int lineIndex, List<String> allLines, List<RegExp> namePatterns) {
    // Try current line first
    for (final pattern in namePatterns) {
      final match = pattern.firstMatch(currentLine);
      if (match != null) {
        return match.group(1) ?? match.group(0);
      }
    }
    
    // Look in nearby lines (±2 lines)
    for (int offset = -2; offset <= 2; offset++) {
      final index = lineIndex + offset;
      if (index >= 0 && index < allLines.length && index != lineIndex) {
        for (final pattern in namePatterns) {
          final match = pattern.firstMatch(allLines[index]);
          if (match != null) {
            return match.group(1) ?? match.group(0);
          }
        }
      }
    }
    
    return null;
  }

  /// Find location in context
  String? _findLocationInContext(String currentLine, int lineIndex, List<String> allLines, List<String> locations) {
    // Try current line first
    String? location = _validateLocation(currentLine, locations);
    if (location != null) return location;
    
    // Look in nearby lines
    for (int offset = -1; offset <= 1; offset++) {
      final index = lineIndex + offset;
      if (index >= 0 && index < allLines.length && index != lineIndex) {
        location = _validateLocation(allLines[index], locations);
        if (location != null) return location;
      }
    }
    
    return null;
  }

  /// Validate and extract location from text
  String? _validateLocation(String? text, List<String> locations) {
    if (text == null) return null;
    
    final lowerText = text.toLowerCase();
    
    for (final location in locations) {
      if (lowerText.contains(location.toLowerCase())) {
        return location;
      }
    }
    
    // Look for location indicators
    final locationPattern = RegExp(r'(?:from|location|county|region|address):\s*([A-Za-z\s]+)', caseSensitive: false);
    final match = locationPattern.firstMatch(text);
    if (match != null) {
      return match.group(1)?.trim();
    }
    
    return null;
  }

  /// Advanced confidence calculation
  double _calculateAdvancedConfidence(String name, String phone, String? location, String sourceText) {
    double confidence = 0.0;

    // Name quality (40% weight)
    final nameWords = name.split(' ');
    if (nameWords.length >= 2) confidence += 0.25;
    if (nameWords.length >= 3) confidence += 0.05;
    if (name.length >= 6) confidence += 0.05;
    if (nameWords.every((word) => word.isNotEmpty && word[0].toUpperCase() == word[0])) confidence += 0.05;

    // Phone quality (40% weight)
    if (phone.startsWith('+254') || phone.startsWith('07') || phone.startsWith('01')) confidence += 0.35;
    if (phone.startsWith('+254')) confidence += 0.05;

    // Location quality (15% weight)
    if (location != null && location != 'Unknown') confidence += 0.15;

    // Source text quality (5% weight)
    if (sourceText.contains('|') || sourceText.contains('\t')) confidence += 0.02; // Table format
    if (sourceText.toLowerCase().contains('name') || sourceText.toLowerCase().contains('phone')) confidence += 0.03; // Form format

    return confidence.clamp(0.0, 1.0);
  }

  /// Remove duplicates and merge similar entries
  List<ScannedAttendee> _deduplicateAndMerge(List<ScannedAttendee> attendees) {
    final uniqueAttendees = <String, ScannedAttendee>{};
    
    for (final attendee in attendees) {
      final key = attendee.phoneNumber;
      
      if (!uniqueAttendees.containsKey(key)) {
        uniqueAttendees[key] = attendee;
      } else {
        // Keep the one with higher confidence
        final existing = uniqueAttendees[key]!;
        if (attendee.confidence > existing.confidence) {
          uniqueAttendees[key] = attendee;
        } else if (attendee.confidence == existing.confidence) {
          // Merge information if confidence is equal
          uniqueAttendees[key] = existing.copyWith(
            name: existing.name.length > attendee.name.length ? existing.name : attendee.name,
            location: existing.location != 'Unknown' ? existing.location : attendee.location,
            sourceText: '${existing.sourceText} | ${attendee.sourceText}',
          );
        }
      }
    }

    return uniqueAttendees.values.toList()
      ..sort((a, b) => b.confidence.compareTo(a.confidence));
  }

  /// Extract name from current line or nearby lines
  String? _extractNameFromLine(String currentLine, int lineIndex, List<String> allLines) {
    // Try to extract name from current line first
    String? name = _extractNameFromText(currentLine);
    if (name != null) return name;

    // Look in previous lines (name might be above phone number)
    for (int i = lineIndex - 1; i >= 0 && i >= lineIndex - 3; i--) {
      name = _extractNameFromText(allLines[i]);
      if (name != null) return name;
    }

    // Look in next lines (name might be below phone number)
    for (int i = lineIndex + 1; i < allLines.length && i <= lineIndex + 3; i++) {
      name = _extractNameFromText(allLines[i]);
      if (name != null) return name;
    }

    return null;
  }

  /// Extract name from text using various patterns
  String? _extractNameFromText(String text) {
    // Remove phone numbers and common prefixes
    String cleanText = text
        .replaceAll(RegExp(r'(\+?254|0)[17]\d{8}'), '')
        .replaceAll(RegExp(r'\d+\.?\s*'), '') // Remove numbers and dots
        .replaceAll(RegExp(r'^(Name|Student|Attendee):\s*', caseSensitive: false), '')
        .trim();

    if (cleanText.isEmpty) return null;

    // Pattern for typical names (First Last or First Middle Last)
    final namePattern = RegExp(r'^([A-Z][a-z]+(?:\s+[A-Z][a-z]+)+)');
    final match = namePattern.firstMatch(cleanText);
    
    if (match != null) {
      final name = match.group(1)!.trim();
      // Validate name (should have at least 2 words, each starting with capital)
      final words = name.split(' ');
      if (words.length >= 2 && words.every((w) => w.isNotEmpty && w[0].toUpperCase() == w[0])) {
        return name;
      }
    }

    // Fallback: look for any capitalized words
    final words = cleanText.split(' ').where((w) => 
        w.length > 1 && 
        w[0].toUpperCase() == w[0] && 
        w.substring(1).toLowerCase() == w.substring(1)
    ).toList();

    if (words.length >= 2) {
      return words.take(3).join(' '); // Take up to 3 words for name
    }

    return null;
  }

  /// Extract location from text
  String? _extractLocationFromLine(String line, List<String> regions) {
    final lowerLine = line.toLowerCase();
    
    for (final region in regions) {
      if (lowerLine.contains(region.toLowerCase())) {
        return region;
      }
    }

    // Look for common location indicators
    final locationPattern = RegExp(r'(from|location|county|region):\s*([A-Za-z\s]+)', caseSensitive: false);
    final match = locationPattern.firstMatch(line);
    if (match != null) {
      return match.group(2)?.trim();
    }

    return null;
  }

  /// Calculate confidence score for extracted data
  double _calculateConfidence(String name, String phone, String? location) {
    double confidence = 0.0;

    // Name confidence (0.4 weight)
    if (name.split(' ').length >= 2) confidence += 0.3;
    if (name.length >= 5) confidence += 0.1;

    // Phone confidence (0.4 weight)
    if (phone.startsWith('+254') || phone.startsWith('07') || phone.startsWith('01')) confidence += 0.4;

    // Location confidence (0.2 weight)
    if (location != null && location != 'Unknown') confidence += 0.2;

    return confidence;
  }

  /// Dispose resources
  void dispose() {
    _textRecognizer.close();
  }
}

/// Result of document scanning operation
class ScanResult {
  final bool success;
  final List<ScannedAttendee> attendees;
  final String? error;
  final Duration? processingTime;
  final int? totalImages;

  ScanResult({
    required this.success,
    this.attendees = const [],
    this.error,
    this.processingTime,
    this.totalImages,
  });

  @override
  String toString() {
    return 'ScanResult(success: $success, attendees: ${attendees.length}, error: $error)';
  }
}