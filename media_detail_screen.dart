import 'package:blurspace/providers/media_detail_provider.dart';
import 'package:blurspace/providers/video_player_provider.dart' as video;
import 'package:blurspace/widget/custom_video_player.dart';
import 'package:blurspace/widget/image_viewer_widget.dart';
import 'package:blurspace/widget/media_thumbnail_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/media_item.dart';

class MediaDetailScreen extends ConsumerStatefulWidget {
  final int initialIndex;
  final List<MediaItem> mediaList;

  const MediaDetailScreen({
    super.key,
    required this.initialIndex,
    required this.mediaList,
  });

  @override
  ConsumerState<MediaDetailScreen> createState() => _MediaDetailScreenState();
}

class _MediaDetailScreenState extends ConsumerState<MediaDetailScreen>
    with WidgetsBindingObserver {
  late PageController _pageController;
  bool _isDisposed = false;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    // Set initial index
    _currentIndex = widget.initialIndex;

    // Initialize page controller with the initial index
    _pageController = PageController(initialPage: widget.initialIndex);

    // Add observer for lifecycle
    WidgetsBinding.instance.addObserver(this);

    // Initialize providers safely
    _initializeProviders();
  }

  void _initializeProviders() {
    // Safely set the initial values
    try {
      // Update providers safely
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _isDisposed) return;

        // Set initial values in providers
        ref.read(currentMediaIndexProvider.notifier).state =
            widget.initialIndex;
        ref.read(updateMediaListProvider.notifier).state = List.from(
          widget.mediaList,
        );

        // Load initial media
        final mediaHandler = ref.read(mediaChangeHandlerProvider);
        mediaHandler.onPageChanged(widget.initialIndex);
      });
    } catch (e) {
      debugPrint('Error initializing providers: $e');
    }
  }

  @override
  void dispose() {
    // Mark as disposed first
    _isDisposed = true;

    // Remove observer
    WidgetsBinding.instance.removeObserver(this);

    // Clean up resources
    _safelyDisposeVideoControllers();

    // Dispose page controller
    _pageController.dispose();

    super.dispose();
  }

  void _safelyDisposeVideoControllers() {
    try {
      if (!_isDisposed && mounted) {
        final videoPlayerNotifier = ref.read(
          video.videoPlayerStateProvider.notifier,
        );
        videoPlayerNotifier.disposeControllers();
      }
    } catch (e) {
      debugPrint('Error safely disposing video controllers: $e');
    }
  }

  // Handle app lifecycle changes
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_isDisposed || !mounted) return;

    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _safelyDisposeVideoControllers();
    }
  }

  void _onPageChanged(int index) {
    if (_isDisposed || !mounted) return;

    setState(() {
      _currentIndex = index;
    });

    try {
      // Only access provider if widget is still mounted
      if (mounted) {
        ref.read(mediaChangeHandlerProvider).onPageChanged(index);
      }
    } catch (e) {
      debugPrint('Error in _onPageChanged: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use local state rather than provider state for UI
    final currentIndex = _currentIndex;

    return PopScope(
      onPopInvokedWithResult: (v, a) async {
        _safelyDisposeVideoControllers();
      },
      child: Scaffold(
        backgroundColor: Colors.black,

        body: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: widget.mediaList.length,
                onPageChanged: _onPageChanged,
                itemBuilder: (context, index) {
                  final media = widget.mediaList[index];

                  if (media.type == 'image') {
                    return ImageViewerWidget(imageUrl: media.fileUrl);
                  } else if (media.type == 'video') {
                    return CustomVideoPlayerWidget(
                      mediaItem: media,
                      index: index,
                    );
                  } else {
                    return const Center(
                      child: Text(
                        'Format media tidak didukung',
                        style: TextStyle(color: Colors.white),
                      ),
                    );
                  }
                },
              ),
            ),
            Container(
              height: 70,
              color: Colors.transparent,
              child: MediaThumbnailList(
                mediaList: widget.mediaList,
                selectedIndex: currentIndex,
                onTap: (index) {
                  if (!_isDisposed && mounted) {
                    _pageController.jumpToPage(index);
                  }
                },
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
