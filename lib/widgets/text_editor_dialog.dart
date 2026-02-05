import 'package:flutter/material.dart';
import '../models/drawing_models.dart';

class TextEditorDialog extends StatefulWidget {
  final CanvasText initialText;
  final bool isEdit;

  const TextEditorDialog({super.key, required this.initialText, this.isEdit = false});

  @override
  State<TextEditorDialog> createState() => _TextEditorDialogState();
}

class _TextEditorDialogState extends State<TextEditorDialog> {
  late TextEditingController _controller;
  late double fontSize;
  late Color color;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText.text);
    fontSize = widget.initialText.fontSize;
    color = widget.initialText.color;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF2C2C2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(widget.isEdit ? 'Edit Text' : 'Add Text', style: const TextStyle(color: Colors.white)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'Type something...',
              hintStyle: TextStyle(color: Colors.white38),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const Text("Size", style: TextStyle(color: Colors.white70)),
              Expanded(
                child: Slider(
                  value: fontSize.clamp(12, 200),
                  min: 12, max: 200,
                  onChanged: (v) => setState(() => fontSize = v),
                ),
              ),
            ],
          )
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
        ElevatedButton(
          onPressed: () {
            widget.initialText.text = _controller.text;
            widget.initialText.fontSize = fontSize;
            Navigator.pop(context, true);
          },
          child: const Text('OK'),
        ),
      ],
    );
  }
}
