FROM quay.io/centos-bootc/centos-bootc:stream10

RUN dnf -y copr enable @redhat-et/flightctl centos-stream-9-x86_64 && \
    dnf -y group install GNOME && \
    dnf -y install flightctl-agent && \
    dnf -y clean all && \
    systemctl enable flightctl-agent.service

ADD config.yaml /etc/flightctl/
RUN echo "This is a new update to 10" > /etc/motd
