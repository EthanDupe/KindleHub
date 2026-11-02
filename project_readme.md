# KHub for Kindle

KHub is a lightweight, offline-first app launcher, online app store, productivity suite, and plugin manager designed specifically for Amazon Kindle e-readers running Mesquite / web widget environments.

## Features

* **Classic App Launcher & Categories:** Clean, high-contrast E-Ink launcher layout organized into Games, Productivity, Misc, and Plugins.

*  **Online App Store:** Secure catalog, update badges, and on-device app installation into `/khub/apps/`.

* **Built-In Productivity & Games:** Includes Quick Notes Pro, 2048 E-Ink, Word Guess, Sudoku, AI Study Flashcards, Pomodoro Habits, and Lemonade Stand.

* **Kindle AI Chat & Quest:** Integrated AI features powered by Gemini 3.1 Flash Lite with zero in-app configuration friction.

* **High-Readability RSS News:** Paginated multi-feed news reader with offline caching and minimalist E-Ink typography.

* **Robust Plugin Ecosystem:** Easily installable and toggleable themes, column grids, and performance boosts.

## Installation Guide

To install KHub on your Kindle, download the repository zip from GitHub and place the files in their correct homes:

1. **Download the Repository:** Click the green **Code** button on the GitHub repository page and select **Download ZIP**, then extract the files on your computer.

2. **Copy Core Files:** Place `index.html`, `config.xml`, and `kindle_state.js` into the **`documents/khub/`** folder on your Kindle drive.

3. **Copy the Launcher:** Place the **`khub.sh`** script directly into the root **`documents/`** folder on your Kindle drive.

4. **Eject & Restart:** Safely eject your Kindle from your computer and restart your device (**Settings -> Device Options -> Restart**) to refresh the Kindle Library indexer and launch KHub.

## Configuration & API Key

To use AI-powered features like AI Chat, AI Quest, and AI Study Flashcards, you'll need a free Gemini API key:

1. **Get a Free API Key:** Head over to [aistudio.google.com](https://aistudio.google.com), sign in with your Google account, and click **Get API Key** to generate your free key.

2. Open KHub on your Kindle and navigate to **Settings -> AI & API Key**.

3. Paste your Gemini API Key directly, or use the **Enter on Phone/PC** local web server mode to securely configure your Kindle over your local Wi-Fi network.