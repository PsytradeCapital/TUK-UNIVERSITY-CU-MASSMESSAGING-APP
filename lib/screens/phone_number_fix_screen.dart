import 'package:flutter/material.dart';
import '../utils/phone_number_fixer.dart';

class PhoneNumberFixScreen extends StatefulWidget {
  const PhoneNumberFixScreen({Key? key}) : super(key: key);

  @override
  State<PhoneNumberFixScreen> createState() => _PhoneNumberFixScreenState();
}

class _PhoneNumberFixScreenState extends State<PhoneNumberFixScreen> {
  final PhoneNumberFixer _fixer = PhoneNumberFixer();
  bool _isFixing = false;
  Map<String, dynamic>? _results;

  Future<void> _runFix() async {
    setState(() {
      _isFixing = true;
      _results = null;
    });

    try {
      final results = await _fixer.fixAllPhoneNumbers();
      setState(() {
        _results = results;
      });
    } catch (e) {
      setState(() {
        _results = {
          'success': false,
          'error': e.toString(),
        };
      });
    } finally {
      setState(() {
        _isFixing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fix Phone Numbers'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.build, color: Colors.blue[700]),
                        const SizedBox(width: 8),
                        const Text(
                          'Phone Number Fixer',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'This tool will scan all attendees in your database and fix phone numbers that are in incorrect formats.',
                      style: TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'What it does:',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '• Converts all phone numbers to +254 format\n'
                      '• Fixes missing + signs\n'
                      '• Fixes missing leading zeros\n'
                      '• Removes invalid characters\n'
                      '• Reports unfixable numbers',
                      style: TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            if (_isFixing)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Fixing phone numbers...'),
                      SizedBox(height: 8),
                      Text(
                        'This may take a moment',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
            
            if (_results != null && !_isFixing)
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _results!['success'] == true
                                    ? Icons.check_circle
                                    : Icons.error,
                                color: _results!['success'] == true
                                    ? Colors.green
                                    : Colors.red,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _results!['success'] == true
                                    ? 'Fix Complete'
                                    : 'Fix Failed',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          
                          if (_results!['success'] == true) ...[
                            _buildResultRow(
                              'Total Attendees',
                              '${_results!['total']}',
                              Colors.blue,
                            ),
                            _buildResultRow(
                              'Already Valid',
                              '${_results!['alreadyValid']}',
                              Colors.green,
                            ),
                            _buildResultRow(
                              'Fixed',
                              '${_results!['fixed']}',
                              Colors.orange,
                            ),
                            _buildResultRow(
                              'Unfixable',
                              '${_results!['unfixable']}',
                              Colors.red,
                            ),
                            
                            if (_results!['unfixable'] > 0) ...[
                              const SizedBox(height: 16),
                              const Divider(),
                              const SizedBox(height: 8),
                              const Text(
                                'Unfixable Numbers:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ...(_results!['unfixableNumbers'] as List<String>)
                                  .map((number) => Padding(
                                        padding: const EdgeInsets.only(bottom: 4.0),
                                        child: Text(
                                          '• $number',
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ))
                                  .toList(),
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.orange[50],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.orange[200]!),
                                ),
                                child: const Text(
                                  'These attendees have phone numbers that could not be automatically fixed. '
                                  'Please update them manually in the Members tab.',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                            
                            if (_results!['fixed'] > 0) ...[
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.green[50],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.green[200]!),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.check_circle, 
                                            color: Colors.green[700], size: 20),
                                        const SizedBox(width: 8),
                                        const Text(
                                          'Success!',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      '${_results!['fixed']} phone numbers have been fixed. '
                                      'You can now send messages to these attendees.',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ] else ...[
                            Text(
                              'Error: ${_results!['error']}',
                              style: const TextStyle(color: Colors.red),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            
            const SizedBox(height: 16),
            
            ElevatedButton.icon(
              onPressed: _isFixing ? null : _runFix,
              icon: const Icon(Icons.build),
              label: Text(_results == null ? 'Run Fix' : 'Run Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[700],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            
            if (_results != null && _results!['success'] == true)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.check),
                  label: const Text('Done'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.green,
                    side: const BorderSide(color: Colors.green),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
