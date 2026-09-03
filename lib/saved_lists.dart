// Saved lists — records set aside for later research.
//
// One JSON file under the user's data directory holds every list. It is small
// enough to read and write whole on each change, which keeps the store to a
// plain object with no database, no schema migration, and no dependency.

import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// A record set aside, with the query that found it.
class SavedItem {
  SavedItem({required this.record, required this.query, required this.added})
    : key = keyFor(record);

  final Map<String, dynamic> record;

  /// The query this record came from. Kept as provenance: months later, how a
  /// verse was found is often the thing worth remembering.
  final String query;

  final DateTime added;

  /// Identity, for keeping the same record out of a list twice.
  ///
  /// Records carry no id of their own, and not every source has citation
  /// numbering QQL can cite — so the content is the key. `score` and `ranked`
  /// are dropped first: the same ayah found by two different ranked queries
  /// is still the same ayah.
  final String key;

  static String keyFor(Map<String, dynamic> record) {
    final stable = SplayTreeMap<String, dynamic>.of(record)
      ..remove('score')
      ..remove('ranked');
    return jsonEncode(stable);
  }

  Map<String, dynamic> toJson() => {
    'record': record,
    'query': query,
    'added': added.toIso8601String(),
  };

  /// Null when the entry is not a usable item, so one bad entry costs one
  /// item rather than the whole file.
  static SavedItem? fromJson(Object? json) {
    if (json is! Map) return null;
    final record = json['record'];
    if (record is! Map) return null;
    return SavedItem(
      record: Map<String, dynamic>.from(record),
      query: '${json['query'] ?? ''}',
      added: DateTime.tryParse('${json['added']}') ?? DateTime.now(),
    );
  }
}

/// One named list.
class SavedList {
  SavedList({
    required this.id,
    required this.name,
    required this.created,
    List<SavedItem> items = const [],
  }) : items = [...items],
       _keys = {for (final item in items) item.key};

  final String id;
  String name;
  final DateTime created;

  /// In the order they were added.
  final List<SavedItem> items;

  final Set<String> _keys;

  bool contains(Map<String, dynamic> record) =>
      _keys.contains(SavedItem.keyFor(record));

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'created': created.toIso8601String(),
    'items': [for (final item in items) item.toJson()],
  };

  static SavedList? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    if (id is! String) return null;
    return SavedList(
      id: id,
      name: '${json['name'] ?? 'Untitled'}',
      created: DateTime.tryParse('${json['created']}') ?? DateTime.now(),
      items: [
        for (final entry in (json['items'] as List? ?? const []))
          ?SavedItem.fromJson(entry),
      ],
    );
  }
}

/// Every list, and the file they live in.
class SavedLists extends ChangeNotifier {
  SavedLists({File? file}) : _file = file ?? defaultFile();

  final File _file;
  final List<SavedList> _lists = [];

  /// Set when the file on disk could not be read, for the UI to surface.
  String? loadWarning;

  /// Most recently created first — the list being built is the one wanted.
  List<SavedList> get all => List.unmodifiable(_lists);

  bool get isEmpty => _lists.isEmpty;

  int get itemCount => _lists.fold(0, (n, list) => n + list.items.length);

  /// Read the file. A missing file is simply no lists.
  void load() {
    _lists.clear();
    loadWarning = null;

    if (!_file.existsSync()) return;

    try {
      final decoded = jsonDecode(_file.readAsStringSync());
      final lists = (decoded is Map ? decoded['lists'] : null) as List?;
      for (final entry in lists ?? const []) {
        final list = SavedList.fromJson(entry);
        if (list != null) _lists.add(list);
      }
    } catch (e) {
      // Move the unreadable file aside rather than saving over it. Losing
      // saved research to a parse error is not an acceptable failure.
      final aside =
          '${_file.path}.unreadable-'
          '${DateTime.now().millisecondsSinceEpoch}';
      try {
        _file.renameSync(aside);
        loadWarning = 'Saved lists could not be read ($e).\nThe file was kept '
            'at $aside and a new one started.';
      } catch (_) {
        loadWarning = 'Saved lists could not be read ($e).';
      }
    }
  }

  SavedList? byId(String? id) {
    for (final list in _lists) {
      if (list.id == id) return list;
    }
    return null;
  }

  /// The lists this record is already in.
  List<SavedList> containing(Map<String, dynamic> record) => [
    for (final list in _lists)
      if (list.contains(record)) list,
  ];

  /// Create a list and return its id.
  String create(String name) {
    final list = SavedList(
      id: 'l${DateTime.now().microsecondsSinceEpoch}',
      name: _clean(name),
      created: DateTime.now(),
    );
    _lists.insert(0, list);
    _persist();
    return list.id;
  }

  void rename(String id, String name) {
    final list = byId(id);
    if (list == null) return;
    list.name = _clean(name);
    _persist();
  }

  void delete(String id) {
    _lists.removeWhere((list) => list.id == id);
    _persist();
  }

  /// Add [record] to a list. False when it was already there.
  bool add(String listId, Map<String, dynamic> record, String query) {
    final list = byId(listId);
    if (list == null || list.contains(record)) return false;

    final item = SavedItem(record: record, query: query, added: DateTime.now());
    list.items.add(item);
    list._keys.add(item.key);
    _persist();
    return true;
  }

  void removeItem(String listId, String key) {
    final list = byId(listId);
    if (list == null) return;
    list.items.removeWhere((item) => item.key == key);
    list._keys.remove(key);
    _persist();
  }

  /// Add to the list if absent, remove it if present.
  void toggle(String listId, Map<String, dynamic> record, String query) {
    final list = byId(listId);
    if (list == null) return;
    if (list.contains(record)) {
      removeItem(listId, SavedItem.keyFor(record));
    } else {
      add(listId, record, query);
    }
  }

  static String _clean(String name) {
    final trimmed = name.trim();
    return trimmed.isEmpty ? 'Untitled' : trimmed;
  }

  void _persist() {
    notifyListeners();
    try {
      _file.parent.createSync(recursive: true);
      // Write beside the real file and rename over it, so an interrupted
      // write cannot leave a half-written list file behind.
      final temporary = File('${_file.path}.tmp');
      temporary.writeAsStringSync(
        jsonEncode({
          'version': 1,
          'lists': [for (final list in _lists) list.toJson()],
        }),
      );
      temporary.renameSync(_file.path);
    } catch (e) {
      loadWarning = 'Could not save to ${_file.path}: $e';
    }
  }

  /// `lists.json` in the platform's per-user data directory.
  static File defaultFile() {
    final home =
        Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '.';

    final String directory;
    if (Platform.isWindows) {
      final appData = Platform.environment['APPDATA'] ?? home;
      directory = '$appData\\qqlang_explorer';
    } else if (Platform.isMacOS) {
      directory = '$home/Library/Application Support/qqlang_explorer';
    } else {
      final data =
          Platform.environment['XDG_DATA_HOME'] ?? '$home/.local/share';
      directory = '$data/qqlang_explorer';
    }
    return File('$directory${Platform.pathSeparator}lists.json');
  }
}
