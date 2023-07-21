#!/usr/bin/bash

# Fungsi untuk mengecek apakah prompt muncul dan memberikan input "y" diikuti dengan Enter
check_and_respond_prompt() {
  # Menjalankan perintah make di background
  make_output=$(make O=out $arch_opts $make_opts $host_make_opts -j"$(nproc --all)" prepare 2>&1 &)

  # Mengecek jika prompt muncul dalam output perintah make
  while ! echo "$make_output" | grep -q "KernelSU function support (KSU) \[Y/n/?\]"; do
    sleep 0.1
  done

  # Memberikan input "y" diikuti dengan Enter
  echo "y" > /dev/tty
}

# Memanggil fungsi untuk mengecek prompt dan memberikan input "y"
check_and_respond_prompt
