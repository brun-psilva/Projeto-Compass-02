#!/bin/bash

# Atualização de Pacotes Instalados
sudo apt-get update -y

# Instala pacotes necessários
sudo apt-get install -y ca-certificates curl

# Instalar o repositório apt
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Adicione o repositório às fontes do Apt:
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Instalar o Docker e o Compose Plugin
sudo apt-get update -y
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Startando Docker e adicionando permissões
sudo systemctl start docker
sudo systemctl enable docker

# Adicionando o usuário ubuntu ao grupo docker
sudo usermod -aG docker ubuntu

# Instalando o EFS-utils e montando no sistema
sudo apt-get -y install nfs-common
sudo mkdir -p /efs
sudo mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport 172.31.13.107:/ /efs
echo "172.31.13.107:/     /efs      nfs4      nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport,_netdev      0      0" | sudo tee -a /etc/fstab

# Criando o arquivo docker-compose.yaml com configuração do WordPress conectado ao RDS
cat <<EOF | sudo tee /home/ubuntu/docker-compose.yaml
version: '3.8'
services:
  wordpress:
    image: wordpress
    restart: always
    ports:
      - "80:80"
    environment:
      WORDPRESS_DB_HOST: database-1.c38ggoecwp8b.us-east-1.rds.amazonaws.com
      WORDPRESS_DB_USER: admin
      WORDPRESS_DB_PASSWORD: Amazon.12345
      WORDPRESS_DB_NAME: wordpressdb
    volumes:
      - /efs/wordpress:/var/www/html
EOF

# Iniciando o docker-compose
docker compose -f /home/ubuntu/docker-compose.yaml up -d

