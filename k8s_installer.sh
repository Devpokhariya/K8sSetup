##################################################################### #
#   All contents including (but not limited to) all written materials,#
# photos,  documentation and code belongs to Dev pokhariya            #
# please write email on pokhriya.dev@gmail.com to get this automation.#
##################################################################### #
#!/bin/bash
EXIT_STATUS=$?
#Update The System
APPS="apt-transport-https ca-certificates curl gnupg-agent software-properties-common"
DOCKER_PACKAGES="docker-ce-3:20.10.9-3.el8 docker-ce-cli-1:20.10.8-3.el8 containerd.io"
DOCKER_REPO_URL="https://download.docker.com/linux/ubuntu/gpg"
SETUP_TYPE=$1
CNI_VERSION="v0.8.2"
ARCH="amd64"
RELEASE="$(curl -sSL https://dl.k8s.io/release/stable.txt)"
CRICTL_VERSION="v1.22.0"
DOWNLOAD_DIR=/usr/local/bin
RELEASE_VERSION="v0.4.0"
OS_TYPE=""


CURRENT_USER=`id -u -nr`
echo "you are : 👉 " $CURRENT_USER
function checkOsType(){
  which yum
  if [ $EXIT_STATUS -ne 0 ]; then
    echo "Not a centos system"
    OS_TYPE="debian"
  else
    echo "Centos/Redhat Based system found"
    OS_TYPE="centos"
  fi 
}
function configureIptable(){
  cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
br_netfilter
EOF

cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sudo sysctl --system
}

function upDate_System(){
  
  if [[ $OS_TYPE == "debian" ]]
  then
  echo "not update"
    sudo apt-get update
     sudo export PATH=$PATH:/usr/local/bin/
  elif [[ $OS_TYPE == "centos" ]]
  then
    echo "update vro"
    sudo yum update -y
    yum install conntrack -y
    sudo  export PATH=$PATH:/usr/local/bin/
  fi
}
function getK8PackageArray(){

  if [[ $OS_TYPE == "debian" ]]
  then
  K8_PACKAGES="kubelet=1.20.1-00 kubeadm=1.20.1-00 kubectl=1.20.1-00"
  elif [[ $OS_TYPE == "centos" ]]
  then
  K8_PACKAGES="kubelet-1.20.1-0 kubeadm-1.20.1-0 kubectl-1.20.1-0"
  fi
  return $K8_PACKAGES
}

function install_Package(){
  if [[ $OS_TYPE == "debian" ]]
  then
      sudo apt-get install -y  $@
  elif [[ $OS_TYPE == "centos" ]]
  then
      sudo yum install -y  $@
  fi
}

#On each node, add the Docker repository
function add_docker_Repository(){
   if [[ $OS_TYPE == "debian" ]]
  then
      curl -fsSL  $DOCKER_REPO_URL | sudo apt-key add -
        sudo add-apt-repository \
      "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) \
      stable"
      sudo apt-get install -y $APPS
  elif [[ $OS_TYPE == "centos" ]]
  then
      sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
  fi
}

function post_docker_setup(){
#DisableSwapOFF
sudo swapoff -a
echo "swap done"
#Disable swap on startup in /etc/fstab
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
echo "fstab done"
sudo usermod -aG docker $1 
echo "usermod added"
# newgrp docker
echo "new grp"
sudo systemctl start docker.service
echo "seriv e restated"
}

function addK8sRepo(){
   if [[ $OS_TYPE == "debian" ]]
  then
   #Download and add GPG key
      curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -

    #Add Kubernetes to repository list
    cat <<EOF | sudo tee /etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF
elif [[ $OS_TYPE == "centos" ]]
  then
  cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-\$basearch
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
exclude=kubelet kubeadm kubectl
EOF
sudo setenforce 0
sudo sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config
fi
}

function serviceEnable(){
  sudo systemctl enable --now kubelet
}

function createKubeConfig(){
#-------Initialize the Cluster---------

cat <<EOF | sudo tee kubeadm-config.yml
# kubeadm-config.yaml
kind: ClusterConfiguration
apiVersion: kubeadm.k8s.io/v1beta3
kubernetesVersion: v1.20.0
---
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
cgroupDriver: systemd
EOF
#On the control plane node, initialize the cluster
sudo kubeadm init --config kubeadm-config.yml

#On the control plane node, set up kubectl access
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

#On the control plane node, install the Calico network add-on
kubectl apply -f https://docs.projectcalico.org/v3.14/manifests/calico.yaml
}

function cmd_For_Worker(){
worker=$(kubeadm token create --print-join-command)
echo "\n################################################################"
echo "\n"
echo "Run this Command On Worker Node 👇 \n $worker"
echo "\n"
echo "\n################################################################"
}
function main(){
echo "⌛  Updating System ..."
upDate_System
  if [ $EXIT_STATUS -ne 0 ]; then
    echo "Error Occured while running command !!"
  else
    add_docker_Repository
    echo "🐟  Installing  docker ..."
    if [ $EXIT_STATUS -ne 0 ]; then
      echo "Error Occured while running command !!"
    else
      install_Package $DOCKER_PACKAGES
      echo "🐟  Docker Installed Successfully"
      if [ $EXIT_STATUS -ne 0 ]; then
        echo "Error Occured while running command !!"
      else
        echo "here"
        post_docker_setup $CURRENT_USER
        echo $EXIT_STATUS
        echo "✅  Docker setup"
        # if [ $EXIT_STATUS -ne 0 ]; then
        #   echo "Error Occured while running command !!"
        # else
        #   installCNIPlugin $APPS
        #   echo "✅  CNI configured"
        #   if [ $EXIT_STATUS -ne 0 ]; then
        #     echo "Error Occured while running command !!"
        #   else
        #     setDownloadDir
        #     if [ $EXIT_STATUS -ne 0 ]; then
        #       echo "Error Occured while running command !!"
        #     else
        #       installCRI
        #       if [ $EXIT_STATUS -ne 0 ]; then
        #         echo "Error Occured while running command !!"
        #       else
                pck=$(getK8PackageArray)
                echo" $pck"
                install_Package $pck
                if [ $EXIT_STATUS -ne 0 ]; then
                  echo "Error Occured while running command !!"
                else
                  serviceEnable 
                  # if [ $EXIT_STATUS -ne 0 ]; then
                  #   echo "Error Occured while running command !!"
                  # else
                  #   setSelinuxCentos
                    if [ $EXIT_STATUS -ne 0 ]; then
                      echo "Error Occured while running command !!"
                    else
                        createKubeConfig
                        exit $EXIT_STATUS
                    fi 
                    exit $EXIT_STATUS
                fi
                exit $EXIT_STATUS
              # fi
              # exit $EXIT_STATUS
      #       fi
      #       exit $EXIT_STATUS
      #     fi
      #     exit $EXIT_STATUS
      #   fi    
      #   exit $EXIT_STATUS
      # fi    
      #   exit $EXIT_STATUS
    fi    
    exit $EXIT_STATUS
  fi    
    exit $EXIT_STATUS
fi
exit $EXIT_STATUS

}

checkOsType 
main

# if [[ SETUP_TYPE == "master" ]];
#   cmd_For_Worker
# fi