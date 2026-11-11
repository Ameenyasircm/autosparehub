import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../models/category_model.dart';
import '../../models/product_model.dart';
import '../../providers/category_provider.dart';
import '../../providers/company_provider.dart';
import '../../providers/product_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_dropdown_field.dart';
import '../../widgets/app_form_card.dart';
import '../../widgets/app_submit_button.dart';
import '../../widgets/app_text_field.dart';

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
  /// Stock can be typed in only as opening stock: for a new product, or an
  /// existing one that never had stock recorded.
  bool get _isStockEditable =>
      !widget.isEditing || widget.productToEdit?.stockQuantity == null;

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
  // String? _selectedRotation; // Skipped with technical specs

  File? _pickedImageFile;
  String? _existingImageUrl;
  bool _isActive = true;

  final ImagePicker _picker = ImagePicker();

  /*
  static const List<String> _rotationOptions = [
    'Right (Clockwise)',
    'Left (Counter-Clockwise)',
    'Bi-directional / Reversible',
  ];
  */

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
    // _selectedRotation = p?.rotation;

    _existingImageUrl = p?.imageUrl;
    _isActive = p?.isActive ?? true;

    // Auto-select brand if exactly one brand is already available
    final initialCompanies = context.read<CompanyProvider>().companies;
    if (_selectedCompanyId == null && initialCompanies.length == 1) {
      _selectedCompanyId = initialCompanies.first.id;
      _selectedCompanyName = initialCompanies.first.name;
    }

    // Ensure company and category catalogs are loaded
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final compProvider = context.read<CompanyProvider>();
      final catProvider = context.read<CategoryProvider>();
      if (compProvider.companies.isEmpty) {
        await compProvider.fetchCompanies();
        if (mounted && _selectedCompanyId == null && compProvider.companies.length == 1) {
          setState(() {
            _selectedCompanyId = compProvider.companies.first.id;
            _selectedCompanyName = compProvider.companies.first.name;
          });
        }
      }

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
    final compProvider = context.read<CompanyProvider>();
    final catProvider = context.read<CategoryProvider>();
    provider.clearError();

    final matchedComp = compProvider.companies.where((c) => c.id == _selectedCompanyId);
    final resolvedCompanyName = matchedComp.isNotEmpty
        ? matchedComp.first.name
        : (_selectedCompanyName ?? '');
    final matchedCat = catProvider.categories.where((c) => c.id == _selectedCategoryId);
    final resolvedCategoryName = matchedCat.isNotEmpty
        ? matchedCat.first.name
        : (_selectedCategoryName ?? '');

    final cleanPriceStr = _priceController.text.trim().replaceAll(',', '');
    final price = cleanPriceStr.isNotEmpty ? double.tryParse(cleanPriceStr) : null;
    // Stock is only entered once (opening stock). After that it changes only
    // through sales and purchases, so editing never overwrites it.
    final stock = _isStockEditable ? int.tryParse(_stockController.text.trim()) : null;

    bool success = false;

    if (widget.isEditing) {
      success = await provider.editProduct(
        id: widget.productToEdit!.id,
        name: _nameController.text.trim(),
        currentImageUrl: _existingImageUrl ?? '',
        newImageFile: _pickedImageFile,
        companyId: _selectedCompanyId!,
        companyName: resolvedCompanyName,
        categoryId: _selectedCategoryId!,
        categoryName: resolvedCategoryName,
        application: _applicationController.text.trim(),
        description: _descriptionController.text.trim(),
        refNo: _refNoController.text.trim(),
        displacement: widget.productToEdit?.displacement,
        maxPressure: widget.productToEdit?.maxPressure,
        controlledFlow: widget.productToEdit?.controlledFlow,
        speedRange: widget.productToEdit?.speedRange,
        rotation: widget.productToEdit?.rotation,
        fuelFeedHole: widget.productToEdit?.fuelFeedHole,
        price: price,
        stockQuantity: stock,
        isActive: _isActive,
      );
    } else {
      success = await provider.addProduct(
        name: _nameController.text.trim(),
        imageFile: _pickedImageFile!,
        companyId: _selectedCompanyId!,
        companyName: resolvedCompanyName,
        categoryId: _selectedCategoryId!,
        categoryName: resolvedCategoryName,
        application: _applicationController.text.trim(),
        description: _descriptionController.text.trim(),
        refNo: _refNoController.text.trim(),
        displacement: null,
        maxPressure: null,
        controlledFlow: null,
        speedRange: null,
        rotation: null,
        fuelFeedHole: null,
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

    // If there is only one brand, make it default selected automatically
    if (companyProvider.companies.length == 1 &&
        (_selectedCompanyId == null || !companyProvider.companies.any((c) => c.id == _selectedCompanyId))) {
      final singleCompany = companyProvider.companies.first;
      _selectedCompanyId = singleCompany.id;
      _selectedCompanyName = singleCompany.name;
    }

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
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        physics: const BouncingScrollPhysics(),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- 1. PHOTOGRAPHY STUDIO HERO ---
              _buildPhotographyStudio(),

              const SizedBox(height: 16),

              // --- 2. GENERAL PRODUCT INFORMATION ---
              _buildGeneralInfoCard(companyProvider, categoryProvider, provider),

              const SizedBox(height: 16),

              // --- 3. COMMERCIAL PRICING & INVENTORY ---
              _buildPricingAndInventoryCard(provider),

              const SizedBox(height: 16),

              // --- 4. VEHICLE APPLICATION & FITMENT ---
              _buildFitmentCard(provider),

              const SizedBox(height: 16),

              // --- 5. DESCRIPTION (OPTIONAL) ---
              _buildDescriptionCard(provider),

              const SizedBox(height: 16),

              // --- TECHNICAL SPECIFICATIONS (SKIPPED FOR NOW AS PER REQUIREMENT) ---
              // _buildTechnicalSpecsCard(provider),
              // const SizedBox(height: 16),

              // --- 6. CATALOG VISIBILITY TOGGLE ---
              _buildPublishingStatusCard(provider),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
      ),
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
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12,
                    runSpacing: 10,
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
    final hasValidCompany = companyProvider.companies.any((c) => c.id == _selectedCompanyId);
    final List<CategoryModel> availableCategories = _selectedCompanyId == null
        ? const <CategoryModel>[]
        : categoryProvider.categories.where((c) {
            if (c.companyId == _selectedCompanyId) return true;
            // Allow preserving an unassigned legacy category when editing an older product
            if (widget.isEditing &&
                _selectedCompanyId == widget.productToEdit?.companyId &&
                c.id == widget.productToEdit?.categoryId &&
                c.companyId.isEmpty) {
              return true;
            }
            return false;
          }).toList();
    final hasValidCategory = availableCategories.any((c) => c.id == _selectedCategoryId);

    return AppFormCard(
      title: 'General Information',
      icon: Icons.info_outline,
      isRequired: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            label: 'Product Name',
            hint: 'Enter product name',
            controller: _nameController,
            isRequired: true,
            enabled: !provider.isSaving,
            textCapitalization: TextCapitalization.words,
            prefixIcon: Icons.precision_manufacturing_outlined,
            isDarkTheme: true,
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'Product name is required';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),

          // Company Selector
          AppDropdownField<String>(
            label: 'Brand',
            hint: 'Select brand',
            isRequired: true,
            enabled: !provider.isSaving,
            value: hasValidCompany ? _selectedCompanyId : null,
            prefixIcon: Icons.business_outlined,
            isDarkTheme: true,
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
            onChanged: (val) {
              if (val != null) {
                final matched = companyProvider.companies.firstWhere((c) => c.id == val);
                final categoryBelongsToCompany = categoryProvider.categories.any(
                  (c) => c.id == _selectedCategoryId && c.companyId == val,
                );
                setState(() {
                  _selectedCompanyId = val;
                  _selectedCompanyName = matched.name;
                  if (!categoryBelongsToCompany) {
                    _selectedCategoryId = null;
                    _selectedCategoryName = null;
                  }
                });
              }
            },
            validator: (val) => val == null || val.isEmpty ? 'Please select a brand' : null,
          ),
          const SizedBox(height: 14),

          // Category Selector (Filtered by Selected Brand/Company)
          AppDropdownField<String>(
            label: 'Category',
            hint: _selectedCompanyId == null
                ? 'Select brand first'
                : (availableCategories.isEmpty
                    ? 'No categories under this brand'
                    : 'Select category'),
            isRequired: true,
            enabled: !provider.isSaving && _selectedCompanyId != null,
            value: hasValidCategory ? _selectedCategoryId : null,
            prefixIcon: Icons.category_outlined,
            isDarkTheme: true,
            helperText: _selectedCompanyId != null && availableCategories.isEmpty
                ? 'Add a category under this company first.'
                : null,
            items: availableCategories.map((c) {
              return DropdownMenuItem<String>(
                value: c.id,
                child: Text(
                  c.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) {
                final matched = availableCategories.firstWhere((c) => c.id == val);
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
    return AppFormCard(
      title: 'Pricing & Stock',
      icon: Icons.payments_outlined,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Price Input
          Expanded(
            flex: 3,
            child: AppTextField(
              label: 'Price (₹)',
              hint: '0.00',
              controller: _priceController,
              isRequired: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              enabled: !provider.isSaving,
              prefixIcon: Icons.currency_rupee_rounded,
              isDarkTheme: true,
              validator: (val) {
                final clean = (val ?? '').trim().replaceAll(',', '');
                if (clean.isEmpty) return 'Enter price';
                final parsed = double.tryParse(clean);
                if (parsed == null || parsed < 0) {
                  return 'Enter valid price';
                }
                return null;
              },
            ),
          ),
          const SizedBox(width: 12),

          // Stock Input
          Expanded(
            flex: 2,
            child: AppTextField(
              label: _isStockEditable ? 'Opening Stock' : 'Stock',
              hint: '0',
              controller: _stockController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              isRequired: _isStockEditable,
              readOnly: !_isStockEditable,
              enabled: !provider.isSaving,
              prefixIcon: Icons.inventory_2_outlined,
              isDarkTheme: true,
              helperText: _isStockEditable ? null : 'Use Sales & Purchases',
              validator: (val) {
                if (!_isStockEditable) return null;
                final parsed = int.tryParse((val ?? '').trim());
                if (parsed == null || parsed < 0) return 'Enter stock';
                return null;
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- 4. VEHICLE APPLICATION & FITMENT CARD ---
  Widget _buildFitmentCard(ProductProvider provider) {
    return AppFormCard(
      title: 'OEM Part No & Part Number',
      icon: Icons.directions_car_outlined,
      isRequired: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            label: 'OEM Part No',
            hint: 'Enter OEM Part No',
            controller: _applicationController,
            isRequired: true,
            enabled: !provider.isSaving,
            prefixIcon: Icons.directions_car_outlined,
            isDarkTheme: true,
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'OEM Part No is required';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          AppTextField(
            label: 'Part Number',
            hint: 'Enter product code / Sorl no',
            controller: _refNoController,
            enabled: !provider.isSaving,
            prefixIcon: Icons.tag_rounded,
            isDarkTheme: true,
          ),
        ],
      ),
    );
  }

  // --- 5. DESCRIPTION CARD ---
  Widget _buildDescriptionCard(ProductProvider provider) {
    return AppFormCard(
      title: 'Description',
      icon: Icons.notes_rounded,
      child: AppTextField(
        label: 'Description',
        hint: 'Enter description (optional)',
        controller: _descriptionController,
        maxLines: 3,
        enabled: !provider.isSaving,
        prefixIcon: Icons.notes_rounded,
        isDarkTheme: true,
      ),
    );
  }

  /*
  // --- TECHNICAL SPECIFICATIONS CARD (SKIPPED FOR NOW AS PER REQUIREMENT) ---
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
  */

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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Flexible(
                      child: Text(
                        'Storefront Publishing',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                      ),
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
          ),
          const SizedBox(width: 12),
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
        border: const Border(top: BorderSide(color: Color(0xFFECEFF3), width: 1.0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 10,
            offset: Offset(0, -3),
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
              child: AppSubmitButton(
                label: widget.isEditing ? 'Update Spare Part' : 'Publish to Catalog',
                loadingLabel: widget.isEditing ? 'Updating Spare Part...' : 'Publishing to Catalog...',
                isLoading: provider.isSaving,
                icon: widget.isEditing ? Icons.check_circle_outline : Icons.cloud_upload_outlined,
                backgroundColor: AppColors.primaryGold,
                foregroundColor: AppColors.darkCharcoal,
                height: 48,
                onPressed: _submit,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
