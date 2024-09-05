#!/bin/bash

CHROMADB_VERSION="0.5.4"

sudo apt update && sudo apt install python3-pip python3-venv -y
sudo mkdir -p /var/www/chromadb /var/lib/chromadb /var/log/chromadb
sudo chown $USER -R  /var/www/chromadb
cd /var/www/chromadb
python3 -m venv venv
source venv/bin/activate
pip install chromadb==$CHROMADB_VERSION
sudo chown www-data:www-data -R /var/www/chromadb /var/lib/chromadb /var/log/chromadb
echo '[Unit]
Description=Chromadb
After=network.target

[Service]
User=www-data
Group=www-data
WorkingDirectory=/var/www/chromadb
Environment="PATH=/var/www/chromadb/venv/bin:$PATH"
Environment="ANONYMIZED_TELEMETRY=False"
ExecStart=/var/www/chromadb/venv/bin/chroma run --host 0.0.0.0 --port 8000 --path /var/lib/chromadb --log-path /var/log/chromadb/chromadb.log
LimitNOFILE=64000

[Install]
WantedBy=multi-user.target' | sudo tee /etc/systemd/system/chromadb.service
sudo systemctl daemon-reload
sudo systemctl enable --now chromadb