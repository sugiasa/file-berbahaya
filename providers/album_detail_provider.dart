import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/album_model.dart';
import '../models/media_model.dart';
import 'album_provider.dart';
import 'cache_provider.dart';
import 'connectivity_provider.dart';

class AlbumDetailNotifier extends StateNotifier<AsyncValue<Album?>> {
  final Ref ref;
  final String albumId;

  AlbumDetailNotifier(this.ref, this.albumId) : super(const AsyncLoading()) {
    loadAlbumDetail();
  }

  Future<void> loadAlbumDetail() async {
    state = const AsyncLoading();

    try {
      // First try to get album from cache
      final cachedMediaList = await ref.read(cachedMediaInfoProvider(albumId).future);
      
      // Check connectivity status
      final connectivityStatus = ref.read(connectivityStatusProvider);
      final isOnline = connectivityStatus.valueOrNull ?? false;

      if (!isOnline) {
        // If offline, try to use cached data
        if (cachedMediaList != null && cachedMediaList.isNotEmpty) {
          // Create a basic album with cached media
          final cacheManager = ref.read(cacheManagerProvider);
          
          // Try to get album info from cached album list
          final cachedAlbums = await cacheManager.getCachedAlbumList();
          final cachedAlbum = cachedAlbums?.firstWhere(
            (album) => album['albumId'] == albumId,
            orElse: () => {'title': 'Cached Album', 'description': 'Offline content'},
          );
          
          // Convert cached media to Media objects
          final List<Media> mediaItems = await Future.wait(
            cachedMediaList.map((media) async {
              final mediaId = media['mediaId'];
              final bool isDownloaded = await cacheManager.isMediaCached(mediaId);
              
              return Media.fromJson({
                ...media,
                'isDownloaded': isDownloaded,
                'isDownloading': false,
              }, mediaId);
            })
          );
          
          final album = Album.fromJson(cachedAlbum!, albumId).copyWith(media: mediaItems);
          state = AsyncData(album);
          return;
        }
        
        state = const AsyncData(null);
        return;
      }
      
      // If online, fetch from Firestore
      await _fetchAlbumDetail();
    } catch (e, stackTrace) {
      state = AsyncError(e, stackTrace);
    }
  }
  
  Future<void> _fetchAlbumDetail() async {
    try {
      final firestore = ref.read(firestoreProvider);
      final cacheManager = ref.read(cacheManagerProvider);
      
      // Fetch album data
      final docSnapshot = await firestore.collection('albums').doc(albumId).get();
      
      if (!docSnapshot.exists) {
        throw Exception('Album not found');
      }
      
      final albumData = docSnapshot.data() as Map<String, dynamic>;
      
      // Check if album is locked
      if (albumData['isLocked'] == true) {
        throw Exception('Album is locked');
      }
      
      // Create Album object
      Album album = Album.fromJson(albumData, albumId);
      
      // Fetch all media in the album
      final mediaSnapshot = await firestore
          .collection('albums')
          .doc(albumId)
          .collection('media')
          .get();
      
      // Process media items
      final List<Media> mediaItems = [];
      
      for (final doc in mediaSnapshot.docs) {
        final mediaId = doc.id;
        final mediaData = doc.data();
        
        // Check if media is cached
        final bool isDownloaded = await cacheManager.isMediaCached(mediaId);
        
        final media = Media.fromJson({
          ...mediaData,
          'mediaId': mediaId,
          'isDownloaded': isDownloaded,
          'isDownloading': false,
        }, mediaId);
        
        mediaItems.add(media);
      }
      
      // Add media to album
      album = album.copyWith(media: mediaItems);
      
      // Cache the media info for offline access
      await cacheManager.cacheMediaInfo(
        albumId,
        mediaItems.map((media) => media.toJson()).toList(),
      );
      
      state = AsyncData(album);
    } catch (e, stackTrace) {
      debugPrint('Error fetching album details: $e');
      
      // If fetching fails, try to use cached data
      final cachedMediaList = await ref.read(cachedMediaInfoProvider(albumId).future);
      
      if (cachedMediaList != null && cachedMediaList.isNotEmpty) {
        // Create a basic album with cached media
        final cacheManager = ref.read(cacheManagerProvider);
        
        // Convert cached media to Media objects
        final List<Media> mediaItems = await Future.wait(
          cachedMediaList.map((media) async {
            final mediaId = media['mediaId'];
            final bool isDownloaded = await cacheManager.isMediaCached(mediaId);
            
            return Media.fromJson({
              ...media,
              'isDownloaded': isDownloaded,
              'isDownloading': false,
            }, mediaId);
          })
        );
        
        final album = Album(
          albumId: albumId,
          title: 'Cached Album',
          description: 'Offline content',
          createdAt: DateTime.now(),
          media: mediaItems,
        );
        
        state = AsyncData(album);
      } else {
        state = AsyncError(e, stackTrace);
      }
    }
  }
  
  Future<void> refreshAlbum() async {
    // Check connectivity
    final connectivityStatus = ref.read(connectivityStatusProvider);
    final isOnline = connectivityStatus.valueOrNull ?? false;
    
    if (isOnline) {
      await _fetchAlbumDetail();
    }
  }
  
  Future<void> downloadMedia(Media media) async {
    // Check connectivity
    final connectivityStatus = ref.read(connectivityStatusProvider);
    final isOnline = connectivityStatus.valueOrNull ?? false;
    
    if (!isOnline) {
      return; // Can't download while offline
    }
    
    // Update the media state to downloading
    final Album? currentAlbum = state.valueOrNull;
    if (currentAlbum == null) return;
    
    // Find the media index
    final mediaIndex = currentAlbum.media.indexWhere((m) => m.mediaId == media.mediaId);
    if (mediaIndex == -1) return;
    
    // Update the media to downloading state
    final updatedMedia = List<Media>.from(currentAlbum.media);
    updatedMedia[mediaIndex] = media.copyWith(isDownloading: true);
    
    // Update the album state
    state = AsyncData(currentAlbum.copyWith(media: updatedMedia));
    
    try {
      // Start the download
      final cacheManager = ref.read(cacheManagerProvider);
      final filePath = await cacheManager.downloadAndCacheMedia(
        media.mediaId,
        media.mediaUrl,
        media.mediaType,
      );
      
      if (filePath == null) {
        throw Exception('Failed to download media');
      }
      
      // Update the media to downloaded state
      final latestAlbum = state.valueOrNull;
      if (latestAlbum == null) return;
      
      final latestMediaIndex = latestAlbum.media.indexWhere((m) => m.mediaId == media.mediaId);
      if (latestMediaIndex == -1) return;
      
      final latestUpdatedMedia = List<Media>.from(latestAlbum.media);
      latestUpdatedMedia[latestMediaIndex] = media.copyWith(
        isDownloaded: true,
        isDownloading: false,
        localPath: filePath,
      );
      
      // Update the album state
      state = AsyncData(latestAlbum.copyWith(media: latestUpdatedMedia));
      
      // Update cached media info
      await cacheManager.cacheMediaInfo(
        albumId,
        latestUpdatedMedia.map((m) => m.toJson()).toList(),
      );
    } catch (e) {
      debugPrint('Error downloading media: $e');
      
      // Update the media to error state
      final latestAlbum = state.valueOrNull;
      if (latestAlbum == null) return;
      
      final latestMediaIndex = latestAlbum.media.indexWhere((m) => m.mediaId == media.mediaId);
      if (latestMediaIndex == -1) return;
      
      final latestUpdatedMedia = List<Media>.from(latestAlbum.media);
      latestUpdatedMedia[latestMediaIndex] = media.copyWith(isDownloading: false);
      
      // Update the album state
      state = AsyncData(latestAlbum.copyWith(media: latestUpdatedMedia));
    }
  }
}

final albumDetailNotifierProvider = StateNotifierProvider.family<AlbumDetailNotifier, AsyncValue<Album?>, String>((ref, albumId) {
  return AlbumDetailNotifier(ref, albumId);
});

class ViewModeNotifier extends StateNotifier<bool> {
  ViewModeNotifier() : super(true); // Default is grid view
  
  void toggleViewMode() {
    state = !state;
  }
}

final viewModeNotifierProvider = StateNotifierProvider<ViewModeNotifier, bool>((ref) {
  return ViewModeNotifier();
});