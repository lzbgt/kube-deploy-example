#!/bin/bash

echo 'source /etc/kubealias.sh' >> /etc/profile
cat <<EOF > /etc/kubealias.sh
    alias k='kubectl -n kube-system'
    alias km='kubectl -n monitoring'
    alias ki='kubectl -n ingress-nginx'
    alias kd=kubectl
EOF

