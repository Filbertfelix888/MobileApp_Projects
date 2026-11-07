import 'package:flutter/material.dart';

import '../Task/kanban_board.dart';
import '../environment_config.dart';

import '../Home/navbar_page.dart';
import '../network.dart';

class ProjectDetailPage extends StatefulWidget {
  const ProjectDetailPage({super.key, required this.boardId});

  final String boardId;

  @override
  State<ProjectDetailPage> createState() => _ProjectDetailPageState();
}

class _ProjectDetailPageState extends State<ProjectDetailPage> {
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _board;
  int _requestId = 0;
  late final int _viewGeneration;

  @override
  void initState() {
    super.initState();
    _viewGeneration = EnvironmentConfig.generation;
    _fetchBoard();
  }

  @override
  void didUpdateWidget(covariant ProjectDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.boardId == oldWidget.boardId) return;
    _requestId++;
    setState(() {
      _board = null;
      _isLoading = true;
      _error = null;
    });
    _fetchBoard();
  }

  Future<void> _fetchBoard() async {
    if (EnvironmentConfig.generation != _viewGeneration) {
      if (mounted) {
        setState(() {
          _board = null;
          _isLoading = false;
          _error = 'Sesi berubah, buka ulang proyek';
        });
      }
      return;
    }
    final boardId = widget.boardId;
    final requestId = ++_requestId;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await BoardService.getBoard(
        boardId,
        expectedGeneration: _viewGeneration,
      );
      if (!mounted || requestId != _requestId) return;
      if (boardId != widget.boardId) return;
      if (EnvironmentConfig.generation != _viewGeneration) {
        setState(() {
          _board = null;
          _isLoading = false;
          _error = 'Sesi berubah, buka ulang proyek';
        });
        return;
      }
      final data = response is Map ? response['data'] : null;
      if (data is! Map) throw Exception('Data proyek tidak valid');
      setState(() {
        _board = Map<String, dynamic>.from(data);
        _isLoading = false;
      });
    } catch (error) {
      if (mounted && requestId == _requestId && boardId == widget.boardId) {
        setState(() {
          if (EnvironmentConfig.generation != _viewGeneration) {
            _board = null;
            _error = 'Sesi berubah, buka ulang proyek';
          } else if (error is! UnauthorizedException) {
            _error = error.toString().replaceAll('Exception: ', '');
          }
          _isLoading = false;
        });
      }
    }
  }

  String _date(Object? value) {
    final text = value?.toString() ?? '';
    if (text.isEmpty) return '-';
    final parsed = DateTime.tryParse(text);
    return parsed?.toLocal().toIso8601String().split('T').first ??
        text.split('T').first;
  }

  Widget _field(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(value, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }

  Widget _body() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final board = _board;
    if (_error != null || board == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error ?? 'Gagal memuat proyek'),
            const SizedBox(height: 12),
            if (EnvironmentConfig.generation == _viewGeneration)
              ElevatedButton(
                onPressed: _fetchBoard,
                child: const Text('Coba lagi'),
              )
            else
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Kembali'),
              ),
          ],
        ),
      );
    }
    final description = board['description']?.toString() ?? '';
    return Column(
      children: [
        Flexible(
          flex: 1,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Kembali'),
                  ),
                ),
                Text(
                  board['title']?.toString() ?? '-',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                _field('Deskripsi', description.isEmpty ? '-' : description),
                _field('Tanggal dibuat', _date(board['created_at'])),
                _field('Tenggat', _date(board['due_date'])),
              ],
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: KanbanBoard(
            key: ValueKey(widget.boardId),
            boardId: widget.boardId,
            boardTitle: board['title']?.toString() ?? '-',
            boardDueDate: board['due_date']?.toString(),
            expectedGeneration: _viewGeneration,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: const Navbar(), body: _body());
  }
}
