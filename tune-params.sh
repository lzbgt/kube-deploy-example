#!/bin/bash

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
