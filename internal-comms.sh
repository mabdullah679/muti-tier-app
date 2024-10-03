#!/bin/bash

echo "Executing internal communication test.."

kubectl exec -it $(kubectl get pods -l app=frontend -o jsonpath="{.items[0].metadata.name}") -- curl http://backend:3001/api/endpoint
