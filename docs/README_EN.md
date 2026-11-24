<div align="center">

# HumanTyper

**A Windows auto-typing utility that types just like a real human**

Natural pacing · Occasional typos & corrections · Word & sentence pauses · Chinese & English support

[![Build & Release](https://github.com/ydnw6/HumanTyper/actions/workflows/build.yml/badge.svg)](https://github.com/ydnw6/HumanTyper/actions/workflows/build.yml)
[![Latest release](https://img.shields.io/github/v/release/ydnw6/HumanTyper?label=Latest%20Release)](https://github.com/ydnw6/HumanTyper/releases/latest)
[![Downloads](https://img.shields.io/github/downloads/ydnw6/HumanTyper/total?label=Downloads)](https://github.com/ydnw6/HumanTyper/releases)
[![License: MIT](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
![Platform](https://img.shields.io/badge/platform-Windows%2010%20%7C%2011-0078D6)

[**⬇ Download Latest**](https://github.com/ydnw6/HumanTyper/releases/latest) · [Quick Start](#quick-start) · [Parameters](#parameters) · [FAQ](#faq) · [中文](README.md) · [English]

<img src="docs/screenshot.png" alt="HumanTyper Main Interface" width="760">

</div>


> [!IMPORTANT]
> **This software is permanently free.** If you paid for it, someone is reselling this free tool without authorization—please request a refund and report the seller.

---

## Why HumanTyper?

Standard auto-typers either paste everything at once or output characters at a robotic, uniform speed—making it immediately obvious that a script is typing.
HumanTyper types your text into any input field **with human rhythm**: fluctuating speeds, accidental slips followed by backspacing, natural pauses to "think" mid-sentence, and IME-style word-by-word commits for Chinese. Once finished, it **proofreads the output from start to finish**, moving the cursor with arrow keys to fix any discrepancies.

> **This software is permanently free and open-source—there are no paid editions, subscriptions, or activation keys.** If you paid for it, immediately request a refund on the platform where you bought it and report the seller. Feedback & Issues: [GitHub Issues](https://github.com/ydnw6/HumanTyper/issues) or QQ `959649446`.

## Features

| | |
| --- | --- |
| ⌨️ **Human-Like Rhythm** | Randomized speed fluctuations—faster on common letter combinations (digraphs), slower on uppercase letters and symbols, giving an organic typing feel |
| ✏️ **Simulated Typos** | **English:** hits adjacent keys, transposes letters, double-taps, or skips keys. **Chinese:** picks wrong IME candidates. May type a few more characters before noticing and backspacing to fix |
| 💭 **Thinking Pauses** | Brief pauses every few words, longer pauses every few sentences, and extended pauses between paragraphs—both frequency and duration are customizable |
| 🀄 **Mixed Chinese & English** | Commits Chinese in 1–4 character words (typing Pinyin first, then selecting the word); measures English in WPM; full emoji support |
| ⏸️ **Hotkeys & Buttons** | Start / Pause / Resume / Stop / Restart via UI buttons or customizable global hotkeys |
| 🖥️ **Remote Desktop Ready** | Scan code & kernel-level virtual keyboard modes emit hardware-identical keystrokes—works inside ToDesk, Sunlogin, RDP, VNC, and VMs, including Pinyin-to-Chinese input |
| 🖱️ **Auto-Pause & Resume** | Automatically pauses if you switch windows or move the cursor, and resumes once you return to the original spot |
| 🔍 **Post-Typing Proofread** | Reads back the actual text in the target box, diffs it character-by-character, and fixes errors using arrow keys + Backspace without touching pre-existing text |
| 📊 **Real-Time Progress** | Completed text turns green and active characters highlight in the main box; an always-on-top HUD overlay displays progress, percentage, ETA, and current character; taskbar button also shows progress |
| 📦 **Portable Single-File** | A ~200 KB standalone `.exe` (with built-in Pinyin dictionary), zero installation required, runs natively on Windows 10/11 |

## Quick Start

1. Download `HumanTyper.exe` from [Releases](https://github.com/ydnw6/HumanTyper/releases/latest) and double-click to run.
2. Paste your text into the upper text box (or click **"Open File..."**, supporting UTF-8 / GBK).
3. Start typing using either method:
   - Click **Start**, then click inside the target input box within the countdown (default: 3 seconds);
   - Or place your cursor in the target input box first and press **`F8`** to begin immediately.
4. Sit back and watch it type. To take over mid-way, press `F8` to pause or simply move your mouse—it will pause automatically.

### Hotkeys

| Action | Default Hotkey | Description |
| --- | :---: | --- |
| Start / Pause / Resume | `F8` | **When idle:** starts immediately at current cursor; **When running:** pauses; **When paused:** resumes at the **current** cursor position |
| Stop | `F9` | Stops typing (also cancels the countdown) |
| Restart | `F10` | Stops the current task and starts over from the beginning |

Hotkeys are global and work across any active application. Click the hotkey box under the "Control" section and press a new key combination (e.g., `Ctrl+Shift+P`) to rebind, or press `Del` to clear.

### Auto-Pause & Resume

When **"Auto-pause when cursor leaves original position/window"** is checked (enabled by default):

- **Switching to another window** → Pauses; automatically resumes when you switch back.
- **Clicking the mouse or pressing arrow keys in the target window** → Pauses; automatically resumes once you return the cursor to its original position.
- Some applications do not expose caret coordinates (e.g., remote machines inside a remote-desktop window, or when your PC is being controlled via ToDesk / Sunlogin). In these cases, move the cursor back manually and press `F8` to resume.
- When your PC is being remotely controlled, clicks and keystrokes sent from the host side also count as "manual input" and will trigger a pause.
- When focus is inside remote-control windows like ToDesk or Sunlogin, those apps intercept keystrokes and forward them to the remote PC. HumanTyper reads input directly at the device layer via **Raw Input**, so `F8` / `F9` / `F10` remain responsive (though those keys may also be forwarded to the remote PC).

### Real-Time Progress

You can track typing progress in three places:

- **Floating HUD Overlay** (enabled by default; can be disabled in settings): A compact, always-on-top window showing current status (*Typing / Paused / Proofreading / Done*), a large percentage readout, a progress bar, a teleprompter-style line highlighting the **active character** in the center (typed text on the left, upcoming text on the right), plus character count, speed, and remaining time at the bottom. It never steals focus, can be dragged anywhere (position is saved), and clicking `×` closes it for the current session. The overlay is excluded from screen capture so it never interferes with OCR proofreading.
<img src="docs/progress-overlay.png" width="560" alt="Progress Overlay">

- **Main Window Text Box**: Typed text is highlighted in green, the active character in yellow, and the view auto-scrolls to follow along. The box becomes read-only during typing, and color highlights clear once finished.
- **Taskbar Button**: Displays a green progress bar (turns yellow when paused), while the window title prefixes the completion percentage.

### Post-Typing Proofreading

When **"Proofread from start after finishing"** is checked (enabled by default), HumanTyper pauses briefly after typing to "read over" its work:

1. Reads the actual text inside the target input box via Windows UI Automation and diffs it against your source text;
2. If any missing, extra, or mistyped characters are detected, it moves the cursor there using `←` `→`, deletes the mistake with `Backspace`, and retypes the correct text;
3. Returns to the end and performs a final verification pass, displaying `"Fixed N issue(s)"` in the status bar.

Only the newly typed segment is modified—pre-existing text in the input box remains untouched. If the discrepancy is too large (e.g., the cursor was accidentally moved elsewhere), proofreading aborts to prevent unintended edits.
In Keyboard Mode, homophone substitutions made by the IME (e.g., `"长得"` vs. `"长的"`) are intentionally ignored; only missing/extra characters and non-Chinese text are corrected.

For applications that do not expose text via UI Automation (such as custom-drawn UIs or remote-desktop windows), HumanTyper falls back to two alternative methods in order (both can be disabled in settings):

- **Clipboard Copy**: Presses `Ctrl+Shift+Home` to select text before the cursor, copies it via `Ctrl+C` for comparison, and presses `→` to deselect and return to the end. Your previous clipboard contents are backed up and restored afterward. Remote windows require clipboard sync to be enabled in your remote-desktop client. This method is skipped in console/terminal windows (where `Ctrl+C` sends an interrupt signal).
- **Screen OCR**: Captures the target window and runs Windows built-in OCR twice at different scaling factors. An error is fixed **only if both passes agree on the exact same mistyped word**, and earlier regions are left untouched if uncertain discrepancies exist closer to the cursor (to avoid offset miscalculations). For multi-page content, it moves the mouse over the input box and scrolls up in overlapping half-page increments until reaching the top, then scrolls back and restores the mouse position. Multi-pass OCR runs concurrently for small images and sequentially for large ones to keep memory usage low. Checks English only; visually ambiguous characters (`0/o`, `1/l/I`, `rn/m`), casing, and punctuation are ignored. Designed to err on the side of caution—never making false edits.

### Using with Remote Desktop / Remote Control Software

Clients like ToDesk, Sunlogin, Windows RDP, VNC, and Virtual Machines forward **hardware keystrokes** rather than direct Unicode character injections. Switch **"Input Mode"** to a keyboard mode when typing into them:

| Input Mode | Mechanism | Best For |
| --- | --- | --- |
| Standard (Default) | Sends direct Unicode character events; Chinese commits directly | Local Windows applications |
| Keyboard Scan Code | Emits hardware-identical scan codes (key down/up & Shift combos) | ToDesk, Sunlogin, RDP, VMs, etc. (no driver needed) |
| Driver-Level Virtual Keyboard | Emits keystrokes at the driver layer via the [Interception](https://github.com/oblitum/Interception) driver, indistinguishable from a physical keyboard | Rare apps that block software-injected keys; requires driver installation |

**Typing Chinese in Keyboard Mode**: Physical keystrokes only produce Latin letters, so Chinese characters must be generated by the **IME on the target machine**. HumanTyper converts Chinese text into Pinyin (using a built-in dictionary of 26,000+ characters and multi-pronunciation phrases, e.g., `"银行 → yinhang"`), types each word's Pinyin, and presses `Space` to pick the first candidate. It automatically presses `Shift` (or `Ctrl+Space`) to toggle between Chinese and English modes, and types Chinese punctuation (`，。？！：“”……——`) using corresponding keys while in Chinese mode. Before starting:

1. Switch the target machine to a Chinese IME (e.g., Microsoft Pinyin, Sogou);
2. Set **"Target IME Initial State"** to match whether the remote IME is currently in **Chinese Mode** or **English Mode**;
3. If your IME uses `Ctrl+Space` to toggle languages, update **"CN/EN Toggle Key"** accordingly.

Occasional homophone selections by the target IME are normal.

**Installing Driver-Level Mode** (Optional): Select **"Driver-Level Virtual Keyboard"** under Input Mode, click **"One-Click Install Driver"** next to it, approve the Windows UAC prompt, and reboot your PC when prompted.

- HumanTyper downloads the installer directly from the [official Interception Release](https://github.com/oblitum/Interception/releases/tag/v1.0.1) and verifies its SHA-256 hash before installing. Files are stored in `%LOCALAPPDATA%\HumanTyper\Interception`.
- To remove it later: click **"Uninstall Driver"** in the same spot, approve UAC, and reboot.
- Interception is free for non-commercial use only; HumanTyper does not bundle the driver binary.

## Parameters

| Group | Parameter | Default | Description |
| --- | --- | :---: | --- |
| Speed | English Speed | 55 WPM | Words per minute (1 word = 5 characters) |
| | Chinese Speed | 80 CPM | Characters per minute (includes Pinyin typing + candidate selection time) |
| | Rhythm Variance | 30 % | Higher values create more uneven pacing; `0` = constant speed |
| Typos | Typo Rate | 3 % | Probability of mistyping each character; `0` = zero typos |
| | Error Detection Delay | Up to 3 extra chars | How many extra characters may be typed before noticing and backspacing |
| Pauses | Word Pause | 0.4–1.8s every 4–12 words | Brief mid-sentence hesitation |
| | Sentence Pause | 1.5–5s every 1–3 sentences | Thinking before the next sentence |
| | Paragraph Pause | 2.5–7s per paragraph | Gathering thoughts between paragraphs |
| | Punctuation Pause | On | Slight pause after commas, semicolons, and enumeration commas |
| Control | Countdown | 3 seconds | Time given to switch to the target window after clicking Start |
| | Line Break Key | Enter | Set to `Shift+Enter` for chat apps where `Enter` sends the message |
| | Minimize on Start / Always on Top | Off | Window behavior preferences |
| | Input Mode | Standard | Use **Keyboard Scan Code** or **Driver-Level** for remote windows |
| | Target IME Initial State | Chinese Mode | Keyboard Mode only; tracks whether remote IME starts in CN or EN |
| | CN/EN Toggle Key | Shift | Keyboard Mode only; can also be set to `Ctrl+Space` |

All settings are automatically saved to `%APPDATA%\HumanTyper\settings.ini`. The UI also displays real-time character count and estimated completion time.

## FAQ

<details>
<summary><b>Will having a Chinese IME active mess up the output?</b></summary>

Not in **Standard Mode**: text is injected via Unicode keyboard events, bypassing the IME completely. **Keyboard Mode**, by contrast, relies on the IME to type Chinese—just make sure to configure the IME state properly as described in the [Remote Desktop](#using-with-remote-desktop--remote-control-software) section.
</details>

<details>
<summary><b>Why isn't it typing anything inside ToDesk / Sunlogin / Remote Desktop?</b></summary>

Switch **"Input Mode"** to **"Keyboard Scan Code"**. If Chinese text comes out as raw Pinyin letters, the target computer is either not using a Chinese IME or is currently in English mode—switch it on the remote PC and match **"Target IME Initial State"**. If it still doesn't register, try **"Driver-Level Virtual Keyboard"**.
</details>

<details>
<summary><b>Why doesn't it type into a specific local program?</b></summary>

If the target application is running as Administrator, Windows UIPI blocks standard-privilege processes from sending keystrokes to it. Right-click `HumanTyper.exe` and select **"Run as administrator"**.
</details>

<details>
<summary><b>Why are extra indentations or closing brackets appearing in code editors?</b></summary>

This is caused by your editor's auto-indent and auto-closing bracket features (which trigger just as they would for a human typist). Temporarily disable auto-closing/auto-indent in your editor, or keep **"Proofread from start after finishing"** enabled to automatically clean up the extra characters.
</details>

<details>
<summary><b>What does "Cannot read text from target app, copy, or OCR—skipping proofread" mean?</b></summary>

Proofreading tries Windows UI Automation first, then clipboard copy, and finally screen OCR. Only when all three fail (e.g., copying is disabled, text is too small, or the typed English snippet cannot be located on screen) will it skip proofreading without affecting the typed text. For remote windows, enabling clipboard sync in your remote-desktop client is recommended.
</details>

<details>
<summary><b>Why doesn't it auto-resume after pausing?</b></summary>

When caret coordinates are readable, auto-resume requires the cursor to return to its **exact pre-pause position**. When coordinates are unavailable (such as in remote windows), press `F8` to resume. If you want to resume at a new cursor position, simply press `F8`.
</details>

<details>
<summary><b>Why does my antivirus flag the executable?</b></summary>

Because HumanTyper simulates keyboard input and installs low-level global keyboard/mouse hooks (to detect manual user takeover), some antivirus heuristics may trigger false positives. The source code is completely open—you can inspect and compile it yourself below.
</details>

## Building from Source

Requires [.NET SDK](https://dotnet.microsoft.com/download) (6.0 or newer to build; targets Windows built-in .NET Framework 4.8 at runtime).

```bash
git clone [https://github.com/ydnw6/HumanTyper.git](https://github.com/ydnw6/HumanTyper.git)
cd HumanTyper
dotnet build HumanTyper.csproj -c Release -o out