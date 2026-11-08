import 'dart:async';

import 'package:flutter/material.dart';

import '../Dashboard/dashboard_service.dart';
import '../Dashboard/global_workload_view.dart';
import '../environment_config.dart';
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
  int _requestId = 0;
  String? _boardsError;
  int _selectedTab = 0;
  late final int _viewGeneration;
  bool _workloadLoading = false;
  bool _workloadRefreshQueued = false;
  String? _workloadError;
  List<AssigneeTaskCount> _workload = const [];
  int _workloadRequestId = 0;

  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _viewGeneration = EnvironmentConfig.generation;
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
    final requestId = ++_requestId;
    final search = _searchController.text;
    final page = _currentPage;
    setState(() {
      _isLoading = true;
      _boardsError = null;
    });

    try {
      final response = await BoardService.getMyBoards(
        search: search,
        page: page,
        limit: 10,
      );
      if (!mounted ||
          requestId != _requestId ||
          search != _searchController.text ||
          page != _currentPage) {
        return;
      }

      final data = response is Map ? response['data'] : null;
      final meta = response is Map ? response['meta'] : null;
      final totalPages = meta is Map ? meta['total_pages'] : null;
      final validTotalPages = totalPages is int && totalPages > 0
          ? totalPages
          : 1;
      if (page > validTotalPages) {
        setState(() => _currentPage = validTotalPages);
        await _fetchBoardsData();
        return;
      }
      setState(() {
        _boardsData = data is List ? data : <dynamic>[];
        _totalPages = validTotalPages;
        _boardsError = null;
      });
    } catch (error) {
      if (mounted && requestId == _requestId) {
        setState(() {
          _boardsError = error is UnauthorizedException
              ? null
              : _errorMessage(error);
        });
      }
    } finally {
      if (mounted && requestId == _requestId) {
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
        content: const Text(
          'Menghapus proyek ini juga menghapus semua kolom dan tugas di dalamnya. Tindakan ini tidak dapat dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final deletePage = _currentPage;
    final deleteSearch = _searchController.text;
    final deleteRequestId = _requestId;
    final deletedLastBoardOnPage = _boardsData.length == 1;
    try {
      await BoardService.deleteBoard(boardId);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Board berhasil dihapus')));
        if (_currentPage == deletePage &&
            _searchController.text == deleteSearch &&
            _requestId == deleteRequestId &&
            deletedLastBoardOnPage &&
            _currentPage > 1) {
          _currentPage--;
        }
        _fetchBoardsData();
      }
    } catch (error) {
      if (error is! UnauthorizedException && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_errorMessage(error)),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
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

  String _errorMessage(Object error) {
    if (error is NetworkHttpException) return error.message;
    if (error is FormatException) return error.message;
    if (error is StateError) return error.message;
    return error.toString().replaceFirst('Exception: ', '');
  }

  void _selectTab(int tab) {
    if (_selectedTab == tab) return;
    setState(() => _selectedTab = tab);
    if (tab != 1) return;
    if (_workloadLoading) {
      _workloadRefreshQueued = true;
    } else {
      _loadGlobalWorkload();
    }
  }

  Future<void> _loadGlobalWorkload() async {
    if (_workloadLoading) return;
    final requestId = ++_workloadRequestId;
    setState(() {
      _workloadLoading = true;
      _workloadError = null;
    });
    try {
      final workload = await DashboardService.getWorkload(
        expectedGeneration: _viewGeneration,
      );
      if (!mounted || requestId != _workloadRequestId) return;
      if (EnvironmentConfig.generation != _viewGeneration) {
        setState(() {
          _workload = const [];
          _workloadError = 'Sesi berubah. Masuk kembali untuk memuat data.';
        });
        return;
      }
      setState(() {
        _workload = workload;
        _workloadError = null;
      });
    } catch (error) {
      if (mounted && requestId == _workloadRequestId) {
        setState(() {
          _workloadError = _errorMessage(error);
        });
      }
    } finally {
      if (mounted && requestId == _workloadRequestId) {
        final refreshQueued = _workloadRefreshQueued && _selectedTab == 1;
        _workloadRefreshQueued = false;
        setState(() => _workloadLoading = false);
        if (refreshQueued) await _loadGlobalWorkload();
      }
    }
  }

  Widget _pageHeading(BuildContext context, {required String title}) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 360) {
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Semantics(
                    selected: _selectedTab == 0,
                    child: _selectedTab == 0
                        ? FilledButton.tonal(
                            onPressed: () => _selectTab(0),
                            child: const Text('Proyek'),
                          )
                        : OutlinedButton(
                            onPressed: () => _selectTab(0),
                            child: const Text('Proyek'),
                          ),
                  ),
                  Semantics(
                    selected: _selectedTab == 1,
                    child: _selectedTab == 1
                        ? FilledButton.tonal(
                            onPressed: () => _selectTab(1),
                            child: const Text('Analitik global'),
                          )
                        : OutlinedButton(
                            onPressed: () => _selectTab(1),
                            child: const Text('Analitik global'),
                          ),
                  ),
                ],
              );
            }
            return SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('Proyek')),
                ButtonSegment(value: 1, label: Text('Analitik global')),
              ],
              selected: {_selectedTab},
              onSelectionChanged: (selection) => _selectTab(selection.first),
            );
          },
        ),
      ],
    );
  }

  String _projectDate(Object? value) {
    final text = value?.toString() ?? '';
    if (text.isEmpty || text.startsWith('0001-01-01')) return '-';
    return DateTime.tryParse(text)
            ?.toLocal()
            .toIso8601String()
            .split('T')
            .first ??
        text.split('T').first;
  }

  Widget _mobileProjectRow(BuildContext context, dynamic data) {
    final publicId = data['public_id']?.toString() ?? '';
    final title = data['title']?.toString() ?? '-';
    final description = data['description']?.toString() ?? '-';
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Dibuat ${_projectDate(data['created_at'])}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            'Tenggat ${_projectDate(data['due_date'])}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () =>
                    Navigator.pushNamed(context, '/projects/$publicId'),
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const Text('Detail proyek'),
              ),
              IconButton(
                tooltip: 'Hapus proyek $title',
                onPressed: () => _handleDeleteBoard(publicId),
                icon: Icon(
                  Icons.delete_outline,
                  color: theme.colorScheme.error,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _projectsBody(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final pagePadding = constraints.maxWidth < 600 ? 16.0 : 24.0;
        final availableWidth = constraints.maxWidth > pagePadding * 2
            ? constraints.maxWidth - pagePadding * 2
            : constraints.maxWidth;
        final searchWidth = availableWidth < 480 ? availableWidth : 240.0;
        final theme = Theme.of(context);
        return SingleChildScrollView(
          padding: EdgeInsets.all(pagePadding),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _pageHeading(context, title: 'Daftar Proyek'),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox(
                        width: searchWidth,
                        child: TextField(
                          controller: _searchController,
                          onChanged: _onSearchChanged,
                          decoration: const InputDecoration(
                            labelText: 'Cari proyek',
                            hintText: 'Nama proyek',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: _handleOpenAddNewProject,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(48, 48),
                        ),
                        icon: const Icon(Icons.add),
                        label: const Text('Buat proyek baru'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant,
                      ),
                      borderRadius: BorderRadius.circular(10),
                      color: theme.colorScheme.surface,
                    ),
                    child: _isLoading
                        ? Semantics(
                            label: 'Memuat',
                            liveRegion: true,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: List.generate(
                                  3,
                                  (_) => Container(
                                    height: 52,
                                    margin: const EdgeInsets.symmetric(
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          theme.colorScheme.surfaceContainerLow,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          )
                        : _boardsError != null
                        ? Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Gagal memuat proyek',
                                  style: theme.textTheme.titleMedium,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _boardsError!,
                                  style: TextStyle(
                                    color: theme.colorScheme.error,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                OutlinedButton.icon(
                                  onPressed: _fetchBoardsData,
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Coba lagi'),
                                ),
                              ],
                            ),
                          )
                        : _boardsData.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              'Data tidak tersedia',
                              style: TextStyle(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          )
                        : constraints.maxWidth < 600
                        ? Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _boardsData.length,
                              itemBuilder: (context, index) =>
                                  _mobileProjectRow(
                                    context,
                                    _boardsData[index],
                                  ),
                              separatorBuilder: (context, index) =>
                                  Divider(height: 1, color: theme.dividerColor),
                            ),
                          )
                        : SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              columns: [
                                DataColumn(
                                  label: Text(
                                    'Nama proyek',
                                    style: theme.textTheme.titleSmall,
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    'Deskripsi',
                                    style: theme.textTheme.titleSmall,
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    'Tanggal dibuat',
                                    style: theme.textTheme.titleSmall,
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    'Tenggat',
                                    style: theme.textTheme.titleSmall,
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    'Aksi',
                                    style: theme.textTheme.titleSmall,
                                  ),
                                ),
                              ],
                              rows: _boardsData.map((data) {
                                final publicId =
                                    data['public_id']?.toString() ?? '';
                                final title = data['title']?.toString() ?? '-';
                                final description =
                                    data['description']?.toString() ?? '-';
                                return DataRow(
                                  cells: [
                                    DataCell(Text(title)),
                                    DataCell(Text(description)),
                                    DataCell(
                                      Text(_projectDate(data['created_at'])),
                                    ),
                                    DataCell(
                                      Text(_projectDate(data['due_date'])),
                                    ),
                                    DataCell(
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          OutlinedButton(
                                            onPressed: () =>
                                                Navigator.pushNamed(
                                                  context,
                                                  '/projects/$publicId',
                                                ),
                                            child: const Text('Detail proyek'),
                                          ),
                                          const SizedBox(width: 8),
                                          IconButton(
                                            tooltip: 'Hapus proyek $title',
                                            onPressed: () =>
                                                _handleDeleteBoard(publicId),
                                            icon: Icon(
                                              Icons.delete_outline,
                                              size: 20,
                                              color: theme.colorScheme.error,
                                            ),
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
                  const SizedBox(height: 12),
                  Wrap(
                    alignment: WrapAlignment.end,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      IconButton(
                        tooltip: 'Halaman sebelumnya',
                        icon: const Icon(Icons.chevron_left),
                        onPressed: _currentPage > 1
                            ? () {
                                setState(() => _currentPage--);
                                _fetchBoardsData();
                              }
                            : null,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text('Halaman $_currentPage dari $_totalPages'),
                      ),
                      IconButton(
                        tooltip: 'Halaman berikutnya',
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
          ),
        );
      },
    );
  }

  Widget _globalWorkloadBody(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final pagePadding = constraints.maxWidth < 600 ? 16.0 : 24.0;
        return SingleChildScrollView(
          padding: EdgeInsets.all(pagePadding),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _pageHeading(context, title: 'Analitik global'),
                  const SizedBox(height: 12),
                  GlobalWorkloadView(
                    workload: _workload,
                    loading: _workloadLoading,
                    error: _workloadError,
                    onRetry: _loadGlobalWorkload,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const Navbar(),
      body: _selectedTab == 0
          ? _projectsBody(context)
          : _globalWorkloadBody(context),
    );
  }
}
