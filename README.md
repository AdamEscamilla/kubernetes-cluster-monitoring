# Kubernetes Cluster Monitoring (POC)

 A bare minimum configuration, suitable for development.
 This builds latest upstream kubernetes and all native components with acception of kubelet, we're using the
 coreos recommended [kubelet-wrapper](https://coreos.com/kubernetes/docs/latest/kubelet-wrapper.html) as CoreOS doesn't ship with socat. This is only required if deploying charts with helm.

### Requirements
 These need to be installed in your local path
- [Terraform](https://www.terraform.io/intro/getting-started/install.html)
- [Kubelet](https://kubernetes.io/docs/tasks/tools/install-kubectl/)
- [Helm](https://github.com/kubernetes/helm/blob/master/docs/install.md)

 You can provide your AWS credentials via environment variables or a [credentials file](http://docs.aws.amazon.com/cli/latest/userguide/cli-config-files.html)

```bash
export AWS_ACCESS_KEY_ID="anaccesskey"
export AWS_SECRET_ACCESS_KEY="asecretkey"
export AWS_DEFAULT_REGION="us-west-2"
```

### Specify ssh keys
 You will need to provide a public key and the path to your private key using either of the methods below

Method #1 Provide details during the deployment

```bash
var.private_key_path
  Enter a value: /home/adam/.ssh/id_rsa
var.public_key
  Enter a value: ssh-rsa AAAAB3NzaC1yc...itHyqMcw== adam@localhost
```

Method #2 Provide details from an environment variables file

```bash
cat terraform.vars
public_key = "ssh-rsa AAAAB3NzaC1yc...itHyqMcw== adam@localhost"
private_key_path = "/home/adam/.ssh/id_rsa"

```

Run ssh-agent so we can use it to tunnel through our bastion host
```bash
eval $(ssh-agent -s)
ssh-add /home/adam/.ssh/id_rsa
ssh-add -l
```

### Run multiple instances of kubectl

go to the project root and run
```bash
make test && make run
```
This will esstablish a new session with your cluster

### Deploy the cluster

```bash
git clone https://github.com/adamescamilla/kubernetes-cluster-monitoring.git
cd kubernetes-cluster-monitoring
make all
```
Done!

This will establish a kubectl session with the cluster, test at the console, try it and result should appear similar
```bash
kubectl cluster-info
> Kubernetes master is running at http://34.228.233.84:8080
> Heapster is running at http://34.228.233.84:8080/api/v1/namespaces/kube-system/services/heapster/proxy
> KubeDNS is running at http://34.228.233.84:8080/api/v1/namespaces/kube-system/services/kube-dns/proxy
> Grafana is running at http://34.228.233.84:8080/api/v1/namespaces/kube-system/services/monitoring-grafana/proxy
> InfluxDB is running at http://34.228.233.84:8080/api/v1/namespaces/kube-system/services/monitoring-influxdb/proxy
```

### Deploy TICK monitoring app

There is a chart available for this (shamelessly borrows)
```bash
git clone https://github.com/jackzampolin/tick-charts.git
cd tick-charts

#initialize helm to deploy tiller into our cluster
helm init
helm install --name data --namespace tick ./influxdb/ 
```
### Test it

Create a utility pod to test our services
```bash
cat > busybox.yaml <<-'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: busybox
  namespace: default
spec:
  containers:
  - image: busybox
    command:
      - sleep
      - "3600"
    imagePullPolicy: IfNotPresent
    name: busybox
  restartPolicy: Always
EOF

kubectl create -f  busybox.yaml

# test DNS resolution, i.e.: nslookup <service>.<namespace>
kubectl exec -it busybox -- nslookup data-influxdb.tick

# test HTTP service (enter localhost followed by two carrage returns)
kubectl exec -it busybox -- telnet data-influxdb.tick 8086
> GET /ping HTTP/1.1
> host: localhost
>
>

```
If that worked, then install the other services
```bash
helm install --name polling --namespace tick ./telegraf-s/
helm install --name hosts --namespace tick ./telegraf-ds/
helm install --name alerts --namespace tick ./kapacitor/
helm install --name dash --namespace tick ./chronograf/
```

### Setup Chronograf dashboard proxy
```bash
# stop proxy with ^C
kubectl port-forward -n tick $(kubectl get pods -n tick -l app=dash-chronograf -o jsonpath='{ .items[0].metadata.name }') 8888
```
Visit in your browser http://localhost:8888/

admin / password

### Cleanup
```bash
helm delete data polling hosts alerts dash --purge
kubectl delete ns tick
make clean
```

## To Do
~~No external dependencies~~ (using external kubelet wrapper, see [issue](https://github.com/coreos/bugs/issues/1114)) and [coreos #NoSocat](https://github.com/kubernetes/kops/issues/1861)
