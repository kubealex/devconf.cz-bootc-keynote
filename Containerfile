FROM quay.io/centos-bootc/centos-bootc:stream9

RUN dnf -y copr enable @redhat-et/flightctl && \
    dnf -y group install GNOME \
    dnf -y install flightctl-agent && \
    dnf -y clean all && \
    systemctl enable flightctl-agent.service

ADD config.yaml /etc/flightctl/
RUN echo "This is a new update" > /etc/motd
