#!/bin/bash
# 
# basedod on https://computingforgeeks.com/install-and-use-guacamole-on-ubuntu/
#
#
#
# Guacamole 1.3: https://apache.org/dyn/closer.lua/guacamole/1.3.0/source/guacamole-server-1.3.0.tar.gz?action=download
#
#
#
# Guacamole Web Client: https://downloads.apache.org/guacamole/1.3.0/binary/guacamole-1.3.0.war

#
# Get updates
sudo apt update

# Install updates
sudo apt dist-upgrade -y

# Install dependencies
sudo apt update
sudo apt install gcc vim curl wget g++ libcairo2-dev libjpeg-turbo8-dev libpng-dev libtool-bin libossp-uuid-dev libavcodec-dev libavutil-dev libswscale-dev build-essential libpango1.0-dev libssh2-1-dev libvncserver-dev libtelnet-dev libssl-dev libvorbis-dev libwebp-dev unzip -y

# Using FreeRDP2 hosted in remmina PPA
sudo add-apt-repository ppa:remmina-ppa-team/freerdp-daily
sudo apt update
sudo apt install freerdp2-dev freerdp2-x11 -y

# Install Apache Tomcat
sudo apt install openjdk-11-jdk -y

## Confirm JAVA > 11.0.11 as of July 14th
#		java --version


# Create separate non-root user to run applications
sudo useradd -m -U -d /opt/tomcat -s /bin/false tomcat

# Get Apache Tomcat (latest)
# This is 9.0.5.0 as of today
wget https://httpd-mirror.sergal.org/apache/tomcat/tomcat-9/v9.0.50/bin/apache-tomcat-9.0.50.zip -P ~

# Extract the files to /opt/tomcat and cleanup
sudo mkdir /opt/tomcat
sudo unzip apache-tomcat-9.0.50.zip
sudo mv apache-tomcat-9.0.50 /opt/tomcat/tomcatapp
sudo rm apache-tomcat-9.0.50.zip

# Give tomact rights to run guacamole
sudo chown -R tomcat: /opt/tomcat

# Make all shell scripts in directory executable
sudo chmod +x /opt/tomcat/tomcatapp/bin/*.sh


## Create a new file
sudo nano /etc/systemd/system/tomcat.service

# Paste these contents in the file

#		[Unit]
#		Description=Tomcat 9 servlet container
#		After=network.target
#
#		[Service]
#		Type=forking
#
#		User=tomcat
#		Group=tomcat
#
#		Environment="JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64"
#		Environment="JAVA_OPTS=-Djava.security.egd=file:///dev/urandom -Djava.awt.headless=true"
#
#		Environment="CATALINA_BASE=/opt/tomcat/tomcatapp"
#		Environment="CATALINA_HOME=/opt/tomcat/tomcatapp"
#		Environment="CATALINA_PID=/opt/tomcat/tomcatapp/temp/tomcat.pid"
#		Environment="CATALINA_OPTS=-Xms512M -Xmx1024M -server -XX:+UseParallelGC"
#
#		ExecStart=/opt/tomcat/tomcatapp/bin/startup.sh
#		ExecStop=/opt/tomcat/tomcatapp/bin/shutdown.sh
#
#		[Install]
#		WantedBy=multi-user.target


# Reload the service
sudo systemctl daemon-reload

# Start the service
sudo systemctl enable --now tomcat

# Update firewall rules for 8080
sudo ufw allow 8080/tcp


## Build Guacamole Server from Source


# Download latest
wget https://downloads.apache.org/guacamole/1.3.0/source/guacamole-server-1.3.0.tar.gz -P ~

# Extract tarball
tar xzf ~/guacamole-server-1.3.0.tar.gz

# Remove zip
sudo rm guacamole-server-1.3.0.tar.gz

# Move to directory
cd ~/guacamole-server-1.3.0

# Run the config script
./configure --with-init-dir=/etc/init.d

# Compile
make

# install
sudo make install

# Create links and cache to most recent shared libraries
sudo ldconfig

# Restart service
sudo systemctl daemon-reload

# Start & Enable service
sudo systemctl start guacd
sudo systemctl enable guacd



# Install Guacamole Web Application
cd ~
sudo mkdir /etc/guacamole
wget https://downloads.apache.org/guacamole/1.3.0/binary/guacamole-1.3.0.war -P ~
sudo mv ~/guacamole-1.3.0.war /etc/guacamole/guacamole.war

# Create symlink from guacamole client to tomcat webapps dir
sudo ln -s /etc/guacamole/guacamole.war /opt/tomcat/tomcatapp/webapps


## Configure Guacamole Server

# Create GUACAMOLE_HOME environment variable
echo "GUACAMOLE_HOME=/etc/guacamole" | sudo tee -a /etc/default/tomcat


# Create guacamole.properties file
# This is important
sudo nano /etc/guacamole/guacamole.properties

## Add the following to it

#		guacd-hostname: localhost
#		guacd-port: 4822
#		user-mapping: /etc/guacamole/user-mapping.xml
#		auth-provider: net.sourceforge.guacamole.net.basic.BasicFileAuthenticationProvider

# Link this file to the guacamole configs directory
sudo ln -s /etc/guacamole /opt/tomcat/tomcatapp/.guacamole


# Setup Guacamole Authentication Method


# Create password has
# Config store passwords in plain text, so use a hash

echo -n StrongPW@492 | openssl md5
# (stdin)= 8dcca9c219fcf18ce03c32f778a3f45e
# note md5 is weak, but trouble switching to different one


# Create User-Mapping.XML file
sudo nano /etc/guacamole/user-mapping.xml

# Add this to XML file
<?xml version="1.0" encoding="UTF-8"?>
<user-mapping>
	
    <!-- Per-user authentication and config information -->
    <authorize username="ACCOUNTING" password="PASSWORD">
        <protocol>vnc</protocol>
        <param name="hostname">10.10.11.114</param>
        <param name="port">5900</param>
        <param name="password">VNCPASS</param>
    </authorize>

    <!-- Another user, but using md5 to hash the password
         (example below uses the md5 hash of "PASSWORD") -->
    <authorize 
            username="yalefox"
            password="8dcca9c219fcf18ce03c32f778a3f45e"
            encoding="md5">

        <!-- First authorized connection -->
		<connection name="localhost">
            <protocol>vnc</protocol>
            <param name="hostname">localhost</param>
            <param name="port">5901</param>
            <param name="password">VNCPASS</param>
        </connection>

        <!-- Second authorized connection -->
   		<connection name="otherhost">
            <protocol>vnc</protocol>
            <param name="hostname">otherhost</param>
            <param name="port">5900</param>
            <param name="password">VNCPASS</param>
        </connection>

 </authorize>

</user-mapping>




## Restart Interface
sudo systemctl restart tomcat guacd

## Allow Ports
sudo ufw allow 4822/tcp

# Go to the web panel
#

# http://10.10.11.7:8080/guacamole/
