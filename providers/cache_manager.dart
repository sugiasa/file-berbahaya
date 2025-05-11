import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class CacheManager {
  static final CacheManager _instance = CacheManager._internal();
  
  factory CacheManager() {
    return _instance;
  }
  
  CacheManager._internal();
  
  // Constants for SharedPreferences keys
  static const String _keyAlbumCache = 'album_cache';
  static const String _keyMediaCache = 'media_cache';
  static const String _keyLastSync = 'last_sync';
  
  // Initialize the cache directory
  Future<Directory> _getCacheDirectory() async {
    final directory = await getApplicationSupportDirectory();
    final cacheDir = Directory('${directory.path}/media_cache');
    
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    
    return cacheDir;
  }
  
  // Generate a secure random filename
  String _generateSecureFilename(String mediaId, String extension) {
    final random = Random.secure();
    final values = List<int>.generate(32, (i) => random.nextInt(256));
    final hash = sha256.convert(values).toString();
    
    // Use mediaId in the hash calculation to ensure the same file always gets the same name
    final uniqueHash = sha256.convert(utf8.encode(hash + mediaId)).toString();
    return '$uniqueHash.$extension';
  }
  
  // Cache album data
  Future<void> cacheAlbumList(List<Map<String, dynamic>> albums) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final albumsJson = jsonEncode(albums);
      await prefs.setString(_keyAlbumCache, albumsJson);
      await prefs.setInt(_keyLastSync, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('Error caching albums: $e');
    }
  }
  
  // Get cached album list
  Future<List<Map<String, dynamic>>?> getCachedAlbumList() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final albumsJson = prefs.getString(_keyAlbumCache);
      
      if (albumsJson != null) {
        final decoded = jsonDecode(albumsJson) as List;
        return decoded.cast<Map<String, dynamic>>();
      }
      
      return null;
    } catch (e) {
      debugPrint('Error getting cached albums: $e');
      return null;
    }
  }
  
  // Get last sync time
  Future<DateTime?> getLastSyncTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSync = prefs.getInt(_keyLastSync);
      
      if (lastSync != null) {
        return DateTime.fromMillisecondsSinceEpoch(lastSync);
      }
      
      return null;
    } catch (e) {
      debugPrint('Error getting last sync time: $e');
      return null;
    }
  }
  
  // Cache media information
  Future<void> cacheMediaInfo(String albumId, List<Map<String, dynamic>> mediaList) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final mediaJson = jsonEncode(mediaList);
      
      // Create key specific to this album's media
      final key = '${_keyMediaCache}_$albumId';
      await prefs.setString(key, mediaJson);
    } catch (e) {
      debugPrint('Error caching media info: $e');
    }
  }
  
  // Get cached media information
  Future<List<Map<String, dynamic>>?> getCachedMediaInfo(String albumId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '${_keyMediaCache}_$albumId';
      final mediaJson = prefs.getString(key);
      
      if (mediaJson != null) {
        final decoded = jsonDecode(mediaJson) as List;
        return decoded.cast<Map<String, dynamic>>();
      }
      
      return null;
    } catch (e) {
      debugPrint('Error getting cached media info: $e');
      return null;
    }
  }
  
  // Download and cache media file
  Future<String?> downloadAndCacheMedia(String mediaId, String url, String mediaType) async {
    try {
      final cacheDir = await _getCacheDirectory();
      final extension = _getExtensionFromMediaType(mediaType);
      final filename = _generateSecureFilename(mediaId, extension);
      final file = File('${cacheDir.path}/$filename');
      
      // Check if file already exists
      if (await file.exists()) {
        return file.path;
      }
      
      // Download the file
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        await file.writeAsBytes(response.bodyBytes);
        
        // Update media cache info
        await _updateMediaCacheInfo(mediaId, filename);
        
        return file.path;
      } else {
        throw Exception('Failed to download file: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error downloading media: $e');
      return null;
    }
  }
  
  // Get file path for cached media
  Future<String?> getCachedMediaPath(String mediaId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final mediaCache = prefs.getString(_keyMediaCache);
      
      if (mediaCache != null) {
        final Map<String, dynamic> cacheInfo = jsonDecode(mediaCache);
        
        if (cacheInfo.containsKey(mediaId)) {
          final filename = cacheInfo[mediaId];
          final cacheDir = await _getCacheDirectory();
          final file = File('${cacheDir.path}/$filename');
          
          if (await file.exists()) {
            return file.path;
          }
        }
      }
      
      return null;
    } catch (e) {
      debugPrint('Error getting cached media path: $e');
      return null;
    }
  }
  
  // Check if media is cached
  Future<bool> isMediaCached(String mediaId) async {
    final path = await getCachedMediaPath(mediaId);
    return path != null;
  }
  
  // Update the media cache info when a new file is cached
  Future<void> _updateMediaCacheInfo(String mediaId, String filename) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final mediaCache = prefs.getString(_keyMediaCache) ?? '{}';
      
      final Map<String, dynamic> cacheInfo = jsonDecode(mediaCache);
      cacheInfo[mediaId] = filename;
      
      await prefs.setString(_keyMediaCache, jsonEncode(cacheInfo));
    } catch (e) {
      debugPrint('Error updating media cache info: $e');
    }
  }
  
  // Clear all cached files and information
  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyAlbumCache);
      await prefs.remove(_keyMediaCache);
      await prefs.remove(_keyLastSync);
      
      // Delete all cached files
      final cacheDir = await _getCacheDirectory();
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
      }
    } catch (e) {
      debugPrint('Error clearing cache: $e');
    }
  }
  
  // Get file extension from media type
  String _getExtensionFromMediaType(String mediaType) {
    switch (mediaType.toLowerCase()) {
      case 'video':
        return 'mp4';
      case 'image':
        return 'jpg';
      default:
        return 'bin';
    }
  }
  
  // Get media info from local cache
  Future<Map<String, String>> getAllCachedMediaPaths() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final mediaCache = prefs.getString(_keyMediaCache) ?? '{}';
      
      final Map<String, dynamic> cacheInfo = jsonDecode(mediaCache);
      final Map<String, String> result = {};
      
      final cacheDir = await _getCacheDirectory();
      
      for (final entry in cacheInfo.entries) {
        final file = File('${cacheDir.path}/${entry.value}');
        if (await file.exists()) {
          result[entry.key] = file.path;
        }
      }
      
      return result;
    } catch (e) {
      debugPrint('Error getting all cached media paths: $e');
      return {};
    }
  }
}