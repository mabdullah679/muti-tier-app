MUTI-TIER-APP (plain version)

What it is
A small website with two parts: a front page (React, served by Nginx) and a back-end service (Node). They run on Kubernetes on Amazon's EKS service. A traffic router (Nginx ingress) sends page requests to the front page and anything starting with /api to the back-end. Prometheus collects numbers from the back-end and Grafana draws them. Everything is built and deployed automatically by GitHub Actions and Terraform, without any stored Amazon passwords.

How to try it on your own computer
1. In the backend folder run: npm ci, then npm start.
2. In the frontend folder run: npm ci, then npm start.
3. Open http://localhost:3000.

How it gets to Amazon
Pushing to the prod-hardening branch makes GitHub Actions check the code, run the tests, plan the infrastructure, build it, push the container images to Amazon's image store, put the app on the cluster, and then test the public address. A one-time setup (terraform/bootstrap) creates the place where Terraform remembers its work and the role GitHub uses to log in.

What was done
- The back-end got input checks, health and readiness endpoints, JSON logs, security headers, metrics, graceful shutdown, and 13 tests.
- The front-end got a real page that shows back-end status and a greeting form, and 4 tests.
- Both container images now run as non-root users.
- Kubernetes files got health probes, memory limits, two copies of each service, and disruption protection.
- Terraform builds the network, the cluster, the image stores and the monitoring.
- The old Minikube scripts were turned into scripts that work with the cluster on Amazon.

What was proven on 20 October 2026
The pipeline went green and the site answered through the public load balancer address: the front page loaded, the API answered, the greeting form worked and bad input was refused. Two different back-end copies answered. Prometheus was collecting numbers from both back-end copies, and Grafana had the dashboard and could read the numbers.

What went wrong along the way and how it was fixed
- The first deploy failed because the login token for the cluster expired during the long cluster build. Fixed by fetching a fresh token each time it is needed.
- The Amazon account refuses to create the newer kinds of load balancer. Fixed by using the older Classic load balancer, which is allowed.
- The monitoring operator waited for a certificate that was switched off. Fixed by switching off its certificate requirement.

What was not proven
- The Grafana dashboard was checked through its API but not viewed in a browser.
- The browser check of the website went through a port-forward, because the test browser could not open the load balancer address. A command-line check did reach the real address.
- Prices are estimates, about 26 cents an hour while running.

Cost and cleanup
On 20 October 2026, right after checking, everything was taken down to save money. Direct lookups afterwards found no cluster, load balancer, disk, image store, storage bucket, role, network or log group left for this project, and the tagging service showed zero tagged items (it can lag a little). The shared login provider and shared permission limit policy were not touched.
To rebuild: run terraform -chdir=terraform/bootstrap apply -auto-approve once (the one-time setup was also removed), then gh workflow run ci-cd-pipeline.yml --ref prod-hardening. It takes about 25 minutes.
To take it down again: scripts/destroy.sh, then terraform -chdir=terraform/bootstrap destroy.
