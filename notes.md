TKGi - H2o instance 
https://h2o.vmware.com/my-resources/h2o-3-24676
kubectl vsphere login --server=10.214.162.66 --vsphere-username administrator@vsphere.local \
--insecure-skip-tls-verify

kubectl vsphere login --server=10.214.162.66 --vsphere-username administrator@vsphere.local \
--tanzu-kubernetes-cluster-namespace psp-psa \
--insecure-skip-tls-verify

kubectl vsphere login --server=10.214.162.66 --vsphere-username administrator@vsphere.local \
--tanzu-kubernetes-cluster-name tkgi-wl \
--tanzu-kubernetes-cluster-namespace psp-psa \
--insecure-skip-tls-verify

EYlu3NzY6TrT2wGulP$
