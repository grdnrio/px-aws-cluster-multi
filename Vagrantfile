# Edit these parameters
clusters = 2
nodes = 3
disk_size = 20
keypair_name = "***"
type = "t3.medium"

# Do not edit below this line
subnet_id = "#{ENV['subnet']}"
security_group_id = "#{ENV['sg']}"
ami = "#{ENV['ami']}"
region = "#{ENV['AWS_DEFAULT_REGION']}"
distro = "#{ENV['distro']}"
usernames = { "centos" => "centos", "ubuntu" => "ubuntu" }

open("hosts", "w") do |f|
  (1..clusters).each do |c|
    f << "192.168.99.1#{c}0 master-#{c}\n"
    (1..nodes).each do |n|
      f << "192.168.99.1#{c}#{n} node-#{c}-#{n}\n"
    end
  end
end

Vagrant.configure("2") do |config|
  config.vm.box = "dummy"
  config.vm.synced_folder ".", "/vagrant", type: "rsync"
  config.vm.provider :aws do |aws, override|
    aws.security_groups = ["#{security_group_id}"]
    aws.keypair_name = "#{keypair_name}"
    aws.region = "#{region}"
    aws.instance_type = "#{type}"
    aws.ami = "#{ami}"
    aws.subnet_id = "#{subnet_id}"
    aws.associate_public_ip = true
    override.ssh.username = usernames["#{distro}"]
    override.ssh.private_key_path = "#{ENV['HOME']}/.ssh/id_rsa"
  end
  config.vm.provision "shell", inline: <<-SHELL
    if [ -f /etc/selinux/config ]; then
      setenforce 0
      sed -i s/SELINUX=enforcing/SELINUX=disabled/g /etc/selinux/config
    fi
    swapoff -a
    sed -i /swap/d /etc/fstab
    cp /vagrant/{sysctl.conf,hosts} /etc
    cp /vagrant/id_rsa /root/.ssh
    cp /vagrant/id_rsa.pub /root/.ssh/authorized_keys
    chmod 600 /root/.ssh/id_rsa
    modprobe br_netfilter
    sysctl -p
  SHELL

  (1..clusters).each do |c|
    hostname_master = "master-#{c}"
    config.vm.define "#{hostname_master}" do |master|
      master.vm.hostname = "#{hostname_master}"
      master.vm.provider :aws do |aws|
        aws.private_ip_address = "192.168.99.1#{c}0"
        aws.tags = { "Name" => "#{hostname_master}" }
        aws.block_device_mapping = [{ "DeviceName" => "/dev/sda1", "Ebs.DeleteOnTermination" => true, "Ebs.VolumeSize" => 20 }]
      end
      master.vm.provision "shell", inline: <<-SHELL
        ( hostnamectl set-hostname #{hostname_master}
          if [ #{distro} == centos ]; then
            sed -i s/enabled=1/enabled=0/ /etc/yum/pluginconf.d/fastestmirror.conf
            cp /vagrant/*.repo /etc/yum.repos.d
            yum install -y kubeadm docker
          elif [ #{distro} == ubuntu ]; then
            curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add
            echo deb http://apt.kubernetes.io/ kubernetes-xenial main >/etc/apt/sources.list.d/kubernetes.list
            apt update -y
            apt install -y docker.io kubeadm
          fi
          yum install -y docker kubeadm git vim
          alias ls='ls -la'
          git clone https://github.com/grdnrio/sa-toolkit.git
          yum install -y docker kubeadm git
          systemctl start docker
          kubeadm config images pull &
          systemctl enable docker kubelet
          systemctl start kubelet
          wait
          kubeadm init --apiserver-advertise-address=192.168.99.1#{c}0 --pod-network-cidr=10.244.0.0/16
          mkdir /root/.kube /home/#{usernames["#{distro}"]}/.kube
          cp /etc/kubernetes/admin.conf /root/.kube/config
          cp /etc/kubernetes/admin.conf /home/#{usernames["#{distro}"]}/.kube/config
          chown -R #{usernames["#{distro}"]} /home/#{usernames["#{distro}"]}/.kube
          kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
          kubectl apply -f 'https://install.portworx.com/2.0?kbver=1.13.1&b=true&m=ens5&d=ens5&c=px-demo-#{c}&stork=true&st=k8s&lh=true'
          kubectl apply -f https://docs.portworx.com/samples/k8s/portworx-pxc-operator.yaml
          kubectl create secret generic alertmanager-portworx -n kube-system --from-file=<(curl -s https://docs.portworx.com/samples/k8s/portworx-pxc-alertmanager.yaml | sed 's/<.*address>/dummy@dummy.com/;s/<.*password>/dummy/;s/<.*port>/localhost:25/')
          while : ; do
            kubectl apply -f https://docs.portworx.com/samples/k8s/prometheus/02-service-monitor.yaml
            [ $? -eq 0 ] && break
          done
          kubectl apply -f https://docs.portworx.com/samples/k8s/prometheus/05-alertmanager-service.yaml
          kubectl apply -f https://docs.portworx.com/samples/k8s/prometheus/06-portworx-rules.yaml
          kubectl apply -f https://docs.portworx.com/samples/k8s/prometheus/07-prometheus.yaml
          mkdir /tmp/grafanaConfigurations
          curl -o /tmp/grafanaConfigurations/Portworx_Volume_template.json -s https://raw.githubusercontent.com/portworx/px-docs/gh-pages/k8s-samples/grafana/dashboards/Portworx_Volume_template.json
          curl -o /tmp/grafanaConfigurations/dashboardConfig.yaml -s https://raw.githubusercontent.com/portworx/px-docs/gh-pages/k8s-samples/grafana/config/dashboardConfig.yaml
          kubectl create configmap grafana-config --from-file=/tmp/grafanaConfigurations -n kube-system
          kubectl apply -f <(curl -s https://docs.portworx.com/samples/k8s/grafana/grafana-deployment.yaml | sed 's/config.yaml/dashboardConfig.yaml/g;/- port: 3000/a\\    nodePort: 30950')
          curl -s http://openstorage-stork.s3-website-us-east-1.amazonaws.com/storkctl/2.0.0/linux/storkctl -o /usr/bin/storkctl
          chmod +x /usr/bin/storkctl
          if [ $(hostname) != master-1 ]; then
            while : ; do
              token=$(ssh -oConnectTimeout=1 -oStrictHostKeyChecking=no node-#{c}-1 pxctl cluster token show | cut -f 3 -d " ")
              echo $token | grep -Eq '.{128}'
              [ $? -eq 0 ] && break
              sleep 5
            done
            storkctl generate clusterpair -n default remotecluster-#{c} | sed '/insert_storage_options_here/c\\    ip: node-#{c}-1\\n    token: '$token >/root/cp.yaml
            cat /root/cp.yaml | ssh -oConnectTimeout=1 -oStrictHostKeyChecking=no master-1 kubectl apply -f -
          fi
          echo End
        ) &>/var/log/vagrant.bootstrap &
      SHELL
    end
    (1..nodes).each do |n|
      config.vm.define "node-#{c}-#{n}" do |node|
        node.vm.hostname = "node-#{c}-#{n}"
        node.vm.provider :aws do |aws|
          aws.private_ip_address = "192.168.99.1#{c}#{n}"
          aws.tags = { "Name" => "node-#{c}-#{n}" }
          aws.block_device_mapping = [{ "DeviceName" => "/dev/sda1", "Ebs.DeleteOnTermination" => true, "Ebs.VolumeSize" => 10 }, { "DeviceName" => "/dev/sdb", "Ebs.DeleteOnTermination" => true, "Ebs.VolumeSize" => disk_size }]
        end
        node.vm.provision "shell", inline: <<-SHELL
          ( hostnamectl set-hostname node-#{c}-#{n}
            if [ #{distro} == centos ]; then
               sed -i s/enabled=1/enabled=0/ /etc/yum/pluginconf.d/fastestmirror.conf
               cp /vagrant/*.repo /etc/yum.repos.d
              yum install -y kubeadm docker
            elif [ #{distro} == ubuntu ]; then
              curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add
              echo deb http://apt.kubernetes.io/ kubernetes-xenial main >/etc/apt/sources.list.d/kubernetes.list
              apt update -y
              apt install -y docker.io kubeadm
            fi
            systemctl enable docker kubelet
            systemctl restart docker kubelet
            kubeadm config images pull &
            (docker pull portworx/oci-monitor:2.0.1 ; docker pull openstorage/stork:2.0.1 ; docker pull portworx/px-enterprise:2.0.1) &
            while : ; do
              command=$(ssh -oConnectTimeout=1 -oStrictHostKeyChecking=no #{hostname_master} kubeadm token create --print-join-command)
              [ $? -eq 0 ] && break
              sleep 5
            done
            wait %1
            eval $command
            echo End
          ) &>/var/log/vagrant.bootstrap &
        SHELL
      end
    end
  end

end

