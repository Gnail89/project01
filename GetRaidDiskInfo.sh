#!/bin/bash

declare -r megacli_tool="/opt/MegaRAID/MegaCli/MegaCli64"
declare -r ssacli_tool="/usr/sbin/ssacli"
Global_Status_RLevel=0

ipaddr="unknown"

SASDiskCount=0
declare -a SASDiskSize
declare -a SASDeviceSpeed
declare -a SASRaidLevelList

SATADiskCount=0
declare -a SATADiskSize
declare -a SATADeviceSpeed
declare -a SATARaidLevelList

SSDCount=0
declare -a SSDSize
declare -a SSDDeviceSpeed
declare -a SSDRaidLevelList

PCIECount=0
declare -a PCIESize


function GetIPAddr(){
    if [ $(ip addr show |grep '10\.191\.' |wc -l) -ne 0 ]; then
        ipaddr="$(ip -o -4 addr show scope global primary |grep '10\.191\.' |awk '{print $4}' |sed "s/\/.*//" |sed -n 1p)"
    else
        ipaddr="$(ip -o -4 addr show scope global primary |awk '{print $4}' |sed "s/\/.*//" |sed -n 1p)"
    fi
}


function SAS_GetHDDCount(){
    local l_pcount="$1"
    SASDiskCount="$(( SASDiskCount + l_pcount ))"
    unset l_pcount
}


function SAS_GetHDDSize(){
    local l_psize="$1"
    local l_psize_tag=0
    for ((p=0;p<${#SASDiskSize[*]};p++));do
        if [ x"${SASDiskSize[${p}]}" != x"" ]; then
            if [ x"${SASDiskSize[${p}]}" == x"${l_psize}" ]; then
                l_psize_tag=1
                break
            else
                l_psize_tag=0
                continue
            fi
        fi
    done
    if [ ${l_psize_tag} -eq 0 ]; then
        SASDiskSize[${#SASDiskSize[*]}]="${l_psize}"
    fi
    unset p l_psize l_psize_tag
}


function SAS_GetHDDSpeed(){
    local l_pspeed="$1"
    local l_pspeed_tag=0
    for ((s=0;s<${#SASDeviceSpeed[*]};s++));do
        if [ x"${SASDeviceSpeed[${s}]}" != x"" ]; then
            if [ x"${SASDeviceSpeed[${s}]}" == x"${l_pspeed}" ]; then
                l_pspeed_tag=1
                break
            else
                l_pspeed_tag=0
                continue
            fi
        fi
    done
    if [ ${l_pspeed_tag} -eq 0 ]; then
        SASDeviceSpeed[${#SASDeviceSpeed[*]}]="${l_pspeed}"
    fi
    unset s l_pspeed l_pspeed_tag
}


function SAS_MegaCli_GetHDDRaidList(){
    local l_vdlevel="$1"
    local l_spandepth="$2"
    local l_vpdevnum="$3"
    case "${l_vdlevel}" in
        "Primary-0, Secondary-0, RAID Level Qualifier-0")
            l_vdlevel=RAID0
            ;;
        "Primary-1, Secondary-0, RAID Level Qualifier-0")
            [ "${l_spandepth}" -eq 1 ] && l_vdlevel=RAID1
            [ "${l_spandepth}" -gt 1 ] && l_vdlevel=RAID10
            ;;
        "Primary-5, Secondary-0, RAID Level Qualifier-3")
            l_vdlevel=RAID5
            ;;
        "Primary-6, Secondary-0, RAID Level Qualifier-3")
            l_vdlevel=RAID6
            ;;
        "Primary-1, Secondary-3, RAID Level Qualifier-0")
            l_vdlevel=RAID10
            ;;
        *)
            l_vdlevel=Unknown
            ;;
    esac
    local l_vpdevcount=$(( ${l_vpdevnum:-0} * ${l_spandepth:-0} ))
    SASRaidLevelList[${#SASRaidLevelList[*]}]="${l_vdlevel}(${l_vpdevcount} pcs)"
    unset l_vdlevel l_spandepth l_vpdevnum l_vpdevcount
}


function SATA_GetHDDCount(){
    local l_pcount="$1"
    SATADiskCount="$(( SATADiskCount + l_pcount ))"
    unset l_pcount
}


function SATA_GetHDDSize(){
    local l_psize="$1"
    local l_psize_tag=0
    for ((p=0;p<${#SATADiskSize[*]};p++));do
        if [ x"${SATADiskSize[${p}]}" != x"" ]; then
            if [ x"${SATADiskSize[${p}]}" == x"${l_psize}" ]; then
                l_psize_tag=1
                break
            else
                l_psize_tag=0
                continue
            fi
        fi
    done
    if [ ${l_psize_tag} -eq 0 ]; then
        SATADiskSize[${#SATADiskSize[*]}]="${l_psize}"
    fi
    unset p l_psize l_psize_tag
}


function SATA_GetHDDSpeed(){
    local l_pspeed="$1"
    local l_pspeed_tag=0
    for ((s=0;s<${#SATADeviceSpeed[*]};s++));do
        if [ x"${SATADeviceSpeed[${s}]}" != x"" ]; then
            if [ x"${SATADeviceSpeed[${s}]}" == x"${l_pspeed}" ]; then
                l_pspeed_tag=1
                break
            else
                l_pspeed_tag=0
                continue
            fi
        fi
    done
    if [ ${l_pspeed_tag} -eq 0 ]; then
        SATADeviceSpeed[${#SATADeviceSpeed[*]}]="${l_pspeed}"
    fi
    unset s l_pspeed l_pspeed_tag
}


function SATA_MegaCli_GetHDDRaidList(){
    local l_vdlevel="$1"
    local l_spandepth="$2"
    local l_vpdevnum="$3"
    case "${l_vdlevel}" in
        "Primary-0, Secondary-0, RAID Level Qualifier-0")
            l_vdlevel=RAID0
            ;;
        "Primary-1, Secondary-0, RAID Level Qualifier-0")
            [ "${l_spandepth}" -eq 1 ] && l_vdlevel=RAID1
            [ "${l_spandepth}" -gt 1 ] && l_vdlevel=RAID10
            ;;
        "Primary-5, Secondary-0, RAID Level Qualifier-3")
            l_vdlevel=RAID5
            ;;
        "Primary-6, Secondary-0, RAID Level Qualifier-3")
            l_vdlevel=RAID6
            ;;
        "Primary-1, Secondary-3, RAID Level Qualifier-0")
            l_vdlevel=RAID10
            ;;
        *)
            l_vdlevel=Unknown
            ;;
    esac
    local l_vpdevcount=$(( ${l_vpdevnum:-0} * ${l_spandepth:-0} ))
    SATARaidLevelList[${#SATARaidLevelList[*]}]="${l_vdlevel}(${l_vpdevcount} pcs)"
    unset l_vdlevel l_spandepth l_vpdevnum l_vpdevcount
}


function SSD_GetSSDCount(){
    local l_pcount="$1"
    SSDCount="$(( SSDCount + l_pcount ))"
    unset l_pcount
}


function SSD_GetSSDSize(){
    local l_psize="$1"
    local l_psize_tag=0
    for ((p=0;p<${#SSDSize[*]};p++));do
        if [ x"${SSDSize[${p}]}" != x"" ]; then
            if [ x"${SSDSize[${p}]}" == x"${l_psize}" ]; then
                l_psize_tag=1
                break
            else
                l_psize_tag=0
                continue
            fi
        fi
    done
    if [ ${l_psize_tag} -eq 0 ]; then
        SSDSize[${#SSDSize[*]}]="${l_psize}"
    fi
    unset p l_psize l_psize_tag
}


function SSD_GetSSDSpeed(){
    local l_pspeed="$1"
    local l_pspeed_tag=0
    for ((s=0;s<${#SSDDeviceSpeed[*]};s++));do
        if [ x"${SSDDeviceSpeed[${s}]}" != x"" ]; then
            if [ x"${SSDDeviceSpeed[${s}]}" == x"${l_pspeed}" ]; then
                l_pspeed_tag=1
                break
            else
                l_pspeed_tag=0
                continue
            fi
        fi
    done
    if [ ${l_pspeed_tag} -eq 0 ]; then
        SSDDeviceSpeed[${#SSDDeviceSpeed[*]}]="${l_pspeed}"
    fi
    unset s l_pspeed l_pspeed_tag
}


function SSD_MegaCli_GetSSDRaidList(){
    local l_vdlevel="$1"
    local l_spandepth="$2"
    local l_vpdevnum="$3"
    case "${l_vdlevel}" in
        "Primary-0, Secondary-0, RAID Level Qualifier-0")
            l_vdlevel=RAID0
            ;;
        "Primary-1, Secondary-0, RAID Level Qualifier-0")
            [ "${l_spandepth}" -eq 1 ] && l_vdlevel=RAID1
            [ "${l_spandepth}" -gt 1 ] && l_vdlevel=RAID10
            ;;
        "Primary-5, Secondary-0, RAID Level Qualifier-3")
            l_vdlevel=RAID5
            ;;
        "Primary-6, Secondary-0, RAID Level Qualifier-3")
            l_vdlevel=RAID6
            ;;
        "Primary-1, Secondary-3, RAID Level Qualifier-0")
            l_vdlevel=RAID10
            ;;
        *)
            l_vdlevel=Unknown
            ;;
    esac
    local l_vpdevcount=$(( ${l_vpdevnum:-0} * ${l_spandepth:-0} ))
    SSDRaidLevelList[${#SSDRaidLevelList[*]}]="${l_vdlevel}(${l_vpdevcount} pcs)"
    unset l_vdlevel l_spandepth l_vpdevnum l_vpdevcount
}


function PCIE_Nvme_GetSSDCount(){
    local l_pcount="$1"
    PCIECount="$(( PCIECount + l_pcount ))"
    unset l_pcount
}


function PCIE_Nvme_GetSSDSize(){
    local l_psize="$1"
    local l_psize_tag=0
    for ((p=0;p<${#PCIESize[*]};p++));do
        if [ x"${PCIESize[${p}]}" != x"" ]; then
            if [ x"${PCIESize[${p}]}" == x"${l_psize}" ]; then
                l_psize_tag=1
                break
            else
                l_psize_tag=0
                continue
            fi
        fi
    done
    if [ ${l_psize_tag} -eq 0 ]; then
        PCIESize[${#PCIESize[*]}]="${l_psize}"
    fi
    unset p l_psize l_psize_tag
}


function MegaCli_SAS_HDD(){
    local l_vrstart="$1"
    local l_vrend="$2"
    local l_prstart="$3"
    local l_prend="$4"
    if [ x"{l_vrstart}" != x"" ] && [ x"{l_vrend}" != x"" ] && [ x"{l_prstart}" != x"" ] && [ x"{l_prend}" != x"" ]; then
        SAS_GetHDDCount "$(${megacli_tool} -LdPdInfo -aALL -Nolog |sed -n "${l_vrstart},${l_vrend}p" |sed -n "${l_prstart},${l_prend}p" |egrep "^\<PD Type\>" |egrep "\<SAS\>" |wc -l)"
        
        local l_psize="$(${megacli_tool} -LdPdInfo -aALL -Nolog |sed -n "${l_vrstart},${l_vrend}p" |sed -n "${l_prstart},${l_prend}p" |egrep "^\<Raw Size\>" |sed -e "s/^Raw Size:[[:space:]]*//g" -e "s/[[:space:]]*\[.*$//g" -e 's/ //g')"
        if [ x"${l_psize}" != x"" ]; then
            SAS_GetHDDSize "${l_psize}"
        fi
        unset l_psize
        
        local l_pspeed="$(${megacli_tool} -LdPdInfo -aALL -Nolog |sed -n "${l_vrstart},${l_vrend}p" |sed -n "${l_prstart},${l_prend}p" |egrep "^\<Device Speed\>" |sed -e "s/^Device Speed:[[:space:]]*//g" -e "s/[[:space:]]*\[.*$//g" -e 's/ //g')"
        if [ x"${l_pspeed}" != x"" ]; then
            SAS_GetHDDSpeed "${l_pspeed}"
        fi
        unset l_pspeed
        
        if [ "${Global_Status_RLevel}" -eq 0 ]; then
            local l_vdlevel="$(${megacli_tool} -LdPdInfo -aALL -Nolog |sed -n "${l_vrstart},${l_vrend}p" |egrep "\<RAID Level\>" |sed -n 1p |sed "s/^RAID Level[[:space:]]*:[[:space:]]*//g")"
            local l_spandepth="$(${megacli_tool} -LdPdInfo -aALL -Nolog |sed -n "${l_vrstart},${l_vrend}p" |egrep "^\<Span Depth\>" |sed -n 1p |egrep -o "[[:digit:]]+")"
            local l_vpdevnum="$(${megacli_tool} -LdPdInfo -aALL -Nolog |sed -n "${l_vrstart},${l_vrend}p" |egrep "^\<Number Of Drives\>" |sed -n 1p |egrep -o "[[:digit:]]+")"
            if [ x"${l_vdlevel}" != x"" ] && [ x"${l_spandepth}" != x"" ] && [ x"${l_vpdevnum}" != x"" ]; then
                SAS_MegaCli_GetHDDRaidList "${l_vdlevel}" "${l_spandepth}" "${l_vpdevnum}"
            fi
            unset l_vdlevel l_spandepth l_vpdevnum
            Global_Status_RLevel=1
            
        fi
    else
        echo "Parameter non-compliance"
    fi
    unset l_vrstart l_vrend l_prstart l_prend
}


function MegaCli_SATA_HDD(){
    local l_vrstart="$1"
    local l_vrend="$2"
    local l_prstart="$3"
    local l_prend="$4"
    if [ x"{l_vrstart}" != x"" ] && [ x"{l_vrend}" != x"" ] && [ x"{l_prstart}" != x"" ] && [ x"{l_prend}" != x"" ]; then
        SATA_GetHDDCount "$(${megacli_tool} -LdPdInfo -aALL -Nolog |sed -n "${l_vrstart},${l_vrend}p" |sed -n "${l_prstart},${l_prend}p" |egrep "^\<PD Type\>" |egrep "\<SATA\>" |wc -l)"
        
        local l_psize="$(${megacli_tool} -LdPdInfo -aALL -Nolog |sed -n "${l_vrstart},${l_vrend}p" |sed -n "${l_prstart},${l_prend}p" |egrep "^\<Raw Size\>" |sed -e "s/^Raw Size:[[:space:]]*//g" -e "s/[[:space:]]*\[.*$//g" -e 's/ //g')"
        if [ x"${l_psize}" != x"" ]; then
            SATA_GetHDDSize "${l_psize}"
        fi
        unset l_psize
        
        local l_pspeed="$(${megacli_tool} -LdPdInfo -aALL -Nolog |sed -n "${l_vrstart},${l_vrend}p" |sed -n "${l_prstart},${l_prend}p" |egrep "^\<Device Speed\>" |sed -e "s/^Device Speed:[[:space:]]*//g" -e "s/[[:space:]]*\[.*$//g" -e 's/ //g')"
        if [ x"${l_pspeed}" != x"" ]; then
            SATA_GetHDDSpeed "${l_pspeed}"
        fi
        unset l_pspeed
        
        if [ "${Global_Status_RLevel}" -eq 0 ]; then
            local l_vdlevel="$(${megacli_tool} -LdPdInfo -aALL -Nolog |sed -n "${l_vrstart},${l_vrend}p" |egrep "\<RAID Level\>" |sed -n 1p |sed "s/^RAID Level[[:space:]]*:[[:space:]]*//g")"
            local l_spandepth="$(${megacli_tool} -LdPdInfo -aALL -Nolog |sed -n "${l_vrstart},${l_vrend}p" |egrep "^\<Span Depth\>" |sed -n 1p |egrep -o "[[:digit:]]+")"
            local l_vpdevnum="$(${megacli_tool} -LdPdInfo -aALL -Nolog |sed -n "${l_vrstart},${l_vrend}p" |egrep "^\<Number Of Drives\>" |sed -n 1p |egrep -o "[[:digit:]]+")"
            if [ x"${l_vdlevel}" != x"" ] && [ x"${l_spandepth}" != x"" ] && [ x"${l_vpdevnum}" != x"" ]; then
                SATA_MegaCli_GetHDDRaidList "${l_vdlevel}" "${l_spandepth}" "${l_vpdevnum}"
            fi
            unset l_vdlevel l_spandepth l_vpdevnum
            Global_Status_RLevel=1
        fi
    else
        echo "Parameter non-compliance"
    fi
    unset l_vrstart l_vrend l_prstart l_prend
}


function MegaCli_SAS_SSD(){
    local l_vrstart="$1"
    local l_vrend="$2"
    local l_prstart="$3"
    local l_prend="$4"
    if [ x"{l_vrstart}" != x"" ] && [ x"{l_vrend}" != x"" ] && [ x"{l_prstart}" != x"" ] && [ x"{l_prend}" != x"" ]; then
        SSD_GetSSDCount "$(${megacli_tool} -LdPdInfo -aALL -Nolog |sed -n "${l_vrstart},${l_vrend}p" |sed -n "${l_prstart},${l_prend}p" |egrep "^\<Media Type\>" |egrep "\<Solid State Device\>" |wc -l)"
        
        local l_psize="$(${megacli_tool} -LdPdInfo -aALL -Nolog |sed -n "${l_vrstart},${l_vrend}p" |sed -n "${l_prstart},${l_prend}p" |egrep "^\<Raw Size\>" |sed -e "s/^Raw Size:[[:space:]]*//g" -e "s/[[:space:]]*\[.*$//g" -e 's/ //g')"
        if [ x"${l_psize}" != x"" ]; then
            SSD_GetSSDSize "${l_psize}"
        fi
        unset l_psize
        
        local l_pspeed="$(${megacli_tool} -LdPdInfo -aALL -Nolog |sed -n "${l_vrstart},${l_vrend}p" |sed -n "${l_prstart},${l_prend}p" |egrep "^\<Device Speed\>" |sed -e "s/^Device Speed:[[:space:]]*//g" -e "s/[[:space:]]*\[.*$//g" -e 's/ //g')"
        if [ x"${l_pspeed}" != x"" ]; then
            SSD_GetSSDSpeed "${l_pspeed}"
        fi
        unset l_pspeed
        
        if [ "${Global_Status_RLevel}" -eq 0 ]; then
            local l_vdlevel="$(${megacli_tool} -LdPdInfo -aALL -Nolog |sed -n "${l_vrstart},${l_vrend}p" |egrep "\<RAID Level\>" |sed -n 1p |sed "s/^RAID Level[[:space:]]*:[[:space:]]*//g")"
            local l_spandepth="$(${megacli_tool} -LdPdInfo -aALL -Nolog |sed -n "${l_vrstart},${l_vrend}p" |egrep "^\<Span Depth\>" |sed -n 1p |egrep -o "[[:digit:]]+")"
            local l_vpdevnum="$(${megacli_tool} -LdPdInfo -aALL -Nolog |sed -n "${l_vrstart},${l_vrend}p" |egrep "^\<Number Of Drives\>" |sed -n 1p |egrep -o "[[:digit:]]+")"
            if [ x"${l_vdlevel}" != x"" ] && [ x"${l_spandepth}" != x"" ] && [ x"${l_vpdevnum}" != x"" ]; then
                SSD_MegaCli_GetSSDRaidList "${l_vdlevel}" "${l_spandepth}" "${l_vpdevnum}"
            fi
            unset l_vdlevel l_spandepth l_vpdevnum
            Global_Status_RLevel=1
        fi
    else
        echo "Parameter non-compliance"
    fi
    unset l_vrstart l_vrend l_prstart l_prend
}


function MegaCli_SATA_SSD(){
    local l_vrstart="$1"
    local l_vrend="$2"
    local l_prstart="$3"
    local l_prend="$4"
    if [ x"{l_vrstart}" != x"" ] && [ x"{l_vrend}" != x"" ] && [ x"{l_prstart}" != x"" ] && [ x"{l_prend}" != x"" ]; then
        MegaCli_SAS_SSD "${l_vrstart}" "${l_vrend}" "${l_prstart}" "${l_prend}"
    else
        echo "Parameter non-compliance"
    fi
    unset l_vrstart l_vrend l_prstart l_prend
}


function MegaCli_PDSwitch(){
    local l_vrstart="$1"
    local l_vrend="$2"
    local l_prstart="$3"
    local l_prend="$4"
    if [ x"{l_vrstart}" != x"" ] && [ x"{l_vrend}" != x"" ] && [ x"{l_prstart}" != x"" ] && [ x"{l_prend}" != x"" ]; then
        case "$(${megacli_tool} -LdPdInfo -aALL -Nolog |sed -n "${l_vrstart},${l_vrend}p" |sed -n "${l_prstart},${l_prend}p" |egrep "^\<PD Type\>" |sed -e "s/^PD Type:[[:space:]]*//g" |sort |uniq)" in
            SAS)
                case "$(${megacli_tool} -LdPdInfo -aALL -Nolog |sed -n "${l_vrstart},${l_vrend}p" |sed -n "${l_prstart},${l_prend}p" |egrep "^\<Media Type\>" |sed -e "s/^Media Type:[[:space:]]*//g" |sort |uniq)" in
                    "Hard Disk Device")
                        MegaCli_SAS_HDD "${l_vrstart}" "${l_vrend}" "${l_prstart}" "${l_prend}"
                        ;;
                    "Solid State Device")
                        MegaCli_SAS_SSD "${l_vrstart}" "${l_vrend}" "${l_prstart}" "${l_prend}"
                        ;;
                    *)
                        echo "Unknown media type"
                        ;;
                esac
                ;;
            SATA)
                case "$(${megacli_tool} -LdPdInfo -aALL -Nolog |sed -n "${l_vrstart},${l_vrend}p" |sed -n "${l_prstart},${l_prend}p" |egrep "^\<Media Type\>" |sed -e "s/^Media Type:[[:space:]]*//g" |sort |uniq)" in
                    "Hard Disk Device")
                        MegaCli_SATA_HDD "${l_vrstart}" "${l_vrend}" "${l_prstart}" "${l_prend}"
                        ;;
                    "Solid State Device")
                        MegaCli_SATA_SSD "${l_vrstart}" "${l_vrend}" "${l_prstart}" "${l_prend}"
                        ;;
                    *)
                        echo "Unknown media type"
                        ;;
                esac
                ;;
            *)
                echo "Unknown PD type"
                ;;
        esac
    else
        echo "Parameter non-compliance"
    fi
    unset l_vrstart l_vrend l_prstart l_prend
}


function MegaCli_VDSwitch(){
    local l_vrstart="$1"
    local l_vrend="$2"
    if [ x"{l_vrstart}" != x"" ] && [ x"{l_vrend}" != x"" ]; then
        declare -a l_pdlines
        for plinenum in $(${megacli_tool} -LdPdInfo -aALL -Nolog |sed -n "${l_vrstart},${l_vrend}p" |sed -n '/^PD:[[:space:]]\+[[:digit:]]\+/=');do
            l_pdlines[${#l_pdlines[*]}]="${plinenum}"
        done
        for ((x=0;x<${#l_pdlines[*]};x++));do
            local l_prstart="${l_pdlines[${x}]}"
            local l_prend="${l_pdlines[$(( ${x} + 1 ))]}"
            if [ "${x}" -lt "$(( ${#l_pdlines[*]} - 1 ))" ]; then
                MegaCli_PDSwitch "${l_vrstart}" "${l_vrend}" "${l_prstart}" "${l_prend}"
            elif [ "${x}" -eq "$(( ${#l_pdlines[*]} - 1 ))" ]; then
                [ x"${l_prend}" == x"" ] && l_prend='$'
                MegaCli_PDSwitch "${l_vrstart}" "${l_vrend}" "${l_prstart}" "${l_prend}"
            fi
        done
        unset x plinenum l_pdlines l_prstart l_prend
    else
        echo "Parameter non-compliance"
    fi
    unset l_vrstart l_vrend
}


function MegaCli_PDJBOD(){
    for esid in $(${megacli_tool} -PDList -aALL -Nolog |egrep -i "^\<(Enclosure Device ID|Slot Number)\>[[:space:]]*:" |sed -e "N;s/\nSlot Number[[:space:]]*:[[:space:]]*\(.*\)/:\1/g" -e "s/Enclosure Device ID[[:space:]]*:[[:space:]]*//g");do
        if [ x"$(${megacli_tool} -PDInfo -PhysDrv[${esid}] -aALL -Nolog |egrep -i "^\<Firmware state\>[[:space:]]*:" |sed "s/^\<Firmware state\>[[:space:]]*:[[:space:]]*//g")" == x"JBOD" ]; then
            case "$(${megacli_tool} -PDInfo -PhysDrv[${esid}] -aALL -Nolog |egrep "^\<PD Type\>" |sed -e "s/^PD Type:[[:space:]]*//g")" in
                SAS)
                    case "$(${megacli_tool} -PDInfo -PhysDrv[${esid}] -aALL -Nolog |egrep "^\<Media Type\>" |sed -e "s/^Media Type:[[:space:]]*//g")" in
                        "Hard Disk Device")
                            SAS_GetHDDCount "1"
                            
                            local l_psize="$(${megacli_tool} -PDInfo -PhysDrv[${esid}] -aALL -Nolog |egrep "^\<Raw Size\>" |sed -e "s/^Raw Size:[[:space:]]*//g" -e "s/[[:space:]]*\[.*$//g" -e 's/ //g')"
                            if [ x"${l_psize}" != x"" ]; then
                                SAS_GetHDDSize "${l_psize}"
                            fi
                            
                            local l_pspeed="$(${megacli_tool} -PDInfo -PhysDrv[${esid}] -aALL -Nolog |egrep "^\<Device Speed\>" |sed -e "s/^Device Speed:[[:space:]]*//g" -e "s/[[:space:]]*\[.*$//g" -e 's/ //g')"
                            if [ x"${l_pspeed}" != x"" ]; then
                                SAS_GetHDDSpeed "${l_pspeed}"
                            fi
                            unset l_psize l_pspeed
                            ;;
                        "Solid State Device")
                            SSD_GetSSDCount "1"
                            
                            local l_psize="$(${megacli_tool} -PDInfo -PhysDrv[${esid}] -aALL -Nolog |egrep "^\<Raw Size\>" |sed -e "s/^Raw Size:[[:space:]]*//g" -e "s/[[:space:]]*\[.*$//g" -e 's/ //g')"
                            if [ x"${l_psize}" != x"" ]; then
                                SSD_GetSSDSize "${l_psize}"
                            fi
                            unset l_psize
                            
                            local l_pspeed="$(${megacli_tool} -PDInfo -PhysDrv[${esid}] -aALL -Nolog |egrep "^\<Device Speed\>" |sed -e "s/^Device Speed:[[:space:]]*//g" -e "s/[[:space:]]*\[.*$//g" -e 's/ //g')"
                            if [ x"${l_pspeed}" != x"" ]; then
                                SSD_GetSSDSpeed "${l_pspeed}"
                            fi
                            unset l_pspeed
                            ;;
                        *)
                            echo "Unknown media type"
                            ;;
                    esac
                    ;;
                SATA)
                    case "$(${megacli_tool} -PDInfo -PhysDrv[${esid}] -aALL -Nolog |egrep "^\<Media Type\>" |sed -e "s/^Media Type:[[:space:]]*//g")" in
                        "Hard Disk Device")
                            SATA_GetHDDCount "1"
                            
                            local l_psize="$(${megacli_tool} -PDInfo -PhysDrv[${esid}] -aALL -Nolog |egrep "^\<Raw Size\>" |sed -e "s/^Raw Size:[[:space:]]*//g" -e "s/[[:space:]]*\[.*$//g" -e 's/ //g')"
                            if [ x"${l_psize}" != x"" ]; then
                                SATA_GetHDDSize "${l_psize}"
                            fi
                            
                            local l_pspeed="$(${megacli_tool} -PDInfo -PhysDrv[${esid}] -aALL -Nolog |egrep "^\<Device Speed\>" |sed -e "s/^Device Speed:[[:space:]]*//g" -e "s/[[:space:]]*\[.*$//g" -e 's/ //g')"
                            if [ x"${l_pspeed}" != x"" ]; then
                                SATA_GetHDDSpeed "${l_pspeed}"
                            fi
                            unset l_psize l_pspeed
                            ;;
                        "Solid State Device")
                            SSD_GetSSDCount "1"
                            
                            local l_psize="$(${megacli_tool} -PDInfo -PhysDrv[${esid}] -aALL -Nolog |egrep "^\<Raw Size\>" |sed -e "s/^Raw Size:[[:space:]]*//g" -e "s/[[:space:]]*\[.*$//g" -e 's/ //g')"
                            if [ x"${l_psize}" != x"" ]; then
                                SSD_GetSSDSize "${l_psize}"
                            fi
                            unset l_psize
                            
                            local l_pspeed="$(${megacli_tool} -PDInfo -PhysDrv[${esid}] -aALL -Nolog |egrep "^\<Device Speed\>" |sed -e "s/^Device Speed:[[:space:]]*//g" -e "s/[[:space:]]*\[.*$//g" -e 's/ //g')"
                            if [ x"${l_pspeed}" != x"" ]; then
                                SSD_GetSSDSpeed "${l_pspeed}"
                            fi
                            unset l_pspeed
                            ;;
                        *)
                            echo "Unknown media type"
                            ;;
                    esac
                    ;;
                *)
                    echo "Unknown PD type"
                    ;;
            esac
        fi
    done
    unset esid
}


function MegaCliGetInfo(){
    if [ -f "${megacli_tool}" ]; then
        declare -a l_vdlines
        for vlinenum in $(${megacli_tool} -LdPdInfo -aALL -Nolog |sed -n '/^Virtual Drive:[[:space:]]*[[:digit:]]\+/=');do
            l_vdlines[${#l_vdlines[*]}]="${vlinenum}"
        done
        for ((i=0;i<${#l_vdlines[*]};i++));do
            local l_vrstart="${l_vdlines[${i}]}"
            local l_vrend="${l_vdlines[$(( ${i} + 1 ))]}"
            Global_Status_RLevel=0
            if [ "${i}" -lt "$(( ${#l_vdlines[*]} - 1 ))" ]; then
                MegaCli_VDSwitch "${l_vrstart}" "${l_vrend}"
            elif [ "${i}" -eq "$(( ${#l_vdlines[*]} - 1 ))" ]; then
                [ x"${l_vrend}" == x"" ] && l_vrend='$'
                MegaCli_VDSwitch "${l_vrstart}" "${l_vrend}"
            fi
        done
        unset i vlinenum l_vdlines l_vrstart l_vrend
        if [ $(${megacli_tool} -PDList -aALL -Nolog |egrep -i "^\<Firmware state\>[[:space:]]*:" |egrep "JBOD" |wc -l) -gt 0 ]; then
            MegaCli_PDJBOD
        fi
    else
        echo "${megacli_tool} not found"
    fi
}


function Ssacli_SAS_HDD(){
    local l_slotid="$1"
    local l_arrayid="$2"
    if [ x"{l_slotid}" != x"" ] && [ x"{l_arrayid}" != x"" ]; then
        SAS_GetHDDCount "$(${ssacli_tool} ctrl slot="${l_slotid}" array "${l_arrayid}" pd all show |egrep "\<physicaldrive\>" |wc -l)"
        
        for l_pdid in $(${ssacli_tool} ctrl slot="${l_slotid}" array "${l_arrayid}" pd all show |egrep "\<physicaldrive\>" |awk '{print $2}');do
            if [ x"${l_pdid}" != x"" ]; then
                local l_psize="$(${ssacli_tool} ctrl slot="${l_slotid}" array "${l_arrayid}" pd "${l_pdid}" show |egrep "^[[:space:]]+\<Size\>:[[:space:]]+" |sed -e 's/^[[:space:]]\+\<Size\>:[[:space:]]\+//g' -e 's/ //g')"
                if [ x"${l_psize}" != x"" ]; then
                    SAS_GetHDDSize "${l_psize}"
                fi
                unset l_psize
                
                local l_pspeed="$(${ssacli_tool} ctrl slot="${l_slotid}" array "${l_arrayid}" pd "${l_pdid}" show |egrep "^[[:space:]]+\<PHY Transfer Rate\>:[[:space:]]+" |sed -e 's/^[[:space:]]\+\<PHY Transfer Rate\>:[[:space:]]\+//g' -e 's/,.*$//g')"
                if [ x"${l_pspeed}" != x"" ]; then
                    SAS_GetHDDSpeed "${l_pspeed}"
                fi
                unset l_pspeed
            fi
        done
        unset l_pdid
        
        for l_ldid in $(${ssacli_tool} ctrl slot="${l_slotid}" array "${l_arrayid}" ld all show |egrep "\<logicaldrive\>[[:space:]]+[[:digit:]]+" |awk '{print $2}');do
            if [ x"${l_ldid}" != x"" ]; then
                local l_ldlevel="$(${ssacli_tool} ctrl slot="${l_slotid}" array "${l_arrayid}" ld "${l_ldid}" show status |egrep "\<logicaldrive\>" |awk -F ' |,|)' '{print $9 $10}')"
                local l_pdcount="$(${ssacli_tool} ctrl slot="${l_slotid}" array "${l_arrayid}" pd all show |egrep "\<physicaldrive\>" |wc -l)"
                SASRaidLevelList[${#SASRaidLevelList[*]}]="${l_ldlevel}(${l_pdcount} pcs)"
            fi
        done
        unset l_ldid l_ldlevel l_pdcount
    else
        echo "Parameter non-compliance"
    fi
    unset l_slotid l_arrayid
}


function Ssacli_SATA_HDD(){
    local l_slotid="$1"
    local l_arrayid="$2"
    if [ x"{l_slotid}" != x"" ] && [ x"{l_arrayid}" != x"" ]; then
        SATA_GetHDDCount "$(${ssacli_tool} ctrl slot="${l_slotid}" array "${l_arrayid}" pd all show |egrep "\<physicaldrive\>" |wc -l)"
        
        for l_pdid in $(${ssacli_tool} ctrl slot="${l_slotid}" array "${l_arrayid}" pd all show |egrep "\<physicaldrive\>" |awk '{print $2}');do
            if [ x"${l_pdid}" != x"" ]; then
                local l_psize="$(${ssacli_tool} ctrl slot="${l_slotid}" array "${l_arrayid}" pd "${l_pdid}" show |egrep "^[[:space:]]+\<Size\>:[[:space:]]+" |sed -e 's/^[[:space:]]\+\<Size\>:[[:space:]]\+//g' -e 's/ //g')"
                if [ x"${l_psize}" != x"" ]; then
                    SATA_GetHDDSize "${l_psize}"
                fi
                unset l_psize
                
                local l_pspeed="$(${ssacli_tool} ctrl slot="${l_slotid}" array "${l_arrayid}" pd "${l_pdid}" show |egrep "^[[:space:]]+\<PHY Transfer Rate\>:[[:space:]]+" |sed -e 's/^[[:space:]]\+\<PHY Transfer Rate\>:[[:space:]]\+//g' -e 's/,.*$//g')"
                 if [ x"${l_pspeed}" != x"" ]; then
                    SATA_GetHDDSpeed "${l_pspeed}"
                fi
                unset l_pspeed
            fi
        done
        unset l_pdid
        
        for l_ldid in $(${ssacli_tool} ctrl slot="${l_slotid}" array "${l_arrayid}" ld all show |egrep "\<logicaldrive\>[[:space:]]+[[:digit:]]+" |awk '{print $2}');do
            if [ x"${l_ldid}" != x"" ]; then
                local l_ldlevel="$(${ssacli_tool} ctrl slot="${l_slotid}" array "${l_arrayid}" ld "${l_ldid}" show status |egrep "\<logicaldrive\>" |awk -F ' |,|)' '{print $9 $10}')"
                local l_pdcount="$(${ssacli_tool} ctrl slot="${l_slotid}" array "${l_arrayid}" pd all show |egrep "\<physicaldrive\>" |wc -l)"
                SATARaidLevelList[${#SATARaidLevelList[*]}]="${l_ldlevel}(${l_pdcount} pcs)"
            fi
        done
        unset l_ldid l_ldlevel l_pdcount
    else
        echo "Parameter non-compliance"
    fi
    unset l_slotid l_arrayid
}


function Ssacli_SATA_SSD(){
    local l_slotid="$1"
    local l_arrayid="$2"
    if [ x"{l_slotid}" != x"" ] && [ x"{l_arrayid}" != x"" ]; then
        SSD_GetSSDCount "$(${ssacli_tool} ctrl slot="${l_slotid}" array "${l_arrayid}" pd all show |egrep "\<physicaldrive\>" |wc -l)"
        
        for l_pdid in $(${ssacli_tool} ctrl slot="${l_slotid}" array "${l_arrayid}" pd all show |egrep "\<physicaldrive\>" |awk '{print $2}');do
            if [ x"${l_pdid}" != x"" ]; then
                local l_psize="$(${ssacli_tool} ctrl slot="${l_slotid}" array "${l_arrayid}" pd "${l_pdid}" show |egrep "^[[:space:]]+\<Size\>:[[:space:]]+" |sed -e 's/^[[:space:]]\+\<Size\>:[[:space:]]\+//g' -e 's/ //g')"
                if [ x"${l_psize}" != x"" ]; then
                    SSD_GetSSDSize "${l_psize}"
                fi
                unset l_psize
                
                local l_pspeed="$(${ssacli_tool} ctrl slot="${l_slotid}" array "${l_arrayid}" pd "${l_pdid}" show |egrep "^[[:space:]]+\<PHY Transfer Rate\>:[[:space:]]+" |sed -e 's/^[[:space:]]\+\<PHY Transfer Rate\>:[[:space:]]\+//g' -e 's/,.*$//g')"
                 if [ x"${l_pspeed}" != x"" ]; then
                    SSD_GetSSDSpeed "${l_pspeed}"
                fi
                unset l_pspeed
            fi
        done
        unset l_pdid
        
        for l_ldid in $(${ssacli_tool} ctrl slot="${l_slotid}" array "${l_arrayid}" ld all show |egrep "\<logicaldrive\>[[:space:]]+[[:digit:]]+" |awk '{print $2}');do
            if [ x"${l_ldid}" != x"" ]; then
                local l_ldlevel="$(${ssacli_tool} ctrl slot="${l_slotid}" array "${l_arrayid}" ld "${l_ldid}" show status |egrep "\<logicaldrive\>" |awk -F ' |,|)' '{print $9 $10}')"
                local l_pdcount="$(${ssacli_tool} ctrl slot="${l_slotid}" array "${l_arrayid}" pd all show |egrep "\<physicaldrive\>" |wc -l)"
                SSDRaidLevelList[${#SSDRaidLevelList[*]}]="${l_ldlevel}(${l_pdcount} pcs)"
            fi
        done
        unset l_ldid l_ldlevel l_pdcount
    else
        echo "Parameter non-compliance"
    fi
    unset l_slotid l_arrayid
}


function SsacliGetInfo(){
    if [ -f "${ssacli_tool}" ]; then
        for slotid in $(${ssacli_tool} ctrl all show |egrep -o "\<Slot\>[[:space:]]+[[:digit:]]+" |egrep -o "[[:digit:]]+");do
            for arrayid in $(${ssacli_tool} ctrl slot=${slotid} array all show |egrep "^[[:space:]]+\<Array\>" |awk '{print $2}');do
                case "$(${ssacli_tool} ctrl slot=${slotid} array ${arrayid} show |egrep "^[[:space:]]+\<Interface Type\>:[[:space:]]+" |sed 's/^[[:space:]]\+\<Interface Type\>:[[:space:]]\+//g')" in
                    SAS)
                        Ssacli_SAS_HDD "${slotid}" "${arrayid}"
                        ;;
                    SATA)
                        Ssacli_SATA_HDD "${slotid}" "${arrayid}"
                        ;;
                    "Solid State SATA")
                        Ssacli_SATA_SSD "${slotid}" "${arrayid}"
                        ;;
                    *)
                        echo "Unknown array interface type"
                        ;;
                esac
            done
            unset arrayid
        done
        unset slotid
    else
        echo "${ssacli_tool} not found"
    fi
}


function NvmeSSDGetInfo(){
    local lsblk="$(which lsblk 2>/dev/null)"
    if [ x"${lsblk}" != x"" ] && [ -x "${lsblk}" ]; then
        PCIE_Nvme_GetSSDCount "$(${lsblk} |egrep "^nvme" |wc -l)"
        if [ $(${lsblk} |egrep "^nvme" |wc -l) -gt 0 ]; then
            for l_psize in $(${lsblk} |egrep "^nvme" |awk '{print $4}');do
                if [ x"${l_psize}" != x"" ]; then
                    PCIE_Nvme_GetSSDSize "${l_psize}"
                fi
            done
            unset l_psize
        fi
    else
        echo "lsblk not found"
    fi
}


function PrintAllInfo(){
    printf "%-20s: %-16s\n" "Host IP" "${ipaddr}"
    printf "%-20s: %-16s\n" "SAS Disk total" "${SASDiskCount:-0}"
    printf "%-20s: %-16s\n" "SAS Disk Size" "${SASDiskSize[*]:-0}"
    printf "%-20s: %-16s\n" "SAS Device Speed" "${SASDeviceSpeed[*]:-0}"
    printf "%-20s: %-16s\n" "SAS RAID Level" "${SASRaidLevelList[*]:-0}"
    printf "%-20s: %-16s\n" "SATA Disk total" "${SATADiskCount:-0}"
    printf "%-20s: %-16s\n" "SATA Disk Size" "${SATADiskSize[*]:-0}"
    printf "%-20s: %-16s\n" "SATA Device Speed" "${SATADeviceSpeed[*]:-0}"
    printf "%-20s: %-16s\n" "SATA RAID Level" "${SATARaidLevelList[*]:-0}"
    printf "%-20s: %-16s\n" "SSD Disk total" "${SSDCount:-0}"
    printf "%-20s: %-16s\n" "SSD Disk Size" "${SSDSize[*]:-0}"
    printf "%-20s: %-16s\n" "SSD Device Speed" "${SSDDeviceSpeed[*]:-0}"
    printf "%-20s: %-16s\n" "SSD RAID Level" "${SSDRaidLevelList[*]:-0}"
    printf "%-20s: %-16s\n" "PCIE Disk total" "${PCIECount:-0}"
    printf "%-20s: %-16s\n" "PCIE Disk Size" "${PCIESize[*]:-0}"
}


function main(){
    if [ -r /sys/class/dmi/id/board_vendor ]; then
        manufacturer="$(cat /sys/class/dmi/id/board_vendor |awk '{print $1}')"
    elif [ -r /sys/class/dmi/id/chassis_vendor ]; then
        manufacturer="$(cat /sys/class/dmi/id/chassis_vendor |awk '{print $1}')"
    elif [ -r /sys/class/dmi/id/bios_vendor ]; then
        manufacturer="$(cat /sys/class/dmi/id/bios_vendor |awk '{print $1}')"
    else
        manufacturer=""
    fi
    if [ -n "${manufacturer}" ] && [ x"${manufacturer}" != x"" ]; then
        GetIPAddr
        case "${manufacturer}" in
            HP|hp|H3C|h3c)
                SsacliGetInfo
                ;;
            *)
                MegaCliGetInfo
                ;;
        esac
        NvmeSSDGetInfo
        PrintAllInfo
    else
        echo "Unknown Vendor"
    fi
}

main
