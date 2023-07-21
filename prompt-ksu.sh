#!/usr/bin/expect

# Membuat spawn untuk menjalankan perintah make
spawn make O=out $arch_opts $make_opts $host_make_opts -j"$(nproc --all)" prepare

# Menggunakan expect untuk menangani prompt dan memberikan input "y"
expect "KernelSU function support (KSU) \[Y/n/?\]"
send "y\r"

# Tunggu hingga proses selesai
expect eof
