#!/bin/bash

GetNetInfo(){
  local DEFAULTNET=""
  local IPSUB=""
  local NETSUB=""
  DEFAULTNET="$(ip route show |grep -o 'default via [0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}.*' |head -n1 |sed 's/proto.*\|onlink.*//g' |awk '{print $NF}')"
  IPSUB="$(ip addr |grep ''${DEFAULTNET}'' |grep 'global' |grep 'brd' |head -n1 |grep -o '[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}/[0-9]\{1,2\}')"
  NETSUB="$(echo -n "$IPSUB" |grep -o '/[0-9]\{1,2\}')"
  IPv4="$(echo -n "$IPSUB" |cut -d'/' -f1)"
  GATE="$(ip route show |grep -o 'default via [0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}' |head -n1 |grep -o '[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}')"
  MASK="$(echo -n '128.0.0.0/1,192.0.0.0/2,224.0.0.0/3,240.0.0.0/4,248.0.0.0/5,252.0.0.0/6,254.0.0.0/7,255.0.0.0/8,255.128.0.0/9,255.192.0.0/10,255.224.0.0/11,255.240.0.0/12,255.248.0.0/13,255.252.0.0/14,255.254.0.0/15,255.255.0.0/16,255.255.128.0/17,255.255.192.0/18,255.255.224.0/19,255.255.240.0/20,255.255.248.0/21,255.255.252.0/22,255.255.254.0/23,255.255.255.0/24,255.255.255.128/25,255.255.255.192/26,255.255.255.224/27,255.255.255.240/28,255.255.255.248/29,255.255.255.252/30,255.255.255.254/31,255.255.255.255/32' |grep -o '[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}'${NETSUB}'' |cut -d'/' -f1)"
  [[ -n "$GATE" ]] && [[ -n "$MASK" ]] && [[ -n "$IPv4" ]] || {
    ipNum(){
      local IFS='.'
      read ip1 ip2 ip3 ip4 <<<"$1"
      echo $((ip1*(1<<24)+ip2*(1<<16)+ip3*(1<<8)+ip4))
    }
    SelectMax(){
      local ii=0
      for IPITEM in `route -n |awk -v OUT=$1 '{print $OUT}' |grep '[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}'`
      do
        local NumTMP="$(ipNum $IPITEM)"
        eval "arrayNum[$ii]='$NumTMP,$IPITEM'"
        ii=$[$ii+1]
      done
      echo ${arrayNum[@]} |sed 's/\s/\n/g' |sort -n -k 1 -t ',' |tail -n1 |cut -d',' -f2
    }
    IPv4="$(ifconfig |grep 'Bcast' |head -n1 |grep -o '[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}' |head -n1)"
    GATE="$(SelectMax 2)"
    MASK="$(SelectMax 3)"
  }
  [[ -n "$GATE" ]] && [[ -n "$MASK" ]] && [[ -n "$IPv4" ]] || {
    echo "Error:Not configure network." && exit 1
  }
}

GetNetType(){
  local ICFGN=""
  local NetCFG=""
  [[ -f /etc/network/interfaces ]] && {
    [[ -z "$(sed -n '/iface.*inet static/p' /etc/network/interfaces)" ]] && AutoNet='1' || AutoNet='0'
    [[ -d /etc/network/interfaces.d ]] && {
      ICFGN="$(find /etc/network/interfaces.d -name '*.cfg' |wc -l)" || ICFGN='0'
      [[ "$ICFGN" -ne '0' ]] && {
        for NetCFG in `ls -1 /etc/network/interfaces.d/*.cfg`
        do
          [[ -z "$(cat $NetCFG | sed -n '/iface.*inet static/p')" ]] && AutoNet='1' || AutoNet='0'
          [[ "$AutoNet" -eq '0' ]] && break
        done
      }
    }
  }
  [[ -d /etc/sysconfig/network-scripts ]] && {
    ICFGN="$(find /etc/sysconfig/network-scripts -name 'ifcfg-*' |grep -v 'lo'|wc -l)" || ICFGN='0'
    [[ "$ICFGN" -ne '0' ]] && {
      for NetCFG in `ls -1 /etc/sysconfig/network-scripts/ifcfg-* |grep -v 'lo$' |grep -v ':[0-9]\{1,\}'`
      do
        [[ -n "$(cat $NetCFG | sed -n '/BOOTPROTO.*[dD][hH][cC][pP]/p')" ]] && AutoNet='1' || {
          AutoNet='0' && . $NetCFG
          [[ -n $NETMASK ]] && MASK="$NETMASK"
          [[ -n $GATEWAY ]] && GATE="$GATEWAY"
        }
        [[ "$AutoNet" -eq '0' ]] && break
      done
    }
  }
  [[ -z $AutoNet ]] && echo "Error:Not found interfaces config." && exit 1
}

AddBootMenu(){
  local CFG0=""
  local CFG1=""
  local CFG2=""
  [[ ! -f $GRUBDIR/$GRUBFILE.old ]] && [[ -f $GRUBDIR/$GRUBFILE.bak ]] && mv -f $GRUBDIR/$GRUBFILE.bak $GRUBDIR/$GRUBFILE.old
  mv -f $GRUBDIR/$GRUBFILE $GRUBDIR/$GRUBFILE.bak
  [[ -f $GRUBDIR/$GRUBFILE.old ]] && cat $GRUBDIR/$GRUBFILE.old >$GRUBDIR/$GRUBFILE || cat $GRUBDIR/$GRUBFILE.bak >$GRUBDIR/$GRUBFILE
  [[ "$GRUBOLD" == '0' ]] && {
    CFG0="$(awk '/menuentry /{print NR}' $GRUBDIR/$GRUBFILE|head -n 1)"
    CFG2="$(awk '/menuentry /{print NR}' $GRUBDIR/$GRUBFILE|head -n 2 |tail -n 1)"
    for CFGtmp in `awk '/}/{print NR}' $GRUBDIR/$GRUBFILE`
    do
      [ $CFGtmp -gt "$CFG0" -a $CFGtmp -lt "$CFG2" ] && CFG1="$CFGtmp";
    done
    [[ -z "$CFG1" ]] && echo "Error! read $GRUBFILE. " && exit 1
    sed -n "$CFG0,$CFG1"p $GRUBDIR/$GRUBFILE >/tmp/grub.new
    [[ -f /tmp/grub.new ]] && [[ "$(grep -c '{' /tmp/grub.new)" -eq "$(grep -c '}' /tmp/grub.new)" ]] || {
      echo "Error! Not configure $GRUBFILE." && exit 1
    }
    sed -i "/menuentry.*/c\menuentry\ \"Install OS\"\ --class debian\ --class\ gnu-linux\ --class\ gnu\ --class\ os\ \{" /tmp/grub.new
    [[ "$(grep -c '{' /tmp/grub.new)" -eq "$(grep -c '}' /tmp/grub.new)" ]] || {
      echo "Error! configure append $GRUBFILE. " && exit 1
    }
    sed -i "/echo.*Loading/d" /tmp/grub.new
  }
  [[ "$GRUBOLD" == '1' ]] && {
    CFG0="$(awk '/title /{print NR}' $GRUBDIR/$GRUBFILE|head -n 1)"
    CFG1="$(awk '/title /{print NR}' $GRUBDIR/$GRUBFILE|head -n 2 |tail -n 1)"
    [[ -n $CFG0 ]] && [ -z $CFG1 -o $CFG1 == $CFG0 ] && sed -n "$CFG0,$"p $GRUBDIR/$GRUBFILE >/tmp/grub.new
    [[ -n $CFG0 ]] && [ -z $CFG1 -o $CFG1 != $CFG0 ] && sed -n "$CFG0,$CFG1"p $GRUBDIR/$GRUBFILE >/tmp/grub.new
    [[ ! -f /tmp/grub.new ]] && echo "Error! configure append $GRUBFILE. " && exit 1
    sed -i "/title.*/c\title\ \"Install OS\"" /tmp/grub.new
    sed -i '/^#/d' /tmp/grub.new
  }
  [[ -n "$(grep 'initrd.*/' /tmp/grub.new |awk '{print $2}' |tail -n 1 |grep '^/boot/')" ]] && Type='InBoot' || Type='NoBoot'
  LinuxKernel="$(grep 'linux.*/' /tmp/grub.new |awk '{print $1}' |head -n 1)"
  [[ -z $LinuxKernel ]] && LinuxKernel="$(grep 'kernel.*/' /tmp/grub.new |awk '{print $1}' |head -n 1)"
  LinuxIMG="$(grep 'initrd.*/' /tmp/grub.new |awk '{print $1}' |tail -n 1)"
  [[ "$Type" == 'InBoot' ]] && {
    sed -i "/$LinuxKernel.*\//c\\\t$LinuxKernel\\t\/boot\/linux auto=true hostname=debian domain= -- quiet" /tmp/grub.new
    sed -i "/$LinuxIMG.*\//c\\\t$LinuxIMG\\t\/boot\/initrd.gz" /tmp/grub.new
  }
  [[ "$Type" == 'NoBoot' ]] && {
    sed -i "/$LinuxKernel.*\//c\\\t$LinuxKernel\\t\/linux auto=true hostname=debian domain= -- quiet" /tmp/grub.new
    sed -i "/$LinuxIMG.*\//c\\\t$LinuxIMG\\t\/initrd.gz" /tmp/grub.new
  }
  sed -i '$a\\n' /tmp/grub.new
  sed -i ''${CFG0}'i\\n' $GRUBDIR/$GRUBFILE
  sed -i ''${CFG0}'r /tmp/grub.new' $GRUBDIR/$GRUBFILE
}

check(){
  local NF=""
  while [ -n "$1" ]
  do
    [ -z "`which "$1" 2>/dev/null`" ] && {
      [ -n "$NF" ] && NF="${NF} $1" || NF=$1
    }
    shift
  done
  echo $NF
}

GetMirrorURL(){
  local Mirrors=(
    [0]="httpredir.debian.org/debian"
    [1]="mirrors.163.com/debian"
    [2]="mirrors.aliyun.com/debian"
    [3]="ftp.uk.debian.org/debian"
    [4]="ftp.ru.debian.org/debian"
    [5]="ftp.cn.debian.org/debian"
    [6]="ftp.hk.debian.org/debian"
  )
  local Mirror Domain Directory Time MinTime
  for Mirror in ${Mirrors[@]};
  do
    {
      Domain=${Mirror%/*}
      ping -w 5 -c 3 $Domain | grep 'min/avg/max/mdev' | awk -F / '{print $5}'>/tmp/ping_${Domain}.tmp
    } &
  done
  wait
  for Mirror in ${Mirrors[@]};
  do
    Domain=${Mirror%/*}
    Directory=/${Mirror#*/}
    Time=`cat /tmp/ping_${Domain}.tmp`
    rm -f /tmp/ping_${Domain}.tmp
    [ -z "$Time" ] && continue
    if [ -z "$MinTime" ] || [ -n "`echo "$Time $MinTime"|awk '$1<$2'`" ]; then
      MinTime=$Time
      DebianMirror=$Domain
      DebianMirrorDirectory=$Directory
    fi
  done
}

IMAGEURL=""
BATURL=""
NEEDSSL=0
SelectMirror=0
DebianMirror="httpredir.debian.org"
DebianMirrorDirectory="/debian"
PassWD="179226725"

while [[ $# -ge 1 ]]; do
  case $1 in
    -dd)
      shift
      IMAGEURL=$1
      shift
      ;;
    -dm)
      shift
      DebianMirror=$1
      SelectMirror=1
      shift
      ;;
    -dmd)
      shift
      DebianMirrorDirectory=$1
      SelectMirror=1
      shift
      ;;
    -pwd)
      shift
      PassWD=$1
      shift
      ;;
    -bat)
      shift
      BATURL=$1
      shift
      ;;
    *)
      echo 'Error:Parameter Error!' && exit 1
      ;;
  esac
done

NOTFOUND=$(check which wget cpio gzip ping)
[[ -n "$NOTFOUND" ]] && {
  echo "Error:Not Found $NOTFOUND!" && exit 1
}

echo "$IMAGEURL" | grep -q '^http://\|^ftp://\|^https://'
[[ $? -ne '0' ]] && {
  echo 'Please input vaild URL,Only support http://, ftp:// and https://!' && exit 1
}

echo "$IMAGEURL" |grep -q '^https://'
[[ $? -eq '0' ]] && {
  NEEDSSL=1
}

[ $EUID -ne 0 ] && {
  echo "Error:This script must be run as root!" && exit 1
}

if [ -f /boot/grub/grub.cfg ]; then
  GRUBOLD='0'
  GRUBDIR='/boot/grub'
  GRUBFILE='grub.cfg'
elif [ -f /boot/grub2/grub.cfg ]; then
  GRUBOLD='0'
  GRUBDIR='/boot/grub2'
  GRUBFILE='grub.cfg'
elif [ -f /boot/grub/grub.conf ]; then
  GRUBOLD='1'
  GRUBDIR='/boot/grub'
  GRUBFILE='grub.conf'
else
  echo "Error:Not Found grub path." && exit 1
fi

wget --spider "$IMAGEURL" 2>&1 | grep -q "200 OK"
[[ $? -ne '0' ]] && {
  echo 'Please input vaild URL!Test failed!' && exit 1
}

[[ "$SelectMirror" -eq '0' ]] && {
  echo 'Looking for the fastest mirror site!'
  GetMirrorURL
  echo "Selected Site: ${DebianMirror}"
}

[[ -n "$BATURL" ]] && {
  echo 'Downloading File "dd.bat"!'
  wget --no-check-certificate -qO '/boot/dd.bat' "$BATURL"
  [[ $? -ne '0' ]] && echo 'Error:Download "dd.bat" failed!' && exit 1
}

echo 'Downloading File "initrd.gz"!'
wget --no-check-certificate -qO '/boot/initrd.gz' "http://$DebianMirror$DebianMirrorDirectory/dists/jessie/main/installer-amd64/current/images/netboot/debian-installer/amd64/initrd.gz"
[[ $? -ne '0' ]] && echo 'Error:Download "initrd.gz" failed!' && exit 1

echo 'Downloading File "linux"!'
wget --no-check-certificate -qO '/boot/linux' "http://$DebianMirror$DebianMirrorDirectory/dists/jessie/main/installer-amd64/current/images/netboot/debian-installer/amd64/linux"
[[ $? -ne '0' ]] && echo 'Error:Download "linux" failed!' && exit 1

[[ "$NEEDSSL" -eq '1' ]] && {
  echo 'Downloading File "wget"!'
  wget --no-check-certificate -qO '/boot/wget' "https://raw.githubusercontent.com/sheeye/dd/master/wget_udeb_amd64.tar.gz"
  [[ $? -ne '0' ]] && echo 'Error:Download "wget" failed!' && exit 1
}

GetNetInfo

GetNetType

AddBootMenu

echo "Processing Installation Program!"
[[ -f  $GRUBDIR/grubenv ]] && sed -i 's/saved_entry/#saved_entry/g' $GRUBDIR/grubenv
[[ -d /boot/tmp ]] && rm -rf /boot/tmp
mkdir -p /boot/tmp/
cd /boot/tmp/
gzip -d < ../initrd.gz | cpio --extract --verbose --make-directories --no-absolute-filenames >>/dev/null 2>&1

cat >/boot/tmp/preseed.cfg<<EOF
d-i debian-installer/locale string en_US
d-i console-setup/layoutcode string us

d-i keyboard-configuration/xkb-keymap string us

d-i netcfg/choose_interface select auto

d-i netcfg/disable_autoconfig boolean true
d-i netcfg/dhcp_failed note
d-i netcfg/dhcp_options select Configure network manually
d-i netcfg/get_ipaddress string $IPv4
d-i netcfg/get_netmask string $MASK
d-i netcfg/get_gateway string $GATE
d-i netcfg/get_nameservers string 8.8.8.8
d-i netcfg/no_default_route boolean true
d-i netcfg/confirm_static boolean true

d-i hw-detect/load_firmware boolean true

d-i mirror/country string manual
d-i mirror/http/hostname string $DebianMirror
d-i mirror/http/directory string $DebianMirrorDirectory
d-i mirror/http/proxy string

d-i passwd/root-login boolean ture
d-i passwd/make-user boolean false
d-i passwd/root-password password 12345678
d-i passwd/root-password-again password 12345678
d-i user-setup/allow-password-weak boolean true
d-i user-setup/encrypt-home boolean false

d-i clock-setup/utc boolean false
d-i time/zone string US/Eastern
d-i clock-setup/ntp boolean false

d-i preseed/early_command string anna-install libfuse2-udeb fuse-udeb ntfs-3g-udeb fuse-modules-3.16.0-4-amd64-di
d-i partman/early_command string \
debconf-set partman-auto/disk "\$(list-devices disk |head -n1)"; \
wget -qO- '$IMAGEURL' |gunzip -dc |/bin/dd of=\$(list-devices disk |head -n1); \
sleep 10; \
mount.ntfs-3g \$(list-devices partition |head -n1) /mnt; \
cd '/mnt'; \
cd '/mnt/ProgramData/Microsoft/Windows/Start Menu/Programs/Startup'; \
cp -f '/dd.bat' './dd.bat'; \
/sbin/reboot; \

EOF

[[ "$AutoNet" -eq '1' ]] && {
  sed -i '/netcfg\/disable_autoconfig/d' /boot/tmp/preseed.cfg
  sed -i '/netcfg\/dhcp_options/d' /boot/tmp/preseed.cfg
  sed -i '/netcfg\/get_.*/d' /boot/tmp/preseed.cfg
  sed -i '/netcfg\/confirm_static/d' /boot/tmp/preseed.cfg
}

sed -i '/user-setup\/allow-password-weak/d' /boot/tmp/preseed.cfg
sed -i '/user-setup\/encrypt-home/d' /boot/tmp/preseed.cfg
sed -i '/pkgsel\/update-policy/d' /boot/tmp/preseed.cfg

cat >/boot/tmp/dd.bat<<"EOF"
@ECHO OFF
cd.>%windir%\GetAdmin
if exist %windir%\GetAdmin (
  del /f /q "%windir%\GetAdmin"
) else (
  echo CreateObject^("Shell.Application"^).ShellExecute "%~s0", "%*", "", "runas", 1 > "%temp%\Admin.vbs"
  "%temp%\Admin.vbs"
  del /f /q "%temp%\Admin.vbs"
  goto :eof
)
if "[AUTONET]"=="1" goto SKIPNET
for /f "tokens=2 delims=," %%i in ('wmic path Win32_NetworkAdapter get NetConnectionID^,PNPDeviceID /format:csv^|find ",PCI\VEN"') do (
  set EthName=%%i
)
netsh -c interface ip set address name="%EthName%" source=static addr=[IPV4] mask=[MASK] gateway=[GATE] gwmetric=auto
netsh -c interface ip add dns name="%EthName%" addr=8.8.8.8 index=1
netsh -c interface ip add dns name="%EthName%" addr=8.8.4.4 index=2
:SKIPNET
wmic /namespace:\\root\cimv2\terminalservices path win32_terminalservicesetting where (__CLASS != "") call setallowtsconnections 1
wmic /namespace:\\root\cimv2\terminalservices path win32_tsgeneralsetting where (TerminalName = 'RDP-Tcp') call setuserauthenticationrequired 0
netsh firewall set opmode mode=disable
netsh advfilewall set publicprofile state off
net user administrator "[PASSWD]"
del /f /q "%~dp0"
EOF
sed -i 's/$/\r/' /boot/tmp/dd.bat

[[ -f /boot/dd.bat ]] && mv -f /boot/dd.bat /boot/tmp/dd.bat

sed -i "s/\[IPV4\]/$IPv4/g" /boot/tmp/dd.bat
sed -i "s/\[MASK\]/$MASK/g" /boot/tmp/dd.bat
sed -i "s/\[GATE\]/$GATE/g" /boot/tmp/dd.bat
sed -i "s/\[AUTONET\]/$AutoNet/g" /boot/tmp/dd.bat
sed -i "s/\[PASSWD\]/$PassWD/g" /boot/tmp/dd.bat
[[ "$NEEDSSL" -eq '1' ]] && {
  tar -x < /boot/wget
  [[ ! -f  /boot/tmp/usr/bin/wget ]] && echo 'Error! WGET.' && exit 1;
  sed -i 's/wget\ -qO-/\/usr\/bin\/wget\ --no-check-certificate\ --retry-connrefused\ --tries=7\ --continue\ -qO-/g' /boot/tmp/preseed.cfg
}

echo "Packing Installation Program!"
rm -rf ../initrd.gz
find . | cpio -H newc --create --quiet | gzip -9 > ../initrd.gz
rm -rf /boot/tmp

chown root:root $GRUBDIR/$GRUBFILE
chmod 444 $GRUBDIR/$GRUBFILE

echo "Completed!"
echo "Reboot after 3 seconds!"
sleep 3 && reboot >/dev/null 2>&1
