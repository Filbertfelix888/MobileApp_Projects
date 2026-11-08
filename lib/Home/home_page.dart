import 'dart:async';
import 'package:flutter/material.dart';
import 'navbar_page.dart';
import '../network.dart';
import '../Modal/modal_add_new_project.dart';
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isLoading = false;
  List<dynamic> _boardsData = [];
  int _totalPages = 1;
  int _currentPage = 1;

  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _fetchBoardsData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // Fetching data boards dari backend Golang
  Future<void> _fetchBoardsData() async {
    setState(() => _isLoading = true);

    try {
      final response = await BoardService.getMyBoards(
        search: _searchController.text,
        page: _currentPage,
        limit: 10,
      );

      if (mounted) {
        setState(() {
          // Pengecekan fleksibel untuk struktur data dari Backend Golang
          if (response['data'] is List) {
            _boardsData = response['data'];
          } else if (response['data'] != null && response['data']['data'] is List) {
            _boardsData = response['data']['data'];
          } else {
            _boardsData = [];
          }

          _totalPages = response['data']?['meta']?['total_pages'] ?? 1;
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Handle Debounce Search (1000ms delay)
  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 1000), () {
      setState(() => _currentPage = 1);
      _fetchBoardsData();
    });
  }

  // Handle Hapus Proyek
  Future<void> _handleDeleteBoard(String boardId) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konfirmasi Hapus'),
        content: const Text('Yakin ingin menghapus proyek ini?'),
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
      await BoardService.deleteBoard(boardId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Board berhasil dihapus')),
        );
        _fetchBoardsData();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal menghapus board'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // Handle Modal Buat Proyek Baru
  void _handleOpenAddNewProject() {
    showDialog(
      context: context,
      builder: (context) => ModalAddNewProject(
        onSuccess: () {
          _fetchBoardsData();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: const Navbar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Breadcrumbs & Page Title
            Text(
              'Home / Daftar Proyek',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Daftar Proyek',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.titleLarge?.color,
              ),
            ),
            const SizedBox(height: 20),

            // Top Bar: Search Input & Button Add New
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SizedBox(
                  width: 216,
                  height: 40,
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: 'Cari nama proyek',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: const OutlineInputBorder(),
                      isDense: true,
                      fillColor: Theme.of(context).cardColor,
                      filled: true,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: _handleOpenAddNewProject,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1976D2),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                  child: const Text(
                    'BUAT PROYEK BARU',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Data Table / Loading / Empty State
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).dividerColor),
                borderRadius: BorderRadius.circular(4),
                color: Theme.of(context).cardColor,
              ),
              child: _isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : _boardsData.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(24.0),
                          child: Text('Data tidak tersedia', style: TextStyle(color: Colors.grey)),
                        )
                      : SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text('Nama proyek', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Deskripsi', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Tanggal dibuat', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Aksi', style: TextStyle(fontWeight: FontWeight.bold))),
                            ],
                            rows: _boardsData.map((data) {
                              final publicId = data['public_id'] ?? '';
                              final title = data['title'] ?? '-';
                              final description = data['description'] ?? '-';
                              final createdAt = data['created_at'] != null
                                  ? data['created_at'].toString().split('T')[0]
                                  : '-';

                              return DataRow(
                                cells: [
                                  DataCell(Text(title)),
                                  DataCell(Text(description)),
                                  DataCell(Text(createdAt)),
                                  DataCell(
                                    Row(
                                      children: [
                                        OutlinedButton(
                                          onPressed: () {
                                            Navigator.pushNamed(context, '/projects/$publicId');
                                          },
                                          style: OutlinedButton.styleFrom(
                                            side: const BorderSide(color: Color(0xFF1976D2)),
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          ),
                                          child: const Text('DETAIL PROYEK', style: TextStyle(fontSize: 11, color: Color(0xFF1976D2))),
                                        ),
                                        const SizedBox(width: 8),
                                        IconButton(
                                          icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                          onPressed: () => _handleDeleteBoard(publicId),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
            ),
            const SizedBox(height: 16),

            // Pagination Controls
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: _currentPage > 1
                      ? () {
                          setState(() => _currentPage--);
                          _fetchBoardsData();
                        }
                      : null,
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    border: Border.all(color: Theme.of(context).dividerColor),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('$_currentPage'),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: _currentPage < _totalPages
                      ? () {
                          setState(() => _currentPage++);
                          _fetchBoardsData();
                        }
                      : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}