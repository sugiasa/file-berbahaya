class MediaItem {
  final String id;
  final String type; // 'image' atau 'video'
  final String thumbnailUrl;
  final String fileUrl;

  MediaItem({
    required this.id,
    required this.type,
    required this.thumbnailUrl,
    required this.fileUrl,
  });
}
