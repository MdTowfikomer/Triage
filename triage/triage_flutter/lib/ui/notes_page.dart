import 'package:flutter/material.dart';
import '../notes/local_notes_repository.dart';

class NotesPage extends StatefulWidget {
  const NotesPage({super.key, required this.repository});
  final LocalNotesRepository repository;

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'all';
  List<LocalNoteItem> _notes = [];
  bool _isLoading = true;

  final List<String> _categories = [
    'all',
    'note',
    'idea',
    'reminder',
    'shopping',
  ];

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    setState(() => _isLoading = true);
    final notes = await widget.repository.getNotes(
      categoryQuery: _selectedCategory,
      searchQuery: _searchController.text,
    );
    if (mounted) {
      setState(() {
        _notes = notes;
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteNote(String id) async {
    await widget.repository.deleteNote(id);
    _loadNotes();
  }

  Color _categoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'idea':
        return const Color(0xFFD97706);
      case 'reminder':
        return const Color(0xFF2563EB);
      case 'shopping':
        return const Color(0xFF059669);
      default:
        return const Color(0xFF777971);
    }
  }

  Color _categoryBg(String category) {
    switch (category.toLowerCase()) {
      case 'idea':
        return const Color(0xFFFEF3C7);
      case 'reminder':
        return const Color(0xFFDBEAFE);
      case 'shopping':
        return const Color(0xFFD1FAE5);
      default:
        return const Color(0xFFF3F4F6);
    }
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF242521);
    const muted = Color(0xFF777971);
    const paper = Color(0xFFF8F7F2);

    return Scaffold(
      backgroundColor: paper,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Scratchpad & Notes',
          style: TextStyle(
            color: ink,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.8,
          ),
        ),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => _loadNotes(),
              style: const TextStyle(color: ink, fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Search offline notes...',
                hintStyle: const TextStyle(color: muted, fontSize: 15),
                prefixIcon: const Icon(Icons.search_rounded, color: muted, size: 20),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // Category Filter Pills
          SizedBox(
            height: 38,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final cat = _categories[index];
                final isSelected = _selectedCategory == cat;
                return ChoiceChip(
                  label: Text(
                    cat == 'all' ? 'All Notes' : cat[0].toUpperCase() + cat.substring(1),
                    style: TextStyle(
                      color: isSelected ? Colors.white : ink,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: ink,
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: isSelected ? ink : const Color(0xFFE5E7EB),
                    ),
                  ),
                  onSelected: (val) {
                    if (val) {
                      setState(() => _selectedCategory = cat);
                      _loadNotes();
                    }
                  },
                );
              },
            ),
          ),

          const SizedBox(height: 14),

          // Notes List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _notes.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.edit_note_rounded, size: 56, color: muted.withValues(alpha: 0.5)),
                        const SizedBox(height: 12),
                        const Text(
                          'No notes recorded yet',
                          style: TextStyle(color: ink, fontSize: 17, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Say "Note down: buy groceries" to add',
                          style: TextStyle(color: muted, fontSize: 14),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                    itemCount: _notes.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = _notes[index];
                      return Dismissible(
                        key: ValueKey(item.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626)),
                        ),
                        onDismissed: (_) => _deleteNote(item.id),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.02),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: _categoryBg(item.category),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      item.category.toUpperCase(),
                                      style: TextStyle(
                                        color: _categoryColor(item.category),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.4,
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    _formatTime(item.createdAt),
                                    style: const TextStyle(color: muted, fontSize: 12),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                item.content,
                                style: const TextStyle(
                                  color: ink,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
