#!/bin/sh
# Name: KHub
# Author: EthanDupe
# DontUseFBInk

export PATH="/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin:$PATH"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -d "/mnt/us/documents/khub" ]; then
    SOURCE_DIR="/mnt/us/documents/khub"
elif [ -d "/mnt/us/documents/KHub" ]; then
    SOURCE_DIR="/mnt/us/documents/KHub"
elif [ -d "$SCRIPT_DIR/khub" ]; then
    SOURCE_DIR="$SCRIPT_DIR/khub"
else
    SOURCE_DIR="/mnt/us/documents/khub"
fi

PERSIST_DIR="/mnt/us/documents/khub"
TARGET_DIR="/var/local/mesquite/KHub"
DB="/var/local/appreg.db"
APP_ID="xyz.ethandupe.khub"
PORT=8088
REPO_BASE="https://ethandupe.github.io/KindleHub"

mkdir -p "$PERSIST_DIR/apps"

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

# Preserve existing permanent API key, settings, and /khub/apps before copying
SAVED_KEY=""
if [ -f "$PERSIST_DIR/api_key.txt" ]; then
    SAVED_KEY="$(cat "$PERSIST_DIR/api_key.txt")"
elif [ -f "$TARGET_DIR/api_key.txt" ]; then
    SAVED_KEY="$(cat "$TARGET_DIR/api_key.txt")"
fi

SAVED_SETTINGS=""
if [ -f "$PERSIST_DIR/khub_settings.json" ]; then
    SAVED_SETTINGS="$(cat "$PERSIST_DIR/khub_settings.json")"
elif [ -f "$TARGET_DIR/khub_settings.json" ]; then
    SAVED_SETTINGS="$(cat "$TARGET_DIR/khub_settings.json")"
fi

if [ -d "$TARGET_DIR/apps" ]; then
    cp -rn "$TARGET_DIR/apps/"* "$PERSIST_DIR/apps/" 2>/dev/null
fi

# Copy to /var/local/mesquite
if [ -d "$SOURCE_DIR" ]; then
    if [ -d "$TARGET_DIR" ]; then
        rm -rf "$TARGET_DIR"
    fi
    cp -r "$SOURCE_DIR" "$TARGET_DIR"
    mkdir -p "$TARGET_DIR/apps"
else
    exit 1
fi

# Restore permanent API key, settings, and downloaded /khub/apps to both directories
if [ -n "$SAVED_KEY" ]; then
    printf "%s" "$SAVED_KEY" > "$PERSIST_DIR/api_key.txt"
    printf "%s" "$SAVED_KEY" > "$TARGET_DIR/api_key.txt"
fi
if [ -n "$SAVED_SETTINGS" ]; then
    printf "%s" "$SAVED_SETTINGS" > "$PERSIST_DIR/khub_settings.json"
    printf "%s" "$SAVED_SETTINGS" > "$TARGET_DIR/khub_settings.json"
fi
if [ ! -f "$PERSIST_DIR/apps/installed_apps.js" ]; then
    printf "window.__khubDiskApps = {};\n" > "$PERSIST_DIR/apps/installed_apps.js"
fi
cp -r "$PERSIST_DIR/apps/"* "$TARGET_DIR/apps/" 2>/dev/null

# Write initial kindle_state.js with detected Kindle IP and API key
CURRENT_IP="$(detect_kindle_ip)"
ESC_KEY="$(printf "%s" "$SAVED_KEY" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr -d '\r\n')"
cat << EOF_STATE > "$TARGET_DIR/kindle_state.js"
window.__khubDiskState = {"ok":true,"ip":"$CURRENT_IP","port":$PORT,"apiKey":"$ESC_KEY"};
if (window.onKhubDiskState) { window.onKhubDiskState(window.__khubDiskState); }
EOF_STATE
cp "$TARGET_DIR/kindle_state.js" "$PERSIST_DIR/kindle_state.js" 2>/dev/null

# Open port 8088 on Kindle firewall
iptables -C INPUT -p tcp --dport $PORT -j ACCEPT 2>/dev/null || iptables -I INPUT -p tcp --dport $PORT -j ACCEPT 2>/dev/null

# Stop any previous KHub helper server instance
for pid in $(ps -ef 2>/dev/null | grep "khub_server" | grep -v grep | awk '{print $2}'); do
    kill -9 "$pid" 2>/dev/null
done
for pid in $(ps 2>/dev/null | grep "khub_server" | grep -v grep | awk '{print $1}'); do
    kill -9 "$pid" 2>/dev/null
done
for pid in $(ps -ef 2>/dev/null | grep "httpd.*$PORT" | grep -v grep | awk '{print $2}'); do
    kill -9 "$pid" 2>/dev/null
done
for pid in $(ps 2>/dev/null | grep "httpd.*$PORT" | grep -v grep | awk '{print $1}'); do
    kill -9 "$pid" 2>/dev/null
done
for pid in $(ps -ef 2>/dev/null | grep "khub_ip_watcher" | grep -v grep | awk '{print $2}'); do
    kill -9 "$pid" 2>/dev/null
done

# Background watcher that keeps kindle_state.js updated with current Wi-Fi IP and API key every 3s
cat << 'EOF_WATCH' > /tmp/khub_ip_watcher.sh
#!/bin/sh
export PATH="/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin:$PATH"
PERSIST_DIR="/mnt/us/documents/khub"
TARGET_DIR="/var/local/mesquite/KHub"
PORT=8088

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
    CUR_IP="$(get_ip)"
    CUR_KEY=""
    if [ -f "$PERSIST_DIR/api_key.txt" ]; then
        CUR_KEY="$(cat "$PERSIST_DIR/api_key.txt" 2>/dev/null)"
    elif [ -f "$TARGET_DIR/api_key.txt" ]; then
        CUR_KEY="$(cat "$TARGET_DIR/api_key.txt" 2>/dev/null)"
    fi
    ESC_KEY="$(printf "%s" "$CUR_KEY" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr -d '\r\n')"
    NEW_STATE="${CUR_IP}|${ESC_KEY}"
    if [ "$NEW_STATE" != "$LAST_STATE" ]; then
        LAST_STATE="$NEW_STATE"
        JS_CONTENT="window.__khubDiskState = {\"ok\":true,\"ip\":\"$CUR_IP\",\"port\":$PORT,\"apiKey\":\"$ESC_KEY\"}; if (window.onKhubDiskState) { window.onKhubDiskState(window.__khubDiskState); }"
        printf "%s\n" "$JS_CONTENT" > "$TARGET_DIR/kindle_state.js" 2>/dev/null
        printf "%s\n" "$JS_CONTENT" > "$PERSIST_DIR/kindle_state.js" 2>/dev/null
        if [ -d "/tmp/khub_www" ]; then
            printf "%s\n" "$JS_CONTENT" > "/tmp/khub_www/state.js" 2>/dev/null
        fi
    fi
    sleep 3
done
EOF_WATCH
chmod +x /tmp/khub_ip_watcher.sh
nohup /tmp/khub_ip_watcher.sh >/dev/null 2>&1 &

# Create local helper server (handles Remote API Key web form, /khub/apps/<id>/ disk downloads, netcheck, and GitHub updates)
cat << 'EOF_PY' > /tmp/khub_server.py
#!/usr/bin/env python
import sys, os, shutil, json, subprocess

try:
    from BaseHTTPServer import BaseHTTPRequestHandler, HTTPServer
    from urlparse import urlparse, parse_qs
except ImportError:
    from http.server import BaseHTTPRequestHandler, HTTPServer
    from urllib.parse import urlparse, parse_qs

PERSIST_DIR = "/mnt/us/documents/khub"
TARGET_DIR = "/var/local/mesquite/KHub"
KEY_FILE = os.path.join(PERSIST_DIR, "api_key.txt")
TARGET_KEY_FILE = os.path.join(TARGET_DIR, "api_key.txt")
SETTINGS_FILE = os.path.join(PERSIST_DIR, "khub_settings.json")
TARGET_SETTINGS_FILE = os.path.join(TARGET_DIR, "khub_settings.json")
REMOTE_ACTIVE = True

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

def sync_disk_state_js():
    ip_val = get_wifi_ip()
    key_val = read_key()
    cfg = read_settings()
    state_obj = {
        "ok": True,
        "ip": ip_val,
        "port": 8088,
        "remoteActive": REMOTE_ACTIVE,
        "apiKey": key_val,
        "zoom": cfg.get("zoom", 100)
    }
    js_str = "window.__khubDiskState = " + json.dumps(state_obj) + "; if (window.onKhubDiskState) { window.onKhubDiskState(window.__khubDiskState); }\n"
    for d in [PERSIST_DIR, TARGET_DIR]:
        try:
            if not os.path.exists(d):
                os.makedirs(d)
            with open(os.path.join(d, "kindle_state.js"), "w") as f:
                f.write(js_str)
        except Exception:
            pass

def write_key(val):
    val = (val or "").strip()
    for d, p in [(PERSIST_DIR, KEY_FILE), (TARGET_DIR, TARGET_KEY_FILE)]:
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
    repo = "https://ethandupe.github.io/KindleHub"
    cmds = [
        "mkdir -p /mnt/us/documents/khub/apps /var/local/mesquite/KHub/apps",
        " (wget -q -O /tmp/khub_index.html '" + repo + "/khub/index.html' || wget -q -O /tmp/khub_index.html '" + repo + "/index.html' || curl -sL '" + repo + "/khub/index.html' -o /tmp/khub_index.html || curl -sL '" + repo + "/index.html' -o /tmp/khub_index.html) ",
        "if [ -s /tmp/khub_index.html ]; then cp /tmp/khub_index.html /mnt/us/documents/khub/index.html && cp /tmp/khub_index.html /var/local/mesquite/KHub/index.html; fi",
        " (wget -q -O /tmp/khub_config.xml '" + repo + "/khub/config.xml' || wget -q -O /tmp/khub_config.xml '" + repo + "/config.xml' || curl -sL '" + repo + "/khub/config.xml' -o /tmp/khub_config.xml || curl -sL '" + repo + "/config.xml' -o /tmp/khub_config.xml) ",
        "if [ -s /tmp/khub_config.xml ]; then cp /tmp/khub_config.xml /mnt/us/documents/khub/config.xml && cp /tmp/khub_config.xml /var/local/mesquite/KHub/config.xml; fi",
        " (wget -q -O /tmp/khub_new.sh '" + repo + "/khub.sh' || curl -sL '" + repo + "/khub.sh' -o /tmp/khub_new.sh) ",
        "if [ -s /tmp/khub_new.sh ]; then cp /tmp/khub_new.sh /mnt/us/documents/khub.sh && chmod +x /mnt/us/documents/khub.sh; fi"
    ]
    try:
        subprocess.call(" && ".join(cmds), shell=True)
        sync_disk_state_js()
        sync_disk_apps_index()
        return True
    except Exception:
        return False

REMOTE_HTML = '''<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>KHub - Enter AI API Key</title>
<style>
body { font-family: sans-serif; background: #fff; color: #000; text-align: center; padding: 24px; margin: 0; }
.box { max-width: 460px; margin: 20px auto; border: 4px solid #000; padding: 20px; text-align: left; }
h1 { margin: 0 0 8px 0; font-size: 28px; }
p { font-size: 16px; line-height: 1.4; }
input[type=text] { width: 100%; box-sizing: border-box; font-size: 18px; padding: 12px; border: 3px solid #000; margin: 10px 0 16px 0; }
button { width: 100%; font-size: 20px; font-weight: bold; padding: 14px; background: #000; color: #fff; border: 3px solid #000; cursor: pointer; }
.msg { margin-top: 14px; padding: 10px; border: 2px solid #000; font-weight: bold; display: none; }
</style>
</head>
<body>
<div class="box">
  <h1>KHUB API KEY SETUP</h1>
  <p>Paste your Gemini API Key below to save it permanently on your Kindle.</p>
  <form method="GET" action="/save">
    <label><strong>Gemini API Key:</strong></label>
    <input type="text" name="key" placeholder="Paste API key here..." value="__CURRENT_KEY__" required autocomplete="off">
    <input type="hidden" name="from" value="remote">
    <button type="submit">Save API Key to Kindle</button>
  </form>
  __SAVED_BANNER__
</div>
</body>
</html>'''

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
            "apiKey": read_key(),
            "zoom": cfg.get("zoom", 100)
        }

    def do_GET(self):
        global REMOTE_ACTIVE
        parsed = urlparse(self.path)
        qs = parse_qs(parsed.query)

        if parsed.path in ("/status", "/state.js"):
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

        if parsed.path == "/apps/list":
            apps_map = sync_disk_apps_index()
            if "jsonp" in qs:
                self._headers("application/javascript; charset=utf-8")
                js = "window.__khubDiskApps = " + json.dumps(apps_map) + "; if (window.onKhubDiskApps) { window.onKhubDiskApps(window.__khubDiskApps); }"
                self.wfile.write(js.encode("utf-8"))
            else:
                self._headers("application/json")
                self.wfile.write(json.dumps({"ok": True, "apps": apps_map}).encode("utf-8"))
            return

        if parsed.path == "/apps/uninstall":
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

        if parsed.path in ("/server/start", "/server/stop"):
            REMOTE_ACTIVE = (parsed.path == "/server/start")
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

        if parsed.path == "/save":
            if "key" in qs:
                k = qs["key"][0] if len(qs["key"]) > 0 else ""
                write_key(k)
            if "clear" in qs:
                write_key("")
            if "zoom" in qs:
                try:
                    z = int(qs["zoom"][0])
                    cfg = read_settings()
                    cfg["zoom"] = z
                    write_settings(cfg)
                except Exception:
                    pass
            if qs.get("from", [""])[0] == "remote":
                self._headers("text/html; charset=utf-8")
                banner = '<div class="msg" style="display:block;">Saved! Your Kindle has received and permanently stored the API key.</div>'
                page = REMOTE_HTML.replace("__CURRENT_KEY__", read_key()).replace("__SAVED_BANNER__", banner)
                self.wfile.write(page.encode("utf-8"))
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

        if parsed.path == "/update":
            ok = run_github_update()
            if "jsonp" in qs:
                self._headers("application/javascript; charset=utf-8")
                self.wfile.write(("if(window.onKhubSystemUpdateDone)window.onKhubSystemUpdateDone(" + ("true" if ok else "false") + ");").encode("utf-8"))
            else:
                self._headers("application/json")
                self.wfile.write(json.dumps({"ok": ok}).encode("utf-8"))
            return

        # Default GET / -> Remote API Key Web UI
        self._headers("text/html; charset=utf-8")
        if not REMOTE_ACTIVE:
            self.wfile.write(b"<html><body style='font-family:sans-serif;text-align:center;padding:30px;'><h2>KHub Remote Key Server is Paused</h2><p>Tap 'Use Phone/PC' in KHub Settings on your Kindle first.</p></body></html>")
            return
        page = REMOTE_HTML.replace("__CURRENT_KEY__", read_key()).replace("__SAVED_BANNER__", "")
        self.wfile.write(page.encode("utf-8"))

    def do_POST(self):
        parsed = urlparse(self.path)
        length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(length).decode("utf-8") if length > 0 else ""

        if parsed.path == "/apps/install":
            try:
                app_obj = json.loads(body)
                install_app_to_disk(app_obj)
                self._headers("application/json")
                self.wfile.write(json.dumps({"ok": True, "path": "/khub/apps/" + str(app_obj.get("id", ""))}).encode("utf-8"))
            except Exception as e:
                self._headers("application/json")
                self.wfile.write(json.dumps({"ok": False, "error": str(e)}).encode("utf-8"))
            return

        qs = parse_qs(body)
        if "key" in qs:
            write_key(qs["key"][0])
        self._headers("text/html; charset=utf-8")
        banner = '<div class="msg" style="display:block;">Saved! Your Kindle has received and permanently stored the API key.</div>'
        page = REMOTE_HTML.replace("__CURRENT_KEY__", read_key()).replace("__SAVED_BANNER__", banner)
        self.wfile.write(page.encode("utf-8"))

if __name__ == "__main__":
    sync_disk_state_js()
    sync_disk_apps_index()
    server = HTTPServer(("0.0.0.0", 8088), Handler)
    server.serve_forever()
EOF_PY
chmod +x /tmp/khub_server.py

if command -v python3 >/dev/null 2>&1; then
    nohup python3 /tmp/khub_server.py >/dev/null 2>&1 &
elif command -v python >/dev/null 2>&1; then
    nohup python /tmp/khub_server.py >/dev/null 2>&1 &
fi

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

echo Registered $APP_ID, you may now launch it with LIPC.
sleep 2

# Launch with LIPC
nohup lipc-set-prop com.lab126.appmgrd start app://$APP_ID >/dev/null 2>&1 &
