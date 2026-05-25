import 'package:flutter/material.dart';

class InvoiceNameDialog extends StatefulWidget {
  final String? initialTitle;

  const InvoiceNameDialog({super.key, this.initialTitle});

  @override
  State<InvoiceNameDialog> createState() => _InvoiceNameDialogState();
}

class _InvoiceNameDialogState extends State<InvoiceNameDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _controller;

  bool _isSubmitting = false;

  bool get _isEditing => widget.initialTitle != null;

  @override
  void initState() {
    super.initState();

    _controller = TextEditingController(text: widget.initialTitle ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: Text(_isEditing ? 'تعديل اسم الفاتورة' : 'إنشاء فاتورة'),
        content: Form(
          key: _formKey,
          child: TextFormField(
            controller: _controller,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'اسم الفاتورة',
              hintText: 'مثال: حسابات عصام',
            ),
            validator: _validateTitle,
            onFieldSubmitted: (_) => _submit(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isSubmitting ? null : () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: _isSubmitting ? null : _submit,
            child: Text(_isEditing ? 'حفظ' : 'إنشاء'),
          ),
        ],
      ),
    );
  }

  String? _validateTitle(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'اسم الفاتورة مطلوب';
    }

    return null;
  }

  void _submit() {
    if (_isSubmitting) return;

    final formState = _formKey.currentState;
    if (formState == null || !formState.validate()) return;

    _isSubmitting = true;

    FocusScope.of(context).unfocus();

    Navigator.pop(context, _controller.text.trim());
  }
}
