class Artist {
  final int id;
  final String artist;
  final int? numberOfAlbums;
  final int? numberOfTracks;

  const Artist({
    required this.id,
    required this.artist,
    this.numberOfAlbums,
    this.numberOfTracks,
  });
}