import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class FavoriteContact {
  const FavoriteContact({
    required this.displayName,
    required this.phoneNumber,
    this.aliases = const [],
  });

  final String displayName;
  final String phoneNumber;
  final List<String> aliases;

  Map<String, Object?> toJson() => {
    'displayName': displayName,
    'phoneNumber': phoneNumber,
    'aliases': aliases,
  };

  factory FavoriteContact.fromJson(Map<String, dynamic> json) =>
      FavoriteContact(
        displayName: json['displayName'] as String? ?? '',
        phoneNumber: json['phoneNumber'] as String? ?? '',
        aliases: (json['aliases'] as List<dynamic>? ?? const [])
            .map((value) => value.toString())
            .toList(),
      );
}

class FavoriteContactsRepository {
  FavoriteContactsRepository(this.preferences);

  static const _key = 'favorite_contacts_v1';
  final SharedPreferences preferences;

  List<FavoriteContact> getAll() {
    final raw = preferences.getString(_key);
    if (raw == null) return const [];
    try {
      final stored = (jsonDecode(raw) as List<dynamic>)
          .map((item) => FavoriteContact.fromJson(item as Map<String, dynamic>))
          .toList();
      final unique = <String, FavoriteContact>{};
      for (final contact in stored) {
        final phone = _phoneKey(contact.phoneNumber);
        if (phone.isEmpty) continue;
        final previous = unique[phone];
        unique[phone] = previous == null
            ? contact
            : FavoriteContact(
                displayName: previous.displayName,
                phoneNumber: previous.phoneNumber,
                aliases: {
                  ...previous.aliases,
                  ...contact.aliases,
                  contact.displayName,
                }.toList(),
              );
      }
      return unique.values.toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> save(
    FavoriteContact contact, {
    String? previousPhoneNumber,
  }) async {
    // Empty/corrupt storage returns a const list; copy before adding a contact.
    final contacts = List<FavoriteContact>.of(getAll());
    final index = contacts.indexWhere(
      (item) =>
          _phoneKey(item.phoneNumber) ==
          _phoneKey(previousPhoneNumber ?? contact.phoneNumber),
    );
    if (index < 0) {
      contacts.add(contact);
    } else {
      final existing = contacts[index];
      contacts[index] = previousPhoneNumber != null
          ? contact
          : FavoriteContact(
              displayName: existing.displayName,
              phoneNumber: existing.phoneNumber,
              aliases: {
                ...existing.aliases,
                ...contact.aliases,
                if (_normalize(existing.displayName) !=
                    _normalize(contact.displayName))
                  contact.displayName,
              }.toList(),
            );
    }
    await _write(contacts);
  }

  Future<void> delete(String displayName, {String? phoneNumber}) async =>
      _write(
        getAll()
            .where(
              (item) => phoneNumber != null
                  ? _phoneKey(item.phoneNumber) != _phoneKey(phoneNumber)
                  : item.displayName.toLowerCase() != displayName.toLowerCase(),
            )
            .toList(),
      );

  List<FavoriteContact> findMatches(String name) {
    final normalized = _normalize(name);
    if (normalized.isEmpty) return const [];
    final contacts = getAll();
    final exact = contacts
        .where((contact) => _normalize(contact.displayName) == normalized)
        .toList();
    if (exact.isNotEmpty) return exact;
    final ranked = <({FavoriteContact contact, double score})>[];
    for (final contact in contacts) {
      final names = [contact.displayName, ...contact.aliases];
      final score = names
          .map((candidate) => _similarity(normalized, _normalize(candidate)))
          .fold<double>(0, (best, value) => value > best ? value : best);
      if (score >= 0.62) ranked.add((contact: contact, score: score));
    }
    ranked.sort((a, b) => b.score.compareTo(a.score));
    if (ranked.isEmpty) return const [];
    final best = ranked.first.score;
    return ranked
        .where((entry) => best - entry.score <= 0.09)
        .map((entry) => entry.contact)
        .toList();
  }

  /// Returns only a clear single match. Ambiguous matches must be clarified.
  FavoriteContact? resolve(String name) {
    final matches = findMatches(name);
    return matches.length == 1 ? matches.single : null;
  }

  FavoriteContact? chooseFromReply(
    String reply,
    List<FavoriteContact> options,
  ) {
    final normalized = _normalize(reply);
    final ordinal = RegExp(
      r'\b(first|one|1st|second|two|2nd|third|three|3rd)\b',
    ).firstMatch(normalized)?.group(1);
    final index = switch (ordinal) {
      'first' || 'one' || '1st' => 0,
      'second' || 'two' || '2nd' => 1,
      'third' || 'three' || '3rd' => 2,
      _ => -1,
    };
    if (index >= 0 && index < options.length) return options[index];
    final exact = options
        .where((contact) => _normalize(contact.displayName) == normalized)
        .toList();
    if (exact.length == 1) return exact.single;
    final matches = findMatches(reply);
    final matchingOptions = matches
        .where(
          (match) => options.any(
            (option) =>
                _phoneKey(option.phoneNumber) == _phoneKey(match.phoneNumber),
          ),
        )
        .toList();
    return matchingOptions.length == 1 ? matchingOptions.single : null;
  }

  static double _similarity(String query, String candidate) {
    if (query == candidate) return 1;
    final queryTokens = query
        .split(' ')
        .where((token) => token.isNotEmpty)
        .toList();
    final candidateTokens = candidate
        .split(' ')
        .where((token) => token.isNotEmpty)
        .toList();
    if (queryTokens.isEmpty || candidateTokens.isEmpty) return 0;
    if (candidate.contains(query) || query.contains(candidate)) return 0.96;

    var tokenTotal = 0.0;
    for (final token in queryTokens) {
      var best = 0.0;
      for (final candidateToken in candidateTokens) {
        if (candidateToken == token) {
          best = 1;
        } else if (candidateToken.contains(token) ||
            token.contains(candidateToken)) {
          best = best < 0.88 ? 0.88 : best;
        } else {
          final distance = _editDistance(token, candidateToken);
          final scale =
              distance.toDouble() /
              (token.length > candidateToken.length
                  ? token.length.toDouble()
                  : candidateToken.length.toDouble());
          final editScore = 1 - scale;
          final phoneticScore = _soundex(token) == _soundex(candidateToken)
              ? 0.82
              : 0.0;
          final score = editScore > phoneticScore ? editScore : phoneticScore;
          if (score > best) best = score;
        }
      }
      tokenTotal += best;
    }
    return tokenTotal / queryTokens.length;
  }

  static int _editDistance(String a, String b) {
    var previous = List<int>.generate(b.length + 1, (i) => i);
    for (var i = 0; i < a.length; i++) {
      final current = List<int>.filled(b.length + 1, 0)..[0] = i + 1;
      for (var j = 0; j < b.length; j++) {
        final substitution = previous[j] + (a[i] == b[j] ? 0 : 1);
        final insertion = current[j] + 1;
        final deletion = previous[j + 1] + 1;
        current[j + 1] = [
          substitution,
          insertion,
          deletion,
        ].reduce((x, y) => x < y ? x : y);
      }
      previous = current;
    }
    return previous[b.length];
  }

  static String _soundex(String value) {
    if (value.isEmpty) return '';
    const groups = {
      'bfpv': '1',
      'cgjkqsxz': '2',
      'dt': '3',
      'l': '4',
      'mn': '5',
      'r': '6',
    };
    String codeFor(String char) => groups.entries
        .firstWhere(
          (entry) => entry.key.contains(char),
          orElse: () => const MapEntry('', '0'),
        )
        .value;
    final first = value[0];
    final out = StringBuffer(first);
    var previous = codeFor(first);
    for (final char in value.substring(1).split('')) {
      final code = codeFor(char);
      if (code != '0' && code != previous) out.write(code);
      previous = code;
    }
    final result = out.toString().padRight(4, '0');
    return result.substring(0, 4);
  }

  Future<void> _write(List<FavoriteContact> contacts) => preferences.setString(
    _key,
    jsonEncode(contacts.map((contact) => contact.toJson()).toList()),
  );

  static String _normalize(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();

  static String _phoneKey(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (phone.trim().startsWith('+91') && digits.length == 12)
      return digits.substring(2);
    return digits;
  }
}
