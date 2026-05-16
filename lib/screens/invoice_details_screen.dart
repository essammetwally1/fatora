import 'package:fatora/core/utils/formatters.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/models/invoice_item_model.dart';
import '../data/models/invoice_model.dart';
import '../providers/invoice_provider.dart';

class InvoiceDetailsScreen extends StatelessWidget {
  final InvoiceModel invoice;

  const InvoiceDetailsScreen({super.key, required this.invoice});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<InvoiceProvider>();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xffF5F7FA),

        appBar: AppBar(
          elevation: 0,
          centerTitle: true,
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.black,

          title: Text(
            invoice.title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),

        // WITH THIS MODERN DESIGN
        floatingActionButton: Container(
          height: 60,

          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),

            boxShadow: [
              BoxShadow(
                color: Theme.of(context).primaryColor.withOpacity(.25),

                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),

          child: FloatingActionButton.extended(
            elevation: 0,

            backgroundColor: Theme.of(context).primaryColor,

            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),

            onPressed: () {
              _showAddItemBottomSheet(context);
            },

            icon: const Icon(Icons.add_rounded, color: Colors.white, size: 24),

            label: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),

              child: Text(
                'إضافة عنصر',

                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),

        body: Column(
          children: [
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),

              padding: const EdgeInsets.all(18),

              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).primaryColor,
                    Theme.of(context).primaryColor.withOpacity(.8),
                  ],
                ),

                borderRadius: BorderRadius.circular(24),
              ),

              child: Row(
                children: [
                  Expanded(
                    child: _topCard(
                      title: 'الإجمالي',
                      value: Formatters.formatMoney(invoice.total),
                      icon: Icons.receipt_long,
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: _topCard(
                      title: 'المدفوع',
                      value: Formatters.formatMoney(invoice.paidTotal),
                      icon: Icons.check_circle,
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: _topCard(
                      title: 'المتبقي',
                      value: Formatters.formatMoney(invoice.unpaidTotal),
                      icon: Icons.pending_actions,
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: invoice.items.isEmpty
                  ? const Center(
                      child: Text(
                        'لا توجد عناصر',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(
                        left: 16,
                        right: 16,
                        bottom: 120,
                      ),

                      itemCount: invoice.items.length,

                      itemBuilder: (context, index) {
                        final item = invoice.items[index];

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 14),

                          child: Dismissible(
                            key: UniqueKey(),

                            direction: DismissDirection.startToEnd,

                            background: Container(
                              alignment: Alignment.centerLeft,

                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                              ),

                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(24),
                              ),

                              child: const Icon(
                                Icons.delete,
                                color: Colors.white,
                                size: 30,
                              ),
                            ),

                            onDismissed: (_) {
                              provider.deleteItem(
                                invoice: invoice,
                                index: index,
                              );
                            },

                            child: _InvoiceModernCard(item: item),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topCard({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),

      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.15),

        borderRadius: BorderRadius.circular(20),
      ),

      child: Column(
        children: [
          Icon(icon, color: Colors.white),

          const SizedBox(height: 10),

          Text(
            title,

            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),

          const SizedBox(height: 8),

          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,

            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  void _showAddItemBottomSheet(BuildContext context) {
    final customerController = TextEditingController();

    final itemController = TextEditingController();

    final priceController = TextEditingController();

    final noteController = TextEditingController();

    bool isPaid = false;

    showModalBottomSheet(
      context: context,

      isScrollControlled: true,

      backgroundColor: Colors.white,

      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),

      builder: (_) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 18,
                right: 18,
                top: 20,

                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),

              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,

                  children: [
                    Container(
                      width: 60,
                      height: 6,

                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,

                        borderRadius: BorderRadius.circular(50),
                      ),
                    ),

                    const SizedBox(height: 20),

                    const Text(
                      'إضافة عنصر',

                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 24),

                    ArabicTextField(
                      controller: customerController,

                      hint: 'اسم العميل',

                      icon: Icons.person,
                    ),

                    const SizedBox(height: 14),

                    ArabicTextField(
                      controller: itemController,

                      hint: 'اسم المنتج',

                      icon: Icons.inventory,
                    ),

                    const SizedBox(height: 14),

                    ArabicTextField(
                      controller: priceController,

                      hint: 'السعر',

                      icon: Icons.payments_outlined,

                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),

                    const SizedBox(height: 14),

                    ArabicTextField(
                      controller: noteController,

                      hint: 'ملاحظات',

                      icon: Icons.edit_note_outlined,

                      maxLines: 3,
                    ),

                    const SizedBox(height: 8),

                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,

                        borderRadius: BorderRadius.circular(16),
                      ),

                      child: CheckboxListTile(
                        value: isPaid,

                        title: const Text('تم الدفع'),

                        controlAffinity: ListTileControlAffinity.leading,

                        onChanged: (value) {
                          setModalState(() {
                            isPaid = value ?? false;
                          });
                        },
                      ),
                    ),

                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      height: 56,

                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),

                        onPressed: () async {
                          final item = InvoiceItemModel(
                            date: DateTime.now(),

                            customerName: customerController.text.trim(),

                            itemName: itemController.text.trim(),

                            price:
                                double.tryParse(priceController.text.trim()) ??
                                0,

                            note: noteController.text.trim(),

                            isPaid: isPaid,
                          );

                          await context.read<InvoiceProvider>().addItem(
                            invoice: invoice,
                            item: item,
                          );

                          Navigator.pop(context);
                        },

                        child: const Text(
                          'حفظ العنصر',

                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _InvoiceModernCard extends StatelessWidget {
  final InvoiceItemModel item;

  const _InvoiceModernCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius: BorderRadius.circular(24),

        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),

      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.customerName,

                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),

                decoration: BoxDecoration(
                  color: item.isPaid
                      ? Colors.green.withOpacity(.12)
                      : Colors.orange.withOpacity(.12),

                  borderRadius: BorderRadius.circular(50),
                ),

                child: Text(
                  item.isPaid ? 'مدفوع' : 'غير مدفوع',

                  style: TextStyle(
                    color: item.isPaid ? Colors.green : Colors.orange,

                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          _row('المنتج', item.itemName),

          const SizedBox(height: 10),

          _row('التاريخ', Formatters.formatDate(item.date)),

          const SizedBox(height: 10),

          _row('الملاحظات', item.note.isEmpty ? 'لا يوجد' : item.note),

          const SizedBox(height: 18),

          Container(
            width: double.infinity,

            padding: const EdgeInsets.symmetric(vertical: 14),

            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,

              borderRadius: BorderRadius.circular(16),
            ),

            child: Text(
              Formatters.formatMoney(item.price),

              textAlign: TextAlign.center,

              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String title, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        Expanded(
          child: Text(
            value,

            textAlign: TextAlign.left,

            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),

        const SizedBox(width: 12),

        Text(
          '$title :',

          style: TextStyle(
            color: Colors.grey.shade700,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class ArabicTextField extends StatelessWidget {
  final TextEditingController controller;

  final String hint;

  final IconData icon;

  final TextInputType? keyboardType;

  final int maxLines;

  const ArabicTextField({
    super.key,
    required this.controller,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,

      keyboardType: keyboardType,

      maxLines: maxLines,

      textAlign: TextAlign.right,

      decoration: InputDecoration(
        hintText: hint,

        prefixIcon: Icon(icon),

        filled: true,

        fillColor: Colors.grey.shade100,

        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),

        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),

          borderSide: BorderSide.none,
        ),

        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),

          borderSide: BorderSide(
            color: Theme.of(context).primaryColor,
            width: 1.5,
          ),
        ),
      ),
    );
  }
}
