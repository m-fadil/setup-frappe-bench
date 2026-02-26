#!/usr/bin/env bash
set -euo pipefail

trap 'tput cnorm 2>/dev/null; echo; echo "Error pada baris $LINENO. Exiting."; exit 1' ERR

# Pastikan cursor kembali normal jika script dihentikan
cleanup() {
    tput cnorm 2>/dev/null
    echo
}
trap cleanup EXIT

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
# LABELS & KEYS
# =========================
LABELS=(
    "Frappe Version"
    "DB Host"
    "DB Port"
    "Redis Cache"
    "Redis Queue"
    "Redis SocketIO"
    "DB Name"
    "DB Root User"
    "DB Root Password"
    "Admin Password"
    "Site Name"
    "Bench Name"
)

KEYS=(
    FRAPPE_VERSION
    DB_HOST
    DB_PORT
    REDIS_CACHE
    REDIS_QUEUE
    REDIS_SOCKETIO
    DB_NAME
    DB_ROOT_USER
    DB_ROOT_PASS
    ADMIN_PASS
    SITE_NAME
    BENCH_NAME
)

SECRET_KEYS=(DB_ROOT_PASS ADMIN_PASS)

is_secret() {
    local key="$1"
    for s in "${SECRET_KEYS[@]}"; do
        [[ "$s" == "$key" ]] && return 0
    done
    return 1
}

get_display_value() {
    local key="$1"
    if is_secret "$key"; then
        echo "********"
    else
        echo "${!key}"
    fi
}

# =========================
# TERMINAL HELPERS
# =========================
TOTAL_ITEMS=$(( ${#LABELS[@]} + 2 )) # items + Apply + Quit
MENU_ITEMS=$(( ${#LABELS[@]} ))       # index 0..N-1 = config, N = Apply, N+1 = Quit
IDX_APPLY=$(( ${#LABELS[@]} ))
IDX_QUIT=$(( ${#LABELS[@]} + 1 ))

draw_menu() {
    local selected="$1"
    local label_width=20

    clear
    echo "==== Frappe Bench Interactive Setup ===="
    echo "  Gunakan ARROW UP/DOWN untuk navigasi, ENTER untuk pilih."
    echo

    for i in "${!LABELS[@]}"; do
        local val
        val=$(get_display_value "${KEYS[$i]}")
        if [[ "$i" -eq "$selected" ]]; then
            printf "  \e[7m %-${label_width}s : %-30s \e[0m\n" "${LABELS[$i]}" "$val"
        else
            printf "    %-${label_width}s : %s\n" "${LABELS[$i]}" "$val"
        fi
    done

    echo
    if [[ "$selected" -eq "$IDX_APPLY" ]]; then
        printf "  \e[7m [ Apply & Run ] \e[0m\n"
    else
        printf "    [ Apply & Run ]\n"
    fi

    if [[ "$selected" -eq "$IDX_QUIT" ]]; then
        printf "  \e[7m [ Quit ]        \e[0m\n"
    else
        printf "    [ Quit ]\n"
    fi

    echo
}

# =========================
# EDIT VALUE
# =========================
edit_value() {
    local label="$1"
    local var_name="$2"
    local current="${!var_name}"
    local secret=false
    is_secret "$var_name" && secret=true

    clear
    echo "==== Edit: $label ===="
    echo
    if [[ "$secret" == "true" ]]; then
        echo "  Nilai saat ini : ********"
    else
        echo "  Nilai saat ini : $current"
    fi
    echo
    echo "  Tekan ESC untuk batal, ENTER untuk simpan."
    echo
    printf "  Nilai baru : "

    local input=""
    local char

    tput cnorm  # tampilkan cursor

    while true; do
        IFS= read -r -s -n1 char

        if [[ "$char" == $'\x1b' ]]; then
            IFS= read -r -s -n2 -t 0.05 _ || true
            echo
            echo
            echo "  Batal."
            sleep 0.4
            tput civis
            return
        fi

        if [[ "$char" == "" || "$char" == $'\r' ]]; then
            break
        fi

        if [[ "$char" == $'\x7f' || "$char" == $'\b' ]]; then
            if [[ ${#input} -gt 0 ]]; then
                input="${input%?}"
                printf '\b \b'
            fi
            continue
        fi

        input+="$char"
        if [[ "$secret" == "true" ]]; then
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
        tput civis
        return
    fi

    printf -v "$var_name" '%s' "$input"
    echo
    echo "  Tersimpan."
    sleep 0.5
    tput civis
}

# =========================
# RUN BENCH
# =========================
run_bench() {
    tput cnorm
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
tput civis  # sembunyikan cursor di menu

selected=0

while true; do
    draw_menu "$selected"

    # Baca input arrow / enter
    IFS= read -r -s -n1 char

    if [[ "$char" == $'\x1b' ]]; then
        IFS= read -r -s -n1 char2
        IFS= read -r -s -n1 char3

        if [[ "$char2" == "[" ]]; then
            case "$char3" in
                A)  # Arrow UP
                    (( selected = (selected - 1 + TOTAL_ITEMS) % TOTAL_ITEMS ))
                    ;;
                B)  # Arrow DOWN
                    (( selected = (selected + 1) % TOTAL_ITEMS ))
                    ;;
            esac
        fi
        continue
    fi

    # ENTER
    if [[ "$char" == "" || "$char" == $'\r' ]]; then
        if [[ "$selected" -lt "$MENU_ITEMS" ]]; then
            edit_value "${LABELS[$selected]}" "${KEYS[$selected]}"
        elif [[ "$selected" -eq "$IDX_APPLY" ]]; then
            run_bench
            exit 0
        elif [[ "$selected" -eq "$IDX_QUIT" ]]; then
            clear
            echo "  Keluar."
            exit 0
        fi
    fi

    # Shortcut q
    if [[ "$char" == "q" || "$char" == "Q" ]]; then
        clear
        echo "  Keluar."
        exit 0
    fi
done
