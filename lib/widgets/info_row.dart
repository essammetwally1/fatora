import 'package:flutter/material.dart';

class InfoRow extends StatelessWidget {
  final String title;
  final String value;

  const InfoRow({super.key, required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$title: ',
          style: TextStyle(
            color: Theme.of(context).hintColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        Expanded(child: Text(value)),
      ],
    );
  }
}
