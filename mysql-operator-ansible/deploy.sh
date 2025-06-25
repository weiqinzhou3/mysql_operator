#!/bin/bash

# MySQL Operator 部署脚本
set -e

echo "=== MySQL Operator 部署脚本 ==="

# 检查kubectl是否可用
if ! command -v kubectl &> /dev/null; then
    echo "错误: kubectl 未安装或不在PATH中"
    exit 1
fi

# 检查集群连接
if ! kubectl cluster-info &> /dev/null; then
    echo "错误: 无法连接到Kubernetes集群"
    exit 1
fi

echo "✅ Kubernetes集群连接正常"

# 创建namespace（如果不存在）
NAMESPACE="mysql-operator-ansible-system"
if ! kubectl get namespace $NAMESPACE &> /dev/null; then
    echo "创建namespace: $NAMESPACE"
    kubectl create namespace $NAMESPACE
else
    echo "✅ Namespace $NAMESPACE 已存在"
fi

# 部署CRD
echo "部署MySQL CRD..."
kubectl apply -f config/crd/bases/mysql.qwzhou.local_mysqls.yaml

# 等待CRD就绪
echo "等待CRD就绪..."
kubectl wait --for=condition=established crd/mysqls.mysql.qwzhou.local --timeout=60s

echo "✅ CRD部署完成"

# 构建并部署operator
echo "构建operator镜像..."
TAG=ansible-$(date +%Y%m%d%H%M%S)
IMG=crpi-oedkuzepm53hblsq.cn-shanghai.personal.cr.aliyuncs.com/qwzhou_test/operator:$TAG

echo "使用镜像标签: $IMG"

make docker-build IMG=$IMG
echo "推送镜像到阿里云仓库..."
make docker-push IMG=$IMG

# 部署operator到集群
echo "部署operator到集群..."
make deploy IMG=$IMG

# 确保deployment使用正确的镜像
echo "更新deployment镜像..."
kubectl -n mysql-operator-ansible-system set image deploy/mysql-operator-ansible-controller-manager manager=$IMG

# 等待operator就绪
echo "等待operator就绪..."
kubectl wait --for=condition=available deployment/mysql-operator-ansible-controller-manager -n $NAMESPACE --timeout=300s

echo "✅ MySQL Operator部署完成！"

# 显示部署状态
echo ""
echo "=== 部署状态 ==="
kubectl get pods -n $NAMESPACE
echo ""
echo "=== 可用的MySQL CRD ==="
kubectl get crd mysqls.mysql.qwzhou.local

echo ""
echo "=== 部署完成 ==="
echo "现在您可以创建MySQL实例了:"
echo "kubectl apply -f config/samples/mysql_v1alpha1_mysql.yaml"
echo ""
echo "查看MySQL实例:"
echo "kubectl get mysql"