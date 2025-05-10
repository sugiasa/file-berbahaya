import 'package:blurspace/models/media_item.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final mediaListProvider = Provider<List<MediaItem>>((ref) {
  return [
    MediaItem(
      id: '1',
      type: 'image',
      thumbnailUrl:
          'https://res.cloudinary.com/tmart/image/upload/v1675231206/yoenui29nqgbxuqnjto1.jpg',
      fileUrl:
          'https://res.cloudinary.com/tmart/image/upload/v1675231206/yoenui29nqgbxuqnjto1.jpg',
    ),
    MediaItem(
      id: '2',
      type: 'video',
      thumbnailUrl:
          'https://res.cloudinary.com/tmart/video/upload/v1712135091/zut3bzpgmjyrc9bdgo3v.jpg',
      fileUrl:
          'https://res.cloudinary.com/tmart/video/upload/v1712135091/zut3bzpgmjyrc9bdgo3v.mp4',
    ),
    MediaItem(
      id: '3',
      type: 'image',
      thumbnailUrl:
          'https://res.cloudinary.com/tmart/image/upload/v1677474277/fobguun3he2mwesxmtos.jpg',
      fileUrl:
          'https://res.cloudinary.com/tmart/image/upload/v1677474277/fobguun3he2mwesxmtos.jpg',
    ),
    MediaItem(
      id: '4',
      type: 'video',
      thumbnailUrl:
          'https://res.cloudinary.com/tmart/video/upload/v1710453797/yvhk9de4dcbyhvtj4obf.jpg',
      fileUrl:
          'https://res.cloudinary.com/tmart/video/upload/v1710453797/yvhk9de4dcbyhvtj4obf.mp4',
    ),
    MediaItem(
      id: '5',
      type: 'video',
      thumbnailUrl:
          'https://res.cloudinary.com/tmart/video/upload/v1710082088/ybagabtrrvnzopyvz5q8.jpg',
      fileUrl:
          'https://res.cloudinary.com/tmart/video/upload/v1710082088/ybagabtrrvnzopyvz5q8.mp4',
    ),
    MediaItem(
      id: '6',
      type: 'video',
      thumbnailUrl:
          'https://res.cloudinary.com/tmart/video/upload/v1710042870/lfhkqerffc5pwqwq5rfd.jpg',
      fileUrl:
          'https://res.cloudinary.com/tmart/video/upload/v1710042870/lfhkqerffc5pwqwq5rfd.mp4',
    ),
  ];
});
