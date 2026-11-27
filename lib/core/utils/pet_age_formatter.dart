/// Formats a pet age string so whole-year `.0` decimals (e.g. `1.0 years`,
/// `12.0 years`) are shown without `.0` (`1 year`, `12 years`), while non-zero
/// decimal ages (`1.2 years`, `12.1 years`) keep their decimal value.
String formatPetAge(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return '';

  final match = RegExp(
    r'^(\d+)\.0\s+years?(.*)$',
    caseSensitive: false,
  ).firstMatch(trimmed);
  if (match != null) {
    final yearsStr = match.group(1)!;
    final years = int.tryParse(yearsStr) ?? 0;
    final suffix = match.group(2) ?? '';
    final unit = years == 1 ? 'year' : 'years';
    return '$yearsStr $unit$suffix';
  }

  return trimmed;
}
