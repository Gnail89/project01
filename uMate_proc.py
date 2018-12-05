#!/usr/bin/env python
# -*- coding: utf-8 -*-

import os
import sys
from xml.etree import cElementTree as ET

os.chdir(sys.path[0])
script_name = sys.argv[0]
# xml_file_path = sys.argv[1]
log_file_name = 'log.txt'
xml_file_name = 'output.xml'

if os.path.exists(xml_file_name):
    tree = ET.parse(xml_file_name)
    root = tree.getroot()
    for server in root.findall("server"):
        Result = server.find("Result").text
        if Result == 'Unknown':
            IPAddress = server.find("IPAddress").text
            ProductName = server.find("ProductName").text
            SerialNumber = server.find("SerialNumber").text
            ErrorMessage = server.find("ErrorMessage").text
            output_msg = ('%-15s  %-18s  %-23s  %-8s  %s' % (
                IPAddress, ProductName, SerialNumber, Result, ErrorMessage))
            print(IPAddress, ProductName, SerialNumber, Result, ErrorMessage)
            if os.path.exists(log_file_name):
                with open(log_file_name, 'a+') as f:
                    f.write(output_msg + '\n')
                    f.close()
            else:
                print(log_file_name + ' not found.')
else:
    print(xml_file_name + ' not found.')
