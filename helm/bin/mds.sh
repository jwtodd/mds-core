#!/usr/bin/env bash

formulas=("kubernetes-helm" "brew install txn2/tap/kubefwd" "pgsql")
tools=$(dirname ${0})/../tools
istio=1.2.4
os=${MDS_OS:-`uname`}
OSX=Darwin
red=`tput setaf 9`
reset=`tput sgr0`

usage() {
  [ "${1}" ] && warn "${1}"

  cat << EOF
usage: $(basename ${0}) [commands]

commands:
  bootstrap                              : install dependencies; default: (tool-chain), helm, dashboard, istio
  build                                  : build project
  install[:helm,dashboard,istio,mds]     : install specified components; default: all
  test[:unit,integration]                : preform specified tests; default: all
  proxy                                  : port forward to kuberneetes cluster
  forward                                : add host names and port-forwarding for all services
  token[:dashboard]                      : get specified token, copied to copy-paste buffer for osx; default: dashboard
  postgresql                             : create a postgresql console
  uninstall[:mds,istio,dashboard,helm]   : uninstall specified components; default: all
  help                                   : help message
EOF

  [ "${1}" ] && exit 1 || exit 0
}

warn() {
  echo "${red}warn: ${1}${reset}"
}

bootstrap() {
  case "${os}" in
    ${OSX}) brew bundle --file=$(dirname ${0})/Brewfile || usage "brew bundle failed";;
    *) usage "unsupported os: ${os}";;
  esac

  install helm dashboard istio
}

build()  {
  (cd ..; yarn; yarn build; yarn image)
}

installHelm() {
  helm init || usage "helm intialization failure"
  helm repo add stable https://kubernetes-charts.storage.googleapis.com
  helm repo add banzaicloud-stable https://kubernetes-charts.banzaicloud.com
  helm dependency update
  helm plugin install https://github.com/lrills/helm-unittest
}

installDashboard() {
  kubectl apply -f \
    https://raw.githubusercontent.com/kubernetes/dashboard/v1.10.1/src/deploy/recommended/kubernetes-dashboard.yaml
  cat <<EOF | kubectl apply -f - || echo "kubernetes dashboard installation failure"
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin-user
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: admin-user
  namespace: kube-system
EOF
  kubectl port-forward $(kubectl get pods -n=kube-system |
    grep kubernetes-dashboard | cut -d' ' -f1) 8443:8443 -n=kube-system &
}

installIstio() {
  istioPath=${tools}/istio-${istio}

  if [ ! -d ${istioPath} ]; then
    mkdir -p ${tools}
    (cd ${tools}; curl -L https://git.io/getLatestIstio | ISTIO_VERSION=${istio} sh -)
  fi

  export PATH=${istioPath}/bin:${PATH}

  istioctl verify-install || warn "istio verify installation failure"

  [[ $(kubectl get namespace istio-system) ]] || {
    kubectl create namespace istio-system
    helm template ${istioPath}/install/kubernetes/helm/istio-init \
      --name istio-init \
      --namespace istio-system | kubectl apply -f -
  
    # todo: fix
    # [ "$(kubectl -n istio-sytem get crds | grep "istio.io" | wc -l)" -eq "23" ] || \
    #   usage "istio installation failure"
  
    helm template ${istioPath}/install/kubernetes/helm/istio \
      --name istio \
      --namespace istio-system --values \
      ${istioPath}/install/kubernetes/helm/istio/values-istio-demo.yaml | \
      kubectl apply -f -
    kubectl label namespaces default istio-injection=enabled
  }
}

installMds() {
  # todo: don't install if secret exists
  kubectl create secret generic pg-pass --from-literal 'postgresql-password=Password123#'
  helm install --name mds .
}

testUnit() {
  (cd ..; yarn test)
  helm unittest .
}

testIntegration() {
  usage "todo: cypress"
}

proxy() {
  kubectl proxy &
}

forward() {
  sudo kubefwd services -n default
}

tokenDashboard() {
    case "${os}" in
      ${OSX}) kubectl -n kube-system describe secret $(kubectl -n kube-system get secret | \
        grep admin-user | awk '{print $1}') | grep ^token | cut -d: -f2 | tr -d '[:space:]' | \
        pbcopy;;
      *) kubectl -n kube-system describe secret $(kubectl -n kube-system get secret | \
        grep admin-user | awk '{print $1}') | grep ^token | cut -d: -f2 | tr -d '[:space:]';;
    esac
}

postgresql() {
  # note: assumes `kubefwd svc -n default` is running
  pgcli postgres://mdsadmin@mds-postgresql:5432/mds || usage "pgcli failure"
}

uninstallMds() {
  helm delete --purge mds
}

uninstallIstio() {
  istioPath=${tools}/istio-${istio}

  helm template ${istioPath}/install/kubernetes/helm/istio \
  --name istio \
  --namespace istio-system \
  --values ${istioPath}/install/kubernetes/helm/istio/values-istio-demo.yaml | \
    kubectl delete -f -
  kubectl delete namespace istio-system
  kubectl delete -f ${istioPath}/install/kubernetes/helm/istio-init/files
}

uninstallDashboard() {
  usage "not yet implemented: ${0}"
}

uninstallHelm() {
  usage "not yet implemented: ${0}"
}

invoke() {
  for arg in ${2}; do
    ${1}${arg^}
  done
}

[[ $# == 0 ]] && usage

for arg in "$@"; do
  case "${arg}" in
    bootstrap) bootstrap || warn  "${arg} failure";;
    build) build || usage "${arg} failure";;
    install) arg="helm,dashboard,istio,mds";&
    install:*) invoke install "$(echo ${arg} | cut -d ':' -f 2 | tr ',' ' ')";;
    test) arg="unit,integration";&
    test:*) invoke test "$(echo ${arg} | cut -d ':' -f 2 | tr ',' ' ')";;
    proxy) proxy || usage "${arg} failure";;
    forward) forward || usage "${arg} failure";;
    token) arg="dashboard";&
    token:*) invoke token "$(echo ${arg} | cut -d ':' -f 2 | tr ',' ' ')";;
    postgresql|postgres) postgresql || usage "${arfg} failure";;
    uninstall) arg="mds,istio,dashboard,helm";&
    uninstall:*) invoke uninstall "$(echo ${arg} | cut -d ':' -f 2 | tr ',' ' ')";;
    help) usage;;
    *) usage "unknown command: ${arg}"
  esac
done
