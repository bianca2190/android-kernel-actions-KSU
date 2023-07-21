FROM archlinux:latest
ENV DEBIAN_FRONTEND noninteractive
RUN bash -c 'echo -e "[multilib]\nInclude = /etc/pacman.d/mirrorlist" >> /etc/pacman.conf'
RUN pacman -Syyu --noconfirm
RUN pacman -Sy --noconfirm base base-devel bc python python-pip jdk8-openjdk perl git gnupg flex bison gperf zip unzip sdl squashfs-tools ncurses libpng zlib libusb libusb-compat readline inetutils schedtool gperf imagemagick lzop pngcrush rsync repo clang llvm lld dtc lz4 libzip jdk11-openjdk jdk17-openjdk go openssl cpio wget curl git tzdata ntp
RUN pacman -Sy --noconfirm gcc-multilib gcc-libs-multilib libtool-multilib lib32-libusb lib32-readline lib32-glibc bash-completion lib32-zlib
RUN pacman -Sy --noconfirm kmod libelf-dev libssl-dev libtfm-dev device-tree-compiler ca-certificates xz-utils expect
ENV TZ=Asia/Jakarta
RUN echo 'arch-cyberspace' > /etc/hostname
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone
RUN systemctl enable ntpd.service
RUN pacman -Syyu --noconfirm
COPY entrypoint.sh /entrypoint.sh
ENTRYPOINT [ "/entrypoint.sh" ]
