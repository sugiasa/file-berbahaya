import 'package:blurspace/providers/media_detail_provider.dart';
import 'package:blurspace/providers/video_player_provider.dart';
import 'package:blurspace/widget/image_viewer_widget.dart';
import 'package:blurspace/widget/media_thumbnail_list.dart';
import 'package:blurspace/widget/video_player_widget.dart';
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

class _MediaDetailScreenState extends ConsumerState<MediaDetailScreen> {
  @override
  void initState() {
    super.initState();
    
    // Initialize providers after widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Set initial index
      ref.read(currentMediaIndexProvider.notifier).state = widget.initialIndex;
      
      // Set media list to provider
      ref.read(updateMediaListProvider.notifier).state = widget.mediaList;
      
      // Load initial media
      ref.read(mediaChangeHandlerProvider).onPageChanged(widget.initialIndex);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Watch current index
    final currentIndex = ref.watch(currentMediaIndexProvider);
    
    // Watch page controller
    final pageController = ref.watch(pageControllerProvider);
    
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
              controller: pageController,
              itemCount: widget.mediaList.length,
              onPageChanged: (index) {
                ref.read(mediaChangeHandlerProvider).onPageChanged(index);
              },
              itemBuilder: (context, index) {
                final media = widget.mediaList[index];

                if (media.type == 'image') {
                  return ImageViewerWidget(imageUrl: media.fileUrl);
                } else if (media.type == 'video') {
                  return VideoPlayerWidget(index: index);
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
                pageController.jumpToPage(index);
              },
            ),
          ),
        ],
      ),
    );
  }


}