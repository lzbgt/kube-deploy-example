#!/bin/bash
declare -a etcd_hosts_ip=("192.168.50.210" "192.168.50.211" "192.168.50.212")
declare -a etcd_hosts
function join_by { local IFS="$1"; shift; echo "$*"; }

echo ${#etcd_hosts_ip[@]}
for (( i=0; i<${#etcd_hosts_ip[@]};i++));
do
    etcd_hosts[$i]=etcd$i\=http://${etcd_hosts_ip[$i]}:2380
done
etcd_cluster=$(join_by , "${etcd_hosts[@]}")
echo "etcd cluster: "$etcd_cluster

let i=0
for h in "${etcd_hosts_ip[@]}";
do
    node=$h
    name=etcd$i
    let i=i+1
    ssh root@$node /bin/bash << EOF 
    docker stop etcd; docker rm etcd
    rm -fr /var/lib/etcd/
    rm -rf /var/lib/etcd-cluster
    mkdir -p /var/lib/etcd-cluster
    docker run -d \
    --restart always \
    -v /etc/ssl/certs:/etc/ssl/certs \
    -v /var/lib/etcd-cluster:/var/lib/etcd \
    -p 4001:4001 \
    -p 2380:2380 \
    -p 2379:2379 \
    --name etcd \
    gcr.io/google_containers/etcd-amd64:3.1.11 \
    etcd --name=$name \
    --advertise-client-urls=http://$node:2379,http://$node:4001 \
    --listen-client-urls=http://0.0.0.0:2379,http://0.0.0.0:4001 \
    --initial-advertise-peer-urls=http://$node:2380 \
    --listen-peer-urls=http://0.0.0.0:2380 \
    --initial-cluster=$etcd_cluster \
    --initial-cluster-token=etc-cluster-0 \
    --initial-cluster-state=new \
    --auto-tls \
    --peer-auto-tls \
    --data-dir=/var/lib/etcd
EOF
done
