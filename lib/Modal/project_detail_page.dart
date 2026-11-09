import 'package:flutter/material.dart';

import '../Home/navbar_page.dart';
import '../network.dart';
import 'project_board_layout.dart';

class ProjectDetailPage extends StatefulWidget {
  final String boardPublicId;

  const ProjectDetailPage({super.key, required this.boardPublicId});

  @override
  State<ProjectDetailPage> createState() => _ProjectDetailPageState();
}

class _ProjectDetailPageState extends State<ProjectDetailPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _activeTab = 1;
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _boardDetail;
  List<Map<String, dynamic>> _boardLists = [];
  Map<String, List<dynamic>> _cardsByList = {};
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: 1);
    _loadProjectData();
  }

  Future<void> _loadProjectData() async {
    final requestId = ++_requestId;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final detailResponse = await BoardService.getBoardDetail(
        widget.boardPublicId,
      );
      final detailData = detailResponse is Map ? detailResponse['data'] : null;
      if (detailData is! Map) {
        throw Exception('Data proyek tidak valid');
      }
      final board = Map<String, dynamic>.from(detailData);

      List<Map<String, dynamic>> lists = [];
      try {
        final listsResponse = await BoardService.getBoardLists(
          widget.boardPublicId,
        );
        final listsData = listsResponse is Map ? listsResponse['data'] : null;
        dynamic rawLists;

        if (listsData is Map && listsData['Lists'] is List) {
          rawLists = listsData['Lists'];
        } else if (listsData is List) {
          rawLists = listsData;
        }

        if (rawLists is List) {
          lists = rawLists
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
        }
      } catch (error) {
        // GET /boards/:id/lists returns 404 while a board still has no list.
        debugPrint('Daftar tugas belum tersedia: $error');
      }

      final cardsByList = <String, List<dynamic>>{};
      await Future.wait(
        lists.map((list) async {
          final listId = list['public_id']?.toString() ?? '';
          if (listId.isEmpty) return;

          try {
            final cardsResponse = await ListService.getCards(listId);
            final cardsData = cardsResponse is Map
                ? cardsResponse['data']
                : null;
            cardsByList[listId] = cardsData is List ? cardsData : <dynamic>[];
          } catch (error) {
            cardsByList[listId] = <dynamic>[];
            debugPrint('Tugas untuk daftar $listId belum tersedia: $error');
          }
        }),
      );

      if (!mounted || requestId != _requestId) return;
      setState(() {
        _boardDetail = board;
        _boardLists = lists;
        _cardsByList = cardsByList;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _error = error.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _handleDeleteList(Map<String, dynamic> list) async {
    final listId = list['public_id']?.toString() ?? '';
    if (listId.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konfirmasi Hapus'),
        content: const Text('Yakin ingin menghapus daftar tugas ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await ListService.deleteList(listId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Daftar tugas berhasil dihapus')),
      );
      await _loadProjectData();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _handleTaskMoved(
    Map<String, dynamic> task,
    String fromListId,
    String toListId,
  ) async {
    if (fromListId.isEmpty || toListId.isEmpty || fromListId == toListId) {
      return;
    }

    final cardId = task['public_id']?.toString() ?? '';
    if (cardId.isEmpty) return;

    final sourceTasks = List<dynamic>.from(
      _cardsByList[fromListId] ?? const <dynamic>[],
    );
    final originalIndex = sourceTasks.indexWhere(
      (item) => item is Map && item['public_id']?.toString() == cardId,
    );
    if (originalIndex == -1) return;

    sourceTasks.removeAt(originalIndex);
    final targetTasks = List<dynamic>.from(
      _cardsByList[toListId] ?? const <dynamic>[],
    );
    final movedTask = Map<String, dynamic>.from(task)
      ..['list_id'] = toListId
      ..['position'] = targetTasks.length + 1;
    targetTasks.add(movedTask);

    setState(() {
      _cardsByList[fromListId] = sourceTasks;
      _cardsByList[toListId] = targetTasks;
    });

    try {
      // Send the card back with the new list, matching the reference app's
      // update payload so optional card fields are preserved.
      await CardService.updateCard(cardId, movedTask);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        final currentSource = List<dynamic>.from(
          _cardsByList[fromListId] ?? const <dynamic>[],
        );
        final currentTarget = List<dynamic>.from(
          _cardsByList[toListId] ?? const <dynamic>[],
        );
        currentTarget.removeWhere(
          (item) => item is Map && item['public_id']?.toString() == cardId,
        );
        if (currentSource.every(
          (item) => item is! Map || item['public_id']?.toString() != cardId,
        )) {
          currentSource.insert(
            originalIndex.clamp(0, currentSource.length),
            task,
          );
        }
        _cardsByList[fromListId] = currentSource;
        _cardsByList[toListId] = currentTarget;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String get _boardTitle => (_boardDetail?['title'] ?? '').toString();

  String get _projectInitials {
    final words = _boardTitle
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty);

    return words.map((word) => word[0].toUpperCase()).join();
  }

  String get _pageTitle {
    final initials = _projectInitials;
    return initials.isEmpty ? _boardTitle : '$_boardTitle ($initials)';
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_error ?? 'Gagal memuat proyek'),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _loadProjectData,
            child: const Text('Coba lagi'),
          ),
        ],
      ),
    );
  }

  void _openProjects() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacementNamed(context, '/');
    }
  }

  Widget _breadcrumbLink(String label, Color color) {
    return InkWell(
      onTap: _openProjects,
      child: Text(label, style: TextStyle(fontSize: 12, color: color)),
    );
  }

  Widget _buildProjectBoard() {
    return ProjectBoardLayout(
      boardPublicId: widget.boardPublicId,
      lists: _boardLists,
      cardsByList: _cardsByList,
      projectInitials: _projectInitials,
      onDeleteList: _handleDeleteList,
      onTaskMoved: _handleTaskMoved,
      onReload: _loadProjectData,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final crumbColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;

    return Scaffold(
      appBar: const Navbar(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _buildError()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Breadcrumbs
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _breadcrumbLink('Home', crumbColor),
                      Text(
                        ' / ',
                        style: TextStyle(fontSize: 12, color: crumbColor),
                      ),
                      _breadcrumbLink('Daftar Proyek', crumbColor),
                      Text(
                        ' / $_boardTitle',
                        style: TextStyle(fontSize: 12, color: crumbColor),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Project Title
                  Text(
                    _pageTitle,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.titleLarge?.color,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Tabs: DASHBOARD & PROJECT
                  TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    labelColor: const Color(0xFF1976D2),
                    unselectedLabelColor: isDark
                        ? Colors.grey[400]
                        : Colors.grey[600],
                    indicatorColor: const Color(0xFF1976D2),
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                    onTap: (index) => setState(() => _activeTab = index),
                    tabs: const [
                      Tab(text: 'DASHBOARD'),
                      Tab(text: 'PROJECT'),
                    ],
                  ),
                  const SizedBox(height: 16),

                  if (_activeTab == 0)
                    const Center(child: Text('Tampilan Dashboard'))
                  else ...[
                    // Button Tambah Member
                    TextButton.icon(
                      onPressed: () {
                        // Action tambah member
                      },
                      icon: const Icon(Icons.person_add_outlined, size: 18),
                      label: const Text(
                        'TAMBAH MEMBER',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildProjectBoard(),
                  ],
                ],
              ),
            ),
    );
  }
}
