import 'package:flutter/material.dart';
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
              margin: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                border: Border.all(
                  color: selectedIndex == index ? Colors.blue : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Image.network(item.thumbnailUrl),
            ),
          );
        },
      ),
    );
  }
}
