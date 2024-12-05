#!/bin/bash

# Gaya Teks
NORMAL='\033[0m'
BOLD='\033[1m'
UNDERLINE='\033[4m'

# Text Colors
BLACK='\033[0;30m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[0;37m'

# Bold Text Colors
BOLD_BLACK='\033[1;30m'
BOLD_RED='\033[1;31m'
BOLD_GREEN='\033[1;32m'
BOLD_YELLOW='\033[1;33m'
BOLD_BLUE='\033[1;34m'
BOLD_MAGENTA='\033[1;35m'
BOLD_CYAN='\033[1;36m'
BOLD_WHITE='\033[1;37m'

# Fungsi cek root user ============================================================================>
check_root() {
  if [ "$(id -u)" != "0" ]; then
    echo -e "${BOLD_MAGENTA}Jalankan script ini sebagai root!!!${NORMAL}"
    exit 1
  fi
}

BACKUP_DIR=/backup

# Restore Layanan
restore_service() {
    local service="$1"
    local path="$2"
    local backup_path="$BACKUP_DIR/backup_default/backup_${service}_default"

    echo -e "${BOLD_GREEN}[SYSTEM]: Melakukan restore untuk ${service}...${NORMAL}"

    if [ ! -d "$backup_path" ]; then
        echo -e "${BOLD_RED}[ERROR]: Backup untuk ${service} tidak ditemukan di ${backup_path}.${NORMAL}"
        return 1
    fi

    if rsync -av --delete "$backup_path"/ "$path"; then
        echo -e "${BOLD_GREEN}[INFO]: Restore untuk ${service} selesai dengan sukses.${NORMAL}"
    else
        echo -e "${BOLD_RED}[ERROR]: Terjadi kesalahan saat melakukan restore untuk ${service}.${NORMAL}"
    fi
    sleep 0.5;clear
}

# Fungsi untuk merestore satu layanan berdasarkan pilihan
restore_service_log() {
    local SERVICE=$1
    if [[ "$SERVICE" == "apache2" ]]; then
        restore_service "$SERVICE" "/etc/apache2"
        echo -e "${BOLD_YELLOW}Mengembalikan konten /var/www...${NORMAL}"
        rsync -av --delete "$BACKUP_DIR/backup_www_default/www/" /var/www/
    else
        restore_service "$SERVICE" "/etc/$SERVICE"
    fi
}

# Tampilan UI untuk memilih layanan yang akan di-restore
restore_menu() {
    echo -e "${BOLD_GREEN}====== Menu Restore Layanan ======${NORMAL}"
    echo -e "${BOLD_WHITE}1. Samba ${NORMAL}"
    echo -e "${BOLD_WHITE}2. Bind9 ${NORMAL}"
    echo -e "${BOLD_WHITE}3. Apache2 ${NORMAL}"
    echo -e "${BOLD_WHITE}4. MySQL ${NORMAL}"
    echo -e "${BOLD_WHITE}5. DHCP ${NORMAL}"
    echo -e "${BOLD_WHITE}6. SSH ${NORMAL}"
    echo -e "${BOLD_WHITE}7. Postfix ${NORMAL}"
    echo -e "${BOLD_WHITE}8. Dovecot ${NORMAL}"
    echo -e "${BOLD_WHITE}9. Roundcube ${NORMAL}"
    echo -e "${BOLD_BLUE}10. Semua (Restore Semua Layanan) ${NORMAL}"
    echo -e "${BOLD_RED}11. Keluar ${NORMAL}"
    echo -e "${BOLD_GREEN}========================================${NORMAL}"
    echo -e -n "${BOLD_YELLOW}Pilih nomor layanan yang ingin di-restore (1-11): ${NORMAL}" 
    read choice
    
    case $choice in
        1)
            restore_service_log "samba"
            systemctl restart smbd
            ;;
        2)
            restore_service_log "bind"
            systemctl restart bind9
            ;;
        3)
            restore_service_log "apache2"
            systemctl restart apache2
            ;;
        4)
            restore_service_log "mysql"
            systemctl restart mysql
            ;;
        5)
            restore_service_log "dhcp"
            systemctl restart isc-dhcp-server
            ;;
        6)
            restore_service_log "ssh"
            systemctl restart ssh
            ;;
        7)
            restore_service_log "postfix"
            systemctl restart postfix
            ;;
        8)
            restore_service_log "dovecot"
            systemctl restart dovecot
            ;;
        9)
            restore_service_log "roundcube"
            systemctl restart apache2  # atau tambahkan perintah untuk php-fpm jika diperlukan
            ;;
        10)
            # Restore semua layanan
            echo -e "${BOLD_GREEN}[SYSTEM]: Merestore semua layanan...${NORMAL}"
            restore_service_log "samba"
            systemctl restart smbd
            restore_service_log "bind"
            systemctl restart bind9
            restore_service_log "apache2"
            systemctl restart apache2
            restore_service_log "mysql"
            systemctl restart mysql
            restore_service_log "dhcp"
            systemctl restart isc-dhcp-server
            restore_service_log "ssh"
            systemctl restart ssh
            restore_service_log "postfix"
            systemctl restart postfix
            restore_service_log "dovecot"
            systemctl restart dovecot
            restore_service_log "roundcube"
            systemctl restart apache2  # atau tambahkan perintah untuk php-fpm jika diperlukan
            ;;
        11)
            echo -e "${BOLD_MAGENTA}[SYSTEM]: Keluar dari script.${NORMAL}"
            exit 0
            ;;
        *)
            echo -e "${BOLD_RED}[ERROR]: Pilihan tidak valid. Harap pilih angka antara 1 dan 11.${NORMAL}"
            continue
            ;;
    esac
    sleep 0.5;clear
}

check_root
# Menampilkan header sebelum prompt konfirmasi
echo -e "${BOLD_MAGENTA}
      ____               _          _       
     |  _ \             | |        (_)      
     | |_) |  ___   __ _| |_  _ __ _ __  __ 
     |  _ <  / _ \ / _\` | __|| '__| |\ \/ / 
     | |_) ||  __/| (_| | |_ | |   | | >  <  
     |____/  \___| \__,_|\__||_|   |_|/_/\_\ 
    ${NORMAL}"
echo -e "${BOLD_WHITE}~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ${NORMAL}"
echo -e "${BOLD_WHITE}Apakah Anda ingin melakukan restore server? (y/n)${NORMAL}"
read -r CHOICE_R

if [[ "$CHOICE_R" != "y" && "$CHOICE_R" != "Y" ]]; then
    echo -e "${BOLD_MAGENTA}[SYSTEM]: Proses restore dibatalkan. Keluar dari script.${NORMAL}"
    exit 0
fi

while true; do
restore_menu

done
