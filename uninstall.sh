#!/bin/bash


set -x


function remove_for_centos7()
{
    yum remove chrony -y

    yum remove -y  openstack-dashboard
    rm -rf /etc/openstack-dashboard
    rm -rf /etc/httpd/conf.d/openstack-dashboard.conf

    yum remove  -y openstack-neutron openstack-neutron-ml2 openstack-neutron-openvswitch
    sudo rm -rf /etc/neutron/neutron.conf
    sudo rm -rf /etc/neutron/plugins/ml2/ml2_conf.ini
    sudo rm -rf /etc/neutron/plugins/ml2/openvswitch_agent.ini
    sudo rm -rf /etc/neutron/l3_agent.ini
    sudo rm -rf /etc/neutron/dhcp_agent.ini
    sudo rm -rf /etc/neutron/metadata_agent.ini
    yum remove  -y openstack-nova-api openstack-nova-conductor openstack-nova-console openstack-nova-novncproxy  openstack-nova-scheduler openstack-nova-placement-api
    sudo rm -rf /etc/nova/nova.conf
    yum remove  -y  openstack-glance
    sudo rm -rf /etc/glance/glance-api.conf
    sudo rm -rf /etc/glance/glance-registry.conf
    yum remove -y  openstack-keystone httpd mod_wsgi
    sudo rm -rf /etc/keystone/keystone.conf
    sed -i '/\[mysqld\]/,+7d' /etc/my.cnf.d/openstack.cnf

    yum remove -y centos-release-openstack-rocky
    yum remove -y  python-openstackclient
    yum remove  -y mariadb mariadb-server python2-PyMySQL
    sudo rm -rf /var/lib/mysql
    sudo rm -rf /var/lib64/mysql
    yum remove -y  memcached python-memcached
}

TOP_DIR=$(cd $(dirname "$0") && pwd)
source $TOP_DIR/common
GetOSVersion

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

#Remove all the package installed for openstack
if [ $is_cent7 -eq 1 ]  ;then
       echo "Remove  openstack pkg on centos7"
       remove_for_centos7
elif [ $is_cent8 -eq 1 ] ; then
       echo "Remove  openstack pkg On centos8"
elif [ $is_ub16 -eq 1 ] ; then
       echo "Remove  Openstack pkg on Ubutun16"
fi


