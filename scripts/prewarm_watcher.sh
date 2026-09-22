#!/system/bin/sh
# prewarm_watcher v5.1 (task-aware + app-existence guard)
# v5 增量：预启动前校验目标包仍安装（app 被删除 → 自动跳过，防白拉/防过期表）
# Watches for new virtual displays; resolves the current PhoneAgent task target;
# writes /data/local/tmp/prewarm_target.txt for server-side auto-prewarm (x.smali).
# Policy: fresh task resolved and package installed -> write package (mtime aged so it is read immediately)
#         otherwise                                  -> write empty  (never prewarm, safe)
LOG_FILE=/sdcard/Download/Operit/prewarm.log
SRV_LOG=/data/local/tmp/shower.log
CONF=/data/local/tmp/prewarm_target.txt
MAP=/data/local/tmp/prewarm_map.tsv
AGE_TS=202601010000.00

log() { echo "[$(date +%H:%M:%S)] $1" >> $LOG_FILE; }
to_sec() { echo "$1" | awk -F: '{print ($1*3600+$2*60+$3)}'; }

find_task() {
  L=$(logcat -d -v time -t 3000 2>/dev/null | /system/bin/grep -aE '^[0-9][0-9]-[0-9][0-9] [0-9:.]+ D/PhoneAgent' | /system/bin/grep -a 'run: starting first step for task=' | tail -1)
  [ -z "$L" ] && return 1
  A=$(echo "$L" | /system/bin/grep -oE '\[[0-9A-Za-z_]+\]' | head -1 | tr -d '[]')
  T=$(echo "$L" | awk -F"task='" '{print $2}' | cut -d"'" -f1)
  H=$(echo "$L" | cut -c7-14)
  [ -z "$T" ] && return 1
  printf '%s\t%s\t%s' "$A" "$T" "$H"
}

pkg_installed() {
  pm list packages "$1" 2>/dev/null | /system/bin/grep -qxF "package:$1"
}

if [ "$1" = "--resolve" ]; then
  T="$2"
  while read -r KW PKG; do
    case "$T" in *"$KW"*) echo "$PKG"; exit 0;; esac
  done < $MAP
  exit 1
fi

if [ "$1" = "--find" ]; then
  find_task && exit 0 || exit 1
fi

echo "== prewarm watcher v5 (task-aware + app-existence guard) started $(date) ==" >> $LOG_FILE
LAST=$(tail -150 $SRV_LOG 2>/dev/null | /system/bin/grep -a "Created virtual display id=" | tail -1)
echo "[init] LAST=[$LAST]" >> $LOG_FILE

while true; do
  CUR=$(tail -150 $SRV_LOG 2>/dev/null | /system/bin/grep -a "Created virtual display id=" | tail -1)
  if [ -n "$CUR" ] && [ "$CUR" != "$LAST" ]; then
    LAST="$CUR"
    D=$(echo "$CUR" | sed -n 's/.*id=\([0-9]*\).*/\1/p')
    log "display=$D created; analyzing task..."
    : > $CONF; touch -t $AGE_TS $CONF
    N=0; PKG=""; TNAME=""; TOK=""
    while [ $N -lt 3 ]; do
      N=$((N+1))
      SCAN=$(find_task)
      if [ -n "$SCAN" ]; then
        AG=$(echo "$SCAN" | cut -f1)
        TNAME=$(echo "$SCAN" | cut -f2)
        H=$(echo "$SCAN" | cut -f3)
        NOW=$(date +%H:%M:%S)
        DIFF=$(( $(to_sec "$NOW") - $(to_sec "$H") ))
        [ $DIFF -lt 0 ] && DIFF=$((DIFF+86400))
        if [ $DIFF -le 60 ] && [ -n "$AG" ]; then TOK="$AG"; break; fi
      fi
      sleep 0.5 2>/dev/null || sleep 1
    done
    if [ -n "$TOK" ]; then
      if logcat -d -v time -t 800 2>/dev/null | /system/bin/grep -a 'D/PhoneAgent' | /system/bin/grep -a "\[$TOK\]" | /system/bin/grep -aq 'finishing'; then
        log "display=$D: task $TOK already finished; skip"
      else
        while read -r KW P; do
          case "$TNAME" in *"$KW"*) PKG="$P"; break;; esac
        done < $MAP
        if [ -n "$PKG" ]; then
          if pkg_installed "$PKG"; then
            printf '%s' "$PKG" > $CONF
            touch -t $AGE_TS $CONF
            log "display=$D: task='$TNAME' agent=$TOK -> prewarm: $PKG"
          else
            log "display=$D: task='$TNAME' agent=$TOK -> target $PKG MISSING (uninstalled?); skip"
          fi
        else
          log "display=$D: task='$TNAME' agent=$TOK -> no map match; skip"
        fi
      fi
    else
      log "display=$D: no fresh task; skip (empty conf)"
    fi
  fi
  [ -z "$CUR" ] && LAST=""
  sleep 0.5 2>/dev/null || sleep 1
done
