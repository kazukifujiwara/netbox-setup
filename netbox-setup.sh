#!/bin/bash
sudo apt update
sudo apt-get install apt-transport-https ca-certificates curl gnupg-agent software-properties-common -y
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable"
sudo apt update && sudo apt install docker-ce docker-ce-cli containerd.io docker-compose -y
git clone -b release https://github.com/netbox-community/netbox-docker.git
cd netbox-docker

tee plugin_requirements.txt <<EOF
netbox-bgp
EOF

tee Dockerfile-Plugins <<EOF
FROM netboxcommunity/netbox:latest

COPY ./plugin_requirements.txt /
RUN /opt/netbox/venv/bin/pip install  --no-warn-script-location -r /plugin_requirements.txt

# These lines are only required if your plugin has its own static files.
COPY configuration/configuration.py /etc/netbox/config/configuration.py
RUN SECRET_KEY="dummy" /opt/netbox/venv/bin/python /opt/netbox/netbox/manage.py collectstatic --no-input
EOF

tee docker-compose.override.yml <<EOF
version: '3.4'
services:
  netbox:
    ports:
      - 8000:8080
    build:
      context: .
      dockerfile: Dockerfile-Plugins
    image: netbox:latest-plugins
  netbox-worker:
    image: netbox:latest-plugins
EOF

tee -a configuration/configuration.py <<EOF
PLUGINS = ["netbox_bgp"]

PLUGINS_CONFIG = {
  "netbox_bgp": {
    "asdot": False
  }
}
EOF

sudo docker-compose build --no-cache
sudo docker-compose up -d

