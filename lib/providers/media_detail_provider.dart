import 'package:blurspace/models/media_item.dart';
import 'package:blurspace/providers/video_player_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Provider for current media index
final currentMediaIndexProvider = StateProvider<int>((ref) => 0);

// Provider for PageController
final pageControllerProvider = Provider.autoDispose<PageController>((ref) {
  final initialIndex = ref.watch(currentMediaIndexProvider);
  final controller = PageController(initialPage: initialIndex);

  ref.onDispose(() {
    controller.dispose();
  });

  return controller;
});

// Provider for the media list in the detail screen
final mediaDetailListProvider = Provider<List<MediaItem>>((ref) => []);

// Provider to update the media list
final updateMediaListProvider = StateProvider<List<MediaItem>>((ref) => []);

// Provider that loads the media at the current index
final currentMediaProvider = Provider.autoDispose<MediaItem?>((ref) {
  final mediaList = ref.watch(updateMediaListProvider);
  final currentIndex = ref.watch(currentMediaIndexProvider);

  if (currentIndex >= 0 && currentIndex < mediaList.length) {
    return mediaList[currentIndex];
  }

  return null;
});

// Provider for media change handling
final mediaChangeHandlerProvider = Provider.autoDispose<MediaChangeHandler>((ref) {
  return MediaChangeHandler(ref);
});

class MediaChangeHandler {
  final Ref _ref;
  bool _isChangingPage = false;

  MediaChangeHandler(this._ref);

  Future<void> onPageChanged(int index) async {
    // Prevent multiple simultaneous page changes
    if (_isChangingPage) {
      debugPrint('Page change already in progress, ignoring request for index: $index');
      return;
    }

    _isChangingPage = true;
    debugPrint('Starting page change to index: $index');

    try {
      // 1. Clean up any previous video controller
      await _ref.read(videoPlayerStateProvider.notifier).disposeControllers();
      debugPrint('Successfully disposed previous controllers');

      // 2. Update the index to the new one
      _ref.read(currentMediaIndexProvider.notifier).update((_) => index);
      debugPrint('Updated currentMediaIndexProvider to: $index');

      // 3. Get the new media
      final mediaList = _ref.read(updateMediaListProvider);
      if (index >= 0 && index < mediaList.length) {
        final media = mediaList[index];
        debugPrint('Loading media at index $index: ${media.type}');

        // 4. If it's a video, load it
        if (media.type == 'video') {
          debugPrint('Loading video: ${media.fileUrl}');
          await _ref.read(videoPlayerStateProvider.notifier).loadVideo(media);
          
          // Verify video loaded successfully
          final videoState = _ref.read(videoPlayerStateProvider);
          if (videoState.controller != null && videoState.controller!.value.isInitialized) {
            debugPrint('Video loaded successfully and controller initialized');
            // Explicitly start playback
            if (!videoState.controller!.value.isPlaying) {
              debugPrint('Starting video playback');
              videoState.controller!.play();
            }
          } else {
            debugPrint('Warning: Video controller not properly initialized');
          }
        }
      } else {
        debugPrint('Index out of bounds: $index, mediaList length: ${mediaList.length}');
      }
    } catch (e) {
      debugPrint('Error in MediaChangeHandler.onPageChanged: $e');
    } finally {
      _isChangingPage = false;
      debugPrint('Completed page change to index: $index');
    }
  }

  // Helper method to preload the next and previous videos
  Future<void> preloadAdjacentMedia(int currentIndex) async {
    try {
      final mediaList = _ref.read(updateMediaListProvider);
      if (mediaList.isEmpty) return;

      // Tentukan indeks sebelum dan sesudah
      final prevIndex = currentIndex > 0 ? currentIndex - 1 : null;
      final nextIndex = currentIndex < mediaList.length - 1 ? currentIndex + 1 : null;

      // Logic untuk preload bisa diimplementasikan di sini
      // Namun perlu berhati-hati agar tidak memakan terlalu banyak memori
      // Untuk saat ini, kita bisa memulai dengan approach sederhana
    } catch (e) {
      debugPrint('Error in preloadAdjacentMedia: $e');
    }
  }
}