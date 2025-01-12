#!/bin/bash

echo ""
echo "Join: https://t.me/airdrop_node"
read -p "Have you joined t.me/airdrop_node on tele? (y/Y to proceed): " JOINED

if [[ ! "$JOINED" =~ ^[yY]$ ]]; then
    echo ""
    echo "Please join t.me/airdrop_node on tele before proceeding."
    exit 1
fi

# Install Docker
echo -e "${INFO}Installing Docker...${NC}"
sudo apt update
sudo apt install -y docker.io
sudo service docker start
sudo service docker enable
echo -e "${SUCCESS}Docker installed successfully.${NC}"

# Check if the directory exists
if [ -d "network3-docker" ]; then
  echo -e "${INFO}Directory network3-docker already exists.${NC}"
else
  # Create the directory
  mkdir network3-docker
  echo -e "${SUCCESS}Directory network3-docker created.${NC}"
fi

# Navigate into the directory
cd network3-docker

# Retrieve public IP
public_ip=$(curl -s ifconfig.me)
if [ -z "$public_ip" ]; then
  echo -e "${ERROR}Failed to retrieve public IP address. Exiting.${NC}"
  exit 1
fi

# Create or replace the Dockerfile with the specified content
cat <<EOL > Dockerfile
# Use an official Ubuntu as a parent image
FROM ubuntu:latest

# Install wget, ufw, tar, nano, sudo, net-tools, iproute2, and procps
RUN apt-get update && apt-get install -y \\
    wget \\
    ufw \\
    tar \\
    nano \\
    sudo \\
    net-tools \\
    iproute2 \\
    procps

# Download and extract Network3
RUN wget https://network3.io/ubuntu-node-v2.1.0.tar && \\
    tar -xf ubuntu-node-v2.1.0.tar && \\
    rm ubuntu-node-v2.1.0.tar

# Change directory
WORKDIR /ubuntu-node

# Allow custom port for traffic (this will be the dynamically calculated port)
RUN ufw allow $port_number

# Start the node and provide a shell
CMD ["bash", "-c", "bash manager.sh up; bash manager.sh key; exec bash"]
EOL

# Detect existing network3-docker instances and find the highest instance number
existing_instances=$(docker ps -a --filter "name=network3-docker-" --format "{{.Names}}" | grep -Eo 'network3-docker-[0-9]+' | grep -Eo '[0-9]+'$ | sort -n | tail -1)

# Set the instance number
if [ -z "$existing_instances" ]; then
  instance_number=1
else
  instance_number=$((existing_instances + 1))
fi

# Set the container name
container_name="network3-docker-$instance_number"

# Calculate the port number (now avoiding 8080 and using an alternative base port, for example, 8081)
base_port=8081
port_number=$((base_port + instance_number - 1))

# Build the Docker image with the specified name
docker build -t $container_name .

# Check if ufw is installed and add rule for the port number
if command -v ufw > /dev/null; then
  echo -e "${INFO}Configuring UFW to allow traffic on port $port_number...${NC}"
  if ! sudo ufw status | grep -q "$port_number"; then
    sudo ufw allow $port_number
    echo -e "${SUCCESS}UFW configured successfully.${NC}"
  else
    echo -e "${INFO}UFW rule for port $port_number already exists.${NC}"
  fi
fi

# Display the completion message and command to view logs
echo -e "${SUCCESS}The Docker container will be built and will run on port $port_number.${NC}"
echo -e "${INFO}To consult the dashboard, visit:${NC}"
echo -e "${BANNER}https://account.network3.ai/main?o=$public_ip:$port_number${NC}"
echo -e "${INFO}Use the key that will be displayed to link node with your email${NC}"

# Run the Docker container with the necessary privileges and an interactive shell
docker run -it --cap-add=NET_ADMIN --device /dev/net/tun --name $container_name -p $port_number:$port_number $container_name

echo -e "${BOLD_PINK}Join airdrop node t.me/airdrop_node on tele${RESET_COLOR}"
echo
