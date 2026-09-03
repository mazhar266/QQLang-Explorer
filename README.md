# QQL Explorer

A desktop front end for [QQ Lang](https://github.com/mazhar266/QQ-Lang): type a
query, press Search, read the records it resolves to.

## The QQL runtime

The app ships QQL with it. `third_party/qql` holds the shared library and the
JSON data the resolvers read, taken from a
[QQ Lang release](https://github.com/mazhar266/QQ-Lang/releases) — no QQ Lang
checkout, no cargo, no build step.

The payload is about 129 MB, so it is **not committed**; `VERSION` and
`LICENSE.md` are, which is what records the release the repo expects. Fetch
the rest:

```bash
tool/fetch-qql.sh                     # the version in third_party/qql/VERSION
tool/fetch-qql.sh 3.2.0               # a specific release
tool/fetch-qql.sh 3.2.0 aarch64-macos # a specific platform
```

It takes the shared library and `sources/` only — not the 51 MB static
library, which is for linking on iOS, nor the CLI binaries, which this app
never runs.

Releases are built with `vector` and `fulltext` on, so the ranked forms
`*"…"` and `?"…"` work. A library built without them refuses those with
`QQL_UNSUPPORTED` rather than quietly matching something else.

### Where it is looked for

1. `$QQL_HOME` — an unpacked release bundle, to try another build in place
2. `qql/` beside the executable — where a built app carries it
3. `third_party/qql` — the checkout, for `flutter run` and the tests

`flutter build linux` installs the runtime into the bundle, so the built app
runs from anywhere rather than only from a checkout.

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
assumed, so `2:255` is the same query.

Before anything has been run, the window lists the eighteen collections with
their code, what their first index means, and the range it runs over; picking
one starts a query with that code. The `?` button adds the syntax to that.
The full grammar is in the QQ Lang README.

The table is transcribed in [lib/sources.dart](lib/sources.dart) from the
[Sources wiki page](https://github.com/mazhar266/QQ-Lang/wiki/Sources), and
its ranges were checked against the data.

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

## About

The ⓘ button in the title bar shows the version, the QQL engine version, and
who made it.

The QQL version shown there is what the bundled library reports for itself
through `qql_version()`.

## Icon

The mark is the Rub el Hizb, the eight-pointed star used in the mushaf itself
to mark divisions of the text. [tool/make_icon.py](tool/make_icon.py) draws it
and writes every platform's files; run it after changing anything there:

```bash
python3 tool/make_icon.py    # needs Pillow
```

The Linux runner loads the icon out of the Flutter bundle at startup. That
reaches the switcher and the dock on X11 only — GTK3 has no window-icon
protocol on Wayland, where GNOME matches a window to a desktop entry by
application id instead. For the icon there, install a user-level entry:

```bash
flutter build linux
tool/install-desktop-entry.sh              # --debug for the debug build
tool/install-desktop-entry.sh --remove     # takes it all back
```

It writes only under `~/.local/share`, and prints every file it created.

## Layout

| | |
| --- | --- |
| [lib/main.dart](lib/main.dart) | The window: query bar, examples, results, error and empty states |
| [lib/result_card.dart](lib/result_card.dart) | One record. Records have no fixed shape, so known fields are laid out and the rest becomes chips |
| [lib/qql_client.dart](lib/qql_client.dart) | Finds the checkout, holds one context, times each query |
| [lib/qql_binding.dart](lib/qql_binding.dart) | Vendored copy of the upstream Dart FFI binding — see the header before editing |
| [lib/sources.dart](lib/sources.dart) | The collection table, and the home screen built from it |
| [lib/help_sheet.dart](lib/help_sheet.dart) | The syntax and source reference drawer |
| [lib/about.dart](lib/about.dart) | The About dialog, and the app version |
| [lib/saved_lists.dart](lib/saved_lists.dart) | Lists, their items, and the JSON file behind them |
| [lib/lists_ui.dart](lib/lists_ui.dart) | The lists drawer and the bookmark on a result |
| [third_party/qql/](third_party/qql/) | The vendored QQL library and data |
| [tool/fetch-qql.sh](tool/fetch-qql.sh) | Fetches that runtime from a release |
| [tool/make_icon.py](tool/make_icon.py) | Draws the icon for every platform |
| [tool/install-desktop-entry.sh](tool/install-desktop-entry.sh) | User-level desktop entry, for the icon on Wayland |
