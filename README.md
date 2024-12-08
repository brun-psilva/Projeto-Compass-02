# Executar WordPress contênizado usando Ferramentas da AWS

O projeto disposto na segunda fase consiste em elaborar um ambiente escalável e seguro para rodar uma aplicação WordPress. Este trabalho envolve configurar diversos serviços e tecnologias para garantir o funcionamento do site com o armazenamento persistente, balanceamento de carga e integração com um banco de dados gerenciado.

## Componentes do Projeto

#### 1. Instância EC2 com Docker:
- Configurar uma máquina virtual (EC2) como host para rodar contêineres Docker.
- A instalação do Docker pode ser automatizada via script de inicialização (*user_data.sh*).

#### 2. Criação de um Banco de Dados RDS MYSQL:
- Utilizar o Amazon RDS para hospedar o banco de dados MySQL que armazenará os dados do WordPress.
-Garantir a comunicação segura entre o RDS e o contêiner do WordPress, utilizando configurações de rede na VPC.

#### 3.Armazenamento Persistente com EFS (Elastic File System):
- Configurar um sistema de arquivos compartilhado (EFS) para armazenar os arquivos estáticos do WordPress, como uploads e plugins.
- Montar o EFS no contêiner para garantir persistência dos dados mesmo em caso de reinício.

#### 4. Load Balancer:

- Configurar um Load Balancer da AWS (Classic ou Application) para gerenciar o tráfego de entrada.
- O Load Balancer será responsável por fornecer alta disponibilidade e balanceamento de carga entre múltiplas instâncias, se necessário.

#### 5. Rede Segura:

- Configurar o ambiente para evitar a exposição pública desnecessária:
   - Remover IP público da instância EC2.
   - Direcionar todo o tráfego externo pelo Load Balancer.
- Utilizar um NAT Gateway para permitir acesso à internet para atualizações e instalação de dependências, mantendo o ambiente isolado.

#### 6. Ferramentas de Contêiner:

- Escolha entre utilizar Dockerfile para criar imagens customizadas ou docker-compose para orquestrar os contêineres.
- Configurar o contêiner do WordPress para se conectar ao banco RDS e ao EFS.

# Arquitetura Disposta

![Arquitetura do Projeto](Images/Captura%20de%20tela%20de%202024-12-05%2022-47-58.png)


### Criação da VPC
Para criação da VPC, afim de distribuir toda a infraestrutura da rede para conexão das instâncias, fiz da seguinte forma:

Imagem de Exemplo->

Usei o modo defaut de criação de VPC, para que assim pudesse aprimorar com o desencadear do projeto.

Foi criada 4 subnets, sendo duas Públicas e dua Privadas, para agregar as duas EC2, sendo uma ná pública e a outra em uma privada, limitando o acesso.Dentro desta privada é que rodará nosso script com WordPress. E ainda, estas 4 distribiuídas em duas zonas de disponibilidade, 1a e 1b.

Para controlar o acesso, criei um Gateway NAT, para controlar o acesso entre as redes na VPC.

### SG (Securit Groups)
Após a criação da VPC, foi designado um Grupo de segurança para designar a forma de comunicação das Instâncias e assim limitar e liberar o acesso delas a recursos de infra.

Para o RDS, e o EFS (que veremos a frente), foram alocados em um grupo privado, onde apenas a instância pública tem acesso a eles. Sendo o BD acessado pela porta 3306 e o EFS na porta 2049.

Já para as instâncias, foi criado um grupo público, com IP aberto, para que possa acessar as instâncias privadas.


### RDS ( Banco de Dados)

Para que que a aplicação WordPress possa rodar, ela precisa estar conectada a um Banco de dados. E para criação dele, usei a documentação presente [Neste link da AWS](https://aws.amazon.com/pt/tutorials/deploy-wordpress-with-amazon-rds/module-one/).

Para resumo, escolhi a opção criação padrão, em seguida selecionei a opção MySQL.

Neste momento, não usamos a opção Conectar-se a um recurso de computação do EC2, pois a instância ainda não foi criada.

O Template, use Free Tier

Nas configurações siga:
- DB instance: database-1
- Master Username: (nome de sua escolha)
- Master Password: (senha de sua escolha)

Conectividade
Use a VCP que criamos acima
escolha o SG privado, conforme criamos acima
ZOna de disponibilidade, use (no preference)

E em Informações adicionais 
- Nome inical do Banco de Dados: (de sua escolha)

### Criação do EFS

Para que os dados da aplicação fiquem salvos, configuramos o EFS desta forma:

Aperte em `Criar Sistemas de Arquivos`
Escolha o nome de sua preferência
Em VPC, selecione a que criamos acima
Aperte em `Criar`

### Criar da EC2

Para montar a EC2, de início, recomenda-se a criação a mão de uma instancia, para testes e assim poder montar o seu `user_data.yaml`. Vá para o menu EC2 e clique em Executar Instância

Os parâmetros são:

##### Nomes e Tags;

*Name*
*Valor*: `Fornecido pela Compass`
*Tipos de Recurso*: `Instâncias e Volumes`


*CostCenter*
*Valor*: `Fornecido pela Compass`
*Tipos de Recurso*: `Instâncias e Volumes`

*Project*
*Valor*: `Fornecido pela Compass`
*Tipos de Recurso*: `Instâncias e Volumes`

A imagem que usei foi a Ubuntu Server que estava neste momento na versão 24.04 LTS
O tipo de instância usada foi T2.micro

Criei uma Key pair usando ED25519 versão `.pem` 

A rede, use a VPC que criamos anteriormente, selecione a Subnet pública e o SG que criamos anteriormente

Seu armazenamento use: 8GB gp2


Após a criação, use o seguinte comando via SSH no terminal para acessar a sua instância, usando o IPV4 público, ou o DNS público.

```
sudo chmod 400 chavePub.pem
ssh -i chavePub.pem ubuntu@cole-o-ip-aqui
```

Dica Importante!
deve-se estar no diretório da chave para que o comando funcione. Ou seja, se o arquivo `chave.pem` estiver na sua pasta de Downloads, por exemplo, inicie o terminal dentro desta página.

Assim que acessar a máquina, use os comandos para instalar o Docker  e liberar acesso direto ao usuário, após isso, reinicie a instancia para que as permições sejam aplicadas, ou use `newgrp docker`

```
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

```

#### Montando o EFS na instância

Com o Docker instalado e Rodando, monta-se o EFS na máquina, para isso use o comando abaixo para instalar onfs-common (como usamos a imagem do Ubuntu).
Para a montagem, existem dois modos, via DNS e IP, eu escolhi a opçãop IP
Neste comando, também criamos o diretório efs, pelo código: `sudo mkdir /efs`


```
#Instala o nfs-common e monta o efs no sistema
sudo apt-get -y install nfs-common
sudo mkdir /efs
sudo mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport 10.0.0.49:/ /efs
sudo chmod 666 /etc/fstab
sudo echo "10.0.0.49:/     /efs      nfs4      nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport,_netdev      0      0" >> /etc/fstab
```

#### Docker Compose
Para agregar as informações necessárias e assim fazer o contêiner subir na instância, precisa-se criar um comando para  que o WordPress possa alocar os arquivos em um volume, que no caso é o nosso EFS, e os dados de acesso salvos dentro do BD que é o nosso RDS.
Neste arquivo indicamos as variáveis para comunicação entre eles.

Para criar, use o Vim ou o Nano. (aqui eu usei o Vim)

`sudo vi docker-compose.yaml`

```
version: '3.8'
services:
  wordpress:
    image: wordpress
    restart: always
    ports:
      - "80:80"
    environment:
      WORDPRESS_DB_HOST: O Endpoint do seu RDS
      WORDPRESS_DB_USER: (o nome de úsuário usado na criação do BD)
      WORDPRESS_DB_PASSWORD: (senha usada na criação)
      WORDPRESS_DB_NAME: (nome escolhido na criação)
    volumes:
      - /efs/wordpress:/var/www/html

```
Após a criação, use o comando para executar:

```
docker-compose -f docker-compose.yaml up -d
```


#### Arquivo `user_data.sh`

##### Passo a Passo
* Crie um arquivo `user_data.sh`: Esse script será executado automaticamente durante a inicialização da instância EC2.

* Adicione o código abaixo ao seu `user_data.sh`:


```
#! /bin/bash

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

#Instala o nfs-common e monta o efs no sistema
sudo apt-get -y install nfs-common
sudo mkdir /efs
sudo mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport 10.0.0.49:/ /efs
sudo chmod 666 /etc/fstab
sudo echo "10.0.0.49:/     /efs      nfs4      nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport,_netdev      0      0" >> /etc/fstab

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
      WORDPRESS_DB_HOST: O Endpoint do seu RDS
      WORDPRESS_DB_USER: (o nome de úsuário usado na criação do BD)
      WORDPRESS_DB_PASSWORD: (senha usada na criação)
      WORDPRESS_DB_NAME: (nome escolhido na criação)
    volumes:
      - /efs/wordpress:/var/www/html
EOF
```


#### Modelo e Execução (LaunchTemplate)

Para criação do Template (ou modelo de Execução) eu usei as mesmas configurações que usamos para criar uma instância [neste passo a passo aqui](#criar-da-ec2), com a ajuda deste [link](https://docs.aws.amazon.com/pt_br/AWSEC2/latest/UserGuide/create-launch-template.html).
