FROM quay.io/centos-bootc/centos-bootc:stream10

RUN dnf -y copr enable @redhat-et/flightctl epel-9-x86_64 && \
    dnf -y group install GNOME && \
    dnf -y install flightctl-agent mkpasswd && \
    dnf -y clean all && \
    systemctl enable flightctl-agent.service

RUN pass=$(mkpasswd --method=SHA-512 --rounds=4096 redhat) && useradd -m -G wheel sysadmin -p $pass
RUN echo "%wheel        ALL=(ALL)       NOPASSWD: ALL" > /etc/sudoers.d/wheel-sudo
ADD config.yaml /etc/flightctl/
ADD firefox-kiosk.service /etc/systemd/system/
RUN systemctl enable firefox-kiosk.service
RUN echo "This is a new update to 10" > /etc/motd
