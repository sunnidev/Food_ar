import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/cart_provider.dart';

/// Screen displaying ordered items, quantity stepper controls, subtotal/tax calculations,
/// table number selection, and backend kitchen order dispatch via Dio.
class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  int _selectedTable = 4; // Default dining table number
  final TextEditingController _instructionsController = TextEditingController();

  @override
  void dispose() {
    _instructionsController.dispose();
    super.dispose();
  }

  Future<void> _handlePlaceOrder() async {
    try {
      final result = await ref.read(orderPlacementProvider.notifier).placeOrder(
            tableNumber: _selectedTable,
            specialInstructions: _instructionsController.text.trim(),
          );

      if (!mounted || result == null) return;

      final orderId = result['orderId'] ?? 'ORD-CONFIRMED';
      final total = (result['total'] as num?)?.toDouble() ?? 0.0;
      final prepTime = result['estimatedPrepMinutes'] ?? 18;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E212B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 28),
              SizedBox(width: 10),
              Text(
                'Order Dispatched!',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Order ID: $orderId',
                style: const TextStyle(
                  color: Color(0xFFFF7043),
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Assigned to Dining Table #$_selectedTable',
                style: const TextStyle(color: Colors.white70, fontSize: 13.5),
              ),
              const SizedBox(height: 4),
              Text(
                'Total: \$${total.toStringAsFixed(2)} • Est. prep: ~$prepTime mins',
                style: const TextStyle(color: Colors.white60, fontSize: 12.5),
              ),
              const Divider(color: Colors.white12, height: 24),
              const Text(
                'Your dishes have been received by the kitchen. You can preview them in 1:1 real scale while you wait!',
                style: TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.4),
              ),
            ],
          ),
          actions: [
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFF5722),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () {
                ref.read(orderPlacementProvider.notifier).reset();
                Navigator.pop(ctx);
                context.go('/');
              },
              child: const Text('Return to Menu'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to submit order: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartItems = ref.watch(cartProvider);
    final subtotal = ref.watch(cartTotalPriceProvider);
    final tax = subtotal * 0.0825; // 8.25% tax
    final total = subtotal + tax;
    final orderState = ref.watch(orderPlacementProvider);
    final isSubmitting = orderState.isLoading;

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Order', style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          if (cartItems.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'Clear Cart',
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Clear Order?'),
                    content: const Text('Are you sure you want to remove all items from your cart?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () {
                          ref.read(cartProvider.notifier).clearCart();
                          Navigator.pop(ctx);
                        },
                        child: const Text('Clear', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
      body: cartItems.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF202430) : const Color(0xFFF1EAE0),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.shopping_bag_outlined,
                        size: 56,
                        color: isDark ? Colors.grey[500] : Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Your cart is empty',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 19,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Explore our 3D AR menu and preview dishes on your dining table before placing your order.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () => context.pop(),
                      icon: const Icon(Icons.restaurant_menu),
                      label: const Text('Explore Menu'),
                    ),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                // Cart Items List
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    itemCount: cartItems.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = cartItems[index];
                      final food = item.food;

                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1B1E28) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark ? const Color(0xFF2C3242) : const Color(0xFFEBE5DC),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            // Thumbnail
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: SizedBox(
                                width: 68,
                                height: 68,
                                child: CachedNetworkImage(
                                  imageUrl: food.thumbnailUrl,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),

                            // Details
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    food.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '\$${food.price.toStringAsFixed(2)} each',
                                    style: TextStyle(
                                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '\$${item.totalPrice.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Quantity Stepper
                            Container(
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF262C3A) : const Color(0xFFF1EAE0),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    icon: const Icon(Icons.remove, size: 16),
                                    onPressed: () {
                                      ref.read(cartProvider.notifier).removeItem(food.id);
                                    },
                                  ),
                                  Text(
                                    '${item.quantity}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    icon: const Icon(Icons.add, size: 16),
                                    onPressed: () {
                                      ref.read(cartProvider.notifier).addItem(food);
                                    },
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(width: 6),

                            // Delete button
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, size: 20),
                              color: Colors.redAccent.withValues(alpha: 0.8),
                              onPressed: () {
                                ref.read(cartProvider.notifier).deleteItem(food.id);
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                // Table Selector & Checkout Summary
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF181B24) : Colors.white,
                    border: Border(
                      top: BorderSide(
                        color: isDark ? const Color(0xFF2A2F3D) : const Color(0xFFEBE4DC),
                      ),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 10,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Dining Table Number Selector
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.table_restaurant_rounded, size: 18),
                                SizedBox(width: 6),
                                Text(
                                  'Dining Table #',
                                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                                ),
                              ],
                            ),
                            Row(
                              children: [1, 2, 3, 4, 5].map((tableNum) {
                                final isSelected = _selectedTable == tableNum;
                                return Padding(
                                  padding: const EdgeInsets.only(left: 6),
                                  child: ChoiceChip(
                                    label: Text('$tableNum'),
                                    selected: isSelected,
                                    onSelected: (val) {
                                      if (val) setState(() => _selectedTable = tableNum);
                                    },
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Subtotal
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Subtotal',
                              style: TextStyle(
                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              '\$${subtotal.toStringAsFixed(2)}',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),

                        // Tax
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Estimated Tax (8.25%)',
                              style: TextStyle(
                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              '\$${tax.toStringAsFixed(2)}',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                            ),
                          ],
                        ),
                        const Divider(height: 20),

                        // Total
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Total Amount',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                            ),
                            Text(
                              '\$${total.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 20,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Place Kitchen Order Button
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            onPressed: isSubmitting ? null : _handlePlaceOrder,
                            child: isSubmitting
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    'Place Kitchen Order • \$${total.toStringAsFixed(2)}',
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
