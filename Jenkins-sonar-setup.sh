#!/bin/bash

set -e

echo "🔧 Updating packages and installing prerequisites..."
apt-get update
apt-get install -y wget curl unzip net-tools openjdk-17-jdk

JAVA_HOME="/usr/lib/jvm/java-17-openjdk-amd64"
echo "Using JAVA_HOME=$JAVA_HOME"

####### Jenkins #############
 

echo "Stopping Jenkins (if running)..."
systemctl stop jenkins || true

echo "🧹 Purging Jenkins installation (if any)..."
apt-get purge -y jenkins || true
rm -rf /var/lib/jenkins /var/cache/jenkins /usr/share/jenkins /etc/default/jenkins /etc/jenkins /var/log/jenkins
mkdir -p /usr/share/jenkins

echo " Downloading Jenkins WAR..."
wget https://get.jenkins.io/war-stable/2.504.1/jenkins.war -O /usr/share/jenkins/jenkins.war

echo " Creating Jenkins user and setting permissions..."
useradd -r -s /bin/false jenkins || true
mkdir -p /var/lib/jenkins /var/log/jenkins /var/cache/jenkins
chown -R jenkins:jenkins /var/lib/jenkins /var/log/jenkins /var/cache/jenkins /usr/share/jenkins
chmod 644 /usr/share/jenkins/jenkins.war

echo "Creating Jenkins systemd service..."
cat <<EOF > /etc/systemd/system/jenkins.service
[Unit]
Description=Jenkins Continuous Integration Server
After=network.target

[Service]
Type=simple
User=jenkins
Group=jenkins
Environment="JAVA_HOME=$JAVA_HOME"
ExecStart=/usr/bin/java -jar /usr/share/jenkins/jenkins.war --httpPort=8080
SuccessExitStatus=143

[Install]
WantedBy=multi-user.target
EOF

echo " Reloading systemd and enabling Jenkins..."
systemctl daemon-reload
systemctl enable jenkins
systemctl restart jenkins

echo "Jenkins started. Status:"
systemctl status jenkins --no-pager


#######SonarQube#######

set -e

SONAR_VERSION="10.4.1.88267"
SONAR_USER="sonar"
SONAR_GROUP="sonar"
SONAR_DIR="/opt/sonarqube"
SONAR_ZIP="sonarqube-${SONAR_VERSION}.zip"
SONAR_URL="https://binaries.sonarsource.com/Distribution/sonarqube/${SONAR_ZIP}"
SONAR_SERVICE="/etc/systemd/system/sonarqube.service"
SONAR_DB_USER="sonar"
SONAR_DB_PASS="password"
SONAR_DB_NAME="sonarqube"

echo "🔧 Installing dependencies..."
sudo apt update
sudo apt install -y openjdk-17-jdk wget unzip

echo "Creating SonarQube user and group..."
if ! id "$SONAR_USER" &>/dev/null; then
  sudo useradd -r -s /bin/false "$SONAR_USER"
fi

echo "Downloading SonarQube $SONAR_VERSION..."
cd /tmp
wget -q "$SONAR_URL" -O "$SONAR_ZIP" || {
  echo " ERROR: Failed to download SonarQube from $SONAR_URL"
  exit 1
}

echo " Extracting SonarQube..."
sudo unzip -q "$SONAR_ZIP" -d /opt
sudo mv "/opt/sonarqube-${SONAR_VERSION}" "$SONAR_DIR"
sudo chown -R "$SONAR_USER:$SONAR_GROUP" "$SONAR_DIR"

echo "Configuring sonar.properties..."
SONAR_PROP="$SONAR_DIR/conf/sonar.properties"

sudo sed -i "s|#sonar.jdbc.username=.*|sonar.jdbc.username=$SONAR_DB_USER|" $SONAR_PROP
sudo sed -i "s|#sonar.jdbc.password=.*|sonar.jdbc.password=$SONAR_DB_PASS|" $SONAR_PROP
sudo sed -i "s|#sonar.jdbc.url=jdbc:postgresql.*|sonar.jdbc.url=jdbc:postgresql://localhost/$SONAR_DB_NAME|" $SONAR_PROP

echo "Creating systemd service..."
sudo tee "$SONAR_SERVICE" > /dev/null <<EOF
[Unit]
Description=SonarQube service
After=network.target
[Service]
Type=forking
User=$SONAR_USER
Group=$SONAR_GROUP
ExecStart=$SONAR_DIR/bin/linux-x86-64/sonar.sh start
ExecStop=$SONAR_DIR/bin/linux-x86-64/sonar.sh stop
Restart=always
LimitNOFILE=65536
LimitNPROC=4096
TimeoutStartSec=5

[Install]
WantedBy=multi-user.target
EOF

echo "Reloading systemd and starting SonarQube..."
sudo systemctl daemon-reload
sudo systemctl enable sonarqube
sudo systemctl start sonarqube

echo " SonarQube installation complete."
echo " Access it at: http://<your-server-ip>:9000"
