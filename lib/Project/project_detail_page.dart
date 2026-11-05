import 'package:flutter/material.dart';

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

  @override
  void initState() {
    super.initState();
    _fetchBoard();
  }

  Future<void> _fetchBoard() async {
    final requestId = ++_requestId;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await BoardService.getBoard(widget.boardId);
      if (!mounted || requestId != _requestId) return;
      final data = response is Map ? response['data'] : null;
      if (data is! Map) throw Exception('Data proyek tidak valid');
      setState(() {
        _board = Map<String, dynamic>.from(data);
        _isLoading = false;
      });
    } catch (error) {
      if (mounted && requestId == _requestId) {
        setState(() {
          if (error is! UnauthorizedException) {
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
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 16)),
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
            ElevatedButton(onPressed: _fetchBoard, child: const Text('Coba lagi')),
          ],
        ),
      );
    }
    final description = board['description']?.toString() ?? '';
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Kembali'),
          ),
          const SizedBox(height: 8),
          Text(
            board['title']?.toString() ?? '-',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _field('Deskripsi', description.isEmpty ? '-' : description),
          _field('Tanggal dibuat', _date(board['created_at'])),
          _field('Tenggat', _date(board['due_date'])),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: const Navbar(), body: _body());
  }
}
