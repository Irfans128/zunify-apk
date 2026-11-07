import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
import '../providers/theme_provider.dart';
import '../services/ytmusic_service.dart';
import '../widgets/liquid_background_widget.dart';
import '../widgets/song_tile_widget.dart';

/// Halaman Profil Artis Lengkap (Lagu Terpopuler, Album & Single, Bio, Artis Serupa)
class ArtistProfileScreen extends StatefulWidget {
  final String artistName;
  final String? browseId;

  const ArtistProfileScreen({
    super.key,
    required this.artistName,
    this.browseId,
  });

  @override
  State<ArtistProfileScreen> createState() => _ArtistProfileScreenState();
}

class _ArtistProfileScreenState extends State<ArtistProfileScreen> {
  ZunifyArtistProfile? _profile;
  bool _isLoading = true;
  bool _bioExpanded = false;
  bool _showAllTopSongs = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final ytm = context.read<PlayerProvider>().ytMusicService;
    final res = await ytm.fetchArtistProfile(
      widget.artistName,
      browseId: widget.browseId,
    );
    if (!mounted) return;
    setState(() {
      _profile = res;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final player = context.watch<PlayerProvider>();
    final accent = theme.accentColor;
    final isBrutal = theme.isNeoBrutalism;
    final profile = _profile;

    return Scaffold(
      backgroundColor: theme.scaffoldBgColor,
      body: _isLoading || profile == null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: theme.accentText),
                  const SizedBox(height: 14),
                  Text(
                    'Memuat profil ${widget.artistName}...',
                    style: TextStyle(color: theme.textSecondary, fontSize: 13),
                  ),
                ],
              ),
            )
          : CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // Immersive Artist Banner AppBar
                SliverAppBar(
                  expandedHeight: 276,
                  pinned: true,
                  backgroundColor: theme.scaffoldBgColor,
                  leading: Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Center(
                      child: IosGlassIconButton(
                        icon: Icons.arrow_back_ios_new_rounded,
                        size: 36,
                        iconSize: 17,
                        onTap: () => Navigator.pop(context),
                      ),
                    ),
                  ),
                  flexibleSpace: FlexibleSpaceBar(
                    titlePadding: const EdgeInsets.fromLTRB(56, 0, 20, 14),
                    title: Text(
                      profile.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: theme.textPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 21,
                        letterSpacing: -0.5,
                      ),
                    ),
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (profile.bannerUrl.isNotEmpty)
                          CachedNetworkImage(
                            imageUrl: profile.bannerUrl,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => Container(
                              color: theme.subtleFill,
                            ),
                          )
                        else
                          Container(color: accent.withOpacity(0.25)),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withOpacity(0.18),
                                Colors.transparent,
                                theme.scaffoldBgColor.withOpacity(0.88),
                                theme.scaffoldBgColor,
                              ],
                              stops: const [0.0, 0.34, 0.78, 1.0],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 110),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Action Buttons: Putar Populer & Radio Artis
                        if (profile.topSongs.isNotEmpty)
                          Row(
                            children: [
                              Expanded(
                                child: IosSpringButton(
                                  onTap: () {
                                    player.playSong(
                                      profile.topSongs.first,
                                      customQueue: profile.topSongs,
                                      contextName: profile.name,
                                    );
                                  },
                                  child: Container(
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: accent,
                                      borderRadius: BorderRadius.circular(
                                        isBrutal ? 11 : 16,
                                      ),
                                      border: isBrutal
                                          ? Border.all(
                                              color: theme.brutalBorderColor,
                                              width: 2.2,
                                            )
                                          : null,
                                      boxShadow: isBrutal
                                          ? [
                                              BoxShadow(
                                                color: theme.brutalShadowColor,
                                                blurRadius: 0,
                                                offset: const Offset(3.2, 3.2),
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.play_arrow_rounded,
                                          color: Color(0xFF111111),
                                          size: 22,
                                        ),
                                        SizedBox(width: 6),
                                        Text(
                                          'Putar Populer',
                                          style: TextStyle(
                                            color: Color(0xFF111111),
                                            fontWeight: FontWeight.w800,
                                            fontSize: 13.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: LiquidGlassBox(
                                  height: 44,
                                  borderRadius: 16,
                                  tintOpacity: 0.09,
                                  rimIntensity: 0.35,
                                  onTap: () {
                                    player.playSong(
                                      profile.topSongs.first,
                                      customQueue: const [],
                                      contextName: 'Radio ${profile.name}',
                                    );
                                  },
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.sensors_rounded,
                                        color: theme.accentText,
                                        size: 19,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Radio Artis',
                                        style: TextStyle(
                                          color: theme.textPrimary,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 13.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        const SizedBox(height: 22),

                        // Lagu Terpopuler
                        if (profile.topSongs.isNotEmpty) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Lagu Terpopuler',
                                style: TextStyle(
                                  color: theme.textPrimary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              if (profile.topSongs.length > 5)
                                GestureDetector(
                                  onTap: () => setState(
                                    () => _showAllTopSongs = !_showAllTopSongs,
                                  ),
                                  child: Text(
                                    _showAllTopSongs
                                        ? 'Tampilkan Sedikit'
                                        : 'Lihat Semua (${profile.topSongs.length})',
                                    style: TextStyle(
                                      color: theme.accentText,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ...profile.topSongs
                              .take(_showAllTopSongs ? 15 : 5)
                              .toList()
                              .asMap()
                              .entries
                              .map(
                                (entry) => ZunifySongTile(
                                  song: entry.value,
                                  queueContext: profile.topSongs,
                                  contextName: profile.name,
                                  rank: entry.key + 1,
                                ),
                              ),
                          const SizedBox(height: 24),
                        ],

                        // Album & Single Carousel
                        if (profile.albums.isNotEmpty) ...[
                          Text(
                            'Album & Single',
                            style: TextStyle(
                              color: theme.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 200,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              itemCount: profile.albums.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 14),
                              itemBuilder: (context, idx) {
                                final alb = profile.albums[idx];
                                return IosSpringButton(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            AlbumDetailScreen(album: alb),
                                      ),
                                    );
                                  },
                                  child: SizedBox(
                                    width: 138,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          decoration: isBrutal
                                              ? BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  border: Border.all(
                                                    color:
                                                        theme.brutalBorderColor,
                                                    width: 2.0,
                                                  ),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: theme
                                                          .brutalShadowColor,
                                                      blurRadius: 0,
                                                      offset: const Offset(
                                                        3.2,
                                                        3.2,
                                                      ),
                                                    ),
                                                  ],
                                                )
                                              : null,
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              isBrutal ? 10 : 14,
                                            ),
                                            child: CachedNetworkImage(
                                              imageUrl: alb.coverUrl,
                                              width: 138,
                                              height: 138,
                                              fit: BoxFit.cover,
                                              errorWidget: (_, __, ___) =>
                                                  Container(
                                                width: 138,
                                                height: 138,
                                                color: theme.subtleFill,
                                                child: Icon(
                                                  Icons.album_rounded,
                                                  color: theme.accentText,
                                                  size: 36,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          alb.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: theme.textPrimary,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          alb.yearOrSubtitle.isNotEmpty
                                              ? alb.yearOrSubtitle
                                              : 'Album',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: theme.textMuted,
                                            fontSize: 11.2,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],

                        // Artis Serupa
                        if (profile.similarArtists.isNotEmpty) ...[
                          Text(
                            'Artis Serupa',
                            style: TextStyle(
                              color: theme.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 146,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              itemCount: profile.similarArtists.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 14),
                              itemBuilder: (context, idx) {
                                final sim = profile.similarArtists[idx];
                                return IosSpringButton(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ArtistProfileScreen(
                                          artistName: sim.name,
                                          browseId: sim.browseId,
                                        ),
                                      ),
                                    );
                                  },
                                  child: SizedBox(
                                    width: 102,
                                    child: Column(
                                      children: [
                                        Container(
                                          decoration: isBrutal
                                              ? BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                    color:
                                                        theme.brutalBorderColor,
                                                    width: 2.0,
                                                  ),
                                                )
                                              : null,
                                          child: ClipOval(
                                            child: CachedNetworkImage(
                                              imageUrl: sim.avatarUrl,
                                              width: 92,
                                              height: 92,
                                              fit: BoxFit.cover,
                                              errorWidget: (_, __, ___) =>
                                                  Container(
                                                width: 92,
                                                height: 92,
                                                color: theme.subtleFill,
                                                child: Icon(
                                                  Icons.person_rounded,
                                                  color: theme.accentText,
                                                  size: 34,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          sim.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: theme.textPrimary,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12.2,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],

                        // Tentang Artis (Bio)
                        if (profile.description.trim().isNotEmpty) ...[
                          Text(
                            'Tentang Artis',
                            style: TextStyle(
                              color: theme.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 10),
                          LiquidGlassBox(
                            borderRadius: 18,
                            padding: const EdgeInsets.all(16),
                            tintOpacity: 0.07,
                            rimIntensity: 0.32,
                            onTap: () =>
                                setState(() => _bioExpanded = !_bioExpanded),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  profile.description.trim(),
                                  maxLines: _bioExpanded ? 40 : 4,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: theme.textSecondary,
                                    fontSize: 13,
                                    height: 1.45,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _bioExpanded
                                      ? 'Tutup'
                                      : 'Baca selengkapnya...',
                                  style: TextStyle(
                                    color: theme.accentText,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

/// Halaman Detail Album / Single (`MPREb_...`)
class AlbumDetailScreen extends StatefulWidget {
  final ZunifyAlbumSummary album;

  const AlbumDetailScreen({super.key, required this.album});

  @override
  State<AlbumDetailScreen> createState() => _AlbumDetailScreenState();
}

class _AlbumDetailScreenState extends State<AlbumDetailScreen> {
  ZunifyAlbumDetail? _detail;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAlbum();
  }

  Future<void> _loadAlbum() async {
    final ytm = context.read<PlayerProvider>().ytMusicService;
    final res = await ytm.fetchAlbumDetail(widget.album);
    if (!mounted) return;
    setState(() {
      _detail = res;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final player = context.watch<PlayerProvider>();
    final accent = theme.accentColor;
    final isBrutal = theme.isNeoBrutalism;
    final tracks = _detail?.tracks ?? const [];

    return Scaffold(
      backgroundColor: theme.scaffoldBgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: theme.textPrimary,
            size: 19,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.album.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: theme.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: theme.accentText))
          : ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 110),
              children: [
                Center(
                  child: Container(
                    decoration: isBrutal
                        ? BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: theme.brutalBorderColor,
                              width: 2.4,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: theme.brutalShadowColor,
                                blurRadius: 0,
                                offset: const Offset(4.5, 4.5),
                              ),
                            ],
                          )
                        : null,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(isBrutal ? 13.6 : 20),
                      child: CachedNetworkImage(
                        imageUrl: widget.album.coverUrl,
                        width: 200,
                        height: 200,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(
                          width: 200,
                          height: 200,
                          color: theme.subtleFill,
                          child: Icon(
                            Icons.album_rounded,
                            color: theme.accentText,
                            size: 56,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.album.title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: theme.textPrimary,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ArtistProfileScreen(
                          artistName: widget.album.artist,
                        ),
                      ),
                    );
                  },
                  child: Text(
                    '${widget.album.artist} • ${widget.album.yearOrSubtitle.isNotEmpty ? widget.album.yearOrSubtitle : "${tracks.length} lagu"}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: theme.accentText,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                if (tracks.isNotEmpty)
                  Row(
                    children: [
                      Expanded(
                        child: IosSpringButton(
                          onTap: () {
                            player.playSong(
                              tracks.first,
                              customQueue: tracks,
                              contextName: widget.album.title,
                            );
                          },
                          child: Container(
                            height: 44,
                            decoration: BoxDecoration(
                              color: accent,
                              borderRadius: BorderRadius.circular(
                                isBrutal ? 11 : 16,
                              ),
                              border: isBrutal
                                  ? Border.all(
                                      color: theme.brutalBorderColor,
                                      width: 2.2,
                                    )
                                  : null,
                              boxShadow: isBrutal
                                  ? [
                                      BoxShadow(
                                        color: theme.brutalShadowColor,
                                        blurRadius: 0,
                                        offset: const Offset(3.2, 3.2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.play_arrow_rounded,
                                  color: Color(0xFF111111),
                                  size: 22,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Putar Album',
                                  style: TextStyle(
                                    color: Color(0xFF111111),
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: LiquidGlassBox(
                          height: 44,
                          borderRadius: 16,
                          tintOpacity: 0.09,
                          rimIntensity: 0.35,
                          onTap: () {
                            final shuffled = List.of(tracks)..shuffle();
                            player.playSong(
                              shuffled.first,
                              customQueue: shuffled,
                              contextName: widget.album.title,
                            );
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.shuffle_rounded,
                                size: 18,
                                color: theme.accentText,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Acak',
                                style: TextStyle(
                                  color: theme.textPrimary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 18),
                ...tracks.asMap().entries.map(
                      (entry) => ZunifySongTile(
                        song: entry.value,
                        queueContext: tracks,
                        contextName: widget.album.title,
                        rank: entry.key + 1,
                      ),
                    ),
              ],
            ),
    );
  }
}
