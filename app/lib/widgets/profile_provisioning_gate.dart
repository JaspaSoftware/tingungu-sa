import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class ProfileProvisioningGate extends StatefulWidget {
  const ProfileProvisioningGate({
    super.key,
    required this.provision,
    required this.child,
  });

  final Future<void> Function() provision;
  final Widget child;

  @override
  State<ProfileProvisioningGate> createState() =>
      _ProfileProvisioningGateState();
}

class _ProfileProvisioningGateState extends State<ProfileProvisioningGate> {
  late Future<void> _provisioning;

  @override
  void initState() {
    super.initState();
    _provisioning = _runProvisioning();
  }

  Future<void> _runProvisioning() async {
    try {
      await widget.provision();
    } catch (_) {
      if (kDebugMode) debugPrint('Account profile provisioning failed.');
      rethrow;
    }
  }

  void _retry() {
    final retry = _runProvisioning();
    setState(() {
      _provisioning = retry;
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _provisioning,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Unable to complete account setup',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      "Your sign-in succeeded, but we couldn't finish setting up your profile. Please try again.",
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _retry,
                      child: const Text('Retry account setup'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        return widget.child;
      },
    );
  }
}
