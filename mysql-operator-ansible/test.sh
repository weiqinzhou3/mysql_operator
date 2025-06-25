#!/bin/bash

# MySQL Operator 测试脚本
set -e

echo "=== MySQL Operator 测试脚本 ==="

# 检查operator是否运行
echo "1. 检查operator状态..."
echo "检查MySQL Operator Pod状态:"
kubectl get pods -n mysql-operator-ansible-system

echo ""
echo "检查operator deployment状态:"
kubectl get deployment -n mysql-operator-ansible-system

echo ""
echo "2. 检查CRD是否存在..."
kubectl get crd mysqls.mysql.qwzhou.local

echo ""
echo "3. 创建测试MySQL实例..."
cat <<EOF | kubectl apply -f -
apiVersion: mysql.qwzhou.local/v1alpha1
kind: MySQL
metadata:
  name: test-mysql
  namespace: default
spec:
  image: "mysql:8.0"
  rootPassword: "TestPassword123!"
  database: "testdb"
  storage:
    size: "10Gi"
  resources:
    requests:
      memory: "512Mi"
      cpu: "500m"
    limits:
      memory: "1Gi"
      cpu: "1000m"
EOF

echo "✅ MySQL实例创建请求已提交"

echo ""
echo "4. 等待MySQL资源创建..."
sleep 10

echo "检查MySQL CR状态:"
kubectl get mysql test-mysql -o wide

echo ""
echo "检查相关资源:"
echo "- PVC状态:"
kubectl get pvc test-mysql-pvc || echo "PVC尚未创建"

echo "- Secret状态:"
kubectl get secret test-mysql-secret || echo "Secret尚未创建"

echo "- Deployment状态:"
kubectl get deployment test-mysql || echo "Deployment尚未创建"

echo "- Service状态:"
kubectl get service test-mysql || echo "Service尚未创建"

echo "- Pod状态:"
kubectl get pods -l app=test-mysql || echo "Pod尚未创建"

echo ""
echo "5. 等待MySQL Pod就绪..."
echo "等待最多5分钟..."

for i in {1..30}; do
    POD_STATUS=$(kubectl get pods -l app=test-mysql -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "NotFound")
    if [ "$POD_STATUS" = "Running" ]; then
        echo "✅ MySQL Pod已运行!"
        break
    elif [ "$POD_STATUS" = "NotFound" ]; then
        echo "等待Pod创建... ($i/30)"
    else
        echo "Pod状态: $POD_STATUS ($i/30)"
    fi
    sleep 10
done

echo ""
echo "6. 最终状态检查..."
echo "MySQL CR详细信息:"
kubectl describe mysql test-mysql

echo ""
echo "MySQL Pod详细信息:"
kubectl describe pods -l app=test-mysql

echo ""
echo "如果MySQL正常运行，您可以通过以下方式连接:"
echo "1. 端口转发: kubectl port-forward svc/test-mysql 3306:3306"
echo "2. 获取密码: kubectl get secret test-mysql-secret -o jsonpath='{.data.mysql-root-password}' | base64 -d"
echo "3. 连接: mysql -h localhost -P 3306 -u root -p"

echo ""
echo "=== 测试完成 ==="
echo "如需清理测试资源，运行: kubectl delete mysql test-mysql"