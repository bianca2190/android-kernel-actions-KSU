FROM mkv28/archlinux-builder:latest
ENV DEBIAN_FRONTEND noninteractive
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT [ "/entrypoint.sh" ]
