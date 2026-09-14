import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

class ChildJoinApprovalButton extends StatefulWidget {
  const ChildJoinApprovalButton({
    super.key,
    required this.approve,
    required this.onApproved,
  });

  final Future<void> Function() approve;
  final VoidCallback onApproved;

  @override
  State<ChildJoinApprovalButton> createState() =>
      _ChildJoinApprovalButtonState();
}

class _ChildJoinApprovalButtonState extends State<ChildJoinApprovalButton> {
  bool _processing = false;
  String? _error;

  Future<void> _approve() async {
    if (_processing) return;
    setState(() {
      _processing = true;
      _error = null;
    });
    try {
      await widget.approve();
      if (mounted) widget.onApproved();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = switch (error) {
          StateError() => error.message,
          FirebaseFunctionsException() =>
            error.message ?? '参加を許可できませんでした。もう一度お試しください。',
          _ => '参加を許可できませんでした。通信状態を確認してもう一度お試しください。',
        };
      });
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: _processing ? null : _approve,
          icon: _processing
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.approval_outlined),
          label: Text(_processing ? '参加を許可しています…' : 'こどもの参加申請を許可する'),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ],
    );
  }
}
