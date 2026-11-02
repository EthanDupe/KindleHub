#!/bin/sh
# Name: KHub
# Author: EthanDupe
# Version: 2.5
# DontUseFBInk
# Icon: data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAIwAAADSAgMAAADlKsAqAAAADFBMVEX////Hx8c6OjoAAACMFR/OAAAC3ElEQVR42u3ZT2jTUBwH8JeWLrAivewg2JLLDnXsz8mLdDayQ/GgiAcRbFedMATBtSNdd9C+KEgYBWGgq4cJHTsoTvSoA1mDOxS9GBxsiJcMKr3s4CFglSbZe+3qlrysmVAqg5dj8+H3+/7y0iZpAOji5jXdNrlz5qdLmEAnTbRtmjo11LgaA0ADnFJZs8aYImfKfgMAX4kwNTBlNYAjjMqYNsMSRmTtxmM3OVTaYqBKmFkAbUZj7OYG+sRmiDo4oVsvPKmKgrabC0QJM3KEOn7HPFZD5Ll8cC4xgDJXgN0I+8cn0DR1ULKZ+3+Ps+w3ec7RQL61XornN+AavQijtNYdJ4/izEQeqLXOHw3tLTnOBfXWeWjgvc7nj8n3NI35g5nCxveWfpep6Z6JtL0sR6g5sslUx4NwXoFiIFaDYmjoq1QjTFZKxjNLigA4KZFRsEkQJseOLwoZVGegjAynO9XJxRI7yAjgzNZeL7LOjJT40OgFq7wAQkMbDkZ4kYjAeQOKxXfYDOZiteO/Fm3uZ//JHPPZ6yDgOvuh5sD9egQEDjx8UHNszS9Jg+dXzfy2Du9hs8ZK+eRmxWL+lMPTDx4FQ5nPKVyHUXrLX+I9fRajFzTIvwyGT9chNp78xcJK8mPRYswqSDEX9utsJKvZuK/fYmpZZFaD/u3yXp7bWa89D11Tag4znfqto/c29NpEzf82syn/9vp4VMUGXl+osJf05bm7YxbzOhVi1u+wjTrTz672sY/lyec3reZbKsyYM7GGgb0Pi+yb+szigKUXY+A6JalZ58nTfvacPPr+iqWOR8J5lrYaJv0d5RnWBwVbHrqm1NBrEzXOhhEPNxw/wiOhp5FhK45meQw9knsURjb0HLcVmkguqISZ9PJrPDL19Cc2WDgxEV/RCHPWy2dxLzk9B68VQrcSr8heQ9zOME6sj2JTgclNzXX2k3Td90yn/ovr4ru2Lr5D7OK2C8FvGNzVf6fHAAAAAElFTkSuQmCC

export PATH="/mnt/us/python3/bin:/mnt/us/python/bin:/mnt/us/usbnet/bin:/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin:$PATH"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "/mnt/us/documents/khub/index.html" ]; then
    SOURCE_DIR="/mnt/us/documents/khub"
elif [ -f "/mnt/us/documents/KHub/index.html" ]; then
    SOURCE_DIR="/mnt/us/documents/KHub"
elif [ -f "$SCRIPT_DIR/khub/index.html" ]; then
    SOURCE_DIR="$SCRIPT_DIR/khub"
elif [ -d "/mnt/us/documents/khub" ]; then
    SOURCE_DIR="/mnt/us/documents/khub"
elif [ -d "/mnt/us/documents/KHub" ]; then
    SOURCE_DIR="/mnt/us/documents/KHub"
else
    SOURCE_DIR="/mnt/us/documents/khub"
fi

PERSIST_DIR="/mnt/us/documents/khub"
TARGET_DIR="/var/local/mesquite/KHub"
WWW_DIR="/tmp/khub_www"
DB="/var/local/appreg.db"
APP_ID="xyz.ethandupe.khub"
PORT=8088
REPO_BASE="https://ethandupe.github.io/KindleHub"
RAW_REPO_BASE="https://raw.githubusercontent.com/ethandupe/KindleHub/main"
CLOUDFLARE_API="https://khub-api.ethananaya351.workers.dev"
DEFAULT_RSS="https://www.theguardian.com/us-news/rss"

mkdir -p "$PERSIST_DIR/apps"

# One-time v2.0 cleanup: remove any legacy preloaded apps and stray root files from v1.9
rm -f "/mnt/us/documents/index.html" "/mnt/us/documents/config.xml" "/mnt/us/documents/kindle_state.js" "/mnt/us/documents/installed_apps.js" 2>/dev/null
if [ ! -f "$PERSIST_DIR/.khub_v22_clean_apps" ]; then
    rm -rf "$PERSIST_DIR/apps/"* "$TARGET_DIR/apps/"* 2>/dev/null
    mkdir -p "$PERSIST_DIR/apps"
    printf "window.__khubDiskApps = {};\nif (window.onKhubDiskApps) { window.onKhubDiskApps(window.__khubDiskApps); }\n" > "$PERSIST_DIR/apps/installed_apps.js"
    touch "$PERSIST_DIR/.khub_v22_clean_apps"
    touch "$PERSIST_DIR/.khub_v20_no_preload"
fi

# Extract numeric version (e.g. 2.5 -> 2005) from a config.xml file for safe version comparison
get_config_ver_num() {
    CFG_FILE="$1"
    if [ ! -f "$CFG_FILE" ]; then
        echo 0
        return
    fi
    VER_STR="$(sed -n 's/.*<widget[^>]*version="\([0-9.]*\)".*/\1/p' "$CFG_FILE" 2>/dev/null | head -n 1)"
    if [ -z "$VER_STR" ]; then
        echo 0
        return
    fi
    MAJ="$(printf "%s" "$VER_STR" | cut -d. -f1 | tr -cd '0-9')"
    MIN="$(printf "%s" "$VER_STR" | cut -d. -f2 | tr -cd '0-9')"
    [ -z "$MAJ" ] && MAJ=0
    [ -z "$MIN" ] && MIN=0
    echo $((MAJ * 1000 + MIN))
}

# Install Book Cover / Thumbnail for Kindle Library (.sdr folder + system thumbnails)
install_book_cover() {
    COVER_SRC=""
    if [ -f "$PERSIST_DIR/cover.png" ]; then
        COVER_SRC="$PERSIST_DIR/cover.png"
    elif [ -f "$SOURCE_DIR/cover.png" ]; then
        COVER_SRC="$SOURCE_DIR/cover.png"
    elif [ -f "$PERSIST_DIR/icon.png" ]; then
        COVER_SRC="$PERSIST_DIR/icon.png"
    fi
    if [ -n "$COVER_SRC" ] && [ -f "$COVER_SRC" ]; then
        mkdir -p "/mnt/us/documents/khub.sdr" 2>/dev/null
        cp "$COVER_SRC" "/mnt/us/documents/khub.sdr/icon.png" 2>/dev/null
        cp "$COVER_SRC" "/mnt/us/documents/khub.sdr/cover.png" 2>/dev/null
        if command -v sha1sum >/dev/null 2>&1 && [ -d "/mnt/us/system/thumbnails" ]; then
            CDE_KEY="$(printf "/mnt/us/documents/khub.sh" | sha1sum | awk '{print $1}')"
            if [ -n "$CDE_KEY" ]; then
                cp "$COVER_SRC" "/mnt/us/system/thumbnails/thumbnail_${CDE_KEY}_EBSP_portrait.jpg" 2>/dev/null
                cp "$COVER_SRC" "/mnt/us/system/thumbnails/thumbnail_${CDE_KEY}_SH_portrait.jpg" 2>/dev/null
                cp "$COVER_SRC" "/mnt/us/system/thumbnails/thumbnail_${CDE_KEY}_EBOK_portrait.jpg" 2>/dev/null
            fi
        fi
    fi
}

# Automatic Kindle IP detector across LIPC wifid, routing table, all interfaces (wlan0/mlan0/tiwlan0/etc.), and /proc/net/fib_trie
detect_kindle_ip() {
    IP=""
    if command -v lipc-get-prop >/dev/null 2>&1; then
        IP="$(lipc-get-prop com.lab126.wifid ipAddress 2>/dev/null | tr -d ' \r\n')"
    fi
    if [ -z "$IP" ] || [ "$IP" = "127.0.0.1" ] || [ "$IP" = "0.0.0.0" ]; then
        IP="$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="src") {print $(i+1); exit}}')"
    fi
    if [ -z "$IP" ] || [ "$IP" = "127.0.0.1" ] || [ "$IP" = "0.0.0.0" ]; then
        IP="$(ip -4 addr show 2>/dev/null | awk '/inet / {print $2}' | cut -d/ -f1 | grep -v '^127\.' | grep -v '^169\.254\.' | head -n 1)"
    fi
    if [ -z "$IP" ] || [ "$IP" = "127.0.0.1" ] || [ "$IP" = "0.0.0.0" ]; then
        IP="$(ifconfig 2>/dev/null | awk '/inet addr:/{print substr($2,6)} /inet /{print $2}' | tr -d 'addr:' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | grep -v '^127\.' | grep -v '^169\.254\.' | head -n 1)"
    fi
    if [ -z "$IP" ] || [ "$IP" = "127.0.0.1" ] || [ "$IP" = "0.0.0.0" ]; then
        IP="$(awk '/32 host LOCAL/ { print prev } { prev=$2 }' /proc/net/fib_trie 2>/dev/null | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | grep -v '^127\.' | grep -v '^169\.254\.' | head -n 1)"
    fi
    printf "%s" "$IP"
}

# Automatic Kindle Battery Level detector (0-100)
detect_kindle_battery() {
    BAT=""
    if command -v lipc-get-prop >/dev/null 2>&1; then
        BAT="$(lipc-get-prop com.lab126.powerd battLevel 2>/dev/null | tr -cd '0-9')"
    fi
    if [ -z "$BAT" ] && command -v gasgauge-info >/dev/null 2>&1; then
        BAT="$(gasgauge-info -s 2>/dev/null | tr -cd '0-9')"
    fi
    if [ -z "$BAT" ]; then
        for cap in /sys/class/power_supply/*bat*/capacity /sys/class/power_supply/*/capacity; do
            if [ -f "$cap" ]; then
                BAT="$(cat "$cap" 2>/dev/null | tr -cd '0-9')"
                [ -n "$BAT" ] && break
            fi
        done
    fi
    if [ -z "$BAT" ]; then
        BAT="100"
    fi
    printf "%s" "$BAT"
}

# Preserve existing permanent API key, tracking_id.txt, settings, rss_feeds.json, and /khub/apps before copying
SAVED_KEY=""
if [ -f "$PERSIST_DIR/api_key.txt" ]; then
    SAVED_KEY="$(cat "$PERSIST_DIR/api_key.txt")"
elif [ -f "$TARGET_DIR/api_key.txt" ]; then
    SAVED_KEY="$(cat "$TARGET_DIR/api_key.txt")"
fi

SAVED_TRACKING_ID=""
if [ -f "$PERSIST_DIR/tracking_id.txt" ]; then
    SAVED_TRACKING_ID="$(cat "$PERSIST_DIR/tracking_id.txt" | tr -cd 'A-Za-z0-9_-')"
elif [ -f "$TARGET_DIR/tracking_id.txt" ]; then
    SAVED_TRACKING_ID="$(cat "$TARGET_DIR/tracking_id.txt" | tr -cd 'A-Za-z0-9_-')"
fi

SAVED_SETTINGS=""
if [ -f "$PERSIST_DIR/khub_settings.json" ]; then
    SAVED_SETTINGS="$(cat "$PERSIST_DIR/khub_settings.json")"
elif [ -f "$TARGET_DIR/khub_settings.json" ]; then
    SAVED_SETTINGS="$(cat "$TARGET_DIR/khub_settings.json")"
fi

SAVED_RSS_JSON=""
if [ -f "$PERSIST_DIR/rss_feeds.json" ]; then
    SAVED_RSS_JSON="$(cat "$PERSIST_DIR/rss_feeds.json")"
elif [ -f "$TARGET_DIR/rss_feeds.json" ]; then
    SAVED_RSS_JSON="$(cat "$TARGET_DIR/rss_feeds.json")"
fi

SAVED_RSS_SEQ="0"
if [ -f "$PERSIST_DIR/rss_seq.txt" ]; then
    SAVED_RSS_SEQ="$(cat "$PERSIST_DIR/rss_seq.txt" | tr -cd '0-9')"
elif [ -f "$TARGET_DIR/rss_seq.txt" ]; then
    SAVED_RSS_SEQ="$(cat "$TARGET_DIR/rss_seq.txt" | tr -cd '0-9')"
fi
[ -z "$SAVED_RSS_SEQ" ] && SAVED_RSS_SEQ="0"

if [ -d "$TARGET_DIR/apps" ]; then
    cp -rn "$TARGET_DIR/apps/"* "$PERSIST_DIR/apps/" 2>/dev/null
fi

# Clear stale Mesquite AppCache so it never caches an older index.html
rm -rf /var/local/mesquite/devkit/resource/appcache/* 2>/dev/null

# Ensure we never overwrite a newer TARGET_DIR or PERSIST_DIR with an older SOURCE_DIR
TARGET_VER_NUM="$(get_config_ver_num "$TARGET_DIR/config.xml")"
PERSIST_VER_NUM="$(get_config_ver_num "$PERSIST_DIR/config.xml")"
SOURCE_VER_NUM="$(get_config_ver_num "$SOURCE_DIR/config.xml")"

if [ "$TARGET_VER_NUM" -gt "$PERSIST_VER_NUM" ] && [ -f "$TARGET_DIR/index.html" ]; then
    cp -f "$TARGET_DIR/index.html" "$PERSIST_DIR/index.html" 2>/dev/null
    cp -f "$TARGET_DIR/config.xml" "$PERSIST_DIR/config.xml" 2>/dev/null
    PERSIST_VER_NUM="$TARGET_VER_NUM"
fi
if [ "$PERSIST_VER_NUM" -gt "$SOURCE_VER_NUM" ] && [ -f "$PERSIST_DIR/index.html" ]; then
    cp -f "$PERSIST_DIR/index.html" "$SOURCE_DIR/index.html" 2>/dev/null
    cp -f "$PERSIST_DIR/config.xml" "$SOURCE_DIR/config.xml" 2>/dev/null
    [ -d "/mnt/us/documents/KHub" ] && cp -f "$PERSIST_DIR/index.html" "/mnt/us/documents/KHub/index.html" 2>/dev/null
    [ -d "/mnt/us/documents/KHub" ] && cp -f "$PERSIST_DIR/config.xml" "/mnt/us/documents/KHub/config.xml" 2>/dev/null
    sync
fi

# Copy cleanly to /var/local/mesquite/KHub
if [ -d "$SOURCE_DIR" ]; then
    rm -rf "$TARGET_DIR"
    mkdir -p "$TARGET_DIR/apps"
    cp -rf "$SOURCE_DIR/"* "$TARGET_DIR/" 2>/dev/null
    if [ "$SOURCE_DIR" != "$PERSIST_DIR" ]; then
        cp -rf "$SOURCE_DIR/"* "$PERSIST_DIR/" 2>/dev/null
    fi
else
    exit 1
fi

install_book_cover

# Restore permanent API key, tracking ID, settings, RSS feeds, and downloaded /khub/apps to both directories
if [ -n "$SAVED_KEY" ]; then
    printf "%s" "$SAVED_KEY" > "$PERSIST_DIR/api_key.txt"
    printf "%s" "$SAVED_KEY" > "$TARGET_DIR/api_key.txt"
fi
if [ -n "$SAVED_TRACKING_ID" ]; then
    printf "%s" "$SAVED_TRACKING_ID" > "$PERSIST_DIR/tracking_id.txt"
    printf "%s" "$SAVED_TRACKING_ID" > "$TARGET_DIR/tracking_id.txt"
fi
if [ -n "$SAVED_SETTINGS" ]; then
    printf "%s" "$SAVED_SETTINGS" > "$PERSIST_DIR/khub_settings.json"
    printf "%s" "$SAVED_SETTINGS" > "$TARGET_DIR/khub_settings.json"
fi
if [ -z "$SAVED_RSS_JSON" ]; then
    SAVED_RSS_JSON="[\"$DEFAULT_RSS\"]"
fi
printf "%s" "$SAVED_RSS_JSON" > "$PERSIST_DIR/rss_feeds.json"
printf "%s" "$SAVED_RSS_JSON" > "$TARGET_DIR/rss_feeds.json"
printf "%s" "$SAVED_RSS_SEQ" > "$PERSIST_DIR/rss_seq.txt"
printf "%s" "$SAVED_RSS_SEQ" > "$TARGET_DIR/rss_seq.txt"

if [ ! -f "$PERSIST_DIR/apps/installed_apps.js" ]; then
    printf "window.__khubDiskApps = {};\nif (window.onKhubDiskApps) { window.onKhubDiskApps(window.__khubDiskApps); }\n" > "$PERSIST_DIR/apps/installed_apps.js"
fi
cp -r "$PERSIST_DIR/apps/"* "$TARGET_DIR/apps/" 2>/dev/null

# Prepare /tmp/khub_www for BusyBox httpd / CGI and Python fallback
mount -o remount,exec /tmp 2>/dev/null
mkdir -p "$WWW_DIR/cgi-bin"
chmod 777 "$WWW_DIR" "$WWW_DIR/cgi-bin" 2>/dev/null
printf "%s" "$SAVED_KEY" > "$WWW_DIR/api_key.txt" 2>/dev/null
printf "%s" "$SAVED_RSS_JSON" > "$WWW_DIR/rss_feeds.json" 2>/dev/null
printf "%s" "$SAVED_RSS_SEQ" > "$WWW_DIR/rss_seq.txt" 2>/dev/null

cat << 'EOF_REMOTE_HTML' > "$WWW_DIR/index.html"
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>KHub v2.5 — Remote Phone/PC Setup</title>
<style>
body { font-family: sans-serif; background: #fff; color: #000; text-align: center; padding: 18px; margin: 0; }
.box { max-width: 500px; margin: 14px auto; border: 4px solid #000; padding: 18px; text-align: left; background: #fff; }
h1 { margin: 0 0 6px 0; font-size: 24px; text-transform: uppercase; border-bottom: 3px solid #000; padding-bottom: 6px; }
h2 { margin: 0 0 6px 0; font-size: 19px; text-transform: uppercase; }
p { font-size: 15px; line-height: 1.4; margin: 6px 0 12px 0; }
input[type=text], textarea { width: 100%; box-sizing: border-box; font-size: 16px; padding: 11px; border: 3px solid #000; margin: 8px 0 12px 0; font-family: monospace; }
button { width: 100%; font-size: 18px; font-weight: bold; padding: 13px; background: #000; color: #fff; border: 3px solid #000; cursor: pointer; margin-bottom: 6px; }
button.secondary { background: #fff; color: #000; font-size: 14px; padding: 8px 10px; width: auto; margin: 2px 4px 2px 0; }
.msg { margin: 12px 0; padding: 12px; border: 3px solid #000; font-weight: bold; background: #eee; }
.feed-item { border: 2px solid #000; padding: 8px 10px; margin-bottom: 6px; font-size: 14px; word-break: break-all; display: flex; justify-content: space-between; align-items: center; gap: 8px; }
</style>
</head>
<body>
<div class="box">
  <h1>KHub v2.5 Remote Setup</h1>
  <p>Configure your Kindle's <strong>Gemini API Key</strong> or <strong>Custom RSS Feed URLs</strong> directly from your Phone or PC.</p>
  <div id="status-banner"></div>
</div>

<div class="box">
  <h2>1. Gemini AI API Key</h2>
  <p>Paste your Gemini API Key below to save it permanently on your Kindle.</p>
  <form method="GET" action="/cgi-bin/khub.cgi">
    <input type="hidden" name="action" value="save">
    <input type="hidden" name="from" value="remote">
    <label><strong>Gemini API Key:</strong></label>
    <input type="text" name="key" id="key-input" placeholder="Paste Gemini API key here..." required autocomplete="off">
    <button type="submit">Save API Key to Kindle</button>
  </form>
</div>

<div class="box">
  <h2>2. Custom RSS Feed URLs</h2>
  <p>Enter one or multiple RSS Feed URLs (separated by commas or new lines) to sync them to your Kindle's <strong>RSS Feed</strong> reader.</p>
  <form method="GET" action="/cgi-bin/khub.cgi" onsubmit="prepareRssSubmit()">
    <input type="hidden" name="action" value="save_rss">
    <input type="hidden" name="from" value="remote">
    <input type="hidden" name="feeds" id="feeds-hidden-input" value="">
    <label><strong>Add or Edit RSS Feed URLs (one per line or comma-separated):</strong></label>
    <textarea id="rss-textarea" rows="5" placeholder="https://www.theguardian.com/us-news/rss&#10;https://hnrss.org/frontpage&#10;https://feeds.bbci.co.uk/news/rss.xml"></textarea>
    <button type="submit">Save RSS Feeds to Kindle</button>
  </form>
  <div style="margin-top: 10px;">
    <strong>Currently Saved Feeds on Kindle:</strong>
    <div id="current-feeds-list" style="margin-top: 6px;"></div>
  </div>
</div>

<script src="/state.js"></script>
<script>
function renderRemoteState() {
  var st = window.__khubDiskState || {};
  if (st.apiKey) {
    var el = document.getElementById('key-input');
    if (el && !el.value) el.value = st.apiKey;
  }
  var feeds = st.rssFeeds || ["https://www.theguardian.com/us-news/rss"];
  var ta = document.getElementById('rss-textarea');
  if (ta && !ta.value) {
    ta.value = feeds.join("\n");
  }
  var listEl = document.getElementById('current-feeds-list');
  if (listEl) {
    var html = '';
    for (var i = 0; i < feeds.length; i++) {
      html += '<div class="feed-item"><span>' + feeds[i].replace(/</g, '&lt;') + '</span></div>';
    }
    listEl.innerHTML = html;
  }
}
function prepareRssSubmit() {
  var ta = document.getElementById('rss-textarea');
  var hid = document.getElementById('feeds-hidden-input');
  if (ta && hid) {
    var raw = ta.value || '';
    var parts = raw.split(/[\r\n,;]+/);
    var clean = [];
    for (var i = 0; i < parts.length; i++) {
      var u = parts[i].replace(/^\s+|\s+$/g, '');
      if (u) {
        if (u.indexOf('http://') !== 0 && u.indexOf('https://') !== 0) {
          u = 'https://' + u;
        }
        clean.push(u);
      }
    }
    if (clean.length === 0) {
      clean.push('https://www.theguardian.com/us-news/rss');
    }
    hid.value = clean.join('|');
  }
}
renderRemoteState();
</script>
</body>
</html>
EOF_REMOTE_HTML

# Create universal POSIX shell CGI script (/tmp/khub_www/cgi-bin/khub.cgi) for BusyBox httpd & CLI helper
cat << 'EOF_CGI' > "$WWW_DIR/cgi-bin/khub.cgi"
#!/bin/sh
export PATH="/mnt/us/python3/bin:/mnt/us/python/bin:/mnt/us/usbnet/bin:/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin:$PATH"
PERSIST_DIR="/mnt/us/documents/khub"
TARGET_DIR="/var/local/mesquite/KHub"
WWW_DIR="/tmp/khub_www"
PORT=8088
REPO="https://ethandupe.github.io/KindleHub"
RAW_REPO="https://raw.githubusercontent.com/ethandupe/KindleHub/main"
CLOUDFLARE_API="https://khub-api.ethananaya351.workers.dev"
DEFAULT_RSS="https://www.theguardian.com/us-news/rss"

urldecode() {
    printf "%s" "$1" | sed 's/+/ /g; s/%\([0-9A-Fa-f][0-9A-Fa-f]\)/\\x\1/g' | xargs -0 printf "%b" 2>/dev/null || printf "%s" "$1"
}

get_raw_param() {
    KEY="$1"
    printf "%s" "$QUERY_STRING" | tr '&' '\n' | grep "^${KEY}=" | head -n 1 | cut -d= -f2-
}

get_param() {
    KEY="$1"
    printf "%s" "$QUERY_STRING" | tr '&' '\n' | grep "^${KEY}=" | head -n 1 | cut -d= -f2- | sed 's/%20//g; s/%0[aAdD9]//g; s/+//g'
}

get_ip() {
    IP=""
    if command -v lipc-get-prop >/dev/null 2>&1; then
        IP="$(lipc-get-prop com.lab126.wifid ipAddress 2>/dev/null | tr -d ' \r\n')"
    fi
    if [ -z "$IP" ] || [ "$IP" = "127.0.0.1" ] || [ "$IP" = "0.0.0.0" ]; then
        IP="$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="src") {print $(i+1); exit}}')"
    fi
    if [ -z "$IP" ] || [ "$IP" = "127.0.0.1" ] || [ "$IP" = "0.0.0.0" ]; then
        IP="$(ip -4 addr show 2>/dev/null | awk '/inet / {print $2}' | cut -d/ -f1 | grep -v '^127\.' | grep -v '^169\.254\.' | head -n 1)"
    fi
    if [ -z "$IP" ] || [ "$IP" = "127.0.0.1" ] || [ "$IP" = "0.0.0.0" ]; then
        IP="$(ifconfig 2>/dev/null | awk '/inet addr:/{print substr($2,6)} /inet /{print $2}' | tr -d 'addr:' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | grep -v '^127\.' | grep -v '^169\.254\.' | head -n 1)"
    fi
    printf "%s" "$IP"
}

get_battery() {
    BAT=""
    if command -v lipc-get-prop >/dev/null 2>&1; then
        BAT="$(lipc-get-prop com.lab126.powerd battLevel 2>/dev/null | tr -cd '0-9')"
    fi
    if [ -z "$BAT" ] && command -v gasgauge-info >/dev/null 2>&1; then
        BAT="$(gasgauge-info -s 2>/dev/null | tr -cd '0-9')"
    fi
    if [ -z "$BAT" ]; then
        for cap in /sys/class/power_supply/*bat*/capacity /sys/class/power_supply/*/capacity; do
            if [ -f "$cap" ]; then
                BAT="$(cat "$cap" 2>/dev/null | tr -cd '0-9')"
                [ -n "$BAT" ] && break
            fi
        done
    fi
    [ -z "$BAT" ] && BAT="100"
    printf "%s" "$BAT"
}

sync_state() {
    REMOTE_ACTIVE_FLAG="${1:-true}"
    AUTO_STOPPED_FLAG="${2:-false}"
    CUR_IP="$(get_ip)"
    CUR_BAT="$(get_battery)"
    CUR_KEY=""
    if [ -f "$PERSIST_DIR/api_key.txt" ]; then
        CUR_KEY="$(cat "$PERSIST_DIR/api_key.txt" 2>/dev/null)"
    elif [ -f "$TARGET_DIR/api_key.txt" ]; then
        CUR_KEY="$(cat "$TARGET_DIR/api_key.txt" 2>/dev/null)"
    fi
    ESC_KEY="$(printf "%s" "$CUR_KEY" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr -d '\r\n')"
    CUR_TID=""
    if [ -f "$PERSIST_DIR/tracking_id.txt" ]; then
        CUR_TID="$(cat "$PERSIST_DIR/tracking_id.txt" 2>/dev/null | tr -cd 'A-Za-z0-9_-')"
    elif [ -f "$TARGET_DIR/tracking_id.txt" ]; then
        CUR_TID="$(cat "$TARGET_DIR/tracking_id.txt" 2>/dev/null | tr -cd 'A-Za-z0-9_-')"
    fi
    ZOOM_VAL="100"
    if [ -f "$PERSIST_DIR/khub_settings.json" ]; then
        Z_TMP="$(sed -n 's/.*"zoom"[[:space:]]*:[[:space:]]*\([0-9]*\).*/\1/p' "$PERSIST_DIR/khub_settings.json" 2>/dev/null | head -n 1)"
        [ -n "$Z_TMP" ] && ZOOM_VAL="$Z_TMP"
    fi
    RSS_JSON="[\"$DEFAULT_RSS\"]"
    if [ -f "$PERSIST_DIR/rss_feeds.json" ]; then
        TMP_R="$(cat "$PERSIST_DIR/rss_feeds.json" 2>/dev/null | tr -d '\r\n')"
        [ -n "$TMP_R" ] && RSS_JSON="$TMP_R"
    elif [ -f "$TARGET_DIR/rss_feeds.json" ]; then
        TMP_R="$(cat "$TARGET_DIR/rss_feeds.json" 2>/dev/null | tr -d '\r\n')"
        [ -n "$TMP_R" ] && RSS_JSON="$TMP_R"
    fi
    RSS_SEQ="0"
    if [ -f "$PERSIST_DIR/rss_seq.txt" ]; then
        TMP_S="$(cat "$PERSIST_DIR/rss_seq.txt" 2>/dev/null | tr -cd '0-9')"
        [ -n "$TMP_S" ] && RSS_SEQ="$TMP_S"
    fi
    STATE_JSON="{\"ok\":true,\"ip\":\"$CUR_IP\",\"port\":$PORT,\"remoteActive\":$REMOTE_ACTIVE_FLAG,\"autoStopped\":$AUTO_STOPPED_FLAG,\"apiKey\":\"$ESC_KEY\",\"trackingId\":\"$CUR_TID\",\"batteryLevel\":$CUR_BAT,\"zoom\":$ZOOM_VAL,\"rssFeeds\":$RSS_JSON,\"rssUpdatedSeq\":$RSS_SEQ}"
    JS_STR="window.__khubDiskState = $STATE_JSON; if (window.onKhubDiskState) { window.onKhubDiskState(window.__khubDiskState); }"
    printf "%s\n" "$JS_STR" > "$PERSIST_DIR/kindle_state.js" 2>/dev/null
    printf "%s\n" "$JS_STR" > "$TARGET_DIR/kindle_state.js" 2>/dev/null
    printf "%s\n" "$JS_STR" > "$WWW_DIR/state.js" 2>/dev/null
    printf "%s" "$CUR_KEY" > "$WWW_DIR/api_key.txt" 2>/dev/null
    printf "%s" "$RSS_JSON" > "$WWW_DIR/rss_feeds.json" 2>/dev/null
    if [ -n "$CUR_TID" ]; then
        printf "%s" "$CUR_TID" > "$WWW_DIR/tracking_id.txt" 2>/dev/null
    fi
}

ACTION="$(get_param action)"
FROM_PARAM="$(get_param from)"
JSONP_PARAM="$(get_param jsonp)"

if [ -n "$(get_param trackingId)" ]; then
    TID_IN="$(get_param trackingId | tr -cd 'A-Za-z0-9_-')"
    if [ -n "$TID_IN" ]; then
        printf "%s" "$TID_IN" > "$PERSIST_DIR/tracking_id.txt" 2>/dev/null
        printf "%s" "$TID_IN" > "$TARGET_DIR/tracking_id.txt" 2>/dev/null
        printf "%s" "$TID_IN" > "$WWW_DIR/tracking_id.txt" 2>/dev/null
    fi
fi

# Handle saving custom RSS feeds (from Phone/PC remote UI or Kindle in-app sync)
if [ "$ACTION" = "save_rss" ] || [ -n "$(get_raw_param feeds)" ]; then
    RAW_FEEDS="$(get_raw_param feeds)"
    DEC_FEEDS="$(urldecode "$RAW_FEEDS")"
    # Split on '|', ',', newline, or space and build JSON array + plain text list
    JSON_ARR="["
    TXT_LIST=""
    FIRST=1
    HAS_DEF=0
    OLD_IFS="$IFS"
    IFS="$(printf '|,\n\r\t ')"
    for item in $DEC_FEEDS; do
        CLEAN_U="$(printf "%s" "$item" | tr -d ' "\r\n\t' | sed 's/\\/\\\\/g')"
        if [ -n "$CLEAN_U" ]; then
            case "$CLEAN_U" in
                http://*|https://*) ;;
                *) CLEAN_U="https://$CLEAN_U" ;;
            esac
            [ "$CLEAN_U" = "$DEFAULT_RSS" ] && HAS_DEF=1
            if [ "$FIRST" -eq 1 ]; then
                JSON_ARR="${JSON_ARR}\"${CLEAN_U}\""
                TXT_LIST="${CLEAN_U}"
                FIRST=0
            else
                JSON_ARR="${JSON_ARR},\"${CLEAN_U}\""
                TXT_LIST="${TXT_LIST}\n${CLEAN_U}"
            fi
        fi
    done
    IFS="$OLD_IFS"
    if [ "$FIRST" -eq 1 ]; then
        JSON_ARR="[\"$DEFAULT_RSS\"]"
        TXT_LIST="$DEFAULT_RSS"
    else
        if [ "$HAS_DEF" -eq 0 ]; then
            JSON_ARR="[\"$DEFAULT_RSS\",${JSON_ARR#\[}"
            TXT_LIST="${DEFAULT_RSS}\n${TXT_LIST}"
        fi
        JSON_ARR="${JSON_ARR}]"
    fi
    NEW_SEQ="$(date +%s 2>/dev/null || echo 1)"
    if [ "$FROM_PARAM" = "remote" ]; then
        NEW_SEQ=$((NEW_SEQ + 1))
    fi
    printf "%s\n" "$JSON_ARR" > "$PERSIST_DIR/rss_feeds.json" 2>/dev/null
    printf "%s\n" "$JSON_ARR" > "$TARGET_DIR/rss_feeds.json" 2>/dev/null
    printf "%s\n" "$JSON_ARR" > "$WWW_DIR/rss_feeds.json" 2>/dev/null
    printf "%b\n" "$TXT_LIST" > "$PERSIST_DIR/rss_feeds.txt" 2>/dev/null
    printf "%b\n" "$TXT_LIST" > "$TARGET_DIR/rss_feeds.txt" 2>/dev/null
    printf "%b\n" "$TXT_LIST" > "$WWW_DIR/rss_feeds.txt" 2>/dev/null
    printf "%s" "$NEW_SEQ" > "$PERSIST_DIR/rss_seq.txt" 2>/dev/null
    printf "%s" "$NEW_SEQ" > "$TARGET_DIR/rss_seq.txt" 2>/dev/null
    printf "%s" "$NEW_SEQ" > "$WWW_DIR/rss_seq.txt" 2>/dev/null

    if [ "$FROM_PARAM" = "remote" ]; then
        sync_state "false" "true"
        printf "Content-Type: text/html; charset=utf-8\r\nCache-Control: no-store\r\nAccess-Control-Allow-Origin: *\r\n\r\n"
        cat << EOF_RSS_SAVED
<!DOCTYPE html>
<html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>KHub - RSS Feeds Saved!</title>
<style>body{font-family:sans-serif;background:#fff;color:#000;text-align:center;padding:20px;margin:0;}.box{max-width:480px;margin:16px auto;border:4px solid #000;padding:20px;text-align:left;}h1{margin:0 0 8px 0;font-size:24px;text-transform:uppercase;}a.btn{display:block;text-align:center;text-decoration:none;font-size:18px;font-weight:bold;padding:13px;background:#000;color:#fff;border:3px solid #000;margin-top:14px;}.msg{margin-top:12px;padding:12px;border:3px solid #000;font-weight:bold;background:#eee;}</style>
</head><body><div class="box">
<h1>RSS Feeds Saved to Kindle</h1>
<div class="msg">Success! Your Kindle has received and saved your Custom RSS Feeds, synced them into KHub RSS Feed, and stopped the remote listener automatically. You can now return to your Kindle!</div>
<a class="btn" href="/">Back to KHub Remote Setup</a>
</div></body></html>
EOF_RSS_SAVED
        exit 0
    fi
    sync_state "true" "false"
    if [ -n "$JSONP_PARAM" ]; then
        printf "Content-Type: application/javascript; charset=utf-8\r\nCache-Control: no-store\r\nAccess-Control-Allow-Origin: *\r\n\r\n"
        cat "$PERSIST_DIR/kindle_state.js" 2>/dev/null
    else
        printf "Content-Type: application/json\r\nCache-Control: no-store\r\nAccess-Control-Allow-Origin: *\r\n\r\n"
        printf "%s\n" "$STATE_JSON"
    fi
    exit 0
fi

if [ "$ACTION" = "save" ] || [ -n "$(get_param key)" ] || [ -n "$(get_param clear)" ] || [ -n "$(get_param zoom)" ] || [ -n "$(get_param trackingId)" ]; then
    if [ -n "$(get_param clear)" ]; then
        printf "" > "$PERSIST_DIR/api_key.txt" 2>/dev/null
        printf "" > "$TARGET_DIR/api_key.txt" 2>/dev/null
    elif [ -n "$(get_param key)" ]; then
        NEW_K="$(get_param key | tr -cd 'A-Za-z0-9_.-')"
        printf "%s" "$NEW_K" > "$PERSIST_DIR/api_key.txt" 2>/dev/null
        printf "%s" "$NEW_K" > "$TARGET_DIR/api_key.txt" 2>/dev/null
    fi
    if [ -n "$(get_param zoom)" ]; then
        Z_IN="$(get_param zoom | tr -cd '0-9')"
        if [ -n "$Z_IN" ]; then
            printf "{\"zoom\": %s}\n" "$Z_IN" > "$PERSIST_DIR/khub_settings.json" 2>/dev/null
            printf "{\"zoom\": %s}\n" "$Z_IN" > "$TARGET_DIR/khub_settings.json" 2>/dev/null
        fi
    fi
    if [ "$FROM_PARAM" = "remote" ]; then
        sync_state "false" "true"
        SAVED_K="$(cat "$PERSIST_DIR/api_key.txt" 2>/dev/null | sed 's/"/\&quot;/g')"
        printf "Content-Type: text/html; charset=utf-8\r\nCache-Control: no-store\r\nAccess-Control-Allow-Origin: *\r\n\r\n"
        cat << EOF_SAVED
<!DOCTYPE html>
<html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>KHub - Saved!</title>
<style>body{font-family:sans-serif;background:#fff;color:#000;text-align:center;padding:20px;margin:0;}.box{max-width:480px;margin:16px auto;border:4px solid #000;padding:20px;text-align:left;}h1{margin:0 0 8px 0;font-size:24px;}input[type=text]{width:100%;box-sizing:border-box;font-size:18px;padding:12px;border:3px solid #000;margin:10px 0 16px 0;}button,a.btn{display:block;width:100%;box-sizing:border-box;text-align:center;text-decoration:none;font-size:18px;font-weight:bold;padding:14px;background:#000;color:#fff;border:3px solid #000;cursor:pointer;margin-top:10px;}.msg{margin-top:14px;padding:12px;border:3px solid #000;font-weight:bold;background:#eee;}</style>
</head><body><div class="box">
<h1>KHUB API KEY SAVED</h1>
<div class="msg">Success! Your Kindle has received and permanently stored your Gemini API Key. You can now return to your Kindle!</div>
<form method="GET" action="/cgi-bin/khub.cgi" style="margin-top:16px;">
<input type="hidden" name="action" value="save"><input type="hidden" name="from" value="remote">
<label><strong>Stored API Key:</strong></label>
<input type="text" name="key" value="$SAVED_K" required autocomplete="off">
<button type="submit">Update Key</button>
</form>
<a class="btn" href="/">Manage RSS Feeds &amp; Setup</a>
</div></body></html>
EOF_SAVED
        exit 0
    fi
    sync_state "true" "false"
fi

# Cloudflare Status Proxy (bypasses legacy Kindle WebKit SSL errors)
if [ "$ACTION" = "cloud_status" ]; then
    TS="$(date +%s 2>/dev/null || echo 1)"
    rm -f /tmp/khub_cf_status.json 2>/dev/null
    /usr/bin/curl -k -sL --connect-timeout 8 "${CLOUDFLARE_API}/status?_t=${TS}" -o /tmp/khub_cf_status.json 2>/dev/null
    [ ! -s /tmp/khub_cf_status.json ] && curl -k -sL --connect-timeout 8 "${CLOUDFLARE_API}/status?_t=${TS}" -o /tmp/khub_cf_status.json 2>/dev/null
    [ ! -s /tmp/khub_cf_status.json ] && wget --no-check-certificate -q -O /tmp/khub_cf_status.json "${CLOUDFLARE_API}/status?_t=${TS}" 2>/dev/null
    printf "Content-Type: application/json; charset=utf-8\r\nCache-Control: no-store\r\nAccess-Control-Allow-Origin: *\r\n\r\n"
    if [ -s /tmp/khub_cf_status.json ]; then
        cat /tmp/khub_cf_status.json
    else
        printf "{\"ok\":false}\n"
    fi
    exit 0
fi

# Cloudflare Heartbeat Proxy (POST or GET payload -> forwards to Cloudflare Worker /heartbeat via curl -k)
if [ "$ACTION" = "cloud_heartbeat" ]; then
    rm -f /tmp/khub_hb_in.json /tmp/khub_hb_out.json 2>/dev/null
    if [ "$REQUEST_METHOD" = "POST" ]; then
        cat > /tmp/khub_hb_in.json 2>/dev/null
    else
        RAW_P="$(get_raw_param payload)"
        if [ -n "$RAW_P" ]; then
            urldecode "$RAW_P" > /tmp/khub_hb_in.json 2>/dev/null
        fi
    fi
    if [ -s /tmp/khub_hb_in.json ]; then
        /usr/bin/curl -k -sL --connect-timeout 10 -X POST -H "Content-Type: application/json" --data-binary @/tmp/khub_hb_in.json "${CLOUDFLARE_API}/heartbeat" -o /tmp/khub_hb_out.json 2>/dev/null
        [ ! -s /tmp/khub_hb_out.json ] && curl -k -sL --connect-timeout 10 -X POST -H "Content-Type: application/json" --data-binary @/tmp/khub_hb_in.json "${CLOUDFLARE_API}/heartbeat" -o /tmp/khub_hb_out.json 2>/dev/null
    fi
    printf "Content-Type: application/json; charset=utf-8\r\nCache-Control: no-store\r\nAccess-Control-Allow-Origin: *\r\n\r\n"
    if [ -s /tmp/khub_hb_out.json ]; then
        cat /tmp/khub_hb_out.json
    else
        printf "{\"ok\":true}\n"
    fi
    exit 0
fi

# Store Catalog Proxy
if [ "$ACTION" = "store_catalog" ] || [ "$ACTION" = "check_update" ]; then
    TS="$(date +%s 2>/dev/null || echo 1)"
    rm -f /tmp/khub_store_cat.json 2>/dev/null
    /usr/bin/curl -k -f -sL --connect-timeout 10 "${REPO}/kindlestore.json?_t=${TS}" -o /tmp/khub_store_cat.json 2>/dev/null
    [ ! -s /tmp/khub_store_cat.json ] && curl -k -f -sL --connect-timeout 10 "${REPO}/kindlestore.json?_t=${TS}" -o /tmp/khub_store_cat.json 2>/dev/null
    [ ! -s /tmp/khub_store_cat.json ] && wget --no-check-certificate -q -O /tmp/khub_store_cat.json "${REPO}/kindlestore.json?_t=${TS}" 2>/dev/null
    [ ! -s /tmp/khub_store_cat.json ] && /usr/bin/curl -k -f -sL --connect-timeout 10 "${RAW_REPO}/kindlestore.json?_t=${TS}" -o /tmp/khub_store_cat.json 2>/dev/null
    [ ! -s /tmp/khub_store_cat.json ] && wget --no-check-certificate -q -O /tmp/khub_store_cat.json "${RAW_REPO}/kindlestore.json?_t=${TS}" 2>/dev/null
    printf "Content-Type: application/json; charset=utf-8\r\nCache-Control: no-store\r\nAccess-Control-Allow-Origin: *\r\n\r\n"
    if [ -s /tmp/khub_store_cat.json ]; then
        cat /tmp/khub_store_cat.json
    else
        printf "{\"ok\":false}\n"
    fi
    exit 0
fi

# Direct raw file write via POST /cgi-bin/khub.cgi?action=write_file&target=index.html|config.xml|khub.sh
if [ "$ACTION" = "write_file" ] && [ "$REQUEST_METHOD" = "POST" ]; then
    TARGET_NAME="$(get_param target)"
    TMP_IN="/tmp/khub_post_file.tmp"
    rm -f "$TMP_IN" 2>/dev/null
    cat > "$TMP_IN" 2>/dev/null
    WROTE_OK="false"
    if [ "$TARGET_NAME" = "index.html" ] && grep -q "KHUB_CURRENT_VERSION" "$TMP_IN" 2>/dev/null; then
        cp -f "$TMP_IN" "$PERSIST_DIR/index.html"
        cp -f "$TMP_IN" "$TARGET_DIR/index.html"
        [ -d "/mnt/us/documents/KHub" ] && cp -f "$TMP_IN" "/mnt/us/documents/KHub/index.html" 2>/dev/null
        WROTE_OK="true"
    elif [ "$TARGET_NAME" = "config.xml" ] && grep -qi "<widget" "$TMP_IN" 2>/dev/null; then
        cp -f "$TMP_IN" "$PERSIST_DIR/config.xml"
        cp -f "$TMP_IN" "$TARGET_DIR/config.xml"
        [ -d "/mnt/us/documents/KHub" ] && cp -f "$TMP_IN" "/mnt/us/documents/KHub/config.xml" 2>/dev/null
        WROTE_OK="true"
    elif [ "$TARGET_NAME" = "khub.sh" ] && grep -q "^#!/bin/sh" "$TMP_IN" 2>/dev/null; then
        tr -d '\r' < "$TMP_IN" > /mnt/us/documents/khub.sh
        chmod +x /mnt/us/documents/khub.sh
        WROTE_OK="true"
    fi
    rm -rf /var/local/mesquite/devkit/resource/appcache/* 2>/dev/null
    sync
    printf "Content-Type: application/json\r\nCache-Control: no-store\r\nAccess-Control-Allow-Origin: *\r\n\r\n"
    printf "{\"ok\":%s}\n" "$WROTE_OK"
    exit 0
fi

if [ "$ACTION" = "uninstall" ]; then
    APP_ID_DEL="$(get_param id | tr -cd 'a-zA-Z0-9_-')"
    if [ -n "$APP_ID_DEL" ]; then
        rm -rf "$PERSIST_DIR/apps/$APP_ID_DEL" "$TARGET_DIR/apps/$APP_ID_DEL" 2>/dev/null
    fi
fi

# Reliable Multi-Source OTA System Updater (action=update or action=reset_software)
if [ "$ACTION" = "update" ] || [ "$ACTION" = "reset_software" ]; then
    TS="$(date +%s 2>/dev/null || echo 1)"
    mkdir -p "$PERSIST_DIR/apps" "$TARGET_DIR/apps"

    # Preserve tracking_id.txt, api_key.txt, and rss_feeds.json across update / reset_software
    KEEP_TID=""
    if [ -f "$PERSIST_DIR/tracking_id.txt" ]; then
        KEEP_TID="$(cat "$PERSIST_DIR/tracking_id.txt" 2>/dev/null | tr -cd 'A-Za-z0-9_-')"
    elif [ -f "$TARGET_DIR/tracking_id.txt" ]; then
        KEEP_TID="$(cat "$TARGET_DIR/tracking_id.txt" 2>/dev/null | tr -cd 'A-Za-z0-9_-')"
    fi
    KEEP_KEY=""
    if [ -f "$PERSIST_DIR/api_key.txt" ]; then
        KEEP_KEY="$(cat "$PERSIST_DIR/api_key.txt" 2>/dev/null)"
    elif [ -f "$TARGET_DIR/api_key.txt" ]; then
        KEEP_KEY="$(cat "$TARGET_DIR/api_key.txt" 2>/dev/null)"
    fi
    KEEP_RSS=""
    if [ -f "$PERSIST_DIR/rss_feeds.json" ]; then
        KEEP_RSS="$(cat "$PERSIST_DIR/rss_feeds.json" 2>/dev/null)"
    elif [ -f "$TARGET_DIR/rss_feeds.json" ]; then
        KEEP_RSS="$(cat "$TARGET_DIR/rss_feeds.json" 2>/dev/null)"
    fi

    dl_file() {
        URL="$1"
        DEST="$2"
        rm -f "$DEST" 2>/dev/null
        /usr/bin/curl -k -f -sL --connect-timeout 15 "${URL}?_t=${TS}" -o "$DEST" 2>/dev/null
        [ ! -s "$DEST" ] && curl -k -f -sL --connect-timeout 15 "${URL}?_t=${TS}" -o "$DEST" 2>/dev/null
        [ ! -s "$DEST" ] && wget --no-check-certificate -q -O "$DEST" "${URL}?_t=${TS}" 2>/dev/null
        [ ! -s "$DEST" ] && wget -q -O "$DEST" "${URL}?_t=${TS}" 2>/dev/null
    }

    UPDATED_INDEX=0
    for u in "$REPO/khub/index.html" "$RAW_REPO/khub/index.html" "$REPO/index.html" "$RAW_REPO/index.html"; do
        dl_file "$u" /tmp/khub_u_index.html
        if grep -q "KHUB_CURRENT_VERSION" /tmp/khub_u_index.html 2>/dev/null && grep -qi "<html" /tmp/khub_u_index.html 2>/dev/null; then
            cp -f /tmp/khub_u_index.html "$PERSIST_DIR/index.html"
            cp -f /tmp/khub_u_index.html "$TARGET_DIR/index.html"
            [ -d "/mnt/us/documents/KHub" ] && cp -f /tmp/khub_u_index.html "/mnt/us/documents/KHub/index.html" 2>/dev/null
            UPDATED_INDEX=1
            break
        fi
    done

    UPDATED_CFG=0
    for u in "$REPO/khub/config.xml" "$RAW_REPO/khub/config.xml" "$REPO/config.xml" "$RAW_REPO/config.xml"; do
        dl_file "$u" /tmp/khub_u_config.xml
        if grep -qi "<widget" /tmp/khub_u_config.xml 2>/dev/null && grep -q "xyz.ethandupe.khub" /tmp/khub_u_config.xml 2>/dev/null; then
            cp -f /tmp/khub_u_config.xml "$PERSIST_DIR/config.xml"
            cp -f /tmp/khub_u_config.xml "$TARGET_DIR/config.xml"
            [ -d "/mnt/us/documents/KHub" ] && cp -f /tmp/khub_u_config.xml "/mnt/us/documents/KHub/config.xml" 2>/dev/null
            UPDATED_CFG=1
            break
        fi
    done

    for u in "$REPO/khub.sh" "$RAW_REPO/khub.sh"; do
        dl_file "$u" /tmp/khub_u_sh.sh
        if grep -q "^#!/bin/sh" /tmp/khub_u_sh.sh 2>/dev/null && grep -q "xyz.ethandupe.khub" /tmp/khub_u_sh.sh 2>/dev/null; then
            tr -d '\r' < /tmp/khub_u_sh.sh > /mnt/us/documents/khub.sh
            chmod +x /mnt/us/documents/khub.sh
            break
        fi
    done

    rm -rf /var/local/mesquite/devkit/resource/appcache/* 2>/dev/null

    if [ -n "$KEEP_TID" ]; then
        printf "%s" "$KEEP_TID" > "$PERSIST_DIR/tracking_id.txt" 2>/dev/null
        printf "%s" "$KEEP_TID" > "$TARGET_DIR/tracking_id.txt" 2>/dev/null
    fi
    if [ -n "$KEEP_KEY" ]; then
        printf "%s" "$KEEP_KEY" > "$PERSIST_DIR/api_key.txt" 2>/dev/null
        printf "%s" "$KEEP_KEY" > "$TARGET_DIR/api_key.txt" 2>/dev/null
    fi
    if [ -n "$KEEP_RSS" ]; then
        printf "%s" "$KEEP_RSS" > "$PERSIST_DIR/rss_feeds.json" 2>/dev/null
        printf "%s" "$KEEP_RSS" > "$TARGET_DIR/rss_feeds.json" 2>/dev/null
    fi

    sync_state "true" "false"
    sync

    NEW_VER="$(sed -n 's/.*<widget[^>]*version="\([0-9.]*\)".*/\1/p' "$TARGET_DIR/config.xml" 2>/dev/null | head -n 1)"
    [ -z "$NEW_VER" ] && NEW_VER="2.5"
    OK_BOOL="false"
    if [ "$UPDATED_INDEX" -eq 1 ] || [ -f "$TARGET_DIR/index.html" ]; then
        OK_BOOL="true"
    fi

    if [ -n "$JSONP_PARAM" ]; then
        printf "Content-Type: application/javascript; charset=utf-8\r\nCache-Control: no-store\r\nAccess-Control-Allow-Origin: *\r\n\r\n"
        printf "if(window.onKhubSystemUpdateDone)window.onKhubSystemUpdateDone(%s, \"%s\");\n" "$OK_BOOL" "$NEW_VER"
    else
        printf "Content-Type: application/json\r\nCache-Control: no-store\r\nAccess-Control-Allow-Origin: *\r\n\r\n"
        printf "{\"ok\":%s,\"version\":\"%s\"}\n" "$OK_BOOL" "$NEW_VER"
    fi
    exit 0
fi

sync_state "true" "false"
if [ -n "$JSONP_PARAM" ]; then
    printf "Content-Type: application/javascript; charset=utf-8\r\nCache-Control: no-store\r\nAccess-Control-Allow-Origin: *\r\n\r\n"
    cat "$PERSIST_DIR/kindle_state.js" 2>/dev/null
else
    printf "Content-Type: application/json\r\nCache-Control: no-store\r\nAccess-Control-Allow-Origin: *\r\n\r\n"
    printf "%s\n" "$STATE_JSON"
fi
EOF_CGI
chmod +x "$WWW_DIR/cgi-bin/khub.cgi"

# Write initial kindle_state.js with detected Kindle IP, API key, and RSS feeds
CURRENT_IP="$(detect_kindle_ip)"
CURRENT_BAT="$(detect_kindle_battery)"
ESC_KEY="$(printf "%s" "$SAVED_KEY" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr -d '\r\n')"
CLEAN_RSS_JSON="$(printf "%s" "$SAVED_RSS_JSON" | tr -d '\r\n')"
[ -z "$CLEAN_RSS_JSON" ] && CLEAN_RSS_JSON="[\"$DEFAULT_RSS\"]"
cat << EOF_STATE > "$TARGET_DIR/kindle_state.js"
window.__khubDiskState = {"ok":true,"ip":"$CURRENT_IP","port":$PORT,"remoteActive":true,"apiKey":"$ESC_KEY","trackingId":"$SAVED_TRACKING_ID","batteryLevel":$CURRENT_BAT,"rssFeeds":$CLEAN_RSS_JSON,"rssUpdatedSeq":$SAVED_RSS_SEQ};
if (window.onKhubDiskState) { window.onKhubDiskState(window.__khubDiskState); }
EOF_STATE
cp "$TARGET_DIR/kindle_state.js" "$PERSIST_DIR/kindle_state.js" 2>/dev/null
cp "$TARGET_DIR/kindle_state.js" "$WWW_DIR/state.js" 2>/dev/null

# Open port 8088 on Kindle firewall (insert at top of INPUT chain so wifid DROP rules never block it)
open_kindle_firewall() {
    for ipt in iptables /usr/sbin/iptables /sbin/iptables; do
        if command -v "$ipt" >/dev/null 2>&1 || [ -x "$ipt" ]; then
            "$ipt" -C INPUT -p tcp --dport $PORT -j ACCEPT 2>/dev/null || "$ipt" -I INPUT 1 -p tcp --dport $PORT -j ACCEPT 2>/dev/null
            "$ipt" -C INPUT -i wlan0 -p tcp --dport $PORT -j ACCEPT 2>/dev/null || "$ipt" -I INPUT 1 -i wlan0 -p tcp --dport $PORT -j ACCEPT 2>/dev/null
            break
        fi
    done
}
open_kindle_firewall

# Stop any previous KHub helper server instance
for pid in $(ps -ef 2>/dev/null | grep -E "khub_server|khub_ip_watcher|khub_nc_server|httpd.*$PORT" | grep -v grep | awk '{print $2}'); do
    kill -9 "$pid" 2>/dev/null
done
for pid in $(ps 2>/dev/null | grep -E "khub_server|khub_ip_watcher|khub_nc_server|httpd.*$PORT" | grep -v grep | awk '{print $1}'); do
    kill -9 "$pid" 2>/dev/null
done

# Create Python server (if Python is available on the Kindle, handles POST /apps/install + CGI + RSS + OTA + all routes)
cat << 'EOF_PY' > /tmp/khub_server.py
#!/usr/bin/env python
import sys, os, shutil, json, subprocess, time

try:
    from BaseHTTPServer import BaseHTTPRequestHandler, HTTPServer
    from SocketServer import ThreadingMixIn
    from urlparse import urlparse, parse_qs, unquote
except ImportError:
    from http.server import BaseHTTPRequestHandler, HTTPServer
    from socketserver import ThreadingMixIn
    from urllib.parse import urlparse, parse_qs, unquote

class ThreadedHTTPServer(ThreadingMixIn, HTTPServer):
    allow_reuse_address = True
    daemon_threads = True

PERSIST_DIR = "/mnt/us/documents/khub"
TARGET_DIR = "/var/local/mesquite/KHub"
WWW_DIR = "/tmp/khub_www"
KEY_FILE = os.path.join(PERSIST_DIR, "api_key.txt")
TARGET_KEY_FILE = os.path.join(TARGET_DIR, "api_key.txt")
SETTINGS_FILE = os.path.join(PERSIST_DIR, "khub_settings.json")
TARGET_SETTINGS_FILE = os.path.join(TARGET_DIR, "khub_settings.json")
RSS_FILE = os.path.join(PERSIST_DIR, "rss_feeds.json")
TARGET_RSS_FILE = os.path.join(TARGET_DIR, "rss_feeds.json")
RSS_SEQ_FILE = os.path.join(PERSIST_DIR, "rss_seq.txt")
DEFAULT_RSS = "https://www.theguardian.com/us-news/rss"
REMOTE_ACTIVE = True
AUTO_STOPPED = False

def get_wifi_ip():
    env = os.environ.copy()
    env["PATH"] = "/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin:" + env.get("PATH", "")
    for cmd in [
        "lipc-get-prop com.lab126.wifid ipAddress 2>/dev/null",
        "ip -4 route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i==\"src\") {print $(i+1); exit}}'",
        "ip -4 addr show 2>/dev/null | awk '/inet / {print $2}' | cut -d/ -f1 | grep -v '^127\\.' | grep -v '^169\\.254\\.' | head -n 1",
        "ifconfig 2>/dev/null | awk '/inet addr:/{print substr($2,6)} /inet /{print $2}' | tr -d 'addr:' | grep -E '^[0-9]+\\.[0-9]+\\.[0-9]+\\.[0-9]+$' | grep -v '^127\\.' | grep -v '^169\\.254\\.' | head -n 1",
        "awk '/32 host LOCAL/ { print prev } { prev=$2 }' /proc/net/fib_trie 2>/dev/null | grep -E '^[0-9]+\\.[0-9]+\\.[0-9]+\\.[0-9]+$' | grep -v '^127\\.' | grep -v '^169\\.254\\.' | head -n 1"
    ]:
        try:
            out = subprocess.check_output(cmd, shell=True, env=env).decode("utf-8").strip()
            if out and out not in ("127.0.0.1", "0.0.0.0"):
                return out.split("\n")[0].strip()
        except Exception:
            pass
    return ""

def read_key():
    for p in [KEY_FILE, TARGET_KEY_FILE]:
        try:
            if os.path.exists(p):
                with open(p, "r") as f:
                    val = f.read().strip()
                    if val:
                        return val
        except Exception:
            pass
    return ""

def read_rss_feeds():
    for p in [RSS_FILE, TARGET_RSS_FILE, os.path.join(WWW_DIR, "rss_feeds.json")]:
        try:
            if os.path.exists(p):
                with open(p, "r") as f:
                    arr = json.load(f)
                    if isinstance(arr, list) and len(arr) > 0:
                        return [str(x).strip() for x in arr if str(x).strip()]
        except Exception:
            pass
    return [DEFAULT_RSS]

def read_rss_seq():
    for p in [RSS_SEQ_FILE, os.path.join(TARGET_DIR, "rss_seq.txt"), os.path.join(WWW_DIR, "rss_seq.txt")]:
        try:
            if os.path.exists(p):
                with open(p, "r") as f:
                    digits = "".join(c for c in f.read() if c.isdigit())
                    if digits:
                        return int(digits)
        except Exception:
            pass
    return 0

def write_rss_feeds(feeds_input, from_remote=False):
    global REMOTE_ACTIVE, AUTO_STOPPED
    if isinstance(feeds_input, list):
        raw_parts = feeds_input
    else:
        s = str(feeds_input or "")
        for sep in ["|", ",", "\n", "\r", ";"]:
            s = s.replace(sep, "\n")
        raw_parts = s.split("\n")

    clean = []
    for item in raw_parts:
        u = str(item or "").strip()
        if not u:
            continue
        if not (u.startswith("http://") or u.startswith("https://")):
            u = "https://" + u
        if u not in clean:
            clean.append(u)

    if DEFAULT_RSS not in clean:
        clean.insert(0, DEFAULT_RSS)

    seq = int(time.time())
    if from_remote:
        seq += 1
        REMOTE_ACTIVE = False
        AUTO_STOPPED = True

    raw_json = json.dumps(clean)
    raw_txt = "\n".join(clean) + "\n"
    for d in [PERSIST_DIR, TARGET_DIR, WWW_DIR]:
        try:
            if not os.path.exists(d):
                os.makedirs(d)
            with open(os.path.join(d, "rss_feeds.json"), "w") as f:
                f.write(raw_json)
            with open(os.path.join(d, "rss_feeds.txt"), "w") as f:
                f.write(raw_txt)
            with open(os.path.join(d, "rss_seq.txt"), "w") as f:
                f.write(str(seq))
        except Exception:
            pass
    sync_disk_state_js()
    return clean

def sync_disk_apps_index():
    apps_map = {}
    apps_root = os.path.join(PERSIST_DIR, "apps")
    if os.path.exists(apps_root):
        for entry in os.listdir(apps_root):
            app_dir = os.path.join(apps_root, entry)
            manifest_path = os.path.join(app_dir, "manifest.json")
            html_path = os.path.join(app_dir, "index.html")
            if os.path.isdir(app_dir) and os.path.exists(manifest_path):
                try:
                    with open(manifest_path, "r") as mf:
                        meta = json.load(mf)
                    if os.path.exists(html_path):
                        with open(html_path, "r") as hf:
                            meta["html"] = hf.read()
                    meta["diskPath"] = "/khub/apps/" + entry + "/index.html"
                    apps_map[entry] = meta
                except Exception:
                    pass
    js_str = "window.__khubDiskApps = " + json.dumps(apps_map) + ";\nif (window.onKhubDiskApps) { window.onKhubDiskApps(window.__khubDiskApps); }\n"
    for base in [PERSIST_DIR, TARGET_DIR]:
        try:
            adir = os.path.join(base, "apps")
            if not os.path.exists(adir):
                os.makedirs(adir)
            with open(os.path.join(adir, "installed_apps.js"), "w") as f:
                f.write(js_str)
        except Exception:
            pass
    return apps_map

def install_app_to_disk(app_obj):
    app_id = "".join(c for c in str(app_obj.get("id", "")) if c.isalnum() or c in ("-", "_"))
    if not app_id:
        return False
    html_code = str(app_obj.get("html", ""))
    manifest = {
        "id": app_id,
        "name": app_obj.get("name", app_id),
        "version": app_obj.get("version", "1.0"),
        "author": app_obj.get("author", "EthanDupe"),
        "requiresAi": bool(app_obj.get("requiresAi", False)),
        "description": app_obj.get("description", ""),
        "diskPath": "/khub/apps/" + app_id + "/index.html"
    }
    for base in [PERSIST_DIR, TARGET_DIR]:
        try:
            app_folder = os.path.join(base, "apps", app_id)
            if not os.path.exists(app_folder):
                os.makedirs(app_folder)
            with open(os.path.join(app_folder, "index.html"), "w") as hf:
                hf.write(html_code)
            with open(os.path.join(app_folder, "manifest.json"), "w") as mf:
                json.dump(manifest, mf, indent=2)
        except Exception:
            pass
    sync_disk_apps_index()
    return True

def uninstall_app_from_disk(app_id):
    clean_id = "".join(c for c in str(app_id or "") if c.isalnum() or c in ("-", "_"))
    if not clean_id:
        return False
    for base in [PERSIST_DIR, TARGET_DIR]:
        try:
            app_folder = os.path.join(base, "apps", clean_id)
            if os.path.exists(app_folder):
                shutil.rmtree(app_folder)
        except Exception:
            pass
    sync_disk_apps_index()
    return True

def get_battery_level():
    for cmd in [
        "lipc-get-prop com.lab126.powerd battLevel 2>/dev/null",
        "gasgauge-info -s 2>/dev/null",
        "cat /sys/class/power_supply/*bat*/capacity 2>/dev/null"
    ]:
        try:
            out = subprocess.check_output(cmd, shell=True).decode("utf-8").strip()
            digits = "".join(c for c in out if c.isdigit())
            if digits:
                return int(digits)
        except Exception:
            pass
    return 100

def read_tracking_id():
    for p in [os.path.join(PERSIST_DIR, "tracking_id.txt"), os.path.join(TARGET_DIR, "tracking_id.txt")]:
        try:
            if os.path.exists(p):
                with open(p, "r") as f:
                    val = "".join(c for c in f.read().strip() if c.isalnum() or c in ("-", "_"))
                    if val:
                        return val
        except Exception:
            pass
    return ""

def write_tracking_id(val):
    clean = "".join(c for c in str(val or "").strip() if c.isalnum() or c in ("-", "_"))
    if not clean:
        return
    for d in [PERSIST_DIR, TARGET_DIR, WWW_DIR]:
        try:
            if not os.path.exists(d):
                os.makedirs(d)
            with open(os.path.join(d, "tracking_id.txt"), "w") as f:
                f.write(clean)
        except Exception:
            pass

def sync_disk_state_js():
    ip_val = get_wifi_ip()
    key_val = read_key()
    tid_val = read_tracking_id()
    bat_val = get_battery_level()
    cfg = read_settings()
    rss_val = read_rss_feeds()
    rss_seq = read_rss_seq()
    state_obj = {
        "ok": True,
        "ip": ip_val,
        "port": 8088,
        "remoteActive": REMOTE_ACTIVE,
        "autoStopped": AUTO_STOPPED,
        "apiKey": key_val,
        "trackingId": tid_val,
        "batteryLevel": bat_val,
        "zoom": cfg.get("zoom", 100),
        "rssFeeds": rss_val,
        "rssUpdatedSeq": rss_seq
    }
    js_str = "window.__khubDiskState = " + json.dumps(state_obj) + "; if (window.onKhubDiskState) { window.onKhubDiskState(window.__khubDiskState); }\n"
    for d in [PERSIST_DIR, TARGET_DIR, WWW_DIR]:
        try:
            if not os.path.exists(d):
                os.makedirs(d)
            fname = "state.js" if d == WWW_DIR else "kindle_state.js"
            with open(os.path.join(d, fname), "w") as f:
                f.write(js_str)
        except Exception:
            pass

def write_key(val, from_remote=False):
    global REMOTE_ACTIVE, AUTO_STOPPED
    val = (val or "").strip()
    if from_remote:
        REMOTE_ACTIVE = False
        AUTO_STOPPED = True
    for d, p in [(PERSIST_DIR, KEY_FILE), (TARGET_DIR, TARGET_KEY_FILE), (WWW_DIR, os.path.join(WWW_DIR, "api_key.txt"))]:
        try:
            if not os.path.exists(d):
                os.makedirs(d)
            with open(p, "w") as f:
                f.write(val)
        except Exception:
            pass
    sync_disk_state_js()

def read_settings():
    for p in [SETTINGS_FILE, TARGET_SETTINGS_FILE]:
        try:
            if os.path.exists(p):
                with open(p, "r") as f:
                    return json.load(f)
        except Exception:
            pass
    return {"zoom": 100}

def write_settings(data):
    raw = json.dumps(data)
    for d, p in [(PERSIST_DIR, SETTINGS_FILE), (TARGET_DIR, TARGET_SETTINGS_FILE)]:
        try:
            if not os.path.exists(d):
                os.makedirs(d)
            with open(p, "w") as f:
                f.write(raw)
        except Exception:
            pass
    sync_disk_state_js()

def run_github_update():
    try:
        subprocess.call("/tmp/khub_www/cgi-bin/khub.cgi", shell=True, env={"QUERY_STRING": "action=update"})
        sync_disk_state_js()
        sync_disk_apps_index()
        return True
    except Exception:
        return False

def render_remote_html(banner_html=""):
    try:
        with open(os.path.join(WWW_DIR, "index.html"), "r") as f:
            page = f.read()
        if banner_html:
            page = page.replace('<div id="status-banner"></div>', '<div id="status-banner">' + banner_html + '</div>')
        return page
    except Exception:
        return "<html><body>Saved!</body></html>"

class Handler(BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        return

    def _headers(self, ctype="application/json"):
        self.send_response(200)
        self.send_header("Content-Type", ctype)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.send_header("Cache-Control", "no-store, no-cache, must-revalidate")
        self.end_headers()

    def do_OPTIONS(self):
        self._headers("text/plain")

    def _state_dict(self):
        cfg = read_settings()
        return {
            "ok": True,
            "ip": get_wifi_ip(),
            "port": 8088,
            "remoteActive": REMOTE_ACTIVE,
            "autoStopped": AUTO_STOPPED,
            "apiKey": read_key(),
            "trackingId": read_tracking_id(),
            "batteryLevel": get_battery_level(),
            "zoom": cfg.get("zoom", 100),
            "rssFeeds": read_rss_feeds(),
            "rssUpdatedSeq": read_rss_seq()
        }

    def do_GET(self):
        global REMOTE_ACTIVE, AUTO_STOPPED
        parsed = urlparse(self.path)
        qs = parse_qs(parsed.query)
        action = qs.get("action", [""])[0]

        if parsed.path == "/api_key.txt":
            self._headers("text/plain; charset=utf-8")
            self.wfile.write(read_key().encode("utf-8"))
            return

        if parsed.path in ("/rss_feeds.json", "/rss/list") or action == "rss_list":
            self._headers("application/json; charset=utf-8")
            self.wfile.write(json.dumps({"ok": True, "rssFeeds": read_rss_feeds(), "rssUpdatedSeq": read_rss_seq()}).encode("utf-8"))
            return

        if parsed.path in ("/status", "/state.js") or action == "status":
            st = self._state_dict()
            sync_disk_state_js()
            if parsed.path == "/state.js" or "jsonp" in qs:
                self._headers("application/javascript; charset=utf-8")
                js = "window.__khubDiskState = " + json.dumps(st) + "; if (window.onKhubDiskState) { window.onKhubDiskState(window.__khubDiskState); }"
                self.wfile.write(js.encode("utf-8"))
            else:
                self._headers("application/json")
                self.wfile.write(json.dumps(st).encode("utf-8"))
            return

        if parsed.path in ("/store_catalog", "/check_update") or action in ("store_catalog", "check_update", "cloud_status", "cloud_heartbeat"):
            try:
                out = subprocess.check_output("/tmp/khub_www/cgi-bin/khub.cgi", shell=True, env={"QUERY_STRING": parsed.query})
                body = out.split(b"\r\n\r\n", 1)[-1] if b"\r\n\r\n" in out else out
                self._headers("application/json; charset=utf-8")
                self.wfile.write(body)
                return
            except Exception:
                pass
            self._headers("application/json")
            self.wfile.write(json.dumps({"ok": False}).encode("utf-8"))
            return

        if parsed.path == "/apps/list" or action == "list":
            apps_map = sync_disk_apps_index()
            if "jsonp" in qs:
                self._headers("application/javascript; charset=utf-8")
                js = "window.__khubDiskApps = " + json.dumps(apps_map) + "; if (window.onKhubDiskApps) { window.onKhubDiskApps(window.__khubDiskApps); }"
                self.wfile.write(js.encode("utf-8"))
            else:
                self._headers("application/json")
                self.wfile.write(json.dumps({"ok": True, "apps": apps_map}).encode("utf-8"))
            return

        if parsed.path == "/apps/uninstall" or action == "uninstall":
            app_id = qs.get("id", [""])[0]
            uninstall_app_from_disk(app_id)
            apps_map = sync_disk_apps_index()
            if "jsonp" in qs:
                self._headers("application/javascript; charset=utf-8")
                js = "window.__khubDiskApps = " + json.dumps(apps_map) + "; if (window.onKhubDiskApps) { window.onKhubDiskApps(window.__khubDiskApps); }"
                self.wfile.write(js.encode("utf-8"))
            else:
                self._headers("application/json")
                self.wfile.write(json.dumps({"ok": True, "apps": apps_map}).encode("utf-8"))
            return

        if parsed.path in ("/server/start", "/server/stop") or action in ("start", "stop") or "/__KHUB_CMD__/" in parsed.path:
            if "stop" in parsed.path or action == "stop":
                REMOTE_ACTIVE = False
            else:
                REMOTE_ACTIVE = True
                AUTO_STOPPED = False
            st = self._state_dict()
            sync_disk_state_js()
            if "jsonp" in qs:
                self._headers("application/javascript; charset=utf-8")
                js = "window.__khubDiskState = " + json.dumps(st) + "; if (window.onKhubDiskState) { window.onKhubDiskState(window.__khubDiskState); }"
                self.wfile.write(js.encode("utf-8"))
            else:
                self._headers("application/json")
                self.wfile.write(json.dumps(st).encode("utf-8"))
            return

        if parsed.path in ("/update", "/reset_software") or action in ("update", "reset_software"):
            ok = run_github_update()
            if "jsonp" in qs:
                self._headers("application/javascript; charset=utf-8")
                self.wfile.write(("if(window.onKhubSystemUpdateDone)window.onKhubSystemUpdateDone(" + ("true" if ok else "false") + ");").encode("utf-8"))
            else:
                self._headers("application/json")
                self.wfile.write(json.dumps({"ok": ok}).encode("utf-8"))
            return

        if parsed.path == "/save_rss" or action == "save_rss" or "feeds" in qs:
            raw_feeds = qs.get("feeds", [""])[0]
            is_rem = (qs.get("from", [""])[0] == "remote")
            write_rss_feeds(unquote(raw_feeds), from_remote=is_rem)
            if is_rem:
                self._headers("text/html; charset=utf-8")
                banner = '<div class="msg">Success! Your Custom RSS Feeds have been saved to your Kindle and synced into KHub RSS Feed.</div>'
                self.wfile.write(render_remote_html(banner).encode("utf-8"))
                return
            st = self._state_dict()
            if "jsonp" in qs:
                self._headers("application/javascript; charset=utf-8")
                js = "window.__khubDiskState = " + json.dumps(st) + "; if (window.onKhubDiskState) { window.onKhubDiskState(window.__khubDiskState); }"
                self.wfile.write(js.encode("utf-8"))
            else:
                self._headers("application/json")
                self.wfile.write(json.dumps(st).encode("utf-8"))
            return

        if "trackingId" in qs and len(qs["trackingId"]) > 0:
            write_tracking_id(qs["trackingId"][0])
        if parsed.path == "/save" or action == "save" or "key" in qs or "clear" in qs or "zoom" in qs or "trackingId" in qs:
            is_rem = (qs.get("from", [""])[0] == "remote")
            if "key" in qs:
                k = qs["key"][0] if len(qs["key"]) > 0 else ""
                write_key(k, from_remote=is_rem)
            if "clear" in qs:
                write_key("", from_remote=False)
            if "zoom" in qs:
                try:
                    z = int(qs["zoom"][0])
                    cfg = read_settings()
                    cfg["zoom"] = z
                    write_settings(cfg)
                except Exception:
                    pass
            if is_rem:
                self._headers("text/html; charset=utf-8")
                banner = '<div class="msg">Saved! Your Kindle has received and permanently stored the Gemini API key.</div>'
                self.wfile.write(render_remote_html(banner).encode("utf-8"))
                return
            st = self._state_dict()
            if "jsonp" in qs:
                self._headers("application/javascript; charset=utf-8")
                js = "window.__khubDiskState = " + json.dumps(st) + "; if (window.onKhubDiskState) { window.onKhubDiskState(window.__khubDiskState); }"
                self.wfile.write(js.encode("utf-8"))
            else:
                self._headers("application/json")
                self.wfile.write(json.dumps(st).encode("utf-8"))
            return

        # Default GET / -> Remote API Key + RSS Feeds Web UI
        self._headers("text/html; charset=utf-8")
        self.wfile.write(render_remote_html("").encode("utf-8"))

    def do_POST(self):
        parsed = urlparse(self.path)
        qs_url = parse_qs(parsed.query)
        action = qs_url.get("action", [""])[0]
        length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(length).decode("utf-8") if length > 0 else ""

        if action == "write_file":
            target_name = qs_url.get("target", [""])[0]
            dirs = [PERSIST_DIR, TARGET_DIR]
            if os.path.exists("/mnt/us/documents/KHub"):
                dirs.append("/mnt/us/documents/KHub")
            wrote = False
            try:
                if target_name == "index.html" and "KHUB_CURRENT_VERSION" in body:
                    for base in dirs:
                        if not os.path.exists(base):
                            os.makedirs(base)
                        with open(os.path.join(base, "index.html"), "w") as f:
                            f.write(body)
                    wrote = True
                elif target_name == "config.xml" and "<widget" in body.lower():
                    for base in dirs:
                        if not os.path.exists(base):
                            os.makedirs(base)
                        with open(os.path.join(base, "config.xml"), "w") as f:
                            f.write(body)
                    wrote = True
                elif target_name == "khub.sh" and body.startswith("#!/bin/sh"):
                    with open("/mnt/us/documents/khub.sh", "w") as f:
                        f.write(body.replace("\r", ""))
                    os.chmod("/mnt/us/documents/khub.sh", 0o755)
                    wrote = True
                subprocess.call("rm -rf /var/local/mesquite/devkit/resource/appcache/* 2>/dev/null; sync", shell=True)
            except Exception:
                pass
            self._headers("application/json")
            self.wfile.write(json.dumps({"ok": wrote}).encode("utf-8"))
            return

        if parsed.path == "/cloud/heartbeat" or action == "cloud_heartbeat":
            try:
                with open("/tmp/khub_hb_in.json", "w") as f:
                    f.write(body)
                out = subprocess.check_output(
                    '/usr/bin/curl -k -sL --connect-timeout 10 -X POST -H "Content-Type: application/json" --data-binary @/tmp/khub_hb_in.json "https://khub-api.ethananaya351.workers.dev/heartbeat" 2>/dev/null || curl -k -sL --connect-timeout 10 -X POST -H "Content-Type: application/json" --data-binary @/tmp/khub_hb_in.json "https://khub-api.ethananaya351.workers.dev/heartbeat" 2>/dev/null',
                    shell=True
                )
                self._headers("application/json")
                self.wfile.write(out if out else json.dumps({"ok": True}).encode("utf-8"))
            except Exception:
                self._headers("application/json")
                self.wfile.write(json.dumps({"ok": True}).encode("utf-8"))
            return

        if parsed.path == "/apps/write_core" or "write_core" in parsed.query:
            try:
                payload = json.loads(body)
                dirs = [PERSIST_DIR, TARGET_DIR]
                if os.path.exists("/mnt/us/documents/KHub"):
                    dirs.append("/mnt/us/documents/KHub")
                if payload.get("indexHtml") and "KHUB_CURRENT_VERSION" in payload.get("indexHtml", ""):
                    for base in dirs:
                        if not os.path.exists(base):
                            os.makedirs(base)
                        with open(os.path.join(base, "index.html"), "w") as f:
                            f.write(payload["indexHtml"])
                if payload.get("configXml") and "<widget" in payload.get("configXml", "").lower():
                    for base in dirs:
                        if not os.path.exists(base):
                            os.makedirs(base)
                        with open(os.path.join(base, "config.xml"), "w") as f:
                            f.write(payload["configXml"])
                if payload.get("khubSh") and payload.get("khubSh", "").startswith("#!/bin/sh"):
                    with open("/mnt/us/documents/khub.sh", "w") as f:
                        f.write(payload["khubSh"].replace("\r", ""))
                    os.chmod("/mnt/us/documents/khub.sh", 0o755)
                try:
                    subprocess.call("rm -rf /var/local/mesquite/devkit/resource/appcache/* 2>/dev/null; sync", shell=True)
                except Exception:
                    pass
                self._headers("application/json")
                self.wfile.write(json.dumps({"ok": True}).encode("utf-8"))
            except Exception as e:
                self._headers("application/json")
                self.wfile.write(json.dumps({"ok": False, "error": str(e)}).encode("utf-8"))
            return

        if parsed.path == "/apps/install" or "install" in parsed.query:
            try:
                app_obj = json.loads(body)
                install_app_to_disk(app_obj)
                self._headers("application/json")
                self.wfile.write(json.dumps({"ok": True, "path": "/khub/apps/" + str(app_obj.get("id", ""))}).encode("utf-8"))
            except Exception as e:
                self._headers("application/json")
                self.wfile.write(json.dumps({"ok": False, "error": str(e)}).encode("utf-8"))
            return

        if parsed.path == "/rss/save" or action == "save_rss":
            try:
                data = json.loads(body)
                feeds = write_rss_feeds(data.get("feeds", []), from_remote=bool(data.get("fromRemote", False)))
                self._headers("application/json")
                self.wfile.write(json.dumps({"ok": True, "rssFeeds": feeds}).encode("utf-8"))
                return
            except Exception:
                pass

        qs = parse_qs(body)
        if "key" in qs:
            write_key(qs["key"][0], from_remote=True)
        if "feeds" in qs:
            write_rss_feeds(qs["feeds"][0], from_remote=True)
        self._headers("text/html; charset=utf-8")
        banner = '<div class="msg">Saved! Your Kindle has received and permanently stored your changes.</div>'
        self.wfile.write(render_remote_html(banner).encode("utf-8"))

if __name__ == "__main__":
    sync_disk_state_js()
    sync_disk_apps_index()
    server = ThreadedHTTPServer(("0.0.0.0", 8088), Handler)
    server.serve_forever()
EOF_PY
chmod +x /tmp/khub_server.py

# Create two-way FIFO netcat (nc) fallback server in case neither Python nor BusyBox httpd is present
cat << 'EOF_NC' > /tmp/khub_nc_server.sh
#!/bin/sh
export PATH="/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin:$PATH"
PORT=8088
WWW_DIR="/tmp/khub_www"
FIFO="/tmp/khub_nc_fifo"
while true; do
    rm -f "$FIFO" 2>/dev/null
    mkfifo "$FIFO" 2>/dev/null
    (
        read -r REQ_LINE
        REQ_METHOD="$(printf "%s" "$REQ_LINE" | awk '{print $1}')"
        REQ_PATH="$(printf "%s" "$REQ_LINE" | awk '{print $2}')"
        while read -r HDR; do
            HDR="$(printf "%s" "$HDR" | tr -d '\r\n')"
            [ -z "$HDR" ] && break
        done
        case "$REQ_PATH" in
            /api_key.txt*)
                printf "HTTP/1.1 200 OK\r\nContent-Type: text/plain; charset=utf-8\r\nCache-Control: no-store\r\nAccess-Control-Allow-Origin: *\r\nConnection: close\r\n\r\n"
                cat "$WWW_DIR/api_key.txt" 2>/dev/null
                ;;
            /rss_feeds.json*)
                printf "HTTP/1.1 200 OK\r\nContent-Type: application/json; charset=utf-8\r\nCache-Control: no-store\r\nAccess-Control-Allow-Origin: *\r\nConnection: close\r\n\r\n"
                cat "$WWW_DIR/rss_feeds.json" 2>/dev/null
                ;;
            /state.js*)
                printf "HTTP/1.1 200 OK\r\nContent-Type: application/javascript; charset=utf-8\r\nCache-Control: no-store\r\nAccess-Control-Allow-Origin: *\r\nConnection: close\r\n\r\n"
                cat "$WWW_DIR/state.js" 2>/dev/null
                ;;
            /cgi-bin/khub.cgi*|/save*|/status*|/update*|/reset_software*|/store_catalog*|/check_update*)
                QS="$(printf "%s" "$REQ_PATH" | cut -s -d? -f2-)"
                printf "HTTP/1.1 200 OK\r\nConnection: close\r\n"
                REQUEST_METHOD="$REQ_METHOD" QUERY_STRING="$QS" /bin/sh "$WWW_DIR/cgi-bin/khub.cgi"
                ;;
            *)
                printf "HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nCache-Control: no-store\r\nConnection: close\r\n\r\n"
                cat "$WWW_DIR/index.html" 2>/dev/null
                ;;
        esac
    ) < "$FIFO" | nc -l -p $PORT > "$FIFO" 2>/dev/null || sleep 1
done
EOF_NC
chmod +x /tmp/khub_nc_server.sh

# Helper to start the best available web server on Port 8088
start_khub_webserver() {
    if command -v python3 >/dev/null 2>&1; then
        nohup python3 /tmp/khub_server.py >/dev/null 2>&1 &
    elif command -v python >/dev/null 2>&1; then
        nohup python /tmp/khub_server.py >/dev/null 2>&1 &
    elif command -v httpd >/dev/null 2>&1; then
        nohup httpd -f -p 0.0.0.0:$PORT -h "$WWW_DIR" >/dev/null 2>&1 &
    elif busybox --list 2>/dev/null | grep -qx "httpd"; then
        nohup busybox httpd -f -p 0.0.0.0:$PORT -h "$WWW_DIR" >/dev/null 2>&1 &
    else
        nohup /tmp/khub_nc_server.sh >/dev/null 2>&1 &
    fi
}

start_khub_webserver

# Background watcher that keeps kindle_state.js updated, firewall port 8088 open, and web server alive every 3s
cat << 'EOF_WATCH' > /tmp/khub_ip_watcher.sh
#!/bin/sh
export PATH="/mnt/us/python3/bin:/mnt/us/python/bin:/mnt/us/usbnet/bin:/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin:$PATH"
PERSIST_DIR="/mnt/us/documents/khub"
TARGET_DIR="/var/local/mesquite/KHub"
WWW_DIR="/tmp/khub_www"
PORT=8088
DEFAULT_RSS="https://www.theguardian.com/us-news/rss"

get_ip() {
    IP=""
    if command -v lipc-get-prop >/dev/null 2>&1; then
        IP="$(lipc-get-prop com.lab126.wifid ipAddress 2>/dev/null | tr -d ' \r\n')"
    fi
    if [ -z "$IP" ] || [ "$IP" = "127.0.0.1" ] || [ "$IP" = "0.0.0.0" ]; then
        IP="$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="src") {print $(i+1); exit}}')"
    fi
    if [ -z "$IP" ] || [ "$IP" = "127.0.0.1" ] || [ "$IP" = "0.0.0.0" ]; then
        IP="$(ip -4 addr show 2>/dev/null | awk '/inet / {print $2}' | cut -d/ -f1 | grep -v '^127\.' | grep -v '^169\.254\.' | head -n 1)"
    fi
    if [ -z "$IP" ] || [ "$IP" = "127.0.0.1" ] || [ "$IP" = "0.0.0.0" ]; then
        IP="$(ifconfig 2>/dev/null | awk '/inet addr:/{print substr($2,6)} /inet /{print $2}' | tr -d 'addr:' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | grep -v '^127\.' | grep -v '^169\.254\.' | head -n 1)"
    fi
    if [ -z "$IP" ] || [ "$IP" = "127.0.0.1" ] || [ "$IP" = "0.0.0.0" ]; then
        IP="$(awk '/32 host LOCAL/ { print prev } { prev=$2 }' /proc/net/fib_trie 2>/dev/null | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | grep -v '^127\.' | grep -v '^169\.254\.' | head -n 1)"
    fi
    printf "%s" "$IP"
}

LAST_STATE=""
while true; do
    # Keep firewall port 8088 open even if wifid resets iptables on Wi-Fi reconnect
    for ipt in iptables /usr/sbin/iptables /sbin/iptables; do
        if command -v "$ipt" >/dev/null 2>&1 || [ -x "$ipt" ]; then
            "$ipt" -C INPUT -p tcp --dport $PORT -j ACCEPT 2>/dev/null || "$ipt" -I INPUT 1 -p tcp --dport $PORT -j ACCEPT 2>/dev/null
            break
        fi
    done

    # Keep web server alive
    if ! netstat -tlpn 2>/dev/null | grep -q ":$PORT " && ! netstat -tln 2>/dev/null | grep -q ":$PORT "; then
        if command -v python3 >/dev/null 2>&1; then
            nohup python3 /tmp/khub_server.py >/dev/null 2>&1 &
        elif command -v python >/dev/null 2>&1; then
            nohup python /tmp/khub_server.py >/dev/null 2>&1 &
        elif command -v httpd >/dev/null 2>&1; then
            nohup httpd -f -p 0.0.0.0:$PORT -h "$WWW_DIR" >/dev/null 2>&1 &
        elif busybox --list 2>/dev/null | grep -qx "httpd"; then
            nohup busybox httpd -f -p 0.0.0.0:$PORT -h "$WWW_DIR" >/dev/null 2>&1 &
        fi
    fi

    CUR_IP="$(get_ip)"
    CUR_BAT=""
    if command -v lipc-get-prop >/dev/null 2>&1; then
        CUR_BAT="$(lipc-get-prop com.lab126.powerd battLevel 2>/dev/null | tr -cd '0-9')"
    fi
    if [ -z "$CUR_BAT" ] && command -v gasgauge-info >/dev/null 2>&1; then
        CUR_BAT="$(gasgauge-info -s 2>/dev/null | tr -cd '0-9')"
    fi
    if [ -z "$CUR_BAT" ]; then
        for cap in /sys/class/power_supply/*bat*/capacity /sys/class/power_supply/*/capacity; do
            if [ -f "$cap" ]; then
                CUR_BAT="$(cat "$cap" 2>/dev/null | tr -cd '0-9')"
                [ -n "$CUR_BAT" ] && break
            fi
        done
    fi
    [ -z "$CUR_BAT" ] && CUR_BAT="100"
    CUR_KEY=""
    if [ -f "$PERSIST_DIR/api_key.txt" ]; then
        CUR_KEY="$(cat "$PERSIST_DIR/api_key.txt" 2>/dev/null)"
    elif [ -f "$TARGET_DIR/api_key.txt" ]; then
        CUR_KEY="$(cat "$TARGET_DIR/api_key.txt" 2>/dev/null)"
    fi
    CUR_TID=""
    if [ -f "$PERSIST_DIR/tracking_id.txt" ]; then
        CUR_TID="$(cat "$PERSIST_DIR/tracking_id.txt" 2>/dev/null | tr -cd 'A-Za-z0-9_-')"
    elif [ -f "$TARGET_DIR/tracking_id.txt" ]; then
        CUR_TID="$(cat "$TARGET_DIR/tracking_id.txt" 2>/dev/null | tr -cd 'A-Za-z0-9_-')"
    fi
    CUR_RSS="[\"$DEFAULT_RSS\"]"
    if [ -f "$PERSIST_DIR/rss_feeds.json" ]; then
        TMP_R="$(cat "$PERSIST_DIR/rss_feeds.json" 2>/dev/null | tr -d '\r\n')"
        [ -n "$TMP_R" ] && CUR_RSS="$TMP_R"
    fi
    CUR_SEQ="0"
    if [ -f "$PERSIST_DIR/rss_seq.txt" ]; then
        TMP_S="$(cat "$PERSIST_DIR/rss_seq.txt" 2>/dev/null | tr -cd '0-9')"
        [ -n "$TMP_S" ] && CUR_SEQ="$TMP_S"
    fi
    ESC_KEY="$(printf "%s" "$CUR_KEY" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr -d '\r\n')"
    NEW_STATE="${CUR_IP}|${ESC_KEY}|${CUR_TID}|${CUR_BAT}|${CUR_RSS}|${CUR_SEQ}"
    if [ "$NEW_STATE" != "$LAST_STATE" ]; then
        LAST_STATE="$NEW_STATE"
        JS_CONTENT="window.__khubDiskState = {\"ok\":true,\"ip\":\"$CUR_IP\",\"port\":$PORT,\"remoteActive\":true,\"apiKey\":\"$ESC_KEY\",\"trackingId\":\"$CUR_TID\",\"batteryLevel\":$CUR_BAT,\"rssFeeds\":$CUR_RSS,\"rssUpdatedSeq\":$CUR_SEQ}; if (window.onKhubDiskState) { window.onKhubDiskState(window.__khubDiskState); }"
        printf "%s\n" "$JS_CONTENT" > "$TARGET_DIR/kindle_state.js" 2>/dev/null
        printf "%s\n" "$JS_CONTENT" > "$PERSIST_DIR/kindle_state.js" 2>/dev/null
        if [ -d "$WWW_DIR" ]; then
            printf "%s\n" "$JS_CONTENT" > "$WWW_DIR/state.js" 2>/dev/null
            printf "%s" "$CUR_KEY" > "$WWW_DIR/api_key.txt" 2>/dev/null
            printf "%s" "$CUR_RSS" > "$WWW_DIR/rss_feeds.json" 2>/dev/null
        fi
    fi
    sleep 3
done
EOF_WATCH
chmod +x /tmp/khub_ip_watcher.sh
nohup /tmp/khub_ip_watcher.sh >/dev/null 2>&1 &

# Redeclare to appreg.db
sqlite3 "$DB" <<EOF
INSERT OR IGNORE INTO interfaces(interface) VALUES('application');

INSERT OR IGNORE INTO handlerIds(handlerId) VALUES('$APP_ID');

INSERT OR REPLACE INTO properties(handlerId,name,value)
  VALUES('$APP_ID','lipcId','$APP_ID');
INSERT OR REPLACE INTO properties(handlerId,name,value)
  VALUES('$APP_ID','command','/usr/bin/mesquite -l $APP_ID -c file://$TARGET_DIR/');
INSERT OR REPLACE INTO properties(handlerId,name,value)
  VALUES('$APP_ID','supportedOrientation','U');
EOF

echo Registered $APP_ID v2.5, you may now launch it with LIPC.
sleep 2

# Launch with LIPC
nohup lipc-set-prop com.lab126.appmgrd start app://$APP_ID >/dev/null 2>&1 &
