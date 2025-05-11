// ignore_for_file: use_key_in_widget_constructors, prefer_const_constructors_in_immutables, library_private_types_in_public_api, use_build_context_synchronously, unrelated_type_equality_checks

import 'dart:ui';
import 'package:blurspace/utils/colors.dart';
import 'package:blurspace/utils/snackbar_utils.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'media_viewer_page.dart';
import '../providers/cache_manager.dart';

class AlbumDetailPage extends StatefulWidget {
  final String albumId;

  AlbumDetailPage({required this.albumId});

  @override
  _AlbumDetailPageState createState() => _AlbumDetailPageState();
}

class _AlbumDetailPageState extends State<AlbumDetailPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CacheManager _cacheManager = CacheManager();

  bool isLoading = true;
  bool isOffline = false;
  Map<String, dynamic> albumData = {};
  List<Map<String, dynamic>> mediaList = [];
  bool isGridView = true; // Default view is grid

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    // Check connectivity
    final connectivityResult = await Connectivity().checkConnectivity();
    final hasConnection = connectivityResult != ConnectivityResult.none;

    setState(() {
      isOffline = !hasConnection;
    });

    // Try to load cached data first
    await _loadCachedData();

    // Then try to fetch fresh data if online
    if (hasConnection) {
      await fetchAlbumDetails();
    } else {
      setState(() {
        isLoading = false;
      });

      // Show offline notification
      if (mounted && mediaList.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('You are offline. Connect to view this album.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _loadCachedData() async {
    try {
      // Load cached media info for this album
      final cachedMedia = await _cacheManager.getCachedMediaInfo(
        widget.albumId,
      );

      if (cachedMedia != null && cachedMedia.isNotEmpty) {
        // Update download status for each media
        final updatedMedia = await Future.wait(
          cachedMedia.map((media) async {
            final mediaId = media['mediaId'];
            final isDownloaded = await _cacheManager.isMediaCached(mediaId);
            return {
              ...media,
              'isDownloaded': isDownloaded,
              'isDownloading': false,
            };
          }),
        );

        setState(() {
          mediaList = updatedMedia.cast<Map<String, dynamic>>();

          // Set basic album info if we have media
          if (mediaList.isNotEmpty && albumData.isEmpty) {
            albumData = {
              'title': 'Cached Album',
              'description': 'Offline content',
            };
          }

          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading cached data: $e');
    }
  }

  Future<void> fetchAlbumDetails() async {
    setState(() {
      isLoading = true;
    });

    try {
      // Fetch album data
      final DocumentSnapshot albumDoc =
          await _firestore.collection('albums').doc(widget.albumId).get();

      if (!albumDoc.exists) {
        throw Exception('Album not found');
      }

      final Map<String, dynamic> album =
          albumDoc.data() as Map<String, dynamic>;

      // Check if album is locked
      if (album['isLocked'] == true) {
        throw Exception('Album is locked');
      }

      // Fetch all media in the album
      final QuerySnapshot mediaSnapshot =
          await _firestore
              .collection('albums')
              .doc(widget.albumId)
              .collection('media')
              .get();

      final List<Map<String, dynamic>> media = [];

      // Check which media files are already cached
      for (final doc in mediaSnapshot.docs) {
        final String mediaId = doc.id;
        final Map<String, dynamic> mediaData =
            doc.data() as Map<String, dynamic>;

        // Check if the media is cached
        final bool isDownloaded = await _cacheManager.isMediaCached(mediaId);

        media.add({
          ...mediaData,
          'mediaId': mediaId,
          'isDownloaded': isDownloaded,
          'isDownloading': false,
        });
      }

      // Cache the media info for offline access
      await _cacheManager.cacheMediaInfo(widget.albumId, media);

      setState(() {
        albumData = album;
        mediaList = media;
        isLoading = false;
        isOffline = false;
      });
    } catch (e) {
      debugPrint('Error fetching album details: $e');

      // If fetching fails but we have cached media, use that
      if (mediaList.isEmpty) {
        await _loadCachedData();
      }

      setState(() {
        isLoading = false;
        isOffline = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );

      // Navigate back on severe error
      if (mediaList.isEmpty) {
        Future.delayed(Duration(milliseconds: 1500), () {
          Navigator.pop(context);
        });
      }
    }
  }

  // Function to download media
  Future<void> downloadMedia(int index) async {
    final media = mediaList[index];
    final mediaId = media['mediaId'];
    final String mediaUrl = media['mediaUrl'];
    final String mediaType = media['mediaType'];

    // Only allow download for non-premium content
    if (media['isPremium'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Premium content requires subscription'),
          backgroundColor: error,
        ),
      );
      return;
    }

    // Check connectivity
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Cannot download while offline')));
      return;
    }

    // Set downloading state
    setState(() {
      List<Map<String, dynamic>> updatedMediaList = List.from(mediaList);
      updatedMediaList[index] = {
        ...updatedMediaList[index],
        'isDownloading': true,
      };
      mediaList = updatedMediaList;
    });

    try {
      // Download and cache the media
      final filePath = await _cacheManager.downloadAndCacheMedia(
        mediaId,
        mediaUrl,
        mediaType,
      );

      if (filePath == null) {
        throw Exception('Failed to download media');
      }

      // Update state
      setState(() {
        List<Map<String, dynamic>> updatedMediaList = List.from(mediaList);
        updatedMediaList[index] = {
          ...updatedMediaList[index],
          'isDownloaded': true,
          'isDownloading': false,
          'localPath': filePath,
        };
        mediaList = updatedMediaList;
      });

      // Update cached media info
      await _cacheManager.cacheMediaInfo(widget.albumId, mediaList);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Media downloaded for offline use')),
      );
    } catch (e) {
      debugPrint('Error downloading media: $e');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to download media: ${e.toString()}')),
      );

      setState(() {
        List<Map<String, dynamic>> updatedMediaList = List.from(mediaList);
        updatedMediaList[index] = {
          ...updatedMediaList[index],
          'isDownloading': false,
        };
        mediaList = updatedMediaList;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // backgroundColor: Colors.black, // ganti sesuai tema lu
        automaticallyImplyLeading: false, // matiin default back button
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: white,
          ), // ganti icon sesuka lu
          onPressed: () {
            Navigator.of(context).pop(); // atau custom logic lu
          },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isLoading ? 'Loading...' : '${albumData['title']}',
              style: GoogleFonts.roboto(
                fontSize: 24,
                color: white,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Total media: ${mediaList.length}',
              style: GoogleFonts.roboto(
                fontWeight: FontWeight.w500,
                fontSize: 12,
                color: white,
              ),
            ),
          ],
        ),
        actions: [
          if (isOffline)
            IconButton(
              icon: Icon(Icons.cloud_off, color: white),
              tooltip: 'Offline Mode',
              onPressed: null,
            ),
          IconButton(
            icon: Icon(
              isGridView ? Icons.view_agenda_rounded : Icons.grid_view_rounded,
              color: white,
            ),
            onPressed: () {
              setState(() {
                isGridView = !isGridView;
              });
            },
            tooltip: isGridView ? 'Switch to List View' : 'Switch to Grid View',
          ),
        ],
      ),
      body:
          isLoading
              ? Center(child: CircularProgressIndicator())
              : mediaList.isEmpty
              ? _buildEmptyState()
              : Column(
                children: [
                  // Offline banner
                  if (isOffline)
                    Container(
                      padding: EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 16,
                      ),
                      color: Colors.orange.withOpacity(0.1),
                      child: Row(
                        children: [
                          Icon(Icons.cloud_off, size: 16, color: Colors.orange),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Offline mode. Only downloaded content is available.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.orange.shade800,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => _initData(),
                            child: Text(
                              'Retry',
                              style: TextStyle(fontSize: 12),
                            ),
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              minimumSize: Size(0, 0),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Media content
                  Expanded(
                    child: isGridView ? _buildGridView() : _buildListView(),
                  ),
                ],
              ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isOffline ? Icons.cloud_off : Icons.photo_library_outlined,
            size: 64,
            color: Colors.grey,
          ),
          SizedBox(height: 16),
          Text(
            isOffline ? 'No Downloaded Content' : 'No Media Found',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            isOffline
                ? 'Connect to the internet to view this album'
                : 'This album is empty',
            style: TextStyle(color: Colors.grey),
          ),
          SizedBox(height: 24),
          if (isOffline)
            ElevatedButton.icon(
              icon: Icon(Icons.refresh),
              label: Text('Check Connection'),
              onPressed: () => _initData(),
            ),
        ],
      ),
    );
  }

  Widget _buildGridView() {
    return RefreshIndicator(
      onRefresh: () => _initData(),
      child: GridView.builder(
        padding: EdgeInsets.all(8),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 1,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: mediaList.length,
        itemBuilder: (context, index) {
          final media = mediaList[index];
          final bool isPremium = media['isPremium'] ?? false;
          final bool isDownloaded = media['isDownloaded'] ?? false;
          final bool isDownloading = media['isDownloading'] ?? false;

          return GestureDetector(
            onTap: () {
              if (isPremium) {
                ErrorGlobalSnackbar.show(
                  context,
                  message: 'Premium content requires subscription',
                );
              } else if (isDownloaded) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) => MediaViewerPage(
                          albumId: widget.albumId,
                          initialMediaIndex: index,
                          mediaList: mediaList,
                        ),
                  ),
                );
              } else if (!isOffline) {
                // Start download if not premium, not downloaded, and online
                downloadMedia(index);
              } else {
                // Offline and not downloaded
                ErrorGlobalSnackbar.show(
                  context,
                  message: 'Connect to the internet to download content',
                );
              }
            },
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.grey.shade200,
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Thumbnail
                  CachedNetworkImage(
                    imageUrl: media['thumbnailUrl'] ?? '',
                    fit: BoxFit.cover,
                    placeholder:
                        (context, url) =>
                            Center(child: CircularProgressIndicator()),
                    errorWidget:
                        (context, url, error) => Center(
                          child: Icon(
                            media['mediaType'] == 'video'
                                ? Icons.video_file
                                : Icons.image,
                            size: 40,
                            color: white,
                          ),
                        ),
                  ),

                  // Blur effect for premium content
                  if (isPremium)
                    ClipRRect(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          color: black.withAlpha(90),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.lock, color: Colors.white, size: 32),
                                SizedBox(height: 8),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: blue,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Text(
                                    'PREMIUM',
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                  // Offline indicator for non-downloaded content
                  if (isOffline && !isDownloaded && !isPremium)
                    ClipRect(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          color: black.withAlpha(90),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.cloud_off,
                                  color: Colors.white,
                                  size: 32,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Offline',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                  // Download button
                  if (!isPremium && !isDownloaded && !isOffline)
                    GestureDetector(
                      onTap: isDownloading ? null : () => downloadMedia(index),
                      child: ClipRect(
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            width: 200,
                            height: 20,
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: black.withAlpha(40),
                              // shape: BoxShape.circle,
                            ),
                            child:
                                isDownloading
                                    ? SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                    : Icon(
                                      Icons.download_rounded,
                                      color: Colors.white,
                                      size: 30,
                                    ),
                          ),
                        ),
                      ),
                    ),

                  // Downloaded indicator
                  // if (isDownloaded)
                  //   Positioned(
                  //     right: 8,
                  //     top: 8,
                  //     child: Container(
                  //       padding: EdgeInsets.all(8),
                  //       decoration: BoxDecoration(
                  //         color: Colors.green.withOpacity(0.8),
                  //         shape: BoxShape.circle,
                  //       ),
                  //       child: Icon(Icons.check, color: Colors.white, size: 24),
                  //     ),
                  //   ),

                  // Media type and info
                  Positioned(
                    left: 8,
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Icon(
                            media['mediaType'] == 'video'
                                ? Icons.play_circle_outline
                                : Icons.image,
                            color: Colors.white,
                            size: 16,
                          ),
                          Text(
                            '${(media['size'] / (1024 * 1024)).toStringAsFixed(1)} MB',
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ],
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

  Widget _buildListView() {
    return RefreshIndicator(
      onRefresh: () => _initData(),
      child: ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: mediaList.length,
        itemBuilder: (context, index) {
          final media = mediaList[index];
          final bool isPremium = media['isPremium'] ?? false;
          final bool isDownloaded = media['isDownloaded'] ?? false;
          final bool isDownloading = media['isDownloading'] ?? false;

          // Format date if available
          String formattedDate = '';
          if (media['createdAt'] != null) {
            try {
              final DateTime createdAt = DateTime.parse(media['createdAt']);
              formattedDate = DateFormat('dd MMM yyyy').format(createdAt);
            } catch (e) {
              formattedDate = '';
            }
          }

          return GestureDetector(
            onTap: () {
              if (isPremium) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Premium content requires subscription'),
                  ),
                );
              } else if (isDownloaded) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) => MediaViewerPage(
                          albumId: widget.albumId,
                          initialMediaIndex: index,
                          mediaList: mediaList,
                        ),
                  ),
                );
              } else if (!isOffline) {
                // Start download if not premium, not downloaded, and online
                downloadMedia(index);
              } else {
                // Offline and not downloaded
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Connect to the internet to download content',
                    ),
                  ),
                );
              }
            },
            child: Card(
              margin: EdgeInsets.only(bottom: 16),
              elevation: 4,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 200,
                    width: double.infinity,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Thumbnail
                        CachedNetworkImage(
                          imageUrl: media['thumbnailUrl'] ?? '',
                          fit: BoxFit.cover,
                          placeholder:
                              (context, url) =>
                                  Center(child: CircularProgressIndicator()),
                          errorWidget:
                              (context, url, error) => Center(
                                child: Icon(
                                  media['mediaType'] == 'video'
                                      ? Icons.video_file
                                      : Icons.image,
                                  size: 64,
                                  color: Colors.grey,
                                ),
                              ),
                        ),

                        // Blur effect for premium content
                        if (isPremium)
                          ClipRRect(
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                              child: Container(
                                color: Colors.black.withOpacity(0.3),
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.lock,
                                        color: Colors.white,
                                        size: 48,
                                      ),
                                      SizedBox(height: 16),
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.amber.shade700,
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        child: Text(
                                          'PREMIUM ACCESS ONLY',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),

                        // Offline indicator for non-downloaded content
                        if (isOffline && !isDownloaded && !isPremium)
                          Container(
                            color: Colors.black.withOpacity(0.5),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.cloud_off,
                                    color: Colors.white,
                                    size: 48,
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    'OFFLINE',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Connect to download',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                        // Media type indicator
                        if (media['mediaType'] == 'video' &&
                            !isPremium &&
                            (!isOffline || isDownloaded))
                          Center(
                            child: Container(
                              padding: EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.6),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.play_arrow,
                                color: Colors.white,
                                size: 32,
                              ),
                            ),
                          ),

                        // Download button
                        if (!isPremium && !isDownloaded && !isOffline)
                          Positioned(
                            right: 16,
                            top: 16,
                            child: GestureDetector(
                              onTap:
                                  isDownloading
                                      ? null
                                      : () => downloadMedia(index),
                              child: Container(
                                padding: EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.6),
                                  shape: BoxShape.circle,
                                ),
                                child:
                                    isDownloading
                                        ? SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        )
                                        : Icon(
                                          Icons.download,
                                          color: Colors.white,
                                          size: 28,
                                        ),
                              ),
                            ),
                          ),

                        // Downloaded indicator
                        if (isDownloaded)
                          Positioned(
                            right: 16,
                            top: 16,
                            child: Container(
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.8),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    media['name'] ?? 'Untitled',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color:
                                              media['mediaType'] == 'video'
                                                  ? Colors.blue.shade100
                                                  : Colors.green.shade100,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          media['mediaType']?.toUpperCase() ??
                                              'UNKNOWN',
                                          style: TextStyle(
                                            color:
                                                media['mediaType'] == 'video'
                                                    ? Colors.blue.shade800
                                                    : Colors.green.shade800,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      if (formattedDate.isNotEmpty) ...[
                                        SizedBox(width: 8),
                                        Text(
                                          formattedDate,
                                          style: TextStyle(
                                            color: Colors.grey,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${(media['size'] / (1024 * 1024)).toStringAsFixed(2)} MB',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Row(
                                  children: [
                                    if (isPremium)
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.amber.shade100,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.star,
                                              size: 12,
                                              color: Colors.amber.shade800,
                                            ),
                                            SizedBox(width: 4),
                                            Text(
                                              'PREMIUM',
                                              style: TextStyle(
                                                color: Colors.amber.shade800,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    if (isDownloaded)
                                      Container(
                                        margin: EdgeInsets.only(
                                          left: isPremium ? 8 : 0,
                                        ),
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.green.shade100,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.download_done,
                                              size: 12,
                                              color: Colors.green.shade800,
                                            ),
                                            SizedBox(width: 4),
                                            Text(
                                              'SAVED',
                                              style: TextStyle(
                                                color: Colors.green.shade800,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),

                        // Additional actions
                        if (!isPremium)
                          Padding(
                            padding: const EdgeInsets.only(top: 12.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (isDownloaded)
                                  OutlinedButton.icon(
                                    icon: Icon(Icons.visibility),
                                    label: Text('View'),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder:
                                              (context) => MediaViewerPage(
                                                albumId: widget.albumId,
                                                initialMediaIndex: index,
                                                mediaList: mediaList,
                                              ),
                                        ),
                                      );
                                    },
                                  )
                                else if (!isOffline)
                                  OutlinedButton.icon(
                                    icon:
                                        isDownloading
                                            ? SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                            : Icon(Icons.download),
                                    label: Text(
                                      isDownloading
                                          ? 'Downloading...'
                                          : 'Download',
                                    ),
                                    onPressed:
                                        isDownloading
                                            ? null
                                            : () => downloadMedia(index),
                                  ),
                              ],
                            ),
                          ),
                      ],
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
