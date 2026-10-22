import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../models/product_model.dart';
import '../../providers/category_provider.dart';
import '../../providers/company_provider.dart';
import '../../providers/product_provider.dart';
import '../../theme/app_theme.dart';

/// Form screen for adding or editing an automotive spare part product.
class ProductFormScreen extends StatefulWidget {
  final ProductModel? productToEdit;

  const ProductFormScreen({super.key, this.productToEdit});

  bool get isEditing => productToEdit != null;

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _applicationController;
  late TextEditingController _descriptionController;
  late TextEditingController _refNoController;
  late TextEditingController _displacementController;
  late TextEditingController _maxPressureController;
  late TextEditingController _controlledFlowController;
  late TextEditingController _speedRangeController;
  late TextEditingController _fuelFeedHoleController;
  late TextEditingController _priceController;
  late TextEditingController _stockController;

  String? _selectedCompanyId;
  String? _selectedCompanyName;
  String? _selectedCategoryId;
  String? _selectedCategoryName;
  String? _selectedRotation;

  File? _pickedImageFile;
  String? _existingImageUrl;
  bool _isActive = true;

  final ImagePicker _picker = ImagePicker();

  static const List<String> _rotationOptions = [
    'Right (Clockwise)',
    'Left (Counter-Clockwise)',
    'Bi-directional / Reversible',
  ];

  @override
  void initState() {
    super.initState();
    final p = widget.productToEdit;

    _nameController = TextEditingController(text: p?.name ?? '');
    _applicationController = TextEditingController(text: p?.application ?? '');
    _descriptionController = TextEditingController(text: p?.description ?? '');
    _refNoController = TextEditingController(text: p?.refNo ?? '');
    _displacementController = TextEditingController(text: p?.displacement ?? '');
    _maxPressureController = TextEditingController(text: p?.maxPressure ?? '');
    _controlledFlowController = TextEditingController(text: p?.controlledFlow ?? '');
    _speedRangeController = TextEditingController(text: p?.speedRange ?? '');
    _fuelFeedHoleController = TextEditingController(text: p?.fuelFeedHole ?? '');
    _priceController = TextEditingController(text: p?.price != null ? p!.price!.toStringAsFixed(2) : '');
    _stockController = TextEditingController(text: p?.stockQuantity != null ? p!.stockQuantity.toString() : '');

    _selectedCompanyId = p?.companyId;
    _selectedCompanyName = p?.companyName;
    _selectedCategoryId = p?.categoryId;
    _selectedCategoryName = p?.categoryName;
    _selectedRotation = p?.rotation;

    _existingImageUrl = p?.imageUrl;
    _isActive = p?.isActive ?? true;

    // Ensure company and category catalogs are loaded for dropdown selection
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final compProvider = context.read<CompanyProvider>();
      if (compProvider.companies.isEmpty) {
        compProvider.fetchCompanies();
      }

      final catProvider = context.read<CategoryProvider>();
      if (catProvider.categories.isEmpty) {
        catProvider.fetchCategories();
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _applicationController.dispose();
    _descriptionController.dispose();
    _refNoController.dispose();
    _displacementController.dispose();
    _maxPressureController.dispose();
    _controlledFlowController.dispose();
    _speedRangeController.dispose();
    _fuelFeedHoleController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1400,
        maxHeight: 1400,
        imageQuality: 85,
      );
      if (picked != null) {
        setState(() {
          _pickedImageFile = File(picked.path);
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to pick image: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text(
                'Select Product Photo',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.darkCharcoal,
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined, color: AppColors.primaryGold),
                title: const Text('Take a photo with Camera'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: AppColors.primaryGold),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Image validation (mandatory on create)
    if (!widget.isEditing && _pickedImageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a product photo.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_selectedCompanyId == null || _selectedCompanyId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a vehicle manufacturer/company.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_selectedCategoryId == null || _selectedCategoryId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a spare parts category.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final provider = context.read<ProductProvider>();
    provider.clearError();

    final price = double.tryParse(_priceController.text.trim());
    final stock = int.tryParse(_stockController.text.trim());

    bool success = false;

    if (widget.isEditing) {
      success = await provider.editProduct(
        id: widget.productToEdit!.id,
        name: _nameController.text.trim(),
        currentImageUrl: _existingImageUrl ?? '',
        newImageFile: _pickedImageFile,
        companyId: _selectedCompanyId!,
        companyName: _selectedCompanyName ?? '',
        categoryId: _selectedCategoryId!,
        categoryName: _selectedCategoryName ?? '',
        application: _applicationController.text.trim(),
        description: _descriptionController.text.trim(),
        refNo: _refNoController.text.trim(),
        displacement: _displacementController.text.trim(),
        maxPressure: _maxPressureController.text.trim(),
        controlledFlow: _controlledFlowController.text.trim(),
        speedRange: _speedRangeController.text.trim(),
        rotation: _selectedRotation,
        fuelFeedHole: _fuelFeedHoleController.text.trim(),
        price: price,
        stockQuantity: stock,
        isActive: _isActive,
      );
    } else {
      success = await provider.addProduct(
        name: _nameController.text.trim(),
        imageFile: _pickedImageFile!,
        companyId: _selectedCompanyId!,
        companyName: _selectedCompanyName ?? '',
        categoryId: _selectedCategoryId!,
        categoryName: _selectedCategoryName ?? '',
        application: _applicationController.text.trim(),
        description: _descriptionController.text.trim(),
        refNo: _refNoController.text.trim(),
        displacement: _displacementController.text.trim(),
        maxPressure: _maxPressureController.text.trim(),
        controlledFlow: _controlledFlowController.text.trim(),
        speedRange: _speedRangeController.text.trim(),
        rotation: _selectedRotation,
        fuelFeedHole: _fuelFeedHoleController.text.trim(),
        price: price,
        stockQuantity: stock,
        isActive: _isActive,
      );
    }

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isEditing
                ? 'Product updated successfully.'
                : 'Product added to catalog successfully.',
          ),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProductProvider>();
    final companyProvider = context.watch<CompanyProvider>();
    final categoryProvider = context.watch<CategoryProvider>();

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppColors.darkCharcoal,
        elevation: 0,
        title: Text(
          widget.isEditing ? 'Edit Spare Part' : 'Add New Spare Part',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 17,
          ),
        ),
      ),
      body: SingleChildScrollView(
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

              // --- 1. PHOTO PICKER CONTAINER ---
              Center(
                child: GestureDetector(
                  onTap: provider.isSaving ? null : _showImageSourceDialog,
                  child: Container(
                    width: double.infinity,
                    height: 190,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _pickedImageFile != null || _existingImageUrl != null
                            ? AppColors.primaryGold
                            : Colors.grey.shade300,
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          if (_pickedImageFile != null)
                            Image.file(
                              _pickedImageFile!,
                              width: double.infinity,
                              height: double.infinity,
                              fit: BoxFit.cover,
                            )
                          else if (_existingImageUrl != null && _existingImageUrl!.isNotEmpty)
                            Image.network(
                              _existingImageUrl!,
                              width: double.infinity,
                              height: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => const Icon(
                                Icons.broken_image_outlined,
                                size: 50,
                                color: Colors.grey,
                              ),
                            )
                          else
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryGold.withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.add_a_photo_outlined,
                                    size: 32,
                                    color: AppColors.primaryGold,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                const Text(
                                  'Upload Product Photo *',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.darkCharcoal,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Tap to choose from Camera or Gallery',
                                  style: TextStyle(color: Colors.grey, fontSize: 12),
                                ),
                              ],
                            ),

                          // Edit floating badge if image exists
                          if (_pickedImageFile != null || (_existingImageUrl != null && _existingImageUrl!.isNotEmpty))
                            Positioned(
                              bottom: 12,
                              right: 12,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.darkCharcoal.withValues(alpha: 0.85),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Icon(Icons.edit, color: AppColors.primaryGold, size: 14),
                                    SizedBox(width: 4),
                                    Text(
                                      'Change Photo',
                                      style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // --- 2. MANDATORY DETAILS CARD ---
              _buildSectionHeader('Mandatory Information', Icons.info_outline),
              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Product Name
                    _buildFieldLabel('Product Name *'),
                    TextFormField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      enabled: !provider.isSaving,
                      decoration: const InputDecoration(
                        hintText: 'e.g. Power Steering Pump',
                        prefixIcon: Icon(Icons.precision_manufacturing_outlined),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Product name is required';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // Company Dropdown
                    _buildFieldLabel('Vehicle Company / Brand *'),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _selectedCompanyId,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.business_outlined),
                        hintText: 'Select vehicle company',
                      ),
                      items: companyProvider.companies.map((c) {
                        return DropdownMenuItem<String>(
                          value: c.id,
                          child: Text(
                            c.name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        );
                      }).toList(),
                      onChanged: provider.isSaving
                          ? null
                          : (val) {
                              if (val != null) {
                                final matched = companyProvider.companies.firstWhere((c) => c.id == val);
                                setState(() {
                                  _selectedCompanyId = val;
                                  _selectedCompanyName = matched.name;
                                });
                              }
                            },
                      validator: (val) => val == null || val.isEmpty ? 'Please select a company' : null,
                    ),

                    const SizedBox(height: 16),

                    // Category Dropdown
                    _buildFieldLabel('Part Category *'),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _selectedCategoryId,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.category_outlined),
                        hintText: 'Select part category',
                      ),
                      items: categoryProvider.categories.map((c) {
                        return DropdownMenuItem<String>(
                          value: c.id,
                          child: Text(
                            c.name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        );
                      }).toList(),
                      onChanged: provider.isSaving
                          ? null
                          : (val) {
                              if (val != null) {
                                final matched = categoryProvider.categories.firstWhere((c) => c.id == val);
                                setState(() {
                                  _selectedCategoryId = val;
                                  _selectedCategoryName = matched.name;
                                });
                              }
                            },
                      validator: (val) => val == null || val.isEmpty ? 'Please select a category' : null,
                    ),

                    const SizedBox(height: 16),

                    // Application Field
                    _buildFieldLabel('Application (Vehicle / Engine Compatibility) *'),
                    TextFormField(
                      controller: _applicationController,
                      maxLines: 2,
                      enabled: !provider.isSaving,
                      decoration: const InputDecoration(
                        hintText: 'e.g. Toyota Hilux Vigo 2.5/3.0 D-4D 2005-2015 / Fortuner',
                        prefixIcon: Icon(Icons.directions_car_outlined),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Application details are required';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // Description / Review Field
                    _buildFieldLabel('Detailed Description / Review / Notes (Optional)'),
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 3,
                      enabled: !provider.isSaving,
                      decoration: const InputDecoration(
                        hintText: 'e.g. Detailed product review, material grade, installation tips, warranty notes...',
                        prefixIcon: Icon(Icons.notes_rounded),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // --- 3. TECHNICAL SPECIFICATIONS (NON-MANDATORY) ---
              _buildSectionHeader('Technical Specifications (Non-mandatory)', Icons.build_circle_outlined),
              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Ref No / OEM Part No
                    _buildFieldLabel('Part / OEM Reference No (Ref No)'),
                    TextFormField(
                      controller: _refNoController,
                      enabled: !provider.isSaving,
                      decoration: const InputDecoration(
                        hintText: 'e.g. 44310-0K040 / 44310-0K020',
                        prefixIcon: Icon(Icons.tag_rounded),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Displacement & Max Pressure (Two per row)
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildFieldLabel('Displacement'),
                              TextFormField(
                                controller: _displacementController,
                                enabled: !provider.isSaving,
                                decoration: const InputDecoration(
                                  hintText: 'e.g. 16.0 ml/r',
                                  prefixIcon: Icon(Icons.speed_outlined),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildFieldLabel('Max Pressure'),
                              TextFormField(
                                controller: _maxPressureController,
                                enabled: !provider.isSaving,
                                decoration: const InputDecoration(
                                  hintText: 'e.g. 120 bar',
                                  prefixIcon: Icon(Icons.compress_outlined),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Controlled Flow & Speed Range
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildFieldLabel('Controlled Flow'),
                              TextFormField(
                                controller: _controlledFlowController,
                                enabled: !provider.isSaving,
                                decoration: const InputDecoration(
                                  hintText: 'e.g. 9.0 L/min',
                                  prefixIcon: Icon(Icons.water_drop_outlined),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildFieldLabel('Speed Range'),
                              TextFormField(
                                controller: _speedRangeController,
                                enabled: !provider.isSaving,
                                decoration: const InputDecoration(
                                  hintText: 'e.g. 600-4500 r/min',
                                  prefixIcon: Icon(Icons.av_timer_outlined),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Rotation Dropdown
                    _buildFieldLabel('Rotation Direction'),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _selectedRotation,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.rotate_right_rounded),
                        hintText: 'Select rotation direction',
                      ),
                      items: _rotationOptions.map((opt) {
                        return DropdownMenuItem<String>(
                          value: opt,
                          child: Text(opt, overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: provider.isSaving
                          ? null
                          : (val) => setState(() => _selectedRotation = val),
                    ),

                    const SizedBox(height: 16),

                    // Fuel Feed Hole
                    _buildFieldLabel('Fuel Feed Hole / Port Spec'),
                    TextFormField(
                      controller: _fuelFeedHoleController,
                      enabled: !provider.isSaving,
                      decoration: const InputDecoration(
                        hintText: 'e.g. M16 x 1.5 or 3/4"-16 UNF',
                        prefixIcon: Icon(Icons.radio_button_checked_rounded),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // --- 4. COMMERCIAL (PRICE & STOCK) ---
              _buildSectionHeader('Inventory & Commercial (Optional)', Icons.payments_outlined),
              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildFieldLabel('Price (Optional)'),
                          TextFormField(
                            controller: _priceController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            enabled: !provider.isSaving,
                            decoration: const InputDecoration(
                              hintText: 'e.g. 250.00',
                              prefixIcon: Icon(Icons.attach_money_rounded),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildFieldLabel('Stock Quantity'),
                          TextFormField(
                            controller: _stockController,
                            keyboardType: TextInputType.number,
                            enabled: !provider.isSaving,
                            decoration: const InputDecoration(
                              hintText: 'e.g. 10',
                              prefixIcon: Icon(Icons.inventory_2_outlined),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // --- 5. AVAILABILITY STATUS TOGGLE ---
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
                          'Catalog Status',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                        Text(
                          _isActive ? 'Active (Visible in catalog)' : 'Inactive (Hidden from users)',
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
                      onChanged: provider.isSaving ? null : (val) => setState(() => _isActive = val),
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
                            Text('Saving Product...'),
                          ],
                        )
                      : Text(
                          widget.isEditing ? 'Update Product' : 'Add Product to Catalog',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primaryGold),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: AppColors.darkCharcoal,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.darkCharcoal,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
