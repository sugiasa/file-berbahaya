import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'album_detail_page.dart'; // Pastikan file ini ada

class AlbumListPage extends StatefulWidget {
  @override
  _AlbumListPageState createState() => _AlbumListPageState();
}

class _AlbumListPageState extends State<AlbumListPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool isLoading = true;
  List<Map<String, dynamic>> albums = [];
  Map<String, List<Map<String, dynamic>>> albumMedia = {};

  @override
  void initState() {
    super.initState();
    fetchAlbums();
  }

  Future<void> fetchAlbums() async {
    setState(() {
      isLoading = true;
    });

    try {
      // Fetch all albums
      final QuerySnapshot albumSnapshot = await _firestore
          .collection('albums')
          .orderBy('createdAt', descending: true)
          .get();

      final List<Map<String, dynamic>> fetchedAlbums = [];
      final Map<String, List<Map<String, dynamic>>> fetchedAlbumMedia = {};

      // Process each album
      for (final doc in albumSnapshot.docs) {
        final albumData = doc.data() as Map<String, dynamic>;
        final String albumId = doc.id;

        // Only include unlocked albums
        if (!(albumData['isLocked'] ?? false)) {
          fetchedAlbums.add({
            ...albumData,
            'albumId': albumId,
          });

          // Fetch a preview of media (maximum 5)
          final QuerySnapshot mediaSnapshot = await _firestore
              .collection('albums')
              .doc(albumId)
              .collection('media')
              .limit(5)
              .get();

          final List<Map<String, dynamic>> mediaList = [];
          bool hasPremiumMedia = false;

          for (final mediaDoc in mediaSnapshot.docs) {
            final mediaData = mediaDoc.data() as Map<String, dynamic>;
            mediaList.add(mediaData);
            
            // Check if any media is premium
            if (mediaData['isPremium'] == true) {
              hasPremiumMedia = true;
            }
          }

          // Add hasPremiumMedia flag to album data
          final int albumIndex = fetchedAlbums.length - 1;
          fetchedAlbums[albumIndex]['hasPremiumMedia'] = hasPremiumMedia;
          
          // Store media for this album
          fetchedAlbumMedia[albumId] = mediaList;
        }
      }

      setState(() {
        albums = fetchedAlbums;
        albumMedia = fetchedAlbumMedia;
        isLoading = false;
      });
    } catch (e) {
      print('Error fetching albums: $e');
      setState(() {
        isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Albums'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: fetchAlbums,
          ),
          IconButton(
            icon: Icon(Icons.cloud_upload),
            onPressed: () {
              // Navigate to TeraBox uploader
              Navigator.pushNamed(context, '/uploader');
            },
          ),
        ],
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : albums.isEmpty
              ? _buildEmptyState()
              : _buildAlbumList(),
    );
  }
  
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.photo_album_outlined, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'No Albums Found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Upload some content from TeraBox',
            style: TextStyle(color: Colors.grey),
          ),
          SizedBox(height: 24),
          ElevatedButton.icon(
            icon: Icon(Icons.cloud_upload),
            label: Text('Upload Content'),
            onPressed: () {
              // Navigate to TeraBox uploader
              Navigator.pushNamed(context, '/uploader');
            },
          ),
        ],
      ),
    );
  }
  
  Widget _buildAlbumList() {
    return RefreshIndicator(
      onRefresh: fetchAlbums,
      child: ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: albums.length,
        itemBuilder: (context, index) {
          final album = albums[index];
          final albumId = album['albumId'];
          final media = albumMedia[albumId] ?? [];
          final bool hasPremiumMedia = album['hasPremiumMedia'] ?? false;
          
          // Format date
          final DateTime createdAt = DateTime.parse(album['createdAt']);
          final String formattedDate = DateFormat('dd MMM yyyy').format(createdAt);
          
          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AlbumDetailPage(albumId: albumId),
                ),
              ).then((_) {
                // Refresh albums when returning from detail page
                fetchAlbums();
              });
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
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                album['title'] ?? 'Untitled Album',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(height: 4),
                              Text(
                                formattedDate,
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (hasPremiumMedia)
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade200,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.star,
                                  color: Colors.amber.shade800,
                                  size: 16,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Premium',
                                  style: TextStyle(
                                    color: Colors.amber.shade800,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (media.isNotEmpty)
                    Container(
                      height: 120,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: media.length,
                        itemBuilder: (context, mediaIndex) {
                          final mediaItem = media[mediaIndex];
                          final bool isPremium = mediaItem['isPremium'] ?? false;
                          
                          return Container(
                            width: 160,
                            margin: EdgeInsets.only(
                              left: mediaIndex == 0 ? 16 : 8,
                              right: mediaIndex == media.length - 1 ? 16 : 0,
                              bottom: 16,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.grey.shade200,
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                // Thumbnail image
                                CachedNetworkImage(
                                  imageUrl: mediaItem['thumbnailUrl'] ?? '',
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                  errorWidget: (context, url, error) => Center(
                                    child: Icon(
                                      mediaItem['mediaType'] == 'video'
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
                                          child: Icon(
                                            Icons.lock,
                                            color: Colors.white,
                                            size: 32,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  
                                // Media type indicator
                                Positioned(
                                  right: 8,
                                  bottom: 8,
                                  child: Container(
                                    padding: EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.6),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Icon(
                                      mediaItem['mediaType'] == 'video'
                                          ? Icons.play_arrow
                                          : Icons.image,
                                      color: Colors.white,
                                      size: 16,
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
    );
  }
}