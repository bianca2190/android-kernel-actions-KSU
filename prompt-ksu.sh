#!/bin/bash

# Fungsi untuk mengecek apakah prompt muncul
check_prompt() {
  tail -n 0 -F log.txt | grep -q "KernelSU function support (KSU) \[Y/n/?\]"
}

# Memulai tail pada file log untuk menunggu munculnya prompt
check_prompt &

# Menunggu munculnya prompt
wait $!

# Memberikan input "y" dan menambahkan karakter Enter
echo "y" > log.txt

# Menjalankan perintah make dengan log output
make O=out $arch_opts $make_opts $host_make_opts -j"$(nproc --all)" prepare
