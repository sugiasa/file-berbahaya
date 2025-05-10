import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';

class VideoCacheManager {
  static final VideoCacheManager _instance = VideoCacheManager._internal();
  factory VideoCacheManager() => _instance;
  VideoCacheManager._internal();

  final Map<String, String> _videoCache = {};
  
  // Untuk menyimpan status download video
  final Map<String, double> _downloadProgress = {};
  
  // Event handlers/listeners untuk progress download
  final Map<String, List<Function(double)>> _progressListeners = {};
  
  // Generate hash key dari URL untuk nama file cache
  String _generateCacheKey(String url) {
    var bytes = utf8.encode(url);
    var digest = md5.convert(bytes);
    return digest.toString();
  }

  // Bersihkan cache yang sudah lama (lebih dari usia tertentu)
  Future<void> cleanExpiredCache({Duration maxAge = const Duration(days: 7)}) async {
    try {
      final cacheDir = await getTemporaryDirectory();
      final videoCacheDir = Directory('${cacheDir.path}/video_cache');
      
      if (!await videoCacheDir.exists()) {
        return;
      }
      
      final now = DateTime.now();
      final files = await videoCacheDir.list().toList();
      
      for (FileSystemEntity file in files) {
        if (file is File) {
          final stat = await file.stat();
          final fileAge = now.difference(stat.modified);
          
          if (fileAge > maxAge) {
            await file.delete();
            debugPrint('Deleted expired cache file: ${file.path}');
            
            // Remove from memory cache if exists
            _videoCache.removeWhere((key, value) => value == file.path);
          }
        }
      }
    } catch (e) {
      debugPrint('Error cleaning cache: $e');
    }
  }

  // Get cache size
  Future<int> getCacheSize() async {
    try {
      final cacheDir = await getTemporaryDirectory();
      final videoCacheDir = Directory('${cacheDir.path}/video_cache');
      
      if (!await videoCacheDir.exists()) {
        return 0;
      }
      
      int totalSize = 0;
      final files = await videoCacheDir.list().toList();
      
      for (FileSystemEntity file in files) {
        if (file is File) {
          totalSize += await file.length();
        }
      }
      
      return totalSize;
    } catch (e) {
      debugPrint('Error getting cache size: $e');
      return 0;
    }
  }

  // Clear all cache
  Future<void> clearAllCache() async {
    try {
      final cacheDir = await getTemporaryDirectory();
      final videoCacheDir = Directory('${cacheDir.path}/video_cache');
      
      if (await videoCacheDir.exists()) {
        await videoCacheDir.delete(recursive: true);
      }
      
      _videoCache.clear();
      debugPrint('All video cache cleared');
    } catch (e) {
      debugPrint('Error clearing cache: $e');
    }
  }

  // Register listener untuk progress download
  void addProgressListener(String url, Function(double) listener) {
    final cacheKey = _generateCacheKey(url);
    if (!_progressListeners.containsKey(cacheKey)) {
      _progressListeners[cacheKey] = [];
    }
    
    // Jika sudah ada progress, langsung kirim ke listener
    if (_downloadProgress.containsKey(cacheKey)) {
      listener(_downloadProgress[cacheKey] ?? 0.0);
    }
    
    _progressListeners[cacheKey]?.add(listener);
  }
  
  // Hapus listener
  void removeProgressListener(String url, Function(double) listener) {
    final cacheKey = _generateCacheKey(url);
    _progressListeners[cacheKey]?.remove(listener);
  }
  
  // Update progress dan notifikasi semua listeners
  void _updateProgress(String cacheKey, double progress) {
    _downloadProgress[cacheKey] = progress;
    
    // Notifikasi semua listeners
    if (_progressListeners.containsKey(cacheKey)) {
      for (var listener in _progressListeners[cacheKey]!) {
        listener(progress);
      }
    }
  }
  
  // Cek apakah video sudah ada di cache
  bool isVideoCached(String url) {
    final cacheKey = _generateCacheKey(url);
    return _videoCache.containsKey(cacheKey);
  }

  // Periksa dan download video ke cache jika belum ada
  Future<String> getVideoCachePath(String url) async {
    final cacheKey = _generateCacheKey(url);
    
    // Jika sudah ada di memory cache, gunakan itu
    if (_videoCache.containsKey(cacheKey)) {
      final cachedPath = _videoCache[cacheKey];
      if (cachedPath != null && File(cachedPath).existsSync()) {
        debugPrint('Using memory cached video: $cachedPath');
        
        // Set progress ke 1.0 (completed)
        _updateProgress(cacheKey, 1.0);
        
        return cachedPath;
      }
    }
    
    // Dapatkan directory cache
    final cacheDir = await getTemporaryDirectory();
    final videoFile = File('${cacheDir.path}/video_cache/$cacheKey.mp4');
    
    // Buat directory jika belum ada
    if (!await videoFile.parent.exists()) {
      await videoFile.parent.create(recursive: true);
    }
    
    // Jika file sudah ada di cache disk, gunakan itu
    if (await videoFile.exists()) {
      debugPrint('Using disk cached video: ${videoFile.path}');
      _videoCache[cacheKey] = videoFile.path;
      
      // Set progress ke 1.0 (completed)
      _updateProgress(cacheKey, 1.0);
      
      return videoFile.path;
    }
    
    try {
      // Download file video
      debugPrint('Downloading video to cache: $url');
      final httpClient = HttpClient();
      final request = await httpClient.getUrl(Uri.parse(url));
      final response = await request.close();
      
      if (response.statusCode == 200) {
        // Dapatkan total size
        final totalBytes = response.contentLength;
        
        // Open file for writing
        final sink = videoFile.openWrite();
        int downloadedBytes = 0;
        
        // Reset progress
        _updateProgress(cacheKey, 0.0);
        
        // Dengan progress tracking
        await response.listen((List<int> chunk) {
          // Write to file
          sink.add(chunk);
          
          // Update progress
          downloadedBytes += chunk.length;
          if (totalBytes > 0) {
            final progress = downloadedBytes / totalBytes;
            _updateProgress(cacheKey, progress);
          }
        }).asFuture();
        
        // Close file
        await sink.close();
        
        // Simpan ke cache
        _videoCache[cacheKey] = videoFile.path;
        
        // Final progress update
        _updateProgress(cacheKey, 1.0);
        
        debugPrint('Video cached successfully: ${videoFile.path}');
        return videoFile.path;
      } else {
        debugPrint('Error downloading video: ${response.statusCode}');
        return url; // Fallback to original URL
      }
    } catch (e) {
      debugPrint('Error caching video: $e');
      return url; // Fallback to original URL
    }
  }
}