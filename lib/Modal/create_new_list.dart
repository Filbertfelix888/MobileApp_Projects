import 'package:flutter/material.dart';
import '../network.dart';

class CreateNewList extends StatefulWidget {
  final String boardPublicId;
  final VoidCallback onSuccess;

  const CreateNewList({
    super.key,
    required this.boardPublicId,
    required this.onSuccess,
  });

  @override
  State<CreateNewList> createState() => _CreateNewListState();
}

class _CreateNewListState extends State<CreateNewList> {
  bool _showForm = false;
  bool _isLoading = false;
  final _titleController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  Future<void> _onSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final payload = {
        'title': _titleController.text,
        'board_public_id': widget.boardPublicId,
      };

      await ListService.createList(payload);

      if (mounted) {
        _titleController.clear();
        setState(() => _showForm = false);
        widget.onSuccess(); // Refresh daftar list board
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

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      child: _showForm
          ? Card(
              elevation: 2,
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: _titleController,
                        autofocus: true,
                        decoration: const InputDecoration(
                          hintText: 'Nama daftar tugas',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          isDense: true,
                        ),
                        validator: (val) =>
                            (val == null || val.trim().isEmpty) ? 'Nama daftar tugas wajib diisi' : null,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          ElevatedButton(
                            onPressed: _isLoading ? null : _onSubmit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1976D2),
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Text('Simpan', style: TextStyle(color: Colors.white, fontSize: 12)),
                          ),
                          const SizedBox(width: 4),
                          OutlinedButton(
                            onPressed: _isLoading ? null : () => setState(() => _showForm = false),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                            ),
                            child: const Text('Batal', style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            )
          : ElevatedButton.icon(
              onPressed: () => setState(() => _showForm = true),
              icon: const Icon(Icons.add_sharp, size: 18, color: Colors.white),
              label: const Text(
                'BUAT DAFTAR TUGAS',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1976D2),
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
            ),
    );
  }
}