#!/usr/bin/env bash
set -euo pipefail

trap 'echo; echo "Error pada baris $LINENO. Exiting."; exit 1' ERR

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
# MENU
# =========================
print_menu() {
    clear
    echo "==== Frappe Bench Interactive Setup ===="
    echo
    echo "  1)  Frappe Version   : $FRAPPE_VERSION"
    echo "  2)  DB Host          : $DB_HOST"
    echo "  3)  DB Port          : $DB_PORT"
    echo "  4)  Redis Cache      : $REDIS_CACHE"
    echo "  5)  Redis Queue      : $REDIS_QUEUE"
    echo "  6)  Redis SocketIO   : $REDIS_SOCKETIO"
    echo "  7)  DB Name          : $DB_NAME"
    echo "  8)  DB Root User     : $DB_ROOT_USER"
    echo "  9)  DB Root Password : ********"
    echo "  10) Admin Password   : ********"
    echo "  11) Site Name        : $SITE_NAME"
    echo "  12) Bench Name       : $BENCH_NAME"
    echo
    echo "  a) Apply & Run"
    echo "  q) Quit"
    echo
}

# =========================
# EDIT VALUE
# =========================
edit_value() {
    local label="$1"
    local var_name="$2"
    local is_secret="${3:-false}"
    local current="${!var_name}"
    local input=""
    local char

    clear
    echo "==== Edit: $label ===="
    echo
    if [[ "$is_secret" == "true" ]]; then
        echo "  Nilai saat ini : ********"
    else
        echo "  Nilai saat ini : $current"
    fi
    echo
    echo "  Tekan ESC untuk batal, ENTER untuk simpan."
    echo

    # Tampilkan prompt di baris yang sama, lalu baca karakter
    printf "  Nilai baru : "

    while true; do
        IFS= read -r -s -n1 char

        # ESC
        if [[ "$char" == $'\x1b' ]]; then
            IFS= read -r -s -n2 -t 0.05 _ || true
            echo
            echo
            echo "  Batal."
            sleep 0.4
            return
        fi

        # Enter
        if [[ "$char" == "" || "$char" == $'\r' ]]; then
            break
        fi

        # Backspace
        if [[ "$char" == $'\x7f' || "$char" == $'\b' ]]; then
            if [[ ${#input} -gt 0 ]]; then
                input="${input%?}"
                printf '\b \b'
            fi
            continue
        fi

        # Karakter biasa
        input+="$char"
        if [[ "$is_secret" == "true" ]]; then
            printf '*'
        else
            printf '%s' "$char"
        fi
    done

    echo

    if [[ -z "$input" ]]; then
        echo
        echo "  Input kosong, nilai tidak diubah."
        sleep 0.8
        return
    fi

    printf -v "$var_name" '%s' "$input"
    echo
    echo "  Tersimpan."
    sleep 0.5
}

# =========================
# RUN BENCH
# =========================
run_bench() {
    clear
    echo "==== Menjalankan Bench Setup ===="
    echo

    bench init \
        --skip-redis-config-generation \
        --ignore-exist \
        --frappe-branch="$FRAPPE_VERSION" \
        --dev \
        "$BENCH_NAME"

    cd "$BENCH_NAME"

    bench set-config -g db_host        "$DB_HOST"
    bench set-config -g db_port        "$DB_PORT"
    bench set-config -g redis_cache    "$REDIS_CACHE"
    bench set-config -g redis_queue    "$REDIS_QUEUE"
    bench set-config -g redis_socketio "$REDIS_SOCKETIO"

    bench new-site \
        --db-name="$DB_NAME" \
        --db-root-username="$DB_ROOT_USER" \
        --db-root-password="$DB_ROOT_PASS" \
        --admin-password="$ADMIN_PASS" \
        --mariadb-user-host-login-scope="%" \
        "$SITE_NAME"

    echo
    echo "Done."
}

# =========================
# MAIN LOOP
# =========================
while true; do
    print_menu
    read -rp "  Pilih opsi : " choice

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
        10) edit_value "Admin Password"   ADMIN_PASS   true ;;
        11) edit_value "Site Name"        SITE_NAME ;;
        12) edit_value "Bench Name"       BENCH_NAME ;;
        a|A) run_bench; exit 0 ;;
        q|Q) echo; echo "  Keluar."; echo; exit 0 ;;
        *)  echo; echo "  Opsi tidak valid."; sleep 0.5 ;;
    esac
done
