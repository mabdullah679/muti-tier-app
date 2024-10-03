#!/bin/bash

echo "Deleting Kubernetes resouces.."
kubectl delete deployment backend frontend
kubectl delete service backend frontend
kubectl delete ingress frontend-ingress

echo "Shutdown complete!"

echo "Stopping Minikube.."
minikube stop
