#!/bin/sh
# Name: KHub
# Author: EthanDupe
# DontUseFBInk
# Icon: data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAIwAAADSAgMAAADlKsAqAAAADFBMVEX////Hx8c6OjoAAACMFR/OAAAC2klEQVR42u3ZT2jTUBwH8JeW7eGK9LKDYEsuO9Sx6cmLdDayQ/GgiAcRbFadMATBtSNdd9C+KEgYBWGgq4cJGzsoTvSoA7HBHYpeDA42xEsHlV528BCwSpMsr3/ckpc2E0ql8N6x+fB731/ea5M0AHRxeA23IXfO/HQJ4++kibRNU6WGGlejA6SD40VoVBhDZA3ZpwPQlydMBUxbDWAJU2QMm4GEEaHdeOwmY5a2GFQkzBxANqMydnPd/MRmiDo4odtcuNOiGbRdXyBCmFOHqONzzGM1RJ5LB/sS/WbmErAbYf/8+OumCvI2c+/veZZ9Bsc6GsQ110vx/AZsbS7CKM11x8kjODORB6nN/aOaR/OOfSGtuQ91fNR5/xhcf90YP5hpbPre0O8yNd0z4baX5TA1hzap8kQALShI9EcrSAyOfpUqhElL8VhqRREAK/EpBRueMBk4sSSkzDrDBdOwmlOdTJTfNY0ATm835iLrzEr8+9pcqMwJIDi66WCE53wYLehIXH6LzUgmWun9tWhzP/tPpsd7rwK/a+8tzYH79TDwH3j4oKZnzS9JRefWjeyOhu5i8wFK2fhWyWL+FEIz9x8GgqnPCVyHUQYKX2L9gxaj5VTEvQiETlQRNp7shdxa/OOyxRhlkGDO79fZjJfTsb4hi6mkTbMe8O0UGnlupb32PHRNqWllOvVbR+9t6LWJmv9t5hK+nY2JSBEbdG2xBC9qq/N3xi3mVSLIbNyGtTozT68Mwkfy1LMbVvMtEWKM2WjNoIEHy/B1dXZp2DIXo+M6eale5/GTIXhWHnt32VLHI+E8K9s1k/xu5jmpjQi2PHRNqaHXJmqcDSO2NiyX50yhJU0DS45mdZyDwKMwsq5l2O3gZHyxSJgpL3cEm2ryEwzkjk7G1lTCnPFyAZxGTs6jq7ngTf4lOdcouxvCRhvDpoTiW6pr78foujdMp/6L6+K7ti6+Q+zi2AOH9xdpyqDNcgAAAABJRU5ErkJggg==

export PATH="/mnt/us/python3/bin:/mnt/us/python/bin:/mnt/us/usbnet/bin:/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin:$PATH"

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
WWW_DIR="/tmp/khub_www"
DB="/var/local/appreg.db"
APP_ID="xyz.ethandupe.khub"
PORT=8088
CTRL_PORT=8089
REPO_BASE="https://ethandupe.github.io/KindleHub"

mkdir -p "$PERSIST_DIR/apps"

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

# Preserve existing permanent API key, settings, and /khub/apps before copying
SAVED_KEY=""
if [ -f "$PERSIST_DIR/api_key.txt" ]; then
    SAVED_KEY="$(cat "$PERSIST_DIR/api_key.txt" | tr -d ' \t\r\n')"
elif [ -f "$TARGET_DIR/api_key.txt" ]; then
    SAVED_KEY="$(cat "$TARGET_DIR/api_key.txt" | tr -d ' \t\r\n')"
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

install_book_cover

# Restore permanent API key, settings, and downloaded /khub/apps to both directories
printf "%s" "$SAVED_KEY" > "$PERSIST_DIR/api_key.txt" 2>/dev/null
printf "%s" "$SAVED_KEY" > "$TARGET_DIR/api_key.txt" 2>/dev/null

if [ -n "$SAVED_SETTINGS" ]; then
    printf "%s" "$SAVED_SETTINGS" > "$PERSIST_DIR/khub_settings.json"
    printf "%s" "$SAVED_SETTINGS" > "$TARGET_DIR/khub_settings.json"
fi
if [ ! -f "$PERSIST_DIR/apps/installed_apps.js" ]; then
    printf "window.__khubDiskApps = {};\nif (window.onKhubDiskApps) { window.onKhubDiskApps(window.__khubDiskApps); }\n" > "$PERSIST_DIR/apps/installed_apps.js"
fi
cp -r "$PERSIST_DIR/apps/"* "$TARGET_DIR/apps/" 2>/dev/null

# Prepare /tmp/khub_www for BusyBox httpd / CGI and Python fallback
mkdir -p "$WWW_DIR/cgi-bin"
printf "%s" "$SAVED_KEY" > "$WWW_DIR/api_key.txt" 2>/dev/null
echo "1" > /tmp/khub_remote_active

cat << 'EOF_REMOTE_HTML' > "$WWW_DIR/index.html"
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>KHub - Enter AI API Key</title>
<style>
body { font-family: sans-serif; background: #fff; color: #000; text-align: center; padding: 20px; margin: 0; }
.box { max-width: 460px; margin: 16px auto; border: 4px solid #000; padding: 20px; text-align: left; }
h1 { margin: 0 0 8px 0; font-size: 26px; }
p { font-size: 16px; line-height: 1.4; }
input[type=text] { width: 100%; box-sizing: border-box; font-size: 18px; padding: 12px; border: 3px solid #000; margin: 10px 0 16px 0; }
button { width: 100%; font-size: 20px; font-weight: bold; padding: 14px; background: #000; color: #fff; border: 3px solid #000; cursor: pointer; }
.msg { margin-top: 14px; padding: 12px; border: 3px solid #000; font-weight: bold; background: #eee; }
</style>
</head>
<body>
<div class="box">
  <h1>KHUB API KEY SETUP</h1>
  <p>Paste your Gemini API Key below. As soon as you tap Save, your Kindle will receive it in the API Key box, save it permanently, and automatically stop this web server.</p>
  <form method="GET" action="/cgi-bin/khub.cgi">
    <input type="hidden" name="action" value="save">
    <input type="hidden" name="from" value="remote">
    <label><strong>Gemini API Key:</strong></label>
    <input type="text" name="key" id="key-input" placeholder="Paste Gemini API key here..." required autocomplete="off">
    <button type="submit">Save API Key to Kindle</button>
  </form>
</div>
<script src="/state.js"></script>
<script>
if (window.__khubDiskState && window.__khubDiskState.apiKey) {
  var el = document.getElementById('key-input');
  if (el && !el.value) el.value = window.__khubDiskState.apiKey;
}
</script>
</body>
</html>
EOF_REMOTE_HTML

# Create universal POSIX shell CGI script (/tmp/khub_www/cgi-bin/khub.cgi) — NO xargs -0!
cat << 'EOF_CGI' > "$WWW_DIR/cgi-bin/khub.cgi"
#!/bin/sh
export PATH="/mnt/us/python3/bin:/mnt/us/python/bin:/mnt/us/usbnet/bin:/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin:$PATH"
PERSIST_DIR="/mnt/us/documents/khub"
TARGET_DIR="/var/local/mesquite/KHub"
WWW_DIR="/tmp/khub_www"
PORT=8088
CTRL_PORT=8089

get_param() {
    KEY="$1"
    printf '%s' "$QUERY_STRING" | tr '&' '\n' | grep "^${KEY}=" | head -n 1 | cut -d= -f2- | sed 's/%20//g; s/%0[aAdD9]//g; s/+//g'
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

sync_state() {
    AUTO_STOPPED="${1:-false}"
    CUR_IP="$(get_ip)"
    CUR_KEY=""
    if [ -f "$PERSIST_DIR/api_key.txt" ]; then
        CUR_KEY="$(cat "$PERSIST_DIR/api_key.txt" 2>/dev/null | tr -d ' \t\r\n')"
    elif [ -f "$TARGET_DIR/api_key.txt" ]; then
        CUR_KEY="$(cat "$TARGET_DIR/api_key.txt" 2>/dev/null | tr -d ' \t\r\n')"
    fi
    ESC_KEY="$(printf "%s" "$CUR_KEY" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr -d '\r\n')"
    ZOOM_VAL="100"
    if [ -f "$PERSIST_DIR/khub_settings.json" ]; then
        Z_TMP="$(sed -n 's/.*"zoom"[[:space:]]*:[[:space:]]*\([0-9]*\).*/\1/p' "$PERSIST_DIR/khub_settings.json" 2>/dev/null | head -n 1)"
        [ -n "$Z_TMP" ] && ZOOM_VAL="$Z_TMP"
    fi
    REM_ACT="false"
    [ -f /tmp/khub_remote_active ] && REM_ACT="true"
    STATE_JSON="{\"ok\":true,\"ip\":\"$CUR_IP\",\"port\":$PORT,\"remoteActive\":$REM_ACT,\"autoStopped\":$AUTO_STOPPED,\"apiKey\":\"$ESC_KEY\",\"zoom\":$ZOOM_VAL}"
    JS_STR="window.__khubDiskState = $STATE_JSON; if (window.onKhubDiskState) { window.onKhubDiskState(window.__khubDiskState); }"
    printf "%s\n" "$JS_STR" > "$PERSIST_DIR/kindle_state.js" 2>/dev/null
    printf "%s\n" "$JS_STR" > "$TARGET_DIR/kindle_state.js" 2>/dev/null
    printf "%s\n" "$JS_STR" > "$WWW_DIR/state.js" 2>/dev/null
    printf "%s" "$CUR_KEY" > "$WWW_DIR/api_key.txt" 2>/dev/null

    BRIDGE_HTML="<!DOCTYPE html><html><head><meta charset=\"utf-8\"><script>var st=$STATE_JSON;try{if(window.parent&&window.parent.onKhubDiskState)window.parent.onKhubDiskState(st);}catch(e){}</script></head><body>$ESC_KEY</body></html>"
    printf "%s\n" "$BRIDGE_HTML" > "$PERSIST_DIR/api_key_bridge.html" 2>/dev/null
    printf "%s\n" "$BRIDGE_HTML" > "$TARGET_DIR/api_key_bridge.html" 2>/dev/null
    printf "%s\n" "$BRIDGE_HTML" > "$WWW_DIR/api_key_bridge.html" 2>/dev/null
}

stop_port_8088_bg() {
    rm -f /tmp/khub_remote_active 2>/dev/null
    (
        sleep 3
        for pid in $(ps -ef 2>/dev/null | grep -E "httpd.*:8088|khub_nc_server" | grep -v grep | awk '{print $2}'); do
            kill -9 "$pid" 2>/dev/null
        done
        for pid in $(ps 2>/dev/null | grep -E "httpd.*:8088|khub_nc_server" | grep -v grep | awk '{print $1}'); do
            kill -9 "$pid" 2>/dev/null
        done
        for ipt in iptables /usr/sbin/iptables /sbin/iptables; do
            if command -v "$ipt" >/dev/null 2>&1 || [ -x "$ipt" ]; then
                "$ipt" -D INPUT -p tcp --dport 8088 -j ACCEPT 2>/dev/null
                "$ipt" -D INPUT -i wlan0 -p tcp --dport 8088 -j ACCEPT 2>/dev/null
                break
            fi
        done
    ) >/dev/null 2>&1 &
}

start_port_8088_now() {
    echo "1" > /tmp/khub_remote_active
    for ipt in iptables /usr/sbin/iptables /sbin/iptables; do
        if command -v "$ipt" >/dev/null 2>&1 || [ -x "$ipt" ]; then
            "$ipt" -C INPUT -p tcp --dport 8088 -j ACCEPT 2>/dev/null || "$ipt" -I INPUT 1 -p tcp --dport 8088 -j ACCEPT 2>/dev/null
            "$ipt" -C INPUT -i wlan0 -p tcp --dport 8088 -j ACCEPT 2>/dev/null || "$ipt" -I INPUT 1 -i wlan0 -p tcp --dport 8088 -j ACCEPT 2>/dev/null
            break
        fi
    done
    if ! netstat -tlpn 2>/dev/null | grep -q ":8088 " && ! netstat -tln 2>/dev/null | grep -q ":8088 "; then
        if command -v httpd >/dev/null 2>&1; then
            nohup httpd -f -p 0.0.0.0:8088 -h "$WWW_DIR" >/dev/null 2>&1 &
        elif busybox --list 2>/dev/null | grep -qx "httpd"; then
            nohup busybox httpd -f -p 0.0.0.0:8088 -h "$WWW_DIR" >/dev/null 2>&1 &
        else
            nohup /tmp/khub_nc_server.sh >/dev/null 2>&1 &
        fi
    fi
}

ACTION="$(get_param action)"
FROM_PARAM="$(get_param from)"
JSONP_PARAM="$(get_param jsonp)"
KEY_PARAM="$(get_param key | tr -cd 'A-Za-z0-9_.-')"
CLEAR_PARAM="$(get_param clear)"
ZOOM_PARAM="$(get_param zoom | tr -cd '0-9')"

if [ "$ACTION" = "start" ]; then
    start_port_8088_now
    sync_state false
    if [ -n "$JSONP_PARAM" ]; then
        printf "Content-Type: application/javascript; charset=utf-8\r\nCache-Control: no-store\r\nAccess-Control-Allow-Origin: *\r\n\r\n"
        cat "$PERSIST_DIR/kindle_state.js" 2>/dev/null
    else
        printf "Content-Type: application/json\r\nCache-Control: no-store\r\nAccess-Control-Allow-Origin: *\r\n\r\n"
        printf "%s\n" "$STATE_JSON"
    fi
    exit 0
fi

if [ "$ACTION" = "stop" ]; then
    stop_port_8088_bg
    sync_state true
    if [ -n "$JSONP_PARAM" ]; then
        printf "Content-Type: application/javascript; charset=utf-8\r\nCache-Control: no-store\r\nAccess-Control-Allow-Origin: *\r\n\r\n"
        cat "$PERSIST_DIR/kindle_state.js" 2>/dev/null
    else
        printf "Content-Type: application/json\r\nCache-Control: no-store\r\nAccess-Control-Allow-Origin: *\r\n\r\n"
        printf "%s\n" "$STATE_JSON"
    fi
    exit 0
fi

if [ "$ACTION" = "save" ] || [ -n "$KEY_PARAM" ] || [ -n "$CLEAR_PARAM" ] || [ -n "$ZOOM_PARAM" ]; then
    if [ -n "$CLEAR_PARAM" ]; then
        printf "" > "$PERSIST_DIR/api_key.txt" 2>/dev/null
        printf "" > "$TARGET_DIR/api_key.txt" 2>/dev/null
        printf "" > "$WWW_DIR/api_key.txt" 2>/dev/null
    elif [ -n "$KEY_PARAM" ]; then
        printf "%s" "$KEY_PARAM" > "$PERSIST_DIR/api_key.txt" 2>/dev/null
        printf "%s" "$KEY_PARAM" > "$TARGET_DIR/api_key.txt" 2>/dev/null
        printf "%s" "$KEY_PARAM" > "$WWW_DIR/api_key.txt" 2>/dev/null
    fi
    if [ -n "$ZOOM_PARAM" ]; then
        printf "{\"zoom\": %s}\n" "$ZOOM_PARAM" > "$PERSIST_DIR/khub_settings.json" 2>/dev/null
        printf "{\"zoom\": %s}\n" "$ZOOM_PARAM" > "$TARGET_DIR/khub_settings.json" 2>/dev/null
    fi

    if [ "$FROM_PARAM" = "remote" ]; then
        rm -f /tmp/khub_remote_active 2>/dev/null
        sync_state true
        stop_port_8088_bg
        SAVED_K="$(cat "$PERSIST_DIR/api_key.txt" 2>/dev/null | sed 's/"/\&quot;/g')"
        printf "Content-Type: text/html; charset=utf-8\r\nCache-Control: no-store\r\nAccess-Control-Allow-Origin: *\r\n\r\n"
        cat << EOF_SAVED
<!DOCTYPE html>
<html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>KHub - API Key Saved & Server Stopped</title>
<style>body{font-family:sans-serif;background:#fff;color:#000;text-align:center;padding:20px;margin:0;}.box{max-width:460px;margin:16px auto;border:4px solid #000;padding:20px;text-align:left;}h1{margin:0 0 8px 0;font-size:26px;}.msg{margin-top:14px;padding:12px;border:3px solid #000;font-weight:bold;background:#eee;line-height:1.4;}</style>
</head><body><div class="box">
<h1>API KEY RECEIVED &amp; SAVED!</h1>
<div class="msg">Success! Your Kindle has received your Gemini API Key (<code>$SAVED_K</code>), filled it into the Settings box, saved it permanently, and <strong>automatically stopped the web server</strong>.</div>
</div></body></html>
EOF_SAVED
        exit 0
    fi

    sync_state false
    if [ -n "$JSONP_PARAM" ]; then
        printf "Content-Type: application/javascript; charset=utf-8\r\nCache-Control: no-store\r\nAccess-Control-Allow-Origin: *\r\n\r\n"
        cat "$PERSIST_DIR/kindle_state.js" 2>/dev/null
    else
        printf "Content-Type: application/json\r\nCache-Control: no-store\r\nAccess-Control-Allow-Origin: *\r\n\r\n"
        printf "%s\n" "$STATE_JSON"
    fi
    exit 0
fi

if [ "$ACTION" = "uninstall" ]; then
    APP_ID_DEL="$(get_param id | tr -cd 'a-zA-Z0-9_-')"
    if [ -n "$APP_ID_DEL" ]; then
        rm -rf "$PERSIST_DIR/apps/$APP_ID_DEL" "$TARGET_DIR/apps/$APP_ID_DEL" 2>/dev/null
    fi
fi

if [ "$ACTION" = "update" ]; then
    REPO="https://ethandupe.github.io/KindleHub"
    mkdir -p "$PERSIST_DIR/apps" "$TARGET_DIR/apps"
    dl_file() {
        URL="$1"
        DEST="$2"
        curl -k -sL --connect-timeout 10 "$URL" -o "$DEST" 2>/dev/null || wget --no-check-certificate -q -O "$DEST" "$URL" 2>/dev/null || wget -q -O "$DEST" "$URL" 2>/dev/null
    }
    dl_file "$REPO/khub/index.html" /tmp/khub_u_index.html
    if ! grep -qi "<html" /tmp/khub_u_index.html 2>/dev/null; then
        dl_file "$REPO/index.html" /tmp/khub_u_index.html
    fi
    if grep -qi "<html" /tmp/khub_u_index.html 2>/dev/null; then
        cp /tmp/khub_u_index.html "$PERSIST_DIR/index.html"
        cp /tmp/khub_u_index.html "$TARGET_DIR/index.html"
    fi

    dl_file "$REPO/khub/config.xml" /tmp/khub_u_config.xml
    if ! grep -qi "<widget" /tmp/khub_u_config.xml 2>/dev/null; then
        dl_file "$REPO/config.xml" /tmp/khub_u_config.xml
    fi
    if grep -qi "<widget" /tmp/khub_u_config.xml 2>/dev/null; then
        cp /tmp/khub_u_config.xml "$PERSIST_DIR/config.xml"
        cp /tmp/khub_u_config.xml "$TARGET_DIR/config.xml"
    fi

    dl_file "$REPO/khub.sh" /tmp/khub_u_sh.sh
    if grep -q "^#!/bin/sh" /tmp/khub_u_sh.sh 2>/dev/null; then
        cp /tmp/khub_u_sh.sh /mnt/us/documents/khub.sh
        chmod +x /mnt/us/documents/khub.sh
    fi
    sync_state false
    if [ -n "$JSONP_PARAM" ]; then
        printf "Content-Type: application/javascript; charset=utf-8\r\nCache-Control: no-store\r\nAccess-Control-Allow-Origin: *\r\n\r\n"
        printf "if(window.onKhubSystemUpdateDone)window.onKhubSystemUpdateDone(true);\n"
    else
        printf "Content-Type: application/json\r\nCache-Control: no-store\r\nAccess-Control-Allow-Origin: *\r\n\r\n"
        printf "{\"ok\":true}\n"
    fi
    exit 0
fi

sync_state false
if [ -n "$JSONP_PARAM" ]; then
    printf "Content-Type: application/javascript; charset=utf-8\r\nCache-Control: no-store\r\nAccess-Control-Allow-Origin: *\r\n\r\n"
    cat "$PERSIST_DIR/kindle_state.js" 2>/dev/null
else
    printf "Content-Type: application/json\r\nCache-Control: no-store\r\nAccess-Control-Allow-Origin: *\r\n\r\n"
    printf "%s\n" "$STATE_JSON"
fi
EOF_CGI
chmod +x "$WWW_DIR/cgi-bin/khub.cgi"

# Write initial kindle_state.js and api_key_bridge.html with detected Kindle IP and API key
CURRENT_IP="$(detect_kindle_ip)"
ESC_KEY="$(printf "%s" "$SAVED_KEY" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr -d '\r\n')"
STATE_OBJ_STR="{\"ok\":true,\"ip\":\"$CURRENT_IP\",\"port\":$PORT,\"remoteActive\":true,\"autoStopped\":false,\"apiKey\":\"$ESC_KEY\"}"
cat << EOF_STATE > "$TARGET_DIR/kindle_state.js"
window.__khubDiskState = $STATE_OBJ_STR;
if (window.onKhubDiskState) { window.onKhubDiskState(window.__khubDiskState); }
EOF_STATE
cp "$TARGET_DIR/kindle_state.js" "$PERSIST_DIR/kindle_state.js" 2>/dev/null
cp "$TARGET_DIR/kindle_state.js" "$WWW_DIR/state.js" 2>/dev/null

BRIDGE_INIT="<!DOCTYPE html><html><head><meta charset=\"utf-8\"><script>var st=$STATE_OBJ_STR;try{if(window.parent&&window.parent.onKhubDiskState)window.parent.onKhubDiskState(st);}catch(e){}</script></head><body>$ESC_KEY</body></html>"
printf "%s\n" "$BRIDGE_INIT" > "$TARGET_DIR/api_key_bridge.html" 2>/dev/null
printf "%s\n" "$BRIDGE_INIT" > "$PERSIST_DIR/api_key_bridge.html" 2>/dev/null
printf "%s\n" "$BRIDGE_INIT" > "$WWW_DIR/api_key_bridge.html" 2>/dev/null

# Open ports 8088 (Remote Key Server) and 8089 (Internal Helper) on Kindle firewall
open_kindle_firewall() {
    for ipt in iptables /usr/sbin/iptables /sbin/iptables; do
        if command -v "$ipt" >/dev/null 2>&1 || [ -x "$ipt" ]; then
            "$ipt" -C INPUT -p tcp --dport $PORT -j ACCEPT 2>/dev/null || "$ipt" -I INPUT 1 -p tcp --dport $PORT -j ACCEPT 2>/dev/null
            "$ipt" -C INPUT -i wlan0 -p tcp --dport $PORT -j ACCEPT 2>/dev/null || "$ipt" -I INPUT 1 -i wlan0 -p tcp --dport $PORT -j ACCEPT 2>/dev/null
            "$ipt" -C INPUT -p tcp --dport $CTRL_PORT -j ACCEPT 2>/dev/null || "$ipt" -I INPUT 1 -p tcp --dport $CTRL_PORT -j ACCEPT 2>/dev/null
            "$ipt" -C INPUT -i lo -j ACCEPT 2>/dev/null || "$ipt" -I INPUT 1 -i lo -j ACCEPT 2>/dev/null
            break
        fi
    done
}
open_kindle_firewall

# Stop any previous KHub helper server instance
for pid in $(ps -ef 2>/dev/null | grep -E "khub_server|khub_ip_watcher|khub_nc_server|httpd.*808" | grep -v grep | awk '{print $2}'); do
    kill -9 "$pid" 2>/dev/null
done
for pid in $(ps 2>/dev/null | grep -E "khub_server|khub_ip_watcher|khub_nc_server|httpd.*808" | grep -v grep | awk '{print $1}'); do
    kill -9 "$pid" 2>/dev/null
done

# Create pure-shell netcat (nc) fallback server in case BusyBox httpd is not present
cat << 'EOF_NC' > /tmp/khub_nc_server.sh
#!/bin/sh
export PATH="/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin:$PATH"
PORT=8088
WWW_DIR="/tmp/khub_www"
while [ -f /tmp/khub_remote_active ]; do
    (
        read -r REQ_LINE
        REQ_PATH="$(printf "%s" "$REQ_LINE" | awk '{print $2}')"
        while read -r HDR; do
            HDR="$(printf "%s" "$HDR" | tr -d '\r\n')"
            [ -z "$HDR" ] && break
        done
        case "$REQ_PATH" in
            /cgi-bin/khub.cgi*|/save*|/status*|/state.js*|/update*)
                QS="$(printf "%s" "$REQ_PATH" | cut -s -d? -f2-)"
                printf "HTTP/1.1 200 OK\r\n"
                QUERY_STRING="$QS" "$WWW_DIR/cgi-bin/khub.cgi"
                ;;
            *)
                printf "HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nCache-Control: no-store\r\nConnection: close\r\n\r\n"
                cat "$WWW_DIR/index.html"
                ;;
        esac
    ) | nc -l -p $PORT 2>/dev/null || sleep 2
done
EOF_NC
chmod +x /tmp/khub_nc_server.sh

# Start BusyBox httpd on port 8088 (Remote Key Server) and port 8089 (Always-On Local Control Server)
start_khub_webserver() {
    if command -v httpd >/dev/null 2>&1; then
        nohup httpd -f -p 0.0.0.0:$PORT -h "$WWW_DIR" >/dev/null 2>&1 &
        nohup httpd -f -p 0.0.0.0:$CTRL_PORT -h "$WWW_DIR" >/dev/null 2>&1 &
    elif busybox --list 2>/dev/null | grep -qx "httpd"; then
        nohup busybox httpd -f -p 0.0.0.0:$PORT -h "$WWW_DIR" >/dev/null 2>&1 &
        nohup busybox httpd -f -p 0.0.0.0:$CTRL_PORT -h "$WWW_DIR" >/dev/null 2>&1 &
    else
        nohup /tmp/khub_nc_server.sh >/dev/null 2>&1 &
    fi
}

start_khub_webserver

# Background watcher that keeps kindle_state.js + api_key_bridge.html updated, keeps firewall open while remote server is active, and stops port 8088 when key is saved
cat << 'EOF_WATCH' > /tmp/khub_ip_watcher.sh
#!/bin/sh
export PATH="/mnt/us/python3/bin:/mnt/us/python/bin:/mnt/us/usbnet/bin:/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin:$PATH"
PERSIST_DIR="/mnt/us/documents/khub"
TARGET_DIR="/var/local/mesquite/KHub"
WWW_DIR="/tmp/khub_www"
PORT=8088
CTRL_PORT=8089

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
    # Keep internal control port 8089 alive at all times
    for ipt in iptables /usr/sbin/iptables /sbin/iptables; do
        if command -v "$ipt" >/dev/null 2>&1 || [ -x "$ipt" ]; then
            "$ipt" -C INPUT -p tcp --dport $CTRL_PORT -j ACCEPT 2>/dev/null || "$ipt" -I INPUT 1 -p tcp --dport $CTRL_PORT -j ACCEPT 2>/dev/null
            break
        fi
    done
    if ! netstat -tlpn 2>/dev/null | grep -q ":$CTRL_PORT " && ! netstat -tln 2>/dev/null | grep -q ":$CTRL_PORT "; then
        if command -v httpd >/dev/null 2>&1; then
            nohup httpd -f -p 0.0.0.0:$CTRL_PORT -h "$WWW_DIR" >/dev/null 2>&1 &
        elif busybox --list 2>/dev/null | grep -qx "httpd"; then
            nohup busybox httpd -f -p 0.0.0.0:$CTRL_PORT -h "$WWW_DIR" >/dev/null 2>&1 &
        fi
    fi

    # Only keep Remote Key Server port 8088 open if /tmp/khub_remote_active exists
    if [ -f /tmp/khub_remote_active ]; then
        for ipt in iptables /usr/sbin/iptables /sbin/iptables; do
            if command -v "$ipt" >/dev/null 2>&1 || [ -x "$ipt" ]; then
                "$ipt" -C INPUT -p tcp --dport $PORT -j ACCEPT 2>/dev/null || "$ipt" -I INPUT 1 -p tcp --dport $PORT -j ACCEPT 2>/dev/null
                break
            fi
        done
        if ! netstat -tlpn 2>/dev/null | grep -q ":$PORT " && ! netstat -tln 2>/dev/null | grep -q ":$PORT "; then
            if command -v httpd >/dev/null 2>&1; then
                nohup httpd -f -p 0.0.0.0:$PORT -h "$WWW_DIR" >/dev/null 2>&1 &
            elif busybox --list 2>/dev/null | grep -qx "httpd"; then
                nohup busybox httpd -f -p 0.0.0.0:$PORT -h "$WWW_DIR" >/dev/null 2>&1 &
            fi
        fi
    fi

    CUR_IP="$(get_ip)"
    CUR_KEY=""
    if [ -f "$PERSIST_DIR/api_key.txt" ]; then
        CUR_KEY="$(cat "$PERSIST_DIR/api_key.txt" 2>/dev/null | tr -d ' \t\r\n')"
    elif [ -f "$TARGET_DIR/api_key.txt" ]; then
        CUR_KEY="$(cat "$TARGET_DIR/api_key.txt" 2>/dev/null | tr -d ' \t\r\n')"
    fi
    ESC_KEY="$(printf "%s" "$CUR_KEY" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr -d '\r\n')"
    REM_ACT="false"
    AUTO_STOP="true"
    if [ -f /tmp/khub_remote_active ]; then
        REM_ACT="true"
        AUTO_STOP="false"
    fi
    NEW_STATE="${CUR_IP}|${ESC_KEY}|${REM_ACT}"
    if [ "$NEW_STATE" != "$LAST_STATE" ]; then
        LAST_STATE="$NEW_STATE"
        STATE_JSON="{\"ok\":true,\"ip\":\"$CUR_IP\",\"port\":$PORT,\"remoteActive\":$REM_ACT,\"autoStopped\":$AUTO_STOP,\"apiKey\":\"$ESC_KEY\"}"
        JS_CONTENT="window.__khubDiskState = $STATE_JSON; if (window.onKhubDiskState) { window.onKhubDiskState(window.__khubDiskState); }"
        printf "%s\n" "$JS_CONTENT" > "$TARGET_DIR/kindle_state.js" 2>/dev/null
        printf "%s\n" "$JS_CONTENT" > "$PERSIST_DIR/kindle_state.js" 2>/dev/null
        if [ -d "$WWW_DIR" ]; then
            printf "%s\n" "$JS_CONTENT" > "$WWW_DIR/state.js" 2>/dev/null
            printf "%s" "$CUR_KEY" > "$WWW_DIR/api_key.txt" 2>/dev/null
        fi
        BRIDGE_HTML="<!DOCTYPE html><html><head><meta charset=\"utf-8\"><script>var st=$STATE_JSON;try{if(window.parent&&window.parent.onKhubDiskState)window.parent.onKhubDiskState(st);}catch(e){}</script></head><body>$ESC_KEY</body></html>"
        printf "%s\n" "$BRIDGE_HTML" > "$TARGET_DIR/api_key_bridge.html" 2>/dev/null
        printf "%s\n" "$BRIDGE_HTML" > "$PERSIST_DIR/api_key_bridge.html" 2>/dev/null
        printf "%s\n" "$BRIDGE_HTML" > "$WWW_DIR/api_key_bridge.html" 2>/dev/null
    fi
    sleep 2
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

echo Registered $APP_ID, you may now launch it with LIPC.
sleep 2

# Launch with LIPC
nohup lipc-set-prop com.lab126.appmgrd start app://$APP_ID >/dev/null 2>&1 &
