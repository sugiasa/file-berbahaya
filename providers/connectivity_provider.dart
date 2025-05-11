import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ConnectivityNotifier extends StateNotifier<AsyncValue<bool>> {
  ConnectivityNotifier() : super(const AsyncLoading()) {
    _init();
  }

  Future<void> _init() async {
    // Check current connectivity status
    final connectivityResult = await Connectivity().checkConnectivity();
    final hasConnection = connectivityResult != ConnectivityResult.none;
    state = AsyncData(hasConnection);
    
    // Listen to connectivity changes
    Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      // Jika ada hasil koneksi yang bukan 'none', maka ada koneksi
      final hasConnection = results.any((result) => result != ConnectivityResult.none);
      state = AsyncData(hasConnection);
    });
  }
  
  Future<bool> checkConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    final hasConnection = connectivityResult != ConnectivityResult.none;
    state = AsyncData(hasConnection);
    return hasConnection;
  }
}

final connectivityStatusProvider = StateNotifierProvider<ConnectivityNotifier, AsyncValue<bool>>((ref) {
  return ConnectivityNotifier();
});

// Simple provider to check if device is offline - convenience wrapper
final isOfflineProvider = Provider<bool>((ref) {
  final connectivityStatus = ref.watch(connectivityStatusProvider);
  return !connectivityStatus.hasValue || !connectivityStatus.value!;
});

// Provider for handling connectivity-related UI feedback
class ConnectivityUINotifier extends StateNotifier<void> {
  ConnectivityUINotifier() : super(null);
  
  void showOfflineSnackBar(BuildContext context, {String? customMessage}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(customMessage ?? 'You are offline. Connect to view content.'),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 3),
      ),
    );
  }
  
  void showConnectionErrorSnackBar(BuildContext context, Object error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error: ${error.toString()}'),
        backgroundColor: Colors.red,
      ),
    );
  }
}

final connectivityNotifierProvider = StateNotifierProvider<ConnectivityUINotifier, void>((ref) {
  return ConnectivityUINotifier();
});