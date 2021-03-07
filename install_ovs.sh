#!/bin/bash

#download src code of openvswitch

rpm2cpio openvswitch-2.11.0-4.el7.src.rpm | cpio -ivd 
#if modify is need ,modify openvswitch.spec

yum install rpmdevtools
rpmdev-setuptree

cd rpmbuild/SOURCES
#could download from web or rebuild a tar.gz file to put into the rpmbuild/SOURCES
wget http://openvswitch.org/releases/openvswitch-2.12.0.tar.gz
#move src code of .tar to rpm build dir
rpmbuild -bb openvswitch.spec

#In the rpmbuild/RPMS find the made rpm package

#cp the file out to install
rpm -ivh openvswitch-2.12.0-1.x86_64.rpm
