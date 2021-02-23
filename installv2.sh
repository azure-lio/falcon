#!/bin/bash
#Basic enviroment set

set -x

TOP_DIR=$(cd $(dirname "$0") && pwd)
source $TOP_DIR/common
GetOSVersion

if [[ "$os_VENDOR" =~ (Ubuntu)  ]]; then
         echo "OS vendor is Ubutu" $os_RELEASE
elif [[ "$os_VENDOR" =~ (CentOS) ]]; then
         echo "OS Vendor is Centos" $os_RELEASE
else
         echo "Not support this os vendor"
         exit 0
fi

init_lib_common

source $TOP_DIR/functions




function_main()
{
    
    env_set
    install_chrony
    install_openstack_pkg
#First install controller ,then check whether need to install compute
    if [ $controller -eq 1 ] ; then
        install_mariadb
        install_memcache
        install_rabbitmq
        install_etcd
        install_keystone
        install_glance
        install_controller_nova
        install_controller_neutron 
        install_dashboard
        echo "=====Install Successfully  within a control node====="
        echo "Your dashborad address:http://$HOST_IP/dashboard/"
        echo "Doamin:Default"
        echo "User name:admin"
        echo "Password:$PASSWORD"
    fi
#IF in allinone mode ,we install control modules before this

    if [ $compute -eq 1 ] ; then
        install_compute_nova
        install_compute_neutron
    fi
#notify the state of installation    
    if [ $controller -eq 1 ] ; then
        echo "=====Install Successfully  within a control node====="
        echo "Your dashborad address:http://$HOST_IP/dashboard/"
        echo "Doamin:Default"
        echo "User name:admin"
        echo "Password:$PASSWORD"
    fi
}

#call main
function_main

