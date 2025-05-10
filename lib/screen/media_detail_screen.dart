// Berikut adalah kode yang perlu diupdate pada file: lib/screen/media_detail_screen.dart

import 'package:blurspace/providers/media_detail_provider.dart';
import 'package:blurspace/providers/video_player_provider.dart';
import 'package:blurspace/utils/colors.dart';
import 'package:blurspace/widget/custom_video_player.dart'; // Import widget baru
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

class _MediaDetailScreenState extends ConsumerState<MediaDetailScreen> {
  @override
void initState() {
  super.initState();

  WidgetsBinding.instance.addPostFrameCallback((_) {
    // Set index provider
    ref.read(currentMediaIndexProvider.notifier).state = widget.initialIndex;

    // Set media list
    ref.read(updateMediaListProvider.notifier).state = widget.mediaList;

    // Force page controller ke index yg benar
    ref.read(pageControllerProvider).jumpToPage(widget.initialIndex);

    // Load media (trigger player, dll)
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
                  // Pakai Custom Video Player baru
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
                pageController.jumpToPage(index);
              },
            ),
          ),
          SizedBox(height: 40),
        ],
      ),
    );
  }
}
