#!/usr/bin/env python
import os
import re
import json
def Devices(diskdir, skippable):
    raw_devices = (device for device in os.listdir(diskdir) if not any(ignore in device for ignore in skippable))
    devices = (device for device in raw_devices if re.match(r'^\w{3}$', device))
    data = [{"{#DEVICENAME}": device} for device in devices]
    print(json.dumps({"data": data}, indent=4))
if __name__ == "__main__":
    # Iterate over all block devices, but ignore them if they are in the skippable set
    diskdir = "/sys/class/block"
    skippable = ("sr", "loop", "ram", "dm")
    Devices(diskdir, skippable)
