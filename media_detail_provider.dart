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
final mediaChangeHandlerProvider = Provider.autoDispose<MediaChangeHandler>((
  ref,
) {
  return MediaChangeHandler(ref);
});

class MediaChangeHandler {
  final Ref _ref;

  MediaChangeHandler(this._ref);

  void onPageChanged(int index) async {
    try {
      // 1. Bersihin video sebelumnya DULU
      await _ref.read(videoPlayerStateProvider.notifier).disposeControllers();

      // 2. Update index ke yang baru
      _ref.read(currentMediaIndexProvider.notifier).update((_) => index);

      // 3. Ambil media baru
      final mediaList = _ref.read(updateMediaListProvider);
      if (index >= 0 && index < mediaList.length) {
        final media = mediaList[index];

        // 4. Kalau video, load
        if (media.type == 'video') {
          await _ref.read(videoPlayerStateProvider.notifier).loadVideo(media);
        }
      }
    } catch (e) {
      debugPrint('Error in MediaChangeHandler.onPageChanged: $e');
    }
  }
}
