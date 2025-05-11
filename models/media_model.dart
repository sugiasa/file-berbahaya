class Media {
  final String mediaId;
  final String name;
  final String mediaType;
  final String mediaUrl;
  final String thumbnailUrl;
  final int size;
  final bool isPremium;
  final DateTime? createdAt;
  
  // Local state
  final bool isDownloaded;
  final bool isDownloading;
  final String? localPath;

  Media({
    required this.mediaId,
    required this.name,
    required this.mediaType,
    required this.mediaUrl,
    required this.thumbnailUrl,
    required this.size,
    this.isPremium = false,
    this.createdAt,
    this.isDownloaded = false,
    this.isDownloading = false,
    this.localPath,
  });

  Media copyWith({
    String? mediaId,
    String? name,
    String? mediaType,
    String? mediaUrl,
    String? thumbnailUrl,
    int? size,
    bool? isPremium,
    DateTime? createdAt,
    bool? isDownloaded,
    bool? isDownloading,
    String? localPath,
  }) {
    return Media(
      mediaId: mediaId ?? this.mediaId,
      name: name ?? this.name,
      mediaType: mediaType ?? this.mediaType,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      size: size ?? this.size,
      isPremium: isPremium ?? this.isPremium,
      createdAt: createdAt ?? this.createdAt,
      isDownloaded: isDownloaded ?? this.isDownloaded,
      isDownloading: isDownloading ?? this.isDownloading,
      localPath: localPath ?? this.localPath,
    );
  }

  factory Media.fromJson(Map<String, dynamic> json, String id) {
    return Media(
      mediaId: id,
      name: json['name'] ?? 'Untitled',
      mediaType: json['mediaType'] ?? 'unknown',
      mediaUrl: json['mediaUrl'] ?? '',
      thumbnailUrl: json['thumbnailUrl'] ?? '',
      size: json['size'] ?? 0,
      isPremium: json['isPremium'] ?? false,
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
      isDownloaded: json['isDownloaded'] ?? false,
      isDownloading: json['isDownloading'] ?? false,
      localPath: json['localPath'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'mediaId': mediaId,
      'name': name,
      'mediaType': mediaType,
      'mediaUrl': mediaUrl,
      'thumbnailUrl': thumbnailUrl,
      'size': size,
      'isPremium': isPremium,
      'createdAt': createdAt?.toIso8601String(),
      'isDownloaded': isDownloaded,
      'isDownloading': isDownloading,
      'localPath': localPath,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Media &&
        other.mediaId == mediaId &&
        other.name == name &&
        other.mediaType == mediaType &&
        other.mediaUrl == mediaUrl &&
        other.thumbnailUrl == thumbnailUrl &&
        other.size == size &&
        other.isPremium == isPremium &&
        other.createdAt == createdAt &&
        other.isDownloaded == isDownloaded &&
        other.isDownloading == isDownloading &&
        other.localPath == localPath;
  }

  @override
  int get hashCode {
    return mediaId.hashCode ^
        name.hashCode ^
        mediaType.hashCode ^
        mediaUrl.hashCode ^
        thumbnailUrl.hashCode ^
        size.hashCode ^
        isPremium.hashCode ^
        createdAt.hashCode ^
        isDownloaded.hashCode ^
        isDownloading.hashCode ^
        localPath.hashCode;
  }
}