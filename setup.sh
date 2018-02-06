#!/bin/bash

# reset iptables
ansible all -m shell -a 'ip link del cni0; ip link del flannel.1; iptables -P INPUT ACCEPT && iptables -P FORWARD ACCEPT && iptables -P OUTPUT ACCEPT && iptables -t nat -F && iptables -t mangle -F && iptables -F && iptables -X && service iptables save'
ansible all -m shell -a 'lsblk|grep sdb'
echo 1> /sys/block/sdb/device/delete
for BUS in /sys/class/scsi_host/host*/scan; do echo "- - -" >  ; done

ansible all -m shell -a 'wipefs -a /dev/sdb --force'

reboot

ansible all -m shell -a ' yum-complete-transaction; yum upgrade -y kubelet kubeadm kubectl kubernetes-cni'

# config yum repos of kuberentes

# install nginx and keepalived

# install masters
kubeadm init --config kubeadm.yaml

scp -r /etc/kubernetes/pki masterN:/etc/kubernetes/
scp -r masterN.yaml masterN:~/
masterN@# kubeadm init --config masterN.yaml

# setup nfs
ansible all -m shell -a 'mkdir /mnt/nfs'
ansible all -m shell -a 'echo "192.168.50.32:/home/nfs_data /mnt/nfs nfs defaults 0 0" >> /etc/fstab'
ansible all -m shell -a 'mount -a'

# docker pull and save images into nfs dir
docker pull gcr.io/google_containers/kube-apiserver-amd64:v1.9.2
docker images save gcr.io/google_containers/kube-apiserver-amd64:v1.9.0 -o /mnt/nfs/k8s/images/kaa1.9.0.tar
ansible all -m shell -a 'docker load -i /mnt/nfs/k8s/images/kaa1.9.0.tar'
docker save quay.io/coreos/flannel:v0.10.0-amd64 -o /mnt/nfs/k8s/images/flannel:v0.10.0-amd64
ansible all -m shell -a 'docker load -i /mnt/nfs/k8s/images/flannel:v0.10.0-amd64'
docker pull gcr.io/google_containers/kube-controller-manager-amd64:v1.9.2
docker image save gcr.io/google_containers/kube-controller-manager-amd64:v1.9.2 -o /mnt/nfs/k8s/images/kube-controller-manager-amd64:v1.9.2.tar
docker pull gcr.io/google_containers/kube-proxy-amd64:v1.9.2
docker save gcr.io/google_containers/kube-proxy-amd64:v1.9.2 -o /mnt/nfs/k8s/images/kube-proxy-amd64:v1.9.2.tar
ansible all -m shell -a 'docker load -i /mnt/nfs/k8s/images/kube-proxy-amd64:v1.9.2.tar'
docker pull gcr.io/google_containers/kube-scheduler-amd64:v1.9.2
docker save gcr.io/google_containers/kube-scheduler-amd64:v1.9.2 -o /mnt/nfs/k8s/images/kube-scheduler-amd64:v1.9.2.tar
ansible all -m shell -a 'docker load -i /mnt/nfs/k8s/images/kube-scheduler-amd64:v1.9.2.tar'

# edit config map to use VIP
kubectl edit configmap/kube-proxy -n kube-system
    server: https://192.168.50.209:8443
k edit configmap/kubeadm-config

# cadvisor port on all nodes
sed -e "/cadvisor-port=0/d" -i /etc/systemd/system/kubelet.service.d/10-kubeadm.conf && systemctl daemon-reload && systemctl restart kubelet
# load images on all nodes

