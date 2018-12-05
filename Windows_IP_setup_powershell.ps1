do{
    Echo "################################################"
    Echo "#    1. Setup IP Address: Static mode          #"
    Echo "#    2. Recovery IP Address Default: DHCP mode #"
    Echo "#    3. Exit                                   #"
    Echo "################################################"
    Echo "`n"
    $SelectString = Read-Host "please select an option:"
    Echo "`n"
    $wmi = Get-WmiObject win32_NetworkAdapterConfiguration -filter "IPEnabled = 'true'"
    switch($SelectString){
        1 {
            $wmi.EnableStatic("192.168.99.253", "255.255.255.0") >$null
            $wmi.SetGateways("192.168.99.254",1) >$null
             $wmi.SetDNSServerSearchOrder("192.168.99.254") >$null
            }
        2 {
            $wmi.SetDNSServerSearchOrder() >$null
            $wmi.EnableDHCP() >$null
           }
        3 {
            Exit
            }
        Default {"input error"}
    }
    Echo "please check details:"
    $IPAddress = $wmi.IPAddress
    $Subnet = $wmi.IPSubnet
    $DefaultIPGateway = $wmi.DefaultIPGateway
    $DNS = $wmi.DNSServerSearchOrder
    Echo "IP Adrress: $IPAddress"
    Echo "   Netmask: $Subnet"
    Echo "   Gateway: $DefaultIPGateway"
    Echo "       DNS: $DNS"
    Echo "`n"
} While($numA -eq 1)
