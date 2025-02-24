# Customer PSP Migration

As part of upgrading k8s clusters to 1.25 or Higher, the Customer needed to migrate their Security Policies from PSPs to PSAs (Non Mutating) and then to OPA Constraints (Mutating). This document presents a solution tested during the week of 04/14/2024.
- We know we have to address API deprecation. our migation tool has built-in features and we were going to leverage Helm remap-api plugin 
- Customer is heavy user of PSP, deprecated in 1.25. We had to use PSA non-mutation, validation and OPA mutation Policies 

## Problem description

A PSP (psp-Customer.yaml) is used across the board to set the minimal security requirements for a compliant cluster following Customer Infosec recommendations.

As PSPs get removed from the Kubernetes API in v1.25, the Fin-tech Customer needs to remove the PSPs in place.

## Solution

### Namespace labeling

To address the cluster's overall security, we will rely on Pod Security Standards enforced to namespaces labeling.

```sh
kubectl label --overwrite ns --all pod-security.kubernetes.io/enforce=retricted
```

For the namespaces where any privileged configuration is required, such as NFS volume mounting, we will label the namespace as `privileged` and rely on OPA constrains to enforce policies in those namespaces.

```sh
kubectl label --overwrite ns a-privileged-ns pod-security.kubernetes.io/enforce=privileged
```

### OPA Gatekeeper setup

1. Install the Gatekeeper using Helm:

```sh
helm repo add gatekeeper https://open-policy-agent.github.io/gatekeeper/charts

helm install -n gatekeeper-system my-gatekeeper gatekeeper/gatekeeper --create-namespace                                         

NAME: my-gatekeeper
LAST DEPLOYED: Thu Apr 18 14:50:48 2024
NAMESPACE: gatekeeper-system
STATUS: deployed
REVISION: 1
TEST SUITE: None
```

2. Install Contrains Templates from the Gatekeeper Library

```sh
git clone https://github.com/open-policy-agent/gatekeeper-library.git

kustomize build library | k apply -f-
```

### Create OPA Constrains

We used [psp-migration](https://github.com/appvia/psp-migration/) tool to translate the PSP to OPA constrains and the result is in `opa-Customer.yaml`

```sh
kubectl apply -f opa-Customer.yaml
```

### Test

```sh
k apply -f red-test-pod.yaml -n privileged-ns
Error from server (Forbidden): error when creating "red-test-pod.yaml": admission webhook "validation.gatekeeper.sh" denied the request: [psp-k8spspallowedusers-2e627] Container nginx is attempting to run with disallowed supplementalGroups [4000]. Allowed supplementalGroups: {"ranges": [{"max": 65535, "min": 10000}], "rule": "MustRunAs"}
[psp-k8spspallowprivilegeescalationcontainer-13d09] Privilege escalation container is not allowed: nginx

k apply -f red-test-pod.yaml -n restrict-ns
Error from server (Forbidden): error when creating "red-test-pod.yaml": admission webhook "validation.gatekeeper.sh" denied the request: [psp-k8spspallowedusers-2e627] Container nginx is attempting to run with disallowed supplementalGroups [4000]. Allowed supplementalGroups: {"ranges": [{"max": 65535, "min": 10000}], "rule": "MustRunAs"}
[psp-k8spspallowprivilegeescalationcontainer-13d09] Privilege escalation container is not allowed: nginx

```

```sh
k apply -f green-test-pod.yaml -n privileged-ns
pod/busybox created

```
# Customer PSP Migration Notes

Step 1:

In Uppers you can run this command to confirm the presence of imagepullsecret. If present you can skip next two steps.

kubectl get secrets -A | grep -i image (If secrets don’t exist run below 2 commands)


kubectl get secrets -n epp-cert artifactory-image-pull -o go-template='{{range $k,$v := .data}}{{"### "}}{{$k}}{{"\n"}}{{$v|base64decode}}{{"\n\n"}}{{end}}'

kubectl get secrets -n epp-cert nexus-image-pull -o go-template='{{range $k,$v := .data}}{{"### "}}{{$k}}{{"\n"}}{{$v|base64decode}}{{"\n\n"}}{{end}}'

 
- Rollout imagepullsecrets on workload, operator namespaces with exclusion of system namespaces. We shared the script ot run loops

- Rollout Serivce account patching on on all namespaces to append the imagepullsecrets


Step 2:

- Run dry-run commands to scope out the blast radius for Pod security polices (Grab outputs)

   pspmigrator mutating pods

   pspmigrator migrate -d
   
   
 

Backup

kubectl get psp -A > banksol-cert-epp-jcc-psp.txt

kubectl get pods -A --field-selector=status.phase!=Running > banksol-cert-epp-failing-pods.txt


Step 3:

- Assess the PSA admission scope baseline OR privileged on individual namespaces.

Non-workload namespaces,
kubectl label --overwrite ns --all pod-security.kubernetes.io/enforce=baseline
workload namespaces,
kubectl label --overwrite ns <WORKLOAD_NAMESPACE> pod-security.kubernetes.io/enforce=privileged


Step 4:

workload namespaces need to be set to privileged
Run below script (script_overwrite_privileged-ns.sh)

Validation : kubectl get ns --show-labels >> 


Step 5:

- Scale down falcon-node-cleanup daemonset

kubectl -n falcon-system patch daemonset falcon-sensor-node-cleanup -p '{"spec": {"template": {"spec": {"nodeSelector": {"non-existing": "true"}}}}}'

 Step 6:

- App teams need to update the K8s Api-versions on existing Manifests that might still be hardcoded with Older K8s api versions. https://kubernetes.io/docs/reference/using-api/deprecation-guide/#v1-25


Example, Based on K8s 1.25 deprecation guide, in 1.25 HPA Api version has changed from autoscaling/v2beta1 to autoscaling/v2.

Here's the K8s deprecation guide that list the changes.

https://kubernetes.io/docs/reference/using-api/deprecation-guide/#v1-25

Based on K8s 1.25 deprecation guide, in 1.25 HPA Api version has changed from autoscaling/v2beta1 to autoscaling/v2.

here's the K8s deprecation guide that list the changes.

https://kubernetes.io/docs/reference/using-api/deprecation-guide/#v1-25


*** Run this command to validate prior to upgrading,

kubectl get hpa,pdb,cronjob -A -o wide

- Update the helm manifests and app rollout pipeline manifests accordingly
Using Helm  mapkubeapis Plugin:  https://github.com/helm/helm-mapkubeapis

CronJob >> batch/v1
HPA aka HorizontalPodAutoscaler >> autoscaling/v2
PDB aka PodDisruptionBudget >> policy/v1

- Proceed to upgrade the cluster.

autoscaling/v2beta1 to autoscaling/v2

batch/v1beta1 to batch/v1

policy/v1beta1 to policy/v1


Step 7

Once validation is complete from App team scale up 

kubectl -n falcon-system patch daemonset falcon-sensor-node-cleanup --type json -p='[{"op": "remove", "path": "/spec/template/spec/nodeSelector/non-existing"}]'

-------------------------------------------------------------------
**Best Practices:**

DRY-RUN:

Migration scenarios:
When it comes to applying PSA, there are four scenarios in which users can find themselves: 

- Migrating brand-new workloads directly to PSA. 
- Migrating existing, policy-free workloads that are not under any policy to PSA. 
- Migrating existing workloads with simple PSPs to PSA. 
- Migrating existing workloads with elaborate PSPs to an external admission controller. 

Onboarding of new and policy-free workloads,
Whether you need to stage a brand-new cluster, add a new workload to an existing cluster, or migrate existing clusters or namespaces to PSA, this section will guide you through the process. When applying PSS to a new or existing PSP-free workload, we can use the following commands:

```sh
$ kubectl label ns <namespace name> pod-security.kubernetes.io/enforce=<level> --dry-run=server
```

Note the --dry-run=server flag—this flag enables various checks to be carried out, including authentication and authorization, without applying any changes. If the PSS level is suitable for the namespace workloads, there will be no warnings in the output. Otherwise, kubectl will helpfully print a list of warnings detailing the specific problems:

```sh
$ kubectl label ns default pod-security.kubernetes.io/enforce=restricted --dry-run=server 
Warning: existing pods in namespace "default" violate the new PodSecurity 
enforce level "restricted:latest" 

Warning: andy-dufresne: host namespaces, privileged, allowPrivilegeEscalation 
!= false, unrestricted capabilities, runAsNonRoot != true, seccompProfile 

namespace/default labeled (server dry run)
```

Takeaways:
- What is the current state of security policy adoption?  

Data shows that migration to PSA from PSP has been slow. The worst scenario entails losing Kubernetes users who currently use PSP and stop using any policy after the upgrade to v1.25. 

- What can I do about the transition to PSA/PSS? 

There is more than one way to facilitate migration, but you must start before version 1.25. Hopefully, this guide can serve as a starting point.  

- What should I expect? 

To demonstrate what you should expect when attempting to apply PSS to typical workloads, we have compiled a table specifying which PSS levels are expected:

![image](https://github.com/user-attachments/assets/013d67cc-9ccd-4967-9029-41f34f18082f)

Two patterns emerge: 1) Similar applications can have different PSS levels across CSPs (multi-cloud Kubernetes users should be ready for migration process variation across CSPs), and (2) none of the applications can operate at a restricted level, which after all is rather demanding.
