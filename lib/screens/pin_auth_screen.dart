import 'package:flutter/material.dart';
import '../services/security_service.dart';

class PinAuthScreen extends StatefulWidget {
  final VoidCallback onAuthenticated;
  
  const PinAuthScreen({
    Key? key,
    required this.onAuthenticated,
  }) : super(key: key);

  @override
  State<PinAuthScreen> createState() => _PinAuthScreenState();
}

class _PinAuthScreenState extends State<PinAuthScreen> {
  String _pin = '';
  bool _isLoading = false;
  String _errorMessage = '';
  int _failedAttempts = 0;
  bool _canUseBiometrics = false;

  @override
  void initState() {
    super.initState();
    _checkBiometricAvailability();
  }

  Future<void> _checkBiometricAvailability() async {
    final isAvailable = await SecurityService.isBiometricAvailable();
    setState(() {
      _canUseBiometrics = isAvailable;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue[700],
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.lock,
                size: 80,
                color: Colors.white,
              ),
              const SizedBox(height: 32),
              const Text(
                'Enter Your PIN',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'Please enter your PIN to access the app',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              _buildPinDisplay(),
              const SizedBox(height: 48),
              _buildNumericKeypad(),
              if (_errorMessage.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  _errorMessage,
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              if (_isLoading) ...[
                const SizedBox(height: 16),
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ],
              if (_canUseBiometrics) ...[
                const SizedBox(height: 32),
                TextButton.icon(
                  onPressed: _authenticateWithBiometrics,
                  icon: const Icon(
                    Icons.fingerprint,
                    color: Colors.white,
                    size: 32,
                  ),
                  label: const Text(
                    'Use Biometric Authentication',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPinDisplay() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (index) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: index < _pin.length 
                ? Colors.white 
                : Colors.white30,
          ),
        );
      }),
    );
  }

  Widget _buildNumericKeypad() {
    return Column(
      children: [
        _buildKeypadRow(['1', '2', '3']),
        const SizedBox(height: 20),
        _buildKeypadRow(['4', '5', '6']),
        const SizedBox(height: 20),
        _buildKeypadRow(['7', '8', '9']),
        const SizedBox(height: 20),
        _buildKeypadRow(['', '0', 'delete']),
      ],
    );
  }

  Widget _buildKeypadRow(List<String> keys) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: keys.map((key) {
        if (key.isEmpty) {
          return const SizedBox(width: 80, height: 80);
        }
        
        return GestureDetector(
          onTap: () => _onKeypadTap(key),
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.1),
              border: Border.all(color: Colors.white30),
            ),
            child: Center(
              child: key == 'delete'
                  ? const Icon(
                      Icons.backspace,
                      size: 24,
                      color: Colors.white,
                    )
                  : Text(
                      key,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        );
      }).toList(),
    );
  }

  void _onKeypadTap(String key) {
    if (_isLoading) return;

    setState(() {
      _errorMessage = '';
    });

    if (key == 'delete') {
      _deleteDigit();
    } else {
      _addDigit(key);
    }
  }

  void _addDigit(String digit) {
    if (_pin.length < 4) {
      setState(() {
        _pin += digit;
      });
      
      if (_pin.length == 4) {
        _validatePin();
      }
    }
  }

  void _deleteDigit() {
    if (_pin.isNotEmpty) {
      setState(() {
        _pin = _pin.substring(0, _pin.length - 1);
      });
    }
  }

  Future<void> _validatePin() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final isValid = await SecurityService.validatePIN(_pin);
      if (isValid) {
        await SecurityService.updateLastActiveTime();
        widget.onAuthenticated();
      } else {
        setState(() {
          _failedAttempts++;
          _errorMessage = 'Invalid PIN. Please try again.';
          _pin = '';
          
          if (_failedAttempts >= 3) {
            _errorMessage = 'Too many failed attempts. Please try again later.';
          }
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Authentication error. Please try again.';
        _pin = '';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _authenticateWithBiometrics() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final isAuthenticated = await SecurityService.authenticateWithBiometrics();
      if (isAuthenticated) {
        await SecurityService.updateLastActiveTime();
        widget.onAuthenticated();
      } else {
        setState(() {
          _errorMessage = 'Biometric authentication failed.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Biometric authentication error.';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}