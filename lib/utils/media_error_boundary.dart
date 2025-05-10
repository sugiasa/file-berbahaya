import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class MediaErrorBoundary extends StatefulWidget {
  final Widget child;

  const MediaErrorBoundary({
    super.key,
    required this.child,
  });

  @override
  State<MediaErrorBoundary> createState() => _MediaErrorBoundaryState();
}

class _MediaErrorBoundaryState extends State<MediaErrorBoundary> {
  bool _hasError = false;
  dynamic _error;
  late FlutterExceptionHandler? _defaultOnError;

  @override
  void initState() {
    super.initState();

    // Simpan handler default
    _defaultOnError = FlutterError.onError;

    // Override handler error
    FlutterError.onError = (FlutterErrorDetails details) {
      debugPrint('Error dalam MediaErrorBoundary: ${details.exception}');
      if (mounted) {
        setState(() {
          _hasError = true;
          _error = details.exception;
        });
      }
    };
  }

  @override
  void dispose() {
    // Balikin ke handler default biar nggak ngaruh ke luar widget ini
    FlutterError.onError = _defaultOnError;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 48,
              ),
              const SizedBox(height: 16),
              const Text(
                'Terjadi kesalahan saat memuat media',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                _error?.toString() ?? 'Unknown error',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _hasError = false;
                    _error = null;
                  });
                },
                child: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      );
    }

    return widget.child;
  }
}
