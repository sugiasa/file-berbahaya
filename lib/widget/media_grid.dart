// Berikut adalah kode yang perlu diupdate pada file: lib/widget/media_grid.dart

import 'package:blurspace/screen/media_detail_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
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
                  builder:
                      (_) => MediaDetailScreen(
                        initialIndex: index,
                        mediaList: mediaList,
                      ),
                ),
              );
            },
            child: Stack(
              children: [
                // Thumbnail dengan error handling
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: item.thumbnailUrl,
                    fit: BoxFit.cover,
                    placeholder:
                        (context, url) => Container(
                          color: Colors.grey[800],
                          height:
                              index.isEven
                                  ? 200
                                  : 240, // Variasi tinggi untuk tampilan yang dinamis
                          child: const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white54,
                            ),
                          ),
                        ),
                    errorWidget:
                        (context, url, error) => Container(
                          color: Colors.grey[850],
                          height: index.isEven ? 200 : 240,
                          child: const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  color: Colors.red,
                                  size: 32,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Gambar error',
                                  style: TextStyle(color: Colors.white70),
                                ),
                              ],
                            ),
                          ),
                        ),
                  ),
                ),

                // Video indicator
                if (item.type == 'video')
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.play_arrow, color: Colors.white, size: 16),
                          SizedBox(width: 2),
                          Text(
                            'Video',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
