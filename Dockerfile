FROM archlinux:latest
ENV DEBIAN_FRONTEND noninteractive
# custom
ENV TZ=Asia/Jakarta
RUN echo 'arch-cyberspace' > /etc/hostname
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone
RUN systemctl enable ntpd.service
# custom 
COPY entrypoint.sh /entrypoint.sh
ENTRYPOINT [ "/entrypoint.sh" ]
