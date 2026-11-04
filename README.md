# 📚 KHub v2.8 — The Ultimate E-Ink App Launcher & OS Suite for Jailbroken Kindles

![Version](https://img.shields.io/badge/Version-2.8-black?style=for-the-badge)
![Platform](https://img.shields.io/badge/Platform-Kindle_Touch_%2F_Paperwhite_%2F_Oasis_%2F_Scribe-black?style=for-the-badge)
![Backend](https://img.shields.io/badge/Backend-Cloudflare_Workers_%2B_KV-black?style=for-the-badge)
![AI](https://img.shields.io/badge/AI-Gemini_3.1_Flash_Lite-black?style=for-the-badge)

**KHub (`xyz.ethandupe.khub`)** transforms any jailbroken touch-screen Amazon Kindle (Firmware 5.x+) into a distracted-free E-Ink smart hub, gaming console, AI assistant, RSS news reader, and StreetPass peer discovery device—engineered specifically for high-contrast E-Ink displays and WebKit/Mesquite compatibility.

---

## ✨ Core Features in KHub v2.8

### 🏠 Built-In Core Apps
* **🤖 AI Chat Assistant (Gemini 3.1 Flash Lite)** — Multi-conversation AI chat powered by `gemini-3.1-flash-lite` with saved chat history, customizable system instructions, and one-tap conversation management.
* **📰 RSS News Reader (1.5x Dynamic Typography)** — Distraction-free E-Ink news reader with customizable RSS feeds and automatic **1.5x typography scaling** relative to your Settings display zoom for effortless armchair reading.
* **⛅ Local Weather & 7-Day Forecast** — Real-time temperature, wind speed, weather conditions, and 7-day high/low forecast powered by Open-Meteo, plus automatic IP geolocation and manual coordinate support.
* **📡 Kindle StreetPass (P2P Encounter Network)** — Exchange custom E-Ink avatars, greetings, favorite books, and device models with other KHub users within a 60-minute active broadcast window—with zero location tracking.
* **🛒 Kindle App Store (On-Demand Apps & Plugins)** — Browse, install, launch, and uninstall games, utilities, and system plugins on demand. Includes automatic **15-second server availability checks** (`Auto-checking server every 15 seconds...`) and an embedded resilient catalog fallback so the store never fails to load.
* **📖 Help & User Manual** — Built-in offline documentation and troubleshooting reference directly on your Kindle.

---

### 🎮 Kindle App Store Catalog (21 On-Demand Games, Utilities & Plugins)

Nothing from the App Store is pre-installed by default (`installed_apps.js` starts completely clean), keeping your Kindle lightweight until you install what you want:

#### 🕹️ E-Ink Games (13 Titles)
1. **🧞 Akinator E-Ink (`khub-akinator`)** *(New in v2.8!)* — Classic E-Ink Genie mind-reader! Features a clean question counter (`Question 1`), live `Confidence: %` meter, centered bold questions, 2-column 3D shadow-bordered `YES` / `NO` / `DON'T KNOW` / `PROBABLY` / `PROBABLY NOT` buttons, and a dotted `BACK` button. Powered by `gemini-3.1-flash-lite` with an offline 15-character local decision-tree fallback.
2. **🚢 Battleship E-Ink (2P & AI) (`khub-battleship`)** *(New in v2.8!)* — Naval tactical grid combat with **1P vs Smart Hunt/Target AI** and **2-Player Pass & Play** modes, 5 classic ship classes (Carrier, Battleship, Cruiser, Submarine, Destroyer), interactive fleet placement, and dual Target/Fleet radar grids.
3. **🃏 Simplified UNO (2P & Bots) (`khub-uno`)** — Face-to-face Tabletop 2-Player mode (top & bottom split screen) or Solo vs 1–3 AI Bots with Wild color pickers, Action cards (`SKIP`, `+2`, `WILD +4`), and UNO callouts.
4. **♠️ Blackjack 21 (2P & Dealer) (`khub-blackjack`)** — Head-to-head Tabletop 2-Player mode (top & bottom controls) or 1P vs Casino Dealer with bankroll betting, Hit, Stand, and Double Down.
5. **🔤 Hangman E-Ink (`khub-hangman`)** — Classic word-guessing game with 1P AI/Categorized word lists (Literature, Tech, Animals, Science) and 2-Player Custom Secret Word entry + progressive E-Ink gallows drawing.
6. **🐍 Snake E-Ink v2.0 (`khub-snake`)** — High-contrast grid arcade snake with **Walls ON** or **Wrap-Around** modes, Normal/Fast speeds, 3x oversized D-Pad controls, and persistent high scores.
7. **⚪ Connect Four (1P & 2P) (`khub-connect4`)** — 7×6 column-drop strategy game with 2-Player Pass & Play and 1P vs Tactical AI.
8. **💣 Minesweeper E-Ink (`khub-minesweeper`)** — Classic 8×8 and 10×10 minefield sweeper with Quick-Flag toggle (`🔍 Dig` / `🚩 Flag`) and first-tap safety.
9. **🏁 Checkers (Draughts 1P & 2P) (`khub-checkers`)** — Full 8×8 Checkers with multi-jump capture rules, King promotion, 2P mode, and AI opponent.
10. **🔢 2048 E-Ink v2.0 (`khub-2048`)** — Sliding tile puzzle with Undo support, persistent board state, and 3x touch controls.
11. **🟩 Wordle Unlimited v2.0 (`khub-wordle`)** — 5-letter word puzzle with high-contrast E-Ink tile patterns, win-streak tracking, and full on-screen keyboard.
12. **🧩 Sudoku Generator v2.0 (`khub-sudoku`)** — Infinite 9×9 Sudoku puzzles across Easy, Medium, and Hard difficulties with candidate pencil marks (`✏️ Notes`) and Hints.
13. **🗡️ AI Text Dungeon RPG v2.0 (`khub-adventure`)** — Interactive choose-your-own-adventure RPG powered by `gemini-3.1-flash-lite` across Fantasy, Cyberpunk, Space Opera, and Victorian Mystery settings with HP, Gold, and Inventory tracking.

#### 🛠️ Utilities (3 Titles)
14. **📝 E-Ink Scratchpad & Notes v2.0 (`khub-notes`)** — Multi-note distraction-free writer with live word/character counts and persistent local storage.
15. **🗂️ Spaced Repetition Flashcards (`khub-flashcards`)** — Study deck manager with custom cards and Easy/Good/Again spaced repetition grading.
16. **⏱️ Pomodoro Focus Timer (`khub-pomodoro`)** — Big-digit E-Ink focus timer (25m Work / 5m Short Break / 15m Long Break / 50m Deep Work) with session tracking.

#### 🧩 System Plugins (5 Titles)
17. **🔍 All-Games Scale Booster (`plugin-game-scaler`)** — Injects a floating `🔍 Scale: 1x / 1.5x / 2x / 3x` bar into any launched store game to dynamically enlarge buttons, boards, and text.
18. **🚨 NOAA Emergency Weather Alert (`plugin-noaa-emergency`)** — Polls `api.weather.gov` for active Tornado, Severe Thunderstorm, Flash Flood, and Extreme Wind warnings and displays a full-screen high-contrast emergency alert modal. Configurable directly in **`Settings -> 📱 Apps`**.
19. **🖤 E-Ink Deep Refresh (`plugin-eink-refresh`)** — Adds a floating `⚡ Flash` button to trigger a full black-white-black E-Ink waveform flash and eliminate ghosting.
20. **💾 Game Auto-Save Vault (`plugin-autosave-vault`)** — Snapshots and restores all `khub_*` localStorage game states and high scores.
21. **🚀 Quick App Switcher (`plugin-quick-switcher`)** — Floating `⇄ Switch` pill for jumping between installed store apps without returning to the home screen.

---

### ⚙️ Settings & System Management (v2.8)
* **📱 Apps Settings Category** *(New in v2.8!)* — Dedicated **`📱 Apps`** section in Settings to configure app-specific preferences, starting with **NOAA Emergency Weather Alert** (custom Latitude/Longitude, Auto-Locate via IP, Alert Trigger Mode for Extreme/Severe vs All Weather Advisories, and a live `Test / Check Now` button) and **All-Games Scale Booster** default multiplier.
* **🔋 Clean Battery & Power View** *(Updated in v2.8!)* — Displays a clean, distraction-free summary showing only **Current Battery Left (`%`)** and **Estimated Remaining Battery Time**, plus a Low Power Mode toggle.
* **👁️ Display & Text Size** — Global UI zoom selector (`100%` to `150%`) with automatic **1.5x RSS Feed Scaling** (`150%` to `225%`).
* **🔒 Privacy & Tracking** *(Updated in v2.8!)* — Simplified toggle stating *"Collects anonymous data for analytics."*
* **🔔 Remote Popup Notification Manager (35-Minute Poll)** *(New in v2.8!)* — Polls the KHub Cloudflare Worker every **35 minutes** for admin broadcasts targeted to **All Kindles**, a **Specific Firmware / Version**, or your **Kindle ID**. One-time notifications are automatically dismissed and remembered in `localStorage` once seen, while **Persistent** notifications appear on every check until cleared by the admin.
* **⚠️ Remote Force Update (10-Second Countdown)** *(New in v2.8!)* — When an administrator enables a Force Update targeting your Kindle's version or ID, KHub displays an **`Update required. ⚠️`** modal with a live **10-second countdown** and automatically launches the wireless GitHub update when the timer reaches `0`.
* **🔄 3-Stage Resilient Wireless Updater** — Updates KHub over Wi-Fi via **Direct GitHub Raw Download (`index.html`)**, **Local Daemon Full-Archive Sync (`khub.sh` via `127.0.0.1:8765`)**, or **Cloudflare Worker Fallback**, with instant cache-busted reload.

---

## 📦 Repository & Package Structure

```text
KHub_v2.8/
├── khub.sh                     # KUAL / Mesquite launcher, lipc bridge, HTTP daemon (127.0.0.1:8765) & wireless zip updater
├── kindlestore.json            # Full v2.8 App Store catalog (21 apps, games & plugins)
├── admin.html                  # Cloud Admin Dashboard (Fleet telemetry, Popup Notification Manager & Force Update Manager)
├── worker.js                   # Cloudflare Worker API backend (/heartbeat, /streetpass, /notifications, /store, /update)
├── README.md                   # Complete user & developer documentation
└── khub/
    ├── config.xml              # Kindle WebApp (W3C Widget) manifest (`xyz.ethandupe.khub` v2.8)
    ├── index.html              # Complete KHub v2.8 application UI, core apps, settings & embedded store catalog
    ├── kindle_state.js         # Real-time hardware state file populated by khub.sh
    ├── cover.png               # KUAL / Home screen cover graphic
    ├── icon.png                # App icon
    └── apps/
        └── installed_apps.js   # On-disk persistence for installed App Store items (starts empty `{}`)
```

---

## 🚀 Installation Guide (Kindle Device)

### Prerequisites
1. A **jailbroken Amazon Kindle** running Firmware 5.x+ (Kindle Touch, Paperwhite 1–5, Voyage, Oasis 1–3, Basic, or Scribe).
2. **KUAL (Kindle Unified Application Launcher)** installed on your Kindle.

### Step-by-Step Installation
1. **Connect your Kindle** to your computer via USB cable (or use SSH/USBNetwork).
2. Extract **`KHub_v2.8.zip`**.
3. Copy the **`khub/`** folder and **`khub.sh`** to your Kindle's extensions directory (or root USB drive `/mnt/us/`):
   * **Recommended Path (KUAL Extension):**
     ```text
     /mnt/us/extensions/khub/
     ├── khub.sh
     ├── config.xml          (optional KUAL menu config)
     └── khub/
         ├── config.xml
         ├── index.html
         ├── kindle_state.js
         ├── cover.png
         ├── icon.png
         └── apps/
             └── installed_apps.js
     ```
   * **Alternative Path (Root USB `/mnt/us/`):**
     Copy `khub.sh` and the `khub/` folder directly to `/mnt/us/` (`E:\` on Windows or `/Volumes/Kindle/` on macOS).
4. Safely **eject your Kindle** from your computer.
5. Open **KUAL** on your Kindle and tap **Launch KHub** (or run `sh /mnt/us/khub.sh` via SSH/kterm).
6. On first launch, `khub.sh` automatically registers the `xyz.ethandupe.khub` Mesquite app with your Kindle's local SQLite app database (`/var/local/appreg.db`), starts the background hardware/update bridge on `127.0.0.1:8765`, and opens the KHub interface.

---

## 📱 Easy First-Time Setup (Phone / PC QR Setup)

Typing API keys on an E-Ink keyboard can be tedious. KHub includes a **Phone / PC Remote Setup** flow:
1. On the KHub first-boot setup screen (or inside **Settings → General → Setup from Phone / PC**), tap **📱 Setup from Phone / PC**.
2. Scan the on-screen **QR Code** with your smartphone (or visit `https://ethandupe.github.io/KindleHub/setup.html` and enter the **6-character pairing code** shown on your Kindle).
3. Enter your **Owner Name**, **Gemini API Key**, and optional **Weather Coordinates** on your phone and tap **Send to Kindle**.
4. Your Kindle automatically receives the configuration within seconds and boots straight into the Home screen!

---

## ☁️ Hosting & Cloud Admin Setup (GitHub Pages + Cloudflare Worker)

If you are hosting your own fork or managing the KHub fleet:

### 1. GitHub Pages Setup (`https://ethandupe.github.io/KindleHub`)
1. Upload the contents of this archive (`khub/`, `khub.sh`, `kindlestore.json`, `admin.html`, `README.md`) to the root of your `KindleHub` GitHub repository (`main` branch).
2. Enable **GitHub Pages** in your repository settings (`Settings -> Pages -> Deploy from branch: main / root`).
3. Whenever you push a new version of `khub/index.html` and `kindlestore.json` to GitHub, Kindles can download it wirelessly via **Settings → Software Update → Check & Install Update**.

### 2. Cloudflare Worker Backend (`worker.js`)
1. Create a Cloudflare Worker (e.g., `khub-api.ethananaya351.workers.dev`) and bind a KV Namespace named **`KHUB_KV`**.
2. Paste the contents of **`worker.js`** into your Cloudflare Worker and deploy.
3. Set your secret `ADMIN_PASSWORD` environment variable in Cloudflare Worker settings (default fallback is `khub-admin-2025`).
