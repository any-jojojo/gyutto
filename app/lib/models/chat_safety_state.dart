class ChatSafetyState {
  const ChatSafetyState({
    this.role = 'unknown',
    this.active = false,
    this.safetyAccepted = false,
    this.adultConfirmed = false,
    this.permission = 'pending',
    this.serverVerified = false,
  });
  final String role;
  final bool active;
  final bool safetyAccepted;
  final bool adultConfirmed;
  final String permission;
  final bool serverVerified;
  bool get isAdult => role == 'familyAdmin' || role == 'parent';
  bool get canChat =>
      serverVerified &&
      active &&
      safetyAccepted &&
      (isAdult ? adultConfirmed : role == 'child' && permission == 'allowed');
}
