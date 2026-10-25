import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../models/product_model.dart';
import '../../providers/category_provider.dart';
import '../../providers/company_provider.dart';
import '../../providers/product_provider.dart';
import '../../theme/app_theme.dart';

/// Professional automotive spare parts product studio form with modern e-commerce UX,
/// dedicated photography studio uploader, live stock preview, and organized specification cards.
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

    // Ensure company and category catalogs are loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final compProvider = context.read<CompanyProvider>();
      if (compProvider.companies.isEmpty) compProvider.fetchCompanies();

      final catProvider = context.read<CategoryProvider>();
      if (catProvider.categories.isEmpty) catProvider.fetchCategories();
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all required fields correctly.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Image validation (mandatory on create)
    if (!widget.isEditing && _pickedImageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload a product photo for the catalog.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_selectedCompanyId == null || _selectedCompanyId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a vehicle manufacturer / brand.'),
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

    final cleanPriceStr = _priceController.text.trim().replaceAll(',', '');
    final price = cleanPriceStr.isNotEmpty ? double.tryParse(cleanPriceStr) : null;
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.isEditing ? 'Edit Spare Part' : 'Add New Spare Part',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 17,
              ),
            ),
            Text(
              widget.isEditing ? 'ID: ${widget.productToEdit!.id}' : 'E-Commerce Product Studio',
              style: TextStyle(
                color: AppColors.lightGold.withValues(alpha: 0.9),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomActionBar(provider),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        physics: const BouncingScrollPhysics(),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- 1. PHOTOGRAPHY STUDIO HERO ---
              _buildPhotographyStudio(),

              const SizedBox(height: 20),

              // --- 2. GENERAL PRODUCT INFORMATION ---
              _buildSectionHeader('General Information', Icons.info_outline, isMandatory: true),
              const SizedBox(height: 10),
              _buildGeneralInfoCard(companyProvider, categoryProvider, provider),

              const SizedBox(height: 20),

              // --- 3. COMMERCIAL PRICING & INVENTORY ---
              _buildSectionHeader('Pricing & Inventory', Icons.payments_outlined, isMandatory: false),
              const SizedBox(height: 10),
              _buildPricingAndInventoryCard(provider),

              const SizedBox(height: 20),

              // --- 4. VEHICLE APPLICATION & FITMENT ---
              _buildSectionHeader('Vehicle Application & Compatibility', Icons.directions_car_outlined, isMandatory: true),
              const SizedBox(height: 10),
              _buildFitmentCard(provider),

              const SizedBox(height: 20),

              // --- 5. TECHNICAL SPECIFICATIONS (OEM) ---
              _buildSectionHeader('Technical Specifications', Icons.tune_outlined, isMandatory: false),
              const SizedBox(height: 10),
              _buildTechnicalSpecsCard(provider),

              const SizedBox(height: 20),

              // --- 6. DESCRIPTION & REVIEWS ---
              _buildSectionHeader('Description & Review Notes', Icons.notes_rounded, isMandatory: false),
              const SizedBox(height: 10),
              _buildDescriptionCard(provider),

              const SizedBox(height: 20),

              // --- 7. CATALOG VISIBILITY TOGGLE ---
              _buildPublishingStatusCard(provider),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // --- SECTION HEADER ---
  Widget _buildSectionHeader(String title, IconData icon, {bool isMandatory = false}) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primaryGold, size: 18),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w800,
            color: AppColors.darkCharcoal,
          ),
        ),
        if (isMandatory) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.primaryGold.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'Required',
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                color: AppColors.darkCharcoal,
              ),
            ),
          ),
        ],
      ],
    );
  }

  // --- 1. PHOTOGRAPHY STUDIO COMPONENT ---
  Widget _buildPhotographyStudio() {
    final hasImage = _pickedImageFile != null ||
        (_existingImageUrl != null && _existingImageUrl!.isNotEmpty);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: hasImage ? AppColors.primaryGold.withValues(alpha: 0.4) : Colors.grey.shade300,
          width: hasImage ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          if (hasImage) ...[
            // Image Preview Stack
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(17)),
                  child: SizedBox(
                    height: 210,
                    width: double.infinity,
                    child: _pickedImageFile != null
                        ? Image.file(_pickedImageFile!, fit: BoxFit.cover)
                        : Image.network(
                            _existingImageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              color: Colors.grey.shade100,
                              child: const Center(
                                child: Icon(Icons.broken_image_outlined, size: 48, color: Colors.grey),
                              ),
                            ),
                          ),
                  ),
                ),
                // Floating status badge
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.darkCharcoal.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.check_circle, color: AppColors.primaryGold, size: 14),
                        SizedBox(width: 5),
                        Text(
                          'Photo Ready',
                          style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            // Bottom change/remove bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.darkCharcoal,
                          side: BorderSide(color: Colors.grey.shade300),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        ),
                        onPressed: () => _pickImage(ImageSource.camera),
                        icon: const Icon(Icons.camera_alt_outlined, size: 16, color: AppColors.primaryGold),
                        label: const Text('Camera', style: TextStyle(fontSize: 12)),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.darkCharcoal,
                          side: BorderSide(color: Colors.grey.shade300),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        ),
                        onPressed: () => _pickImage(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library_outlined, size: 16, color: AppColors.primaryGold),
                        label: const Text('Gallery', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                  if (_pickedImageFile != null)
                    TextButton.icon(
                      style: TextButton.styleFrom(foregroundColor: AppColors.error),
                      onPressed: () => setState(() => _pickedImageFile = null),
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text('Reset', style: TextStyle(fontSize: 12)),
                    ),
                ],
              ),
            ),
          ] else ...[
            // Empty Photography Uploader
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGold.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.add_a_photo_outlined,
                      size: 38,
                      color: AppColors.primaryGold,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Upload Product Photography *',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.darkCharcoal,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Capture clean, well-lit photos for maximum customer catalog conversion.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 12.5),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.darkCharcoal,
                          foregroundColor: AppColors.primaryGold,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () => _pickImage(ImageSource.camera),
                        icon: const Icon(Icons.camera_alt_outlined, size: 18),
                        label: const Text('Take Photo', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.darkCharcoal,
                          side: const BorderSide(color: AppColors.primaryGold, width: 1.5),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () => _pickImage(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library_outlined, size: 18, color: AppColors.primaryGold),
                        label: const Text('From Gallery', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // --- 2. GENERAL INFORMATION CARD ---
  Widget _buildGeneralInfoCard(
    CompanyProvider companyProvider,
    CategoryProvider categoryProvider,
    ProductProvider provider,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildFieldLabel('Product Title / Spare Part Name *'),
          TextFormField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            enabled: !provider.isSaving,
            decoration: const InputDecoration(
              hintText: 'e.g. Hydraulic Power Steering Pump',
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

          // Company Selector
          _buildFieldLabel('Vehicle Manufacturer / Brand *'),
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

          // Category Selector
          _buildFieldLabel('Spare Parts Category *'),
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
        ],
      ),
    );
  }

  // --- 3. COMMERCIAL PRICING & INVENTORY CARD ---
  Widget _buildPricingAndInventoryCard(ProductProvider provider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              // Price Input
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel('Selling Price (₹) *'),
                    TextFormField(
                      controller: _priceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      enabled: !provider.isSaving,
                      decoration: const InputDecoration(
                        hintText: 'e.g. 2450.00',
                        prefixIcon: Icon(Icons.currency_rupee_rounded),
                      ),
                      validator: (val) {
                        if (val != null && val.trim().isNotEmpty) {
                          final clean = val.trim().replaceAll(',', '');
                          final parsed = double.tryParse(clean);
                          if (parsed == null || parsed < 0) {
                            return 'Enter valid price';
                          }
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // Stock Input
              Expanded(
                flex: 2,
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
          const SizedBox(height: 8),
          const Text(
            'Customer selling price displayed on catalog. Stock updates inventory automatically.',
            style: TextStyle(color: Colors.grey, fontSize: 11),
          ),
        ],
      ),
    );
  }

  // --- 4. VEHICLE APPLICATION & FITMENT CARD ---
  Widget _buildFitmentCard(ProductProvider provider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildFieldLabel('Application (Vehicle / Engine Compatibility) *'),
          TextFormField(
            controller: _applicationController,
            maxLines: 2,
            enabled: !provider.isSaving,
            decoration: const InputDecoration(
              hintText: 'e.g. Toyota Hilux Vigo 2.5/3.0 D-4D 2005-2015 / Fortuner 1KD/2KD',
              prefixIcon: Icon(Icons.directions_car_outlined),
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'Application details are required for part compatibility';
              }
              return null;
            },
          ),
          const SizedBox(height: 6),
          const Text(
            'List exact vehicle models, engine codes, and years to ensure buyer match accuracy.',
            style: TextStyle(color: Colors.grey, fontSize: 11),
          ),
        ],
      ),
    );
  }

  // --- 5. TECHNICAL SPECIFICATIONS CARD ---
  Widget _buildTechnicalSpecsCard(ProductProvider provider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Ref No
          _buildFieldLabel('Part / OEM Reference No (Ref No)'),
          TextFormField(
            controller: _refNoController,
            enabled: !provider.isSaving,
            decoration: const InputDecoration(
              hintText: 'e.g. 44310-0K040 / 44310-0K020',
              prefixIcon: Icon(Icons.tag_rounded),
            ),
          ),

          const SizedBox(height: 14),

          // Displacement & Max Pressure
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

          const SizedBox(height: 14),

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

          const SizedBox(height: 14),

          // Rotation
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

          const SizedBox(height: 14),

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
    );
  }

  // --- 6. DESCRIPTION & REVIEW NOTES CARD ---
  Widget _buildDescriptionCard(ProductProvider provider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildFieldLabel('Detailed Description, Material Grade & Notes (Optional)'),
          TextFormField(
            controller: _descriptionController,
            maxLines: 3,
            enabled: !provider.isSaving,
            decoration: const InputDecoration(
              hintText: 'e.g. OEM grade alloy casting, 1-year warranty, includes mounting O-rings...',
              prefixIcon: Icon(Icons.notes_rounded),
            ),
          ),
        ],
      ),
    );
  }

  // --- 7. CATALOG PUBLISHING STATUS TOGGLE ---
  Widget _buildPublishingStatusCard(ProductProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'Storefront Publishing',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: (_isActive ? AppColors.success : AppColors.error).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _isActive ? 'Live' : 'Draft',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: _isActive ? AppColors.success : AppColors.error,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                _isActive
                    ? 'Visible to buyers on customer store'
                    : 'Hidden from customer search (Draft mode)',
                style: const TextStyle(color: Colors.grey, fontSize: 11),
              ),
            ],
          ),
          Switch(
            value: _isActive,
            activeThumbColor: AppColors.primaryGold,
            activeTrackColor: AppColors.darkCharcoal,
            onChanged: provider.isSaving
                ? null
                : (val) => setState(() => _isActive = val),
          ),
        ],
      ),
    );
  }

  // --- STICKY BOTTOM ACTION BAR ---
  Widget _buildBottomActionBar(ProductProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Cancel
            TextButton(
              onPressed: provider.isSaving ? null : () => Navigator.of(context).pop(),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: AppColors.secondaryText,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Submit
            Expanded(
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primaryGold, AppColors.lightGold],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryGold.withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: provider.isSaving ? null : _submit,
                  child: provider.isSaving
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                valueColor: AlwaysStoppedAnimation<Color>(AppColors.darkCharcoal),
                              ),
                            ),
                            SizedBox(width: 10),
                            Text(
                              'Saving Part...',
                              style: TextStyle(
                                color: AppColors.darkCharcoal,
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              widget.isEditing ? Icons.check_circle_outline : Icons.cloud_upload_outlined,
                              color: AppColors.darkCharcoal,
                              size: 19,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              widget.isEditing ? 'Update Spare Part' : 'Publish to Catalog',
                              style: const TextStyle(
                                color: AppColors.darkCharcoal,
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 12.5,
          color: AppColors.darkCharcoal,
        ),
      ),
    );
  }
}
