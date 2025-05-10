// Berikut adalah kode yang perlu diupdate pada file: lib/widget/media_thumbnail_list.dart

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/media_item.dart';

class MediaThumbnailList extends StatelessWidget {
  final List<MediaItem> mediaList;
  final int selectedIndex;
  final Function(int) onTap;

  const MediaThumbnailList({
    super.key,
    required this.mediaList,
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 90,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: mediaList.length,
        itemBuilder: (context, index) {
          final item = mediaList[index];
          return GestureDetector(
            onTap: () => onTap(index),
            child: Container(
              width: 80,
              margin: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                border: Border.all(
                  color: selectedIndex == index ? Colors.blue : Colors.transparent,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Thumbnail image with error handling
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: CachedNetworkImage(
                      imageUrl: item.thumbnailUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: Colors.grey[900],
                        child: const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white54,
                            ),
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey[800],
                        child: const Icon(
                          Icons.error_outline,
                          color: Colors.white54,
                        ),
                      ),
                    ),
                  ),
                  
                  // Video indicator
                  if (item.type == 'video')
                    Positioned(
                      right: 4,
                      bottom: 4,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(
                          Icons.play_arrow,
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}