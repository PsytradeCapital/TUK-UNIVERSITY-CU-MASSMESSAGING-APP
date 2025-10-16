import 'package:flutter/material.dart';
import '../services/security_service.dart';

class PinSetupScreen extends StatefulWidget {
  final bool isChangingPin;
  
  const PinSetupScreen({
    Key? key,
    this.isChangingPin = false,
  }) : super(key: key);

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  String _currentPin = '';
  String _newPin = '';
  String _confirmPin = '';
  bool _isLoading = false;
  String _errorMessage = '';
  
  PinSetupStep _currentStep = PinSetupStep.currentPin;

  @override
  void initState() {
    super.initState();
    if (!widget.isChangingPin) {
      _currentStep = PinSetupStep.newPin;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isChangingPin ? 'Change PIN' : 'Set Up PIN'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.security,
              size: 80,
              color: Colors.blue[700],
            ),
            const SizedBox(height: 32),
            Text(
              _getStepTitle(),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              _getStepDescription(),
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            _buildPinDisplay(),
            const SizedBox(height: 32),
            _buildNumericKeypad(),
            if (_errorMessage.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                _errorMessage,
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (_isLoading) ...[
              const SizedBox(height: 16),
              const CircularProgressIndicator(),
            ],
          ],
        ),
      ),
    );
  }

  String _getStepTitle() {
    switch (_currentStep) {
      case PinSetupStep.currentPin:
        return 'Enter Current PIN';
      case PinSetupStep.newPin:
        return widget.isChangingPin ? 'Enter New PIN' : 'Create Your PIN';
      case PinSetupStep.confirmPin:
        return 'Confirm Your PIN';
    }
  }

  String _getStepDescription() {
    switch (_currentStep) {
      case PinSetupStep.currentPin:
        return 'Please enter your current PIN to continue';
      case PinSetupStep.newPin:
        return 'Create a 4-digit PIN to secure your app';
      case PinSetupStep.confirmPin:
        return 'Please enter your PIN again to confirm';
    }
  }

  Widget _buildPinDisplay() {
    String currentInput = '';
    switch (_currentStep) {
      case PinSetupStep.currentPin:
        currentInput = _currentPin;
        break;
      case PinSetupStep.newPin:
        currentInput = _newPin;
        break;
      case PinSetupStep.confirmPin:
        currentInput = _confirmPin;
        break;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (index) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 8),
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: index < currentInput.length 
                ? Colors.blue[700] 
                : Colors.grey[300],
          ),
        );
      }),
    );
  }

  Widget _buildNumericKeypad() {
    return Column(
      children: [
        _buildKeypadRow(['1', '2', '3']),
        const SizedBox(height: 16),
        _buildKeypadRow(['4', '5', '6']),
        const SizedBox(height: 16),
        _buildKeypadRow(['7', '8', '9']),
        const SizedBox(height: 16),
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
              color: Colors.grey[100],
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Center(
              child: key == 'delete'
                  ? const Icon(Icons.backspace, size: 24)
                  : Text(
                      key,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
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
    String currentInput = _getCurrentInput();
    if (currentInput.length < 4) {
      setState(() {
        _setCurrentInput(currentInput + digit);
      });
      
      if (currentInput.length + 1 == 4) {
        _handlePinComplete();
      }
    }
  }

  void _deleteDigit() {
    String currentInput = _getCurrentInput();
    if (currentInput.isNotEmpty) {
      setState(() {
        _setCurrentInput(currentInput.substring(0, currentInput.length - 1));
      });
    }
  }

  String _getCurrentInput() {
    switch (_currentStep) {
      case PinSetupStep.currentPin:
        return _currentPin;
      case PinSetupStep.newPin:
        return _newPin;
      case PinSetupStep.confirmPin:
        return _confirmPin;
    }
  }

  void _setCurrentInput(String value) {
    switch (_currentStep) {
      case PinSetupStep.currentPin:
        _currentPin = value;
        break;
      case PinSetupStep.newPin:
        _newPin = value;
        break;
      case PinSetupStep.confirmPin:
        _confirmPin = value;
        break;
    }
  }

  void _handlePinComplete() async {
    switch (_currentStep) {
      case PinSetupStep.currentPin:
        await _validateCurrentPin();
        break;
      case PinSetupStep.newPin:
        _moveToConfirmStep();
        break;
      case PinSetupStep.confirmPin:
        await _confirmAndSavePin();
        break;
    }
  }

  Future<void> _validateCurrentPin() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final isValid = await SecurityService.validatePIN(_currentPin);
      if (isValid) {
        setState(() {
          _currentStep = PinSetupStep.newPin;
          _currentPin = '';
        });
      } else {
        setState(() {
          _errorMessage = 'Invalid PIN. Please try again.';
          _currentPin = '';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error validating PIN. Please try again.';
        _currentPin = '';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _moveToConfirmStep() {
    setState(() {
      _currentStep = PinSetupStep.confirmPin;
    });
  }

  Future<void> _confirmAndSavePin() async {
    if (_newPin != _confirmPin) {
      setState(() {
        _errorMessage = 'PINs do not match. Please try again.';
        _confirmPin = '';
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      if (widget.isChangingPin) {
        await SecurityService.changePIN(_currentPin, _newPin);
      } else {
        await SecurityService.setPIN(_newPin);
      }
      
      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.isChangingPin 
                  ? 'PIN changed successfully!' 
                  : 'PIN set up successfully!'
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error saving PIN. Please try again.';
        _confirmPin = '';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}

enum PinSetupStep {
  currentPin,
  newPin,
  confirmPin,
}