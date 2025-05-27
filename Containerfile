FROM quay.io/centos-bootc/centos-bootc:stream9

RUN dnf -y copr enable @redhat-et/flightctl epel-9-x86_64 && \
    dnf -y group install GNOME && \
    dnf -y install flightctl-agent mkpasswd firefox && \
    dnf -y clean all && \
    systemctl set-default graphical.target

RUN pass=$(mkpasswd --method=SHA-512 --rounds=4096 redhat) && useradd -m -G wheel sysadmin -p $pass && \
    echo "%wheel        ALL=(ALL)       NOPASSWD: ALL" > /etc/sudoers.d/wheel-sudo && \
    echo "This is a new update to 10" > /etc/motd

ADD config.yaml /etc/flightctl/
ADD firefox-kiosk.service /etc/systemd/system/
RUN systemctl enable firefox-kiosk.service && systemctl enable flightctl-agent.service
