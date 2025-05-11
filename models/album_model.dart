import 'package:flutter/foundation.dart';
import 'media_model.dart';

class Album {
  final String albumId;
  final String title;
  final String? description;
  final DateTime createdAt;
  final bool isLocked;
  final String? thumbnailUrl;
  final bool hasPremiumMedia;
  final List<Media> media;

  Album({
    required this.albumId,
    required this.title,
    this.description,
    required this.createdAt,
    this.isLocked = false,
    this.thumbnailUrl,
    this.hasPremiumMedia = false,
    this.media = const [],
  });

  Album copyWith({
    String? albumId,
    String? title,
    String? description,
    DateTime? createdAt,
    bool? isLocked,
    String? thumbnailUrl,
    bool? hasPremiumMedia,
    List<Media>? media,
  }) {
    return Album(
      albumId: albumId ?? this.albumId,
      title: title ?? this.title,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      isLocked: isLocked ?? this.isLocked,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      hasPremiumMedia: hasPremiumMedia ?? this.hasPremiumMedia,
      media: media ?? this.media,
    );
  }

  factory Album.fromJson(Map<String, dynamic> json, String id) {
    return Album(
      albumId: id,
      title: json['title'] ?? 'Untitled Album',
      description: json['description'],
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt']) 
          : DateTime.now(),
      isLocked: json['isLocked'] ?? false,
      thumbnailUrl: json['thumbnailUrl'],
      hasPremiumMedia: json['hasPremiumMedia'] ?? false,
      media: const [], // Will be populated separately
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'albumId': albumId,
      'title': title,
      'description': description,
      'createdAt': createdAt.toIso8601String(),
      'isLocked': isLocked,
      'thumbnailUrl': thumbnailUrl,
      'hasPremiumMedia': hasPremiumMedia,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Album &&
        other.albumId == albumId &&
        other.title == title &&
        other.description == description &&
        other.createdAt == createdAt &&
        other.isLocked == isLocked &&
        other.thumbnailUrl == thumbnailUrl &&
        other.hasPremiumMedia == hasPremiumMedia &&
        listEquals(other.media, media);
  }

  @override
  int get hashCode {
    return albumId.hashCode ^
        title.hashCode ^
        description.hashCode ^
        createdAt.hashCode ^
        isLocked.hashCode ^
        thumbnailUrl.hashCode ^
        hasPremiumMedia.hashCode ^
        Object.hashAll(media);
  }
}