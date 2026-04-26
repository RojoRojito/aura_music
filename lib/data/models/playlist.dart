import 'song.dart';

class Playlist {
  final int? id;
  final String name;
  final List<Song> songs;
  final DateTime createdAt;

  const Playlist({
    this.id,
    required this.name,
    this.songs = const [],
    required this.createdAt,
  });

  int get songCount => songs.length;

  Duration get totalDuration => songs.fold(
    Duration.zero,
    (sum, s) => sum + Duration(milliseconds: s.duration),
  );

  Playlist copyWith({int? id, String? name, List<Song>? songs}) => Playlist(
    id: id ?? this.id,
    name: name ?? this.name,
    songs: songs ?? this.songs,
    createdAt: createdAt,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'created_at': createdAt.toIso8601String(),
  };

  factory Playlist.fromMap(Map<String, dynamic> map) => Playlist(
    id: map['id'],
    name: map['name'],
    songs: const [],
    createdAt: DateTime.parse(map['created_at']),
  );
}
