import 'package:flutter/material.dart';
import '../Home/navbar_page.dart';
import '../network.dart';
import 'create_new_list.dart';

class ProjectDetailPage extends StatefulWidget {
  final String boardPublicId;

  const ProjectDetailPage({super.key, required this.boardPublicId});

  @override
  State<ProjectDetailPage> createState() => _ProjectDetailPageState();
}

class _ProjectDetailPageState extends State<ProjectDetailPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  Map<String, dynamic>? _boardDetail;
  List<dynamic> _boardLists = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: 1);
    _loadProjectData();
  }

  Future<void> _loadProjectData() async {
    setState(() => _isLoading = true);
    try {
      final detailRes = await BoardService.getBoardDetail(widget.boardPublicId);
      final listsRes = await BoardService.getBoardLists(widget.boardPublicId);

      if (mounted) {
        setState(() {
          _boardDetail = detailRes['data'];
          _boardLists = listsRes['data'] ?? [];
        });
      }
    } catch (e) {
      debugPrint('Error fetch board detail: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final String boardTitle = _boardDetail?['title'] ?? 'Coffee Shop';

    return Scaffold(
      appBar: const Navbar(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Breadcrumbs
                  Text(
                    'Home / Daftar Proyek / $boardTitle',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Project Title
                  Text(
                    '$boardTitle (CS)',
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
                    unselectedLabelColor: isDark ? Colors.grey[400] : Colors.grey[600],
                    indicatorColor: const Color(0xFF1976D2),
                    labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    tabs: const [
                      Tab(text: 'DASHBOARD'),
                      Tab(text: 'PROJECT'),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Tab View Content (Project Tab)
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.65,
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        // Tab 1: Dashboard
                        const Center(child: Text('Tampilan Dashboard')),

                        // Tab 2: Project (List & Boards)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Button Tambah Member
                            TextButton.icon(
                              onPressed: () {
                                // Action tambah member
                              },
                              icon: const Icon(Icons.person_add_outlined, size: 18),
                              label: const Text('TAMBAH MEMBER', style: TextStyle(fontSize: 12)),
                            ),
                            const SizedBox(height: 12),

                            // Horizontal List Area
                            Expanded(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Rendering List dari Backend
                                    ..._boardLists.map((list) {
                                      return Container(
                                        width: 260,
                                        margin: const EdgeInsets.only(right: 12),
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).cardColor,
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: Theme.of(context).dividerColor),
                                        ),
                                        child: Text(
                                          list['title'] ?? '',
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                      );
                                    }),

                                    // Button / Form Buat Daftar Tugas
                                    CreateNewList(
                                      boardPublicId: widget.boardPublicId,
                                      onSuccess: _loadProjectData,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}