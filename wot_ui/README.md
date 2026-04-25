# wot_ui — Web of Trust mock plugin for Logos Basecamp

A pure-QML UI plugin that mocks the Web of Trust idea from `ideas/wot.md`.
No backend, no signing, no Waku, no Codex — just local `ListModel` state
seeded with example ratings so the views are not empty on first load.

## Structure

```
wot_ui/
├── Main.qml          # UI entry point (referenced from metadata.json)
├── metadata.json     # plugin descriptor (type: ui_qml)
└── icons/
    └── wot.svg
```

## Run it in Basecamp

### Option A — drop into the user plugins directory (fastest)

Basecamp scans a user-writable plugins directory at startup:

- **Linux:** `~/.local/share/Logos/LogosBasecampDev/plugins/wot_ui/`
- **macOS:** `~/Library/Application Support/Logos/LogosBasecampDev/plugins/wot_ui/`

Copy this folder there and start Basecamp:

```bash
mkdir -p ~/.local/share/Logos/LogosBasecampDev/plugins
cp -r /home/peter/projects/logos-ideas/wot_ui \
      ~/.local/share/Logos/LogosBasecampDev/plugins/
```

Open Basecamp, go to **Modules → UI Apps**, click **Load** on `wot_ui`.
It opens as a new tab in the MDI area.

To isolate from your normal instance, start with a dedicated user dir:

```bash
./result/bin/LogosBasecamp --user-dir /tmp/basecamp-wot
# then put wot_ui/ into /tmp/basecamp-wot/plugins/
```

### Option B — bundle as `.lgx` and install via UI

```bash
cd /home/peter/projects/logos-ideas/wot_ui
nix bundle --bundler github:logos-co/nix-bundle-lgx .#lib
```

Then in Basecamp: **Modules → Install LGX Package** → pick the generated
`.lgx` file. The package manager copies it into the user plugins dir
and the tab appears.

(Option B requires a `flake.nix` exposing `lib` as a Nix output — see
the counter_qml repo for a reference flake. Option A is enough to iterate.)

## What the mock does

- **People** tab: list of all users appearing in the seeded ratings,
  with an aggregated score badge. Green `+3` = you rated them directly
  strong-endorse; `+1*` with asterisk = indirect path through a trusted
  peer; red `-3` = fraud warning.
- **Rate** tab: handle + 4-tier score buttons (`+3 / +1 / -1 / -3`) +
  context textarea. "Sign & save (mock)" appends to the local
  `ListModel` and refreshes the People list.
- **Trust Path** tab: enter a handle, get the direct rating if any,
  otherwise all 1-hop paths via users you rated `≥ +1`.

Nothing persists across restarts — this is a UI-only sketch so the
shape of the interaction can be tried out before the real backend
(Keycard signing + Waku gossip + Codex backup) exists.

## Sandbox note

Basecamp wraps every QML UI app in a deny-all network layer and a URL
interceptor that only allows access to the plugin's own directory. So
the mock cannot accidentally reach out anywhere — all state stays in
the `ListModel` for the lifetime of the tab.
