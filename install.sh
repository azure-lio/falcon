#!/bin/bash
#Basic enviroment set

set -x

TOP_DIR=$(cd $(dirname "$0") && pwd)
source $TOP_DIR/common
GetOSVersion

declare -g is_cent7 is_cent8 is_ub16
if [[ "$os_VENDOR" =~ (Ubuntu)  ]]; then
         echo "OS vendor is Ubutu" $os_RELEASE
         main_num=`echo $os_RELEASE | awk -F '.' '{print $1}'`
         if [[ $main_num -eq 16 ]] ; then
            is_ub16=1
         else
            die "not support this version"

         fi
elif [[ "$os_VENDOR" =~ (CentOS) ]]; then
         echo "OS Vendor is Centos" $os_RELEASE
         main_num=`echo $os_RELEASE | awk -F '.' '{print $1}'`
         if [[ $main_num -eq 7 ]] ; then
             is_cent7=1
             is_cent8=0
         elif [[ $main_num -eq 8 ]]; then
             is_cent7=0
             is_cent8=1
         else
             die "not support this os version"
         fi
else
         echo "Not support this os vendor"
         exit 0
fi


init_lib_common

source $TOP_DIR/functions

function_main()
{

    env_set
    install_openstack_pkg
    install_chrony
#First install controller ,then check whether need to install compute
    if [ $controller -eq 1 ] ; then
        install_mariadb
        install_memcache
        install_rabbitmq
        install_etcd
        install_keystone
        install_glance
        install_placement
        install_controller_nova
        install_netfilter
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
        if [ $is_ub16 -eq 1 ] ; then
            echo "Your dashborad address:http://$HOST_IP/horizon/"
        else
             echo "Your dashborad address:http://$HOST_IP/dashboard/"
        fi
        echo "Doamin:Default"
        echo "User name:admin"
        echo "Password:$PASSWORD"
    fi
}

#call main
function_main
