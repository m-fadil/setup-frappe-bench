#!/usr/bin/env bash
set -euo pipefail

# =========================
# TRAP ERROR
# =========================
trap 'echo; echo "❌ Error pada baris $LINENO. Exiting."; exit 1' ERR

# =========================
# DEFAULT CONFIG
# =========================
FRAPPE_VERSION="version-16"
DB_HOST="mariadb"
DB_PORT="3306"
REDIS_CACHE="redis://redis-cache:6379"
REDIS_QUEUE="redis://redis-queue:6379"
REDIS_SOCKETIO="redis://redis-socketio:6379"
DB_NAME="mydb"
DB_ROOT_USER="root"
DB_ROOT_PASS="123"
ADMIN_PASS="admin"
SITE_NAME="development.localhost"
BENCH_NAME="frappe-bench"

# =========================
# UTILS
# =========================
print_menu() {
    clear
    echo "╔══════════════════════════════════════════════╗"
    echo "║       Frappe Bench Interactive Setup         ║"
    echo "╠══════════════════════════════════════════════╣"
    printf "║  %-4s %-20s %-20s║\n" "No" "Field" "Value"
    echo "╠══════════════════════════════════════════════╣"
    printf "║  %-4s %-20s %-30s║\n" "1)" "Frappe Version"   "$FRAPPE_VERSION"
    printf "║  %-4s %-20s %-30s║\n" "2)" "DB Host"          "$DB_HOST"
    printf "║  %-4s %-20s %-30s║\n" "3)" "DB Port"          "$DB_PORT"
    printf "║  %-4s %-20s %-30s║\n" "4)" "Redis Cache"      "$REDIS_CACHE"
    printf "║  %-4s %-20s %-30s║\n" "5)" "Redis Queue"      "$REDIS_QUEUE"
    printf "║  %-4s %-20s %-30s║\n" "6)" "Redis SocketIO"   "$REDIS_SOCKETIO"
    printf "║  %-4s %-20s %-30s║\n" "7)" "DB Name"          "$DB_NAME"
    printf "║  %-4s %-20s %-30s║\n" "8)" "DB Root User"     "$DB_ROOT_USER"
    printf "║  %-4s %-20s %-30s║\n" "9)" "DB Root Password" "********"
    printf "║  %-4s %-20s %-30s║\n" "10)" "Admin Password"  "********"
    printf "║  %-4s %-20s %-30s║\n" "11)" "Site Name"       "$SITE_NAME"
    printf "║  %-4s %-20s %-30s║\n" "12)" "Bench Name"      "$BENCH_NAME"
    echo "╠══════════════════════════════════════════════╣"
    echo "║  a) Apply & Run bench init                   ║"
    echo "║  q) Quit                                     ║"
    echo "╚══════════════════════════════════════════════╝"
    echo
}

# Baca satu karakter tanpa perlu tekan Enter
read_char() {
    local __var="$1"
    local __char
    IFS= read -r -s -n1 __char
    printf -v "$__var" "%s" "$__char"
}

edit_value() {
    local label="$1"
    local var_name="$2"
    local is_secret="${3:-false}"
    local current_value="${!var_name}"

    clear
    echo "╔══════════════════════════════════════════════╗"
    echo "║              Edit Nilai                      ║"
    echo "╠══════════════════════════════════════════════╣"
    echo "║  Field : $label"
    if [[ "$is_secret" == "true" ]]; then
        echo "║  Nilai saat ini: ********"
    else
        echo "║  Nilai saat ini: $current_value"
    fi
    echo "╠══════════════════════════════════════════════╣"
    echo "║  • Ketik nilai baru lalu tekan ENTER         ║"
    echo "║  • Tekan ESC untuk batal & kembali ke menu   ║"
    echo "╚══════════════════════════════════════════════╝"
    echo

    local input=""
    local char

    # Baca karakter per karakter
    while true; do
        read_char char

        # Deteksi ESC
        if [[ "$char" == $'\x1b' ]]; then
            # Cek apakah ada sequence tambahan (arrow key dll)
            local extra
            IFS= read -r -s -n2 -t 0.1 extra || true
            echo
            echo "  ↩ Batal. Kembali ke menu..."
            sleep 0.5
            return
        fi

        # Deteksi Enter
        if [[ "$char" == "" || "$char" == $'\n' || "$char" == $'\r' ]]; then
            break
        fi

        # Deteksi Backspace
        if [[ "$char" == $'\x7f' || "$char" == $'\b' ]]; then
            if [[ ${#input} -gt 0 ]]; then
                input="${input%?}"
                if [[ "$is_secret" == "true" ]]; then
                    printf "\r  > %s" "$(printf '%*s' "${#input}" '' | tr ' ' '*')"
                    printf "  "
                else
                    printf "\r  > %s " "$input"
                fi
            fi
            continue
        fi

        input+="$char"

        if [[ "$is_secret" == "true" ]]; then
            printf "\r  > %s" "$(printf '%*s' "${#input}" '' | tr ' ' '*')"
        else
            printf "\r  > %s" "$input"
        fi
    done

    echo

    if [[ -z "$input" ]]; then
        echo "  ⚠ Input kosong, nilai tidak diubah."
        sleep 0.8
        return
    fi

    printf -v "$var_name" "%s" "$input"
    echo "  ✅ Nilai berhasil diubah!"
    sleep 0.6
}

run_bench() {
    clear
    echo "╔══════════════════════════════════════════════╗"
    echo "║           Menjalankan Bench Setup            ║"
    echo "╚══════════════════════════════════════════════╝"
    echo

    echo "► bench init --frappe-branch=$FRAPPE_VERSION $BENCH_NAME"
    bench init \
        --skip-redis-config-generation \
        --ignore-exist \
        --frappe-branch="$FRAPPE_VERSION" \
        --dev \
        "$BENCH_NAME"

    cd "$BENCH_NAME"

    echo
    echo "► bench set-config (global)"
    bench set-config -g db_host      "$DB_HOST"
    bench set-config -g db_port      "$DB_PORT"
    bench set-config -g redis_cache  "$REDIS_CACHE"
    bench set-config -g redis_queue  "$REDIS_QUEUE"
    bench set-config -g redis_socketio "$REDIS_SOCKETIO"

    echo
    echo "► bench new-site $SITE_NAME"
    bench new-site \
        --db-name="$DB_NAME" \
        --db-root-username="$DB_ROOT_USER" \
        --db-root-password="$DB_ROOT_PASS" \
        --admin-password="$ADMIN_PASS" \
        --mariadb-user-host-login-scope="%" \
        "$SITE_NAME"

    echo
    echo "╔══════════════════════════════════════════════╗"
    echo "║  ✅  Setup selesai!                          ║"
    echo "╚══════════════════════════════════════════════╝"
}

# =========================
# MAIN LOOP
# =========================
while true; do
    print_menu
    read -rp "  Pilih opsi: " choice

    case "$choice" in
        1)  edit_value "Frappe Version"   FRAPPE_VERSION ;;
        2)  edit_value "DB Host"          DB_HOST ;;
        3)  edit_value "DB Port"          DB_PORT ;;
        4)  edit_value "Redis Cache"      REDIS_CACHE ;;
        5)  edit_value "Redis Queue"      REDIS_QUEUE ;;
        6)  edit_value "Redis SocketIO"   REDIS_SOCKETIO ;;
        7)  edit_value "DB Name"          DB_NAME ;;
        8)  edit_value "DB Root User"     DB_ROOT_USER ;;
        9)  edit_value "DB Root Password" DB_ROOT_PASS true ;;
        10) edit_value "Admin Password"   ADMIN_PASS true ;;
        11) edit_value "Site Name"        SITE_NAME ;;
        12) edit_value "Bench Name"       BENCH_NAME ;;
        a|A) run_bench; exit 0 ;;
        q|Q) echo; echo "  Keluar. Sampai jumpa!"; echo; exit 0 ;;
        *)  echo "  ⚠ Opsi tidak valid."; sleep 0.6 ;;
    esac
done
