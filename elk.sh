#!/bin/bash

java_check() {
java -version
if [ $? -ne 0 ]
    then
        # Installing Java 11 if it's not installed
			sudo yum install java-11-openjdk-devel
    # Checking if java installed is less than version 7. If yes, installing Java 11. As logstash & Elasticsearch require Java 7 or later.
    elif [ "`java -version 2> /tmp/version && awk '/version/ { gsub(/"/, "", $NF); print ( $NF < 1.8 ) ? "YES" : "NO" }' /tmp/version`" == "YES" ]
        then
            sudo yum install java-11-openjdk-devel
fi

}

install_elk() {
    # resynchronize the package index files from their sources.
	sudo yum -y update
    # Import elastic GPG key
	sudo rpm --import https://artifacts.elastic.co/GPG-KEY-elasticsearch
	# Acess to elastic oss repo
	cat <<EOF | sudo tee /etc/yum.repos.d/elasticsearch.repo
	[elasticsearch-7.x]
	name=Elasticsearch repository for 7.x packages
	baseurl=https://artifacts.elastic.co/packages/oss-7.x/yum
	gpgcheck=1
	gpgkey=https://artifacts.elastic.co/GPG-KEY-elasticsearch
	enabled=1
	autorefresh=1
	type=rpm-md
EOF
    # Install elasticsearch
	sudo yum install -y elasticsearch-oss
    # install kibana
	sudo yum -y install kibana-oss
	# Install filebear
	sudo yum -y install filebeat
}
configure_elk{    
	#updaet the yamls
	sudo sed -i 's/#network.host: 192.168.0.1/network.host: 0.0.0.0/' /etc/elasticsearch/elasticsearch.yml
    sudo sed -i 's/#server.host: "localhost"/server.host: "0.0.0.0"/' /etc/kibana/kibana.yml
    sudo sed -i 's/#discovery.zen.ping.unicast.hosts: \["host1", "host2"\]/discovery.zen.ping.unicast.hosts: \["elk1:9300", "elk2:9300", "elk3:9300"\]/g' /etc/elasticsearch/elasticsearch.yml
    sudo sed -i 's/#cluster.name: my-application/cluster.name: my-cluster/' /etc/elasticsearch/elasticsearch.yml
    sudo sed -i 's/#node.name: node-1/node.name: '$MY_HOSTNAME'/' /etc/elasticsearch/elasticsearch.yml
    sudo echo 'node.master: true
node.data: true
' | sudo tee -a /etc/elasticsearch/elasticsearch.yml
}
start_elk{
    # Starting The Services
    sudo systemctl restart filebeat
    sudo systemctl enable filebeat
    sudo systemctl restart elasticsearch
    sudo systemctl enable elasticsearch
	check-elastic-health
    sudo systemctl restart kibana
    sudo systemctl enable kibana
	check-kibana-health
}

check-elastic-health() {
ELKSERVER=${1:-localhost}
ELKPORT=${2:-9200}
if [ -z "$ELKSERVER" ]; then
  # Usage
  echo 'Usage: check-health.sh <elk-server=localhost> <elk-port=9200>'
  # create-index.sh "logstash-solr-*" 
else
  curl -s "http://$ELKSERVER:$ELKPORT/_cat/health?v"
fi
}

check-kibana-health() {
KIBANAMODE=${1:-"-b"}
KIBANASERVER=${2:-localhost}
KIBANAPORT=${3:-5601}
if [ -z "$KIBANASERVER" ]; then
  # Usage
  echo 'Usage: check-kibana-status.sh <-b|-f> [<kibana-server=localhost> <kibana-port=5601>]'
else
  if [ "$KIBANAMODE" = "-b" ]; then
    curl -s "http://$KIBANASERVER:$KIBANAPORT/api/status" | jq ".status.overall"
  else
    curl -s "http://$KIBANASERVER:$KIBANAPORT/api/status" | jq ".status.statuses"
  fi
fi
}

java_check()
install_elk()
