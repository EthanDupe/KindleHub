# KHub v2.4 for Kindle

KHub (`xyz.ethandupe.khub`) is a lightweight, offline-first app launcher, online app store, productivity suite, RSS Feed reader, and plugin manager designed specifically for jailbroken Amazon Kindle e-readers running Mesquite.

## Features in v2.4

* **Classic App Launcher & Categories:** Clean, high-contrast E-Ink launcher layout organized into Games, Productivity, Misc, and Plugins.
* **Strictly Online App Store:** Live store catalog (`kindlestore.json`), smart update badges (`[⬇ UPDATE]`), 5-second watchdog timer, Offline vs. Server Error detection, and global maintenance switch via Cloudflare Worker (`https://khub-api.ethananaya351.workers.dev`).
* **Built-In & Store Apps:** Built-in Tic-Tac-Toe, Lemonade Stand, RSS Feed, and Kindle AI Chat, plus downloadable Quick Notes Pro v2.0, 2048 E-Ink, E-Ink Snake, AI Tap Adventure, Word Guess E-Ink, E-Ink Sudoku, AI Study Flashcards, and Pomodoro & Habits (zero apps preloaded by default).
* **High-Readability RSS Feed & Remote Phone/PC Entry:** Paginated multi-feed RSS reader with 5x zoom scaling, offline story caching, and **Add Feeds on Phone/PC** over port `8088`.
* **Cloudflare Telemetry & Admin Panel (`admin.html` & `worker.js`):** Expanded Kindle device heartbeats (`id`, `name`, `version`, `ip`, `currentScreen`, `installedAppsCount`, `installedAppsList`, `activePlugins`, `rssFeedsCount`, `loadingMode`, `textZoom`, `userAgent`, `uptime`, `lastSeen`) monitored in `admin.html`.
* **Reliable OTA System Updater:** In-app and shell-backed OTA updater that downloads the latest `index.html`, `config.xml`, and `khub.sh`, validates file contents, updates both `/mnt/us/documents/khub/` and `/var/local/mesquite/KHub/`, and reloads cleanly into the new version.

## Installation Guide

1. **Extract the Archive:** Extract the KHub v2.4 ZIP archive on your computer.
2. **Copy Core Files:** Copy the **`khub/`** folder (`index.html`, `config.xml`, `kindle_state.js`, `cover.png`, `icon.png`, and `apps/installed_apps.js`) into **`documents/khub/`** on your Kindle drive.
3. **Copy the Launcher:** Copy **`khub.sh`** directly into the root **`documents/`** folder on your Kindle drive (`/mnt/us/documents/khub.sh`).
4. **Eject & Launch:** Safely eject your Kindle and tap **KHub** from your Kindle Library (or restart your Kindle if launching for the first time).

## Phone/PC Remote Setup (Port 8088)

You can enter your **Gemini API Key** (Settings -> AI & API Key -> **Enter on Phone/PC**) or manage **Custom RSS Feed URLs** (Productivity -> RSS Feed -> Feeds -> **Add Feeds on Phone/PC**) from any phone or computer on the same Wi-Fi network by opening `http://<Kindle-IP>:8088`.
