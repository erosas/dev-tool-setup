# MX Creative Console keypad profiles

Exported profiles for the Logitech MX Creative Console keypad, managed through
[Logi Options+](https://www.logitech.com/software/logi-options-plus.html). Each `.lp5` file is
a profile for one app and lights up automatically when that app is in the foreground.

## Profiles

| File | App | What's on the keys |
| --- | --- | --- |
| `intellij.lp5` | IntelliJ IDEA | Page 1: prev/next/close tab, navigate back/forward, recent files, find / find next / find previous. Page 2: run, debug, build, toggle breakpoint, step into/out/over, line and block comment. |
| `github-copilot.lp5` | GitHub Copilot app | Folders for new session, customize, pinned, chats, and projects. |
| `microsoft-teams.lp5` | Microsoft Teams | Toggle mute, toggle video, raise hand, share screen, live captions, open chat, accept video call, decline call, leave meeting. |
| `powerpoint.lp5` | PowerPoint for Mac | Page 1: new slide, next/previous slide, start/end slide show, save. Page 2: create new, insert link, format object panel. |
| `word.lp5` | Word | New/open/print document, cut/copy/paste, select all, find text, check spelling. |

## Install on a new machine

1. Install Logi Options+ and plug in the MX Creative Console. If the Mac can't reach
   Logitech's servers (Zscaler), install the plugins from [`../plugins`](../plugins/README.md)
   first with `../sync-plugins.sh install`.
2. Open Logi Options+, select the **MX Creative Console** keypad.
3. Pick the app you want (or add it with **+** if it isn't listed).
4. Open the profile menu (**⋯** next to the profile name) and choose **Import**.
5. Select the matching `.lp5` file from this folder.
6. Repeat for each app.

## Export after making changes

In Logi Options+, open the same profile menu and choose **Export**. Save the file over the
matching one in this folder and commit the change.

## Notes

- `.lp5` files are zip archives containing the profile JSON, an app icon, and metadata.
  They're treated as binary in git.
- Exports were made from Logi Options+ on macOS. Windows profiles should import as well,
  but shortcuts that target macOS-specific keys may need adjusting.
