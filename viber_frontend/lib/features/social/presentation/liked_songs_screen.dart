import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/widgets/app_image.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../../core/widgets/motion.dart';
import '../../../core/widgets/skeletons.dart';
import '../domain/liked_song.dart';
import '../infrastructure/liked_songs_service.dart';

class LikedSongsScreen extends StatefulWidget {
  const LikedSongsScreen({super.key});

  @override
  State<LikedSongsScreen> createState() => _LikedSongsScreenState();
}

class _LikedSongsScreenState extends State<LikedSongsScreen> {
  final _service = LikedSongsService();
  final _searchController = TextEditingController();
  List<LikedSong> _songs = [];
  bool _loading = true;
  String? _error;
  String _searchQuery = '';
  String _sortBy = 'date';

  @override
  void initState() {
    super.initState();
    _load();
    _searchController.addListener(
      () => setState(() => _searchQuery = _searchController.text),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final songs = await _service.getLikedSongs();
      if (mounted) setState(() => _songs = songs);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _unlike(LikedSong song) async {
    Haptics.light();
    try {
      await _service.unlikeSong(song.videoId);
      if (mounted) {
        setState(() => _songs.removeWhere((s) => s.id == song.id));
        AppSnackBar.show(context, 'liked_songs.removed'.tr());
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(context,
            e.toString().replaceAll('Exception: ', ''), error: true);
      }
    }
  }

  List<LikedSong> get _filtered {
    var list = _songs.where((s) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return s.title.toLowerCase().contains(q) ||
          (s.channelTitle?.toLowerCase().contains(q) ?? false);
    }).toList();
    switch (_sortBy) {
      case 'title':
        list.sort((a, b) =>
            a.title.toLowerCase().compareTo(b.title.toLowerCase()));
      case 'channel':
        list.sort((a, b) => (a.channelTitle ?? '')
            .toLowerCase()
            .compareTo((b.channelTitle ?? '').toLowerCase()));
      default:
        list.sort((a, b) => b.likedAt.compareTo(a.likedAt));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('liked_songs.title'.tr())),
      body: _loading
          ? const SkeletonList(circleLeading: false)
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: appError)))
              : Column(
                  children: [
                    _buildSearchBar(),
                    _buildSortRow(),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _load,
                        color: appAccent,
                        child: _songs.isEmpty
                            ? _buildEmpty()
                            : _filtered.isEmpty
                                ? _buildNoResults()
                                : _buildList(),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: TextField(
        controller: _searchController,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'liked_songs.search_hint'.tr(),
          hintStyle: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
              fontSize: 14),
          prefixIcon: Icon(Icons.search_rounded, color: context.appTextSecColor, size: 20),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.close_rounded,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
                      size: 18),
                  onPressed: () => _searchController.clear(),
                )
              : null,
          filled: true,
          fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: appDivider),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: appDivider),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: appAccent, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          isDense: true,
        ),
        style: const TextStyle(fontSize: 14),
      ),
    );
  }

  Widget _buildSortRow() {
    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          _sortChip('date', 'explore.sort_newest'.tr(), Icons.schedule_rounded),
          _sortChip('title', 'liked_songs.sort_title'.tr(), Icons.sort_by_alpha_rounded),
          _sortChip('channel', 'liked_songs.sort_artist'.tr(), Icons.person_outline_rounded),
        ],
      ),
    );
  }

  Widget _sortChip(String value, String label, IconData icon) {
    final selected = _sortBy == value;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: ChoiceChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 13,
                color: selected
                    ? Colors.white
                    : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
        selected: selected,
        onSelected: (_) => setState(() => _sortBy = value),
        selectedColor: appAccent,
        backgroundColor:
            Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        labelStyle: TextStyle(
          color: selected
              ? Colors.white
              : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: selected ? appAccent : appDivider,
          ),
        ),
        showCheckmark: false,
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
    );
  }

  Widget _buildEmpty() {
    return ListView(
      children: [
        const SizedBox(height: 80),
        Center(
          child: Column(
            children: [
              Icon(Icons.favorite_border_rounded,
                  size: 56,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.25)),
              const SizedBox(height: 16),
              Text(
                'liked_songs.empty'.tr(),
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                    fontSize: 15),
              ),
              const SizedBox(height: 6),
              Text(
                'liked_songs.empty_hint'.tr(),
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.35),
                    fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNoResults() {
    return ListView(
      children: [
        const SizedBox(height: 60),
        Center(
          child: Column(
            children: [
              Icon(Icons.search_off_rounded,
                  size: 48,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.25)),
              const SizedBox(height: 12),
              Text(
                'liked_songs.no_results_for'.tr(namedArgs: {'query': _searchQuery}),
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                    fontSize: 14),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildList() {
    final songs = _filtered;
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: songs.length,
      separatorBuilder: (_, __) =>
          Divider(color: appDivider, height: 1, indent: 72),
      itemBuilder: (_, i) => AppEntrance(
        delay: Duration(milliseconds: (i.clamp(0, 8)) * 40),
        child: _LikedSongTile(
          song: songs[i],
          onUnlike: () => _unlike(songs[i]),
        ),
      ),
    );
  }
}

class _LikedSongTile extends StatelessWidget {
  final LikedSong song;
  final VoidCallback onUnlike;

  const _LikedSongTile({required this.song, required this.onUnlike});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: song.thumbnailUrl != null && song.thumbnailUrl!.isNotEmpty
            ? AppImage(url: song.thumbnailUrl!,
                width: 52, height: 40,
                errorBuilder: (c) => _placeholder(c))
            : _placeholder(context),
      ),
      title: Text(
        song.title,
        style: TextStyle(
            color: context.appTextPrimColor,
            fontSize: 13,
            fontWeight: FontWeight.w500),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: song.channelTitle != null && song.channelTitle!.isNotEmpty
          ? Text(
              song.channelTitle!,
              style: TextStyle(
                  color: context.appTextSecColor,
                  fontSize: 11),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : null,
      trailing: IconButton(
        icon: const Icon(Icons.favorite_rounded, color: appAccent, size: 20),
        tooltip: 'liked_songs.remove'.tr(),
        onPressed: onUnlike,
      ),
    );
  }

  Widget _placeholder(BuildContext context) => Container(
        width: 52,
        height: 40,
        decoration: BoxDecoration(
          color: context.appSurfaceAltColor,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(Icons.music_note, color: context.appTextSecColor, size: 20),
      );
}
