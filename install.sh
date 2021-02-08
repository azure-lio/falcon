#!/bin/bash
#Basic enviroment set

set -v
TOP_DIR=$(cd $(dirname "$0") && pwd)
if [ ! -f $TOP_DIR/config ]; then
    echo "config does not exit"
    exit 0
fi


source $TOP_DIR/config


if [ -z "$SERVER_IP" ] ;then
    echo "Server ip missing"
    exit 0
fi

HOSTNAME=${HOSTNAME:-controller}
PASSWORD=${PASSWORD:-123456}
MASK_LEN=${MASK_LEN:-24}



env_set()
{

    hostnamectl set-hostname $HOSTNAME
    HOSTNAME=`hostname -s`
#echo $HOSTNAME
    if ! fgrep -qwe "$HOSTNAME" /etc/hosts; then
        sudo sed -i '$a '"$SERVER_IP"' '"$HOSTNAME"'' /etc/hosts
    fi

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


}

function_chrony()
{
    yum install -y chrony
   # $a means add at last in file
    sed -i '$a allow '"$SERVER_IP"'\/'"$MASK_LEN"'' /etc/chrony.conf
    systemctl start chronyd.service && systemctl enable chronyd.service
} 

function_rocky()
{
    yum install -y centos-release-openstack-rocky

    yum upgrade -y
    yum install python-openstackclient -y

}

function_mariadb()
{
    yum install -y mariadb mariadb-server python2-PyMySQL
    if [ ! -f /etc/my.cnf.d/openstack.cnf ] ; then
        touch /etc/my.cnf.d/openstack.cnf
    fi
    
    echo "[mysqld]" >>/etc/my.cnf.d/openstack.cnf

    #sed -i '$a\\[mysqld\]' /etc/my.cnf.d/openstack.cnf
    sed -i '$a bind-address = '"$SERVER_IP"''  /etc/my.cnf.d/openstack.cnf
    sed -i '$a default-storage-engine = innodb'  /etc/my.cnf.d/openstack.cnf
    sed -i '$a innodb_file_per_table = on'  /etc/my.cnf.d/openstack.cnf
    sed -i '$a max_connections = 4096'  /etc/my.cnf.d/openstack.cnf
    sed -i '$a collation-server = utf8_general_ci'  /etc/my.cnf.d/openstack.cnf
    sed -i '$a character-set-server = utf8'  /etc/my.cnf.d/openstack.cnf
    
    systemctl enable mariadb.service && systemctl start mariadb.service

#先采用静态配置，后续测试改动通过配置文件读取
    echo -e "\nY\n$PASSWORD\n$PASSWORD\nY\nn\nY\nY\n" | mysql_secure_installation


}


install_rabbitmq()
{
#install RabbitMq

    yum install -y rabbitmq-server
    systemctl enable rabbitmq-server.service && systemctl start rabbitmq-server.service

#passwd value:smart
    rabbitmqctl add_user openstack $PASSWORD
    rabbitmqctl set_permissions openstack ".*" ".*" ".*"

}

install_memcache()
{
    #memcache install
    yum install -y  memcached python-memcached
    sed -i "s/-l 127.0.0.1,::1/-l 127.0.0.1,::1,'"$HOSTNAME"'/g" /etc/sysconfig/memcached
    systemctl enable memcached.service && systemctl start memcached.service
}


install_etcd()
{

#install  etcd
    yum install -y etcd
    sed -i '/^/,$d' /etc/etcd/etcd.conf
    echo "#[Member]" > /etc/etcd/etcd.conf

    sed -i '$a  ETCD_DATA_DIR="/var/lib/etcd/default.etcd"' /etc/etcd/etcd.conf
    sed -i '$a  ETCD_LISTEN_PEER_URLS="http://'"$SERVER_IP"':2380"' /etc/etcd/etcd.conf
    sed -i '$a  ETCD_LISTEN_CLIENT_URLS="http://'"$SERVER_IP"':2379"' /etc/etcd/etcd.conf
    sed -i '$a  ETCD_NAME="'"$HOSTNAME"'"' /etc/etcd/etcd.conf
    sed -i '$a  #[Clustering]' /etc/etcd/etcd.conf
    sed -i '$a  ETCD_INITIAL_ADVERTISE_PEER_URLS="http://'"$SERVER_IP"':2380"' /etc/etcd/etcd.conf
    sed -i '$a  ETCD_ADVERTISE_CLIENT_URLS="http://'"$SERVER_IP"':2379"' /etc/etcd/etcd.conf
    sed -i '$a  ETCD_INITIAL_CLUSTER="'"$HOSTNAME"'=http://'"$SERVER_IP"':2380"' /etc/etcd/etcd.conf
    sed -i '$a  ETCD_INITIAL_CLUSTER_TOKEN="etcd-cluster-01"' /etc/etcd/etcd.conf
    sed -i '$a  ETCD_INITIAL_CLUSTER_STATE="new"' /etc/etcd/etcd.conf
    systemctl enable etcd && systemctl start etcd

}


function_keystone()
{
    #openstack keystone install
    USERNAME="root"
    mysql -u$USERNAME -p$PASSWORD -e "CREATE DATABASE keystone"
    mysql -u$USERNAME -p$PASSWORD -e "GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'localhost' IDENTIFIED BY '${PASSWORD}'"
    mysql -u$USERNAME -p$PASSWORD -e "GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'%' IDENTIFIED BY '${PASSWORD}'"

    yum install openstack-keystone httpd mod_wsgi -y

    sed -i '/^\[database\]/a\connection = mysql+pymysql://keystone:'"$PASSWORD"'@'"$HOSTNAME"'/keystone' /etc/keystone/keystone.conf
    sed -i '/^\[token\]/a\provider = fernet' /etc/keystone/keystone.conf

    su -s /bin/sh -c "keystone-manage db_sync" keystone

    keystone-manage fernet_setup --keystone-user keystone --keystone-group keystone
    keystone-manage credential_setup --keystone-user keystone --keystone-group keystone
    keystone-manage bootstrap --bootstrap-password $PASSWORD \
     --bootstrap-admin-url http://$HOSTNAME:5000/v3/ \
     --bootstrap-internal-url http://$HOSTNAME:5000/v3/ \
     --bootstrap-public-url http://$HOSTNAME:5000/v3/ \
     --bootstrap-region-id RegionOne
    
    sed -i '$a ServerName '"$HOSTNAME"'' /etc/httpd/conf/httpd.conf
    #echo "ServerName controller" >> /etc/httpd/conf/httpd.conf
    ln -s /usr/share/keystone/wsgi-keystone.conf /etc/httpd/conf.d/
    systemctl enable httpd.service && systemctl start httpd.service

    if [ -f /home/admin-openrc ]
        then
          sed -i '/^/,$d' /home/admin-openrc
    else
        touch /home/admin-openrc
    fi
    echo "export OS_USERNAME=admin" >> /home/admin-openrc
    sed -i '$a OS_PASSWORD='"$PASSWORD"''    /home/admin-openrc
    echo "export OS_PROJECT_NAME=admin" >> /home/admin-openrc
    echo "export OS_USER_DOMAIN_NAME=Default" >> /home/admin-openrc
    echo "export OS_PROJECT_DOMAIN_NAME=Default" >> /home/admin-openrc
    #echo "export OS_AUTH_URL=http://controller:5000/v3" >> /home/admin-openrc
    sed -i '$a export OS_AUTH_URL=http://'"$HOSTNAME"':5000/v3' /home/admin-openrc
    echo "export OS_IDENTITY_API_VERSION=3" >> /home/admin-openrc
    echo "export OS_IMAGE_API_VERSION=2"    >>/home/admin-openrc
    source /home/admin-openrc
    openstack project create --domain default --description "Service Project" service

}


function_glance()
{
# Image service install for control node
    USERNAME="root"
    mysql -u$USERNAME -p$PASSWORD -e "CREATE DATABASE glance"
    mysql -u$USERNAME -p$PASSWORD -e "GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'localhost' IDENTIFIED BY '${PASSWORD}'"
    mysql -u$USERNAME -p$PASSWORD -e "GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'%' IDENTIFIED BY '${PASSWORD}'"

    openstack user create --domain default --password $PASSWORD glance
    openstack role add --project service --user glance admin
    openstack service create --name glance --description "OpenStack Image" image
    openstack endpoint create --region RegionOne image public http://$HOSTNAME:9292
    openstack endpoint create --region RegionOne image internal http://$HOSTNAME:9292
    openstack endpoint create --region RegionOne image admin http://$HOSTNAME:9292
    yum install -y  openstack-glance

#config glance-api.conf
    sed -i '/^\[database\]/a\connection = mysql+pymysql://glance:'"$PASSWORD"'@'"$HOSTNAME"'/glance' /etc/glance/glance-api.conf

    sed -i '/^\[keystone_authtoken\]/a\password = '"$PASSWORD"''      /etc/glance/glance-api.conf
    sed -i '/^\[keystone_authtoken\]/a\username = glance' /etc/glance/glance-api.conf
    sed -i '/^\[keystone_authtoken\]/a\project_name = service' /etc/glance/glance-api.conf
    sed -i '/^\[keystone_authtoken\]/a\user_domain_name = Default' /etc/glance/glance-api.conf
    sed -i '/^\[keystone_authtoken\]/a\project_domain_name = Default' /etc/glance/glance-api.conf
    sed -i '/^\[keystone_authtoken\]/a\auth_type = password' /etc/glance/glance-api.conf
    sed -i '/^\[keystone_authtoken\]/a\memcached_servers = '"$HOSTNAME"':11211' /etc/glance/glance-api.conf
    sed -i '/^\[keystone_authtoken\]/a\auth_url = http://'"$HOSTNAME"':5000' /etc/glance/glance-api.conf
    sed -i '/^\[keystone_authtoken\]/a\www_authenticate_uri  = http://'"$HOSTNAME"':5000'    /etc/glance/glance-api.conf

    sed -i '/^\[paste_deploy\]/a\flavor = keystone' /etc/glance/glance-api.conf

    sed -i '/^\[glance_store\]/a\filesystem_store_datadir = /var/lib/glance/images/' /etc/glance/glance-api.conf
    sed -i '/^\[glance_store\]/a\default_store = file'         /etc/glance/glance-api.conf
    sed -i '/^\[glance_store\]/a\stores = file,http' /etc/glance/glance-api.conf


#config glance-registry.conf
    sed -i '/^\[database\]/a\connection = mysql+pymysql://glance:'"$PASSWORD"'@'"$HOSTNAME"'/glance' /etc/glance/glance-registry.conf

    sed -i '/^\[keystone_authtoken\]/a\password = '"$PASSWORD"''      /etc/glance/glance-registry.conf
    sed -i '/^\[keystone_authtoken\]/a\username = glance' /etc/glance/glance-registry.conf
    sed -i '/^\[keystone_authtoken\]/a\project_name = service' /etc/glance/glance-registry.conf
    sed -i '/^\[keystone_authtoken\]/a\user_domain_name = Default' /etc/glance/glance-registry.conf
    sed -i '/^\[keystone_authtoken\]/a\project_domain_name = Default' /etc/glance/glance-registry.conf
    sed -i '/^\[keystone_authtoken\]/a\auth_type = password' /etc/glance/glance-registry.conf
    sed -i '/^\[keystone_authtoken\]/a\memcached_servers = '"$HOSTNAME"':11211' /etc/glance/glance-registry.conf
    sed -i '/^\[keystone_authtoken\]/a\auth_url = http://'"$HOSTNAME"':5000' /etc/glance/glance-registry.conf
    sed -i '/^\[keystone_authtoken\]/a\www_authenticate_uri  = http://'"$HOSTNAME"':5000'    /etc/glance/glance-registry.conf

    sed -i '/^\[paste_deploy\]/a\flavor = keystone' /etc/glance/glance-registry.conf

    su -s /bin/sh -c "glance-manage db_sync" glance

#glance final installation
    systemctl enable openstack-glance-api.service openstack-glance-registry.service
    systemctl start openstack-glance-api.service  openstack-glance-registry.service

}

function_nova()
{

#nova install  install for controller node
    USERNAME="root"
    mysql -u$USERNAME -p$PASSWORD -e  "CREATE DATABASE nova_api"
    mysql -u$USERNAME -p$PASSWORD -e  "CREATE DATABASE nova"
    mysql -u$USERNAME -p$PASSWORD -e  "CREATE DATABASE nova_cell0"
    mysql -u$USERNAME -p$PASSWORD -e  "CREATE DATABASE placement"
#grant privileges
    mysql -u$USERNAME -p$PASSWORD -e  "GRANT ALL PRIVILEGES ON nova_api.* TO 'nova'@'localhost' IDENTIFIED BY '${PASSWORD}'"
    mysql -u$USERNAME -p$PASSWORD -e  "GRANT ALL PRIVILEGES ON nova_api.* TO 'nova'@'%' IDENTIFIED BY '${PASSWORD}'"
    mysql -u$USERNAME -p$PASSWORD -e  "GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'localhost' IDENTIFIED BY '${PASSWORD}'"
    mysql -u$USERNAME -p$PASSWORD -e  "GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'%' IDENTIFIED BY '${PASSWORD}'"
    mysql -u$USERNAME -p$PASSWORD -e  "GRANT ALL PRIVILEGES ON nova_cell0.* TO 'nova'@'localhost' IDENTIFIED BY '${PASSWORD}'"
    mysql -u$USERNAME -p$PASSWORD -e  "GRANT ALL PRIVILEGES ON nova_cell0.* TO 'nova'@'%' IDENTIFIED BY '${PASSWORD}'"
    mysql -u$USERNAME -p$PASSWORD -e  "GRANT ALL PRIVILEGES ON placement.* TO 'placement'@'localhost' IDENTIFIED BY '${PASSWORD}'"
    mysql -u$USERNAME -p$PASSWORD -e  "GRANT ALL PRIVILEGES ON placement.* TO 'placement'@'%' IDENTIFIED BY '${PASSWORD}'"

#create user nova
    openstack user create --domain default --password $PASSWORD  nova
    openstack role add --project service --user nova admin
    openstack service create --name nova  --description "OpenStack Compute" compute

#endpoint create
    openstack endpoint create --region RegionOne compute public http://$HOSTNAME:8774/v2.1
    openstack endpoint create --region RegionOne compute internal http://$HOSTNAME:8774/v2.1
    openstack endpoint create --region RegionOne compute admin http://$HOSTNAME:8774/v2.1


    openstack user create --domain default --password $PASSWORD placement
    openstack role add --project service --user placement admin
#placement endpoint create

    openstack service create --name placement --description "Placement API" placement
    openstack endpoint create --region RegionOne placement public http://$HOSTNAME:8778
    openstack endpoint create --region RegionOne placement internal http://$HOSTNAME:8778
    openstack endpoint create --region RegionOne placement admin http://$HOSTNAME:8778

#nova package install
    yum install -y openstack-nova-api openstack-nova-conductor openstack-nova-console openstack-nova-novncproxy  openstack-nova-scheduler openstack-nova-placement-api

    #nova config
    sed -i '/^\[DEFAULT\]/a\firewall_driver = nova.virt.firewall.NoopFirewallDriver' /etc/nova/nova.conf
    sed -i '/^\[DEFAULT\]/a\use_neutron = true' /etc/nova/nova.conf
    sed -i '/^\[DEFAULT\]/a\my_ip = 192.168.29.145' /etc/nova/nova.conf
    sed -i '/^\[DEFAULT\]/a\transport_url = rabbit://openstack:'"$PASSWORD"'@'"$HOSTNAME"'' /etc/nova/nova.conf
    sed -i '/^\[DEFAULT\]/a\enabled_apis = osapi_compute,metadata' /etc/nova/nova.conf


    sed -i '/^\[api_database\]/a\connection = mysql+pymysql://nova:'"$PASSWORD"'@'"$HOSTNAME"'/nova_api' /etc/nova/nova.conf
    sed -i '/^\[database\]/a\connection = mysql+pymysql://nova:'"$PASSWORD"'@'"$HOSTNAME"'/nova' /etc/nova/nova.conf
    sed -i '/^\[placement_database\]/a\connection = mysql+pymysql://placement:'"$PASSWORD"'@'"$HOSTNAME"'/placement' /etc/nova/nova.conf
    sed -i '/^\[api\]/a\auth_strategy = keystone' /etc/nova/nova.conf
#keystone authtoken
    sed -i '/^\[keystone_authtoken\]/a\password = '"$PASSWORD"''      /etc/nova/nova.conf
    sed -i '/^\[keystone_authtoken\]/a\username = nova' /etc/nova/nova.conf
    sed -i '/^\[keystone_authtoken\]/a\project_name = service' /etc/nova/nova.conf
    sed -i '/^\[keystone_authtoken\]/a\user_domain_name = Default' /etc/nova/nova.conf
    sed -i '/^\[keystone_authtoken\]/a\project_domain_name = Default'  /etc/nova/nova.conf
    sed -i '/^\[keystone_authtoken\]/a\auth_type = password' /etc/nova/nova.conf
    sed -i '/^\[keystone_authtoken\]/a\memcached_servers = '"$HOSTNAME"':11211' /etc/nova/nova.conf
    sed -i '/^\[keystone_authtoken\]/a\auth_url = http://'"$HOSTNAME"':5000/v3'    /etc/nova/nova.conf


#vnc server
    sed -i '/^\[vnc\]/a\server_listen/a\server_proxyclient_address = $my_ip' /etc/nova/nova.conf
    sed -i '/^\[vnc\]/a\server_listen = $my_ip' /etc/nova/nova.conf
    sed -i '/^\[vnc\]/a\enabled = true' /etc/nova/nova.conf

    sed -i '/^\[glance\]/a\api_servers = http://'"$HOSTNAME"':9292' /etc/nova/nova.conf
    sed -i '/^\[oslo_concurrency\]/a\lock_path = /var/lib/nova/tmp' /etc/nova/nova.conf
    sed -i '/^\[placement\]/a\password = '"$PASSWORD"'' /etc/nova/nova.conf
    sed -i '/^\[placement\]/a\username = placement' /etc/nova/nova.conf
    sed -i '/^\[placement\]/a\auth_url = http://'"$HOSTNAME"':5000/v3' /etc/nova/nova.conf
    sed -i '/^\[placement\]/a\user_domain_name = Default' /etc/nova/nova.conf
    sed -i '/^\[placement\]/a\auth_type = password' /etc/nova/nova.conf
    sed -i '/^\[placement\]/a\project_name = service' /etc/nova/nova.conf
    sed -i '/^\[placement\]/a\project_domain_name = Default' /etc/nova/nova.conf
    sed -i '/^\[placement\]/a\region_name = RegionOne' /etc/nova/nova.conf
    sed -i '/^\[scheduler\]/a\discover_hosts_in_cells_interval = 300'  /etc/nova/nova.conf
    sed -i '/$/a\\n' /etc/httpd/conf.d/00-nova-placement-api.conf
    tee -a /etc/httpd/conf.d/00-nova-placement-api.conf <<-'EOF'
<Directory /usr/bin>
       <IfVersion >= 2.4>
          Require all granted
       </IfVersion>
       <IfVersion < 2.4>
          Order allow,deny
          Allow from all
       </IfVersion>
    </Directory>
EOF

    systemctl restart httpd
    su -s /bin/sh -c "nova-manage api_db sync" nova
    su -s /bin/sh -c "nova-manage cell_v2 map_cell0" nova
    su -s /bin/sh -c "nova-manage cell_v2 create_cell --name=cell1 --verbose" nova
    su -s /bin/sh -c "nova-manage db sync" nova

    systemctl enable openstack-nova-api.service \
      openstack-nova-consoleauth openstack-nova-scheduler.service \
      openstack-nova-conductor.service openstack-nova-novncproxy.service

    systemctl start openstack-nova-api.service \
      openstack-nova-consoleauth openstack-nova-scheduler.service \
      openstack-nova-conductor.service openstack-nova-novncproxy.service
}

function_neutron()
{

    #neutron install for control node
    USERNAME="root"
    mysql -u$USERNAME -p$PASSWORD -e  "CREATE DATABASE neutron"
    mysql -u$USERNAME -p$PASSWORD -e  "GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'localhost' IDENTIFIED BY '${PASSWORD}'"
    mysql -u$USERNAME -p$PASSWORD -e  "GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'%' IDENTIFIED BY '${PASSWORD}'"
    openstack user create --domain default --password $PASSWORD  neutron
    openstack role add --project service --user neutron admin

    openstack service create --name neutron  --description "OpenStack Networking" network

#endpoint set for neutron
    openstack endpoint create --region RegionOne network public http://$HOSTNAME:9696
    openstack endpoint create --region RegionOne network internal http://$HOSTNAME:9696
    openstack endpoint create --region RegionOne network admin http://$HOSTNAME:9696

    yum install -y openstack-neutron openstack-neutron-ml2 openstack-neutron-openvswitch

#neutron config file
    sed -i '/^\[database\]/a\connection = mysql+pymysql://neutron:'"$PASSWORD"'@'"$HOSTNAME"'/neutron' /etc/neutron/neutron.conf
    sed -i '/^\[DEFAULT\]/a\core_plugin = ml2' /etc/neutron/neutron.conf
    sed -i '/^core_plugin/a\service_plugins=router' /etc/neutron/neutron.conf
    sed -i '/^service_plugins/a\allow_overlapping_ips = true'  /etc/neutron/neutron.conf
    sed -i '/^allow_overlapping_ips/a\transport_url = rabbit://openstack:'"$PASSWORD"'@'"$HOSTNAME"'' /etc/neutron/neutron.conf
    sed -i '/^transport_url/a\auth_strategy = keystone' /etc/neutron/neutron.conf
    sed -i '/^auth_strategy/a\notify_nova_on_port_status_changes = true' /etc/neutron/neutron.conf
    sed -i '/^notify_nova_on_port_status_changes/a\notify_nova_on_port_data_changes = true' /etc/neutron/neutron.conf

#keysstone_auth for neutron
    sed -i '/^\[keystone_authtoken\]/a\password = '"$PASSWORD"'' /etc/neutron/neutron.conf
    sed -i '/^\[keystone_authtoken\]/a\username = neutron' /etc/neutron/neutron.conf
    sed -i '/^\[keystone_authtoken\]/a\project_name = service' /etc/neutron/neutron.conf
    sed -i '/^\[keystone_authtoken\]/a\user_domain_name = default' /etc/neutron/neutron.conf
    sed -i '/^\[keystone_authtoken\]/a\project_domain_name = default' /etc/neutron/neutron.conf
    sed -i '/^\[keystone_authtoken\]/a\auth_type = password' /etc/neutron/neutron.conf
    sed -i '/^\[keystone_authtoken\]/a\memcached_servers = '"$HOSTNAME"':11211'          /etc/neutron/neutron.conf
    sed -i '/^\[keystone_authtoken\]/a\auth_url = http://'"$HOSTNAME"':5000' /etc/neutron/neutron.conf
    sed -i '/^\[keystone_authtoken\]/a\www_authenticate_uri = http://'"$HOSTNAME"':5000' /etc/neutron/neutron.conf

#set nova section in neutron.conf
    sed -i '/^\[nova\]/a\password = '"$PASSWORD"'' /etc/neutron/neutron.conf
    sed -i '/^\[nova\]/a\username = nova' /etc/neutron/neutron.conf
    sed -i '/^\[nova\]/a\project_name = service' /etc/neutron/neutron.conf
    sed -i '/^\[nova\]/a\region_name = RegionOne' /etc/neutron/neutron.conf
    sed -i '/^\[nova\]/a\user_domain_name = default' /etc/neutron/neutron.conf
    sed -i '/^\[nova\]/a\project_domain_name = default' /etc/neutron/neutron.conf
    sed -i '/^\[nova\]/a\auth_type = password' /etc/neutron/neutron.conf
    sed -i '/^\[nova\]/a\auth_url = http://'"$HOSTNAME"':5000' /etc/neutron/neutron.conf

    sed -i '/^\[oslo_concurrency\]/a\lock_path = /var/lib/neutron/tmp' /etc/neutron/neutron.conf


#set ml2 plugin config file

    sed -i '/^\[ml2\]/a\type_drivers = flat,vlan,vxlan' /etc/neutron/plugins/ml2/ml2_conf.ini
    sed -i '/^type_drivers/a\tenant_network_types = vxlan' /etc/neutron/plugins/ml2/ml2_conf.ini
    sed -i '/^tenant_network_types/a\mechanism_drivers = openvswitch,l2population' /etc/neutron/plugins/ml2/ml2_conf.ini
    sed -i '/^mechanism_drivers/a\extension_drivers = port_security' /etc/neutron/plugins/ml2/ml2_conf.ini
    sed -i '/^\[ml2_type_vxlan\]/a\vni_ranges = 1:1000' /etc/neutron/plugins/ml2/ml2_conf.ini
    sed -i '/^\[securitygroup\]/a\enable_ipset = true' /etc/neutron/plugins/ml2/ml2_conf.ini

#set ovs agent config
    sed -i '/^\[ovs\]/a\tunnel_bridge = br-tun' /etc/neutron/plugins/ml2/openvswitch_agent.ini
    sed -i '/^tunnel_bridge/a\local_ip = 192.168.29.145' /etc/neutron/plugins/ml2/openvswitch_agent.ini
    sed -i '/^local_ip/a\integration_bridge = br-int' /etc/neutron/plugins/ml2/openvswitch_agent.ini
    sed -i '/^integration_bridge/a\enable_tunneling = True' /etc/neutron/plugins/ml2/openvswitch_agent.ini
    sed -i '/^\[agent\]/a\tunnel_types = vxlan' /etc/neutron/plugins/ml2/openvswitch_agent.ini
    sed -i '/^tunnel_types/a\l2_population = True' /etc/neutron/plugins/ml2/openvswitch_agent.ini
    sed -i '/^\[securitygroup\]/a\firewall_driver = neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver' /etc/neutron/plugins/ml2/openvswitch_agent.ini
    sed -i '/^firewall_driver/a\enable_security_group = True' /etc/neutron/plugins/ml2/openvswitch_agent.ini

#l3 agent set
    sed -i '/^\[DEFAULT\]/a\interface_driver = neutron.agent.linux.interface.OVSInterfaceDriver' /etc/neutron/l3_agent.ini

#dhcp agent set
    sed -i '/^\[DEFAULT\]/a\interface_driver = neutron.agent.linux.interface.OVSInterfaceDriver' /etc/neutron/dhcp_agent.ini
    sed -i '/^interface_driver/a\dhcp_driver = neutron.agent.linux.dhcp.Dnsmasq' /etc/neutron/dhcp_agent.ini
    sed -i '/^dhcp_driver/a\enable_isolated_metadata = True' /etc/neutron/dhcp_agent.ini

#set metadata
    sed -i '/^\[DEFAULT\]/a\nova_metadata_host = '"$HOSTNAME"'' /etc/neutron/metadata_agent.ini
    sed -i '/^nova_metadata_host/a\metadata_proxy_shared_secret = '"$PASSWORD"'' /etc/neutron/metadata_agent.ini

#set neutron section in nova.conf
    sed -i '/^\[neutron\]/a\metadata_proxy_shared_secret = '"$PASSWORD"'' /etc/nova/nova.conf
    sed -i '/^\[neutron\]/a\service_metadata_proxy = true' /etc/nova/nova.conf
    sed -i '/^\[neutron\]/a\password = '"$PASSWORD"'' /etc/nova/nova.conf
    sed -i '/^\[neutron\]/a\username = neutron' /etc/nova/nova.conf
    sed -i '/^\[neutron\]/a\project_name = service' /etc/nova/nova.conf
    sed -i '/^\[neutron\]/a\region_name = RegionOne' /etc/nova/nova.conf
    sed -i '/^\[neutron\]/a\user_domain_name = default' /etc/nova/nova.conf
    sed -i '/^\[neutron\]/a\project_domain_name = default' /etc/nova/nova.conf
    sed -i '/^\[neutron\]/a\auth_type = password' /etc/nova/nova.conf
    sed -i '/^\[neutron\]/a\auth_url = http://'"$HOSTNAME"':5000' /etc/nova/nova.conf
    sed -i '/^\[neutron\]/a\url = http://'"$HOSTNAME"':9696' /etc/nova/nova.conf

    ln -s /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugin.ini

#write to db
    su -s /bin/sh -c "neutron-db-manage --config-file /etc/neutron/neutron.conf \
      --config-file /etc/neutron/plugins/ml2/ml2_conf.ini upgrade head" neutron

    systemctl restart openstack-nova-api.service

    systemctl enable neutron-server.service neutron-openvswitch-agent.service  neutron-dhcp-agent.service neutron-metadata-agent.service
    systemctl start neutron-server.service neutron-openvswitch-agent.service  neutron-dhcp-agent.service neutron-metadata-agent.service
    systemctl enable neutron-l3-agent.service
    systemctl start neutron-l3-agent.service

}


function_dashboard()
{
#dashboard install
    yum install -y  openstack-dashboard

    sed -i 's/^OPENSTACK_HOST.*/OPENSTACK_HOST = "'"$HOSTNAME"'"/' /etc/openstack-dashboard/local_settings
    sed -i "s/ALLOWED_HOSTS.*/ALLOWED_HOSTS = [\'*\']/" /etc/openstack-dashboard/local_settings
    sed -i "/^ALLOWED_HOSTS/a\SESSION_ENGINE = \'django.contrib.sessions.backends.cache\'" /etc/openstack-dashboard/local_settings
    sed -i '/^CACHES/,+5d' /etc/openstack-dashboard/local_settings
    tee >> /etc/openstack-dashboard/local_settings <<-'EOF'
CACHES = {
    'default': {
         'BACKEND': 'django.core.cache.backends.memcached.MemcachedCache',
EOF

    sed -i   '$a        'LOCATION': '$HOSTNAME:11211','  /etc/openstack-dashboard/local_settings
    echo "      }" >> /etc/openstack-dashboard/local_settings
    echo "}"  >>/etc/openstack-dashboard/local_settings
#
    sed -i 's/^#OPENSTACK_KEYSTONE_MULTIDOMAIN_SUPPORT.*/OPENSTACK_KEYSTONE_MULTIDOMAIN_SUPPORT = True/' /etc/openstack-dashboard/local_settings

    tee >> /etc/openstack-dashboard/local_settings <<-'EOF'
OPENSTACK_API_VERSIONS = {
        "identity": 3,
        "image": 2,
        "volume": 2,
    }  
EOF
    sed -i 's/^#OPENSTACK_KEYSTONE_DEFAULT_DOMAIN.*/OPENSTACK_KEYSTONE_DEFAULT_DOMAIN = "Default"/' /etc/openstack-dashboard/local_settings
    sed -i 's/^OPENSTACK_KEYSTONE_DEFAULT_ROLE.*/OPENSTACK_KEYSTONE_DEFAULT_ROLE = "user"/' /etc/openstack-dashboard/local_settings

    sed -i '/$/a\WSGIApplicationGroup %{GLOBAL}' /etc/httpd/conf.d/openstack-dashboard.conf
    systemctl restart httpd.service memcached.service

}


function_main()
{
    env_set
    function_chrony
    function_rocky
    function_mariadb
    install_memcache
    install_etcd
    function_keystone
    function_glance
    function_nova
    function_neutron
    function_dashboard
}

#call main
function_main
