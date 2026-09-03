// The saved-list surfaces: the drawer that holds every list, and the button
// on a result that puts it in one.

import 'package:flutter/material.dart';

import 'saved_lists.dart';

/// Sentinel for the "New list" entry, which cannot collide with a list id.
const _newList = ' new';

/// The bookmark on a result card.
///
/// A record can be in any number of lists, so this is a checklist rather than
/// a single choice — tapping a checked list takes the record back out.
class AddToListButton extends StatelessWidget {
  const AddToListButton({
    super.key,
    required this.lists,
    required this.record,
    required this.query,
  });

  final SavedLists lists;
  final Map<String, dynamic> record;

  /// The query that produced this record, saved alongside it.
  final String query;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final saved = lists.containing(record);

    return PopupMenuButton<String>(
      tooltip: saved.isEmpty
          ? 'Save to a list'
          : 'Saved in ${saved.map((l) => l.name).join(', ')}',
      position: PopupMenuPosition.under,
      icon: Icon(
        saved.isEmpty ? Icons.bookmark_add_outlined : Icons.bookmark_rounded,
        size: 18,
        color: saved.isEmpty ? null : colors.primary,
      ),
      itemBuilder: (context) => [
        for (final list in lists.all)
          CheckedPopupMenuItem(
            value: list.id,
            checked: list.contains(record),
            child: Text(list.name, overflow: TextOverflow.ellipsis),
          ),
        if (!lists.isEmpty) const PopupMenuDivider(),
        const PopupMenuItem(
          value: _newList,
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.add_rounded, size: 20),
            title: Text('New list'),
          ),
        ),
      ],
      onSelected: (value) async {
        // Held before the await, so the dialog closing cannot invalidate it.
        final messenger = ScaffoldMessenger.of(context);

        if (value == _newList) {
          final name = await promptForName(context, title: 'New list');
          if (name == null) return;
          final id = lists.create(name);
          lists.add(id, record, query);
          _say(messenger, 'Saved to ${lists.byId(id)!.name}');
          return;
        }

        final list = lists.byId(value);
        if (list == null) return;
        final wasIn = list.contains(record);
        lists.toggle(value, record, query);
        _say(
          messenger,
          wasIn ? 'Removed from ${list.name}' : 'Saved to ${list.name}',
        );
      },
    );
  }

  static void _say(ScaffoldMessengerState messenger, String text) {
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          behavior: SnackBarBehavior.floating,
          width: 320,
          duration: const Duration(milliseconds: 1400),
        ),
      );
  }
}

/// Every list, with the one being viewed marked.
class ListsDrawer extends StatelessWidget {
  const ListsDrawer({
    super.key,
    required this.lists,
    required this.openListId,
    required this.onOpen,
  });

  final SavedLists lists;

  /// The list currently shown in the body, if any.
  final String? openListId;

  /// Called with a list id to show it, or null to go back to the results.
  final void Function(String? id) onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Drawer(
      width: 340,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Row(
                children: [
                  Text('Lists', style: theme.textTheme.titleLarge),
                  const Spacer(),
                  if (!lists.isEmpty)
                    Text(
                      '${lists.itemCount} saved',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.tonalIcon(
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('New list'),
                  onPressed: () async {
                    final name = await promptForName(
                      context,
                      title: 'New list',
                    );
                    if (name != null) lists.create(name);
                  },
                ),
              ),
            ),
            if (lists.loadWarning != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Text(
                  lists.loadWarning!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.error,
                    height: 1.4,
                  ),
                ),
              ),
            const Divider(height: 1),
            Expanded(
              child: lists.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(28),
                      child: Text(
                        'No lists yet.\n\nMake one here, or use the bookmark '
                        'on any result to save it straight into a new list.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                          height: 1.6,
                        ),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      children: [
                        for (final list in lists.all)
                          _ListTile(
                            list: list,
                            lists: lists,
                            selected: list.id == openListId,
                            onOpen: onOpen,
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ListTile extends StatelessWidget {
  const _ListTile({
    required this.list,
    required this.lists,
    required this.selected,
    required this.onOpen,
  });

  final SavedList list;
  final SavedLists lists;
  final bool selected;
  final void Function(String? id) onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      selected: selected,
      leading: Icon(
        selected ? Icons.folder_open_rounded : Icons.folder_rounded,
        size: 20,
      ),
      title: Text(list.name, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${list.items.length} ${list.items.length == 1 ? 'item' : 'items'}',
        style: theme.textTheme.bodySmall,
      ),
      onTap: () {
        onOpen(list.id);
        Navigator.of(context).pop();
      },
      trailing: PopupMenuButton<String>(
        tooltip: 'List actions',
        icon: const Icon(Icons.more_vert_rounded, size: 18),
        itemBuilder: (context) => const [
          PopupMenuItem(value: 'rename', child: Text('Rename')),
          PopupMenuItem(value: 'delete', child: Text('Delete')),
        ],
        onSelected: (action) async {
          if (action == 'rename') {
            final name = await promptForName(
              context,
              title: 'Rename list',
              initial: list.name,
            );
            if (name != null) lists.rename(list.id, name);
            return;
          }

          // Only worth a confirmation when there is something to lose.
          if (list.items.isNotEmpty) {
            final confirmed = await _confirmDelete(context, list);
            if (!confirmed) return;
          }
          if (selected) onOpen(null);
          lists.delete(list.id);
        },
      ),
    );
  }

  static Future<bool> _confirmDelete(BuildContext context, SavedList list) =>
      showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Delete "${list.name}"?'),
          content: Text(
            'It holds ${list.items.length} saved '
            '${list.items.length == 1 ? 'record' : 'records'}. '
            'This cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        ),
      ).then((value) => value ?? false);
}

/// Ask for a list name. Null when cancelled.
Future<String?> promptForName(
  BuildContext context, {
  required String title,
  String initial = '',
}) {
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'Name',
          hintText: 'Patience',
        ),
        onSubmitted: (value) => Navigator.pop(context, value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text),
          child: const Text('Save'),
        ),
      ],
    ),
  ).whenComplete(controller.dispose);
}
