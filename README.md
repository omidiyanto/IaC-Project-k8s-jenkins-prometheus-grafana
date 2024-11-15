<div align="center">
	<h1> 🌟 Infrastructre as Code (IaC) Project🚀 </h1>
</div>
<div align="center">
    <img src="https://img.shields.io/badge/kubernetes-blue?style=for-the-badge&logo=kubernetes&logoColor=white">
	<img src="https://img.shields.io/badge/docker-white.svg?style=for-the-badge&logo=docker&logoColor=blue">
	<img src="https://img.shields.io/badge/helm chart-navy?style=for-the-badge&logo=helm&logoColor=white">
	<img src="https://img.shields.io/badge/prometheus-orange.svg?style=for-the-badge&logo=trivy&logoColor=white">
	<img src="https://img.shields.io/badge/grafana-grey.svg?style=for-the-badge&logo=trivy&logoColor=white">
    <img src="https://img.shields.io/badge/terraform-%238511FA.svg?style=for-the-badge&logo=terraform&logoColor=white">
    <img src="https://img.shields.io/badge/ansible-%23000.svg?style=for-the-badge&logo=ansible&logoColor=white">
	<img src="https://img.shields.io/badge/jenkins-maroon.svg?style=for-the-badge&logo=jenkins&logoColor=white">
    <img src="https://img.shields.io/badge/proxmox-%23FF6F00.svg?style=for-the-badge&logo=proxmox&logoColor=white">
    <img src="https://img.shields.io/badge/ubuntu-%23D00000.svg?style=for-the-badge&logo=ubuntu&logoColor=white">
</div>
<br>

# System Architecture
<img src="https://github.com/user-attachments/assets/54c1206f-12a1-487f-abf9-65dba12de438"></img>

### Steps

1. **Clone the Repository**:
   ```bash
   git clone https://github.com/omidiyanto/IaC-Project-k8s-jenkins-prometheus-grafana.git
   cd terraform-ansible-kubernetes-proxmox
	```
2. **Rename example.terraform.tfvars to terraform.tfvars**
	```bash
	mv example.terraform.tfvars terraform.tfvars
	```
3. **Edit the content of terraform.tfvars**
	```bash
	vim terraform.tfvars
	```
4. **Fill the Required Variables**
	```bash
	# API proxmox
	proxmox_api_url  ="https://PROXMOX_SERVER:8006/api2/json/"
	proxmox_api_token_id  =  "PROXMOX_API_TOKEN_ID"
	proxmox_api_token_secret  =  "PROXMOX_API_TOKEN_SECRET"

	# cloud-init configuration
	ci_user  =  "YOUR_CLOUD_INIT_USER"
	ci_password  =  "YOUR_CLOUD_INIT_USER_PASSWORD"
	ci_ssh_public_key  =  "~/.ssh/id_rsa.pub"
	ci_ssh_private_key  =  "~/.ssh/id_rsa"
	```
5. **Initialize Pre-required components and provider**
	```bash
	terraform init
	```
6. **Apply or Start Provisioning the Infrastructure and Automatically Create the K8s Cluster**
	```bash
	terraform apply
	```
	Type '**yes**' when prompted to start provisioning !
	Wait until the processed finished. It should not be long, only around 8-15 minutes.

7. **Validate the Cluster**
		Login to the master-node via SSH
	```bash
	ssh ci-user@k8s-master-IP-Address
	```
	
	Validate all nodes are in '**Ready**' state
	```bash
	kubectl get nodes 
	```
	Validate all pods are in '**Running**' state
	```bash
	kubectl get pods -A
	```

8. **Install MetalLB as the Load Balancer and HAproxy as Ingress Controller**
	Clone this repo inside the master node
	```bash
	ssh ci-user@k8s-master-IP-Address
	git clone https://github.com/omidiyanto/IaC-Project-k8s-jenkins-prometheus-grafana.git
	cd IaC-Project-k8s-jenkins-prometheus-grafana
	```
	Install MetalLB by manifest
	```bash
	kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.8/config/manifests/metallb-native.yaml
	```
	Change IP Address Pool range
	```bash
	vim ipaddresspool.yml
	```
	Apply IP Address Pool and L2advertisement
	```bash
	kubectl apply -f ipaddresspool.yml
	kubectl apply -f L2advertisement.yml
	```
	Install HAproxy as Ingress Controller by manifest
	```bash
	kubectl apply -f haproxy-ingress-controller.yml
	```

9. **Configure Cloudflare tunnel for all servers and needs**
10. **Create service-account for Kubernetes**
	<br>
	Create ServiceAccount
	```bash
	kubectl -n default create serviceaccount omidiyanto
	```

	Add Role "Cluster Admin" to ServiceAccount
	```bash
	kubectl create clusterrolebinding kubeconfig-cluster-admin-token --clusterrole=cluster-admin --serviceaccount=default:omidiyanto
	```

	Create Secret and Token for ServiceAccount
	```bash
	vim token-secret-admin.yml
	```
	Fill with this configuration:
	```
	apiVersion: v1
	kind: Secret
	metadata:
	name: kubeconfig-cluster-admin-token
	namespace: default
	annotations:
		kubernetes.io/service-account.name: omidiyanto
	type: kubernetes.io/service-account-token
	```

	Apply the manifest
	```bash
	kubectl apply -f token-secret-admin.yml
	```

	Get the Token
	```bash
	kubectl -n default get secret kubeconfig-cluster-admin-token  -o jsonpath='{.data.token}' | base64 --decode
	```

	Now you can create the kubeconfig to manage k8s cluster using API, this is an example of the kubeconfig file
	```bash
	apiVersion: v1
	clusters:
	- cluster:
		server: https://kubeapi.omidiyanto.my.id
	name: kubernetes
	contexts:
	- context:
		cluster: kubernetes
		user: omidiyanto    #ini sesuaikan dengan nama service account nya tadi
	name: kubernetes-admin@kubernetes
	current-context: kubernetes-admin@kubernetes
	kind: Config
	preferences: {}
	users:
	- name: omidiyanto #ini sesuaikan dengan nama service account nya tadi
	user:
		token: eyJhbGciOiJSUz......
	```

11. **Install node-exporter on all nodes of k8s-cluster using Helm**
	<br>
	Add helm repository
	```bash
	helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
	```

	Install Node Exporter Using Helm
	```bash
	helm install prometheus-node-exporter prometheus-community/prometheus-node-exporter --namespace prometheus-node-exporter --debug --create-namespace
	```

	Validate Node Exporter running on all nodes
	```bash
	kubectl get pods -n prometheus-node-exporter -o wide
	```

12. **Install Prometheus-Metrics Plugin on Jenkins**
13. **Configure /etc/prometheus/prometheus.yml**
	<br>	
	Add scraping configuration, should be similar like this:
	```bash
	- job_name: "prometheus"
		# metrics_path defaults to '/metrics'
		# scheme defaults to 'http'.
		static_configs:
		- targets: ["localhost:9090"]

	- job_name: "node-exporter-monitoring-server"
		static_configs:
		- targets: ["localhost:9100"]

	- job_name: "Jenkins"
		metrics_path: "/prometheus"
		static_configs:
		- targets: ["JENKINS_SERVER_IPADDR_URL"]

	- job_name: "k8s-cluster"
		static_configs:
		- targets: ["IP_MASTER_NODE:9100","IP_WORKER_NODE1:9100","IP_WORKER_NODE2:9100"]
	```

	Then restart prometheus service
	```bash
	systemctl restart prometheus-server.service
	```

14. **Add Grafana Dashboard**
	<br>
	- Add Connections for Prometheus
	- Import Dashbord with ID "1860" and "9964"

## Configure Jenkins Tools
1. Install Plugins
	- Eclipse Temurin
	- SonarQube Scanner
	- Docker
	- Kubernetes
	- NodeJS
	- OWASP Dependency-Check
	- Github integration

2. Configure Jenkins Tools
	- JDK --> jdk17 (Install from adoptium.net : jdk-17.0.8.1+1)
	- Sonarqube Scanner --> sonar-scanner (Install Automatically : latest)
	- NodeJS --> node6 (Install from nodejs.org : nodejs 16.2.0)
	- Dependency-Check --> DP-Check (Install from github.com : latest)
	- Docker --> docker (Install from docker.com : latest)

3. Configure Jenkins Global System
	- Add Sonarqube servers
	- Configure E-Mail Notification
	- Configure Extended E-Mail Notification

4. Run Sonarqube with Docker on Jenkins-Server
	```bash
	docker run -d --name sonar -p 9000:9000 sonarqube:lts-community
	```

5. Install Trivy
	```bash
	sudo apt-get install wget apt-transport-https gnupg lsb-release
	wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo apt-key add -
	echo deb https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main | sudo tee -a /etc/apt/sources.list.d/trivy.list
	sudo apt-get update
	sudo apt-get install trivy        
	```
