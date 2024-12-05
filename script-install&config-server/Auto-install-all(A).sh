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

# Background Colors
BG_BLACK='\033[40m'
BG_RED='\033[41m'
BG_GREEN='\033[42m'
BG_YELLOW='\033[43m'
BG_BLUE='\033[44m'
BG_MAGENTA='\033[45m'
BG_CYAN='\033[46m'
BG_WHITE='\033[47m'

# <========================================================|MAIN FUNGCTION|========================================================>

# fungsi cek root user ============================================================================>
check_root() {
  if [ "$(id -u)" != "0" ]; then
    echo "${BOLD_MAGENTA}Jalankan script ini sebagai root!!!"
    exit 1
  fi
}

# Fungsi untuk memvalidasi IP address ============================================================================>
validate_ip() {
    local ip=$1
    local stat=1

    # Memeriksa format IP (x.x.x.x), setiap bagian antara 0-255
    if [[ $ip =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        IFS='.' read -r i1 i2 i3 i4 <<< "$ip"
        if [[ $i1 -le 255 && $i2 -le 255 && $i3 -le 255 && $i4 -le 255 ]]; then
            stat=0
        fi
    fi
    return $stat
}

# Fungsi untuk mengkonversi CIDR menjadi subnet mask ============================================================================>
cidr_to_netmask() {
    local CIDR=$1
    local MASK=""
    local FULL_OCTETS=$((CIDR / 8))
    local REMAINDER=$((CIDR % 8))

    for ((i = 0; i < 4; i++)); do
        if [ $i -lt $FULL_OCTETS ]; then
            MASK+="255"
        elif [ $i -eq $FULL_OCTETS ]; then
            MASK+=$((256 - 2**(8 - REMAINDER)))
        else
            MASK+="0"
        fi

        # Tambahkan titik antara oktet, kecuali yang terakhir
        if [ $i -lt 3 ]; then
            MASK+="."
        fi
    done

    echo $MASK
}

# Fungsi untuk mengonversi subnetmask ke CIDR ============================================================================>
netmask_to_cidr() {
    local netmask=$1
    local x=$(echo "$netmask" | awk -F"." '{print ($1*256^3) + ($2*256^2) + ($3*256) + $4}')
    local cidr=$(awk -v num="$x" 'BEGIN {
        for (i = 32; i > 0; i--) {
            if (and(2^(32-i), num)) {
                break
            }
        }
        print i
    }')
    echo $cidr
}

# Fungsi untuk memvalidasi format domain
validate_domain() {
    local domain="$1"
    
    # Regex untuk validasi domain
    local regex='^(([a-zA-Z0-9]|[a-zA-Z0-9]-[a-zA-Z0-9]+)*\.)+[a-zA-Z]{2,}$'
    
    if [[ $domain =~ $regex ]]; then
        return 0  # Valid
    else
        return 1  # Tidak valid
    fi
}

# Fungsi untuk memvalidasi input interface ============================================================================>
validate_interface() {
    local interface="$1"
    
    # Loop hingga user memasukkan enp0s3 atau enp0s8
    while [[ "$interface" != "enp0s3" && "$interface" != "enp0s8" ]]; do
        echo -e "${BOLD_RED}[ERROR]: Interface yang valid hanya enp0s3 atau enp0s8.${NORMAL}"
        echo -e "${BOLD_YELLOW}Masukkan nama interface yang valid (enp0s3/enp0s8): ${NORMAL}"
        read interface
    done
    
    echo "$interface"  # Return the valid interface
}

# Fungsi validasi interface type ============================================================================>
validate_interface_type() {
    local type="$1"
    while [[ "$type" != "static" && "$type" != "dhcp" ]]; do
        echo -e "${BOLD_RED}[ERROR]: Tipe konfigurasi tidak valid! Masukkan 'static' atau 'dhcp'.${NORMAL}"
        echo -e "${BOLD_YELLOW}Masukkan tipe konfigurasi (static/dhcp): ${NORMAL}" 
        read type
    done
    echo "$type"
}

# Fungsi untuk menampilkan semua interface yang aktif ============================================================================>
show_active_interfaces() {
    echo -e "${BOLD_WHITE}================================================${NORMAL}"   
    echo -e "${BOLD_CYAN}[INFO]: Menampilkan semua interface yang aktif:${NORMAL}"
    echo -e "${BOLD_WHITE}================================================${NORMAL}"   
    for INTERFACE in $(ip link show | grep 'state UP' | awk -F ': ' '{print $2}'); do
        get_interface_info "$INTERFACE"
    done
}

show_all_interfaces() {
    echo -e "${BOLD_WHITE}====================================================${NORMAL}"
    echo -e "${BOLD_CYAN}[INFO]: Menampilkan semua interface yang tersedia:${NORMAL}"
    echo -e "${BOLD_WHITE}====================================================${NORMAL}"

    local count=1
    for interface in $(ip link show | awk -F ': ' '{print $2}' | grep -v lo); do
        # Mengambil status interface
        STATUS=$(ip addr show $interface | grep -oP '(?<=state )\w+')
        # Mengambil alamat IP
        IP_ADDRESS=$(ip addr show $interface | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)

        # Menentukan warna berdasarkan status
        if [[ "$STATUS" == "UP" ]]; then
            INTERFACE_COLOR="${BOLD_GREEN}"
        else
            INTERFACE_COLOR="${BOLD_RED}"
        fi

        echo -e "${INTERFACE_COLOR}[$count] $interface - Status: $STATUS, IP: ${IP_ADDRESS:-'Tidak ada IP'}${NORMAL}"
        count=$((count + 1))
    done
}

# Fungsi untuk menampilkan detail dari interface ============================================================================>
get_interface_info() {
  INTERFACE=$1

  # Mengambil status interface (UP atau DOWN)
  STATUS=$(ip addr show $INTERFACE | grep -oP '(?<=state )\w+')

  # Mengambil alamat IP (inet)
  IP_ADDRESS=$(ip addr show $INTERFACE | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)

  # Mengambil notasi CIDR
  CIDR=$(ip addr show $INTERFACE | grep 'inet ' | awk '{print $2}')
  
  # Memisahkan CIDR (misalnya 192.168.1.100/24 -> 24)
  CIDR_PREFIX=$(echo $CIDR | cut -d/ -f2)

  # Mengambil broadcast address
  BROADCAST=$(ip addr show $INTERFACE | grep 'inet ' | awk '{print $4}')
  
  # Mengambil alamat IP network 
  NETWORK=$(ip route show dev $INTERFACE | grep proto | awk '{print $1}' | cut -d/ -f1)
  
  # Mengambil subnet mask dari CIDR prefix
  SUBNETMASK=$(cidr_to_netmask $CIDR_PREFIX)

  # Menentukan warna berdasarkan status interface
  if [[ "$STATUS" == "UP" ]]; then
    COLOR="${BOLD_GREEN}"
  else
    COLOR="${BOLD_MAGENTA}"
  fi

  # Menampilkan informasi dengan warna berdasarkan status
  echo -e "${COLOR}Interface         : $INTERFACE ${NORMAL}"
  echo -e "${COLOR}Status            : $STATUS ${NORMAL}"
  echo -e "${COLOR}IP Address        : $IP_ADDRESS ${NORMAL}"
  echo -e "${COLOR}Network           : $NETWORK ${NORMAL}"
  echo -e "${COLOR}Subnet Mask       : $SUBNETMASK ${NORMAL}"
  echo -e "${COLOR}Broadcast Address : $BROADCAST ${NORMAL}"
  echo -e "${COLOR}CIDR Notation     : $CIDR_PREFIX ${NORMAL}"
  echo -e "${COLOR}------------------------------------------------ ${NORMAL}"
  echo ""
}

# Direktori Backup
BACKUP_DIR="/backup/backup_default"

# Backup tanpa direktori ganda
backup_server_data() {
    echo -e "${BOLD_WHITE}[SYSTEM]: Melakukan Backup Layanan Server...${NORMAL}"

    # Cek jika direktori backup tidak ada
    if [ ! -d "$BACKUP_DIR" ]; then
        echo -e "${BOLD_MAGENTA}[INFO]: Direktori backup_default tidak ada. Membuat direktori ${BACKUP_DIR}${NORMAL}"
        mkdir -p "$BACKUP_DIR"
    fi

    SERVICES=(samba apache2 postfix bind dovecot mysql roundcube dhcp ssh)

    for SERVICE in "${SERVICES[@]}"; do
        SERVICE_SPECIFIC_BACKUP_DIR="$BACKUP_DIR/backup_${SERVICE}_default"
        mkdir -p "$SERVICE_SPECIFIC_BACKUP_DIR"

        WWW_BACKUP_DIR="$BACKUP_DIR/backup_www_default"
        mkdir -p "$WWW_BACKUP_DIR"

        case $SERVICE in
            samba)
                cp -r /etc/samba/* "$SERVICE_SPECIFIC_BACKUP_DIR"
                ;;
            apache2)
                cp -r /etc/apache2/* "$SERVICE_SPECIFIC_BACKUP_DIR"
                cp -r /var/www/* "$WWW_BACKUP_DIR"
                ;;
            postfix)
                cp -r /etc/postfix/* "$SERVICE_SPECIFIC_BACKUP_DIR"
                ;;
            bind)
                cp -r /etc/bind/* "$SERVICE_SPECIFIC_BACKUP_DIR"
                ;;
            dovecot)
                cp -r /etc/dovecot/* "$SERVICE_SPECIFIC_BACKUP_DIR"
                ;;
            mysql)
                cp -r /etc/mysql/* "$SERVICE_SPECIFIC_BACKUP_DIR"
                ;;
            roundcube)
                cp -r /etc/roundcube/* "$SERVICE_SPECIFIC_BACKUP_DIR"
                ;;
            dhcp)
                cp -r /etc/dhcp/* "$SERVICE_SPECIFIC_BACKUP_DIR"
                ;;
            ssh)
                cp -r /etc/ssh/* "$SERVICE_SPECIFIC_BACKUP_DIR"
                ;;
            *)
                echo -e "${BOLD_RED}[ERROR]: Layanan $SERVICE tidak dikenali.${NORMAL}"
                ;;
        esac
        if [[ $? -ne 0 ]]; then
            echo -e "${BOLD_RED}[ERROR]: Terjadi kesalahan saat melakukan backup untuk $SERVICE.${NORMAL}"
            exit 1
        fi
        echo -e "${BOLD_BLUE}[INFO]: Backup untuk $SERVICE selesai di: ${BOLD_GREEN}$SERVICE_SPECIFIC_BACKUP_DIR${NORMAL}"
    done
}

# Fungsi untuk instalasi server ============================================================================>
install_server() {
    clear
    echo -e "${BOLD_MAGENTA}
      ____               _          _       
     |  _ \             | |        (_)      
     | |_) |  ___   __ _| |_  _ __ _ __  __ 
     |  _ <  / _ \ / _\` | __|| '__| |\ \/ / 
     | |_) ||  __/| (_| | |_ | |   | | >  <  
     |____/  \___| \__,_|\__||_|   |_|/_/\_\ 
    ${NORMAL}"
    echo -e "${BOLD_WHITE}~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ${NORMAL}" 
    echo -e "${BOLD_WHITE}[SYSTEM]: Apakah Anda Ingin Menjalankan Script ini? (y/n): ${NORMAL}" 
    read first
        if [[ "$first" != "y" && "$first" != "Y" ]]; then
        echo -e "${BOLD_MAGENTA}[SYSTEM]: Anda Tidak Menjalankan Script, Script Akan Berhenti ${NORMAL}"
        exit 1
        fi

    echo -e "${BOLD_YELLOW}Masukkan password root yang akan digunakan untuk MariaDB (contoh: 123/abc): ${NORMAL}" 
    read -s sandi

    echo -e "${BOLD_CYAN}[INFO]: Menambahkan CD-ROM dan memperbarui daftar paket... ${NORMAL}"
    /usr/bin/apt-cdrom add && /usr/bin/apt-get update

    # Set DEBIAN_FRONTEND untuk instalasi tanpa interaksi
    export DEBIAN_FRONTEND=noninteractive

    echo -e "${BOLD_WHITE}========================================================= ${NORMAL}"
    echo -e "${BOLD_CYAN}[SYSTEM]: Melakukan Instalasi Layanan Package Server... ${NORMAL}"
    echo -e "${BOLD_WHITE}========================================================= ${NORMAL}"
    echo ""

    # Mengatur jawaban debconf untuk instalasi otomatis
    echo "postfix postfix/main_mailer_type select Internet Site" | debconf-set-selections
    echo "postfix postfix/mailname string localhost" | debconf-set-selections
    echo "mariadb-server mysql-server/root_password password $sandi" | debconf-set-selections
    echo "mariadb-server mysql-server/root_password_again password $sandi" | debconf-set-selections
    echo "samba-common samba-common/dhcp boolean false" | debconf-set-selections
    if ! apt-get install -y ssh samba proftpd bind9 dnsutils apache2 dovecot-imapd dovecot-pop3d mariadb-server postfix roundcube isc-dhcp-server rsync; then
        echo -e "${BOLD_RED}[ERROR]: Terjadi kesalahan saat menginstal layanan. Mengulang update repository dan mencoba instalasi lagi... ${NORMAL}"
        apt-get update
        if ! apt-get install -y ssh samba proftpd bind9 dnsutils apache2 dovecot-imapd dovecot-pop3d mariadb-server postfix roundcube isc-dhcp-server; then
            echo -e "${BOLD_RED}[INFO]: Instalasi layanan gagal setelah percobaan kedua. Skrip akan berhenti.${NORMAL}"
            exit 1
        fi
    fi
    echo ""
    echo -e "${BOLD_WHITE}========================================== ${NORMAL}"
    echo -e "${BOLD_BLUE}[INFO]: Installasi Package Server Selesai ${NORMAL}"
    echo -e "${BOLD_WHITE}========================================== ${NORMAL}"
    backup_server_data
    sleep 4; clear
}

# Fungsi konfigurasi jaringan ============================================================================>
configure_network() {
    clear
    echo -e "${BOLD_WHITE}========================================= ${NORMAL}"
    echo -e "${BOLD_BLUE}[SYSTEM]: Memulai Konfigurasi Jaringan...${NORMAL}"
    echo -e "${BOLD_WHITE}========================================= ${NORMAL}"
    echo ""

    echo -e "${BOLD_WHITE}====================================================${NORMAL}"
    echo -e "${BOLD_CYAN}[INFO]: Menampilkan semua interface yang tersedia:${NORMAL}"
    echo -e "${BOLD_WHITE}====================================================${NORMAL}"
    echo ""
    # Daftar semua interface aktif pada sistem
    for INTERFACE in $(ip -o link show | awk -F': ' '{print $2}'); do
        get_interface_info $INTERFACE  # Menampilkan informasi dari masing-masing interface
    done

    # Menentukan apakah akan menggunakan interface1
    echo ""
    echo -e "${BOLD_YELLOW}Apakah Anda ingin menggunakan interface pertama? (y/n): ${NORMAL}"
    read use_interface1
    echo ""

    if [[ "$use_interface1" == "y" || "$use_interface1" == "Y" ]]; then
        # Menentukan interface pertama
        echo -e "${BOLD_YELLOW}Masukkan nama interface pertama (contoh: enp0s3/enp0s8): ${NORMAL}"
        read interface1
        interface1=$(validate_interface "$interface1")  # Memvalidasi input interface1

        # Validasi input interface1
        if [[ -z "$interface1" ]]; then
            echo -e "${BOLD_RED}[ERROR]: Interface pertama tidak boleh kosong! ${NORMAL}"
            exit 1
        fi

        # Menanyakan jenis konfigurasi interface1 (static atau dhcp)
        while true; do
            echo -e "${BOLD_YELLOW}Apakah interface $interface1 menggunakan konfigurasi static atau dhcp? ('static'/'dhcp'): ${NORMAL}"
            read interface1_type
            interface1_type=$(validate_interface_type "$interface1_type")  # Validasi input interface1_type

            if [[ "$interface1_type" == "static" || "$interface1_type" == "dhcp" ]]; then
                break
            else
                echo -e "${BOLD_RED}[ERROR]: Input tidak valid. Pastikan untuk memasukkan 'static' atau 'dhcp'.${NORMAL}"
            fi
        done

        # Jika static, minta input IP, CIDR, dan gateway
        if [[ "$interface1_type" == "static" ]]; then
            echo -e "${BOLD_YELLOW}Masukkan IP address untuk $interface1 (contoh: 192.10.10.1): ${NORMAL}"
            read ip1
            while ! validate_ip "$ip1"; do
                echo -e "${BOLD_RED}[ERROR]: IP address tidak valid! Silakan masukkan lagi ${NORMAL}"
                echo -e "${BOLD_YELLOW}Masukkan IP address yang valid untuk $interface1: ${NORMAL}" 
                read ip1
            done
            echo -e "${BOLD_CYAN}[INFO]: Tidak perlu menggunakan / ${NORMAL}"
            echo -e "${BOLD_YELLOW}Masukkan CIDR untuk $interface1 (contoh: 24): ${NORMAL}"
            read cidr1

            # Konversi CIDR ke netmask
            netmask1=$(cidr_to_netmask "$cidr1")
            
            # Hapus konfigurasi lama untuk interface1, jika ada
            if grep -q "^auto $interface1" /etc/network/interfaces; then
                echo -e "${BOLD_CYAN}[INFO]: Menghapus konfigurasi lama untuk interface: $interface1...${NORMAL}"
                sed -i "/^auto $interface1/,/^$/d" /etc/network/interfaces
            fi

            # Konfigurasi interface1
            echo -e "${BOLD_CYAN}[INFO]: Mengonfigurasi interface $interface1 dengan IP: $ip1, Netmask: $netmask1...${NORMAL}"
            echo -e "\nauto $interface1\niface $interface1 inet static\n\taddress $ip1\n\tnetmask $netmask1" >> /etc/network/interfaces
        elif [[ "$interface1_type" == "dhcp" ]]; then
            # Hapus konfigurasi lama untuk interface1, jika ada
            if grep -q "^auto $interface1" /etc/network/interfaces; then
                echo -e "${BOLD_CYAN}[INFO]: Menghapus konfigurasi lama untuk interface: $interface1...${NORMAL}"
                sed -i "/^auto $interface1/,/^$/d" /etc/network/interfaces
            fi
            
            echo -e "${BOLD_CYAN}[INFO]: Mengonfigurasi interface $interface1 untuk menggunakan DHCP...${NORMAL}"
            echo -e "\nauto $interface1\niface $interface1 inet dhcp" >> /etc/network/interfaces
        else
            echo -e "${BOLD_RED}[ERROR]: Tipe konfigurasi tidak valid untuk interface $interface1 ${NORMAL}"
            exit 1
        fi

        # Menanyakan apakah ingin menambahkan interface kedua
        echo -e "${BOLD_YELLOW}Apakah Anda ingin menambahkan interface kedua? (y/n): ${NORMAL}"
        read add_second_interface
        echo ""

        if [[ "$add_second_interface" == "y" ]]; then
            # Menentukan interface kedua
            echo -e "${BOLD_YELLOW}Masukkan nama interface kedua (contoh: enp0s3/enp0s8): ${NORMAL}"
            read interface2
            interface2=$(validate_interface "$interface2")  # Memvalidasi input interface2

            # Validasi input interface2
            if [[ -z "$interface2" ]]; then
                echo -e "${BOLD_RED}[ERROR]: Interface kedua tidak boleh kosong!${NORMAL}"
                exit 1
            fi

            # Menanyakan jenis konfigurasi interface2 (static atau dhcp)
            while true; do
                echo -e "${BOLD_YELLOW}Apakah interface $interface2 menggunakan konfigurasi static atau dhcp? ('static'/'dhcp'): ${NORMAL}"
                read interface2_type
                interface2_type=$(validate_interface_type "$interface2_type")  # Validasi input interface2_type

                if [[ "$interface2_type" == "static" || "$interface2_type" == "dhcp" ]]; then
                    break
                else
                    echo -e "${BOLD_RED}[ERROR]: Input tidak valid. Pastikan untuk memasukkan 'static' atau 'dhcp'.${NORMAL}"
                fi
            done

            # Jika static, minta input IP, CIDR, dan gateway
            if [[ "$interface2_type" == "static" ]]; then
                echo -e "${BOLD_YELLOW}Masukkan IP address untuk $interface2 (contoh: 192.10.10.1): ${NORMAL}"
                read ip2
                while ! validate_ip "$ip2"; do
                    echo -e "${BOLD_RED}[ERROR]: IP address tidak valid! Silakan masukkan lagi.${NORMAL}"
                    echo -e "${BOLD_YELLOW}Masukkan IP address yang valid untuk $interface2: ${NORMAL}" 
                    read ip2
                done
                echo -e "${BOLD_CYAN}[INFO]: Tidak perlu menggunakan / ${NORMAL}"
                echo -e "${BOLD_YELLOW}Masukkan CIDR untuk $interface2 (contoh: 24): ${NORMAL}"
                read cidr2

                # Konversi CIDR ke netmask
                netmask2=$(cidr_to_netmask "$cidr2")

                # Hapus konfigurasi lama untuk interface2, jika ada
                if grep -q "^auto $interface2" /etc/network/interfaces; then
                    echo -e "${BOLD_CYAN}[INFO]: Menghapus konfigurasi lama untuk interface: $interface2...${NORMAL}"
                    sed -i "/^auto $interface2/,/^$/d" /etc/network/interfaces
                fi
                
                # Konfigurasi interface2
                echo -e "${BOLD_CYAN}[INFO]: Mengonfigurasi interface $interface2 dengan IP: $ip2, Netmask: $netmask2...${NORMAL}"
                echo -e "\nauto $interface2\niface $interface2 inet static\n\taddress $ip2\n\tnetmask $netmask2" >> /etc/network/interfaces
            elif [[ "$interface2_type" == "dhcp" ]]; then
                # Hapus konfigurasi lama untuk interface2, jika ada
                if grep -q "^auto $interface2" /etc/network/interfaces; then
                    echo -e "${BOLD_YELLOW}[INFO]: Menghapus konfigurasi lama untuk interface: $interface2...${NORMAL}"
                    sed -i "/^auto $interface2/,/^$/d" /etc/network/interfaces
                fi
                
                echo -e "${BOLD_CYAN}[INFO]: Mengonfigurasi interface $interface2 untuk menggunakan DHCP... ${NORMAL}"
                echo -e "\nauto $interface2\niface $interface2 inet dhcp" >> /etc/network/interfaces
            else
                echo -e "${BOLD_RED}[ERROR]: Tipe konfigurasi tidak valid untuk interface $interface2.${NORMAL}"
                exit 1
            fi
        else
            # Jika user memilih tidak, kosongkan variabel interface2 agar tidak digunakan nanti
            echo -e "${BOLD_MAGENTA}[INFO]: Melewati Konfigurasi interface2... ${NORMAL}"
            interface2=""
        fi
    else
        echo -e "${BOLD_MAGENTA}[INFO]: Melewati konfigurasi interface1 dan interface2... ${NORMAL}"
        interface1=""
        interface2=""
    fi

    # Mendefinisikan interface yang ingin dikelola
    interfaces=()

    # Tambahkan interface1 dan interface2 jika ada
    if [[ -n "$interface1" ]]; then
        interfaces+=("$interface1")
    fi
    if [[ -n "$interface2" ]]; then
        interfaces+=("$interface2")
    fi

# Melakukan down/up untuk kedua interface yang ditentukan
if [[ ${#interfaces[@]} -gt 0 ]]; then
    for interface in "${interfaces[@]}"; do
        # Mengecek apakah interface aktif
        if ip link show "$interface" | grep -q "state UP"; then
            if grep -q "iface $interface inet dhcp" /etc/network/interfaces; then
                echo -e "${BOLD_CYAN}[SYSTEM]: Mengaktifkan DHCP pada $interface di latar belakang...${NORMAL}"
                dhclient "$interface" &  # Menjalankan dhclient di background
            else
                echo -e "${BOLD_MAGENTA}[SYSTEM]: Menonaktifkan interface: $interface ${NORMAL}"
                
                ifdown "$interface"
                sleep 2

                echo -e "${BOLD_GREEN}[SYSTEM]: Mengaktifkan interface: $interface ${NORMAL}"
                
                ifup "$interface"
                sleep 2
            fi
        else
            echo -e "${BOLD_GREEN}[SYSTEM]: Mengaktifkan interface: $interface${NORMAL}"
            
            ifup "$interface"
            sleep 2
        fi
    done
fi
    
    echo -e "${BOLD_WHITE}====================================================${NORMAL}"
    echo -e "${BOLD_CYAN}[INFO]: Menampilkan semua interface yang tersedia:${NORMAL}"
    echo -e "${BOLD_WHITE}====================================================${NORMAL}"
    echo ""
    for INTERFACE in $(ip -o link show | awk -F': ' '{print $2}'); do
        get_interface_info $INTERFACE  # Menampilkan informasi dari masing-masing interface
    done
    sleep 3
    echo ""
    echo -e "${BOLD_WHITE}========================================= ${NORMAL}"
    echo -e "${BOLD_BLUE}[SYSTEM]: Konfigurasi Jaringan Selesai ${NORMAL}"
    echo -e "${BOLD_WHITE}========================================= ${NORMAL}"
    sleep 3; clear
}

### konfigurasi ssh ============================================================================>
configure_ssh() {
    clear
echo -e "${BOLD_WHITE}=========================================== ${NORMAL}"
echo -e "${BOLD_BLUE}[SYSTEM]: Melakukan Konfigurasi SSH Server ${NORMAL}"
echo -e "${BOLD_WHITE}=========================================== ${NORMAL}"
echo ""

echo -e "${BOLD_CYAN}[INFO]: Mengizinkan login root melalui SSH... ${NORMAL}"
sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config

# Memulai ulang layanan ssh
    echo -e "${BOLD_GREEN}[SYSTEM]: Memulai ulang layanan SSH Server... ${NORMAL}"
    if ! systemctl restart ssh; then
        echo -e "${BOLD_RED}[ERROR]: Gagal me-restart SSH Server ${NORMAL}"
        exit 1
    fi

echo ""
echo -e "${BOLD_WHITE}========================================= ${NORMAL}"
echo -e "${BOLD_BLUE}[SYSTEM]: Konfigurasi SSH Server Selesai ${NORMAL}"
echo -e "${BOLD_WHITE}========================================= ${NORMAL}"
sleep 2;clear
}

### konfigurasi samba ============================================================================>
configure_samba() {
  # Menambahkan validasi untuk memulai konfigurasi Samba
    echo -e "${BOLD_WHITE}===== Konfigurasi Samba Server ===== ${NORMAL}"
    echo -e "${BOLD_YELLOW}Apakah Anda ingin melakukan konfigurasi Samba Server? (y/n): ${NORMAL}"
    read config_samba
    echo ""

    if [[ "$config_samba" =~ ^[Nn]$ ]]; then
        echo -e "${BOLD_MAGENTA}[INFO]: Melewati konfigurasi Samba Server ${NORMAL}"
        echo ""
        return 0  # Melewati fungsi jika pengguna memilih 'n'
    fi
  
  clear
  echo -e "${BOLD_WHITE}===================================== ${NORMAL}"
  echo -e "${BOLD_BLUE}[SYSTEM]: Melakukan konfigurasi Samba ${NORMAL}"
  echo -e "${BOLD_WHITE}===================================== ${NORMAL}"
  echo ""

  # Validasi untuk menambah Samba share
  num_shares=0
  for i in {1..3}; do
    if [[ $num_shares -gt 0 ]]; then
      echo -e "${BOLD_YELLOW}Apakah Anda ingin menambahkan Samba share lainnya? (y/n): ${NORMAL}"
    else
      echo -e "${BOLD_YELLOW}Apakah Anda ingin menambahkan Samba share ke-$i? (y/n): ${NORMAL}"
    fi
    read add_share
    echo ""

    if [[ "$add_share" =~ ^[Yy]$ ]]; then
      num_shares=$((num_shares + 1))
      echo -e "${BOLD_YELLOW}Konfigurasi ke-$i ${NORMAL}"

      # Memisahkan input
      echo -e "${BOLD_CYAN}[INFO]: Tidak perlu menambahkan '[]' ${NORMAL}"
      echo -e "${BOLD_YELLOW}Masukkan nama Samba share (contoh: Judul / Var / data): ${NORMAL}"
      read judul_path

      echo -e "${BOLD_YELLOW}Masukkan lokasi untuk sharing (contoh: /home/share): ${NORMAL}"
      read share_path
    
      echo ""
      echo -e "${BOLD_WHITE}~~~~~${NORMAL} ${BOLD_CYAN}Konfigurasi Izin Samba Share ${NORMAL} ${BOLD_WHITE}~~~~~ ${NORMAL}"
      echo ""

      # Validasi yes/no untuk browseable dan sejenisnya
      while true; do
        echo -e "${BOLD_YELLOW}browseable? (yes/no): ${NORMAL}"
        read browseable
        if [[ "$browseable" =~ ^(yes|no)$ ]]; then break; fi
        echo -e "${BOLD_MAGENTA}[ERROR]: Masukkan hanya 'yes' atau 'no'.${NORMAL}"
      done

      while true; do
        echo -e "${BOLD_YELLOW}writable? (yes/no): ${NORMAL}"
        read writable
        if [[ "$writable" =~ ^(yes|no)$ ]]; then break; fi
        echo -e "${BOLD_MAGENTA}[ERROR]: Masukkan hanya 'yes' atau 'no'.${NORMAL}"
      done

      while true; do
        echo -e "${BOLD_YELLOW}guest ok? (yes/no): ${NORMAL}"
        read guest_ok
        if [[ "$guest_ok" =~ ^(yes|no)$ ]]; then break; fi
        echo -e "${BOLD_MAGENTA}[ERROR]: Masukkan hanya 'yes' atau 'no'.${NORMAL}"
      done

      while true; do
        echo -e "${BOLD_YELLOW}read only? (yes/no): ${NORMAL}"
        read read_only
        if [[ "$read_only" =~ ^(yes|no)$ ]]; then break; fi
        echo -e "${BOLD_MAGENTA}[ERROR]: Masukkan hanya 'yes' atau 'no'.${NORMAL}"
      done

      echo ""
      echo -e "${BOLD_WHITE}~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ${NORMAL}"
      echo ""

      # Menambahkan konfigurasi baru
      cat <<EOT >> /etc/samba/smb.conf

[$judul_path]
   path = $share_path
   browseable = $browseable
   writable = $writable
   guest ok = $guest_ok
   read only = $read_only
EOT
      echo -e "${BOLD_BLUE}[INFO]: Konfigurasi Samba share Untuk $judul_path Berhasil Diperbarui ${NORMAL}"
    elif [[ "$add_share" =~ ^[Nn]$ ]]; then
      echo -e "${BOLD_MAGENTA}[INFO]: Tidak menambah konfigurasi Samba share. ${NORMAL}"
      break
    else
      echo -e "${BOLD_RED}[ERROR]: Masukkan hanya 'y' atau 'n'.${NORMAL}"
    fi
  done

  # Fungsi untuk menambahkan user Samba
  num_users=0
  while true; do
    if [[ $num_users -gt 0 ]]; then
      echo -e "${BOLD_YELLOW}Apakah Anda ingin menambahkan pengguna Samba lainnya? (y/n): ${NORMAL}"
    else
      echo -e "${BOLD_YELLOW}Apakah Anda ingin menambahkan pengguna Samba? (y/n): ${NORMAL}"
    fi
    read add_user
    echo ""

    if [[ "$add_user" =~ ^[Yy]$ ]]; then
      num_users=$((num_users + 1))
      echo -e "${BOLD_CYAN}[INFO]: Menambahkan pengguna Samba... ${NORMAL}"

      echo -e "${BOLD_YELLOW}Masukkan nama pengguna Samba baru: ${NORMAL}"
      read samba_user

      echo -e "${BOLD_YELLOW}Masukkan password untuk pengguna Samba: ${NORMAL}"
      read -s samba_password  # Menggunakan -s agar password tidak terlihat
      echo ""

      # Menambahkan pengguna dan mengatur password
      adduser --gecos "" --disabled-password $samba_user
      echo -e "$samba_password" | smbpasswd -a $samba_user
      echo -e "${BOLD_BLUE}[INFO]: Pengguna Samba $samba_user Berhasil Ditambahkan ${NORMAL}"
    elif [[ "$add_user" =~ ^[Nn]$ ]]; then
      echo -e "${BOLD_MAGENTA}[INFO]: Tidak ada pengguna Samba yang ditambahkan ${NORMAL}"
      break
    else
      echo -e "${BOLD_RED}[ERROR]: Masukkan hanya 'y' atau 'n' ${NORMAL}"
    fi
  done

  # Pastikan wins support hanya ditambahkan sekali
  echo -e "${BOLD_BLUE}[SYSTEM]: Menonaktifkan WINS support ${NORMAL}"

  # Tambahkan hanya jika tidak ada baris wins support di smb.conf
  if ! grep -q "^wins support" /etc/samba/smb.conf; then
    cat <<EOT >> /etc/samba/smb.conf

# WINS Configuration
wins support = no
EOT
    echo -e "${BOLD_CYAN}[SYSTEM]: Konfigurasi WINS support berhasil ditambahkan ke smb.conf ${NORMAL}"
  else
    echo -e "${BOLD_MAGENTA}[INFO]: Konfigurasi WINS support sudah ada di smb.conf, tidak perlu menambahkan lagi.${NORMAL}"
  fi

  # Memulai ulang layanan samba
  echo -e "${BOLD_GREEN}[SYSTEM]: Memulai ulang layanan Samba Server... ${NORMAL}"
  if ! systemctl restart smbd; then
      echo -e "${BOLD_RED}[ERROR]: Gagal me-restart Samba Server ${NORMAL}"
      exit 1
  fi
  echo ""
  echo -e "${BOLD_WHITE}=========================================== ${NORMAL}"
  echo -e "${BOLD_BLUE}[SYSTEM]: Konfigurasi Samba Server Selesai ${NORMAL}"
  echo -e "${BOLD_WHITE}=========================================== ${NORMAL}"
  sleep 3; clear
}

test_dns_and_verify() {
    while true; do
        echo -e "${BOLD_WHITE}============================================= ${NORMAL}"
        echo -e "${BOLD_YELLOW}Apakah Anda ingin melakukan tes DNS? (y/n): ${NORMAL}"
        echo -e "${BOLD_WHITE}============================================= ${NORMAL}"
        read choice
        echo ""
        case $choice in
            [Yy]* ) 
                while true; do
                    echo -e "${BOLD_CYAN}[SYSTEM]: Melakukan pengujian koneksi menggunakan ping dan nslookup... ${NORMAL}"
                    
                    # Meminta input target (alamat IP atau nameserver)
                    echo -e -n "${BOLD_YELLOW}Masukkan alamat IP atau nameserver untuk pengujian: ${NORMAL}" 
                    read target

                    # Melakukan ping
                    echo -e "${BOLD_CYAN}[SYSTEM]: Melakukan ping ke $target sebanyak 4 kali...${NORMAL}"
                    ping_result=$(ping -c 4 $target 2>&1)

                    # Menampilkan hasil ping secara jelas
                    if echo -e "$ping_result" | grep -q "0% packet loss"; then
                        echo -e "${BOLD_GREEN}[SYSTEM]: Ping berhasil ke $target.${NORMAL}"
                        echo -e "${BOLD_GREEN}[SYSTEM]: Hasil ping:${NORMAL}"
                        echo "$ping_result"
                    else
                        echo -e "${BOLD_RED}[ERROR]: Ping gagal ke $target.${NORMAL}"
                        echo -e "${BOLD_RED}[ERROR]: Pastikan $target dapat dijangkau.${NORMAL}"
                        echo "$ping_result"
                    fi

                    # Melakukan pengecekan apakah target adalah IP address atau domain
                    if validate_ip "$target"; then
                        # Jika target adalah IP, lakukan reverse DNS lookup (PTR record)
                        echo -e "${BOLD_CYAN}[SYSTEM]: Melakukan reverse DNS lookup (PTR) untuk $target ${NORMAL}"
                        nslookup_result=$(nslookup -type=PTR $target 2>&1)
                    else
                        # Jika target adalah domain, lakukan nslookup biasa (A atau CNAME record)
                        echo -e "${BOLD_CYAN}[SYSTEM]: Melakukan nslookup untuk $target ${NORMAL}"
                        nslookup_result=$(nslookup $target 2>&1)
                    fi

                    # Cek apakah nslookup berhasil atau gagal
                    if echo "$nslookup_result" | grep -q "Address:"; then
                        echo -e "${BOLD_GREEN}[SYSTEM]: Nslookup berhasil.${NORMAL}"
                        echo "$nslookup_result"
                    else
                        echo -e "${BOLD_RED}[ERROR]: Nslookup gagal.${NORMAL}"
                        echo "$nslookup_result"
                    fi

                    # Meminta input untuk melanjutkan atau berhenti dari pengujian
                    echo -e "${BOLD_YELLOW}Apakah Anda ingin menguji koneksi lain? (y/n): ${NORMAL}" 
                    read choice
                    case $choice in
                        [Nn]* )
                            echo "" 
                            echo -e "${BOLD_WHITE}====================================== ${NORMAL}"
                            echo -e "${BOLD_BLUE}[SYSTEM]: Pengujian koneksi selesai ${NORMAL}"
                            echo -e "${BOLD_WHITE}====================================== ${NORMAL}"
                            break
                            ;;
                        [Yy]* ) continue ;;  # Lanjutkan pengujian jika user memilih y/Y
                        * ) 
                            echo -e "${BOLD_RED}[ERROR]: Input tidak valid. Silakan masukkan y/Y atau n/N.${NORMAL}"
                            ;;
                    esac
                done
                break  # Keluar dari loop verifikasi setelah tes DNS selesai
                ;;
            [Nn]* ) 
                echo -e "${BOLD_MAGENTA}[SYSTEM]: Melewati tes DNS.${NORMAL}"
                return 2
                ;;
            * ) 
                echo -e "${BOLD_RED}[ERROR]: Input tidak valid. Silakan masukkan y/Y atau n/N.${NORMAL}"
                ;;
        esac
    done
}

### Konfigurasi dns server ============================================================================>
configure_bind9() {

    # Menambahkan validasi untuk memulai konfigurasi Samba
    echo -e "${BOLD_WHITE}===== Konfigurasi Dns Server ===== ${NORMAL}"
    echo -e "${BOLD_YELLOW}Apakah Anda ingin melakukan konfigurasi Dns Server (bind9)? (y/n): ${NORMAL}"
    read config_dns
    echo ""

    if [[ "$config_dns" =~ ^[Nn]$ ]]; then
        echo -e "${BOLD_MAGENTA}[INFO]: Melewati konfigurasi Dns Server ${NORMAL}"
        echo ""
        return 0  # Melewati fungsi jika pengguna memilih 'n'
    fi

    clear
    # 1. Minta input user untuk variabel nameserver dan ip_address
    echo -e "${BOLD_WHITE}================================================= ${NORMAL}"
    echo -e "${BOLD_BLUE}[SYSTEM]: Melakukan Konfigurasi Bind9 DNS Server ${NORMAL}"
    echo -e "${BOLD_WHITE}================================================= ${NORMAL}"
    echo ""

    # Validasi nama domain
    while true; do
        echo -e "${BOLD_YELLOW}Masukkan nama domain (smk.com / px.net): ${NORMAL}" 
        read nameserver

        if validate_domain "$nameserver"; then
            break
        else
            echo -e "${BOLD_RED}[ERROR]: Domain tidak valid. Masukkan domain yang berakhir dengan format yang didukung (com, net, dll). ${NORMAL}"
        fi
    done

    # Validasi IP address
    while true; do
        echo -e "${BOLD_YELLOW}Masukkan IP address untuk server (192.10.10.1): ${NORMAL}" 
        read ip_address

        if validate_ip "$ip_address"; then
            break
        else
            echo -e "${BOLD_RED}[ERROR]: IP address tidak valid. Harap masukkan IP address dalam format yang benar (mis. 192.168.0.1). ${NORMAL}"
        fi
    done

    # 2. Lakukan cp db.127 db.ip dan cp db.local db.2
    echo ""
    echo -e "${BOLD_CYAN}[INFO]: Menkonfigurasi file db... ${NORMAL}" 
    echo -e "${BOLD_CYAN}[INFO]: Dapat menggunakan 'db' atapun tidak ${NORMAL}" 
    echo -e "${BOLD_YELLOW}Masukkan nama db ip (contoh: db.192 / 192 / ip): ${NORMAL}" 
    read dbip
    echo -e "${BOLD_YELLOW}Masukkan nama db domain (db.SMK / domain): ${NORMAL}" 
    read db2
    cp /etc/bind/db.127 /etc/bind/$dbip && cp /etc/bind/db.local /etc/bind/$db2

    # 3. Konfigurasi file db
    # Ganti placeholder pada db file dengan values dari nameserver dan ip_address
    # Konfigurasi file dbip
    sed -i "s/localhost/$nameserver/g" /etc/bind/$dbip
    sed -i "s/127.0.0.1/$ip_address/g" /etc/bind/$dbip

    # Mengambil bagian ke-4 dari IP address
    n4=$(echo "$ip_address" | awk -F'.' '{print $4}')
    # Membalik urutan IP address
    reversed_ip=$(echo "$ip_address" | awk -F'.' '{print $3"."$2"."$1}')

    # menambahkan baris baru secara default
    echo -e "${BOLD_CYAN}[INFO]: Menambahkan domain pada $dbip... ${NORMAL}"
    echo -e "${BOLD_CYAN}[INFO]: Secara default menambahkan domain www & mail ${NORMAL}"
    # Menghapus dan mengganti 1.0.0 dengan nilai n4
    sed -i "s/1\.0\.0/$n4/g" /etc/bind/$dbip
    echo -e "$n4\tIN\tPTR\t$nameserver." >> /etc/bind/$dbip
    echo -e "$n4\tIN\tPTR\twww.$nameserver." >> /etc/bind/$dbip
    echo -e "$n4\tIN\tPTR\tmail.$nameserver." >> /etc/bind/$dbip

    # menambahkan domain untuk user 5x
    counter=1
    max_domains=5

    while [ $counter -le $max_domains ]
    do  
        echo ""
        echo -e "${BOLD_YELLOW}Apakah anda ingin menambahkan domain lainnya? (y/n): ${NORMAL}" 
        read choice
        if [[ "$choice" != "y" && "$choice" != "Y" ]]; then
            echo -e "${BOLD_MAGENTA}[SYSTEM]: Anda tidak menambahkan domain lainnya ${NORMAL}"
            break
        fi

        echo -e "${BOLD_YELLOW}Masukkan nama domain anda ($counter): ${NORMAL}" 
        read domain
        eval "domain$counter=\"$domain\""  # Menyimpan input ke variabel berdasarkan counter

        echo -e "$n4\tIN\tPTR\t$domain.$nameserver." >> /etc/bind/$dbip

        ((counter++))
    done
    # Di sini Anda bisa menggunakan variabel domain1, domain2, dst untuk keperluan lainnya

    # Konfigurasi file db untuk local
    sed -i "s/localhost/$nameserver/g" /etc/bind/$db2
    sed -i "s/127.0.0.1/$ip_address/g" /etc/bind/$db2

    # menghapus baris
    sed -i "s/@\s*IN\s*AAAA\s*::1/ /g" /etc/bind/$db2
    # menambahkan baris secara default
    echo -e "${BOLD_CYAN}[INFO]: Menambahkan domain & alamat ip pada $db2... ${NORMAL}"
    echo -e "${BOLD_CYAN}[INFO]: Secara default menambahkan domain www & mail ${NORMAL}"
    echo -e "${BOLD_CYAN}[INFO]: Secara default menambahkan domain yang telah diinput user ${NORMAL}"
    echo -e "www\tIN\tA\t$ip_address" >> /etc/bind/$db2
    echo -e "mail\tIN\tA\t$ip_address" >> /etc/bind/$db2

    # Menambahkan domain yang diinput user dari loop ke db.$db2
    counter=1
    while [ $counter -le $max_domains ]
    do
        # Mengecek apakah variabel domainN ada
        eval "domain=\$domain$counter"
        
        # Jika variabel domain tidak kosong, tambahkan ke db.$db2
        if [ ! -z "$domain" ]; then
            echo -e "$domain\tIN\tA\t$ip_address" >> /etc/bind/$db2
        fi

        ((counter++))
    done

    # Menambahkan zona pada konfigurasi bind
    echo -e "${BOLD_CYAN}[INFO]: Melakukan konfigurasi pada default-zones... ${NORMAL}"
    cat << EOF >> /etc/bind/named.conf.default-zones

zone "$nameserver" {
    type master;
    file "/etc/bind/$db2";
};

zone "$reversed_ip.in-addr.arpa" {
    type master;
    file "/etc/bind/$dbip";
};
EOF

    # konfigurasi resolv
    echo -e "${BOLD_CYAN}[INFO]: Melakukan konfigurasi pada resolv.conf... ${NORMAL}"
    cat >> /etc/resolv.conf << EOF
servername $ip_address
domain $nameserver
search $nameserver
EOF

    # Memulai ulang layanan DNS
    echo -e "${BOLD_GREEN}[SYSTEM]: Memulai ulang layanan DNS Server...${NORMAL}"
    if ! systemctl restart bind9; then
        echo "${BOLD_RED}[ERROR]: Gagal me-restart Bind9 DNS Server ${NORMAL}"
        exit 1
    fi
    echo ""
    echo -e "${BOLD_WHITE}======================================== ${NORMAL}"
    echo -e "${BOLD_BLUE}[SYSTEM]: Konfigurasi DNS Server Selesai ${NORMAL}"
    echo -e "${BOLD_WHITE}======================================== ${NORMAL}"

    # Memanggil fungsi test DNS setelah konfigurasi selesai
    test_dns_and_verify
    sleep 3; clear
}

### Konfigurasi Apache2 ============================================================================>
configure_apache2() {

    # Menambahkan validasi untuk memulai konfigurasi Samba
    echo -e "${BOLD_WHITE}===== Konfigurasi WebServer ===== ${NORMAL}"
    echo -e "${BOLD_YELLOW}Apakah Anda ingin melakukan konfigurasi WebServer (Apache2)? (y/n): ${NORMAL}"
    read config_apache
    echo ""

    if [[ "$config_apache" =~ ^[Nn]$ ]]; then
        echo -e "${BOLD_MAGENTA}[INFO]: Melewati konfigurasi WebServer ${NORMAL}"
        echo ""
        return 0  # Melewati fungsi jika pengguna memilih 'n'
    fi

    clear
    echo -e "${BOLD_WHITE}================================================== ${NORMAL}"
    echo -e "${BOLD_CYAN}[SYSTEM]: Melakukan konfigurasi Apache2 Webserver ${NORMAL}"
    echo -e "${BOLD_WHITE}================================================== ${NORMAL}"
    echo ""

    # Membuat direktori untuk website domain
    mkdir -p /var/www/$nameserver

    echo -e "${BOLD_CYAN}[INFO]: Melakukan cp 000-default.conf lalu mengkonfigurasi isi file yang di cp ${NORMAL}"
    echo -e "${BOLD_CYAN}[INFO]: Secara default membuat & menkonfigurasi mailweb (Roundcube) ${NORMAL}"
    echo -e "${BOLD_CYAN}[INFO]: Secara default membuat & menkonfigurasi domain yang telah dibuat user ${NORMAL}"
    
    # Salin template 000-default.conf sebagai dasar konfigurasi
    cp /etc/apache2/sites-available/000-default.conf /etc/apache2/sites-available/$nameserver.conf
    cp /etc/apache2/sites-available/000-default.conf /etc/apache2/sites-available/webmail.conf
    
    # Edit konfigurasi untuk domain utama
    sed -i "s|/var/www/html|/var/www/$nameserver|g" /etc/apache2/sites-available/$nameserver.conf
    sed -i "s|#ServerName www.example.com|ServerName $nameserver\nServerAlias www.$nameserver|g" /etc/apache2/sites-available/$nameserver.conf

    # Membuat file index.html untuk domain utama
    echo "<html><head><title>Welcome to $nameserver</title></head><body><h1>Website $nameserver</h1></body></html>" > /var/www/$nameserver/index.html

    # Edit konfigurasi untuk domain mail
    sed -i "s|/var/www/html|/var/lib/roundcube|g" /etc/apache2/sites-available/webmail.conf
    sed -i "s|#ServerName www.example.com|ServerName mail.$nameserver\nServerAlias mail.$nameserver|g" /etc/apache2/sites-available/webmail.conf

    # Setiap domain tambahan (domain1, domain2, dst) juga dikonfigurasi
    counter=1
    while [ $counter -le $max_domains ]
    do
        # Mengecek apakah variabel domainN ada
        eval "domain=\$domain$counter"

        # Jika variabel domain tidak kosong, buat konfigurasi virtual host untuk domain tersebut
        if [ ! -z "$domain" ]; then
            echo -e "${BOLD_CYAN}[INFO]: Konfigurasi Apache2 untuk $domain... ${NORMAL}"

            # Membuat direktori untuk domain tambahan
            mkdir -p /var/www/$domain

            # Membuat file index.html untuk domain tambahan
            echo "<html><head><title>Welcome to $domain</title></head><body><h1>Website $domain</h1></body></html>" > /var/www/$domain/index.html

            # Salin template 000-default.conf sebagai dasar konfigurasi untuk domain tambahan
            cp /etc/apache2/sites-available/000-default.conf /etc/apache2/sites-available/$domain.conf

            # Edit konfigurasi untuk domain tambahan
            sed -i "s|/var/www/html|/var/www/$domain|g" /etc/apache2/sites-available/$domain.conf
            sed -i "s|#ServerName www.example.com|ServerName $domain.$nameserver\nServerAlias $domain.$nameserver|g" /etc/apache2/sites-available/$domain.conf

            # Aktifkan konfigurasi virtual host domain tambahan
            a2ensite $domain.conf
        fi

        ((counter++))
    done

    # Aktifkan konfigurasi untuk domain utama dan mail
    a2dissite 000-default.conf
    a2ensite $nameserver.conf
    a2ensite webmail.conf

    echo ""
    echo -e "${BOLD_WHITE}===================================== ${NORMAL}"
    echo -e "${BOLD_BLUE}[SYSTEM]: Konfigurasi Apache2 Selesai ${NORMAL}"
    echo -e "${BOLD_WHITE}===================================== ${NORMAL}"
    sleep 3;clear
    echo -e "${BOLD_WHITE}======================================= ${NORMAL}"
    echo -e "${BOLD_GREEN}[SYSTEM]: Restart layanan Server ${NORMAL}"
    echo -e "${BOLD_WHITE}======================================= ${NORMAL}"

    if ! systemctl restart ssh proftpd bind9 apache2 dovecot postfix mariadb smbd ; then
        echo "${BOLD_RED}[INFO]: Gagal merestart layanan. System akan merestart layanan kembali.${NORMAL}"
        systemctl restart ssh proftpd bind9 apache2 dovecot postfix mariadb smbd 
    fi
    echo -e "${BOLD_CYAN}[INFO]: Restart layanan ssh berhasil ${NORMAL}"
    echo -e "${BOLD_CYAN}[INFO]: Restart layanan proftpd berhasil ${NORMAL}"
    echo -e "${BOLD_CYAN}[INFO]: Restart layanan bind9 berhasil ${NORMAL}"
    echo -e "${BOLD_CYAN}[INFO]: Restart layanan apache2 berhasil ${NORMAL}"
    echo -e "${BOLD_CYAN}[INFO]: Restart layanan samba berhasil ${NORMAL}"
    
    echo -e "${BOLD_WHITE}========================================== ${NORMAL}"
    echo -e "${BOLD_GREEN}[SYSTEM]: Instalasi Layanan Server Selesai ${NORMAL}"
    echo -e "${BOLD_WHITE}========================================== ${NORMAL}"
    sleep 3; clear
}

### Konfigurasi ISC-DHCP-Server ============================================================================>
configure_dhcp_server() {

 # Menambahkan validasi untuk memulai konfigurasi Samba
    echo -e "${BOLD_WHITE}===== Konfigurasi Dhcp Server ===== ${NORMAL}"
    echo -e "${BOLD_YELLOW}Apakah Anda ingin melakukan konfigurasi Dhcp-Server? (y/n): ${NORMAL}"
    read config_dhcp
    echo ""

    if [[ "$config_dhcp" =~ ^[Nn]$ ]]; then
        echo -e "${BOLD_MAGENTA}[INFO]: Melewati konfigurasi Dhcp Server ${NORMAL}"
        echo ""
        return 0  # Melewati fungsi jika pengguna memilih 'n'
    fi

while true; do
    clear
    echo -e "${BOLD_WHITE}========================================== ${NORMAL}"
    echo -e "${BOLD_BLUE}[SYSTEM]: Mengkonfigurasi ISC-DHCP-Server ${NORMAL}"
    echo -e "${BOLD_WHITE}========================================== ${NORMAL}"
    echo ""

    echo -e "${BOLD_WHITE}====================================================${NORMAL}"
    echo -e "${BOLD_CYAN}[INFO]: Menampilkan semua interface yang tersedia:${NORMAL}"
    echo -e "${BOLD_WHITE}====================================================${NORMAL}"
    echo ""
    # Daftar semua interface aktif pada sistem
    for INTERFACE in $(ip -o link show | awk -F': ' '{print $2}'); do
        get_interface_info $INTERFACE  # Menampilkan informasi dari masing-masing interface
    done
    
    # Meminta input dari pengguna untuk konfigurasi DHCP
    echo ""
    echo -e "${BOLD_CYAN}[INFO]: Untuk menghindari kesalahan dalam merestart Dhcp server ${NORMAL}" 
    echo -e "${BOLD_CYAN}[INFO]: Sebaiknya menggunakan interface bertype 'static' ${NORMAL}" 
    echo ""
    echo -e "${BOLD_YELLOW}Masukkan interface sebagai DHCP server (contoh: enp0s3/enp0s8): ${NORMAL}" 
    read dhcp_if
    echo -e "${BOLD_YELLOW}IP network server (contoh: 192.168.10.0): ${NORMAL}" 
    read IPsubnet
    echo -e "${BOLD_YELLOW}Subnet mask (contoh: 255.255.255.0): ${NORMAL}" 
    read IPnetmask
    echo -e "${BOLD_YELLOW}Range IP (contoh: 192.168.10.10 192.168.10.20): ${NORMAL}" 
    read IPrange
    echo -e "${BOLD_YELLOW}IP router/server (contoh: 192.168.10.1): ${NORMAL}" 
    read IPserver
   
    # Validasi alamat IP yang dimasukkan oleh pengguna
    if validate_ip "$IPsubnet" && validate_ip "${IPrange% *}" && validate_ip "${IPrange#* }" && validate_ip "$IPserver"; then
        break  # Keluar dari loop jika semua IP valid
    else
        echo -e "${BOLD_RED}[ERROR]: IP yang Anda masukkan tidak valid. Silakan masukkan IP yang benar ${NORMAL}"
    fi
done

# Konversi subnetmask ke notasi CIDR
CIDR2=$(netmask_to_cidr $IPnetmask)

# Menambahkan pengaturan DHCP server sesuai input pengguna ke file konfigurasi
echo ""
echo -e "${BOLD_CYAN}[INFO]: Menambah pengaturan DHCP server sesuai input yang diberikan... ${NORMAL}"
sed -i "s/INTERFACESv4=\"\"/INTERFACESv4=\"$dhcp_if\"/g" /etc/default/isc-dhcp-server

# Cek jika subnet sudah ada
if ! grep -q "subnet $IPsubnet netmask $IPnetmask" /etc/dhcp/dhcpd.conf; then
    # Menambahkan konfigurasi subnet ke file dhcpd.conf
    cat <<EOL >> /etc/dhcp/dhcpd.conf
subnet $IPsubnet netmask $IPnetmask {  
    range $IPrange;  
    option routers $IPserver;  
    option domain-name-servers $IPserver;  
    option domain-name "$nameserver";  
    default-lease-time 600;  
    max-lease-time 7200;  
}
EOL
else
    echo -e "${BOLD_MAGENTA}[WARNING]: Konfigurasi subnet untuk $IPsubnet sudah ada di dhcpd.conf, tidak ada perubahan yang dilakukan.${NORMAL}"
fi

# Restart ISC DHCP Server untuk menerapkan konfigurasi baru
echo -e "${BOLD_GREEN}[SYSTEM]: Melakukan Restart Layanan DHCP Server ${NORMAL}"
systemctl restart isc-dhcp-server
if [ $? -eq 0 ]; then
    echo -e "${BOLD_GREEN}[SYSTEM]: ISC-DHCP-Server Berhasil Dikonfigurasi & Direstart  ${NORMAL}"
else
    echo -e "${BOLD_RED}[ERROR]: Gagal merestart ISC-DHCP-server ${NORMAL}"
fi

# Restart semua interface DHCP
    echo -e "${BOLD_CYAN}[INFO]: Melakukan restart pada semua interfaces DHCP... ${NORMAL}"
    for INTERFACE in $(ip -o link show | awk -F': ' '{print $2}'); do
        if [[ $(cat /etc/network/interfaces | grep -c "iface $INTERFACE inet dhcp") -gt 0 ]]; then
            echo -e "${BOLD_YELLOW}[SYSTEM]: Restarting $INTERFACE... ${NORMAL}"
            ifdown $INTERFACE && ifup $INTERFACE
            if [ $? -eq 0 ]; then
                echo -e "${BOLD_GREEN}[SYSTEM]: $INTERFACE berhasil di-restart ${NORMAL}"
            else
                echo -e "${BOLD_RED}[ERROR]: Gagal merestart $INTERFACE ${NORMAL}"
            fi
        fi
    done

    echo ""
    echo -e "${BOLD_WHITE}========================================== ${NORMAL}"
    echo -e "${BOLD_BLUE}[SYSTEM]: Konfigurasi DHCP_Server Selesai ${NORMAL}"
    echo -e "${BOLD_WHITE}========================================== ${NORMAL}"

    sleep 4; clear
}

# Konfigurasi MariaDB ============================================================================>
configure_mariadb_server() {

echo -e "${BOLD_WHITE}================================== ${NORMAL}"
echo -e "${BOLD_BLUE}[SYSTEM]: Mengkonfigurasi MariaDB ${NORMAL}"
echo -e "${BOLD_WHITE}================================== ${NORMAL}"
echo ""
/usr/bin/mysql_secure_installation <<EOF
y
$sandi
$sandi
y
y
y
y
EOF

echo ""
echo -e "${BOLD_WHITE}===================================== ${NORMAL}"
echo -e "${BOLD_BLUE}[SYSTEM]: Konfigurasi MariaDB Selesai ${NORMAL}"
echo -e "${BOLD_WHITE}===================================== ${NORMAL}"
sleep 1;clear
}

# Konfigurasi dovecot dan postfix ============================================================================>
configure_dovecot_postfix() {
echo -e "${BOLD_WHITE}============================================ ${NORMAL}"
echo -e "${BOLD_BLUE}[SYSTEM]: Mengkonfigurasi Dovecot & Postfix ${NORMAL}"
echo -e "${BOLD_WHITE}============================================ ${NORMAL}"
echo ""

echo -e "${BOLD_CYAN}[INFO]: Mengubah isi file konfigurasi dovecot dan postfix... ${NORMAL}"
/usr/bin/maildirmake.dovecot /etc/skel/Maildir/
sed -i "s/#listen/listen/g" /etc/dovecot/dovecot.conf
sed -i "s/#disable_plaintext_auth = yes/disable_plaintext_auth = no/g" /etc/dovecot/conf.d/10-auth.conf
sed -i 's|mbox:~/mail:INBOX=/var/mail/%u|maildir:~/Maildir|' /etc/dovecot/conf.d/10-mail.conf
echo "home_mailbox = Maildir/" >> /etc/postfix/main.cf

echo -e "${BOLD_CYAN}[INFO]: Melakukan konfigurasi pada main.cf... ${NORMAL}"
    postconf -e "myhostname = mail.$nameserver"
    postconf -e "mydestination = localhost, mail.$nameserver"
    postconf -e "mynetworks = 127.0.0.0/8 [::ffff:127.0.0.0]/104 [::1]/128 $IPsubnet/$CIDR2 0.0.0.0/0"
    postconf -e "mailbox_size_limit = 0"
    postconf -e "recipient_delimiter = +"

debconf-set-selections <<< "postfix postfix/mailname string $nameserver"
dpkg-reconfigure postfix

echo ""
echo -e "${BOLD_WHITE}============================================= ${NORMAL}"
echo -e "${BOLD_BLUE}[INFO]: konfigurasi Dovecot & Postfix Selesai ${NORMAL}"
echo -e "${BOLD_WHITE}============================================= ${NORMAL}"
sleep 3;clear
}

configure_roundcube() {
    echo -e "${BOLD_WHITE}============================================ ${NORMAL}"
    echo -e "${BOLD_BLUE}[SYSTEM]: Mengkonfigurasi Database Roundcube ${NORMAL}"
    echo -e "${BOLD_WHITE}============================================ ${NORMAL}"
    echo ""
    echo -e "${BOLD_CYAN}[INFO]: Mengkonfigurasi file config.inc.php... ${NORMAL}"
    sed -i "s/\['smtp_server'\] = 'localhost'/\['smtp_server'\] = 'mail.$nameserver'/g" /etc/roundcube/config.inc.php
    sed -i "s/\['default_host'\] = ''/\['default_host'\] = 'mail.$nameserver'/g" /etc/roundcube/config.inc.php
    sed -i "s/'%u'/''/g" /etc/roundcube/config.inc.php
    sed -i "s/'%p'/''/g" /etc/roundcube/config.inc.php

    echo -e "${BOLD_CYAN}[INFO]: Melakukan pengecekan apakah databases & user 'roundcube' tersedia... ${NORMAL}"

    # Memeriksa apakah database 'roundcube' sudah ada
    db_check=$(mysql -u root -p"$sandi" -e "SHOW DATABASES LIKE 'roundcube';" | grep "roundcube")

    if [[ -z "$db_check" ]]; then
        echo -e "${BOLD_CYAN}[INFO]: Database 'roundcube' tidak ditemukan. Membuat database 'roundcube' ${NORMAL}"
        
        # Membuat database roundcube
        mysql -u root -p"$sandi" -e "CREATE DATABASE roundcube;"
    else
        echo -e "${BOLD_MAGENTA}[INFO]: Database 'roundcube' sudah ada. Tidak perlu membuat ulang.${NORMAL}"
    fi

    # Memeriksa apakah user 'roundcube' sudah ada
    user_check=$(mysql -u root -p"$sandi" -e "SELECT User FROM mysql.user WHERE User = 'roundcube';" | grep "roundcube")

    if [[ -z "$user_check" ]]; then
        # Membuat user 'roundcube' jika tidak ada
        echo -e "${BOLD_CYAN}[INFO]: User 'roundcube' tidak ditemukan. Membuat user 'roundcube' dengan sandi: $sandi ${NORMAL}"
        mysql -u root -p"$sandi" -e "CREATE USER 'roundcube'@'localhost' IDENTIFIED BY '$sandi';"
    else
        echo -e "${BOLD_MAGENTA}[INFO]: User 'roundcube' sudah ada. Tidak perlu membuat ulang.${NORMAL}"
    fi

    # Memberi akses ke database roundcube
    echo -e "${BOLD_CYAN}[INFO]: Memberi hak akses penuh ke user 'roundcube' pada database 'roundcube' ${NORMAL}"
    mysql -u root -p"$sandi" -e "GRANT ALL PRIVILEGES ON roundcube.* TO 'roundcube'@'localhost';"
    mysql -u root -p"$sandi" -e "FLUSH PRIVILEGES;"

    for ((i=1; i<=4; i++)); do
        echo ""
        echo -e "${BOLD_YELLOW}Apakah Anda ingin membuat user webmail lainnya? (y/n) ${NORMAL}"
        read -r create_user
        if [[ "$create_user" != "y" ]]; then
            echo -e "${BOLD_MAGENTA}[INFO]: Melewati proses pembuatan user... ${NORMAL}"
            break
        fi
            while true; do
            echo -e "${BOLD_YELLOW}Masukkan nama user untuk Roundcube: ${NORMAL}"
            read -r new_user
            
            # Memeriksa apakah user sudah ada di database MySQL
            user_check=$(mysql -u root -p"$sandi" -e "SELECT User FROM mysql.user WHERE User = '$new_user';" | grep "$new_user")

            if [[ -n "$user_check" ]]; then
                echo -e "${BOLD_RED}[ERROR]: User '$new_user' sudah ada. Silakan masukkan nama yang berbeda.${NORMAL}"
            else
                # Menggunakan password dari variabel $sandi untuk user MySQL
                mysql -u root -p"$sandi" -e "CREATE USER '$new_user'@'localhost' IDENTIFIED BY '$sandi';"
                mysql -u root -p"$sandi" -e "GRANT ALL PRIVILEGES ON roundcube.* TO '$new_user'@'localhost';"
                mysql -u root -p"$sandi" -e "FLUSH PRIVILEGES;"

                # Menambahkan user ke sistem Linux dan menetapkan password dari variabel $sandi
                echo -e "${BOLD_CYAN}[INFO]: Menambahkan user '$new_user' pada system... ${NORMAL}"
                if ! id "$new_user" &>/dev/null; then
                    adduser --gecos "" --disabled-password "$new_user"
                    echo "$new_user:$sandi" | chpasswd  # Menggunakan password $sandi untuk user sistem
                    echo -e "${BOLD_GREEN}[INFO]: User sistem '$new_user' berhasil dibuat dengan password '$sandi' ${NORMAL}"
                else
                    echo -e "${BOLD_MAGENTA}[INFO]: User sistem '$new_user' sudah ada.${NORMAL}"
                fi
                break
            fi
        done
    done

    echo ""
    echo -e "${BOLD_WHITE}==================================================== ${NORMAL}"
    echo -e "${BOLD_BLUE}[SYSTEM]: Mengkonfigurasi Database Roundcube Selesai ${NORMAL}"
    echo -e "${BOLD_WHITE}==================================================== ${NORMAL}"
    sleep 3;clear
}

# Set debconf selections untuk Roundcube ============================================================================>
configure_dpkg_recon_roundcube() {
echo -e "${BOLD_WHITE}==================================================== ${NORMAL}"
echo -e "${BOLD_BLUE}[SYSTEM]: Mengkonfigurasi Dpkg-Reconfigure Roundcube ${NORMAL}"
echo -e "${BOLD_WHITE}==================================================== ${NORMAL}"
echo ""

debconf-set-selections <<< "roundcube-core roundcube/dbconfig-install boolean true"
debconf-set-selections <<< "roundcube-core roundcube/mysql/admin-pass password $sandi"
debconf-set-selections <<< "roundcube-core roundcube/mysql/app-pass password $sandi"
debconf-set-selections <<< "roundcube-core roundcube/db/app-user string roundcube@localhost"
debconf-set-selections <<< "roundcube-core roundcube/db/dbname string roundcube"
debconf-set-selections <<< "roundcube-core roundcube/reconfigure-webserver multiselect apache2"
debconf-set-selections <<< "roundcube-core roundcube/hosts string mail.$nameserver"
debconf-set-selections <<< "roundcube-core roundcube/mysql/admin-user string root"
debconf-set-selections <<< "roundcube-core roundcube/remote/host string localhost"
debconf-set-selections <<< "roundcube-core roundcube/dbconfig-install boolean true"
debconf-set-selections <<< "roundcube-core roundcube/restart-webserver boolean true"
debconf-set-selections <<< "roundcube-core roundcube/database-type string mysql"
debconf-set-selections <<< "roundcube-core roundcube/dbconfig-reinstall boolean true"
debconf-set-selections <<< "roundcube-core roundcube/language string en_US"
debconf-set-selections <<< "roundcube-core roundcube/mysql/method string TCP/IP"

dpkg-reconfigure roundcube-core

echo ""
echo -e "${BOLD_WHITE}======================================================== ${NORMAL}"
echo -e "${BOLD_BLUE}[SYSTEM]: Konfigurasi Dpkg-Reconfigure Roundcube Selesai ${NORMAL}"
echo -e "${BOLD_WHITE}======================================================== ${NORMAL}"
}

restart_layanan_server() {
clear
echo -e "${BOLD_WHITE}======================================= ${NORMAL}"
echo -e "${BOLD_GREEN}[SYSTEM]: Restart Semua layanan Server ${NORMAL}"
echo -e "${BOLD_WHITE}======================================= ${NORMAL}"

    if ! systemctl restart ssh proftpd bind9 apache2 dovecot postfix mariadb smbd isc-dhcp-server; then
        echo "${BOLD_RED}[SYSTEM]: Gagal merestart layanan. System akan merestart layanan kembali.${NORMAL}"
        systemctl restart ssh proftpd bind9 apache2 dovecot postfix mariadb smbd isc-dhcp-server
    fi
    
    echo -e "${BOLD_CYAN}[INFO]: Restart layanan ssh berhasil ${NORMAL}"
    echo -e "${BOLD_CYAN}[INFO]: Restart layanan proftpd berhasil ${NORMAL}"
    echo -e "${BOLD_CYAN}[INFO]: Restart layanan bind9 berhasil ${NORMAL}"
    echo -e "${BOLD_CYAN}[INFO]: Restart layanan apache2 berhasil ${NORMAL}"
    echo -e "${BOLD_CYAN}[INFO]: Restart layanan samba berhasil ${NORMAL}"
    echo -e "${BOLD_CYAN}[INFO]: Restart layanan dovecot berhasil ${NORMAL}"
    echo -e "${BOLD_CYAN}[INFO]: Restart layanan postfix berhasil ${NORMAL}"
    echo -e "${BOLD_CYAN}[INFO]: Restart layanan mariadb berhasil ${NORMAL}"
    echo -e "${BOLD_CYAN}[INFO]: Restart layanan dhcp-server berhasil ${NORMAL}"

    echo -e "${BOLD_WHITE}=========================================== ${NORMAL}"
    echo -e "${BOLD_GREEN}[SYSTEM]: Instalasi Layanan Server Selesai ${NORMAL}"
    echo -e "${BOLD_WHITE}=========================================== ${NORMAL}"
    sleep 4; clear
}

manage_services() {
  echo -e "${BOLD_GREEN}====== Service Management ======${NORMAL}"
  
  echo -e "${BOLD_YELLOW}Apakah Anda ingin menggunakan service management? (y/n) ${NORMAL}"
  read USE_SERVICE
  echo ""

  if [[ $USE_SERVICE == "y" || $USE_SERVICE == "Y" ]]; then
    while true; do
      sleep 1;clear
      echo -e "${BOLD_GREEN}====== Service Management Menu ======${NORMAL}"
      echo -e "${BOLD_WHITE}Pilih opsi yang ingin Anda lakukan:${NORMAL}"
      echo ""
      echo -e "${BOLD_WHITE}1) Lihat semua interfaces${NORMAL}"
      echo -e "${BOLD_WHITE}2) Test DNS${NORMAL}"
      echo -e "${BOLD_WHITE}3) Konfigurasi jaringan${NORMAL}"
      echo -e "${BOLD_WHITE}4) Konfigurasi ulang server${NORMAL}"
      echo -e "${BOLD_RED}5) Keluar${NORMAL}"
      echo -e "${BOLD_GREEN}=========================================${NORMAL}"
      
      echo -e "${BOLD_YELLOW}Masukkan pilihan Anda [1-5]: ${NORMAL}" 
      read SERVICE_OPTION

      case $SERVICE_OPTION in
        1)
          echo -e "${BOLD_GREEN}Menampilkan semua interfaces...${NORMAL}"
          echo ""
          sleep 1  # Simulasi delay untuk memberi efek loading
          echo -e "${BOLD_WHITE}====================================================${NORMAL}"
          echo -e "${BOLD_CYAN}[INFO]: Menampilkan semua interface yang tersedia:${NORMAL}"
          echo -e "${BOLD_WHITE}====================================================${NORMAL}"
          echo ""
          for INTERFACE in $(ip -o link show | awk -F': ' '{print $2}'); do
              get_interface_info $INTERFACE  # Menampilkan informasi dari masing-masing interface
          done
        ;;
        2)
          echo -e "${BOLD_GREEN}Melakukan test DNS...${NORMAL}"
          echo ""
          sleep 1  # Simulasi delay
          test_dns_and_verify
          ;;
        3)
          echo -e "${BOLD_GREEN}Mengonfigurasi jaringan...${NORMAL}"
          echo ""
          sleep 1
          configure_network
          ;;
        4)
          echo -e "${BOLD_GREEN}Mengonfigurasi ulang server...${NORMAL}"
          echo -e "${BOLD_CYAN}Mungkin akan terdapat masalah jika anda melakukan konfigurasi server 2x ${NORMAL}"
          echo -e "${BOLD_CYAN}Sebaiknya anda memilih server yang belum dikonfigurasi ${NORMAL}"
          echo ""
          echo -e "${BOLD_WHITE}Pilih server yang ingin dikonfigurasi ulang:${NORMAL}"
          echo -e "${BOLD_WHITE}1) Samba ${NORMAL}"
          echo -e "${BOLD_WHITE}2) Bind9 ${NORMAL}"
          echo -e "${BOLD_WHITE}3) Apache2 ${NORMAL}"
          echo -e "${BOLD_WHITE}4) Dhcp Server ${NORMAL}"
          echo -e "${BOLD_WHITE}5) Semua ${NORMAL}"
          echo -e "${BOLD_WHITE}6) Kembali ${NORMAL}"
          echo -e -n "${BOLD_YELLOW}Masukkan Pilihan Anda [1-6]: ${NORMAL}" 
          read SERVER_OPTION
          
          case $SERVER_OPTION in
            1)
              configure_samba
              ;;
            2)
              configure_bind9
              ;;
            3)
              configure_apache2
              ;;
            4)
              configure_dhcp_server
              ;;
            5)
              echo -e "${BOLD_GREEN}Mengonfigurasi semua server...${NORMAL}"
              echo ""
              configure_samba
              configure_bind9
              configure_apache2
              configure_dhcp_server
              ;;
            6)
              echo -e "${BOLD_MAGENTA}Kembali ke menu utama service management...${NORMAL}"
              sleep 1
              continue
              ;;
            *)
              echo -e "${BOLD_RED}Pilihan tidak valid! ${NORMAL}"
              ;;
          esac
          ;;
        5)
          echo -e "${BOLD_MAGENTA}Keluar dari service management...${NORMAL}"
          break
          ;;
        *)
          echo -e "${BOLD_RED}Pilihan tidak valid! Silakan coba lagi.${NORMAL}"
          ;;
      esac
    done
  else
    echo -e "${BOLD_MAGENTA}Service management dilewati.${NORMAL}"
  fi
}

# Menanyakan kepada pengguna apakah mereka ingin menghapus script ini
end_scripts() {
    echo -e "${BOLD_MAGENTA}
        ____               _          _       
        |  _ \             | |        (_)      
        | |_) |  ___   __ _| |_  _ __ _ __  __ 
        |  _ <  / _ \ / _\` | __|| '__| |\ \/ / 
        | |_) ||  __/| (_| | |_ | |   | | >  <  
        |____/  \___| \__,_|\__||_|   |_|/_/\_\ 
    ${NORMAL}"
    echo -e "${BOLD_WHITE}~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ${NORMAL}" 
    echo -e "${BOLD_WHITE}[SYSTEM]: Semua Fungction Script Telah Dijalankan, Script Telah Selesai ${NORMAL}"
    echo -e "${BOLD_YELLOW}[SYSTEM]: Apakah Anda ingin menghapus script ini? (y/n) ${NORMAL}"
    read delete
    echo ""

    if [[ "$delete" == "y" || "$delete" == "Y" ]]; then
        echo -e "${BOLD_RED}[SYSTEM]: Script ini Akan Dihapus ${NORMAL}"
        
        sleep 5; clear
        exec rm -- "$0"
    else
        echo -e "${BOLD_WHITE}[SYSTEM]: Script Tidak Dihapus, Script Akan Tetap Tersimpan ${NORMAL}"
        echo -e "${BOLD_WHITE}[SYSTEM]: Script Telah Selesai Dieksekusi, Secara Otomatis Akan Berhenti ${NORMAL}"
        
        sleep 5; clear
    fi
    exit 0
}


# <========================================================|EKSEKUSI & MEMANGGIL FUNGCTION|========================================================>

set -e  # Stop execution on error

# eksekusi fungsi cek root
check_root

# eksekusi fungsi install server
if ! install_server; then
    echo -e "${RED}[ERROR]: Instalasi server gagal! ${NORMAL}"
    exit 1
fi
# update server
apt update && apt upgrade -y

# eksekusi fungsi jaringan
if ! configure_network; then
    echo -e "${RED}[ERROR]: Konfigurasi jaringan gagal! ${NORMAL}"
    exit 1
fi

# eksekusi fungsi ssh
if ! configure_ssh; then
    echo -e "${RED}[ERROR]: Konfigurasi ssh server gagal! ${NORMAL}"
    exit 1
fi

# eksekusi fungsi samba
if ! configure_samba; then
    echo -e "${RED}[ERROR]: Konfigurasi samba server gagal! ${NORMAL}"
    exit 1
fi

# eksekusi fungsi samba
if ! configure_bind9; then
    echo -e "${RED}[ERROR]: Konfigurasi samba server gagal! ${NORMAL}"
    exit 1
fi

# eksekusi fungsi samba
if ! configure_apache2; then
    echo -e "${RED}[ERROR]: Konfigurasi samba server gagal! ${NORMAL}"
    exit 1
fi

# eksekusi fungsi dhcp
if ! configure_dhcp_server; then
    echo -e "${RED}[ERROR]: Konfigurasi dhcp server gagal! ${NORMAL}"
    exit 1
fi

# eksekusi fungsi mariadb
if ! configure_mariadb_server; then
    echo -e "${RED}[ERROR]: Konfigurasi mariadb server gagal! ${NORMAL}"
    exit 1
fi

# eksekusi fungsi postif&dovecot
if ! configure_dovecot_postfix; then
    echo -e "${RED}[ERROR]: Konfigurasi dovecot & postfix gagal! ${NORMAL}"
    exit 1
fi

# eksekusi roundcube
if ! configure_roundcube; then
    echo -e "${RED}[ERROR]: Konfigurasi dpkg postfix gagal! ${NORMAL}"
    exit 1
fi
# eksekusi dpkg roundcube core
if ! configure_dpkg_recon_roundcube; then
    echo -e "${RED}[ERROR]: Konfigurasi dpkg roundcube gagal! ${NORMAL}"
    exit 1
fi
# eksekusi fungsi restart semua layanan
if ! restart_layanan_server; then
    echo -e "${RED}[ERROR]: Restart semua layanan server gagal! ${NORMAL}"
    exit 1
fi

manage_services

# update server
apt update && apt upgrade -y

clear
# eksekusi fungsi end scripts
end_scripts

