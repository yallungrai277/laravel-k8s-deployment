### Deployment guides to kubernetes, using minikube here.

This is a a minikube deployment for this app. `https://github.com/yallungrai277/laravel-k8s`. Install minikube first and proceed. You may need to increase cpus and limit by doing `minikube start --cpus=8 --memory=8192` to avoid cpu limit errors assigned to minikube , if the cluster is not setup already, otherwise you may need to stop minikube, delete cluster and then proceed with this command `minikube stop && minikube delete && minikube start --cpus=8 --memory=8192`

## Instructions

This deployment assumes that you are running from current root. Note to debug you can visit the logs via `kubectl logs [podname]` or even better
view the events logged by pod, pvc etc using `kubectl describe [pod or pvc or deployment etc...] [name] --namespace=[namespace]`

1. First create a namespace `kubectl create ns laravel-k8s-prod` can be anything, just that the yaml files explicity defines namespace thatswhy we need it. Can also be done in namepsace.
2. Switch to namespace `kubectl config set-context --current --namespace=laravel-k8s-prod`. You may also use different context than current, by simply creating a new context, switch to that context and then run this cmd. You can view the context / namespace using `kubectl config get-contexts`.
3. Verify that you are in the namespace by running `kubectl get pods`, it should show the namespace name.
4. Apply secrets `kubectl apply -f ./secrets/app-secrets.yml` && `kubectl apply -f ./secrets/ghcr-secrets.yml`
5. Apply config maps `kubectl apply -f config-maps/app-config-map.yml`
6. Apply db pv and pvc `kubectl apply -f persistent-volume/mysql-pv.yml`
7. Start mysql `kubectl apply -f stateful-sets/mysql.yml`
8. Apply redis pv and pvc `kubectl apply -f persistent-volume/redis-pv.yml`
9. Start redis `kubectl apply -f stateful-sets/redis.yml`
10. Apply app volume `kubectl apply -f persistent-volume/app-pv.yml`

```
Note since `deployments/app.yml` has dependencies to redis and mysql, it is best to check and wait before running
the below commands, since it will cause errors if the dependencies are being pulled for the first time such as connection errors resulting in log file could not be appended errors.
```

11. Apply deployment `kubectl apply -f deployments/app.yml`
12. Apply worker `kubectl apply -f deployments/worker.yml`
13. Apply cron `kubectl apply -f cron/cron.yml`

Or one liner: `chmod +x ./build.sh && ./build.sh`. Please also see notes on the script.

# Accessing app for minikube test purposes via nodeport

1. Get the url for the app `minikube service app-service --namespace=laravel-k8s-prod --url=true` or `kubectl port-forward service/[nginx_web_server_service_name] 8080:80` if not on minikube.

Note: App should be running.

# Accessing app via load balancer

You can also access app via loadbalancer service. Above step is using nodeport, below is using load balancer. Though load balancer is standarad
to expose service to internet, minikube does not directly open up port, hence we need additional command, but any legit k8s cluster or cloud cluster
will automatically expose the specified port on k8s. Not recommended, approach though recommended approach is to use ingress.

1. Apply load balancer for local testing `kubectl apply -f loadbalancer/load-balancer.yml`.
2. `minikube service app-loadbalancer --namespace=laravel-k8s-prod`

Note: App should be running.

# Accessing app via ingress

You must have an Ingress controller to satisfy an Ingress. Only creating an Ingress resource has no effect. We are using ingress nginx controller here.

1. First delete the load balancer `kubectl delete service app-loadbalancer` if configured.
2. Enable nginx ingress controller on minikube `minikube addons enable ingress`. If you are running k8s outside of minikube then you need to install the nginx ingress controller manually.
3. Verify ingress controller is running in ingress-nginx namespace `kubectl get pods -n ingress-nginx`
4. Get the minikube ip by running `minikube ip` and add it to `/etc/hosts` file with the host name like this: `_minikube_ laravel-k8s.test`. You can also add other hostname if you like but it should match with the host name defined in `loadbalancer/ingress.yml`
5. Now apply ingress `kubectl apply -f loadbalancer/ingress.yml`. App should be available under host name `laravel-k8s.test`.

Note: App should be running.

# Autoscale using inbuilt metrics

1. First enable metrics server on minikube `minikube addons enable metrics-server`. Please note that enabling metrics server may take some time so, you need to check whethe metric server container is running or not continously by `kubectl get pods -n kube-system` on kube-system namespace.
2. Check metrics server working by running `kubectl top pods` which will show the cpu usage of deployments and other resources
3. Now apply the `HPA (Horizontal Pod AutoScaler)` `kubectl apply -f autoscale/app-autoscale-cpu.yml`.
4. Check properly configured `kubectl get hpa`. The section should have targets set like `0%/20%`. You can also see events `kubectl describe hpa app-hpa-cpu`.
5. Now, install a load testing tool such as `seige` or `hey` using homebrew if on mac or any other tool for other OS.
6. Send many concurrent requests in order to try and break the system while simulatenously running `kubectl get pods --watch` and `kubectl get hpa` (If using hey just do `hey -n 1000 http://laravel-k8s.test`). The pods and deployment should increase in real time after some time. This is because we exceeded the cpu usage in hpa hence, triggering the HPA to autoscale.

Note: App should be running.

# Autoscale using custom metrics

We can obviously scale using k8s default out of the box metrics like cpu, ram usage etc..., But here we would want to autoscale based off custom metrics. Now in order to autoscale or perform other required operations based on custom metrics we should be able to provide that to k8s cluster HPA (HorizontalPodAutoscaler) and it should be understandable by it. The way we do this is
via Prometheus. Now prometheus is an open-source monitoring and alerting toolkit designed especially for microservices and containers. Prometheus monitoring lets you run flexible queries and configure real-time notifications such as alert manager etc...

Now, prometheus scraps or gets metrics out of the container/app by sending requests to `/metrics` endpoint. Mind you that this data should be understandable by prometheus itself. Many containers or services by default expose this endpoint with proemtheus understandable metrics data. But not every containers export these metrics. For instance if you want mysql, redis, mongo-db to expose metrics, there is no native `/metrics` endpoint and hence, prometheus cannot scrap metrics out of it. This is where exporter comes into play. Exporter is basically a deployment that pulls out metrics from required containers and converts them to prometheus understandable metrics and then exposes those metrics to proemtheus at `/metrics` endpoint which can then be scraped by promethues. In theory, in order to do that or create a exporter we would have to create a seperate deployment for exporter, create a service for that and then create a custom `CRD (Custom Resource Definition)` called Service monitor. But that has all been done previously and instead we can use a helm chart for that and just override any values we need based on our own manifests file. Note that before all of that we need to install prometheus then only exporters.

We can install prometheus via helm charts.

(Base prometheus community helm chart.)[https://github.com/prometheus-community/helm-charts] (All charts are available here)
(Kube prometheus stacj)[https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack]. Installs graffana, prometheus-operator and everything needed for prometheus stack. Using this monitoring stack is configured where worker nodes, k8s components are monitored out of the box for the k8s configuration of your cluster. These configuration are coming from configmaps and secrets. CRD (Custom resource definition) are also created.

But today we will be doing that via `linkerd` which is a service mesh. A service mesh is a software layer that handles all communication between services in applications. This layer is composed of containerized microservices. Now, how this works is instead of adding exporters as mentioned above, we add a additional sidecar/helper container on our app deployment that is capable of proxying requests made in and out of the container and also expose custom metrics data from the desired container to prometheus. Note that, we should expose our app `/metrics` endpoint data to prometheus understandable format. And all of this is done via linkerd which is easy to do.

<!-- Note that the goal here is to autoscale laravel app via response time. We take advantage of the metrics exposed by the NGINX Ingress Controller because we cannot
directly consume it unlike the default metrics provided by k8s such as cpu / memory usage. Hence, the metrics exposed by NGINX Ingress Controller are scraped by Prometheus and parsed via Prometheus Adapter. -->

Install linked.

1. [https://linkerd.io/2.15/getting-started/] (May take a while to install, please note that all linkerd components are installed in linked namespace)
2. Now inject proxy to a deployment [https://linkerd.io/2.15/features/proxy-injection/] using command `kubectl get deployment app-deployment -o yaml | linkerd inject - | kubectl apply -f -`
3.

# Todo

-   Research and know about best practices for storing k8s yaml config/manifests for different environments (staging, dev, prod) focusing on reusability.
-   Scale out pods to more than one and test it out if it works, and worker jobs, scheduler jobs does not run multiple times.
-   Scale out redis and mysql to more than one.
-   Research on multi nodes cluster.
-   Zero down time deployment, Highy available deployment /autoscaling
-   SSl certificates
-   Add a script for this minikube instructions process
