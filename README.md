# QQL Explorer

A desktop front end for [QQ Lang](https://github.com/mazhar266/QQ-Lang): type a
query, press Search, read the records it resolves to.

## Prerequisites

The app carries no data of its own. It loads the QQL native library and reads
the JSON sources from a QQ Lang checkout:

```bash
cd ~/Projects/QQ\ Lang
cargo build --release --features vector,fulltext
```

The `vector` and `fulltext` features are optional. Without them the app still
works; the ranked forms `*"…"` and `?"…"` are refused with `QQL_UNSUPPORTED`
rather than quietly matching something else.

`~/Projects/QQ Lang` is assumed. Set `QQL_HOME` to point elsewhere:

```bash
QQL_HOME=/path/to/QQ-Lang flutter run -d linux
```

## Run

```bash
flutter run -d linux
```

The built binary takes an optional query to run at startup:

```bash
./build/linux/x64/debug/bundle/qqlang_explorer 'Q:2:255'
```

## Queries

`Q:2:255` is Surah 2 ayah 255. The source is optional and the Quran is
assumed, so `2:255` is the same query. The in-app reference — the `?` button —
lists the syntax and every source code. The full grammar is in the QQ Lang
README.

## Lists

Any result can be saved to a named list with the bookmark on its card, and a
record can sit in as many lists as you like. The bookmarks button in the title
bar opens them; opening one replaces the results until you go back, and
searching also goes back.

Each saved record keeps the query that found it, which months later is often
the thing worth remembering about it.

Lists live in one JSON file:

| Platform | |
| --- | --- |
| Linux | `$XDG_DATA_HOME/qqlang_explorer/lists.json`, else `~/.local/share/…` |
| macOS | `~/Library/Application Support/qqlang_explorer/lists.json` |
| Windows | `%APPDATA%\qqlang_explorer\lists.json` |

It is written whole on each change, through a temporary file and a rename, so
an interrupted write cannot truncate it. A file that will not parse is moved
aside rather than overwritten.

## Layout

| | |
| --- | --- |
| [lib/main.dart](lib/main.dart) | The window: query bar, examples, results, error and empty states |
| [lib/result_card.dart](lib/result_card.dart) | One record. Records have no fixed shape, so known fields are laid out and the rest becomes chips |
| [lib/qql_client.dart](lib/qql_client.dart) | Finds the checkout, holds one context, times each query |
| [lib/qql_binding.dart](lib/qql_binding.dart) | Vendored copy of the upstream Dart FFI binding — see the header before editing |
| [lib/help_sheet.dart](lib/help_sheet.dart) | The syntax and source reference drawer |
| [lib/saved_lists.dart](lib/saved_lists.dart) | Lists, their items, and the JSON file behind them |
| [lib/lists_ui.dart](lib/lists_ui.dart) | The lists drawer and the bookmark on a result |
