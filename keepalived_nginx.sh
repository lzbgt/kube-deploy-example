#!/bin/bash

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
    virtual_router_id production57
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

