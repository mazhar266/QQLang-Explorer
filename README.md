# QQL Explorer

A desktop front end for [QQ Lang](https://github.com/mazhar266/QQ-Lang): type a
query, press Search, read the records it resolves to.

## The QQL runtime

The app ships QQL with it — no QQ Lang checkout, no cargo, at least not to
run it. The pieces live under `third_party/qql`:

| | From | |
| --- | --- | --- |
| `lib/` | a [release](https://github.com/mazhar266/QQ-Lang/releases) | the desktop shared library |
| `android/<abi>/` | built from source | the same library per Android ABI |
| `sources/` | a release | 123 MB of JSON, indexes and vectors |
| `VERSION`, `LICENSE.md` | | the release this repo expects, and its licence |

The payload is about 140 MB, so it is **not committed** — `VERSION` and
`LICENSE.md` are, which is what records the release. Fetch and build it:

```bash
tool/fetch-qql.sh                     # desktop library + data, from a release
tool/build-qql-android.sh             # the Android libraries, from source
python3 tool/gen-asset-list.py        # only after changing releases
```

`fetch-qql.sh` takes a version and platform (`tool/fetch-qql.sh 3.2.0
aarch64-macos`) and defaults to the version in `VERSION` and the platform of
the machine. Releases are built with `vector` and `fulltext` on, so the ranked
`*"…"` and `?"…"` forms work.

Android needs building rather than fetching, because releases ship desktop
builds only. It needs the NDK, `cargo-ndk`, and the Rust Android targets; the
script's header lists the two commands that install them.

### How each platform finds it

The data ships as Flutter assets, which behave differently per platform, and
that difference is the whole design:

| | Library | Data |
| --- | --- | --- |
| Desktop | `qql/lib/` beside the executable, installed by CMake | read **in place** from `flutter_assets`, since there they are real files |
| Android | `lib/<abi>/libqql.so` in the APK, opened by name | unpacked once from the APK into app storage, since there they are not |

Nothing is stored twice: the desktop bundle carries one copy of the data, and
the resolvers read it where it lies. `$QQL_HOME` overrides both, pointing at
an unpacked release bundle.

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

Android gets a full set: the legacy PNG for old launchers, an adaptive icon
whose background and mark are separate layers for the launcher to mask and
shift, and a monochrome layer for Android 13's themed icons. The mark is drawn
smaller in the adaptive layers than in the legacy tile, sized to sit inside the
66 dp that every mask keeps.

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
| [lib/qql_install.dart](lib/qql_install.dart) | Finding the library and the data, and unpacking on Android |
| [tool/fetch-qql.sh](tool/fetch-qql.sh) | Fetches the desktop runtime from a release |
| [tool/build-qql-android.sh](tool/build-qql-android.sh) | Cross-compiles the library per Android ABI |
| [tool/gen-asset-list.py](tool/gen-asset-list.py) | Regenerates the data asset list in pubspec |
| [tool/make_icon.py](tool/make_icon.py) | Draws the icon for every platform |
| [tool/install-desktop-entry.sh](tool/install-desktop-entry.sh) | User-level desktop entry, for the icon on Wayland |
