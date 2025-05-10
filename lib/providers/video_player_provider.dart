// ignore_for_file: unused_field

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

// Provider to manage video player state
final videoPlayerStateProvider = StateNotifierProvider<VideoPlayerNotifier, VideoPlayerState>((ref) {
  return VideoPlayerNotifier(ref);
});

class VideoPlayerNotifier extends StateNotifier<VideoPlayerState> {
  final Ref _ref;
  VideoPlayerController? _activeController;
  ChewieController? _activeChewieController;

  VideoPlayerNotifier(this._ref) : super(VideoPlayerState(isLoading: false));

  @override
  void dispose() {
    disposeControllers();
    super.dispose();
  }

  Future<void> disposeControllers() async {
    try {
      // Pause video first
      if (state.controller != null && state.controller!.value.isPlaying) {
        await state.controller!.pause();
      }

      // Dispose chewie (even though it's not async, order matters)
      state.chewieController?.dispose();

      // Dispose video controller (this is async and needs to be awaited)
      if (state.controller != null) {
        await state.controller!.dispose();
      }

      _activeController = null;
      _activeChewieController = null;
      state = VideoPlayerState(isLoading: false);
    } catch (e) {
      debugPrint('Dispose error: $e');
    }
  }

  Future<void> loadVideo(MediaItem mediaItem) async {
    if (mediaItem.type != 'video') return;

    debugPrint('Starting to load video: ${mediaItem.fileUrl}');
    state = VideoPlayerState(isLoading: true);

    try {
      await disposeControllers();
      debugPrint('Previous controllers disposed');

      final videoPath = await VideoCacheManager().getVideoCachePath(mediaItem.fileUrl);
      debugPrint('Video path resolved: $videoPath');

      final VideoPlayerController videoController;
      if (videoPath.startsWith('http')) {
        debugPrint('Creating network video controller');
        videoController = VideoPlayerController.networkUrl(Uri.parse(videoPath));
      } else {
        debugPrint('Creating file video controller');
        videoController = VideoPlayerController.file(File(videoPath));
      }

      debugPrint('Initializing video controller');
      await videoController.initialize();
      debugPrint('Video controller initialized successfully');

      // We still create ChewieController for compatibility with old code,
      // but we won't use it for the UI in our CustomVideoPlayerWidget
      final chewieController = ChewieController(
        videoPlayerController: videoController,
        autoPlay: true,
        looping: true,
        aspectRatio: videoController.value.aspectRatio,
        allowFullScreen: true,
        allowMuting: true,
        showControls: false, // We use custom controls
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

      _activeController = videoController;
      _activeChewieController = chewieController;

      // Explicitly start playback
      try {
        debugPrint('Starting video playback');
        await videoController.play();
      } catch (playError) {
        debugPrint('Warning: Error starting playback: $playError');
        // Continue even if play() fails - we'll let the UI handle play/pause
      }

      debugPrint('Video loaded successfully, updating state');
      state = VideoPlayerState(
        controller: videoController,
        chewieController: chewieController,
        isLoading: false,
      );
    } catch (e) {
      debugPrint('Error loading video: $e');
      state = VideoPlayerState(
        isLoading: false,
        errorMessage: 'Error loading video: $e',
      );
    }
  }

  void seekBackward() {
    if (state.controller != null) {
      final newPosition = state.controller!.value.position - const Duration(seconds: 10);
      state.controller!.seekTo(newPosition);
    }
  }

  void seekForward() {
    if (state.controller != null) {
      final newPosition = state.controller!.value.position + const Duration(seconds: 10);
      state.controller!.seekTo(newPosition);
    }
  }

  void pauseVideo() {
    if (state.controller != null && state.controller!.value.isPlaying) {
      state.controller!.pause();
    }
  }

  void playVideo() {
    if (state.controller != null && !state.controller!.value.isPlaying) {
      state.controller!.play();
    }
  }

  void togglePlayPause() {
    if (state.controller != null) {
      if (state.controller!.value.isPlaying) {
        pauseVideo();
      } else {
        playVideo();
      }
    }
  }

  Future<void> setVolume(double volume) async {
    if (state.controller != null) {
      await state.controller!.setVolume(volume);
    }
  }

  Future<void> seekTo(Duration position) async {
    if (state.controller != null) {
      await state.controller!.seekTo(position);
    }
  }
}