#!/bin/bash

minikube start
kubectl apply -f backend-service.yaml
kubectl apply -f frontend-service.yaml
kubectl apply -f backend-deployment.yaml
kubectl apply -f frontend-deployment.yaml
kubectl apply -f ingress.yaml

echo "waiting for K8s resources to stabilize.."
sleep 15
"Connecting to frontend!"
minikube service frontend
