# falcon
## 最小化openstack 安装，支持centos7.6 openstack R版本，ubutun16.04 queens的安装，centos8.3 U版本的安装。
>控制节点和计算节点分别下载或直接git clone。修改config文件，然后执行install.sh 。安装顺序：先安装控制节点，然后再按安装计算节点。
* install.sh 安装脚本，chmod +x修改为可执行，结合config文件的参数配置进行openstack相应的版本的安装，uninstall.sh用于卸载，慎重使用，会删除数据库清理依赖的包。
* 配置文件config中需要预先设置好环境变量的值，=和前后变量间不留空格。   

MASTERNAME 代表的是控制节点，对应的值是需要设置的主机名称  
* MASTERNAME=controller  

hostname 代表的是当前节点名称，如果是计算和控制合一则名称与master相同即可
* HOSTNAME=controller  

ALLINONE支持在一个节点同时安装控制网络和计算服务，此时hostname和mastername是一样的。如果ALLINONE为0，代表分开部署，计算节点必须设置mastername和server_ip，控制节点不设置server_ip。
* ALLINONE=1  

本安装所有密码采用最简化的统一设置，如果不输入password，则默认是采用的123456
* PASSWORD=smart  
SERVER_IP在安装计算节时必须设置，如果是控制节点或者allinone节点，该地址不填写。server-ip是控制节点管理通道的地址，其他计算节点使用该地址与主控节点通信。
* SERVER_IP=192.168.168.106  

local_ip用来作为数据通道的地址，可以与管理地址(HOST_IP)合一（正式环境不建议），也可以单独设置一个网卡做数据通道。本脚本实现的最小化安装支持的租户类型是vxlan，local_ip也就是vxlan的端点地址。
* LOCAL_IP=192.168.168.106  

HOST_IP用来设置本地管理地址的，用来作为节点管理通道的地址，用于管理通道节点间的通信
* HOST_IP=192.168.168.106
