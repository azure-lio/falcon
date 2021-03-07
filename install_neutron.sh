#!/bin/bash


#install basic package
  yum install -y gcc
  yum install -y gcc-c++
  yum install -y autoconf
  yum install -y automake
  yum install -y libtool
  yum install -y openssl-devel
  yum install -y python-devel
  yum install -y python-sphinx
  yum install -y desktop-file-utils
  yum install -y graphviz
  yum install -y unbound-devel
  yum install -y libcap-ng-devel
  yum install -y dpdk-devel
  yum install -y  libpcap-devel
  yum install -y numactl-devel
  yum install -y libmnl-devel

yum -y install wget gcc make python-devel openssl-devel kernel-devel graphviz kernel-debug-devel autoconf automake rpm-build redhat-rpm-config libtool

  yum -y install epel-release
  yum -y install python-pip
  yum -y groupinstall "Development tools"
  pip install -r requirements.txt
  #in centos7 neutron-lib need 1.18
  pip uninstall  -y neutron-lib
  pip install -y neutron-lib==1.18.0
  #config file
 #  PYTHONPATH=. tools/generate_config_file_samples.sh
 #remove config file to dest dir /etc/neutron-dist.conf /usr/share/neutron/
 mkdir -p /etc/neutron/conf.d
 mkdir /var/log/neutron
#add log file dhcp-agent.log  l3-agent.log  metadata-agent.log  openvswitch-agent.log  server.log
 touch /var/log/neutron/dhcp_agent.log
 chmod 777 /var/log/neutron/dhcp_agent.log
#api-paste.ini  conf.d  dhcp_agent.ini  l3_agent.ini  metadata_agent.ini  neutron.conf  plugin.ini  plugins  policy.json

#
  mkdir /usr/share/neutron
 #add this file to the dir
#api-paste.ini  l3_agent  neutron-dist.conf  server
# find the file from rpm package or use source code to generate
 cp neutron-dist.conf /usr/share/neutron/
 cp neutron-enable-bridge-firewall.sh  /usr/bin/
#.service move to /usr/lib/systemd/system
#neutron-server.service
#neutron-openvswitch-agent.service
#neutron-dhcp-agent.service
#neutron-l3-agent.service
#/neutron-metadata-agent.service
#/neutron-ovs-cleanup.service

#modify setup.cfg to auot remove service and other files

python setup.py install --record log

#if need remove use log file to remove installed files
#cat log ｜ xagrs rm -rf

#service need user neutron
groupadd -r neutron
useradd -r -g neutron -d /var/lib/neutron -s /sbin/nologin     -c "OpenStack Neutron Daemons" neutron

 systemctl enable  neutron-server.service
 systemctl start neutron-server.service
systemctl enable neutron-openvswitch-agent.service
systemctl start neutron-openvswitch-agent.service
systemctl start neutron-openvswitch-agent.service
systemctl start neutron-openvswitch-agent.service
systemctl start neutron-openvswitch-agent.service
