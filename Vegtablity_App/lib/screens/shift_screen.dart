import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/shift_provider.dart';
import '../core/localization/app_localizations.dart';
import 'home_screen.dart';

class ShiftScreen extends StatefulWidget {
  const ShiftScreen({super.key});

  @override
  State<ShiftScreen> createState() => _ShiftScreenState();
}

class _ShiftScreenState extends State<ShiftScreen> {
  final _cashController = TextEditingController();
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkShiftStatus();
    });
  }

  void _checkShiftStatus() async {
    final shiftProvider = Provider.of<ShiftProvider>(context, listen: false);
    final isAlreadyOpen = await shiftProvider.checkActiveShiftStatus();

    if (mounted) {
      if (isAlreadyOpen) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      } else {
        setState(() {
          _isChecking = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _cashController.dispose();
    super.dispose();
  }

  void _openShift() async {
    final cashText = _cashController.text.trim();
    final double? startingCash = double.tryParse(cashText);

    if (startingCash == null || startingCash < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('shift_open_error_empty'), textAlign: TextAlign.right),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final shiftProvider = Provider.of<ShiftProvider>(context, listen: false);
    final success = await shiftProvider.openShift(startingCash);

    if (mounted) {
      if (success) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(shiftProvider.errorMessage ?? context.tr('shift_open_failed_fallback'), textAlign: TextAlign.right),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final shiftProvider = Provider.of<ShiftProvider>(context);
    final isLoading = shiftProvider.isLoading;

    if (_isChecking) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [Colors.grey[900]!, Colors.black],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(
                  color: Colors.green,
                  strokeWidth: 3,
                ),
                const SizedBox(height: 24),
                Text(
                  context.tr('shift_checking_status'),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontFamily: 'Outfit',
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  context.tr('shift_wait_data'),
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('shift_new_title')), centerTitle: true),
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            width: 400,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(context.tr('shift_confirm_cash'), style: const TextStyle(fontSize: 20)),
                const SizedBox(height: 32),
                TextField(
                  controller: _cashController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.right,
                  decoration: InputDecoration(
                    labelText: context.tr('shift_cash_label'), 
                    border: const OutlineInputBorder(),
                    prefixText: 'Kwd ',
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _openShift,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                    child: isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(context.tr('shift_open_button'), style: const TextStyle(fontSize: 18)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
