import 'dart:ui';
import 'package:blurspace/models/album_model.dart';
import 'package:blurspace/providers/album_provider.dart';
import 'package:blurspace/providers/cache_provider.dart';
import 'package:blurspace/providers/connectivity_provider.dart';
import 'package:blurspace/utils/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'album_detail_page.dart';

class AlbumListPage extends ConsumerWidget {
  const AlbumListPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final albumsAsync = ref.watch(albumsNotifierProvider);
    final isOffline = ref.watch(isOfflineProvider);
    final lastSyncTime = ref.watch(lastSyncTimeProvider);

    return SafeArea(
      child: Scaffold(
        body: albumsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => _buildErrorState(context, error, ref),
          data: (albums) {
            if (albums.isEmpty) {
              return _buildEmptyState(context, isOffline, ref);
            }
            return _buildAlbumList(context, albums, isOffline, lastSyncTime, ref);
          },
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, Object error, WidgetRef ref) {
    // Show error state and retry button
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            'Error loading albums',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error.toString(),
            style: GoogleFonts.poppins(color: Colors.grey),
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            onPressed: () => ref.refresh(albumsNotifierProvider),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isOffline, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isOffline ? Icons.cloud_off : Icons.photo_album_outlined,
            size: 64,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            isOffline ? 'No Cached Albums' : 'No Albums Found',
            style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            isOffline
                ? 'Connect to the internet to download albums'
                : 'Upload some content from TeraBox',
            style: GoogleFonts.poppins(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          if (!isOffline)
            ElevatedButton.icon(
              icon: const Icon(Icons.cloud_upload),
              label: const Text('Upload Content'),
              onPressed: () {
                // Navigate to TeraBox uploader
                Navigator.pushNamed(context, '/uploader');
              },
            ),
          if (isOffline)
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Check Connection'),
              onPressed: () => ref.read(connectivityStatusProvider.notifier).checkConnectivity(),
            ),
        ],
      ),
    );
  }

  Widget _buildAlbumList(
    BuildContext context,
    List<Album> albums,
    bool isOffline,
    AsyncValue<DateTime?> lastSyncTime,
    WidgetRef ref,
  ) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
          child: SizedBox(
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Media Indonesia',
                  style: GoogleFonts.poppins(
                    color: white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                lastSyncTime.when(
                  loading: () => const SizedBox(),
                  error: (_, __) => const SizedBox(),
                  data: (syncTime) {
                    if (syncTime == null) return const SizedBox();
                    return Row(
                      children: [
                        Icon(
                          isOffline ? Icons.cloud_off : Icons.sync,
                          size: 16,
                          color: white,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            isOffline
                                ? 'Offline mode. Last synced: ${DateFormat('MMM d, y h:mm a').format(syncTime)}'
                                : 'Last synced: ${DateFormat('MMM d, y h:mm a').format(syncTime)}',
                            style: TextStyle(fontSize: 12, color: white),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),

        // Album list
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => ref.read(albumsNotifierProvider.notifier).refreshAlbums(),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: albums.length,
              itemBuilder: (context, index) {
                final album = albums[index];
                final mediaList = album.media;
                
                // Format date
                final String formattedDate = DateFormat('EEEE, dd MMMM yyyy').format(album.createdAt);

                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AlbumDetailPage(albumId: album.albumId),
                      ),
                    ).then((_) {
                      // Refresh albums when returning from detail page
                      ref.read(albumsNotifierProvider.notifier).refreshAlbums();
                    });
                  },
                  child: Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    elevation: 4,
                    shadowColor: white.withAlpha(10),
                    clipBehavior: Clip.antiAlias,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      album.title,
                                      style: GoogleFonts.lato(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      formattedDate,
                                      style: GoogleFonts.lato(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Status labels
                              Row(
                                children: [
                                  if (album.hasPremiumMedia)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      margin: const EdgeInsets.only(right: 8),
                                      decoration: BoxDecoration(
                                        color: blue,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.star,
                                            color: white,
                                            size: 16,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Pro',
                                            style: GoogleFonts.poppins(
                                              color: white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (mediaList.isNotEmpty)
                          SizedBox(
                            height: 120,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: mediaList.length,
                              itemBuilder: (context, mediaIndex) {
                                final media = mediaList[mediaIndex];
                                
                                return Container(
                                  width: 160,
                                  margin: EdgeInsets.only(
                                    left: mediaIndex == 0 ? 16 : 8,
                                    right: mediaIndex == mediaList.length - 1 ? 16 : 0,
                                    bottom: 16,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    color: blue,
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      // Thumbnail image
                                      CachedNetworkImage(
                                        imageUrl: media.thumbnailUrl,
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) => const Center(
                                          child: CircularProgressIndicator(),
                                        ),
                                        errorWidget: (context, url, error) => Center(
                                          child: Icon(
                                            media.mediaType == 'video'
                                                ? Icons.video_file
                                                : Icons.image,
                                            size: 40,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ),

                                      // Blur effect for premium content
                                      if (media.isPremium)
                                        ClipRRect(
                                          child: BackdropFilter(
                                            filter: ImageFilter.blur(
                                              sigmaX: 10,
                                              sigmaY: 10,
                                            ),
                                            child: const Center(
                                              child: Icon(
                                                Icons.lock_outline_rounded,
                                                color: Colors.white,
                                                size: 30,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}