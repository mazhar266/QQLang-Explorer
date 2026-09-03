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

## Layout

| | |
| --- | --- |
| [lib/main.dart](lib/main.dart) | The window: query bar, examples, results, error and empty states |
| [lib/result_card.dart](lib/result_card.dart) | One record. Records have no fixed shape, so known fields are laid out and the rest becomes chips |
| [lib/qql_client.dart](lib/qql_client.dart) | Finds the checkout, holds one context, times each query |
| [lib/qql_binding.dart](lib/qql_binding.dart) | Vendored copy of the upstream Dart FFI binding — see the header before editing |
| [lib/help_sheet.dart](lib/help_sheet.dart) | The syntax and source reference drawer |
