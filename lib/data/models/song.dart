class Song {
  final int id;
  final String title;
  final String artist;
  final String album;
  final String? albumArtUri;
  final String uri;
  final int duration;
  final int? albumId;
  final int? artistId;
  final String? genre;
  final int? year;
  final int? trackNumber;

  const Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    this.albumArtUri,
    required this.uri,
    required this.duration,
    this.albumId,
    this.artistId,
    this.genre,
    this.year,
    this.trackNumber,
  });

  String get durationFormatted {
    final d = Duration(milliseconds: duration);
    final min = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final sec = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$min:$sec';
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'artist': artist,
    'album': album,
    'albumArtUri': albumArtUri,
    'uri': uri,
    'duration': duration,
    'albumId': albumId,
    'artistId': artistId,
    'genre': genre,
    'year': year,
    'trackNumber': trackNumber,
  };

  factory Song.fromJson(Map<String, dynamic> json) => Song(
    id: json['id'] as int,
    title: json['title'] as String,
    artist: json['artist'] as String,
    album: json['album'] as String,
    albumArtUri: json['albumArtUri'] as String?,
    uri: json['uri'] as String,
    duration: json['duration'] as int,
    albumId: json['albumId'] as int?,
    artistId: json['artistId'] as int?,
    genre: json['genre'] as String?,
    year: json['year'] as int?,
    trackNumber: json['trackNumber'] as int?,
  );

  @override
  bool operator ==(Object other) => other is Song && other.id == id;

  @override
  int get hashCode => id.hashCode;
}