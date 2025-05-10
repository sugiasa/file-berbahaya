import 'dart:io';
import 'package:blurspace/models/media_item.dart';
import 'package:blurspace/utils/video_cache.dart';
import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

// State class to hold video player state
class VideoPlayerState {
  final VideoPlayerController? controller;
  final ChewieController? chewieController;
  final bool isLoading;
  final String? errorMessage;
  

  VideoPlayerState({
    this.controller,
    this.chewieController,
    this.isLoading = false,
    this.errorMessage,
  });

  VideoPlayerState copyWith({
    VideoPlayerController? controller,
    ChewieController? chewieController,
    bool? isLoading,
    String? errorMessage,
  }) {
    return VideoPlayerState(
      controller: controller ?? this.controller,
      chewieController: chewieController ?? this.chewieController,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

// Provider to manage current media index
final currentMediaIndexProvider = StateProvider<int>((ref) => 0);

// Provider to manage video player state
final videoPlayerStateProvider =
    StateNotifierProvider<VideoPlayerNotifier, VideoPlayerState>((ref) {
      return VideoPlayerNotifier(ref);
    });

class VideoPlayerNotifier extends StateNotifier<VideoPlayerState> {
  // ignore: unused_field
  final Ref _ref;
  // ignore: unused_field
  VideoPlayerController? _activeController;
  // ignore: unused_field
  ChewieController? _activeChewieController;

  VideoPlayerNotifier(this._ref) : super(VideoPlayerState(isLoading: false));

  @override
  void dispose() {
    disposeControllers();
    super.dispose();
  }

  Future<void> disposeControllers() async {
  debugPrint('Disposing video controllers');

  try {
    // Pause video dulu
    if (state.controller != null && state.controller!.value.isPlaying) {
      await state.controller!.pause();
    }

    // Dispose chewie (meskipun bukan async, tetap urutan penting)
    state.chewieController?.dispose();

    // Dispose video controller (ini async dan harus ditunggu!)
    if (state.controller != null) {
      await state.controller!.dispose();
    }

    // Reset
    _activeController = null;
    _activeChewieController = null;

    // Reset state dan update isLoading ke false
    state = VideoPlayerState(isLoading: false);
  } catch (e) {
    debugPrint('Dispose error: $e');
  }
}


  Future<void> loadVideo(MediaItem mediaItem) async {
    if (mediaItem.type != 'video') return;

    // Set loading state
    state = VideoPlayerState(isLoading: true);

    try {
      // Dispose controllers terlebih dahulu untuk mencegah memory leak
      disposeControllers();

      // Get cached path for video
      final videoPath = await VideoCacheManager().getVideoCachePath(
        mediaItem.fileUrl,
      );

      // Initialize video controller based on source (cache or network)
      final VideoPlayerController videoController;
      if (videoPath.startsWith('http')) {
        // If fallback to original URL, use network controller
        videoController = VideoPlayerController.networkUrl(
          Uri.parse(videoPath),
        );
      } else {
        // If using cached file
        videoController = VideoPlayerController.file(File(videoPath));
      }

      // Wait for initialization to complete
      await videoController.initialize();

      // Create chewie controller with Telegram-like style
      final chewieController = ChewieController(
        videoPlayerController: videoController,
        autoPlay: true,
        looping: true,
        aspectRatio: videoController.value.aspectRatio,
        allowFullScreen: true,
        allowMuting: true,
        showControls: true,
        showControlsOnInitialize: false,
        hideControlsTimer: const Duration(seconds: 5),
        placeholder: Container(color: Colors.black),
        materialProgressColors: ChewieProgressColors(
          playedColor: Colors.blue,
          handleColor: Colors.blue,
          backgroundColor: Colors.grey.shade700,
          bufferedColor: Colors.grey.shade500,
        ),
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Text(
              'Error: $errorMessage',
              style: const TextStyle(color: Colors.white),
            ),
          );
        },
      );

      // Store active controllers
      _activeController = videoController;
      _activeChewieController = chewieController;

      // Update state with controllers
      state = VideoPlayerState(
        controller: videoController,
        chewieController: chewieController,
        isLoading: false,
      );
    } catch (e) {
      // Handle error
      state = VideoPlayerState(
        isLoading: false,
        errorMessage: 'Error loading video: $e',
      );
    }
  }

  void seekBackward() {
    if (state.controller != null) {
      final newPosition =
          state.controller!.value.position - const Duration(seconds: 10);
      state.controller!.seekTo(newPosition);
    }
  }

  void seekForward() {
    if (state.controller != null) {
      final newPosition =
          state.controller!.value.position + const Duration(seconds: 10);
      state.controller!.seekTo(newPosition);
    }
  }

  // Tambahkan method untuk pause video
  void pauseVideo() {
    if (state.controller != null && state.controller!.value.isPlaying) {
      state.controller!.pause();
    }
  }
}
