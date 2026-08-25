import 'package:flutter/material.dart';
import 'package:ireader_web/model/parent.dart';

class AddParentDialog extends StatefulWidget {
  final Parent? parent;
  const AddParentDialog({super.key, this.parent});

  @override
  State<AddParentDialog> createState() => _AddParentDialogState();
}

class _AddParentDialogState extends State<AddParentDialog> {
  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}
