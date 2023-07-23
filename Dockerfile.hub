FROM archlinux:latest
ENV DEBIAN_FRONTEND noninteractive
# custom
RUN pacman -Sy --noconfirm base-devel bc gcc gcc-libs openssl libmikmod libarchive python zip unzip tar gzip bzip2 unrar wget curl git jre-openjdk-headless
RUN archlinux-java set java-20-openjdk
ENV TZ=Asia/Jakarta
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone
RUN yes | pacman -Scc
# custom 
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT [ "/entrypoint.sh" ]
