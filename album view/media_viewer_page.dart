// ignore_for_file: use_key_in_widget_constructors

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';

class MediaViewerPage extends StatefulWidget {
  final String albumId;
  final int initialMediaIndex;
  final List<Map<String, dynamic>> mediaList;
  final Map<String, dynamic> cachedMedia;

  MediaViewerPage({
    required this.albumId,
    required this.initialMediaIndex,
    required this.mediaList,
    required this.cachedMedia,
  });

  @override
  _MediaViewerPageState createState() => _MediaViewerPageState();
}

class _MediaViewerPageState extends State<MediaViewerPage> {
  late PageController _pageController;
  late ScrollController _thumbnailScrollController;
  late int currentIndex;
  VideoPlayerController? _videoPlayerController;
  bool isVideoInitialized = false;
  bool isVideoLoading = false;
  bool isFullScreen = false;
  bool showControls = true;

  @override
  void initState() {
    super.initState();
    currentIndex = widget.initialMediaIndex;
    _pageController = PageController(initialPage: currentIndex);
    _thumbnailScrollController = ScrollController();

    // Set preferred orientations to allow landscape
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    // Initialize with the first media
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMedia(currentIndex);
      _scrollToSelectedThumbnail();
    });
  }

  @override
  void dispose() {
    // Reset to portrait only
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    
    _pageController.dispose();
    _thumbnailScrollController.dispose();
    _videoPlayerController?.dispose();
    super.dispose();
  }

  void _scrollToSelectedThumbnail() {
    // Calculate the position to center the selected thumbnail
    if (_thumbnailScrollController.hasClients) {
      final double screenWidth = MediaQuery.of(context).size.width;
      final double thumbnailWidth = 80.0; // Width of each thumbnail
      final double offset = currentIndex * thumbnailWidth - (screenWidth / 2) + (thumbnailWidth / 2);
      
      _thumbnailScrollController.animateTo(
        offset < 0 ? 0 : offset,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }
  
  void _loadMedia(int index) {
    final media = widget.mediaList[index];
    final mediaId = media['mediaId'];
    final isDownloaded = media['isDownloaded'] ?? false;
    final isPremium = media['isPremium'] ?? false;
    
    // Clean up previous video controller
    if (_videoPlayerController != null) {
      _videoPlayerController!.dispose();
      _videoPlayerController = null;
      setState(() {
        isVideoInitialized = false;
        isVideoLoading = false;
      });
    }
    
    // Don't load premium content or non-downloaded content
    if (isPremium || !isDownloaded) {
      return;
    }
    
    // Get cached media
    final cachedMediaItem = widget.cachedMedia[mediaId];
    if (cachedMediaItem == null) {
      return;
    }
    
    final mediaUrl = cachedMediaItem['mediaUrl'];
    final mediaType = cachedMediaItem['mediaType'];
    
    // Load video if it's a video
    if (mediaType == 'video' && mediaUrl != null) {
      setState(() {
        isVideoLoading = true;
      });
      
      _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(mediaUrl));
      _videoPlayerController!.initialize().then((_) {
        if (mounted) {
          setState(() {
            isVideoInitialized = true;
            isVideoLoading = false;
          });
          _videoPlayerController!.play();
        }
      }).catchError((error) {
        print('Error initializing video: $error');
        if (mounted) {
          setState(() {
            isVideoLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error playing video: $error')),
          );
        }
      });
    }
  }

  void _toggleFullScreen() {
    setState(() {
      isFullScreen = !isFullScreen;
      showControls = !isFullScreen;
    });
  }

  void _togglePlayPause() {
    if (_videoPlayerController != null && isVideoInitialized) {
      _videoPlayerController!.value.isPlaying
          ? _videoPlayerController!.pause()
          : _videoPlayerController!.play();
      setState(() {}); // Update UI
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.black,
      appBar: showControls && !isFullScreen
          ? AppBar(
              backgroundColor: Colors.black.withOpacity(0.5),
              elevation: 0,
              iconTheme: IconThemeData(color: Colors.white),
              title: Text(
                widget.mediaList[currentIndex]['name'] ?? 'Media Viewer',
                style: TextStyle(color: Colors.white),
              ),
              actions: [
                IconButton(
                  icon: Icon(isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen),
                  onPressed: _toggleFullScreen,
                ),
              ],
            )
          : null,
      body: GestureDetector(
        onTap: () {
          setState(() {
            showControls = !showControls;
          });
        },
        child: Stack(
          children: [
            // Status bar color overlay
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: MediaQuery.of(context).padding.top,
              child: Container(
                color: Colors.black.withOpacity(0.5),
              ),
            ),
            
            // Main content viewer
            PageView.builder(
              controller: _pageController,
              itemCount: widget.mediaList.length,
              onPageChanged: (index) {
                setState(() {
                  currentIndex = index;
                });
                _loadMedia(index);
                _scrollToSelectedThumbnail();
              },
              itemBuilder: (context, index) {
                final media = widget.mediaList[index];
                final mediaId = media['mediaId'];
                final bool isPremium = media['isPremium'] ?? false;
                final bool isDownloaded = media['isDownloaded'] ?? false;
                
                if (isPremium) {
                  // Premium content view
                  return Center(
                    child: Container(
                      constraints: BoxConstraints(maxWidth: 600),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              CachedNetworkImage(
                                imageUrl: media['thumbnailUrl'] ?? '',
                                fit: BoxFit.contain,
                                width: double.infinity,
                                height: 300,
                                placeholder: (context, url) => Center(
                                  child: CircularProgressIndicator(),
                                ),
                                errorWidget: (context, url, error) => Icon(
                                  Icons.image_not_supported,
                                  size: 100,
                                  color: Colors.white,
                                ),
                              ),
                              BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
                                child: Container(
                                  color: Colors.black.withOpacity(0.5),
                                  width: double.infinity,
                                  height: 300,
                                ),
                              ),
                              Icon(
                                Icons.lock,
                                size: 80,
                                color: Colors.white,
                              ),
                            ],
                          ),
                          SizedBox(height: 24),
                          Text(
                            'PREMIUM CONTENT',
                            style: TextStyle(
                              color: Colors.amber,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Subscribe to access premium content',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 24),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber,
                              padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                            ),
                            onPressed: () {
                              // Handle subscription
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Subscription feature coming soon')),
                              );
                            },
                            child: Text(
                              'SUBSCRIBE NOW',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                } else if (!isDownloaded) {
                  // Not downloaded content
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.download,
                          size: 80,
                          color: Colors.white,
                        ),
                        SizedBox(height: 24),
                        Text(
                          'Media not cached',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                          ),
                        ),
                        SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          child: Text('Go back and download'),
                        ),
                      ],
                    ),
                  );
                } else {
                  // Get cached media
                  final cachedMediaItem = widget.cachedMedia[mediaId];
                  if (cachedMediaItem == null) {
                    return Center(
                      child: Text(
                        'Media not found in cache',
                        style: TextStyle(color: Colors.white),
                      ),
                    );
                  }
                  
                  final mediaUrl = cachedMediaItem['mediaUrl'];
                  final mediaType = cachedMediaItem['mediaType'];
                  
                  if (mediaType == 'video') {
                    // Video player
                    if (isVideoLoading) {
                      return Center(
                        child: CircularProgressIndicator(),
                      );
                    } else if (isVideoInitialized && _videoPlayerController != null) {
                      return Center(
                        child: AspectRatio(
                          aspectRatio: _videoPlayerController!.value.aspectRatio,
                          child: Stack(
                            alignment: Alignment.bottomCenter,
                            children: [
                              VideoPlayer(_videoPlayerController!),
                              
                              // Video controls
                              if (showControls)
                                _VideoControlsOverlay(
                                  controller: _videoPlayerController!,
                                  onTap: _togglePlayPause,
                                ),
                                
                              // Video progress
                              if (showControls)
                                Positioned(
                                  bottom: 0,
                                  left: 0,
                                  right: 0,
                                  child: Container(
                                    padding: EdgeInsets.only(bottom: 10),
                                    color: Colors.black.withOpacity(0.3),
                                    child: VideoProgressIndicator(
                                      _videoPlayerController!,
                                      allowScrubbing: true,
                                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                      colors: VideoProgressColors(
                                        playedColor: Colors.amber,
                                        bufferedColor: Colors.white.withOpacity(0.3),
                                        backgroundColor: Colors.white.withOpacity(0.1),
                                      ),
                                    ),
                                  ),
                                ),
                              
                              // Center play/pause button
                              GestureDetector(
                                onTap: _togglePlayPause,
                                child: Center(
                                  child: AnimatedOpacity(
                                    opacity: showControls && !_videoPlayerController!.value.isPlaying ? 1.0 : 0.0,
                                    duration: Duration(milliseconds: 300),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.5),
                                        shape: BoxShape.circle,
                                      ),
                                      padding: EdgeInsets.all(20),
                                      child: Icon(
                                        Icons.play_arrow,
                                        color: Colors.white,
                                        size: 50,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    } else {
                      return Center(
                        child: Text(
                          'Error loading video',
                          style: TextStyle(color: Colors.white),
                        ),
                      );
                    }
                  } else {
                    // Image viewer
                    return Center(
                      child: InteractiveViewer(
                        minScale: 0.5,
                        maxScale: 4.0,
                        child: CachedNetworkImage(
                          imageUrl: mediaUrl,
                          fit: BoxFit.contain,
                          placeholder: (context, url) => Center(
                            child: CircularProgressIndicator(),
                          ),
                          errorWidget: (context, url, error) => Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 60,
                                color: Colors.red,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'Error loading image',
                                style: TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }
                }
              },
            ),
            
            // Bottom thumbnail navigation
            if (showControls && !isFullScreen)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  height: 120,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Current media info
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${currentIndex + 1}/${widget.mediaList.length}',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              widget.mediaList[currentIndex]['mediaType']?.toUpperCase() ?? 'MEDIA',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 8),
                      
                      // Thumbnail carousel
                      Container(
                        height: 80,
                        child: ListView.builder(
                          controller: _thumbnailScrollController,
                          scrollDirection: Axis.horizontal,
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          itemCount: widget.mediaList.length,
                          itemBuilder: (context, index) {
                            final media = widget.mediaList[index];
                            final bool isPremium = media['isPremium'] ?? false;
                            final bool isSelected = index == currentIndex;
                            
                            return GestureDetector(
                              onTap: () {
                                _pageController.animateToPage(
                                  index,
                                  duration: Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                );
                              },
                              child: Container(
                                width: 70,
                                margin: EdgeInsets.symmetric(horizontal: 4),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: isSelected
                                      ? Border.all(color: Colors.amber, width: 2)
                                      : null,
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    CachedNetworkImage(
                                      imageUrl: media['thumbnailUrl'] ?? '',
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => Center(
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                      errorWidget: (context, url, error) => Container(
                                        color: Colors.grey[800],
                                        child: Center(
                                          child: Icon(
                                            media['mediaType'] == 'video'
                                                ? Icons.video_file
                                                : Icons.image,
                                            color: Colors.white,
                                            size: 24,
                                          ),
                                        ),
                                      ),
                                    ),
                                    
                                    // Blur effect for premium content
                                    if (isPremium)
                                      ClipRRect(
                                        child: BackdropFilter(
                                          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                                          child: Container(
                                            color: Colors.black.withOpacity(0.3),
                                            child: Center(
                                              child: Icon(
                                                Icons.lock,
                                                color: Colors.white,
                                                size: 20,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    
                                    // Media type indicator
                                    if (media['mediaType'] == 'video')
                                      Positioned(
                                        right: 4,
                                        bottom: 4,
                                        child: Container(
                                          padding: EdgeInsets.all(2),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withOpacity(0.6),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Icon(
                                            Icons.play_arrow,
                                            color: Colors.white,
                                            size: 12,
                                          ),
                                        ),
                                      ),
                                      
                                    // Selected indicator highlight
                                    if (isSelected)
                                      Container(
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: Colors.amber,
                                            width: 2,
                                          ),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
            // Top media controls when in fullscreen
            if (showControls && isFullScreen)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top,
                    left: 16,
                    right: 16,
                    bottom: 16,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.black.withOpacity(0.8), Colors.transparent],
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () {
                          Navigator.pop(context);
                        },
                      ),
                      Text(
                        widget.mediaList[currentIndex]['name'] ?? 'Media Viewer',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.fullscreen_exit, color: Colors.white),
                        onPressed: _toggleFullScreen,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// Video controls overlay
class _VideoControlsOverlay extends StatelessWidget {
  final VideoPlayerController controller;
  final VoidCallback onTap;

  const _VideoControlsOverlay({
    required this.controller,
    required this.onTap,
  });

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Play/Pause button in the center
        Center(
          child: IconButton(
            icon: Icon(
              controller.value.isPlaying ? Icons.pause_circle_outline : Icons.play_circle_outline,
              color: Colors.white,
              size: 60,
            ),
            onPressed: onTap,
          ),
        ),
        
        // Bottom controls
        Positioned(
          left: 0,
          right: 0,
          bottom: 30,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Current position
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: ValueListenableBuilder<VideoPlayerValue>(
                  valueListenable: controller,
                  builder: (context, value, child) {
                    return Text(
                      _formatDuration(value.position),
                      style: TextStyle(color: Colors.white),
                    );
                  },
                ),
              ),
              
              // Playback speed
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: PopupMenuButton<double>(
                  initialValue: controller.value.playbackSpeed,
                  tooltip: 'Playback speed',
                  color: Colors.black87,
                  onSelected: (double speed) {
                    controller.setPlaybackSpeed(speed);
                  },
                  itemBuilder: (context) {
                    return [
                      PopupMenuItem(
                        value: 0.5,
                        child: Text('0.5x', style: TextStyle(color: Colors.white)),
                      ),
                      PopupMenuItem(
                        value: 1.0,
                        child: Text('1.0x', style: TextStyle(color: Colors.white)),
                      ),
                      PopupMenuItem(
                        value: 1.5,
                        child: Text('1.5x', style: TextStyle(color: Colors.white)),
                      ),
                      PopupMenuItem(
                        value: 2.0,
                        child: Text('2.0x', style: TextStyle(color: Colors.white)),
                      ),
                    ];
                  },
                  child: Text(
                    '${controller.value.playbackSpeed}x',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
              
              // Total duration
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  _formatDuration(controller.value.duration),
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}