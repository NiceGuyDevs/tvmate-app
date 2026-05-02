/// Curated EPG display zones (IANA IDs). Labels are English place names for the picker.
class EpgTimezoneEntry {
  const EpgTimezoneEntry({
    required this.ianaId,
    required this.label,
    required this.chipShort,
  });

  final String ianaId;
  final String label;
  /// Very short text for the playlist card chip (e.g. "NY", "IL").
  final String chipShort;
}

/// Scrollable list below "Local" on the EPG time screen (order: roughly by region then name).
const kEpgTimezoneCatalog = <EpgTimezoneEntry>[
  EpgTimezoneEntry(
    ianaId: 'Pacific/Auckland',
    label: 'Auckland',
    chipShort: 'NZ',
  ),
  EpgTimezoneEntry(
    ianaId: 'Australia/Sydney',
    label: 'Sydney',
    chipShort: 'SYD',
  ),
  EpgTimezoneEntry(
    ianaId: 'Asia/Tokyo',
    label: 'Tokyo',
    chipShort: 'TYO',
  ),
  EpgTimezoneEntry(
    ianaId: 'Asia/Seoul',
    label: 'Seoul',
    chipShort: 'SEL',
  ),
  EpgTimezoneEntry(
    ianaId: 'Asia/Shanghai',
    label: 'Shanghai',
    chipShort: 'CN',
  ),
  EpgTimezoneEntry(
    ianaId: 'Asia/Singapore',
    label: 'Singapore',
    chipShort: 'SG',
  ),
  EpgTimezoneEntry(
    ianaId: 'Asia/Kolkata',
    label: 'India',
    chipShort: 'IN',
  ),
  EpgTimezoneEntry(
    ianaId: 'Asia/Karachi',
    label: 'Pakistan',
    chipShort: 'PK',
  ),
  EpgTimezoneEntry(
    ianaId: 'Asia/Dubai',
    label: 'Dubai',
    chipShort: 'DXB',
  ),
  EpgTimezoneEntry(
    ianaId: 'Asia/Riyadh',
    label: 'Riyadh',
    chipShort: 'KSA',
  ),
  EpgTimezoneEntry(
    ianaId: 'Asia/Jerusalem',
    label: 'Israel',
    chipShort: 'IL',
  ),
  EpgTimezoneEntry(
    ianaId: 'Europe/Athens',
    label: 'Athens',
    chipShort: 'GR',
  ),
  EpgTimezoneEntry(
    ianaId: 'Europe/Bucharest',
    label: 'Bucharest',
    chipShort: 'RO',
  ),
  EpgTimezoneEntry(
    ianaId: 'Europe/Berlin',
    label: 'Berlin',
    chipShort: 'DE',
  ),
  EpgTimezoneEntry(
    ianaId: 'Europe/Paris',
    label: 'Paris',
    chipShort: 'FR',
  ),
  EpgTimezoneEntry(
    ianaId: 'Europe/London',
    label: 'London',
    chipShort: 'UK',
  ),
  EpgTimezoneEntry(
    ianaId: 'Europe/Madrid',
    label: 'Madrid',
    chipShort: 'ES',
  ),
  EpgTimezoneEntry(
    ianaId: 'America/Sao_Paulo',
    label: 'São Paulo',
    chipShort: 'BR',
  ),
  EpgTimezoneEntry(
    ianaId: 'America/New_York',
    label: 'New York',
    chipShort: 'NY',
  ),
  EpgTimezoneEntry(
    ianaId: 'America/Chicago',
    label: 'Chicago',
    chipShort: 'CHI',
  ),
  EpgTimezoneEntry(
    ianaId: 'America/Denver',
    label: 'Denver',
    chipShort: 'DEN',
  ),
  EpgTimezoneEntry(
    ianaId: 'America/Los_Angeles',
    label: 'Los Angeles',
    chipShort: 'LA',
  ),
  EpgTimezoneEntry(
    ianaId: 'America/Toronto',
    label: 'Toronto',
    chipShort: 'TO',
  ),
  EpgTimezoneEntry(
    ianaId: 'America/Mexico_City',
    label: 'Mexico City',
    chipShort: 'MX',
  ),
];

String chipShortForIana(String ianaId) {
  for (final e in kEpgTimezoneCatalog) {
    if (e.ianaId == ianaId) return e.chipShort;
  }
  final parts = ianaId.split('/');
  if (parts.isEmpty) return ianaId;
  final last = parts.last.replaceAll('_', ' ');
  if (last.length <= 5) return last;
  return last.substring(0, 5);
}
