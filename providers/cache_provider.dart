import 'package:flutter_riverpod/flutter_riverpod.dart';
import './cache_manager.dart';

// Singleton instance provider
final cacheManagerProvider = Provider<CacheManager>((ref) {
  return CacheManager();
});

// Last sync time provider
final lastSyncTimeProvider = FutureProvider<DateTime?>((ref) async {
  final cacheManager = ref.watch(cacheManagerProvider);
  return await cacheManager.getLastSyncTime();
});

// Cached album list provider
final cachedAlbumListProvider = FutureProvider<List<Map<String, dynamic>>?>((ref) async {
  final cacheManager = ref.watch(cacheManagerProvider);
  return await cacheManager.getCachedAlbumList();
});

// Cached media info provider with parameter
final cachedMediaInfoProvider = FutureProvider.family<List<Map<String, dynamic>>?, String>((ref, albumId) async {
  final cacheManager = ref.watch(cacheManagerProvider);
  return await cacheManager.getCachedMediaInfo(albumId);
});

// Check if media is cached provider with parameter
final isMediaCachedProvider = FutureProvider.family<bool, String>((ref, mediaId) async {
  final cacheManager = ref.watch(cacheManagerProvider);
  return await cacheManager.isMediaCached(mediaId);
});

// Get media local path provider with parameter
final mediaLocalPathProvider = FutureProvider.family<String?, String>((ref, mediaId) async {
  final cacheManager = ref.watch(cacheManagerProvider);
  return await cacheManager.getCachedMediaPath(mediaId);
});

// Media download provider - uses StateNotifier
class MediaDownloadNotifier extends StateNotifier<AsyncValue<String?>> {
  final CacheManager cacheManager;
  final String mediaId;
  final String url;
  final String mediaType;

  MediaDownloadNotifier({
    required this.cacheManager, 
    required this.mediaId, 
    required this.url, 
    required this.mediaType
  }) : super(const AsyncData(null));

  Future<String?> downloadMedia() async {
    state = const AsyncLoading();
    
    try {
      final result = await cacheManager.downloadAndCacheMedia(mediaId, url, mediaType);
      
      if (result == null) {
        state = AsyncError("Failed to download media", StackTrace.current);
        return null;
      }
      
      state = AsyncData(result);
      return result;
    } catch (e, stackTrace) {
      state = AsyncError(e, stackTrace);
      return null;
    }
  }
}

final mediaDownloaderProvider = StateNotifierProvider.family<MediaDownloadNotifier, AsyncValue<String?>, ({String mediaId, String url, String mediaType})>((ref, params) {
  final cacheManager = ref.watch(cacheManagerProvider);
  return MediaDownloadNotifier(
    cacheManager: cacheManager,
    mediaId: params.mediaId,
    url: params.url,
    mediaType: params.mediaType,
  );
});