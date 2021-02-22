#!/bin/bash

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

USERNAME="root"
PASSWD="smart"
drop_db(){
mysql -u$USERNAME -p$PASSWD -e  "DROP DATABASE neutron"
mysql -u$USERNAME -p$PASSWD -e  "DROP DATABASE nova_api"
mysql -u$USERNAME -p$PASSWD -e  "DROP DATABASE nova"
mysql -u$USERNAME -p$PASSWD -e  "DROP DATABASE nova_cell0"
mysql -u$USERNAME -p$PASSWD -e  "DROP DATABASE placement"
mysql -u$USERNAME -p$PASSWD -e  "DROP DATABASE glance"
mysql -u$USERNAME -p$PASSWD -e  "DROP DATABASE keystone"
}

sed -i '/\[mysqld\]/,+7d' /etc/my.cnf.d/openstack.cnf

yum remove -y centos-release-openstack-rocky
yum remove -y  python-openstackclient
yum remove  -y mariadb mariadb-server python2-PyMySQL
sudo rm -rf /var/lib/mysql
sudo rm -rf /var/lib64/mysql

yum remove -y  memcached python-memcached 

