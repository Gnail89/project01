文件说明:
1、disk_discovery.py    扫描磁盘列表的脚本
2、userparameter_diskstats.conf    用户自定义参数配置文件
3、Template Disk Performance.xml    zabbix 2.0 模板配置文件

使用说明：

步骤1：将disk_discovery.py脚本复制到以下指定位置：/usr/local/zabbix_agentd/scripts/disk_discovery.py

步骤2：将userparameter_diskstats.conf自定义参数配置文件复制到以下指定位置：/usr/local/zabbix_agentd/etc/zabbix_agentd.conf.d/userparameter_diskstats.conf
       , 并开启zabbix agent服务以下配置项(/usr/local/zabbix_agentd/etc/zabbix_agentd.conf)：
       Include=/usr/local/zabbix_agentd/etc/zabbix_agentd.conf.d/
       UnsafeUserParameters=1
       
步骤3：将Template Disk Performance.xml从web界面默认导入到zabbix server中.

步骤4：将模板应用于被监控host
