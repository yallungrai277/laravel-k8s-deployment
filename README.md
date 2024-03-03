### Deployment guides to kubernetes, using minikube here.

This is a a minikube deployment for this app. `https://github.com/yallungrai277/laravel-k8s`. Install minikube first and proceed.

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
11. Apply deployment `kubectl apply -f deployments/app.yml`
12. Apply worker `kubectl apply -f deployments/worker.yml`
13. Apply cron `kubectl apply -f cron/cron.yml`

# Accessing app for minikube test purposes via nodeport

1. Get the url for the app `minikube service app-service --namespace=laravel-k8s-prod --url=true` or `kubectl port-forward service/[nginx_web_server_service_name] 8080:80` if not on minikube.

Note: Above steps should be configured.

# Accessing app via load balancer

You can also access app via loadbalancer service. Above step is using nodeport, below is using load balancer. Though load balancer is standarad
to expose service to internet, minikube does not directly open up port, hence we need additional command, but any legit k8s cluster or cloud cluster
will automatically expose the specified port on k8s. Not recommended, approach though recommended approach is to use ingress.

1. Apply load balancer for local testing `kubectl apply -f loadbalancer/load-balancer.yml`.
2. `minikube service app-loadbalancer --namespace=laravel-k8s-prod`

Note: Above steps should be configured.

# Accessing app via ingress

You must have an Ingress controller to satisfy an Ingress. Only creating an Ingress resource has no effect. We are using ingress nginx controller here.

1. First delete the load balancer `kubectl delete service app-loadbalancer` if configured.
1. Enable nginx ingress controller on minikube `minikube addons enable ingress`
1. Verify ingress controller is running `kubectl get pods -n ingress-nginx`
1. Get the minikube ip by running `minikube ip` and add it to `/etc/hosts` file with the host name like this: `_minikube_ laravel-k8s.test`. You can also add other hostname if you like but it should match with the host name defined in `loadbalancer/ingress.yml`
1. Now apply ingress `kubectl apply -f loadbalancer/ingress.yml`. App should be available under host name `laravel-k8s.test`.

# Todo

-   Research and know about best practices for storing k8s yaml config/manifests for different environments (staging, dev, prod) focusing on reusability.
-   Scale out pods to more than one and test it out if it works, and worker jobs, scheduler jobs does not run multiple times.
-   Scale out redis and mysql to more than one.
-   Research on multi nodes cluster.
-   Zero down time deployment, Highy available deployment.
