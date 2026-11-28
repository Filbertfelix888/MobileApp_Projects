import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'profile_store.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _customRoleController = TextEditingController();
  final _phoneController = TextEditingController();
  final _bioController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isPickingImage = false;
  String? _selectedRoleOption;
  int _selectedColorValue = ProfileStore.avatarColors.first;
  ProfileAvatarPreset _selectedPreset = ProfileAvatarPreset.initials;
  String? _avatarBase64;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final profile = await ProfileStore.loadProfile();
    if (!mounted) return;

    final existingRole = profile.role.trim();
    String? dropdownRole;
    if (existingRole.isEmpty) {
      dropdownRole = null;
    } else if (ProfileStore.roleOptions.contains(existingRole) &&
        existingRole != 'Lainnya') {
      dropdownRole = existingRole;
    } else {
      dropdownRole = 'Lainnya';
      _customRoleController.text = existingRole;
    }

    setState(() {
      _nameController.text = profile.name == 'User' && profile.email.isEmpty
          ? ''
          : profile.name;
      _emailController.text = profile.email;
      _selectedRoleOption = dropdownRole;
      _phoneController.text = profile.phone;
      _bioController.text = profile.bio;
      _selectedColorValue =
          ProfileStore.avatarColors.contains(profile.avatarColorValue)
          ? profile.avatarColorValue
          : ProfileStore.avatarColors.first;
      _selectedPreset = profile.avatarPreset;
      _avatarBase64 = profile.avatarBase64;
      _isLoading = false;
    });
  }

  String get _effectiveRole {
    if (_selectedRoleOption == null) return '';
    if (_selectedRoleOption == 'Lainnya') {
      return _customRoleController.text.trim();
    }
    return _selectedRoleOption!;
  }

  String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  Uint8List? get _avatarBytes {
    final encoded = _avatarBase64;
    if (encoded == null || encoded.isEmpty) return null;
    try {
      return base64Decode(encoded);
    } catch (_) {
      return null;
    }
  }

  Future<void> _pickPhoto() async {
    if (_isPickingImage || _isSaving) return;
    setState(() => _isPickingImage = true);

    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 256,
        maxHeight: 256,
        imageQuality: 70,
      );
      if (picked == null || !mounted) return;

      final bytes = await picked.readAsBytes();
      if (!mounted) return;

      if (bytes.length > ProfileStore.maxAvatarBytes) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Ukuran foto terlalu besar (maks 200 KB setelah kompresi).',
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        return;
      }

      setState(() {
        _avatarBase64 = base64Encode(bytes);
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memilih foto: $error'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isPickingImage = false);
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate() || _isSaving) return;

    setState(() => _isSaving = true);
    try {
      final updated = ProfileData(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        role: _effectiveRole,
        phone: _phoneController.text.trim(),
        bio: _bioController.text.trim(),
        avatarColorValue: _selectedColorValue,
        avatarPresetId: _selectedPreset.id,
        avatarBase64: _avatarBase64,
        hasCustomAvatar: true,
      );
      await ProfileStore.saveProfile(updated);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil berhasil diperbarui')),
      );
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceAll('Exception: ', '')),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Widget _buildAvatarPreview(String displayName) {
    final photoBytes = _avatarBytes;
    if (photoBytes != null) {
      return CircleAvatar(
        radius: 42,
        backgroundColor: Color(_selectedColorValue),
        backgroundImage: MemoryImage(photoBytes),
      );
    }

    final presetIcon = _selectedPreset.icon;
    return CircleAvatar(
      radius: 42,
      backgroundColor: Color(_selectedColorValue),
      child: presetIcon != null
          ? Icon(presetIcon, size: 36, color: Colors.white)
          : Text(
              _initials(displayName),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _customRoleController.dispose();
    _phoneController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final displayName = _nameController.text.trim().isEmpty
        ? 'User'
        : _nameController.text.trim();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profil'),
        backgroundColor: theme.cardColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: theme.dividerColor),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Profile Avatar & Identity Card
                      Card(
                        margin: EdgeInsets.zero,
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              _buildAvatarPreview(displayName),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                alignment: WrapAlignment.center,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: _isPickingImage
                                        ? null
                                        : _pickPhoto,
                                    icon: _isPickingImage
                                        ? const SizedBox(
                                            width: 14,
                                            height: 14,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.photo_library_outlined,
                                            size: 18,
                                          ),
                                    label: Text(
                                      _avatarBase64 != null
                                          ? 'Ganti Foto'
                                          : 'Upload Foto',
                                    ),
                                  ),
                                  if (_avatarBase64 != null)
                                    TextButton.icon(
                                      onPressed: () =>
                                          setState(() => _avatarBase64 = null),
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        size: 18,
                                      ),
                                      label: const Text('Hapus Foto'),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                displayName,
                                style: theme.textTheme.titleLarge,
                                textAlign: TextAlign.center,
                              ),
                              if (_effectiveRole.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colors.primaryContainer,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    _effectiveRole,
                                    style: theme.textTheme.labelMedium
                                        ?.copyWith(
                                          color: colors.onPrimaryContainer,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                ),
                              ],
                              if (_emailController.text.trim().isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  _emailController.text.trim(),
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 16),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Avatar Preset (jika tanpa foto)',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: ProfileAvatarPreset.values.map((
                                  preset,
                                ) {
                                  final selected = preset == _selectedPreset;
                                  return ChoiceChip(
                                    key: ValueKey('avatar-${preset.id}'),
                                    selected: selected,
                                    label: Text(preset.label),
                                    avatar: Icon(
                                      preset.icon ?? Icons.text_fields,
                                      size: 16,
                                    ),
                                    onSelected: (isSelected) {
                                      if (!isSelected) return;
                                      setState(() => _selectedPreset = preset);
                                    },
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 14),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Warna Avatar',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 10,
                                runSpacing: 8,
                                children: ProfileStore.avatarColors.map((
                                  colorValue,
                                ) {
                                  final isSelected =
                                      colorValue == _selectedColorValue;
                                  return InkWell(
                                    onTap: () => setState(
                                      () => _selectedColorValue = colorValue,
                                    ),
                                    customBorder: const CircleBorder(),
                                    child: Container(
                                      width: 34,
                                      height: 34,
                                      decoration: BoxDecoration(
                                        color: Color(colorValue),
                                        shape: BoxShape.circle,
                                        border: isSelected
                                            ? Border.all(
                                                color: colors.onSurface,
                                                width: 2.5,
                                              )
                                            : null,
                                      ),
                                      child: isSelected
                                          ? const Icon(
                                              Icons.check,
                                              size: 18,
                                              color: Colors.white,
                                            )
                                          : null,
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Profile Details Form Card
                      Card(
                        margin: EdgeInsets.zero,
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                TextFormField(
                                  controller: _nameController,
                                  onChanged: (_) => setState(() {}),
                                  decoration: const InputDecoration(
                                    labelText: 'Nama Lengkap',
                                    prefixIcon: Icon(Icons.person_outline),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Nama lengkap wajib diisi';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 14),
                                TextFormField(
                                  controller: _emailController,
                                  readOnly: _emailController.text.isNotEmpty,
                                  keyboardType: TextInputType.emailAddress,
                                  decoration: InputDecoration(
                                    labelText: 'Email',
                                    prefixIcon: const Icon(
                                      Icons.email_outlined,
                                    ),
                                    helperText: _emailController.text.isNotEmpty
                                        ? 'Email akun terdaftar'
                                        : null,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                DropdownButtonFormField<String>(
                                  initialValue: _selectedRoleOption,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Jabatan / Role',
                                    prefixIcon: Icon(Icons.work_outline),
                                  ),
                                  hint: const Text('Pilih jabatan atau role'),
                                  items: ProfileStore.roleOptions
                                      .map(
                                        (role) => DropdownMenuItem<String>(
                                          value: role,
                                          child: Text(role),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedRoleOption = value;
                                      if (value != 'Lainnya') {
                                        _customRoleController.clear();
                                      }
                                    });
                                  },
                                ),
                                if (_selectedRoleOption == 'Lainnya') ...[
                                  const SizedBox(height: 14),
                                  TextFormField(
                                    controller: _customRoleController,
                                    onChanged: (_) => setState(() {}),
                                    decoration: const InputDecoration(
                                      labelText: 'Tulis Jabatan / Role',
                                      prefixIcon: Icon(Icons.badge_outlined),
                                    ),
                                    validator: (value) {
                                      if (_selectedRoleOption == 'Lainnya' &&
                                          (value == null ||
                                              value.trim().isEmpty)) {
                                        return 'Mohon isi jabatan atau role';
                                      }
                                      return null;
                                    },
                                  ),
                                ],
                                const SizedBox(height: 14),
                                TextFormField(
                                  controller: _phoneController,
                                  keyboardType: TextInputType.phone,
                                  decoration: const InputDecoration(
                                    labelText: 'Nomor Telepon',
                                    hintText: 'Contoh: 08123456789',
                                    prefixIcon: Icon(Icons.phone_outlined),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                TextFormField(
                                  controller: _bioController,
                                  maxLines: 3,
                                  decoration: const InputDecoration(
                                    labelText: 'Bio',
                                    hintText:
                                        'Ceritakan sedikit tentang Anda...',
                                    prefixIcon: Icon(Icons.info_outline),
                                    alignLabelWithHint: true,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: _isSaving
                                            ? null
                                            : () => Navigator.pop(context),
                                        child: const Text('Batal'),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      flex: 2,
                                      child: FilledButton(
                                        onPressed: _isSaving
                                            ? null
                                            : _saveProfile,
                                        child: _isSaving
                                            ? SizedBox(
                                                width: 18,
                                                height: 18,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: colors.onPrimary,
                                                    ),
                                              )
                                            : const Text('Simpan Perubahan'),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
