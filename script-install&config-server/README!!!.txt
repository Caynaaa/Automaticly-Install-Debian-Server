README!!!

[INFO] 
=================== Main Script ==========================
Script ini dibuat agar dapat memudahkan user dalam melakukan installasi & konfigurasi layanan server pada Debian Linux.

Script ini mendukung penggunaan yang dynamis yang bisa menyesesuaikan kebutuhan user.

Berikut layanan server yang diinstall & dikonfigurasi mencangkup:
networking, ssh, samba, bind9, apache2, dovecot, postfix, roundcube, dhcp server

[How To Do]
1. Tambahkan Script ke Terminal. Bisa menggunakan samba & proftpd server
		(Disarankan menggunakan proftpd)

2. Masuk Ke Direktory Script
Gunakan perintah cd untuk berpindah ke direktori tempat file script berada.

2. Beri Izin Eksekusi
Sebelum menjalankan script, Anda perlu memberikan izin eksekusi pada file tersebut. Gunakan perintah chmod:
		chmod +x "Auto-install-all(A).sh"

3. Jalankan Script
Setelah memberikan izin eksekusi, Anda dapat menjalankan script dengan perintah berikut:
		./Auto-install-all(A).sh


### Catatan Penting!!!
	# Pastikan Anda menjalankan terminal dengan hak akses yang sesuai.  	script memerlukan akses root

	# Sebaiknya anda menambahkan ISO DVD2 & DVD3 terlebih dahulu
		
	# Scipt ini memiliki beberapa validasi namun, validasi tersebut 	tidaklah kuat jadi sebaiknya anda mengisi input dengan benar!!!

	# Jangan menjalankan script lebih dari sekali karena akan ada beberapa 	pengaturan yang akan double sehingga menyebabkan "failed restart"
	
	# Kesalahan validasi sering kali dimasukan kedalam konfigurasi.

[Trobleshot]!!!!
####	lokasi dari kemungkinan terjadinya double konfigurasi & validasi 	kesalahan user tidak sengaja di input:
			- /etv/bind/named.conf.default-zone
			- /etc/samba/smbd.conf
			- /etc/network/interfaces
			
