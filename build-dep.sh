set -e

apt-get update


apt-get install -y \
  autoconf automake cmake libtool libtool-bin build-essential make libssl-dev \
  libtiff-dev pkg-config uuid-dev libsqlite3-dev libcurl4-openssl-dev \
  libspeexdsp-dev libpcre3-dev libldns-dev libedit-dev yasm liblua5.2-dev lua5.2 \
  libopus-dev libpq-dev portaudio19-dev libshout3-dev libmpg123-dev libmp3lame-dev libsndfile-dev dpatch

apt-get install -y \
  lsb-release debhelper libglib2.0-dev doxygen graphviz docbook-xsl xsltproc


# --------------------------- sofia-sip --------------------------- #

mkdir -p /opt/freeswitch/libs
mkdir -p /opt/freeswitch/debs

git clone https://github.com/freeswitch/sofia-sip.git /opt/freeswitch/libs/sofia-sip/

echo 'Building sofia-sip...'
cd /opt/freeswitch/libs/sofia-sip/
dpkg-buildpackage
dpkg -i ../libsofia-sip-ua0_*.deb # Enough to run FreeSWITCH
dpkg -i ../libsofia-sip-ua-*.deb # Required to build FreeSWITCH, no need to ship
echo 'Built sofia-sip'


# ---------------------------- spandsp ---------------------------- #

echo 'Building spandsp...'
git clone https://github.com/freeswitch/spandsp.git  /opt/freeswitch/libs/spandsp
cd  /opt/freeswitch/libs/spandsp
git reset --hard 67d2455efe02e7ff0d897f3fd5636fed4d54549e
dpkg-buildpackage -b
dpkg -i ../libspandsp3_3*.deb # Enough to run FreeSWITCH
dpkg -i ../libspandsp3-dev_*.deb # Required to build FreeSWITCH, no need to ship

cp ../libspandsp3_3*.deb /opt/freeswitch/debs/

echo 'Built spandsp'


# ---------------------------- libks ---------------------------- #

git clone https://github.com/signalwire/libks.git  /opt/freeswitch/libs/libks

echo 'Building libks...'
cd /opt/freeswitch/libs/libks/
PACKAGE_RELEASE="42" cmake . -DCMAKE_BUILD_TYPE=Release && make package
dpkg -i libks2_2*.deb
cp libks2_2*.deb /opt/freeswitch/debs/
echo 'Built libks'


# ------------------------- signalwire-c ------------------------- #

echo 'Building signalwire-c...'
git clone https://github.com/signalwire/signalwire-c /opt/freeswitch/libs/signalwire-c

cd /opt/freeswitch/libs/signalwire-c/
PACKAGE_RELEASE="42" cmake . -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX:PATH=/usr/local/freeswitch && make package

dpkg -i signalwire-client-*.deb
cp signalwire-client-*.deb ../../debs
echo 'Built signalwire-c'

# -------------------------- FreeSWITCH -------------------------- #

echo 'Building FreeSWITCH...'
wget -c https://files.freeswitch.org/releases/freeswitch/freeswitch-1.10.11.-release.tar.gz -P /opt/freeswitch

cd /opt/freeswitch/
tar -zxvf freeswitch-1.10.11.-release.tar.gz
cd freeswitch-1.10.11.-release
./configure --prefix=/usr/local/freeswitch --disable-libvpx
cp /opt/freeswitch/Ziwo/modules.conf /opt/freeswitch/modules.conf
make
make install

mkdir -p /tmp/freeswitch/usr/local/freeswitch/
mkdir -p /tmp/freeswitch/DEBIAN/
mkdir -p /tmp/freeswitch/etc/systemd/system
mkdir -p /tmp/freeswitch/usr/bin/

cp -rv /usr/local/freeswitch/* /tmp/freeswitch/usr/local/freeswitch/
cp -rv /usr/local/freeswitch/bin/* /tmp/freeswitch/usr/bin/


cat <<EOT > /tmp/freeswitch/DEBIAN/control
Package: freeswitch
Comment: # TODO: `git describe --tags --long`
Version: 1.10.11.2
Architecture: amd64
Description: Ziwo FreeSWITCH
Maintainer: Ziwo Infrastructure <infra@ziwo.io>
Depends: libsqlite3-0, libcurl4, libspeexdsp1, libedit2, libpq5, libldns3, liblua5.2-0, libopus0, libshout3, libsndfile1, libmpg123-0, libsofia-sip-ua0 (= 1.13.17-0), libspandsp3 (= 3.0.0-42), libks2 (= 2.0.5-42~jammy), signalwire-client-c2 (= 2.0.1-42~jammy)
EOT

cat <<EOT > /tmp/freeswitch/DEBIAN/postinst
#!/bin/bash
systemctl daemon-reload
systemctl enable freeswitch
systemctl start freeswitch
EOT

chmod +x /tmp/freeswitch/DEBIAN/postinst

#env var for freeswitch
touch /tmp/freeswitch/usr/local/freeswitch/freeswitch
mkdir -p  /tmp/freeswitch/etc/systemd/system/freeswitch.service

cat <<EOT > /tmp/freeswitch/etc/systemd/system/freeswitch.service
[Unit] 
Description=FreeSWITCH open source softswitch 
Wants=network-online.target Requires=network.target local-fs.target 
After=network.target network-online.target local-fs.target 

[Service] 
; service 
Type=forking 
Environment="DAEMON_OPTS=-nonat" 
Environment="USER=root" 
Environment="GROUP=root" 
EnvironmentFile=-/usr/local/freeswitch/freeswitch 
ExecStartPre=/bin/chown -R root:root /usr/local/freeswitch 
ExecStart=/usr/bin/freeswitch -u root -g root -ncwait ${DAEMON_OPTS} 
TimeoutSec=45s 
Restart=always 

[Install] 
WantedBy=multi-user.target
EOT


dpkg-deb --build /tmp/freeswitch
dpkg-name -o /tmp/freeswitch.deb
dpkg -i /tmp/freeswitch_1.10.11.2_amd64.deb
cp /tmp/freeswitch_*.deb /opt/freeswitch/debs

echo 'Built FreeSWITCH!!'



###REPO
# Iterate over all .txt files in /tmp/toto
for file in /opt/freeswitch/debs/*.deb; do
  # Check if the file exists (in case there are no .txt files)
  if [ -f "$file" ]; then
    # Extract the first letter of the filename (excluding the path)
    filename=$(basename "$file")
    first_letter=${filename:0:1}
    
    # Create the target directory based on the first letter
    target_dir="/var/repo/pool/main/$first_letter"
    mkdir -p "$target_dir"
    # Copy the .txt file into the target directory
    cp "$file" "$target_dir/"
    
    echo "Copied $file to $target_dir/"
  fi
done

echo "Done."




