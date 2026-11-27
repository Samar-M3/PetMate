import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/api_client.dart';
import '../../../../core/services/cloudinary_service.dart';
import '../../../../core/widgets/validated_form.dart';
import '../../../shop/presentation/providers/shop_providers.dart';
import '../providers/seller_provider.dart';

/// Add New Product page for the seller dashboard.
class SellerAddProductPage extends ConsumerStatefulWidget {
  const SellerAddProductPage({super.key});

  @override
  ConsumerState<SellerAddProductPage> createState() =>
      _SellerAddProductPageState();
}

class _SellerAddProductPageState extends ConsumerState<SellerAddProductPage> {
  final _formController = ValidatedFormController();
  final _scrollController = ScrollController();

  // Controllers for text fields
  final _nameController = TextEditingController();
  final _skuController = TextEditingController();
  final _brandController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _shortDescriptionController = TextEditingController();
  final _basePriceController = TextEditingController();
  final _discountedPriceController = TextEditingController();
  final _costPriceController = TextEditingController();
  final _stockController = TextEditingController(text: '0');
  final _lowStockThresholdController = TextEditingController(text: '5');
  final _weightController = TextEditingController();
  final _dimensionsController = TextEditingController();
  final _materialController = TextEditingController();
  final _ingredientsController = TextEditingController();

  // State
  String? _selectedCategoryId;
  String? _selectedPetType;
  List<Map<String, dynamic>> _categories = [];
  bool _isFeatured = false;
  bool _isSubmitting = false;
  bool _isLoadingCategories = true;

  // Image state
  final List<_ProductImageEntry> _selectedImages = [];
  static const int _maxImages = 8;
  bool _isPickingImages = false;

  final List<String> _petTypes = [
    'Dog',
    'Cat',
    'Bird',
    'Fish',
    'Rabbit',
    'Hamster',
    'Reptile',
    'All Pets',
  ];

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _nameController.dispose();
    _skuController.dispose();
    _brandController.dispose();
    _descriptionController.dispose();
    _shortDescriptionController.dispose();
    _basePriceController.dispose();
    _discountedPriceController.dispose();
    _costPriceController.dispose();
    _stockController.dispose();
    _lowStockThresholdController.dispose();
    _weightController.dispose();
    _dimensionsController.dispose();
    _materialController.dispose();
    _ingredientsController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoadingCategories = true);
    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.get('/shop/categories');
      if (response is Map) {
        final data = response['data'] is Map ? response['data'] as Map : response;
        List<dynamic> catList;
        if (data['items'] is List) {
          catList = data['items'] as List;
        } else if (data['categories'] is List) {
          catList = data['categories'] as List;
        } else {
          catList = [];
        }
        // Flatten parent+children into a single list with indentation info
        final flat = <Map<String, dynamic>>[];
        for (final cat in catList) {
          if (cat is Map<String, dynamic>) {
            flat.add({'id': cat['id'], 'name': cat['name'], 'isChild': false});
            final children = cat['children'] as List? ?? [];
            for (final child in children) {
              if (child is Map<String, dynamic>) {
                flat.add({
                  'id': child['id'],
                  'name': child['name'],
                  'isChild': true,
                });
              }
            }
          }
        }
        if (mounted) {
          setState(() {
            _categories = flat;
            if (_selectedCategoryId == null && flat.isNotEmpty) {
              _selectedCategoryId = flat.first['id'] as String;
            }
            _isLoadingCategories = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingCategories = false);
      }
    }
  }

  Future<void> _pickImages() async {
    if (_isPickingImages) return;
    _isPickingImages = true;
    try {
      if (_selectedImages.length >= _maxImages) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Maximum 8 images allowed'),
              backgroundColor: AppColors.warning,
            ),
          );
        }
        return;
      }

      final picker = ImagePicker();
      final remaining = _maxImages - _selectedImages.length;
      List<XFile> picked = [];

      try {
        picked = await picker.pickMultiImage(
          maxWidth: 1200,
          maxHeight: 1200,
          imageQuality: 85,
        );
      } catch (multiError) {
        // Fallback for web or devices where pickMultiImage encounters issues
        try {
          final single = await picker.pickImage(
            source: ImageSource.gallery,
            maxWidth: 1200,
            maxHeight: 1200,
            imageQuality: 85,
          );
          if (single != null) {
            picked = [single];
          }
        } catch (_) {
          // Gracefully handled if user cancels
        }
      }

      if (picked.isEmpty) return;

      final newEntries = <_ProductImageEntry>[];
      for (final xFile in picked) {
        if (_selectedImages.length + newEntries.length >= _maxImages) break;
        try {
          final bytes = await xFile.readAsBytes();
          newEntries.add(_ProductImageEntry(
            bytes: bytes,
            name: xFile.name.isNotEmpty ? xFile.name : 'product_image.jpg',
            isUploading: true,
          ));
        } catch (e) {
          debugPrint('Error reading image file: $e');
        }
      }

      if (newEntries.isEmpty || !mounted) return;

      setState(() {
        _selectedImages.addAll(newEntries);
      });

      // Upload each image in background without blocking form inputs
      for (final entry in newEntries) {
        _uploadSingleImage(entry);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not access image: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPickingImages = false);
      } else {
        _isPickingImages = false;
      }
    }
  }

  Future<void> _uploadSingleImage(_ProductImageEntry entry) async {
    try {
      final cloudinary = ref.read(cloudinaryServiceProvider);
      final url = await cloudinary.uploadImage(
        null,
        bytes: entry.bytes,
        filename: entry.name,
        folder: 'products',
      );

      if (url != null && url.isNotEmpty) {
        if (mounted) {
          setState(() {
            entry.uploadedUrl = url;
            entry.isUploading = false;
            entry.errorMessage = null;
          });
        } else {
          entry.uploadedUrl = url;
          entry.isUploading = false;
          entry.errorMessage = null;
        }
      } else {
        throw Exception('Upload returned empty response');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          entry.isUploading = false;
          entry.errorMessage = 'Upload failed';
        });
      } else {
        entry.isUploading = false;
        entry.errorMessage = 'Upload failed';
      }
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  void _reorderImages(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final item = _selectedImages.removeAt(oldIndex);
      _selectedImages.insert(newIndex, item);
    });
  }

  int? _computeDiscountPercentage() {
    final base = double.tryParse(_basePriceController.text.trim());
    final discounted = double.tryParse(_discountedPriceController.text.trim());
    if (base != null && base > 0 && discounted != null && discounted < base) {
      return ((1 - discounted / base) * 100).round();
    }
    return null;
  }

  Future<void> _submitProduct({required bool publish}) async {
    if (!_formController.validate(() => setState(() {}))) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
      return;
    }

    if (_selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one product image'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Check if any images are still uploading
    if (_selectedImages.any((img) => img.isUploading)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please wait for image uploads to complete...'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    // Check if any image failed upload
    final failed = _selectedImages.where((img) => img.uploadedUrl == null);
    if (failed.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Some images failed to upload. Please retry or remove them.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final uploadedUrls = _selectedImages
          .map((img) => img.uploadedUrl)
          .whereType<String>()
          .toList();

      final basePrice = double.parse(_basePriceController.text.trim());
      double? validDiscount;
      final discountText = _discountedPriceController.text.trim();
      if (discountText.isNotEmpty) {
        final parsed = double.tryParse(discountText);
        if (parsed != null && parsed > 0 && parsed < basePrice) {
          validDiscount = parsed;
        }
      }
      final costPrice = double.tryParse(_costPriceController.text.trim());
      final stock = int.tryParse(_stockController.text.trim()) ?? 0;
      final lowStockThreshold =
          int.tryParse(_lowStockThresholdController.text.trim()) ?? 5;

      // Extract numeric value from weight string (e.g. "2KG" -> 2.0)
      double? weight;
      final rawWeight = _weightController.text.trim();
      if (rawWeight.isNotEmpty) {
        final cleanWeight = rawWeight.replaceAll(RegExp(r'[^0-9.]'), '');
        weight = double.tryParse(cleanWeight);
      }

      // Build specifications JSON
      final specs = <String, dynamic>{};
      if (_materialController.text.trim().isNotEmpty) {
        specs['material'] = _materialController.text.trim();
      }
      if (_ingredientsController.text.trim().isNotEmpty) {
        specs['ingredients'] = _ingredientsController.text.trim();
      }
      if (_selectedPetType != null) {
        specs['petType'] = _selectedPetType;
      }
      if (_dimensionsController.text.trim().isNotEmpty) {
        specs['dimensions'] = _dimensionsController.text.trim();
      }

      final body = <String, dynamic>{
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'basePrice': basePrice,
        'availableStock': stock,
        'status': publish ? 'ACTIVE' : 'DRAFT',
        'isFeatured': _isFeatured,
        'imageUrls': uploadedUrls,
      };

      if (_skuController.text.trim().isNotEmpty) {
        body['sku'] = _skuController.text.trim();
      }
      if (_brandController.text.trim().isNotEmpty) {
        body['brand'] = _brandController.text.trim();
      }
      if (_shortDescriptionController.text.trim().isNotEmpty) {
        body['shortDescription'] = _shortDescriptionController.text.trim();
      }
      if (_selectedCategoryId != null) {
        body['categoryId'] = _selectedCategoryId;
      }
      if (validDiscount != null) {
        body['discountedPrice'] = validDiscount;
      }
      if (costPrice != null && costPrice > 0) {
        body['costPrice'] = costPrice;
      }
      if (lowStockThreshold > 0) {
        body['lowStockThreshold'] = lowStockThreshold;
      }
      if (weight != null && weight > 0) {
        body['shippingWeight'] = weight;
      }
      if (_dimensionsController.text.trim().isNotEmpty) {
        body['packageDimensions'] = _dimensionsController.text.trim();
      }
      if (specs.isNotEmpty) {
        body['specifications'] = specs;
      }

      final apiClient = ref.read(apiClientProvider);
      await apiClient.post('/sellers/products', body: body);

      // Refresh seller dashboard and customer shop caches so the new product is immediately visible
      ref.invalidate(shopCategoriesProvider);
      ref.invalidate(shopFeaturedProvider);
      ref.invalidate(shopNewArrivalsProvider);
      ref.invalidate(shopRecommendedProvider);
      ref.invalidate(shopDealsProvider);
      ref.read(sellerProvider.notifier).loadDashboard();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              publish
                  ? 'Product published successfully!'
                  : 'Product saved as draft!',
            ),
            backgroundColor: AppColors.success,
          ),
        );
        context.go('/seller');
      }
    } catch (e) {
      if (mounted) {
        // Extract clean message from ApiException or similar
        String errorMsg = e.toString();
        if (errorMsg.contains('ApiException:')) {
          errorMsg = errorMsg.replaceAll(RegExp(r'^.*ApiException:\s*'), '');
        }
        if (errorMsg.contains('message:')) {
          errorMsg = errorMsg.replaceAll(RegExp(r'^.*message:\s*'), '');
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final discountPct = _computeDiscountPercentage();

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: AppColors.textPrimary,
          ),
          onPressed: () => context.go('/seller'),
        ),
        title: const Text(
          'Add New Product',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: Form(
        key: _formController.formKey,
        autovalidateMode: _formController.autovalidateMode,
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Section: Basic Info ──
                  _buildSectionCard(
                    title: 'Basic Information',
                    icon: Icons.info_outline_rounded,
                    children: [
                      _buildTextField(
                        controller: _nameController,
                        label: 'Product Name *',
                        hint: 'e.g. Premium Adult Dog Food',
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Product name is required'
                            : null,
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _skuController,
                              label: 'SKU',
                              hint: 'e.g. PET-DOG-001',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField(
                              controller: _brandController,
                              label: 'Brand',
                              hint: 'e.g. Royal Canin',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      // Category dropdown
                      _isLoadingCategories
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: LinearProgressIndicator(
                                color: AppColors.primary,
                                minHeight: 2,
                              ),
                            )
                          : DropdownButtonFormField<String>(
                              value: _selectedCategoryId,
                              decoration: _inputDecoration('Category'),
                              items: _categories.map((cat) {
                                final isChild = cat['isChild'] as bool;
                                return DropdownMenuItem<String>(
                                  value: cat['id'] as String,
                                  child: Text(
                                    isChild
                                        ? '  └ ${cat['name']}'
                                        : cat['name'] as String,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: isChild
                                          ? FontWeight.normal
                                          : FontWeight.w600,
                                    ),
                                  ),
                                );
                              }).toList(),
                              onChanged: (v) =>
                                  setState(() => _selectedCategoryId = v),
                            ),
                      const SizedBox(height: 14),
                      _buildTextField(
                        controller: _shortDescriptionController,
                        label: 'Short Description',
                        hint: 'Brief product summary',
                        maxLines: 2,
                      ),
                      const SizedBox(height: 14),
                      _buildTextField(
                        controller: _descriptionController,
                        label: 'Full Description',
                        hint: 'Detailed product description including benefits, ingredients, usage...',
                        maxLines: 5,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── Section: Product Images ──
                  _buildSectionCard(
                    title: 'Product Images',
                    icon: Icons.image_outlined,
                    children: [
                      Text(
                        'Add up to $_maxImages images. The first image will be the main product image.',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildImagePicker(),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── Section: Pricing ──
                  _buildSectionCard(
                    title: 'Pricing (NPR)',
                    icon: Icons.attach_money_rounded,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _basePriceController,
                              label: 'Regular Price *',
                              hint: '0.00',
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Price is required';
                                }
                                final price = double.tryParse(v.trim());
                                if (price == null || price <= 0) {
                                  return 'Enter a valid price';
                                }
                                return null;
                              },
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField(
                              controller: _discountedPriceController,
                              label: 'Sale Price (optional)',
                              hint: '0.00',
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) return null;
                                final disc = double.tryParse(v.trim());
                                if (disc == null) return 'Enter a valid number';
                                if (disc <= 0) return 'Must be greater than 0';
                                final base = double.tryParse(
                                    _basePriceController.text.trim());
                                if (base != null && disc >= base) {
                                  return 'Must be less than regular price';
                                }
                                return null;
                              },
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                        ],
                      ),
                      if (discountPct != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.local_offer_rounded,
                                size: 14,
                                color: AppColors.success,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '$discountPct% discount',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.success,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      _buildTextField(
                        controller: _costPriceController,
                        label: 'Cost Price (optional, internal)',
                        hint: '0.00',
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── Section: Stock & Inventory ──
                  _buildSectionCard(
                    title: 'Stock & Inventory',
                    icon: Icons.inventory_outlined,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _stockController,
                              label: 'Available Stock *',
                              hint: '0',
                              keyboardType: TextInputType.number,
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Stock is required';
                                }
                                final stock = int.tryParse(v.trim());
                                if (stock == null || stock < 0) {
                                  return 'Enter a valid number';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField(
                              controller: _lowStockThresholdController,
                              label: 'Low Stock Alert',
                              hint: '5',
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── Section: Specifications ──
                  _buildSectionCard(
                    title: 'Specifications & Shipping',
                    icon: Icons.settings_outlined,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _weightController,
                              label: 'Weight (kg)',
                              hint: 'e.g. 2.5',
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField(
                              controller: _dimensionsController,
                              label: 'Dimensions',
                              hint: 'e.g. 30x20x10 cm',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _buildTextField(
                        controller: _materialController,
                        label: 'Material',
                        hint: 'e.g. Natural cotton, BPA-free plastic',
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        value: _selectedPetType,
                        decoration: _inputDecoration('Pet Type'),
                        items: _petTypes
                            .map(
                              (t) => DropdownMenuItem(
                                value: t,
                                child: Text(
                                  t,
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => _selectedPetType = v),
                      ),
                      const SizedBox(height: 14),
                      _buildTextField(
                        controller: _ingredientsController,
                        label: 'Ingredients / Key Features',
                        hint: 'List key ingredients or features...',
                        maxLines: 3,
                      ),
                      const SizedBox(height: 14),
                      SwitchListTile(
                        value: _isFeatured,
                        onChanged: (v) => setState(() => _isFeatured = v),
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Featured Product',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: const Text(
                          'Featured products appear in the homepage spotlight',
                          style: TextStyle(fontSize: 11),
                        ),
                        activeColor: AppColors.primary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ── Action Buttons ──
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isSubmitting
                              ? null
                              : () => _submitProduct(publish: false),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textPrimary,
                            side: const BorderSide(color: AppColors.border),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: _isSubmitting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.save_outlined, size: 18),
                          label: const Text(
                            'Save as Draft',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isSubmitting
                              ? null
                              : () => _submitProduct(publish: true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 1,
                          ),
                          icon: _isSubmitting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.publish_rounded, size: 18),
                          label: const Text(
                            'Publish Product',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Reusable Builders ──────────────────────────────────────

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.info),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      onChanged: onChanged,
      style: const TextStyle(fontSize: 14),
      decoration: _inputDecoration(label, hint: hint),
    );
  }

  InputDecoration _inputDecoration(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
      hintStyle: TextStyle(
        fontSize: 13,
        color: AppColors.textMuted.withValues(alpha: 0.7),
      ),
      filled: true,
      fillColor: AppColors.inputFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.error),
      ),
    );
  }

  Widget _buildImagePicker() {
    return Column(
      children: [
        // Image preview grid
        if (_selectedImages.isNotEmpty)
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _selectedImages.length,
            onReorder: _reorderImages,
            itemBuilder: (context, index) {
              final img = _selectedImages[index];
              return Container(
                key: ValueKey('img_$index'),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: AppColors.inputFill,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: index == 0 ? AppColors.primary : AppColors.border,
                    width: index == 0 ? 2 : 1,
                  ),
                ),
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  leading: Stack(
                    alignment: Alignment.center,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(
                          img.bytes,
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                        ),
                      ),
                      if (img.isUploading)
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.45),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Center(
                            child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  title: Text(
                    img.name,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Row(
                    children: [
                      Text(
                        index == 0 ? '⭐ Main Image' : 'Image ${index + 1}',
                        style: TextStyle(
                          fontSize: 11,
                          color: index == 0
                              ? AppColors.primary
                              : AppColors.textSecondary,
                          fontWeight:
                              index == 0 ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (img.isUploading)
                        const Text(
                          '• Uploading...',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.info,
                            fontWeight: FontWeight.w500,
                          ),
                        )
                      else if (img.uploadedUrl != null)
                        const Text(
                          '• Ready',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.success,
                            fontWeight: FontWeight.w500,
                          ),
                        )
                      else if (img.errorMessage != null)
                        const Text(
                          '• Upload failed',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.error,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (img.uploadedUrl != null && !img.isUploading)
                        const Icon(
                          Icons.cloud_done_rounded,
                          size: 18,
                          color: AppColors.success,
                        ),
                      if (img.errorMessage != null && !img.isUploading)
                        IconButton(
                          icon: const Icon(
                            Icons.refresh_rounded,
                            size: 20,
                            color: AppColors.warning,
                          ),
                          tooltip: 'Retry upload',
                          onPressed: () {
                            setState(() {
                              img.isUploading = true;
                              img.errorMessage = null;
                            });
                            _uploadSingleImage(img);
                          },
                        ),
                      IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: AppColors.error,
                        ),
                        tooltip: 'Remove',
                        onPressed: () => _removeImage(index),
                        visualDensity: VisualDensity.compact,
                      ),
                      const Icon(
                        Icons.drag_handle_rounded,
                        size: 18,
                        color: AppColors.textMuted,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

        // Add images button
        if (_selectedImages.length < _maxImages)
          InkWell(
            onTap: _isPickingImages ? null : _pickImages,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24),
              decoration: BoxDecoration(
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.4),
                  style: BorderStyle.solid,
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(12),
                color: AppColors.primary.withValues(alpha: 0.04),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 32,
                    color: AppColors.primary.withValues(alpha: 0.7),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _selectedImages.isEmpty
                        ? 'Tap to add product images'
                        : 'Add more images (${_selectedImages.length}/$_maxImages)',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.primary.withValues(alpha: 0.8),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Internal helper to hold a picked image with upload state tracking.
class _ProductImageEntry {
  final Uint8List bytes;
  final String name;
  String? uploadedUrl;
  bool isUploading;
  String? errorMessage;

  _ProductImageEntry({
    required this.bytes,
    required this.name,
    this.uploadedUrl,
    this.isUploading = false,
    this.errorMessage,
  });
}
