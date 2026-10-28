import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../models/category_model.dart';
import '../../providers/category_provider.dart';
import '../../theme/app_theme.dart';

/// Form screen to add or edit a spare parts category with Cloudinary image upload.
class CategoryFormScreen extends StatefulWidget {
  final CategoryModel? categoryToEdit;

  const CategoryFormScreen({super.key, this.categoryToEdit});

  bool get isEditing => categoryToEdit != null;

  @override
  State<CategoryFormScreen> createState() => _CategoryFormScreenState();
}

class _CategoryFormScreenState extends State<CategoryFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descController;
  final ImagePicker _picker = ImagePicker();

  File? _selectedImageFile;
  String? _existingImageUrl;
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    final category = widget.categoryToEdit;
    _nameController = TextEditingController(text: category?.name ?? '');
    _descController = TextEditingController(text: category?.description ?? '');
    _existingImageUrl = category?.imageUrl;
    _isActive = category?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (picked != null) {
        setState(() {
          _selectedImageFile = File(picked.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick image: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _removeSelectedImage() {
    setState(() {
      _selectedImageFile = null;
    });
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    if (!widget.isEditing && _selectedImageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a category image.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final provider = context.read<CategoryProvider>();
    provider.clearError();

    bool success = false;

    if (widget.isEditing) {
      success = await provider.editCategory(
        id: widget.categoryToEdit!.id,
        name: _nameController.text.trim(),
        newImageFile: _selectedImageFile,
        currentImageUrl: _existingImageUrl ?? '',
        description: _descController.text.trim(),
        isActive: _isActive,
      );
    } else {
      success = await provider.addCategory(
        name: _nameController.text.trim(),
        imageFile: _selectedImageFile!,
        description: _descController.text.trim(),
        isActive: _isActive,
      );
    }

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isEditing
                ? 'Category updated successfully.'
                : 'Category created successfully.',
          ),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CategoryProvider>();
    final hasImage = _selectedImageFile != null || (_existingImageUrl != null && _existingImageUrl!.isNotEmpty);

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppColors.darkCharcoal,
        elevation: 0,
        title: Text(
          widget.isEditing ? 'Edit Category' : 'Add Spare Parts Category',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 17,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        physics: const BouncingScrollPhysics(),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Error Banner
              if (provider.errorMessage != null) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 18),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppColors.error, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          provider.errorMessage!,
                          style: const TextStyle(color: AppColors.error, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // CATEGORY IMAGE PICKER
              const Text(
                'Category Image *',
                style: TextStyle(
                  color: AppColors.darkCharcoal,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),

              Center(
                child: Stack(
                  children: [
                    Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: hasImage ? AppColors.primaryGold : Colors.grey.shade300,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: _selectedImageFile != null
                            ? Image.file(
                                _selectedImageFile!,
                                width: 150,
                                height: 150,
                                fit: BoxFit.cover,
                              )
                            : (_existingImageUrl != null && _existingImageUrl!.isNotEmpty
                                ? Image.network(
                                    _existingImageUrl!,
                                    width: 150,
                                    height: 150,
                                    fit: BoxFit.cover,
                                    loadingBuilder: (ctx, child, progress) {
                                      if (progress == null) return child;
                                      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                                    },
                                    errorBuilder: (ctx, err, stack) => const Icon(
                                      Icons.broken_image_outlined,
                                      size: 40,
                                      color: Colors.grey,
                                    ),
                                  )
                                : Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: provider.isSaving ? null : _pickImage,
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: const [
                                          Icon(
                                            Icons.add_photo_alternate_outlined,
                                            size: 44,
                                            color: AppColors.primaryGold,
                                          ),
                                          SizedBox(height: 6),
                                          Text(
                                            'Select Image',
                                            style: TextStyle(
                                              color: AppColors.secondaryText,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )),
                      ),
                    ),
                    if (hasImage && !provider.isSaving)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: CircleAvatar(
                          radius: 18,
                          backgroundColor: AppColors.darkCharcoal,
                          child: IconButton(
                            icon: const Icon(Icons.edit, size: 16, color: AppColors.primaryGold),
                            onPressed: _pickImage,
                            tooltip: 'Change Image',
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              if (_selectedImageFile != null && !provider.isSaving) ...[
                const SizedBox(height: 8),
                Center(
                  child: TextButton.icon(
                    onPressed: _removeSelectedImage,
                    icon: const Icon(Icons.delete_outline, size: 16, color: AppColors.error),
                    label: const Text('Remove Selected Image', style: TextStyle(color: AppColors.error, fontSize: 12)),
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Category Name Field
              const Text(
                'Category Name *',
                style: TextStyle(
                  color: AppColors.darkCharcoal,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                enabled: !provider.isSaving,
                decoration: const InputDecoration(
                  hintText: 'e.g. Engine Parts, Brake Systems, Transmission...',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Category name is required';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 18),

              // Description Field (Optional)
              const Text(
                'Description (Optional)',
                style: TextStyle(
                  color: AppColors.darkCharcoal,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _descController,
                maxLines: 3,
                enabled: !provider.isSaving,
                decoration: const InputDecoration(
                  hintText: 'Notes regarding components, sub-assemblies, or vehicle systems...',
                  alignLabelWithHint: true,
                ),
              ),

              const SizedBox(height: 20),

              // Active Status Toggle
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Category Visibility',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                        Text(
                          _isActive ? 'Active in parts catalog' : 'Inactive / Hidden',
                          style: TextStyle(
                            color: _isActive ? AppColors.success : AppColors.error,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    Switch(
                      value: _isActive,
                      activeThumbColor: AppColors.primaryGold,
                      onChanged: provider.isSaving
                          ? null
                          : (val) => setState(() => _isActive = val),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Submit Button
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: provider.isSaving ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGold,
                    foregroundColor: AppColors.darkCharcoal,
                  ),
                  child: provider.isSaving
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.darkCharcoal,
                              ),
                            ),
                            SizedBox(width: 12),
                            Text('Uploading & Saving Category...'),
                          ],
                        )
                      : Text(
                          widget.isEditing ? 'Update Category' : 'Save Category',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
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
