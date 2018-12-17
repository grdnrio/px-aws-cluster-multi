clusters = 2
nodes = 3
subnet_id = "#{ENV['subnet']}"
security_group_id = "#{ENV['sg']}"
disk_size = 10
ami = "ami-00846a67"
access_key = "***"
secret_key = "***"
keypair_name = "***"
region = "eu-west-2"
type = "t3.medium"

Vagrant.configure("2") do |config|
  config.vm.box = "dummy"
  config.vm.synced_folder ".", "/vagrant", type: "rsync"
  config.vm.provider :aws do |aws, override|
    aws.access_key_id = "#{access_key}"
    aws.secret_access_key = "#{secret_key}"
    aws.security_groups = ["#{security_group_id}"]
    aws.keypair_name = "#{keypair_name}"
    aws.region = "#{region}"
    aws.instance_type = "#{type}"
    aws.ami = "#{ami}"
    aws.subnet_id = "#{subnet_id}"
    aws.associate_public_ip = true
    override.ssh.username = "centos"
    override.ssh.private_key_path = "#{ENV['HOME']}/.ssh/id_rsa"
  end
  config.vm.provision "shell", inline: <<-SHELL
    setenforce 0
    swapoff -a
    sed -i s/SELINUX=enforcing/SELINUX=disabled/g /etc/selinux/config
    sed -i /swap/d /etc/fstab
    sed -i s/enabled=1/enabled=0/ /etc/yum/pluginconf.d/fastestmirror.conf
    cp /vagrant/{sysctl.conf,hosts} /etc
    cp /vagrant/*.repo /etc/yum.repos.d
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
      end
      master.vm.provision "shell", inline: <<-SHELL
        ( hostnamectl set-hostname #{hostname_master}
          yum install -y docker kubeadm
          systemctl start docker
          docker run -p 5000:5000 -d --restart=always --name registry -e REGISTRY_PROXY_REMOTEURL=http://registry-1.docker.io -v /opt/shared/docker_registry_cache:/var/lib/registry registry:2
          echo 'OPTIONS=" --registry-mirror=http://#{hostname_master}:5000"' >>/etc/sysconfig/docker
          systemctl restart docker
          (docker pull portworx/oci-monitor ; docker pull openstorage/stork ; docker pull portworx/px-enterprise:2.0.0.1) &
          kubeadm config images pull &
          sed -i 's/cgroup-driver=systemd/cgroup-driver=cgroupfs/g' /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
          systemctl enable docker kubelet
          systemctl start kubelet
          mkdir /root/.kube
          wait %2
          kubeadm init --apiserver-advertise-address=192.168.99.1#{c}0 --pod-network-cidr=10.244.0.0/16
          cp /etc/kubernetes/admin.conf /root/.kube/config
          kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
          wait %1
          kubectl apply -f 'https://install.portworx.com/2.0?kbver=1.13.1&b=true&s=%2Fdev%2Fnvme1n1&m=ens5&d=ens5&c=px-demo-#{c}&stork=true&st=k8s&lh=true'
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
            yum install -y kubeadm docker
            echo 'OPTIONS=" --registry-mirror=http://#{hostname_master}:5000"' >>/etc/sysconfig/docker
            sed -i s/cgroup-driver=systemd/cgroup-driver=cgroupfs/g /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
            systemctl enable docker kubelet
            systemctl start docker kubelet
            kubeadm config images pull &
            while : ; do
              command=$(ssh -oConnectTimeout=1 -oStrictHostKeyChecking=no #{hostname_master} kubeadm token create --print-join-command)
              [ $? -eq 0 ] && break
              sleep 5
            done
            wait
            eval $command
            echo End
          ) &>/var/log/vagrant.bootstrap &
        SHELL
      end
    end
  end

end

