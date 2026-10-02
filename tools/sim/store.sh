#!/bin/zsh
# The booted simulator's LogNLoad store, for setting up a state to check (docs/agents/build.md, Drive the app).
#   store.sh backup        save the current store as the baseline
#   store.sh apply <sql>   reset the store to the baseline, then run <sql> on it
#   store.sh sql <sql>     run <sql> on the current store, e.g. to read what a flow saved
#   store.sh restore       put the baseline back
#   store.sh now           the current time as a store timestamp (seconds since 2001-01-01)
set -e
BASELINE=${0:A:h}/baseline.store
store() {
    xcrun simctl terminate booted com.angh84.lognload 2>/dev/null || true
    echo "$(xcrun simctl get_app_container booted com.angh84.lognload data)/Library/Application Support/default.store"
}
case $1 in
backup)
    DB=$(store)
    sqlite3 "$DB" "pragma wal_checkpoint(TRUNCATE);" >/dev/null
    cp "$DB" "$BASELINE" ;;
apply|restore)
    DB=$(store)
    rm -f "$DB-wal" "$DB-shm"
    cp "$BASELINE" "$DB"
    if [[ $1 == apply ]]; then sqlite3 "$DB" "$2"; fi ;;
sql)
    sqlite3 -header "$(store)" "$2" ;;
now)
    echo $(( $(date +%s) - 978307200 )) ;;
*)
    sed -n '2,7p' "$0"; exit 1 ;;
esac
