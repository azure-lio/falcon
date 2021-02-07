#!/bin/bash
#set hostname and host resolve
hostnamectl set-hostname computer1
HOSTNAME=`hostname -s`
#echo $HOSTNAME
if ! fgrep -qwe "$HOSTNAME" /etc/hosts; then
    sudo sed -i '$a 192.168.29.145 '"$HOSTNAME"'' /etc/hosts
fi

sed -i '$a 192.168.29.146   controller' /etc/hosts

#关闭防火墙
systemctl stop firewalld && systemctl disable firewalld

#关闭SELinux
setenforce 0
sed -i "s/SELINUX=enforcing/SELINUX=disabled/g" /etc/selinux/config
#set kernel bridge
modprobe bridge
modprobe br_netfilter
echo "net.bridge.bridge-nf-call-iptables=1" >> /etc/sysctl.conf
echo "net.bridge.bridge-nf-call-ip6tables=1" >> /etc/sysctl.conf

#instal chrony and set ntp
yum install -y chrony
# $a means add at last in file
sed -i '$a allow 192.168.29.0\/24' /etc/chrony.conf
systemctl start chronyd.service && systemctl enable chronyd.service

yum install -y centos-release-openstack-rocky

yum upgrade -y
yum install python-openstackclient -y



#nova compute install
yum install -y openstack-nova-compute

#configure nova.conf


sed -i '/^\[DEFAULT\]/a\firewall_driver = nova.virt.firewall.NoopFirewallDriver' /etc/nova/nova.conf
sed -i '/^\[DEFAULT\]/a\use_neutron = true' /etc/nova/nova.conf
sed -i '/^\[DEFAULT\]/a\my_ip = 192.168.29.145' /etc/nova/nova.conf
sed -i '/^\[DEFAULT\]/a\transport_url = rabbit://openstack:smart@controller' /etc/nova/nova.conf
sed -i '/^\[DEFAULT\]/a\enabled_apis = osapi_compute,metadata' /etc/nova/nova.conf
sed -i '/^\[api\]/a\auth_strategy = keystone' /etc/nova/nova.conf

sed -i '/^\[keystone_authtoken\]/a\password = smart'   /etc/nova/nova/conf
sed -i '/^\[keystone_authtoken\]/a\username = nova'   /etc/nova/nova/conf
sed -i '/^\[keystone_authtoken\]/a\project_name = service'  /etc/nova/nova/conf
sed -i '/^\[keystone_authtoken\]/a\user_domain_name = Default'   /etc/nova/nova/conf
sed -i '/^\[keystone_authtoken\]/a\project_domain_name = Default'   /etc/nova/nova/conf
sed -i '/^\[keystone_authtoken\]/a\auth_type = password'  /etc/nova/nova/conf
sed -i '/^\[keystone_authtoken\]/a\memcached_servers = controller:11211'  /etc/nova/nova/conf
sed -i '/^\[keystone_authtoken\]/a\auth_url = http://controller:5000/v3'  /etc/nova/nova/conf


#vnc section set

sed -i '/^\[vnc\]/a\novncproxy_base_url = http://controller:6080/vnc_auto.html' /etc/nova/nova.conf
sed -i '/^\[vnc\]/a\server_proxyclient_address = $my_ip' /etc/nova/nova.conf
sed -i '/^\[vnc\]/a\server_listen = 0.0.0.0' /etc/nova/nova.conf
sed -i '/^\[vnc\]/a\enabled = true' /etc/nova/nova.conf

#glance section set

sed -i '/^\[glance\]/a\api_servers = http://controller:9292' /etc/nova/nova.conf
sed -i '/^\[oslo_concurrency\]/a\lock_path = /var/lib/nova/tmp' /etc/nova/nova.conf

#placement section
sed -i '/^\[placement\]/a\password = smart' /etc/nova/nova.conf
sed -i '/^\[placement\]/a\username = placement' /etc/nova/nova.conf
sed -i '/^\[placement\]/a\auth_url = http://controller:5000/v3' /etc/nova/nova.conf
sed -i '/^\[placement\]/a\user_domain_name = Default' /etc/nova/nova.conf
sed -i '/^\[placement\]/a\auth_type = password' /etc/nova/nova.conf
sed -i '/^\[placement\]/a\project_name = service' /etc/nova/nova.conf
sed -i '/^\[placement\]/a\project_domain_name = Default' /etc/nova/nova.conf
sed -i '/^\[placement\]/a\region_name = RegionOne' /etc/nova/nova.conf

cpunum=`egrep -c '(vmx|svm)' /proc/cpuinfo`
if [ $cpunum -eq 0 ]
    then
    sed -i '/^\[libvirt\]/a\virt_type = qemu' /etc/nova/nova.conf
fi

systemctl enable libvirtd.service openstack-nova-compute.service
systemctl start libvirtd.service openstack-nova-compute.service

#neutron install in compute node

yum install -y openstack-neutron-openvswitch ebtables ipset

sed -i '/^\[DEFAULT\]/a\transport_url = rabbit://openstack:smart@controller' /etc/neutron/neutron.conf
sed -i '/^\[DEFAULT\]/a\auth_strategy = keystone'  /etc/neutron/neutron.conf
sed -i '/^\[keystone_authtoken\]/a\password = smart'  /etc/neutron/neutron.conf
sed -i '/^\[keystone_authtoken\]/a\username = neutron'  /etc/neutron/neutron.conf
sed -i '/^\[keystone_authtoken\]/a\project_name = service'  /etc/neutron/neutron.conf
sed -i '/^\[keystone_authtoken\]/a\user_domain_name = default'  /etc/neutron/neutron.conf
sed -i '/^\[keystone_authtoken\]/a\project_domain_name = default'  /etc/neutron/neutron.conf
sed -i '/^\[keystone_authtoken\]/a\auth_type = password'  /etc/neutron/neutron.conf
sed -i '/^\[keystone_authtoken\]/a\memcached_servers = controller:11211'  /etc/neutron/neutron.conf
sed -i '/^\[keystone_authtoken\]/a\auth_url = http://controller:5000'  /etc/neutron/neutron.conf
sed -i '/^\[keystone_authtoken\]/a\www_authenticate_uri = http://controller:5000'  /etc/neutron/neutron.conf
sed -i '/^\[oslo_concurrency\]/a\lock_path = /var/lib/neutron/tmp'  /etc/neutron/neutron.conf

#set ovs agent config

sed -i '/^\[ovs\]/a\tunnel_bridge = br-tun' /etc/neutron/plugins/ml2/openvswitch_agent.ini
sed -i '/^tunnel_bridge/a\local_ip = 192.168.29.145' /etc/neutron/plugins/ml2/openvswitch_agent.ini
sed -i '/^local_ip/a\integration_bridge = br-int' /etc/neutron/plugins/ml2/openvswitch_agent.ini
sed -i '/^integration_bridge/a\enable_tunneling = True' /etc/neutron/plugins/ml2/openvswitch_agent.ini
sed -i '/^\[agent\]/a\tunnel_types = vxlan' /etc/neutron/plugins/ml2/openvswitch_agent.ini
sed -i '/^tunnel_types/a\l2_population = True' /etc/neutron/plugins/ml2/openvswitch_agent.ini
sed -i '/^\[securitygroup\]/a\firewall_driver = neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver' /etc/neutron/plugins/ml2/openvswitch_agent.ini
sed -i '/^firewall_driver/a\enable_security_group = True' /etc/neutron/plugins/ml2/openvswitch_agent.ini


#set neutron section in nova.conf

sed -i '/^\[neutron\]/a\password = smart' /etc/nova/nova.conf
sed -i '/^\[neutron\]/a\username = neutron' /etc/nova/nova.conf
sed -i '/^\[neutron\]/a\project_name = service' /etc/nova/nova.conf
sed -i '/^\[neutron\]/a\region_name = RegionOne' /etc/nova/nova.conf
sed -i '/^\[neutron\]/a\user_domain_name = default' /etc/nova/nova.conf
sed -i '/^\[neutron\]/a\project_domain_name = default' /etc/nova/nova.conf
sed -i '/^\[neutron\]/a\auth_type = password' /etc/nova/nova.conf
sed -i '/^\[neutron\]/a\auth_url = http://controller:5000' /etc/nova/nova.conf
sed -i '/^\[neutron\]/a\url = http://controller:9696' /etc/nova/nova.conf

#service start
systemctl restart openstack-nova-compute.service
systemctl enable  neutron-openvswitch-agent.service
systemctl start  neutron-openvswitch-agent.service
