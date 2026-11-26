import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/utils/format_utils.dart';
import '../core/widgets/empty_state.dart';
import '../core/widgets/page_header.dart';
import '../core/models/call_note.dart';
import '../core/services/call_notes_service.dart';
import '../core/services/theme_service.dart';

class NotesPage extends StatefulWidget {
  const NotesPage({super.key});

  @override
  State<NotesPage> createState() => _NotesPageState();
}

enum _NotesFilter { all, recent, archived }

class _NotesPageState extends State<NotesPage> {
  static const Duration _recentWindow = Duration(days: 7);

  final TextEditingController _searchController = TextEditingController();

  List<CallNote> _notes = <CallNote>[];
  bool _isLoading = true;
  String _searchQuery = '';
  _NotesFilter _activeFilter = _NotesFilter.all;

  @override
  void initState() {
    super.initState();
    _loadNotes();
    _searchController.addListener(_handleSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_handleSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadNotes({bool silently = false}) async {
    try {
      if (!silently) {
        setState(() => _isLoading = true);
      }
      final List<CallNote> results = await CallNotesService.getAllNotes();
      if (!mounted) {
        return;
      }
      setState(() {
        _notes = results;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _isLoading = false);
      _showSnack('Error loading notes');
    }
  }

  Future<void> _handleRefresh() => _loadNotes(silently: true);

  void _handleSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.trim().toLowerCase();
    });
  }

  List<CallNote> get _visibleNotes {
    final DateTime now = DateTime.now();
    final DateTime recentCutoff = now.subtract(_recentWindow);

    return _notes.where((CallNote note) {
      final bool matchesFilter;
      switch (_activeFilter) {
        case _NotesFilter.all:
          matchesFilter = true;
          break;
        case _NotesFilter.recent:
          matchesFilter = note.createdAt.isAfter(recentCutoff);
          break;
        case _NotesFilter.archived:
          matchesFilter = note.createdAt.isBefore(recentCutoff);
          break;
      }

      if (!matchesFilter) {
        return false;
      }

      if (_searchQuery.isEmpty) {
        return true;
      }

      final String content = note.content.toLowerCase();
      final String number = note.number.toLowerCase();
      return content.contains(_searchQuery) || number.contains(_searchQuery);
    }).toList(growable: false);
  }

  int get _recentCount {
    final DateTime cutoff = DateTime.now().subtract(_recentWindow);
    return _notes.where((CallNote note) => note.createdAt.isAfter(cutoff)).length;
  }

  CallNote? get _latestNote => _notes.isEmpty ? null : _notes.first;

  void _onFilterTapped(_NotesFilter filter) {
    if (_activeFilter == filter) {
      return;
    }
    setState(() => _activeFilter = filter);
  }



  Future<void> _deleteNote(CallNote note) async {
    await CallNotesService.deleteNote(note.id);
    await _loadNotes(silently: true);
    _showSnack('Note removed');
  }

  void _showSnack(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _formatFull(DateTime timestamp) {
    return DateFormat('MMM d, h:mm a').format(timestamp);
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = context.watch<ThemeService>().isDarkMode;
    final ThemeData theme = Theme.of(context);
    final List<CallNote> notes = _visibleNotes;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _buildHeader(theme, isDarkMode),
              _buildStatsRow(theme, isDarkMode),
              _buildSearchField(theme, isDarkMode),
              _buildFilterBar(theme, isDarkMode),
              Expanded(
                child: RefreshIndicator(
                  color: theme.colorScheme.primary,
                  backgroundColor:
                      isDarkMode ? const Color(0xFF152840) : theme.colorScheme.surface,
                  onRefresh: _handleRefresh,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: _isLoading
                        ? _buildLoadingSkeleton()
                        : notes.isEmpty
                            ? _buildEmptyState(theme, isDarkMode)
                            : _buildNotesList(notes, theme, isDarkMode),
                  ),
                ),
              ),
            ],
          ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, bool isDarkMode) {
    final CallNote? latest = _latestNote;
    return PageHeader(
      title: 'Notes',
      subtitle: latest == null ? 'Jot things down mid-call' : 'Last note ${TimeUtils.formatRelativeTime(latest.createdAt)}',
    );
  }

  Widget _buildStatsRow(ThemeData theme, bool isDarkMode) {
    final Color cardColor = isDarkMode ? Colors.white.withValues(alpha: 0.08) : Colors.white;
    final Color borderColor = isDarkMode
        ? Colors.white.withValues(alpha: 0.12)
        : theme.colorScheme.primary.withValues(alpha: 0.25);

    Widget statCard(String label, String value, IconData icon) {
      return Expanded(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: theme.colorScheme.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    value,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: isDarkMode ? Colors.white : theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDarkMode
                          ? const Color(0xFF8EA6C2)
                          : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      children: <Widget>[
        statCard('Total notes', _notes.length.toString(), Icons.library_books_outlined),
        statCard('This week', _recentCount.toString(), Icons.auto_graph_rounded),
      ],
    );
  }

  Widget _buildSearchField(ThemeData theme, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.white.withValues(alpha: 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDarkMode
                ? Colors.white.withValues(alpha: 0.1)
                : theme.colorScheme.primary.withValues(alpha: 0.2),
          ),
        ),
        child: TextField(
          controller: _searchController,
          cursorColor: theme.colorScheme.primary,
          decoration: InputDecoration(
            hintText: 'Search notes or numbers',
            hintStyle: TextStyle(
              color: isDarkMode
                  ? Colors.white70
                  : theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
            prefixIcon: Icon(Icons.search, color: theme.colorScheme.primary),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close),
                    color: theme.colorScheme.primary,
                    onPressed: () {
                      _searchController.clear();
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterBar(ThemeData theme, bool isDarkMode) {
    Widget chip(_NotesFilter filter, String label) {
      final bool selected = _activeFilter == filter;
      return ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => _onFilterTapped(filter),
        selectedColor: theme.colorScheme.primary.withValues(alpha: 0.15),
        labelStyle: TextStyle(
          color: selected
              ? theme.colorScheme.primary
              : (isDarkMode ? Colors.white70 : theme.colorScheme.onSurface.withValues(alpha: 0.7)),
          fontWeight: FontWeight.w600,
        ),
        backgroundColor: isDarkMode ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        shape: StadiumBorder(
          side: BorderSide(
            color: selected
                ? theme.colorScheme.primary
                : (isDarkMode ? Colors.white.withValues(alpha: 0.12) : Colors.black12),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
      child: Wrap(
        spacing: 12,
        children: <Widget>[
          chip(_NotesFilter.all, 'All'),
          chip(_NotesFilter.recent, 'Recent'),
          chip(_NotesFilter.archived, 'Archived'),
        ],
      ),
    );
  }

  Widget _buildLoadingSkeleton() {
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 120),
      itemCount: 4,
      itemBuilder: (_, __) {
        return Container(
          height: 90,
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(ThemeData theme, bool isDarkMode) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: <Widget>[
        SizedBox(
          height: 360,
          child: _searchQuery.isEmpty
              ? const EmptyState(
                  emoji: '📝',
                  title: 'No notes yet',
                  message: 'Tap Notes during a call to remember who promised what. Future you says thanks.',
                )
              : const EmptyState(emoji: '🕵️', title: 'No matches', message: 'Even Sherlock found nothing. Try other words?'),
        ),
      ],
    );
  }

  Widget _buildNotesList(List<CallNote> notes, ThemeData theme, bool isDarkMode) {
    return ListView.builder(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 120),
      itemCount: notes.length,
      itemBuilder: (BuildContext context, int index) {
        final CallNote note = notes[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Dismissible(
            key: ValueKey<String>(note.id),
            direction: DismissDirection.endToStart,
            background: _buildDismissBackground(theme),
            confirmDismiss: (_) async {
              await _deleteNote(note);
              return true;
            },
            child: _buildNoteCard(note, theme, isDarkMode),
          ),
        );
      },
    );
  }

  Widget _buildDismissBackground(ThemeData theme) {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: theme.colorScheme.error.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Icon(Icons.delete_outline, color: Colors.white),
    );
  }

  Widget _buildNoteCard(CallNote note, ThemeData theme, bool isDarkMode) {
    final Color cardColor = isDarkMode ? Colors.white.withValues(alpha: 0.08) : Colors.white;
    final Color borderColor = isDarkMode
        ? Colors.white.withValues(alpha: 0.08)
        : theme.colorScheme.primary.withValues(alpha: 0.15);

    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: () => _showNoteDetails(note, theme, isDarkMode),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: borderColor),
          boxShadow: <BoxShadow>[
            if (!isDarkMode)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.call_outlined,
                    size: 20,
                    color: isDarkMode ? Colors.white70 : theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    note.number,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: isDarkMode ? Colors.white : theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  TimeUtils.formatRelativeTime(note.createdAt),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDarkMode ? Colors.white70 : Colors.black54,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              note.content,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: isDarkMode ? Colors.white : theme.colorScheme.onSurface,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Icon(Icons.schedule,
                    size: 16,
                    color: isDarkMode ? Colors.white54 : Colors.black45),
                const SizedBox(width: 6),
                Text(
                  _formatFull(note.createdAt),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDarkMode ? Colors.white60 : Colors.black54,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showNoteDetails(CallNote note, ThemeData theme, bool isDarkMode) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return _NoteDetailsSheet(
          note: note,
          theme: theme,
          isDarkMode: isDarkMode,
          formattedTimestamp: _formatFull(note.createdAt),
        );
      },
    );
  }
}


class _NoteDetailsSheet extends StatelessWidget {
  const _NoteDetailsSheet({
    required this.note,
    required this.theme,
    required this.isDarkMode,
    required this.formattedTimestamp,
  });

  final CallNote note;
  final ThemeData theme;
  final bool isDarkMode;
  final String formattedTimestamp;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF0F1E33) : Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                note.number,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: isDarkMode ? Colors.white : theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                formattedTimestamp,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isDarkMode ? Colors.white70 : Colors.black54,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                note.content,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: isDarkMode ? Colors.white : theme.colorScheme.onSurface,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
