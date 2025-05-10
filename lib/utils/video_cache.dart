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

  // Periksa dan download video ke cache jika belum ada
  Future<String> getVideoCachePath(String url) async {
    final cacheKey = _generateCacheKey(url);
    
    // Jika sudah ada di memory cache, gunakan itu
    if (_videoCache.containsKey(cacheKey)) {
      final cachedPath = _videoCache[cacheKey];
      if (cachedPath != null && File(cachedPath).existsSync()) {
        debugPrint('Using memory cached video: $cachedPath');
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
      return videoFile.path;
    }
    
    try {
      // Download file video
      debugPrint('Downloading video to cache: $url');
      final httpClient = HttpClient();
      final request = await httpClient.getUrl(Uri.parse(url));
      final response = await request.close();
      
      if (response.statusCode == 200) {
        final bytes = await consolidateHttpClientResponseBytes(response);
        await videoFile.writeAsBytes(bytes);
        _videoCache[cacheKey] = videoFile.path;
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