#!/bin/sh

# Get the latest version of the mirroring scripts
git clone https://github.com/cperciva/efs-fup/ /root/efs-fup.new

# Copy everything over the existing scripts
mv /root/efs-fup.new/*.sh /root/efs-fup.new/excludes /root/efs-fup.new/aws-ips /root/efs-fup

# Delete the directory we checked out
rm -rf /root/efs-fup.new
