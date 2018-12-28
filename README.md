# What

This will provision one or more Kubernetes clusters, along with Portworx, on an AWS VPC. If there is more than one cluster, ClusterPairs will be configured with the first cluster as the source, and each of the other clusters as the destination.

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

5. Edit `create-vpc.sh` to select AZ. Edit parameters at the top of `Vagrantfile` as necessary.

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

10. Check the status of the ClusterPair(s):
```
$ vagrant ssh master-1
[centos@master-1 ~]$ sudo kubectl get clusterpairs
NAME              AGE
remotecluster-2   8m
```

11. Browse to port 32678 of one of the nodes. Add the cluster(s) to the Lighthouse instance.

12. The Prometheus web UIs can be found on port 30900 on the masters.

13. The Grafana dashboard can be found on port 30950 on the masters.
