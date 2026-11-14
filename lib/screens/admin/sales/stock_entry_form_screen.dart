import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../models/customer_model.dart';
import '../../../models/order_model.dart';
import '../../../models/product_model.dart';
import '../../../models/sales_models.dart';
import '../../../providers/admin_login_provider.dart';
import '../../../providers/product_provider.dart';
import '../../../providers/sales_provider.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/phone_helper.dart';
import '../../../utils/sales_helper.dart';
import '../../../widgets/app_submit_button.dart';
import '../../../widgets/app_text_field.dart';
import 'sales_widgets.dart';

enum StockEntryType { sale, purchase }

/// One screen for both a new sale (stock goes down) and a new purchase
/// (stock goes up). Only the header fields and the stock check differ.
///
/// Pops with `true` when something was saved.
class StockEntryFormScreen extends StatefulWidget {
  final StockEntryType type;

  /// Sale only: pre-fill customer, products, quantities and prices from a
  /// customer app order. Saving links the sale to the order.
  final OrderModel? fromOrder;

  /// Purchase only: products to pre-fill, with the quantity to buy.
  final Map<ProductModel, int>? initialPurchase;

  const StockEntryFormScreen({
    super.key,
    required this.type,
    this.fromOrder,
    this.initialPurchase,
  });

  @override
  State<StockEntryFormScreen> createState() => _StockEntryFormScreenState();
}

class _EditableLine {
  ProductModel product; // refreshed after a purchase so stock is current
  final TextEditingController qty;
  final TextEditingController price;

  _EditableLine(this.product, {double? price, int quantity = 1})
      : qty = TextEditingController(text: '$quantity'),
        price = TextEditingController(text: price == null ? '' : _trimPrice(price));

  static String _trimPrice(double p) =>
      p == p.roundToDouble() ? p.toStringAsFixed(0) : p.toStringAsFixed(2);

  int get quantity => int.tryParse(qty.text.trim()) ?? 0;
  double get unitPrice => double.tryParse(price.text.trim().replaceAll(',', '')) ?? 0;

  StockLineItem toItem() => StockLineItem(
        productId: product.id,
        productName: product.name,
        refNo: product.productCode,
        quantity: quantity,
        unitPrice: unitPrice,
      );

  void dispose() {
    qty.dispose();
    price.dispose();
  }
}

class _StockEntryFormScreenState extends State<StockEntryFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _supplierController = TextEditingController();
  final _billNoController = TextEditingController();
  final _noteController = TextEditingController();
  final List<_EditableLine> _lines = [];
  CustomerModel? _customer;
  DateTime _date = DateTime.now();

  bool get _isSale => widget.type == StockEntryType.sale;

  @override
  void initState() {
    super.initState();
    widget.initialPurchase?.forEach((product, qty) {
      _lines.add(_EditableLine(product, quantity: qty < 1 ? 1 : qty));
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SalesProvider>().clearError();
      if (_isSale && widget.fromOrder != null) _prefillFromOrder(widget.fromOrder!);
    });
  }

  bool _loadingOrder = false;

  Future<void> _prefillFromOrder(OrderModel order) async {
    setState(() => _loadingOrder = true);
    final productProvider = context.read<ProductProvider>();
    await productProvider.fetchProducts(); // latest stock
    if (!mounted) return;

    final byId = {for (final p in productProvider.products) p.id: p};
    final missing = <String>[];
    setState(() {
      _customer = CustomerModel(
        id: order.userId,
        name: order.userName,
        phoneNumber: order.userPhone,
        status: 'APPROVED',
      );
      _noteController.text = 'Order ${order.orderNumber}';
      for (final item in order.items) {
        final product = byId[item.productId];
        if (product == null) {
          missing.add(item.productName);
          continue;
        }
        final existing = _lines.where((l) => l.product.id == product.id);
        if (existing.isNotEmpty) {
          existing.first.qty.text = '${existing.first.quantity + item.quantity}';
        } else {
          _lines.add(_EditableLine(product, price: item.unitPrice, quantity: item.quantity));
        }
      }
      _loadingOrder = false;
    });

    if (missing.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Not in catalog anymore, skipped: ${missing.join(', ')}'),
        backgroundColor: AppColors.error,
      ));
    }
  }

  /// Products whose sale quantity is more than the stock, with how many more
  /// are needed.
  Map<ProductModel, int> get _shortages => {
        for (final l in _lines)
          if (l.quantity > (l.product.stockQuantity ?? 0))
            l.product: l.quantity - (l.product.stockQuantity ?? 0),
      };

  /// Asks to add a purchase for products without enough stock. If a purchase
  /// is saved, stock on this screen is refreshed. Returns true if saved.
  Future<bool> _offerPurchase(Map<ProductModel, int> needed) async {
    final names = needed.entries
        .map((e) => '- ${e.key.name}: in stock ${e.key.stockQuantity ?? 0}, need ${e.value} more')
        .join('\n');
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Not enough stock'),
        content: Text('$names\n\nAdd a purchase to bring the stock in, then continue the sale.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Add Purchase', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (go != true || !mounted) return false;

    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => StockEntryFormScreen(type: StockEntryType.purchase, initialPurchase: needed),
    ));
    if (saved != true || !mounted) return false;

    final productProvider = context.read<ProductProvider>();
    await productProvider.fetchProducts();
    if (!mounted) return true;
    final byId = {for (final p in productProvider.products) p.id: p};
    setState(() {
      for (final l in _lines) {
        l.product = byId[l.product.id] ?? l.product;
      }
    });
    context.read<SalesProvider>().clearError();
    return true;
  }

  @override
  void dispose() {
    _supplierController.dispose();
    _billNoController.dispose();
    _noteController.dispose();
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  double get _total => _lines.fold(0.0, (acc, l) => acc + l.quantity * l.unitPrice);

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      final now = DateTime.now();
      // Keep the current time for today's entries so they sort naturally.
      setState(() => _date = SalesHelper.dayOnly(picked) == SalesHelper.dayOnly(now)
          ? now
          : DateTime(picked.year, picked.month, picked.day, 12));
    }
  }

  Future<void> _pickCustomer() async {
    final c = await showCustomerPicker(context);
    if (c != null) setState(() => _customer = c);
  }

  Future<void> _addProduct() async {
    final picked = await showProductPicker(context, forSale: _isSale);
    if (picked == null || !mounted) return;
    ProductModel product = picked;

    // Out of stock: offer to add a purchase first, then add with fresh stock.
    if (_isSale &&
        (product.stockQuantity ?? 0) <= 0 &&
        !_lines.any((l) => l.product.id == picked.id)) {
      final saved = await _offerPurchase({picked: 1});
      if (!saved || !mounted) return;
      product = context
          .read<ProductProvider>()
          .products
          .firstWhere((x) => x.id == picked.id, orElse: () => picked);
      if ((product.stockQuantity ?? 0) <= 0) return;
    }

    final existing = _lines.where((l) => l.product.id == product.id);
    setState(() {
      if (existing.isNotEmpty) {
        final line = existing.first;
        line.qty.text = (line.quantity + 1).toString();
      } else {
        _lines.add(_EditableLine(product, price: _isSale ? product.price : null));
      }
    });
  }

  void _removeLine(_EditableLine line) {
    setState(() => _lines.remove(line));
    line.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final messenger = ScaffoldMessenger.of(context);
    if (_isSale && _customer == null) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Please select a customer.'), backgroundColor: AppColors.error));
      return;
    }
    if (_lines.isEmpty) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Add at least one product.'), backgroundColor: AppColors.error));
      return;
    }
    if (_isSale && _shortages.isNotEmpty) {
      // Offer to bring stock in instead of just blocking.
      await _offerPurchase(_shortages);
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    final sales = context.read<SalesProvider>();
    final productProvider = context.read<ProductProvider>();
    final admin = context.read<AdminLoginProvider>().currentAdmin;
    final items = _lines.map((l) => l.toItem()).toList();

    String? successMessage;
    if (_isSale) {
      final sale = await sales.createSale(
        customer: _customer!,
        items: items,
        saleDate: _date,
        note: _noteController.text,
        admin: admin,
        orderId: widget.fromOrder?.id,
        orderNumber: widget.fromOrder?.orderNumber,
      );
      if (sale == null && (sales.errorMessage ?? '').startsWith('Not enough stock')) {
        // Stock changed since this screen loaded: refresh so the lines show it.
        await productProvider.fetchProducts();
        if (mounted) {
          final byId = {for (final p in productProvider.products) p.id: p};
          setState(() {
            for (final l in _lines) {
              l.product = byId[l.product.id] ?? l.product;
            }
          });
        }
      }
      if (sale != null) {
        successMessage = 'Sale ${sale.saleNumber} saved • ${SalesHelper.formatAmount(sale.totalAmount)}';
      }
    } else {
      final purchase = await sales.createPurchase(
        supplierName: _supplierController.text,
        supplierBillNo: _billNoController.text,
        items: items,
        purchaseDate: _date,
        note: _noteController.text,
        admin: admin,
      );
      if (purchase != null) {
        successMessage = 'Purchase ${purchase.purchaseNumber} saved. Stock updated.';
      }
    }

    if (successMessage == null || !mounted) return;
    productProvider.fetchProducts(); // refresh stock shown elsewhere
    messenger.showSnackBar(SnackBar(content: Text(successMessage), backgroundColor: AppColors.success));
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final sales = context.watch<SalesProvider>();
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppColors.darkCharcoal,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
            widget.fromOrder != null
                ? 'Sale from ${widget.fromOrder!.orderNumber}'
                : (_isSale ? 'New Sale' : 'New Purchase'),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17)),
      ),
      body: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (sales.errorMessage != null) SalesErrorBanner(sales.errorMessage!),
              if (_loadingOrder)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: LinearProgressIndicator(color: AppColors.warmGold),
                ),
              SelectorTile(
                icon: Icons.calendar_today_rounded,
                label: _isSale ? 'Sale Date' : 'Purchase Date',
                value: SalesHelper.formatDay(_date),
                placeholder: '',
                onTap: _pickDate,
              ),
              const SizedBox(height: 12),
              if (_isSale)
                SelectorTile(
                  icon: Icons.person_rounded,
                  label: 'Customer *',
                  value: _customer == null
                      ? null
                      : '${_customer!.name} • ${PhoneHelper.formatForDisplay(_customer!.phoneNumber)}',
                  placeholder: 'Select or add a customer',
                  // The customer of an order is fixed.
                  onTap: widget.fromOrder != null ? () {} : _pickCustomer,
                )
              else ...[
                AppTextField(
                  label: 'Supplier Name',
                  hint: 'Who did you buy from?',
                  controller: _supplierController,
                  isRequired: true,
                  prefixIcon: Icons.local_shipping_outlined,
                  textCapitalization: TextCapitalization.words,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Supplier name is required' : null,
                ),
                const SizedBox(height: 12),
                AppTextField(
                  label: 'Supplier Bill No.',
                  hint: 'Optional',
                  controller: _billNoController,
                  prefixIcon: Icons.receipt_long_outlined,
                ),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  const Expanded(
                    child: Text('PRODUCTS',
                        style: TextStyle(
                            color: Color(0xFF5A6271),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0)),
                  ),
                  TextButton.icon(
                    onPressed: sales.isSaving ? null : _addProduct,
                    icon: const Icon(Icons.add_rounded, color: AppColors.warmGold),
                    label: const Text('Add Product',
                        style: TextStyle(color: AppColors.darkHeader, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
              if (_lines.isEmpty)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: const Text('No products added yet.',
                      textAlign: TextAlign.center, style: TextStyle(color: AppColors.secondaryText)),
                ),
              ..._lines.map(_buildLineCard),
              const SizedBox(height: 12),
              AppTextField(
                label: 'Note',
                hint: 'Optional',
                controller: _noteController,
                prefixIcon: Icons.notes_rounded,
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.darkHeader,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Text('Total',
                        style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700, fontSize: 14)),
                    const Spacer(),
                    Text(SalesHelper.formatAmount(_total),
                        style: const TextStyle(
                            color: AppColors.primaryGold, fontWeight: FontWeight.w800, fontSize: 20)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              AppSubmitButton(
                label: _isSale ? 'Save Sale' : 'Save Purchase',
                loadingLabel: 'Saving...',
                icon: Icons.check_rounded,
                isLoading: sales.isSaving,
                onPressed: sales.isSaving ? null : _submit,
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLineCard(_EditableLine line) {
    final stock = line.product.stockQuantity ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(line.product.name,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    Text(
                      [
                        if (line.product.productCode != null) 'Code: ${line.product.productCode}',
                        'In stock: $stock',
                      ].join(' • '),
                      style: const TextStyle(fontSize: 12, color: AppColors.secondaryText),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                onPressed: () => _removeLine(line),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _compactField(
                    controller: line.qty,
                    label: 'Qty',
                    digitsOnly: true,
                    validator: (v) {
                      final q = int.tryParse(v?.trim() ?? '') ?? 0;
                      if (q <= 0) return 'Enter qty';
                      if (_isSale && q > stock) return 'Only $stock left';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _compactField(
                    controller: line.price,
                    label: _isSale ? 'Price (₹)' : 'Cost (₹)',
                    digitsOnly: false,
                    validator: (v) {
                      final p = double.tryParse(v?.trim().replaceAll(',', '') ?? '');
                      return (p == null || p < 0) ? 'Enter price' : null;
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Text(
                      SalesHelper.formatAmount(line.quantity * line.unitPrice),
                      textAlign: TextAlign.end,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_isSale && line.quantity > stock)
            Padding(
              padding: const EdgeInsets.only(top: 4, right: 8),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.error),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text('Need ${line.quantity - stock} more in stock',
                        style: const TextStyle(color: AppColors.error, fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                    icon: const Icon(Icons.add_shopping_cart_rounded, size: 16),
                    label: const Text('Add Purchase'),
                    onPressed: () => _offerPurchase({line.product: line.quantity - stock}),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _compactField({
    required TextEditingController controller,
    required String label,
    required bool digitsOnly,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: digitsOnly
          ? TextInputType.number
          : const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        digitsOnly
            ? FilteringTextInputFormatter.digitsOnly
            : FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
      ],
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      validator: validator,
      onChanged: (_) => setState(() {}),
    );
  }
}
