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
repo_name="${GITHUB_REPOSITORY/*\/}"
zipper_path="${ZIPPER_PATH:-zipper}"
kernel_path="${KERNEL_PATH:-.}"
name="${NAME:-$repo_name}"
python_version="${PYTHON_VERSION:-3}"

msg "Updating container..."
pacman -Syyu --noconfirm
msg "Cek space..."
df -lah

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

        mkdir -p "$workdir"/"zyc-clang"-"${ver_number}"
        cd "$workdir"/"zyc-clang"-"${ver_number}"

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
        
        extract_tarball /tmp/zyc-clang-"${ver_number}".tar.gz /
        cd "$workdir"/"zyc-clang"-"${ver_number}" || exit 127
        zyc_path="$(pwd)"
        cd "$workdir"/"$kernel_path" || exit 127

        export PATH="$zyc_path/bin:${PATH}"
        export CROSS_COMPILE="aarch64-linux-gnu-"
        export CROSS_COMPILE_ARM32="arm-linux-gnueabi-"
        echo "zyc-clang" >> /tmp/clangversion.txt
    elif [[ $compiler = proton-clang/* ]]; then
        ver="${compiler/proton-clang\/}"
        ver_number="${ver/\/binutils}"
        url="https://gitlab.com/LeCmnGend/proton-clang/-/archive/clang-${ver_number}/proton-clang-clang-${ver_number}.tar.gz"
        binutils="$([[ $ver = */binutils ]] && echo true || echo false)"

        # Due to different time in container and the host,
        # disable certificate check
        echo "Downloading $url"
        if ! wget --no-check-certificate "$url" -O /tmp/proton-clang-"${ver_number}".tar.gz &>/dev/null; then
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

        extract_tarball /tmp/proton-clang-"${ver_number}".tar.gz /
        cd /proton-clang-"${ver_number}"* || exit 127
        proton_path="$(pwd)"
        cd "$workdir"/"$kernel_path" || exit 127

        export PATH="$proton_path/bin:${PATH}"
        export CLANG_TRIPLE="aarch64-linux-gnu-"
        export CROSS_COMPILE="aarch64-linux-gnu-"
        export CROSS_COMPILE_ARM32="arm-linux-gnueabi-"
        echo "proton-clang" >> /tmp/clangversion.txt
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
conf="arch/arm64/configs/${defconfig}"
msg "Menerapkan Nama Kernel ke $kname ..."
sed -i "s/.*/-$kname/" localversion
msg "Patching KernelSU..."
if [ "$addksu" = true ]; then
    curl -LSs "https://raw.githubusercontent.com/tiann/KernelSU/main/kernel/setup.sh" | bash -s "$verksu" &>/dev/null
    echo "CONFIG_MODULES=y" >> "$conf"
    echo "CONFIG_KPROBES=y" >> "$conf"
    echo "CONFIG_HAVE_KPROBES=y" >> "$conf"
    echo "CONFIG_KPROBE_EVENTS=y" >> "$conf"
fi
msg "Check installasi KernelSU..."
if [ -d "KernelSU" ]; then
    echo "Folder 'KernelSU' ada..."
else
    echo "Folder 'KernelSU' tidak ada..."
fi
if grep -q "CONFIG_OVERLAY_FS=y" "$conf" && \
   grep -q "CONFIG_MODULES=y" "$conf" && \
   grep -q "CONFIG_KPROBES=y" "$conf" && \
   grep -q "CONFIG_HAVE_KPROBES=y" "$conf" && \
   grep -q "CONFIG_KPROBE_EVENTS=y" "$conf"; then
    echo "Semua konfigurasi KernelSU ditemukan..."
else
    echo "Tidak semua konfigurasi KernelSU ditemukan..."
fi
msg "Change user & hostname..."
export KBUILD_BUILD_USER="$kuser"
export KBUILD_BUILD_HOST="$khost"

### Custom ###

ls -lah arch/"$arch"/configs
chmod 644 "$conf"
cat "$conf"
cd "$workdir"/"$kernel_path" || exit 127
start_time="$(date +%s)"
date="$(date +%d%m%Y-%I%M)"
tag="$(git symbolic-ref --short HEAD)"
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
