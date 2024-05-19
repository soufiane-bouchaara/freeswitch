set -e

apt-get update


apt-get install -y \
  autoconf automake cmake libtool libtool-bin build-essential make libssl-dev \
  libtiff-dev pkg-config uuid-dev libsqlite3-dev libcurl4-openssl-dev \
  libspeexdsp-dev libpcre3-dev libldns-dev libedit-dev yasm liblua5.2-dev lua5.2 \
  libopus-dev libpq-dev portaudio19-dev libshout3-dev libmpg123-dev libmp3lame-dev libsndfile-dev dpatch libavformat-dev libswscale-dev

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
PKG_CONFIG_PATH=usr/local/freeswitch/lib/pkgconfig PACKAGE_RELEASE="42" cmake . -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX:PATH=/usr/local/freeswitch 
make package


dpkg -i signalwire-client-*.deb
cp signalwire-client-*.deb ../../debs
echo 'Built signalwire-c'
ldconfig

# -------------------------- FreeSWITCH -------------------------- #

echo 'Building FreeSWITCH...'
#wget -c https://files.freeswitch.org/releases/freeswitch/freeswitch-1.10.11.-release.tar.gz -P /opt/freeswitch
git clone https://github.com/signalwire/freeswitch.git /opt/freeswitch
cd /opt/freeswitch/
#tar -zxvf freeswitch-1.10.11.-release.tar.gz
#cd freeswitch-1.10.11.-release
./bootstrap.sh -j
./configure --prefix=/usr/local/freeswitch --disable-libvpx

cat <<EOT > /opt/freeswitch/modules.conf
applications/mod_abstraction
applications/mod_bert
applications/mod_blacklist
applications/mod_callcenter
applications/mod_cidlookup
applications/mod_cluechoo
applications/mod_commands
applications/mod_conference
applications/mod_curl
applications/mod_db
applications/mod_directory
applications/mod_distributor
applications/mod_dptools
applications/mod_easyroute
applications/mod_enum
applications/mod_esf
applications/mod_esl
applications/mod_expr
applications/mod_fifo
applications/mod_fsk
applications/mod_fsv
applications/mod_hash
applications/mod_httapi
applications/mod_http_cache
applications/mod_lcr
applications/mod_sms
applications/mod_snom
applications/mod_sonar
applications/mod_spandsp
applications/mod_spy
applications/mod_stress
applications/mod_valet_parking
applications/mod_voicemail
applications/mod_voicemail_ivr
codecs/mod_amr
codecs/mod_b64
codecs/mod_g723_1
codecs/mod_g729
codecs/mod_h26x
codecs/mod_opus
codecs/mod_vpx
dialplans/mod_dialplan_asterisk
dialplans/mod_dialplan_xml
endpoints/mod_loopback
endpoints/mod_portaudio
endpoints/mod_rtc
endpoints/mod_rtmp
endpoints/mod_skinny
endpoints/mod_sofia
endpoints/mod_verto
event_handlers/mod_cdr_csv
event_handlers/mod_cdr_sqlite
event_handlers/mod_event_socket
event_handlers/mod_format_cdr
event_handlers/mod_json_cdr
formats/mod_local_stream
formats/mod_native_file
formats/mod_png
formats/mod_portaudio_stream
formats/mod_shout
formats/mod_sndfile
formats/mod_tone_stream
loggers/mod_console
loggers/mod_logfile
loggers/mod_syslog
say/mod_say_en
xml_int/mod_xml_cdr
xml_int/mod_xml_curl
xml_int/mod_xml_rpc
xml_int/mod_xml_scgi
databases/mod_pgsql
languages/mod_lua
EOT


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




