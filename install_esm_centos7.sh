#!/bin/bash
# Install Hyper-V Enhanced Session Mode on CentOS7
# Run this script on the guest-os in a home folder of a wheel user
# The machine needs to be at least Gen2 in HyperV
# Make sure the machine is up to date before running the script
# After the script have finished if you named the machine "CentOS7-GUI";
# run in Powershell on Host: Set-VM -VMName "CentOS7-GUI" -EnhancedSessionTransportType HvSocket

# Ensure having root privileges
if [ "$EUID" -e 0 ]
then echo "Please run as root"
	exit
fi

# Load the Hyper-V kernel module
echo "hv_sock" | tee -a /etc/modules-load.d/hv_sock.conf > /dev/null

# Configure SELinux
# ATTENTION: This makes your system much more insecure!
setenforce Permissive
sed -i 's/SELINUX=enforcing/SELINUX=permissive/g' /etc/selinux/config

# Recompile XRDP with Hyper-V enabled
yum install -y epel-release rpm-build rpmdevtools yum-utils
yum groupinstall -y "Development tools" "Server Platform Development" "Additional Development" "Compatibility libraries"
rpmdev-setuptree
yumdownloader --source xrdp
rpm -ivh xrdp*.src.rpm
yum-builddep -y xrdp
sed -i '/^%configure/ s/$/ --enable-vsock/' ~/rpmbuild/SPECS/xrdp.spec
rpmbuild -bb ~/rpmbuild/SPECS/xrdp.spec

# Install XRDP with Hyper-V enabled
rm -f ~/rpmbuild/RPMS/x86_64/xrdp-d*
rm -f ~/rpmbuild/RPMS/x86_64/xrdp-s*
yum install -y ~/rpmbuild/RPMS/x86_64/xrdp*.x86_64.rpm
systemctl enable xrdp
systemctl start xrdp

# Configure xrdp
sed -i "/^use_vsock=.*/c\use_vsock=true" /etc/xrdp/xrdp.ini
sed -i "/^security_layer=.*/c\security_layer=rdp" /etc/xrdp/xrdp.ini
sed -i "/^crypt_level=.*/c\crypt_level=none" /etc/xrdp/xrdp.ini
sed -i "/^bitmap_compression=.*/c\bitmap_compression=false" /etc/xrdp/xrdp.ini
sed -i "/^max_bpp=.*/c\max_bpp=24" /etc/xrdp/xrdp.ini

sed -i "/^X11DisplayOffset=.*/c\X11DisplayOffset=0" /etc/xrdp/sesman.ini
echo "allowed_users=anybody" | tee -a /etc/X11/Xwrapper.conf > /dev/null

# Prevent yum from reinstalling or upgrading xrdp to a version without Hyper-V support
echo "exclude=xrdp" | tee -a /etc/yum.conf > /dev/null

# After above finished run in Powershell on Host: Set-VM -VMName "CentOS7-GUI" -EnhancedSessionTransportType HvSocket
