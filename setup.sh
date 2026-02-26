#!/usr/bin/env bash
set -euo pipefail

# =========================
# CLEANUP & TRAP
# =========================
cleanup() {
    tput cnorm 2>/dev/null
    tput rmcup 2>/dev/null
    echo
}
trap cleanup EXIT
trap 'cleanup; echo "Error pada baris $LINENO. Exiting."; exit 1' ERR

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

TOTAL_ITEMS=$(( ${#LABELS[@]} + 2 ))
MENU_ITEMS=${#LABELS[@]}
IDX_APPLY=${#LABELS[@]}
IDX_QUIT=$(( ${#LABELS[@]} + 1 ))

# =========================
# HELPERS
# =========================
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
        echo "••••••••"
    else
        echo "${!key}"
    fi
}

# Read a single keypress, output: UP, DOWN, ENTER, ESC, or the char itself
read_key() {
    local char char2 char3
    IFS= read -r -s -n1 char
    if [[ "$char" == $'\x1b' ]]; then
        IFS= read -r -s -n1 -t 0.1 char2 || { echo "ESC"; return; }
        IFS= read -r -s -n1 -t 0.1 char3 || { echo "ESC"; return; }
        if [[ "$char2" == "[" ]]; then
            case "$char3" in
                A) echo "UP" ;;
                B) echo "DOWN" ;;
                *) echo "ESC" ;;
            esac
        else
            echo "ESC"
        fi
    elif [[ "$char" == "" || "$char" == $'\r' ]]; then
        echo "ENTER"
    else
        echo "$char"
    fi
}

# =========================
# DRAW MENU
# =========================
draw_menu() {
    local selected="$1"
    local label_width=22
    local val_width=35

    # Colors
    local C_RESET='\e[0m'
    local C_HEADER='\e[1;36m'   # bold cyan
    local C_SEL='\e[1;33;44m'   # bold yellow on blue
    local C_LABEL='\e[0;37m'    # dim white
    local C_VAL='\e[1;32m'      # bold green
    local C_ACTION='\e[1;35m'   # bold magenta
    local C_BOX='\e[0;34m'      # blue

    clear
    printf "${C_HEADER}"
    printf "╔══════════════════════════════════════════════════════════╗\n"
    printf "║         🛠  Frappe Bench Interactive Setup               ║\n"
    printf "╚══════════════════════════════════════════════════════════╝\n"
    printf "${C_RESET}"
    printf "  ${C_BOX}▲/▼${C_RESET} navigasi   ${C_BOX}ENTER${C_RESET} pilih   ${C_BOX}Q${C_RESET} keluar\n"
    printf "\n"

    for i in "${!LABELS[@]}"; do
        local val
        val=$(get_display_value "${KEYS[$i]}")
        if [[ "$i" -eq "$selected" ]]; then
            printf "  ${C_SEL} ▶ %-${label_width}s  %-${val_width}s ${C_RESET}\n" "${LABELS[$i]}" "$val"
        else
            printf "    ${C_LABEL}%-${label_width}s${C_RESET}  ${C_VAL}%s${C_RESET}\n" "${LABELS[$i]}" "$val"
        fi
    done

    printf "\n"
    printf "  ${C_BOX}──────────────────────────────────────────────────────${C_RESET}\n"

    if [[ "$selected" -eq "$IDX_APPLY" ]]; then
        printf "  ${C_SEL} ▶ %-55s ${C_RESET}\n" "✅  Apply & Run"
    else
        printf "    ${C_ACTION}%-56s${C_RESET}\n" "✅  Apply & Run"
    fi

    if [[ "$selected" -eq "$IDX_QUIT" ]]; then
        printf "  ${C_SEL} ▶ %-55s ${C_RESET}\n" "❌  Quit"
    else
        printf "    ${C_ACTION}%-56s${C_RESET}\n" "❌  Quit"
    fi

    printf "\n"
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

    local C_RESET='\e[0m'
    local C_HEADER='\e[1;36m'
    local C_PROMPT='\e[1;33m'
    local C_INFO='\e[0;37m'
    local C_OK='\e[1;32m'
    local C_WARN='\e[1;31m'

    clear
    printf "${C_HEADER}╔══════════════════════════════════════════════════════════╗\n"
    printf "║  Edit: %-50s║\n" "$label"
    printf "╚══════════════════════════════════════════════════════════╝${C_RESET}\n\n"

    if [[ "$secret" == "true" ]]; then
        printf "  ${C_INFO}Nilai saat ini : ••••••••${C_RESET}\n"
    else
        printf "  ${C_INFO}Nilai saat ini : ${C_OK}%s${C_RESET}\n" "$current"
    fi

    printf "\n  ${C_INFO}ESC = batal │ ENTER = simpan${C_RESET}\n\n"
    printf "  ${C_PROMPT}Nilai baru : ${C_RESET}"

    local input=""
    local char

    tput cnorm  # tampilkan cursor saat edit

    while true; do
        IFS= read -r -s -n1 char

        if [[ "$char" == $'\x1b' ]]; then
            # Drain any remaining escape sequence bytes
            IFS= read -r -s -n2 -t 0.05 _ 2>/dev/null || true
            printf "\n\n  ${C_WARN}Batal.${C_RESET}\n"
            sleep 0.5
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
            printf '•'
        else
            printf '%s' "$char"
        fi
    done

    printf "\n"

    if [[ -z "$input" ]]; then
        printf "\n  ${C_WARN}Input kosong — nilai tidak diubah.${C_RESET}\n"
        sleep 0.8
        tput civis
        return
    fi

    printf -v "$var_name" '%s' "$input"
    printf "\n  ${C_OK}✔ Tersimpan.${C_RESET}\n"
    sleep 0.5
    tput civis
}

# =========================
# CONFIRM DIALOG
# =========================
confirm_run() {
    local C_RESET='\e[0m'
    local C_HEADER='\e[1;36m'
    local C_SEL='\e[1;33;44m'
    local C_NORMAL='\e[0;37m'
    local C_OK='\e[1;32m'
    local C_WARN='\e[1;31m'

    local selected=0  # 0 = Yes, 1 = No
    local options=("Ya, jalankan sekarang" "Tidak, kembali ke menu")

    while true; do
        clear
        printf "${C_HEADER}╔══════════════════════════════════════════════════════════╗\n"
        printf "║               ⚠  Konfirmasi Eksekusi                    ║\n"
        printf "╚══════════════════════════════════════════════════════════╝${C_RESET}\n\n"

        printf "  Konfigurasi yang akan digunakan:\n\n"
        printf "  ${C_OK}%-22s${C_RESET}: %s\n" "Frappe Version"  "$FRAPPE_VERSION"
        printf "  ${C_OK}%-22s${C_RESET}: %s\n" "Bench Name"      "$BENCH_NAME"
        printf "  ${C_OK}%-22s${C_RESET}: %s\n" "Site Name"       "$SITE_NAME"
        printf "  ${C_OK}%-22s${C_RESET}: %s\n" "DB Host:Port"    "$DB_HOST:$DB_PORT"
        printf "  ${C_OK}%-22s${C_RESET}: %s\n" "DB Name"         "$DB_NAME"
        printf "  ${C_OK}%-22s${C_RESET}: %s\n" "DB Root User"    "$DB_ROOT_USER"
        printf "\n"

        for i in "${!options[@]}"; do
            if [[ "$i" -eq "$selected" ]]; then
                printf "  ${C_SEL} ▶ %-52s ${C_RESET}\n" "${options[$i]}"
            else
                printf "    ${C_NORMAL}${options[$i]}${C_RESET}\n"
            fi
        done
        printf "\n"

        local key
        key=$(read_key)

        case "$key" in
            UP)   selected=$(( (selected - 1 + 2) % 2 )) ;;
            DOWN) selected=$(( (selected + 1) % 2 )) ;;
            ENTER)
                if [[ "$selected" -eq 0 ]]; then
                    return 0  # Yes
                else
                    return 1  # No
                fi
                ;;
            ESC|q|Q) return 1 ;;
        esac
    done
}

# =========================
# RUN BENCH
# =========================
run_bench() {
    tput cnorm
    clear

    local C_RESET='\e[0m'
    local C_HEADER='\e[1;36m'
    local C_OK='\e[1;32m'
    local C_STEP='\e[1;33m'

    printf "${C_HEADER}╔══════════════════════════════════════════════════════════╗\n"
    printf "║              🚀 Menjalankan Bench Setup                  ║\n"
    printf "╚══════════════════════════════════════════════════════════╝${C_RESET}\n\n"

    printf "${C_STEP}[1/3] Inisialisasi bench...${C_RESET}\n"
    bench init \
        --skip-redis-config-generation \
        --ignore-exist \
        --frappe-branch="$FRAPPE_VERSION" \
        --dev \
        "$BENCH_NAME"

    cd "$BENCH_NAME"

    printf "\n${C_STEP}[2/3] Set konfigurasi global...${C_RESET}\n"
    bench set-config -g db_host        "$DB_HOST"
    bench set-config -g db_port        "$DB_PORT"
    bench set-config -g redis_cache    "$REDIS_CACHE"
    bench set-config -g redis_queue    "$REDIS_QUEUE"
    bench set-config -g redis_socketio "$REDIS_SOCKETIO"

    printf "\n${C_STEP}[3/3] Membuat site baru...${C_RESET}\n"
    bench new-site \
        --db-name="$DB_NAME" \
        --db-root-username="$DB_ROOT_USER" \
        --db-root-password="$DB_ROOT_PASS" \
        --admin-password="$ADMIN_PASS" \
        --mariadb-user-host-login-scope="%" \
        "$SITE_NAME"

    printf "\n${C_OK}✔ Setup selesai!${C_RESET}\n\n"
}

# =========================
# MAIN LOOP
# =========================
tput smcup 2>/dev/null || true  # gunakan alternate screen buffer
tput civis                       # sembunyikan cursor di menu

selected=0

while true; do
    draw_menu "$selected"

    key=$(read_key)

    case "$key" in
        UP)
            (( selected = (selected - 1 + TOTAL_ITEMS) % TOTAL_ITEMS ))
            ;;
        DOWN)
            (( selected = (selected + 1) % TOTAL_ITEMS ))
            ;;
        ENTER)
            if [[ "$selected" -lt "$MENU_ITEMS" ]]; then
                edit_value "${LABELS[$selected]}" "${KEYS[$selected]}"
            elif [[ "$selected" -eq "$IDX_APPLY" ]]; then
                if confirm_run; then
                    tput rmcup 2>/dev/null || true
                    run_bench
                    exit 0
                fi
            elif [[ "$selected" -eq "$IDX_QUIT" ]]; then
                break
            fi
            ;;
        q|Q|ESC)
            break
            ;;
    esac
done

tput rmcup 2>/dev/null || true
echo "  Keluar."
