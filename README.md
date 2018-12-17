# What

This will provision one or more Kubernetes clusters, along with Portworx, on an AWS VPC.

# How

1. Install [Vagrant](https://www.vagrantup.com/downloads.html).

2. Ensure you have Node.js installed, and install the json module:
```
# npm install -g json
```

3. Install the AWS plugin for Vagrant:
```
$ vagrant plug install vagrant-aws
```

4. Clone this repo and cd to it.

5. Edit `Vagrantfile` as necessary.

6. Generate SSH keys:
```
$ ssh-keygen -t rsa -b 2048 -f id_rsa
```
This will allow SSH as root between the various nodes.

7. Create the necessary VPC infrastructure:
```
$ . create-vpc.sh
```

8. Start the cluster(s):
```
$ vagrant up
```

9. Check the status of the Portworx cluster(s):
```
$ vagrant ssh node-1-1
[centos@node-1-1 ~]$ sudo /opt/pwx/bin/pxctl status
$ vagrant ssh node-2-1
[centos@node-1-1 ~]$ sudo /opt/pwx/bin/pxctl status
```

10. Browse to port 32678 of one of the nodes. Add the cluster(s) to the Lighthouse instance.
