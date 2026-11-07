import 'dart:async';

import 'package:flutter/material.dart';

import '../environment_config.dart';
import '../network.dart';
import 'task_models.dart';
import 'task_service.dart';

class BoardMembersDialog extends StatefulWidget {
  const BoardMembersDialog({
    super.key,
    required this.boardId,
    required this.expectedGeneration,
    required this.onChanged,
    required this.isViewCurrent,
  });

  final String boardId;
  final int expectedGeneration;
  final VoidCallback onChanged;
  final bool Function() isViewCurrent;

  @override
  State<BoardMembersDialog> createState() => _BoardMembersDialogState();
}

class _BoardMembersDialogState extends State<BoardMembersDialog> {
  late final int _viewGeneration;
  late final String _boardId;
  final _searchController = TextEditingController();
  Timer? _debounce;
  int _memberEpoch = 0;
  int _searchEpoch = 0;
  String _search = '';
  int _page = 1;
  List<TaskUser> _members = [];
  TaskUserPage? _results;
  final Set<String> _selectedIds = {};
  bool _membersLoading = true;
  bool _searchLoading = false;
  bool _pending = false;
  String? _membersError;
  String? _searchError;
  String? _savedRefreshError;
  bool _stale = false;

  @override
  void initState() {
    super.initState();
    _viewGeneration = widget.expectedGeneration;
    _boardId = widget.boardId;
    _loadMembers();
  }

  bool get _isCurrent =>
      mounted &&
      !_stale &&
      widget.boardId == _boardId &&
      widget.expectedGeneration == _viewGeneration &&
      EnvironmentConfig.generation == _viewGeneration &&
      widget.isViewCurrent();

  void _markStale() {
    if (!mounted || _stale) return;
    _debounce?.cancel();
    _memberEpoch++;
    _searchEpoch++;
    setState(() {
      _stale = true;
      _members = [];
      _results = null;
      _selectedIds.clear();
      _membersLoading = false;
      _searchLoading = false;
      _membersError = 'Sesi berubah, buka ulang daftar anggota';
      _searchError = null;
      _savedRefreshError = null;
    });
  }

  Future<void> _loadMembers() async {
    final epoch = ++_memberEpoch;
    if (!_isCurrent) {
      _markStale();
      return;
    }
    setState(() {
      _membersLoading = true;
      _membersError = null;
    });
    try {
      final response = await BoardService.getMembers(
        _boardId,
        expectedGeneration: _viewGeneration,
      );
      if (epoch != _memberEpoch) return;
      if (!_isCurrent) {
        _markStale();
        return;
      }
      if (response is! Map || !response.containsKey('data')) {
        throw const FormatException('Format data anggota tidak valid');
      }
      final raw = response['data'];
      if (raw == null) {
        _members = [];
      } else if (raw is List) {
        _members = raw.map((item) {
          if (item is! Map) {
            throw const FormatException('Format anggota tidak valid');
          }
          return TaskUser.fromJson(Map<String, dynamic>.from(item));
        }).toList();
      } else {
        throw const FormatException('Format daftar anggota tidak valid');
      }
      setState(() {
        _membersLoading = false;
        _membersError = null;
        _savedRefreshError = null;
      });
    } catch (error) {
      if (epoch != _memberEpoch) return;
      if (!_isCurrent) {
        _markStale();
        return;
      }
      setState(() {
        _membersLoading = false;
        _membersError = _errorText(error);
        if (_savedRefreshError != null) _savedRefreshError = _errorText(error);
      });
    }
  }

  Future<void> _loadSearch({bool showLoading = true}) async {
    final epoch = ++_searchEpoch;
    final search = _search;
    final page = _page;
    if (!_isCurrent) {
      _markStale();
      return;
    }
    if (showLoading) {
      setState(() {
        _searchLoading = true;
        _searchError = null;
      });
    }
    try {
      final result = await TaskService.searchUsers(
        search: search,
        page: page,
        expectedGeneration: _viewGeneration,
      );
      if (epoch != _searchEpoch || search != _search) return;
      if (!_isCurrent) {
        _markStale();
        return;
      }
      setState(() {
        _results = result;
        _searchLoading = false;
        _searchError = null;
      });
    } catch (error) {
      if (epoch != _searchEpoch || search != _search) return;
      if (!_isCurrent) {
        _markStale();
        return;
      }
      setState(() {
        _searchLoading = false;
        _searchError = _errorText(error);
      });
    }
  }

  void _changeSearch(String value) {
    _debounce?.cancel();
    setState(() {
      _search = value.trim();
      _page = 1;
      _results = null;
      _searchError = null;
      _selectedIds.clear();
    });
    ++_searchEpoch;
    _debounce = Timer(const Duration(seconds: 1), () => _loadSearch());
  }

  Future<void> _addSelected() async {
    final ids = _selectedIds.where((id) => !_memberIds.contains(id)).toList();
    if (_pending || ids.isEmpty) return;
    if (!_isCurrent) {
      _markStale();
      return;
    }
    var committed = false;
    setState(() {
      _pending = true;
      _savedRefreshError = null;
    });
    try {
      await BoardService.addMembers(
        _boardId,
        ids,
        expectedGeneration: _viewGeneration,
      );
      committed = true;
      if (!_isCurrent) {
        _markStale();
        return;
      }
      widget.onChanged();
      setState(() {
        _selectedIds.clear();
        _savedRefreshError = 'Anggota tersimpan, gagal memuat ulang';
      });
      await _loadMembers();
      if (_isCurrent) {
        _results = null;
        await _loadSearch();
      }
    } catch (error) {
      if (!_isCurrent) {
        _markStale();
      } else if (!committed) {
        _showError(error);
      }
    } finally {
      if (mounted) setState(() => _pending = false);
    }
  }

  Future<void> _removeMember(TaskUser user) async {
    if (_pending) return;
    if (!_isCurrent) {
      _markStale();
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Hapus anggota?'),
        content: Text(
          'Hapus ${user.displayName} (${user.displayEmail}) dari papan? Tugas yang ditugaskan tidak berubah.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!_isCurrent) {
      _markStale();
      return;
    }
    var committed = false;
    setState(() {
      _pending = true;
      _savedRefreshError = null;
    });
    try {
      await BoardService.removeMembers(_boardId, [
        user.publicId,
      ], expectedGeneration: _viewGeneration);
      committed = true;
      if (!_isCurrent) {
        _markStale();
        return;
      }
      widget.onChanged();
      setState(() {
        _selectedIds.clear();
        _savedRefreshError = 'Anggota tersimpan, gagal memuat ulang';
      });
      await _loadMembers();
      if (_isCurrent) {
        _results = null;
        await _loadSearch();
      }
    } catch (error) {
      if (!_isCurrent) {
        _markStale();
      } else if (!committed) {
        _showError(error);
      }
    } finally {
      if (mounted) setState(() => _pending = false);
    }
  }

  Set<String> get _memberIds => _members.map((user) => user.publicId).toSet();

  String _errorText(Object error) => error is UnauthorizedException
      ? 'Sesi berubah, muat ulang data'
      : error is FormatException
      ? error.message
      : error.toString();

  void _showError(Object error) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(_errorText(error))));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_stale && !_isCurrent) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _markStale();
      });
    }
    return PopScope(
      canPop: !_pending,
      child: Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 560,
            maxHeight: MediaQuery.sizeOf(context).height * .9,
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Anggota papan',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Tutup',
                      onPressed: _pending ? null : () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                if (_savedRefreshError != null)
                  MaterialBanner(
                    content: Text(_savedRefreshError!),
                    actions: [
                      TextButton(
                        onPressed: _pending ? null : _loadMembers,
                        child: const Text('Coba lagi'),
                      ),
                    ],
                  ),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 8),
                        const Text('Anggota saat ini'),
                        if (_membersLoading)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: CircularProgressIndicator(),
                            ),
                          )
                        else if (_membersError != null)
                          Column(
                            children: [
                              Text(_membersError!, textAlign: TextAlign.center),
                              TextButton(
                                onPressed: _pending ? null : _loadMembers,
                                child: const Text('Coba lagi'),
                              ),
                            ],
                          )
                        else if (_members.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(12),
                            child: Text('Belum ada anggota'),
                          )
                        else
                          ..._members.map(
                            (user) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(user.displayName),
                              subtitle: Text(user.displayEmail),
                              trailing: IconButton(
                                tooltip: 'Hapus ${user.displayName}',
                                onPressed: _pending
                                    ? null
                                    : () => _removeMember(user),
                                icon: const Icon(Icons.person_remove_outlined),
                              ),
                            ),
                          ),
                        const Divider(height: 28),
                        const Text('Cari anggota'),
                        TextField(
                          controller: _searchController,
                          enabled: !_pending,
                          decoration: const InputDecoration(
                            labelText: 'Nama atau email',
                            prefixIcon: Icon(Icons.search),
                          ),
                          onChanged: _changeSearch,
                        ),
                        const SizedBox(height: 8),
                        if (_searchLoading)
                          const Center(child: CircularProgressIndicator())
                        else if (_searchError != null)
                          Column(
                            children: [
                              Text(_searchError!, textAlign: TextAlign.center),
                              TextButton(
                                onPressed: _pending
                                    ? null
                                    : () => _loadSearch(),
                                child: const Text('Coba lagi'),
                              ),
                            ],
                          )
                        else if (_results == null)
                          const Text('Ketik untuk mencari anggota')
                        else if (_results!.users.isEmpty)
                          const Text('Tidak ada hasil')
                        else
                          ..._results!.users.map((user) {
                            final isMember = _memberIds.contains(user.publicId);
                            return CheckboxListTile(
                              value: isMember
                                  ? false
                                  : _selectedIds.contains(user.publicId),
                              onChanged: _pending || isMember
                                  ? null
                                  : (checked) => setState(() {
                                      if (checked == true) {
                                        _selectedIds.add(user.publicId);
                                      } else {
                                        _selectedIds.remove(user.publicId);
                                      }
                                    }),
                              title: Text(user.displayName),
                              subtitle: Text(user.displayEmail),
                              secondary: isMember
                                  ? const Icon(Icons.check_circle_outline)
                                  : null,
                              controlAffinity: ListTileControlAffinity.leading,
                              contentPadding: EdgeInsets.zero,
                            );
                          }),
                        if (_results != null)
                          Wrap(
                            alignment: WrapAlignment.center,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            children: [
                              IconButton(
                                tooltip: 'Halaman sebelumnya',
                                onPressed:
                                    _pending || _searchLoading || _page <= 1
                                    ? null
                                    : () {
                                        setState(() => _page--);
                                        _loadSearch();
                                      },
                                icon: const Icon(Icons.chevron_left),
                              ),
                              Text(
                                'Halaman $_page dari ${_results!.totalPages}',
                              ),
                              IconButton(
                                tooltip: 'Halaman berikutnya',
                                onPressed:
                                    _pending ||
                                        _searchLoading ||
                                        _page >= _results!.totalPages
                                    ? null
                                    : () {
                                        setState(() => _page++);
                                        _loadSearch();
                                      },
                                icon: const Icon(Icons.chevron_right),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  runSpacing: 8,
                  spacing: 8,
                  children: [
                    TextButton(
                      style: TextButton.styleFrom(
                        minimumSize: const Size(48, 48),
                      ),
                      onPressed: _pending ? null : () => Navigator.pop(context),
                      child: const Text('Batal'),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(48, 48),
                      ),
                      onPressed: _pending || !_isCurrent || _selectedIds.isEmpty
                          ? null
                          : _addSelected,
                      child: _pending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text('Tambah (${_selectedIds.length})'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
