import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'media_viewer_page.dart'; // Pastikan file ini ada

class AlbumDetailPage extends StatefulWidget {
  final String albumId;

  AlbumDetailPage({required this.albumId});

  @override
  _AlbumDetailPageState createState() => _AlbumDetailPageState();
}

class _AlbumDetailPageState extends State<AlbumDetailPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool isLoading = true;
  Map<String, dynamic> albumData = {};
  List<Map<String, dynamic>> mediaList = [];
  bool isGridView = true; // Default view is grid
  
  // Cache for downloaded media
  Map<String, dynamic> cachedMedia = {};

  @override
  void initState() {
    super.initState();
    fetchAlbumDetails();
  }

  Future<void> fetchAlbumDetails() async {
    setState(() {
      isLoading = true;
    });

    try {
      // Fetch album data
      final DocumentSnapshot albumDoc = await _firestore
          .collection('albums')
          .doc(widget.albumId)
          .get();

      if (!albumDoc.exists) {
        throw Exception('Album not found');
      }

      final Map<String, dynamic> album = albumDoc.data() as Map<String, dynamic>;
      
      // Check if album is locked
      if (album['isLocked'] == true) {
        throw Exception('Album is locked');
      }

      // Fetch all media in the album
      final QuerySnapshot mediaSnapshot = await _firestore
          .collection('albums')
          .doc(widget.albumId)
          .collection('media')
          .get();

      final List<Map<String, dynamic>> media = [];
      
      for (final doc in mediaSnapshot.docs) {
        final Map<String, dynamic> mediaData = doc.data() as Map<String, dynamic>;
        media.add({
          ...mediaData,
          'mediaId': doc.id,
          'isDownloaded': false, // Initially not downloaded
        });
      }

      setState(() {
        albumData = album;
        mediaList = media;
        isLoading = false;
      });
    } catch (e) {
      print('Error fetching album details: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
      setState(() {
        isLoading = false;
      });
      
      // Navigate back on error
      Future.delayed(Duration(milliseconds: 1500), () {
        Navigator.pop(context);
      });
    }
  }

  // Function to cache media (simulated download)
  Future<void> downloadMedia(int index) async {
    final media = mediaList[index];
    final mediaId = media['mediaId'];
    
    // Only allow download for non-premium content
    if (media['isPremium'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Premium content requires subscription')),
      );
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
      // Simulate network delay for downloading
      await Future.delayed(Duration(seconds: 1));
      
      // Cache the media URL
      cachedMedia[mediaId] = {
        'mediaUrl': media['mediaUrl'],
        'mediaType': media['mediaType'],
        'name': media['name'],
      };
      
      // Update state
      setState(() {
        List<Map<String, dynamic>> updatedMediaList = List.from(mediaList);
        updatedMediaList[index] = {
          ...updatedMediaList[index],
          'isDownloaded': true,
          'isDownloading': false,
        };
        mediaList = updatedMediaList;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Media cached successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to cache media: $e')),
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
        title: Text(isLoading ? 'Loading...' : albumData['title'] ?? 'Album'),
        actions: [
          IconButton(
            icon: Icon(isGridView ? Icons.view_list : Icons.grid_view),
            onPressed: () {
              setState(() {
                isGridView = !isGridView;
              });
            },
            tooltip: isGridView ? 'Switch to List View' : 'Switch to Grid View',
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: fetchAlbumDetails,
          ),
        ],
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : mediaList.isEmpty
              ? _buildEmptyState()
              : isGridView
                  ? _buildGridView()
                  : _buildListView(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.photo_library_outlined, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'No Media Found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'This album is empty',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildGridView() {
    return RefreshIndicator(
      onRefresh: fetchAlbumDetails,
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
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Premium content requires subscription')),
                );
              } else if (isDownloaded) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MediaViewerPage(
                      albumId: widget.albumId,
                      initialMediaIndex: index,
                      mediaList: mediaList,
                      cachedMedia: cachedMedia,
                    ),
                  ),
                );
              } else {
                // Start download if not premium and not downloaded
                downloadMedia(index);
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
                    placeholder: (context, url) => Center(
                      child: CircularProgressIndicator(),
                    ),
                    errorWidget: (context, url, error) => Center(
                      child: Icon(
                        media['mediaType'] == 'video'
                            ? Icons.video_file
                            : Icons.image,
                        size: 40,
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
                                  size: 32,
                                ),
                                SizedBox(height: 8),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.shade700,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Text(
                                    'PREMIUM',
                                    style: TextStyle(
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
                  
                  // Download button
                  if (!isPremium && !isDownloaded)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: GestureDetector(
                        onTap: isDownloading ? null : () => downloadMedia(index),
                        child: Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            shape: BoxShape.circle,
                          ),
                          child: isDownloading
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
                                  size: 24,
                                ),
                        ),
                      ),
                    ),
                  
                  // Downloaded indicator
                  if (isDownloaded)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.8),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  
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
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
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
      onRefresh: fetchAlbumDetails,
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
                  SnackBar(content: Text('Premium content requires subscription')),
                );
              } else if (isDownloaded) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MediaViewerPage(
                      albumId: widget.albumId,
                      initialMediaIndex: index,
                      mediaList: mediaList,
                      cachedMedia: cachedMedia,
                    ),
                  ),
                );
              } else {
                // Start download if not premium and not downloaded
                downloadMedia(index);
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
                          placeholder: (context, url) => Center(
                            child: CircularProgressIndicator(),
                          ),
                          errorWidget: (context, url, error) => Center(
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
                                          borderRadius: BorderRadius.circular(20),
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
                        
                        // Media type indicator
                        if (media['mediaType'] == 'video' && !isPremium)
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
                        if (!isPremium && !isDownloaded)
                          Positioned(
                            right: 16,
                            top: 16,
                            child: GestureDetector(
                              onTap: isDownloading ? null : () => downloadMedia(index),
                              child: Container(
                                padding: EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.6),
                                  shape: BoxShape.circle,
                                ),
                                child: isDownloading
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
                                          color: media['mediaType'] == 'video'
                                              ? Colors.blue.shade100
                                              : Colors.green.shade100,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          media['mediaType']?.toUpperCase() ?? 'UNKNOWN',
                                          style: TextStyle(
                                            color: media['mediaType'] == 'video'
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
                                if (isPremium)
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.shade100,
                                      borderRadius: BorderRadius.circular(4),
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
                                          builder: (context) => MediaViewerPage(
                                            albumId: widget.albumId,
                                            initialMediaIndex: index,
                                            mediaList: mediaList,
                                            cachedMedia: cachedMedia,
                                          ),
                                        ),
                                      );
                                    },
                                  )
                                else
                                  OutlinedButton.icon(
                                    icon: isDownloading
                                        ? SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : Icon(Icons.download),
                                    label: Text(isDownloading ? 'Downloading...' : 'Download'),
                                    onPressed: isDownloading ? null : () => downloadMedia(index),
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