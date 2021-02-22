# falcon
* 极简化，minimal 的openstack R版本安装脚本。控制节点和计算节点分别下载 install.sh,单独执行，执行之前先配置config文件，其中包含的是安装过程中用到的环境变量的值。先安装控制节点，然后再按照计算节点。
* install.sh to install opentack rocky for centos7.6
* 支持最小化安装centos 7.6的openstack rocky版本
* 配置文件config中需要预先设置好环境变量的值    
mastername 代表的是控制节点，对应的名称是需要设置的主机名称  
* MASTERNAME=controller  
hostname 代表的是当前节点名称，如果是计算和控制合一则名称与master相同即可
* HOSTNAME=controller  
allinone支持在一个节点同时安装控制和计算服务，此时hostname和mastername是一样的。如果allinone为0，代表分开部署，计算节点必须设置mastername和server_ip。
* ALLINONE=1  
本安装所有密码采用最简化的统一设置，如果不输入password，则默认是采用的123456
* PASSWORD=smart  
SERVER_IP在计算节点安装时必须提供，用来设置计算节点与控制节点通信，server-ip是控制节点管理通道的地址
* SERVER_IP=192.168.168.106  
local_ip用来作为最小化安装支持的租户类型是vxlan时的数据通信接口地址，也就是vxlan的端点地址。该地址可以与管理通道配置相同也可以单独一个数据通道
* LOCAL_IP=192.168.168.106  
HOST_IP用来设置本地地址的，用来作为节点管理通道的地址
* HOST_IP=192.168.168.106
