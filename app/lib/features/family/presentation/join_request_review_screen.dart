import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../../../models/join_request.dart';
import '../../../repositories/join_request_repository.dart';

class JoinRequestReviewScreen extends StatefulWidget {
  const JoinRequestReviewScreen({
    super.key,
    required this.familyId,
    this.repository,
  });

  final String familyId;
  final JoinRequestRepository? repository;

  @override
  State<JoinRequestReviewScreen> createState() =>
      _JoinRequestReviewScreenState();
}

class _JoinRequestReviewScreenState extends State<JoinRequestReviewScreen> {
  late final JoinRequestRepository _repository;
  late final Stream<List<JoinRequest>> _requestsStream;
  String? _processingUserId;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? JoinRequestRepository();
    _requestsStream = _repository.watchPending(widget.familyId);
  }

  Future<void> _review(JoinRequest request, bool approve) async {
    setState(() => _processingUserId = request.userId);
    try {
      await _repository.review(
        familyId: widget.familyId,
        userId: request.userId,
        approve: approve,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(approve ? '参加を承認しました。' : '参加申請を拒否しました。')),
        );
      }
    } on FirebaseFunctionsException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message ?? '申請を処理できませんでした。')),
        );
      }
    } finally {
      if (mounted) setState(() => _processingUserId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('子アカウントの参加申請')),
      body: StreamBuilder<List<JoinRequest>>(
        stream: _requestsStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('参加申請を読み込めませんでした。'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final requests = snapshot.data!;
          if (requests.isEmpty) {
            return const Center(child: Text('承認待ちの申請はありません。'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            separatorBuilder: (_, _) => const Divider(),
            itemBuilder: (context, index) {
              final request = requests[index];
              final processing = _processingUserId != null;
              return ListTile(
                leading: const CircleAvatar(child: Icon(Icons.child_care)),
                title: Text(request.displayName),
                subtitle: const Text('子アカウントとして参加を申請しています'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: processing
                          ? null
                          : () => _review(request, false),
                      child: const Text('拒否'),
                    ),
                    FilledButton(
                      onPressed: processing
                          ? null
                          : () => _review(request, true),
                      child: const Text('承認'),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
