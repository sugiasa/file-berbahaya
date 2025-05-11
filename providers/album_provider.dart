import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/album_model.dart';
import '../models/media_model.dart';
import 'cache_provider.dart';
import 'connectivity_provider.dart';

final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

class AlbumsNotifier extends StateNotifier<AsyncValue<List<Album>>> {
  final Ref ref;

  AlbumsNotifier(this.ref) : super(const AsyncLoading()) {
    loadAlbums();
  }

  Future<void> loadAlbums() async {
    // Check connectivity first
    final connectivityStatus = ref.read(connectivityStatusProvider);
    final isOnline = connectivityStatus.valueOrNull ?? false;
    
    if (!isOnline) {
      // If offline, try to load from cache
      try {
        final cachedAlbums = await ref.read(cachedAlbumListProvider.future);
        if (cachedAlbums != null && cachedAlbums.isNotEmpty) {
          final albums = cachedAlbums
              .map((album) => Album.fromJson(album, album['albumId']))
              .toList();
          state = AsyncData(albums);
        } else {
          state = const AsyncData([]);
        }
      } catch (e, stackTrace) {
        state = AsyncError(e, stackTrace);
      }
      return;
    }
    
    // If online, fetch from Firestore
    await _fetchAlbums();
  }
  
  Future<void> _fetchAlbums() async {
    state = const AsyncLoading();
    
    try {
      final firestore = ref.read(firestoreProvider);
      final cacheManager = ref.read(cacheManagerProvider);
      
      // Fetch all albums
      final QuerySnapshot albumSnapshot = await firestore
          .collection('albums')
          .orderBy('createdAt', descending: true)
          .get();

      final List<Album> fetchedAlbums = [];

      // Process each album
      for (final doc in albumSnapshot.docs) {
        final albumData = doc.data() as Map<String, dynamic>;
        final String albumId = doc.id;

        // Only include unlocked albums
        if (!(albumData['isLocked'] ?? false)) {
          final album = Album.fromJson(albumData, albumId);
          
          // Fetch a preview of media (maximum 5)
          final QuerySnapshot mediaSnapshot = await firestore
              .collection('albums')
              .doc(albumId)
              .collection('media')
              .limit(5)
              .get();

          final List<Media> mediaList = [];
          bool hasPremiumMedia = false;

          for (final mediaDoc in mediaSnapshot.docs) {
            final mediaData = mediaDoc.data() as Map<String, dynamic>;
            final mediaId = mediaDoc.id;
            
            final bool isDownloaded = await cacheManager.isMediaCached(mediaId);
            
            final media = Media.fromJson({
              ...mediaData,
              'isDownloaded': isDownloaded,
              'isDownloading': false,
            }, mediaId);
            
            mediaList.add(media);

            // Check if any media is premium
            if (media.isPremium) {
              hasPremiumMedia = true;
            }
          }

          // Add media and hasPremiumMedia flag to album
          final updatedAlbum = album.copyWith(
            media: mediaList,
            hasPremiumMedia: hasPremiumMedia,
          );
          
          fetchedAlbums.add(updatedAlbum);

          // Cache media info for this album
          await cacheManager.cacheMediaInfo(
            albumId, 
            mediaList.map((media) => media.toJson()).toList(),
          );
        }
      }

      // Cache the fetched albums for offline use
      await cacheManager.cacheAlbumList(
        fetchedAlbums.map((album) => album.toJson()).toList()
      );

      state = AsyncData(fetchedAlbums);
    } catch (e, stackTrace) {
      // If fetching fails, try to load from cache
      try {
        final cachedAlbums = await ref.read(cachedAlbumListProvider.future);
        
        if (cachedAlbums != null && cachedAlbums.isNotEmpty) {
          final albums = cachedAlbums
              .map((album) => Album.fromJson(album, album['albumId']))
              .toList();
          
          state = AsyncData(albums);
        } else {
          state = AsyncError(e, stackTrace);
        }
      } catch (_) {
        state = AsyncError(e, stackTrace);
      }
    }
  }
  
  Future<void> refreshAlbums() async {
    // First check connectivity
    final isOnline = await ref.read(connectivityStatusProvider.notifier).checkConnectivity();
    
    if (isOnline) {
      // If online, fetch fresh data
      await _fetchAlbums();
    }
  }
}

final albumsNotifierProvider = StateNotifierProvider<AlbumsNotifier, AsyncValue<List<Album>>>((ref) {
  return AlbumsNotifier(ref);
});