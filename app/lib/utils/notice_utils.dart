/// Whether a notice should be visible to a member of [userSociety].
///
/// A notice with no `society` field (or a blank one) is treated as a
/// church-wide announcement and is visible to everyone. A notice tagged
/// with a `society` is only visible to members of a matching society -
/// matching is case/whitespace-insensitive and tolerant of partial names
/// (e.g. "Bethel" matches "Bethel Society"), consistent with how society
/// names are already compared elsewhere in the app.
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

  return noticeSociety == normalizedUserSociety ||
      noticeSociety.contains(normalizedUserSociety) ||
      normalizedUserSociety.contains(noticeSociety);
}
