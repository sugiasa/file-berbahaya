import 'package:blurspace/utils/video_cache.dart';
import 'package:blurspace/widget/media_thumbnail_list.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:chewie/chewie.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../models/media_item.dart';

class MediaDetailScreen extends StatefulWidget {
  final int initialIndex;
  final List<MediaItem> mediaList;

  const MediaDetailScreen({
    super.key,
    required this.initialIndex,
    required this.mediaList,
  });

  @override
  State<MediaDetailScreen> createState() => _MediaDetailScreenState();
}

class _MediaDetailScreenState extends State<MediaDetailScreen> {
  late PageController _pageController;
  late int currentIndex;
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _isVideoLoading = false;

  // Cache manager untuk video
  final Map<String, String> _videoCache = {};

  @override
  void initState() {
    super.initState();
    currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: currentIndex);

    // Load media setelah widget selesai build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMedia(currentIndex);
    });
  }

  // Generate hash key dari URL untuk nama file cache
  String _generateCacheKey(String url) {
    var bytes = utf8.encode(url);
    var digest = md5.convert(bytes);
    return digest.toString();
  }

  // Periksa dan download video ke cache jika belum ada
  // Future<String> _getVideoCachePath(String url) async {
  //   final cacheKey = _generateCacheKey(url);

  //   // Jika sudah ada di memory cache, gunakan itu
  //   if (_videoCache.containsKey(cacheKey)) {
  //     final cachedPath = _videoCache[cacheKey];
  //     if (cachedPath != null && File(cachedPath).existsSync()) {
  //       debugPrint('Using memory cached video: $cachedPath');
  //       return cachedPath;
  //     }
  //   }

  //   // Dapatkan directory cache
  //   final cacheDir = await getTemporaryDirectory();
  //   final videoFile = File('${cacheDir.path}/video_cache/$cacheKey.mp4');

  //   // Buat directory jika belum ada
  //   if (!await videoFile.parent.exists()) {
  //     await videoFile.parent.create(recursive: true);
  //   }

  //   // Jika file sudah ada di cache disk, gunakan itu
  //   if (await videoFile.exists()) {
  //     debugPrint('Using disk cached video: ${videoFile.path}');
  //     _videoCache[cacheKey] = videoFile.path;
  //     return videoFile.path;
  //   }

  //   try {
  //     // Download file video
  //     debugPrint('Downloading video to cache: $url');
  //     final httpClient = HttpClient();
  //     final request = await httpClient.getUrl(Uri.parse(url));
  //     final response = await request.close();

  //     if (response.statusCode == 200) {
  //       final bytes = await consolidateHttpClientResponseBytes(response);
  //       await videoFile.writeAsBytes(bytes);
  //       _videoCache[cacheKey] = videoFile.path;
  //       debugPrint('Video cached successfully: ${videoFile.path}');
  //       return videoFile.path;
  //     } else {
  //       debugPrint('Error downloading video: ${response.statusCode}');
  //       return url; // Fallback to original URL
  //     }
  //   } catch (e) {
  //     debugPrint('Error caching video: $e');
  //     return url; // Fallback to original URL
  //   }
  // }

  Future<void> _loadMedia(int index) async {
    if (index < 0 || index >= widget.mediaList.length) return;

    final item = widget.mediaList[index];

    // Bersihkan controllers sebelumnya
    _disposeControllers();

    if (item.type == 'video') {
      setState(() {
        _isVideoLoading = true;
      });

      try {
        // Dapatkan path cache untuk video
        final videoPath = await VideoCacheManager().getVideoCachePath(
          item.fileUrl,
        );

        // Inisialisasi video controller berdasarkan sumber (cache atau network)
        if (videoPath.startsWith('http')) {
          // Jika fallback ke URL asli, gunakan network controller
          _videoController = VideoPlayerController.networkUrl(
            Uri.parse(videoPath),
          );
        } else {
          // Jika menggunakan cache file
          _videoController = VideoPlayerController.file(File(videoPath));
        }

        // Tunggu inisialisasi selesai
        await _videoController!.initialize();

        // Buat chewie controller dengan style Telegram-like
        _chewieController = ChewieController(
          videoPlayerController: _videoController!,
          autoPlay: true,
          looping: true, // Set looping ke true
          aspectRatio: _videoController!.value.aspectRatio,
          allowFullScreen: true,
          allowMuting: true,
          showControls: true,
          showControlsOnInitialize: false,
          hideControlsTimer: const Duration(seconds: 1 ),
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

        if (mounted) {
          setState(() {
            _isVideoLoading = false;
          });
        }
      } catch (e) {
        debugPrint('Error loading video: $e');
        if (mounted) {
          setState(() {
            _isVideoLoading = false;
          });
        }
      }
    }
  }

  void _disposeControllers() {
    _chewieController?.dispose();
    _chewieController = null;
    _videoController?.dispose();
    _videoController = null;
  }

  @override
  void dispose() {
    _pageController.dispose();
    _disposeControllers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.mediaList.length,
              onPageChanged: (index) {
                setState(() {
                  currentIndex = index;
                });
                _loadMedia(index);
              },
              itemBuilder: (context, index) {
                final media = widget.mediaList[index];

                if (media.type == 'image') {
                  return _buildImageViewer(media.fileUrl);
                } else if (media.type == 'video') {
                  return _buildVideoPlayer(index);
                } else {
                  return const Center(
                    child: Text(
                      'Unsupported media type',
                      style: TextStyle(color: Colors.white),
                    ),
                  );
                }
              },
            ),
          ),
          Container(
            height: 100,
            color: Colors.black87,
            child: MediaThumbnailList(
              mediaList: widget.mediaList,
              selectedIndex: currentIndex,
              onTap: (index) {
                _pageController.jumpToPage(index);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageViewer(String url) {
    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 3.0,
      child: Center(
        child: CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.contain,
          placeholder:
              (context, url) => const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
          errorWidget:
              (context, url, error) => const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, color: Colors.red, size: 48),
                    SizedBox(height: 8),
                    Text(
                      'Image could not be loaded',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
        ),
      ),
    );
  }

  Widget _buildVideoPlayer(int index) {
    // Jika masih loading atau controller tidak tersedia
    if (_isVideoLoading ||
        _chewieController == null ||
        _videoController == null ||
        !_videoController!.value.isInitialized ||
        currentIndex != index) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    // Gunakan Chewie untuk tampilan video player dengan UI style Telegram
    return Stack(
      children: [
        // Video player utama dengan ukuran penuh
        Center(
          child: AspectRatio(
            aspectRatio: _videoController!.value.aspectRatio,
            child: Chewie(controller: _chewieController!),
          ),
        ),

        // Double tap zones untuk rewind/forward (seperti Telegram)
        Positioned.fill(
          child: Row(
            children: [
              // Left zone (rewind)
              Expanded(
                child: GestureDetector(
                  onDoubleTap: () {
                    final newPosition =
                        _videoController!.value.position -
                        const Duration(seconds: 10);
                    _videoController!.seekTo(newPosition);
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Container(color: Colors.transparent),
                ),
              ),

              // Middle zone (play/pause)
              const SizedBox(width: 60),

              // Right zone (forward)
              Expanded(
                child: GestureDetector(
                  onDoubleTap: () {
                    final newPosition =
                        _videoController!.value.position +
                        const Duration(seconds: 10);
                    _videoController!.seekTo(newPosition);
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Container(color: Colors.transparent),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
