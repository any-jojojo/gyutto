import '../constants/app_strings.dart';

class InviteExpirationFormatter {
  const InviteExpirationFormatter._();

  static String format(DateTime expiresAt, {DateTime? now}) {
    final currentTime = now ?? DateTime.now();

    if (!expiresAt.isAfter(currentTime)) {
      return AppStrings.expiredInviteMessage;
    }

    final remaining = expiresAt.difference(currentTime);
    return '${_formatRemainingTime(remaining)}  ${_formatDateTime(expiresAt)}まで';
  }

  static String _formatRemainingTime(Duration duration) {
    final totalMinutes =
        duration.inMinutes + (duration.inSeconds % 60 == 0 ? 0 : 1);
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;

    if (hours > 0 && minutes > 0) {
      return 'あと$hours時間$minutes分有効';
    }

    if (hours > 0) {
      return 'あと$hours時間有効';
    }

    return 'あと$minutes分有効';
  }

  static String _formatDateTime(DateTime dateTime) {
    final year = dateTime.year.toString().padLeft(4, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final day = dateTime.day.toString().padLeft(2, '0');
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');

    return '$year/$month/$day $hour:$minute';
  }
}
