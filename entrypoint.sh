#!/usr/bin/env bash

msg(){
    echo
    echo "==> $*"
    echo
}

err(){
    echo 1>&2
    echo "==> $*" 1>&2
    echo 1>&2
}

set_output(){
    echo "$1=$2" >> $GITHUB_OUTPUT
}

extract_tarball(){
    echo "Extracting $1 to $2"
    tar xf "$1" -C "$2"
}

workdir="$GITHUB_WORKSPACE"
arch="$1"
compiler="$2"
defconfig="$3"
image="$4"
dtbo="$5"
dtb="$6"
addksu="$7"
verksu="$8"
kuser="$9"
khost="${10}"
kname="${11}"
tag="${12}"
repo_name="${GITHUB_REPOSITORY/*\/}"
zipper_path="${ZIPPER_PATH:-zipper}"
kernel_path="${KERNEL_PATH:-.}"
name="${NAME:-$repo_name}"
python_version="${PYTHON_VERSION:-3}"

msg "Updating container..."
pacman -Syyu --noconfirm
msg "Cek space..."
df -h /

set_output hash "$(cd "$kernel_path" && git rev-parse HEAD || exit 127)"
msg "Installing toolchain..."
if [[ $arch = "arm64" ]]; then
    arch_opts="ARCH=${arch} SUBARCH=${arch}"
    export ARCH="$arch"
    export SUBARCH="$arch"

    if [[ $compiler = neutron-clang/* ]]; then
        ver="${compiler/neutron-clang\/}"
        ver_number="${ver/\/binutils}"

        binutils="$([[ $ver = */binutils ]] && echo true || echo false)"

        mkdir -p "$workdir"/"neutron-clang"-"${ver_number}"
        cd "$workdir"/"neutron-clang"-"${ver_number}"

        echo "Downloading neutron-clang version - $ver_number"
        
        if ! bash <(curl -s "https://raw.githubusercontent.com/Neutron-Toolchains/antman/main/antman") -S="$ver_number" &>/dev/null; then
            err "Failed downloading toolchain, refer to the README for details"
            exit 1
        fi

        if $binutils; then
            make_opts="CC=clang"
            host_make_opts="HOSTCC=clang HOSTCXX=clang++"
        else
            make_opts="CC=clang LD=ld.lld NM=llvm-nm AR=llvm-ar STRIP=llvm-strip OBJCOPY=llvm-objcopy"
            make_opts+=" OBJDUMP=llvm-objdump READELF=llvm-readelf LLVM=1 LLVM_IAS=1"
            host_make_opts="HOSTCC=clang HOSTCXX=clang++ HOSTLD=ld.lld HOSTAR=llvm-ar"
        fi
        
        cd "$workdir"/"neutron-clang"-"${ver_number}" || exit 127
        neutron_path="$(pwd)"
        cd "$workdir"/"$kernel_path" || exit 127

        export PATH="$neutron_path/bin:${PATH}"
        export CROSS_COMPILE="aarch64-linux-gnu-"
        export CROSS_COMPILE_ARM32="arm-linux-gnueabi-"
        echo "neutron-clang" >> /tmp/clangversion.txt
    elif [[ $compiler = zyc-clang/* ]]; then
        ver="${compiler/zyc-clang\/}"
        ver_number="${ver/\/binutils}"
        url="https://github.com/ZyCromerZ/Clang/releases/download/"${ver_number}"-release/Clang-"${ver_number}".tar.gz"
        binutils="$([[ $ver = */binutils ]] && echo true || echo false)"
         # space #
        echo "Downloading zyc-clang version - $ver_number"
        
        if ! wget --no-check-certificate "$url" -O /tmp/zyc-clang-"${ver_number}".tar.gz &>/dev/null; then
            err "Failed downloading toolchain, refer to the README for details"
            exit 1
        fi

        if $binutils; then
            make_opts="CC=clang"
            host_make_opts="HOSTCC=clang HOSTCXX=clang++"
        else
            make_opts="CC=clang LD=ld.lld NM=llvm-nm AR=llvm-ar STRIP=llvm-strip OBJCOPY=llvm-objcopy"
            make_opts+=" OBJDUMP=llvm-objdump READELF=llvm-readelf LLVM=1 LLVM_IAS=1"
            host_make_opts="HOSTCC=clang HOSTCXX=clang++ HOSTLD=ld.lld HOSTAR=llvm-ar"
        fi
        
        mkdir -p "$workdir"/"zyc-clang"-"${ver_number}"
        extract_tarball /tmp/zyc-clang-"${ver_number}".tar.gz "$workdir"/"zyc-clang"-"${ver_number}"
        cd "$workdir"/"zyc-clang"-"${ver_number}"
        ls -lah
        zyc_path="$(pwd)"
        cd "$workdir"/"$kernel_path" || exit 127
        
        export PATH="$zyc_path/bin:${PATH}"
        export CROSS_COMPILE="aarch64-linux-gnu-"
        export CROSS_COMPILE_ARM32="arm-linux-gnueabi-"
        echo "zyc-clang" >> /tmp/clangversion.txt
    elif [[ $compiler = proton-clang/* ]]; then
        ver="${compiler/proton-clang\/}"
        ver_number="${ver/\/binutils}"
        url="https://gitlab.com/LeCmnGend/proton-clang"
        binutils="$([[ $ver = */binutils ]] && echo true || echo false)"
        # Due to different time in container and the host,
        # disable certificate check
        
        echo "Downloading $url versi ${ver_number}"
        if ! git clone -b ${ver_number} --depth=1 --single-branch "$url" "$workdir"/"proton-clang"-"${ver_number}" &>/dev/null; then
            err "Failed downloading toolchain, refer to the README for details"
            exit 1
        fi

        if $binutils; then
            make_opts="CC=clang"
            host_make_opts="HOSTCC=clang HOSTCXX=clang++"
        else
            make_opts="CC=clang LD=ld.lld NM=llvm-nm AR=llvm-ar STRIP=llvm-strip OBJCOPY=llvm-objcopy"
            make_opts+=" OBJDUMP=llvm-objdump READELF=llvm-readelf LLVM_IAS=1"
            host_make_opts="HOSTCC=clang HOSTCXX=clang++ HOSTLD=ld.lld HOSTAR=llvm-ar"
        fi

        cd "$workdir"/"proton-clang"-"${ver_number}"
        ls -lah
        proton_path="$(pwd)"
        cd "$workdir"/"$kernel_path" || exit 127

        export PATH="$proton_path/bin:${PATH}"
        export CLANG_TRIPLE="aarch64-linux-gnu-"
        export CROSS_COMPILE="aarch64-linux-gnu-"
        export CROSS_COMPILE_ARM32="arm-linux-gnueabi-"
        echo "proton-clang" >> /tmp/clangversion.txt
    elif [[ $compiler = prelude-clang/* ]]; then
        ver="${compiler/prelude-clang\/}"
        ver_number="${ver/\/binutils}"
        url="https://gitlab.com/jjpprrrr/prelude-clang"
        binutils="$([[ $ver = */binutils ]] && echo true || echo false)"
        # Due to different time in container and the host,
        # disable certificate check
        
        echo "Downloading $url versi ${ver_number}"
        if ! git clone -b ${ver_number} --depth=1 --single-branch "$url" "$workdir"/"prelude-clang"-"${ver_number}" &>/dev/null; then
            err "Failed downloading toolchain, refer to the README for details"
            exit 1
        fi

        if $binutils; then
            make_opts="CC=clang"
            host_make_opts="HOSTCC=clang HOSTCXX=clang++"
        else
            make_opts="CC=clang LD=ld.lld NM=llvm-nm AR=llvm-ar STRIP=llvm-strip OBJCOPY=llvm-objcopy"
            make_opts+=" OBJDUMP=llvm-objdump READELF=llvm-readelf LLVM_IAS=1"
            host_make_opts="HOSTCC=clang HOSTCXX=clang++ HOSTLD=ld.lld HOSTAR=llvm-ar"
        fi

        cd "$workdir"/"prelude-clang"-"${ver_number}"
        ls -lah
        prelude_path="$(pwd)"
        cd "$workdir"/"$kernel_path" || exit 127

        export PATH="$prelude_path/bin:${PATH}"
        export CLANG_TRIPLE="aarch64-linux-gnu-"
        export CROSS_COMPILE="aarch64-linux-gnu-"
        export CROSS_COMPILE_ARM32="arm-linux-gnueabi-"
        echo "prelude-clang" >> /tmp/clangversion.txt
    elif [[ $compiler = yuki-clang/* ]]; then
        ver="${compiler/yuki-clang\/}"
        ver_number="${ver/\/binutils}"
        url="https://gitlab.com/TheXPerienceProject/yuki-clang-new"
        binutils="$([[ $ver = */binutils ]] && echo true || echo false)"
        # Due to different time in container and the host,
        # disable certificate check
        
        echo "Downloading $url versi ${ver_number}"
        if ! git clone -b ${ver_number} --depth=1 --single-branch "$url" "$workdir"/"yuki-clang"-"${ver_number}" &>/dev/null; then
            err "Failed downloading toolchain, refer to the README for details"
            exit 1
        fi

        if $binutils; then
            make_opts="CC=clang"
            host_make_opts="HOSTCC=clang HOSTCXX=clang++"
        else
            make_opts="CC=clang LD=ld.lld NM=llvm-nm AR=llvm-ar STRIP=llvm-strip OBJCOPY=llvm-objcopy"
            make_opts+=" OBJDUMP=llvm-objdump READELF=llvm-readelf LLVM_IAS=1"
            host_make_opts="HOSTCC=clang HOSTCXX=clang++ HOSTLD=ld.lld HOSTAR=llvm-ar"
        fi

        cd "$workdir"/"yuki-clang"-"${ver_number}"
        ls -lah
        yuki_path="$(pwd)"
        cd "$workdir"/"$kernel_path" || exit 127

        export PATH="$yuki_path/bin:${PATH}"
        export CLANG_TRIPLE="aarch64-linux-gnu-"
        export CROSS_COMPILE="aarch64-linux-gnu-"
        export CROSS_COMPILE_ARM32="arm-linux-gnueabi-"
        echo "yuki-clang" >> /tmp/clangversion.txt
    elif [[ $compiler = aosp-clang/* ]]; then
        ver="${compiler/aosp-clang\/}"
        ver_number="${ver/\/binutils}"
        url="https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/refs/heads/main/${ver_number}.tar.gz"
        binutils="$([[ $ver = */binutils ]] && echo true || echo false)"

        echo "Downloading $url"
        if ! wget --no-check-certificate "$url" -O /tmp/aosp-clang.tar.gz &>/dev/null; then
            err "Failed downloading toolchain, refer to the README for details"
            exit 1
        fi
        url="https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9/+archive/refs/heads/master-kernel-build-2021.tar.gz"
        echo "Downloading $url"
        if ! wget --no-check-certificate "$url" -O /tmp/aosp-gcc-arm64.tar.gz &>/dev/null; then
            err "Failed downloading toolchain, refer to the README for details"
            exit 1
        fi
        url="https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/arm/arm-linux-androideabi-4.9/+archive/refs/heads/master-kernel-build-2021.tar.gz"
        echo "Downloading $url"
        if ! wget --no-check-certificate "$url" -O /tmp/aosp-gcc-arm.tar.gz &>/dev/null; then
            err "Failed downloading toolchain, refer to the README for details"
            exit 1
        fi
        url="https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/host/x86_64-linux-glibc2.17-4.8/+archive/refs/heads/master-kernel-build-2021.tar.gz"
        echo "Downloading $url"
        if ! wget --no-check-certificate "$url" -O /tmp/aosp-gcc-host.tar.gz &>/dev/null; then
            err "Failed downloading toolchain, refer to the README for details"
            exit 1
        fi

        mkdir -p /aosp-clang /aosp-gcc-arm64 /aosp-gcc-arm /aosp-gcc-host
        extract_tarball /tmp/aosp-clang.tar.gz /aosp-clang
        extract_tarball /tmp/aosp-gcc-arm64.tar.gz /aosp-gcc-arm64
        extract_tarball /tmp/aosp-gcc-arm.tar.gz /aosp-gcc-arm
        extract_tarball /tmp/aosp-gcc-host.tar.gz /aosp-gcc-host

        for i in /aosp-gcc-host/bin/x86_64-linux-*; do
            ln -sf "$i" "${i/x86_64-linux-}"
        done

        if $binutils; then
            make_opts="CC=clang"
            host_make_opts="HOSTCC=clang HOSTCXX=clang++"
        else
            make_opts="CC=clang LD=ld.lld NM=llvm-nm STRIP=llvm-strip OBJCOPY=llvm-objcopy"
            make_opts+=" OBJDUMP=llvm-objdump READELF=llvm-readelf LLVM_IAS=1"
            host_make_opts="HOSTCC=clang HOSTCXX=clang++ HOSTLD=ld.lld HOSTAR=llvm-ar"
        fi

        export PATH="/aosp-clang/bin:/aosp-gcc-arm64/bin:/aosp-gcc-arm/bin:/aosp-gcc-host/bin:$PATH"
        export CLANG_TRIPLE="aarch64-linux-gnu-"
        export CROSS_COMPILE="aarch64-linux-android-"
        export CROSS_COMPILE_ARM32="arm-linux-androideabi-"
        echo "aosp-clang" >> /tmp/clangversion.txt
    else
        err "Unsupported toolchain string. refer to the README for more detail"
        exit 100
    fi
else
    err "Currently this action only supports arm64, refer to the README for more detail"
    exit 100
fi
### Custom ###
cd "$workdir"/"$kernel_path" || exit 127
link1="https://raw.githubusercontent.com/bianca2190/Kernel-Builder/vayu-13.0/ksu_vayu/input.c"
link2="https://raw.githubusercontent.com/bianca2190/Kernel-Builder/vayu-13.0/ksu_vayu/exec.c"
link3="https://raw.githubusercontent.com/bianca2190/Kernel-Builder/vayu-13.0/ksu_vayu/open.c"
link4="https://raw.githubusercontent.com/bianca2190/Kernel-Builder/vayu-13.0/ksu_vayu/read_write.c"
link5="https://raw.githubusercontent.com/bianca2190/Kernel-Builder/vayu-13.0/ksu_vayu/stat.c"
msg "Menerapkan Nama Kernel ke $kname ..."
kpath1="arch/${arch}/configs/$defconfig"
kpath2="localversion"
if sed -i "s/CONFIG_LOCALVERSION=\"-.*\"/CONFIG_LOCALVERSION=\"-${kname}\"/g" "$kpath1"; then
    echo "File ditemukan dan teks berhasil diubah: $kpath1"
else
    echo "File tidak ditemukan: $kpath1"
fi
if sed -i "s/.*/-${kname}/" "$kpath2"; then
    echo "File ditemukan dan teks berhasil diubah: $kpath2"
else
    echo "File tidak ditemukan: $kpath2"
fi
msg "Mengunduh & Patching KernelSU..."
if [ "$addksu" = true ]; then
    curl -LSs "https://raw.githubusercontent.com/tiann/KernelSU/main/kernel/setup.sh" | bash -s "$verksu"
    wget "$link1" -O drivers/input/input.c &>/dev/null
    wget "$link2" -O fs/exec.c &>/dev/null
    wget "$link3" -O fs/open.c &>/dev/null
    wget "$link4" -O fs/read_write.c &>/dev/null
    wget "$link5" -O fs/stat.c &>/dev/null
    echo "Perhatian ! sementara hanya mendukung vayu/PocoX3Pro, atau mungkin bisa di device SM8150 silahkan di coba, DWYOR :)"
fi
msg "Check installasi KernelSU..."
if [ -d "KernelSU" ]; then
    echo "Folder 'KernelSU' ada..."
else
    echo "Folder 'KernelSU' tidak ada..."
fi
msg "KernelSU sukses terinstall..."
sleep 5
msg "Change user & hostname..."
export KBUILD_BUILD_USER="$kuser"
export KBUILD_BUILD_HOST="$khost"
### Custom ###
cd "$workdir"/"$kernel_path" || exit 127
start_time="$(date +%s)"
date="$(date +%d%m%Y-%I%M)"
clang="$(cat /tmp/clangversion.txt)"
echo "branch/tag: $tag"
echo "make options:" $arch_opts $make_opts $host_make_opts
msg "Generating defconfig from \`make $defconfig\`..."
if ! make O=out $arch_opts $make_opts $host_make_opts "$defconfig"; then
    err "Failed generating .config, make sure it is actually available in arch/${arch}/configs/ and is a valid defconfig file"
    exit 2
fi
msg "Begin building kernel..."

make O=out $arch_opts $make_opts $host_make_opts -j"$(nproc --all)" prepare

if ! make O=out $arch_opts $make_opts $host_make_opts -j"$(nproc --all)"; then
    err "Failed building kernel, probably the toolchain is not compatible with the kernel, or kernel source problem"
    exit 3
fi
set_output elapsed_time "$(echo "$(date +%s)"-"$start_time" | bc)"
msg "Packaging the kernel..."
zip_filename="${name}-${tag}-${clang}-${date}.zip"
if [[ -e "$workdir"/"$zipper_path" ]]; then
    cp out/arch/"$arch"/boot/"$image" "$workdir"/"$zipper_path"/"$image"

    if [ "$dtbo" = true ]; then
        cp out/arch/"$arch"/boot/dtbo.img "$workdir"/"$zipper_path"/dtbo.img
    fi

    if [ "$dtb" = true ]; then
        cp out/arch/"$arch"/boot/dtb.img "$workdir"/"$zipper_path"/dtb.img
    fi

    cd "$workdir"/"$zipper_path" || exit 127
    rm -rf .git .github
    zip -r9 "$zip_filename" . -x .gitignore README.md || exit 127
    set_output outfile "$workdir"/"$zipper_path"/"$zip_filename"
    cd "$workdir" || exit 127
    exit 0
else
    msg "No zip template provided, releasing the kernel image instead"
    set_output image out/arch/"$arch"/boot/"$image"

    if [ "$dtbo" = true ]; then
        set_output dtbo out/arch/"$arch"/boot/dtbo.img
    fi

    if [ "$dtb" = true ]; then
        set_output dtb out/arch/"$arch"/boot/dtb.img
    fi

    exit 0
fi
