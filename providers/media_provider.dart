import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../models/media_model.dart';
import 'cache_provider.dart';

class MediaViewerNotifier extends StateNotifier<void> {
  final Ref ref;
  final List<Media> mediaList;
  final int initialIndex;
  VideoPlayerController? _videoPlayerController;
  
  MediaViewerNotifier(this.ref, this.mediaList, this.initialIndex) : super(null) {
    // Initial setup happens in the StateNotifierProvider.
    // We'll load the initial media when called externally
  }
  
  void dispose() {
    super.dispose();
    _disposeVideoController();
  }
  
  void _disposeVideoController() {
    _videoPlayerController?.dispose();
    _videoPlayerController = null;
  }
  
  Future<void> loadMedia(Media media) async {
    // Clean up previous controller
    _disposeVideoController();
    
    // Skip if not downloaded or premium
    if (!media.isDownloaded || media.isPremium) {
      return;
    }
    
    // Get local file path if not provided
    String? localPath = media.localPath;
    if (localPath == null) {
      localPath = await ref.read(mediaLocalPathProvider(media.mediaId).future);
    }
    
    if (localPath == null) {
      return; // No local path available
    }
    
    // Initialize video if needed
    if (media.mediaType == 'video') {
      _videoPlayerController = VideoPlayerController.file(File(localPath));
      await _videoPlayerController!.initialize();
      _videoPlayerController!.play();
    }
  }
  
  Future<void> onPageChanged(List<Media> mediaList, int index) async {
    if (index >= 0 && index < mediaList.length) {
      await loadMedia(mediaList[index]);
    }
  }
  
  void togglePlayPause() {
    if (_videoPlayerController != null && _videoPlayerController!.value.isInitialized) {
      if (_videoPlayerController!.value.isPlaying) {
        _videoPlayerController!.pause();
      } else {
        _videoPlayerController!.play();
      }
    }
  }
  
  VideoPlayerController? get videoPlayerController => _videoPlayerController;
  
  bool get isVideoInitialized => 
      _videoPlayerController != null && _videoPlayerController!.value.isInitialized;
}

final mediaViewerNotifierProvider = StateNotifierProvider.family<MediaViewerNotifier, void, (List<Media>, int)>((ref, params) {
  final notifier = MediaViewerNotifier(ref, params.$1, params.$2);
  
  // Load initial media
  if (params.$1.isNotEmpty && params.$2 >= 0 && params.$2 < params.$1.length) {
    // We need to dispatch this in a post-frame callback
    Future.microtask(() {
      notifier.loadMedia(params.$1[params.$2]);
    });
  }
  
  // Clean up on dispose
  ref.onDispose(() {
    notifier.dispose();
  });
  
  return notifier;
});

class MediaViewerUIState {
  final int currentIndex;
  final bool showControls;
  final bool isFullScreen;
  
  MediaViewerUIState({
    required this.currentIndex,
    required this.showControls,
    required this.isFullScreen,
  });
  
  MediaViewerUIState copyWith({
    int? currentIndex,
    bool? showControls,
    bool? isFullScreen,
  }) {
    return MediaViewerUIState(
      currentIndex: currentIndex ?? this.currentIndex,
      showControls: showControls ?? this.showControls,
      isFullScreen: isFullScreen ?? this.isFullScreen,
    );
  }
}

class MediaViewerUINotifier extends StateNotifier<MediaViewerUIState> {
  MediaViewerUINotifier() : super(
    MediaViewerUIState(
      currentIndex: 0,
      showControls: true,
      isFullScreen: false,
    )
  );
  
  void setCurrentIndex(int index) {
    state = state.copyWith(currentIndex: index);
  }
  
  void toggleControls() {
    state = state.copyWith(showControls: !state.showControls);
  }
  
  void toggleFullScreen() {
    state = state.copyWith(
      isFullScreen: !state.isFullScreen,
      showControls: !state.isFullScreen ? false : state.showControls,
    );
  }
}

final mediaViewerUINotifierProvider = StateNotifierProvider<MediaViewerUINotifier, MediaViewerUIState>((ref) {
  return MediaViewerUINotifier();
});