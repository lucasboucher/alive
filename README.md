# Alive

A macOS menu bar app that shows your Internet connection status.

- 🟢 Connected to the Internet
- 🟠 Connected to a network, but no Internet access
- 🔴 No network

## Requirements

- macOS 14.0 or later

## Installation

1. Open `Alive.xcodeproj` in Xcode.
2. Run the app with **Cmd+R**.
3. To keep it, copy `Alive.app` to `/Applications`, then enable **Open at Login** from the menu.

## Usage

The menu shows the current status, the launch-at-login option, and **Quit** (Cmd+Q).

If you remove the menu bar icon, Alive keeps running in the background. To quit it, use Activity Monitor or run `killall Alive` in Terminal.

## Tests

Run the tests with **Cmd+U** in Xcode.

## License

MIT. See [LICENSE](LICENSE).
