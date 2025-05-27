FROM quay.io/centos-bootc/centos-bootc:stream10

RUN dnf -y copr enable @redhat-et/flightctl epel-9-x86_64 && \
    dnf -y group install GNOME && \
    dnf -y install flightctl-agent mkpasswd firefox && \
    dnf -y clean all && \
    systemctl set-default graphical.target && \
    systemctl enable flightctl-agent.service

RUN pass=$(mkpasswd --method=SHA-512 --rounds=4096 redhat) && useradd -m -G wheel kiosk-user -p $pass && \
    echo "%wheel        ALL=(ALL)       NOPASSWD: ALL" > /etc/sudoers.d/wheel-sudo && \
    echo "This is a new update to 10" > /etc/motd && \
    mkdir -p /home/kiosk-user/.config/autostart
ADD firefox.desktop /home/kiosk-user/.config/autostart/
ADD config.yaml /etc/flightctl/
RUN chown -R kiosk-user:kiosk-user /home/kiosk-user/.config
