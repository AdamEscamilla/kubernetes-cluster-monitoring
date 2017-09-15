#!/bin/bash

set -e

# create etcd backend
ETCD_VER=v3.2.5
DOWNLOAD_URL=https://github.com/coreos/etcd/releases/download

rm -f /tmp/etcd-${ETCD_VER}-linux-amd64.tar.gz
rm -rf /tmp/etcd-download-bin && mkdir -p /tmp/etcd-download-bin
curl -L ${DOWNLOAD_URL}/${ETCD_VER}/etcd-${ETCD_VER}-linux-amd64.tar.gz -o /tmp/etcd-${ETCD_VER}-linux-amd64.tar.gz
tar xzf /tmp/etcd-${ETCD_VER}-linux-amd64.tar.gz -C /tmp/etcd-download-bin --strip-components=1

sudo mkdir -p /opt/bin
sudo mv /tmp/etcd-download-bin/etcd /opt/bin
sudo rm -rf /tmp/etcd-*
sudo chmod +x /opt/bin/etcd

sudo mv etcd.service /etc/systemd/system
sudo systemctl daemon-reload
sudo systemctl enable etcd
sudo systemctl start etcd

# setup flanneld overlay
FLANNELD_VER=v0.8.0
curl -L https://github.com/coreos/flannel/releases/download/${FLANNELD_VER}/flanneld-amd64 -o flanneld
chmod +x flanneld
sudo mv flanneld /opt/bin
nohup sudo flanneld &

# wait for flannel config to appear
echo -n "waiting on flanneld..."
while [ ! -f /run/flannel/subnet.env ]; do
  sleep 2
done

# configure docker bip
source /run/flannel/subnet.env
sed -i "s:<CHANGE ME>:$(echo $FLANNEL_SUBNET):" docker.service
sudo mv docker.service /etc/systemd/system
sudo systemctl daemon-reload
sudo systemctl enable docker
sudo systemctl start docker

# download latest kubernetes
DOWNLOAD_URL='https://github.com/kubernetes/kubernetes/releases/latest'
KUBE_VER=$(curl -sI ${DOWNLOAD_URL}|awk '/Location/ {print $2}'|sed 's/\r$//;s/tag/download/')
curl -L -k $KUBE_VER/kubernetes.tar.gz  | gzip -d |tar -xf - 
echo yes | sh kubernetes/cluster/get-kube-binaries.sh
tar xzf kubernetes/server/kubernetes-server-linux-amd64.tar.gz kubernetes/server/bin/hyperkube --strip-components=3
sudo mv hyperkube /opt/bin
rm -rf kubernetes/

chmod +x kubelet-wrapper
sudo mv kubelet-wrapper kubelet.service kube-proxy.service /etc/systemd/system
sudo systemctl daemon-reload
sudo systemctl enable kubelet
sudo systemctl start kubelet
sudo systemctl enable kube-proxy
sudo systemctl start kube-proxy
sudo systemctl stop locksmithd
sudo systemctl disable locksmithd

# allow internal pod dns lookups
sudo ip link set docker0 promisc on
