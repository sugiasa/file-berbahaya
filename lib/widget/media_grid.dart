import 'package:blurspace/screen/media_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../models/media_item.dart';

class MediaGrid extends StatelessWidget {
  final List<MediaItem> mediaList;

  const MediaGrid({super.key, required this.mediaList});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: MasonryGridView.count(
        crossAxisCount: 2,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
        itemCount: mediaList.length,
        itemBuilder: (context, index) {
          final item = mediaList[index];
          return GestureDetector(
            onTap: () {
              // Navigasi ke preview
              Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MediaDetailScreen(
                  initialIndex: index,
                  mediaList: mediaList,
                ),
              ),
            );
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                item.thumbnailUrl,
                fit: BoxFit.cover,
              ),
            ),
          );
        },
      ),
    );
  }
}
