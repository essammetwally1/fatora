import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/invoice_provider.dart';
import '../widgets/invoice_card.dart';
import 'invoice_details_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<InvoiceProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Fatora')),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showAddDialog(context);
        },
        child: const Icon(Icons.add),
      ),
      body: provider.invoices.isEmpty
          ? const Center(child: Text('No Invoices Yet'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: provider.invoices.length,
              itemBuilder: (context, index) {
                final invoice = provider.invoices[index];

                return Dismissible(
                  key: UniqueKey(),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    color: Colors.red,
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (_) {
                    provider.deleteInvoice(index);
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: InvoiceCard(
                      invoice: invoice,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                InvoiceDetailsScreen(invoice: invoice),
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
    );
  }

  void _showAddDialog(BuildContext context) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Create Invoice'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: 'Invoice Name'),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                if (controller.text.trim().isEmpty) {
                  return;
                }

                await context.read<InvoiceProvider>().createInvoice(
                  controller.text,
                );

                Navigator.pop(context);
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }
}
