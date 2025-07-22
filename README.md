# ansible-docker-deploy
This repository contains an Ansible playbook for Docker installation and deployment.
# Automated Container Deployment

A DevOps automation project that uses Ansible to deploy Apache web server containers with custom Docker networking configuration.

## 🎯 Project Purpose

This project demonstrates infrastructure as code principles by automating the deployment of an Apache HTTP server running in a Docker container. The solution uses Ansible for orchestration and creates a custom Docker network with specific subnet configuration.

## 🛠️ Technologies Used

- **Ansible**: Automation and orchestration platform
- **Docker**: Containerization platform
- **Apache HTTP Server**: Web server (httpd:latest image)
- **Python**: Required for Ansible Docker modules
- **Git**: Version control

## 📋 Prerequisites

Before running this playbook, ensure you have the following installed on your target machine:

### System Requirements
- Linux-based operating system (Ubuntu 18.04+, CentOS 7+, etc.)
- Python 3.6 or higher
- Git

### Required Software Installation

1. **Install Docker**:
   ```bash
   # Ubuntu/Debian
   sudo apt update
   sudo apt install docker.io docker-compose
   sudo systemctl start docker
   sudo systemctl enable docker
   sudo usermod -aG docker $USER
   
   # CentOS/RHEL
   sudo yum install docker
   sudo systemctl start docker
   sudo systemctl enable docker
   sudo usermod -aG docker $USER
   ```

2. **Install Python and pip**:
   ```bash
   # Ubuntu/Debian
   sudo apt install python3 python3-pip
   
   # CentOS/RHEL
   sudo yum install python3 python3-pip
   ```

3. **Install Ansible and Docker SDK**:
   ```bash
   python3 -m pip install --upgrade pip
   pip install ansible docker
   ```

4. **Verify installations**:
   ```bash
   ansible --version
   docker --version
   python3 --version
   ```

## 🚀 Quick Start

### 1. Clone the Repository
```bash
git clone https://github.com/yourusername/automated-container-deployment.git
cd automated-container-deployment
