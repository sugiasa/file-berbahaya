import 'package:blurspace/models/media_item.dart';
import 'package:blurspace/providers/video_player_provider.dart';
import 'package:blurspace/utils/video_cache.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'dart:io';
import 'dart:ui';

// Custom provider untuk zoom controller pada video
final videoZoomControllerProvider =
    StateProvider.autoDispose<TransformationController>((ref) {
      return TransformationController();
    });

// Custom provider untuk status tampilan full control video player
final videoFullControlsProvider = StateProvider.autoDispose<bool>((ref) {
  return false;
});

// Custom provider untuk mengatur delay auto-hide controls
final videoControlsTimerProvider = StateProvider.autoDispose<bool>((ref) {
  return true;
});

class CustomVideoPlayerWidget extends ConsumerStatefulWidget {
  final MediaItem mediaItem;
  final int index;

  const CustomVideoPlayerWidget({
    super.key,
    required this.mediaItem,
    required this.index,
  });

  @override
  ConsumerState<CustomVideoPlayerWidget> createState() =>
      _CustomVideoPlayerWidgetState();
}

class _CustomVideoPlayerWidgetState
    extends ConsumerState<CustomVideoPlayerWidget> {
  late VideoPlayerController _videoController;
  ChewieController? _chewieController;
  bool _isInitialized = false;
  bool _isLoading = true;
  String? _errorMessage;
  double _currentVolume = 1.0;
  bool _isMuted = false;
  bool _isZoomed = false;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  void _disposeControllers() {
    _chewieController?.dispose();
    _videoController.dispose();
  }

  Future<void> _initializePlayer() async {
    if (widget.mediaItem.type != 'video') return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Get cached path for video
      final videoPath = await VideoCacheManager().getVideoCachePath(
        widget.mediaItem.fileUrl,
      );

      // Initialize video controller based on source
      if (videoPath.startsWith('http')) {
        _videoController = VideoPlayerController.networkUrl(
          Uri.parse(videoPath),
        );
      } else {
        _videoController = VideoPlayerController.file(File(videoPath));
      }

      // Wait for initialization to complete
      await _videoController.initialize();

      // Create custom chewie controller
      _chewieController = ChewieController(
        videoPlayerController: _videoController,
        autoPlay: true,
        looping: true,
        allowFullScreen: true,
        allowMuting: true,
        fullScreenByDefault: true,
        deviceOrientationsAfterFullScreen: [DeviceOrientation.portraitUp],
        showControls: false, // Kita bikin custom controls sendiri
        aspectRatio: _videoController.value.aspectRatio,
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Text(
              'Error: $errorMessage',
              style: const TextStyle(color: Colors.white),
            ),
          );
        },
      );

      // Update state
      setState(() {
        _isInitialized = true;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error loading video: $e';
      });
    }
  }

  void _togglePlayPause() {
    if (_videoController.value.isPlaying) {
      _videoController.pause();
    } else {
      _videoController.play();
    }
    setState(() {});
  }

  void _toggleMute() {
    if (_isMuted) {
      _videoController.setVolume(_currentVolume);
    } else {
      _currentVolume = _videoController.value.volume;
      _videoController.setVolume(0);
    }
    setState(() {
      _isMuted = !_isMuted;
    });
  }

  void _seekBackward() {
    final newPosition =
        _videoController.value.position - const Duration(seconds: 10);
    _videoController.seekTo(newPosition);
  }

  void _seekForward() {
    final newPosition =
        _videoController.value.position + const Duration(seconds: 10);
    _videoController.seekTo(newPosition);
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    if (duration.inHours > 0) {
      return '${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds';
    } else {
      return '$twoDigitMinutes:$twoDigitSeconds';
    }
  }

  void _resetZoom() {
    ref.read(videoZoomControllerProvider).value = Matrix4.identity();
    setState(() {
      _isZoomed = false;
    });
  }

  void _toggleFullControls() {
    // Toggle full controls mode
    ref.read(videoFullControlsProvider.notifier).state =
        !ref.read(videoFullControlsProvider);

    // Reset auto-hide timer
    ref.read(videoControlsTimerProvider.notifier).state = true;
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        ref.read(videoControlsTimerProvider.notifier).state = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final fullControls = ref.watch(videoFullControlsProvider);
    final showControls = ref.watch(videoControlsTimerProvider);
    final zoomController = ref.watch(videoZoomControllerProvider);

    if (_isLoading) {
      return _buildLoadingWidget();
    }

    if (_errorMessage != null) {
      return Center(
        child: Text(
          _errorMessage!,
          style: const TextStyle(color: Colors.white),
        ),
      );
    }

    if (!_isInitialized) {
      return _buildLoadingWidget();
    }

    return GestureDetector(
      onTap: _toggleFullControls,
      onDoubleTap: _togglePlayPause,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // InteractiveViewer untuk pinch-to-zoom
          InteractiveViewer(
            transformationController: zoomController,
            minScale: 1.0,
            maxScale: 4.0,
            onInteractionStart: (details) {
              // Pause video saat user mulai zoom
              if (_videoController.value.isPlaying) {
                _videoController.pause();
              }
            },
            onInteractionUpdate: (details) {
              if (zoomController.value != Matrix4.identity()) {
                setState(() {
                  _isZoomed = true;
                });
              }
            },
            onInteractionEnd: (details) {
              if (zoomController.value == Matrix4.identity()) {
                setState(() {
                  _isZoomed = false;
                });
              }
            },
            child: Center(
              child: AspectRatio(
                aspectRatio: _videoController.value.aspectRatio,
                child: VideoPlayer(_videoController),
              ),
            ),
          ),

          // Double tap zones (rewind/forward)
          if (!_isZoomed)
            Positioned.fill(
              child: Row(
                children: [
                  // Left zone (rewind)
                  Expanded(
                    child: GestureDetector(
                      onDoubleTap: _seekBackward,
                      behavior: HitTestBehavior.translucent,
                      child: Container(color: Colors.transparent),
                    ),
                  ),
                  // Middle zone (kosong, untuk menghindari konflik dengan double tap play/pause)
                  const SizedBox(width: 60),
                  // Right zone (forward)
                  Expanded(
                    child: GestureDetector(
                      onDoubleTap: _seekForward,
                      behavior: HitTestBehavior.translucent,
                      child: Container(color: Colors.transparent),
                    ),
                  ),
                ],
              ),
            ),

          // Reset zoom button (muncul hanya saat zoomed)
          if (_isZoomed)
            Positioned(
              top: 20,
              right: 20,
              child: GestureDetector(
                onTap: _resetZoom,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.zoom_out_map,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),

          // Basic controls overlay (hanya muncul saat tap)
          if (showControls && !_isZoomed)
            Positioned.fill(
              child: AnimatedOpacity(
                opacity: fullControls ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: Container(
                  color: Colors.black.withOpacity(0.3),
                  child: Stack(
                    children: [
                      // Center play/pause button
                      Center(
                        child: IconButton(
                          icon: Icon(
                            _videoController.value.isPlaying
                                ? Icons.pause_circle_filled
                                : Icons.play_circle_fill,
                            color: Colors.white,
                            size: 64,
                          ),
                          onPressed: _togglePlayPause,
                        ),
                      ),

                      // Bottom controls
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.7),
                              ],
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Progress bar
                              ValueListenableBuilder(
                                valueListenable: _videoController,
                                builder: (
                                  context,
                                  VideoPlayerValue value,
                                  child,
                                ) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                    child: Row(
                                      children: [
                                        Text(
                                          _formatDuration(value.position),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                          ),
                                        ),
                                        Expanded(
                                          child: SliderTheme(
                                            data: SliderThemeData(
                                              trackHeight: 2,
                                              thumbShape:
                                                  const RoundSliderThumbShape(
                                                    enabledThumbRadius: 6,
                                                  ),
                                              overlayShape:
                                                  const RoundSliderOverlayShape(
                                                    overlayRadius: 12,
                                                  ),
                                              trackShape: CustomTrackShape(),
                                            ),
                                            child: Slider(
                                              value:
                                                  value.position.inMilliseconds
                                                      .toDouble(),
                                              min: 0,
                                              max:
                                                  value.duration.inMilliseconds
                                                      .toDouble(),
                                              activeColor: Colors.blueAccent,
                                              inactiveColor:
                                                  Colors.grey.shade600,
                                              onChanged: (newValue) {
                                                _videoController.seekTo(
                                                  Duration(
                                                    milliseconds:
                                                        newValue.toInt(),
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                        Text(
                                          _formatDuration(value.duration),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),

                              // Control buttons
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8.0,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    // Left controls
                                    Row(
                                      children: [
                                        IconButton(
                                          icon: Icon(
                                            _isMuted
                                                ? Icons.volume_off
                                                : Icons.volume_up,
                                            color: Colors.white,
                                            size: 24,
                                          ),
                                          onPressed: _toggleMute,
                                        ),
                                      ],
                                    ),

                                    // Right controls
                                    Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(
                                            Icons.replay_10,
                                            color: Colors.white,
                                            size: 24,
                                          ),
                                          onPressed: _seekBackward,
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.forward_10,
                                            color: Colors.white,
                                            size: 24,
                                          ),
                                          onPressed: _seekForward,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLoadingWidget() {
    // Widget loading dengan background blur dari thumbnail
    return Stack(
      fit: StackFit.expand,
      children: [
        // Thumbnail yang diblur
        CachedNetworkImage(
          imageUrl: widget.mediaItem.thumbnailUrl,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(color: Colors.black),
          errorWidget: (context, url, error) => Container(color: Colors.black),
          imageBuilder: (context, imageProvider) {
            return Stack(
              fit: StackFit.expand,
              children: [
                // Image background
                Image(image: imageProvider, fit: BoxFit.cover),
                // Blur layer
                ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 15.0, sigmaY: 15.0),
                    child: Container(color: Colors.black.withOpacity(0.3)),
                  ),
                ),
              ],
            );
          },
        ),

        // Loading indicator
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 3,
              ),
              const SizedBox(height: 16),
              Text(
                'Loading video...',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// Custom track shape untuk progress bar yang lebih tipis
class CustomTrackShape extends RoundedRectSliderTrackShape {
  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final double trackHeight = sliderTheme.trackHeight ?? 1;
    final double trackLeft = offset.dx;
    final double trackTop =
        offset.dy + (parentBox.size.height - trackHeight) / 2;
    final double trackWidth = parentBox.size.width;
    return Rect.fromLTWH(trackLeft, trackTop, trackWidth, trackHeight);
  }
}
