/// Whether a notice should be visible to a member of [userSociety].
///
/// A notice with no `society` field (or a blank one) is treated as a
/// church-wide announcement and is visible to everyone. A notice tagged
/// with a `society` is only visible to members of that exact society -
/// matching is case/whitespace-insensitive but otherwise exact, so a
/// society whose name is a substring of another's (e.g. "Bethel" vs.
/// "Bethel North") doesn't cross-match.
bool isNoticeVisibleToSociety(
  Map<String, dynamic> noticeData,
  String? userSociety,
) {
  final noticeSociety = (noticeData['society'] ?? '')
      .toString()
      .trim()
      .toLowerCase();
  if (noticeSociety.isEmpty) return true;

  final normalizedUserSociety = (userSociety ?? '').trim().toLowerCase();
  if (normalizedUserSociety.isEmpty) return false;

  return noticeSociety == normalizedUserSociety;
}
