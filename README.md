
<p align="center">
  <img src="docs/assets/app-icon.png" alt="Droppy Icon" width="120">
</p>

<h1 align="center">Droppy</h1>

<p align="center">
  <strong>The native productivity layer macOS is missing.</strong><br>
  <em>Free, open-source, and built entirely in Swift.</em>
</p>

<p align="center">
    <a href="https://github.com/iordv/Droppy/releases/latest"><img src="https://img.shields.io/github/v/release/iordv/Droppy?style=flat-square&color=007AFF" alt="Latest Release"></a>
    <img src="https://img.shields.io/badge/macOS_14+-000?style=flat-square" alt="Platform">
    <a href="LICENSE"><img src="https://img.shields.io/badge/license-GPL--3.0-blue?style=flat-square" alt="License"></a>
</p>

---

<p align="center">
  <img src="https://i.postimg.cc/1tpKj1Wf/Droppy-demo-v2.gif" alt="Droppy Demo" width="100%">
</p>

<p align="center">
  <a href="https://iordv.github.io/Droppy/"><strong>🌐 Website</strong></a> · 
  <a href="https://github.com/iordv/Droppy/releases/latest"><strong>⬇️ Download</strong></a> · 
  <a href="https://iordv.github.io/Droppy/extensions.html"><strong>🧩 Extensions</strong></a>
</p>

---

## What is Droppy?

Stop juggling single-purpose utilities. Droppy brings your **clipboard history**, **file shelf**, **screenshot tools**, and **system HUDs** together in one native interface—all living inside your notch.

**No notch?** Droppy adds a Dynamic Island-style pill to any Mac.

---

## ✨ Clipboard Manager

Full history with search, favorites, OCR text extraction, and drag-out support.

<p align="center">
  <img src="docs/assets/images/clipboard-manager.png" alt="Clipboard Manager" width="70%">
</p>

---

## 🎵 Media Controls

Album art, playback controls, and a seek slider—right in your notch.

<p align="center">
  <img src="docs/assets/images/media-hud.png" alt="Media Controls" width="70%">
</p>

---

## 🎤 Voice Transcribe

Record and transcribe speech to text with 100% on-device AI. Your voice never leaves your Mac.

<p align="center">
  <img src="docs/assets/images/voice-transcribe-screenshot.png" alt="Voice Transcribe" width="70%">
</p>

---

## Everything Included

| Feature | Description |
|:---|:---|
| **File Shelf & Basket** | Drag files to the notch. Jiggle your mouse to summon a floating basket. |
| **Clipboard Manager** | Full history, search, favorites, OCR, drag-out |
| **Native HUDs** | Volume, brightness, battery, caps lock, unlock |
| **Media Controls** | Album art, seek slider, playback controls |
| **Window Snapping** | Snap to edges/corners with keyboard shortcuts |
| **Quick Actions** | Right-click to compress, convert, extract text, share |
| **Multi-Monitor** | Works on external displays with smart fullscreen detection |
| **Transparency Mode** | Optional glass effect for all windows |

---

## 🧩 Extensions

Droppy's built-in Extension Store adds powerful features on demand. Everything's free.

<p align="center">
  <img src="docs/assets/images/extension-store-new.png" alt="Extension Store" width="80%">
</p>

**Featured:**

| | |
|:---|:---|
| <img src="https://iordv.github.io/Droppy/assets/icons/voice-transcribe.jpg" height="24"> **Voice Transcribe** | On-device speech-to-text using WhisperKit AI |
| <img src="https://iordv.github.io/Droppy/assets/icons/ai-bg.jpg" height="24"> **AI Background Removal** | Remove backgrounds locally using ML |
| <img src="https://iordv.github.io/Droppy/assets/icons/video-target-size.png" height="24"> **Video Target Size** | Compress videos to exact file sizes with FFmpeg |
| <img src="https://iordv.github.io/Droppy/assets/icons/window-snap.jpg" height="24"> **Window Snap** | Snap windows with keyboard shortcuts |
| <img src="https://iordv.github.io/Droppy/assets/icons/spotify.png" height="24"> **Spotify Integration** | Control Spotify playback from your notch |
| <img src="https://iordv.github.io/Droppy/assets/icons/element-capture.jpg" height="24"> **Element Capture** | Screenshot any UI element |
| <img src="https://iordv.github.io/Droppy/assets/icons/alfred.png" height="24"> **Alfred Workflow** | Add files to Droppy from Alfred |
| <img src="https://iordv.github.io/Droppy/assets/icons/finder.png" height="24"> **Finder Services** | Right-click in Finder to send files to Droppy |

<p align="center">
  <a href="https://iordv.github.io/Droppy/extensions.html">
    <img src="https://img.shields.io/badge/Browse_All_Extensions-blueviolet?style=for-the-badge" alt="Extension Store">
  </a>
</p>

---

## Install

### Homebrew (recommended)
```bash
brew install --cask iordv/tap/droppy
```

### Manual Download
1. Download [**Droppy.dmg**](https://github.com/iordv/Droppy/releases/latest)
2. Clear quarantine: `xattr -rd com.apple.quarantine ~/Downloads/Droppy-*.dmg`
3. Drag Droppy to Applications

---

## Keyboard Shortcuts

| Action | Shortcut |
|:---|:---|
| Open Clipboard | `⌘ + Shift + Space` |
| Navigate items | `↑` / `↓` |
| Paste selected | `Enter` |
| Close | `Escape` |

**Window Snapping** (with extension):

| Action | Shortcut |
|:---|:---|
| Snap left/right | `⌃ + ⌥ + ←/→` |
| Snap top/bottom | `⌃ + ⌥ + ↑/↓` |
| Maximize | `⌃ + ⌥ + Enter` |

---

## Requirements

- **macOS** 14.0 (Sonoma) or later
- **Architecture**: Apple Silicon (M1–M4) and Intel
- **Permissions**: Accessibility (required), Screen Recording (optional)

---

## FAQ

<details>
<summary><strong>Is Droppy really free?</strong></summary>
Yes! Free forever with no ads, subscriptions, or paywalls.
</details>

<details>
<summary><strong>Does it work on Macs without a notch?</strong></summary>
Absolutely. Droppy displays a Dynamic Island-style pill at the top of your screen.
</details>

<details>
<summary><strong>Is my data private?</strong></summary>
100%. All processing happens locally—clipboard history, voice transcription, and background removal never leave your Mac.
</details>

---

## Build from Source

```bash
git clone https://github.com/iordv/Droppy.git
cd Droppy && open Droppy.xcodeproj
# Build with ⌘ + R
```

---

## Support

<p align="center">
  <strong>Free forever — no ads, no subscriptions.</strong><br>
  If Droppy saves you time, consider buying me a coffee.
</p>

<p align="center">
  <a href="https://buymeacoffee.com/droppy">
    <img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" alt="Buy Me A Coffee" width="160">
  </a>
</p>

---

<p align="center">
  <strong><a href="LICENSE">GPL-3.0 + Commons Clause</a></strong> — Source available, not for resale.<br>
  <a href="TRADEMARK">Droppy™</a> by <a href="https://github.com/iordv">Jordy Spruit</a>
</p>
