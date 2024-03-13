#!/bin/sh

kubectl create ns laravel-k8s-prod
kubectl config set-context --current --namespace=laravel-k8s-prod
kubectl apply -f ./secrets/app-secrets.yml
kubectl apply -f ./secrets/ghcr-secrets.yml
kubectl apply -f config-maps/app-config-map.yml
kubectl apply -f persistent-volume/mysql-pv.yml
kubectl apply -f stateful-sets/mysql.yml
# Sleep 120 seconds, image maybe being pulled for the first time.
sleep 120
kubectl apply -f persistent-volume/redis-pv.yml
kubectl apply -f stateful-sets/redis.yml
# Sleep 120 seconds, image maybe being pulled for the first time.
sleep 120
kubectl apply -f persistent-volume/app-pv.yml
# Here in app deployment we are runnning a post deploy script to run migrations and cache
# so, it might show errors while running the app on browser 
# if the dependent mysql and redis service is being pulled for the first time.
# Hence we wait for 120 seconds in above steps.
kubectl apply -f deployments/app.yml
kubectl apply -f deployments/worker.yml
kubectl apply -f cron/cron.yml

# Todo need to write better script, so that `kubectl apply -f deployments/app.yml` only runs if
# it's dependent services such as mysql and redis is up (image has been successfully pulled).