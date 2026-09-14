import 'package:flutter/material.dart';

import '../../models/join_request.dart';
import '../../repositories/join_request_repository.dart';
import '../invite/presentation/child_join_approval_button.dart';

class PendingChildJoinRequests extends StatefulWidget {
  const PendingChildJoinRequests({
    super.key,
    required this.familyId,
    this.requestsStream,
    this.approveRequest,
  });

  final String familyId;
  final Stream<List<JoinRequest>>? requestsStream;
  final Future<void> Function(String familyId, String userId)? approveRequest;

  @override
  State<PendingChildJoinRequests> createState() =>
      _PendingChildJoinRequestsState();
}

class _PendingChildJoinRequestsState extends State<PendingChildJoinRequests> {
  late final Stream<List<JoinRequest>> _requests;
  final Set<String> _approved = {};

  @override
  void initState() {
    super.initState();
    _requests =
        widget.requestsStream ??
        JoinRequestRepository().watchPending(widget.familyId);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<JoinRequest>>(
      stream: _requests,
      builder: (context, snapshot) {
        final requests = (snapshot.data ?? const <JoinRequest>[]).where(
          (request) =>
              request.status == 'pending' &&
              !_approved.contains(request.userId),
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_approved.isNotEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('こども参加申請を許可しました！'),
                ),
              ),
            if (snapshot.hasError)
              const Text('参加申請を読み込めませんでした。通信状態を確認し、ページを再読み込みしてください。'),
            if (!snapshot.hasError)
              for (final request in requests)
                Card(
                  key: ValueKey(request.userId),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '${request.displayName}さんから家族への参加申請が届いています。',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 12),
                        ChildJoinApprovalButton(
                          approve: () async {
                            final approve = widget.approveRequest;
                            if (approve != null) {
                              await approve(widget.familyId, request.userId);
                            } else {
                              await JoinRequestRepository().review(
                                familyId: widget.familyId,
                                userId: request.userId,
                                approve: true,
                              );
                            }
                            if (mounted) {
                              setState(() => _approved.add(request.userId));
                            }
                          },
                          onApproved: () {},
                        ),
                      ],
                    ),
                  ),
                ),
          ],
        );
      },
    );
  }
}
