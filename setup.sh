#!/bin/bash

yum install -y epel-release yum-utils nfs-utils device-mapper-persistent-data lvm2 && yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo && yum-config-manager --enable docker-ce-edge

yum install iptables-services
systemctl stop firewalld; systemctl disable firewalld

# setup yum repo gateway
cat <<EOF > /etc/yum.repos.d/k8s.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=0
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg
        https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF

# install docker-ce

# modify docker.service

# start docker

# mount nfs
echo "192.168.50.32:/home/nfs_data /mnt/nfs nfs defaults 0 0" >> /etc/fstab
mount -a

# load images from nfs
for file in /mnt/nfs/k8s/images/*; do docker load -i $file; done

# tune system parameters: ansible blast runs a script file as below
sed -i "/mapper\/centos-swap/d" /etc/fstab
# swappiness
echo 'vm.swappiness = 0' >> /etc/sysctl.conf && sysctl -p
# set nofile limit
cat >> /etc/security/limits.d/nofile.conf << EOF
# limits for number of open file for root and default users.
root    hard    nofile  65536
root    soft    nofile  65536
*   hard    nofile  65536
*   soft    nofile  65536
EOF

# tuning TCP, UDP
echo 'vm.max_map_count=262144' >> /etc/sysctl.conf
echo 'net.ipv4.tcp_rmem= 10240 87380 12582912' >> /etc/sysctl.conf
echo 'net.ipv4.tcp_wmem= 10240 87380 12582912' >> /etc/sysctl.conf
echo 'net.core.wmem_max=12582912' >> /etc/sysctl.conf
echo 'net.core.rmem_max=12582912' >> /etc/sysctl.conf
echo 'net.ipv4.tcp_window_scaling = 1' >> /etc/sysctl.conf
echo 'net.ipv4.tcp_timestamps = 1' >> /etc/sysctl.conf
echo 'net.ipv4.tcp_sack = 1' >> /etc/sysctl.conf
echo 'net.ipv4.tcp_no_metrics_save = 1' >> /etc/sysctl.conf
echo 'net.core.netdev_max_backlog = 5000' >> /etc/sysctl.conf
echo 'net.netfilter.nf_conntrack_max=131072' >> /etc/sysctl.conf
echo 32768 > /sys/module/nf_conntrack/parameters/hashsize
echo 'net.netfilter.nf_conntrack_generic_timeout=3' >>/etc/sysctl.conf
echo 'net.netfilter.nf_conntrack_tcp_timeout_established=54000' >> /etc/sysctl.conf
echo 'net.ipv4.netfilter.ip_conntrack_generic_timeout=3' >> /etc/sysctl.conf
echo 'net.ipv4.netfilter.ip_conntrack_tcp_timeout_established=5400' >> /etc/sysctl.conf
echo 'net.ipv4.netfilter.ip_conntrack_tcp_timeout_fin_wait=10' >> /etc/sysctl.conf
echo 'net.netfilter.nf_conntrack_tcp_timeout_fin_wait=10' >> /etc/sysctl.conf
echo 'net.netfilter.nf_conntrack_tcp_timeout_close_wait=3' >> /etc/sysctl.conf
echo 'net.ipv4.netfilter.ip_conntrack_tcp_timeout_close_wait=3' >> /etc/sysctl.conf
echo 'net.ipv4.tcp_tw_reuse=1' >> /etc/sysctl.conf
echo 'net.ipv4.tcp_tw_recycle=1' >> /etc/sysctl.conf
echo 'net.ipv4.tcp_timestamps=1' >> /etc/sysctl.conf
echo 'net.ipv4.tcp_fin_timeout=10' >> /etc/sysctl.conf

sysctl -p



# reset iptables
ansible all -m shell -a 'ip link del cni0; ip link del flannel.1; iptables -P INPUT ACCEPT && iptables -P FORWARD ACCEPT && iptables -P OUTPUT ACCEPT && iptables -t nat -F && iptables -t mangle -F && iptables -F && iptables -X && service iptables save'
ansible all -m shell -a 'lsblk|grep sdb'
echo 1> /sys/block/sdb/device/delete
for BUS in /sys/class/scsi_host/host*/scan; do echo "- - -" >  ; done

ansible all -m shell -a 'wipefs -a /dev/sdb --force'

# reboot

ansible all -m shell -a ' yum-complete-transaction; yum upgrade -y kubelet kubeadm kubectl kubernetes-cni'

# config yum repos of kuberentes

# install nginx and keepalived
yum install nginx keepalived -y

cat << EOF > /etc/keepalived/check_apiserver.sh
#!/bin/bash
err=0
for k in $( seq 1 10 )
do
    check_code=$(ps -ef|grep kube-apiserver |grep -v grep | wc -l)
    if [ "$check_code" = "1" ]; then
        err=$(expr $err + 1)
        sleep 5
        continue
    else
        err=0
        break
    fi
done
if [ "$err" != "0" ]; then
    echo "systemctl stop keepalived"
    /usr/bin/systemctl stop keepalived
    exit 1
else
    exit 0
fi
EOF

cat <<EOF > /etc/keepalived/keepalived.conf
! Configuration File for keepalived
global_defs {
    router_id LVS_DEVEL
}
vrrp_script chk_apiserver {
    script "/etc/keepalived/check_apiserver.sh"
    interval 2
    weight -5
    fall 3  
    rise 2
}
vrrp_instance VI_1 {
    state MASTER
    interface ens160
    mcast_src_ip 192.168.50.57
    virtual_router_id 57
    priority 100
    advert_int 2
    virtual_ipaddress {
        192.168.50.60
    }
    track_script {
       chk_apiserver
    }
}
EOF

cat <<EOF > /etc/nginx/nginx.conf
user  nginx;
worker_processes auto;

error_log  /var/log/nginx/error.log info;
pid        /var/run/nginx.pid;

load_module /usr/lib64/nginx/modules/ngx_stream_module.so;

events {
    worker_connections  1024;
}

stream {

    upstream apiserver {
        server 192.168.50.57:6443 weight=5 max_fails=3 fail_timeout=30s;
        server 192.168.50.58:6443 weight=5 max_fails=3 fail_timeout=30s;
        server 192.168.50.59:6443 weight=5 max_fails=3 fail_timeout=30s;
    }

    server {
        listen 8443;
        proxy_pass apiserver;
    }
}
EOF

# install masters
kubeadm init --config kubeadm.yaml

scp -r /etc/kubernetes/pki masterN:/etc/kubernetes/
scp -r masterN.yaml masterN:~/
masterN@# kubeadm init --config masterN.yaml

# apply flannel
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml

# edit kube-system configmap/kube-proxy

# install workers

# on all workers
sed -i "s/server: .*/server: https:\/\/192.168.50.60:8443/" /etc/kubernetes/*


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

