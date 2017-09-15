#!/bin/bash
###############################################
# POD_NETWORK=10.5.2.0/24       pod IPs       #
# SERVICE_IP_RANGE=10.2.0.0/16  service VIPs  #
# K8S_SERVICE_IP=10.2.0.1       API VIP       #
# DNS_SERVICE_IP=10.2.0.10      cluster DNS   #
###############################################

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
sudo mv /tmp/etcd-download-bin/etcdctl /opt/bin
sudo rm -rf /tmp/etcd-*
sudo chmod +x /opt/bin/etcd /opt/bin/etcdctl

sudo mv etcd.service /etc/systemd/system
sudo systemctl daemon-reload
sudo systemctl enable etcd
sudo systemctl start etcd

if [ $(etcdctl member list|wc -l) -eq 2 ]; then
  echo "successfully installed etcd-$ETCD_VER"
else
  echo "problem installing etcd-$ETCD_VER"
fi

# setup flanneld overlay
FLANNELD_VER=v0.8.0
curl -L https://github.com/coreos/flannel/releases/download/${FLANNELD_VER}/flanneld-amd64 -o flanneld
chmod +x flanneld
sudo mv flanneld /opt/bin
nohup sudo flanneld &
sleep 2
etcdctl set /coreos.com/network/config '{ "Network": "10.2.0.0/16", "Backend": {"Type": "vxlan","VNI": 100, "Port": 8472}}'

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
sudo mv kubernetes/client/bin/kubectl  /opt/bin
tar xzf kubernetes/server/kubernetes-server-linux-amd64.tar.gz kubernetes/server/bin/hyperkube --strip-components=3
sudo mv hyperkube /opt/bin
rm -rf kubernetes/

# create certificates
HOST_IP=$(ip -4 addr show | awk '/inet/ {print $2}' | cut -d/ -f1)
LIST_IP=$(for IP in $HOST_IP; do ARR_IP=( "${ARR_IP[@]}" "IP:$IP" );done; echo ${ARR_IP[@]})
chmod +x make-ca-cert.sh
sudo ./make-ca-cert.sh 127.0.0.1 IP:10.2.0.1 IP:10.2.0.10 $(echo $LIST_IP) DNS:$(hostname -f) DNS:$(hostname -s) DNS:demo.dotinceptions.com DNS:master1
sudo mkdir -p /etc/kubernetes/ssl
sudo mv ca.crt /etc/kubernetes/ssl/ca.pem
sudo mv server.cert /etc/kubernetes/ssl/apiserver.pem
sudo mv server.key /etc/kubernetes/ssl/apiserver-key.pem
sudo chmod 600 /etc/kubernetes/ssl/apiserver-key.pem
sudo chown root:root /etc/kubernetes/ssl/apiserver-key.pem
sudo mv basic_auth.csv /etc/kubernetes

# start scheduler services
sudo mv *.service /etc/systemd/system
sudo systemctl enable kube-controller
sudo systemctl start kube-controller
sudo systemctl enable kube-scheduler
sudo systemctl start kube-scheduler
sudo systemctl enable kube-apiserver
sudo systemctl start kube-apiserver
sudo systemctl stop locksmithd
sudo systemctl disable locksmithd

# wait for nodes to register
echo "cluster is coming online..."
while ! /opt/bin/kubectl get no 2>/dev/null|grep -q '\<Ready'; do sleep 2; done

# setup internal host resolution
NODE_HOST=$(/opt/bin/kubectl get nodes -o=jsonpath="{.items[0].metadata.name}")
NODE_IP=$(/opt/bin/kubectl get nodes -o=jsonpath="{.items[0].status.addresses[0].address}")
sudo su - -c "echo $NODE_IP $NODE_HOST >> /etc/hosts"

# install kube-system services
SYS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/kube-config/cluster"

if /opt/bin/kubectl apply -f "$SYS_DIR/" &> /dev/null; then
  echo "cluster pods have been setup"
else
  echo "failed to setup cluster pods"
fi

# install monitoring services
MON_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/kube-config/monitor"

if /opt/bin/kubectl apply -f "$MON_DIR/" &> /dev/null; then
  echo "monitoring pods have been setup"
else
  echo "failed to setup monitoring pods"
fi

exit 0
