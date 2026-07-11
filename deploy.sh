#!/bin/bash

set -e

# Si algo falla, muestra el estado del namespace antes de morir,
# en vez de cortar en seco sin explicar por qué.
on_error() {
  local line="$1"
  echo ""
  echo "===================================="
  echo "❌ Error en la línea ${line}"
  echo "===================================="
  echo "---- Pods en namespace examen ----"
  kubectl get pods -n examen -o wide || true
  echo ""
  echo "---- Últimos eventos ----"
  kubectl get events -n examen --sort-by='.lastTimestamp' 2>/dev/null | tail -n 20 || true
  echo ""
  echo "Tip: revisa 'kubectl describe pod <pod> -n examen' y"
  echo "     'kubectl logs <pod> -n examen' para más detalle."
}
trap 'on_error $LINENO' ERR

REGION="us-east-1"
CLUSTER_NAME="devopseks"

ACCOUNT_ID=$(aws sts get-caller-identity \
  --query Account \
  --output text)

ECR_URL="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"

echo "===================================="
echo "Account ID : ${ACCOUNT_ID}"
echo "Cluster    : ${CLUSTER_NAME}"
echo "Region     : ${REGION}"
echo "ECR URL    : ${ECR_URL}"
echo "===================================="

echo ""
echo "Actualizando kubeconfig..."

aws eks update-kubeconfig \
  --region ${REGION} \
  --name ${CLUSTER_NAME}

echo ""
echo "Instalando Metrics Server..."

kubectl apply -f \
https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml


echo "Configurando manifests Kubernetes..."
find ./k8s -type f -name "*.yaml" \
  -exec sed -i "s|{{ECR_URL}}|${ECR_URL}|g" {} \;


echo ""
echo "Login ECR..."

aws ecr get-login-password \
  --region ${REGION} | \
docker login \
  --username AWS \
  --password-stdin ${ECR_URL}

####################################################
# FRONTEND
####################################################

echo ""
echo "Build Frontend..."

docker build -t examen-frontend ./frontend
docker tag examen-frontend:latest ${ECR_URL}/examen-frontend:eks-v1
docker push ${ECR_URL}/examen-frontend:eks-v1

# Limpiar imagen local y caché
docker rmi -f examen-frontend:latest ${ECR_URL}/examen-frontend:eks-v1 || true
docker builder prune -f

####################################################
# BACKEND - DESPACHOS
####################################################

echo ""
echo "Build Backend Despachos..."

docker build -t examen-backend-despachos ./backend/back-Despachos_SpringBoot

docker tag \
  examen-backend-despachos:latest \
  ${ECR_URL}/examen-backend:despachos-v1

docker push \
  ${ECR_URL}/examen-backend:despachos-v1

# Limpieza
docker rmi -f examen-backend-despachos:latest ${ECR_URL}/examen-backend:despachos-v1 || true
docker builder prune -f

####################################################
# BACKEND - VENTAS
####################################################

echo ""
echo "Build Backend Ventas..."

docker build -t examen-backend-ventas ./backend/back-Ventas_SpringBoot

docker tag \
  examen-backend-ventas:latest \
  ${ECR_URL}/examen-backend:ventas-v1

docker push \
  ${ECR_URL}/examen-backend:ventas-v1

# Limpieza
docker rmi -f examen-backend-ventas:latest ${ECR_URL}/examen-backend:ventas-v1 || true
docker builder prune -f

####################################################
# DB
####################################################

echo ""
echo "Build DB..."

docker build -t examen-db ./db
docker tag examen-db:latest ${ECR_URL}/examen-db:eks-v1
docker push ${ECR_URL}/examen-db:eks-v1

# Limpiar imagen local y caché
docker rmi -f examen-db:latest ${ECR_URL}/examen-db:eks-v1 || true
docker builder prune -f

####################################################
# KUBERNETES
####################################################

echo ""
echo "Desplegando Namespace..."

kubectl apply -f ./k8s/namespace.yaml

####################################################
# MYSQL
####################################################

echo ""
echo "Desplegando MySQL..."

kubectl apply -f ./k8s/mysql-secret.yaml
kubectl apply -f ./k8s/mysql-deployment.yaml
kubectl apply -f ./k8s/mysql-service.yaml

# Como el tag de la imagen es fijo (eks-v1), "kubectl apply" no detecta
# cambios y no dispara un rollout por sí solo. Forzamos el reinicio.
# Si quedó un pod de un intento anterior en CrashLoopBackOff (por ej.
# con datos corruptos en el emptyDir), lo borramos para forzar un
# arranque limpio en vez de esperar sobre un pod ya roto.
kubectl delete pod -l app=examen-db -n examen --ignore-not-found=true

kubectl rollout restart deployment/examen-db -n examen

echo ""
echo "Esperando que MySQL quede Ready..."

kubectl rollout status \
  deployment/examen-db \
  -n examen \
  --timeout=400s

echo "Dándole 15 segundos a MySQL para procesar el init.sql..."
sleep 15

echo ""
echo "Estado actual:"

kubectl get pods -n examen
kubectl get svc -n examen

####################################################
# BACKEND
####################################################

echo ""
echo "Desplegando Backend..."

kubectl apply -f ./k8s/backend-deployment.yaml
kubectl apply -f ./k8s/backend-service.yaml
kubectl apply -f ./k8s/backend-hpa.yaml

# Reiniciamos y esperamos UNO POR UNO (no ambos a la vez): así el pico
# de CPU de arranque del JVM de cada servicio no se suma, y el HPA no
# tiene motivo para escalar de más justo en medio del despliegue.
kubectl rollout restart deployment/examen-backend-despachos -n examen

kubectl rollout status \
  deployment/examen-backend-despachos \
  -n examen \
  --timeout=300s

kubectl rollout restart deployment/examen-backend-ventas -n examen

kubectl rollout status \
  deployment/examen-backend-ventas \
  -n examen \
  --timeout=300s

####################################################
# FRONTEND
####################################################

echo ""
echo "Desplegando Frontend..."

kubectl apply -f ./k8s/frontend-deployment.yaml
kubectl apply -f ./k8s/frontend-service.yaml
kubectl apply -f ./k8s/frontend-hpa.yaml

kubectl rollout restart deployment/examen-frontend -n examen

kubectl rollout status \
  deployment/examen-frontend \
  -n examen \
  --timeout=300s

####################################################
# LOAD BALANCER
####################################################

echo ""
echo "Esperando LoadBalancer..."

for i in {1..40}
do
  HOSTNAME=$(kubectl get svc examen-frontend \
  -n examen \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

  IP=$(kubectl get svc examen-frontend \
  -n examen \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
  if [ ! -z "$HOSTNAME" ]; then
    echo ""
    echo "===================================="
    echo "APLICACIÓN DISPONIBLE EN:"
    echo "http://${HOSTNAME}"
    echo "===================================="
    exit 0
  fi

  if [ ! -z "$IP" ]; then
    echo ""
    echo "===================================="
    echo "APLICACIÓN DISPONIBLE EN:"
    echo "http://${IP}"
    echo "===================================="
    exit 0
  fi

  echo "Esperando IP pública... (${i}/40)"
  sleep 15
done

echo ""
echo "No fue posible obtener la IP pública."
echo "Verificar manualmente con:"
echo "kubectl get svc examen-frontend -n examen"
