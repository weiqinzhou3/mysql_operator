# MySQL Operator (Ansible)

这是一个基于Ansible的Kubernetes MySQL Operator，用于在Kubernetes集群中部署和管理MySQL实例。

## 功能特性

- ✅ 单实例MySQL部署
- ✅ 可配置MySQL登录密码
- ✅ 可选择MySQL版本（支持MySQL 5.7, 8.0等版本）
- ✅ 持久化存储支持
- ✅ 资源配置管理
- ✅ 健康检查（Liveness & Readiness Probes）
- ✅ Service自动创建

## 快速开始

### 1. 部署Operator

```bash
# 部署CRD
kubectl apply -f config/crd/bases/mysql.qwzhou.local_mysqls.yaml

# 部署Operator
kubectl apply -f config/default/
```

### 2. 创建MySQL实例

#### 使用MySQL 8.0（默认）

```yaml
apiVersion: mysql.qwzhou.local/v1alpha1
kind: MySQL
metadata:
  name: mysql-sample
  namespace: default
spec:
  image: "mysql:8.0"
  rootPassword: "MySecurePassword123!"
  database: "sampledb"
  storage:
    size: "20Gi"
  resources:
    requests:
      memory: "512Mi"
      cpu: "500m"
    limits:
      memory: "1Gi"
      cpu: "1000m"
```

#### 使用MySQL 5.7

```yaml
apiVersion: mysql.qwzhou.local/v1alpha1
kind: MySQL
metadata:
  name: mysql-57-sample
  namespace: default
spec:
  image: "mysql:5.7"
  rootPassword: "MySQL57Password!"
  database: "legacy_db"
  storage:
    size: "10Gi"
  resources:
    requests:
      memory: "256Mi"
      cpu: "250m"
    limits:
      memory: "512Mi"
      cpu: "500m"
```

### 3. 应用配置

```bash
# 创建MySQL实例
kubectl apply -f config/samples/mysql_v1alpha1_mysql.yaml

# 或者创建MySQL 5.7实例
kubectl apply -f config/samples/mysql_v1alpha1_mysql-5.7.yaml
```

## 配置参数

### 必需参数

- `rootPassword`: MySQL root用户密码（必须至少8个字符）

### 可选参数

- `image`: MySQL Docker镜像，默认为 `mysql:8.0`
- `database`: 初始创建的数据库名称
- `storage.size`: 存储大小，默认为 `20Gi`
- `storage.storageClass`: 存储类名称
- `resources.requests.memory`: 内存请求，默认为 `512Mi`
- `resources.requests.cpu`: CPU请求，默认为 `500m`
- `resources.limits.memory`: 内存限制，默认为 `1Gi`
- `resources.limits.cpu`: CPU限制，默认为 `1000m`

## 支持的MySQL版本

- `mysql:8.0` (默认)
- `mysql:5.7`
- `mysql:8.0.33`
- `mysql:5.7.42`
- 其他MySQL官方镜像版本

## 访问MySQL

### 获取连接信息

```bash
# 获取MySQL Service
kubectl get svc mysql-sample

# 获取MySQL密码
kubectl get secret mysql-sample-secret -o jsonpath='{.data.mysql-root-password}' | base64 -d
```

### 连接MySQL

```bash
# 端口转发
kubectl port-forward svc/mysql-sample 3306:3306

# 使用MySQL客户端连接
mysql -h localhost -P 3306 -u root -p
```

## 监控和管理

### 检查MySQL状态

```bash
# 查看MySQL实例状态
kubectl get mysql

# 查看详细信息
kubectl describe mysql mysql-sample

# 查看Pod状态
kubectl get pods -l app=mysql-sample

# 查看日志
kubectl logs -l app=mysql-sample
```

### 删除MySQL实例

```bash
kubectl delete mysql mysql-sample
```

## 开发和构建

### 构建Operator镜像

```bash
# 构建镜像
make docker-build IMG=mysql-operator-ansible:latest

# 推送镜像
make docker-push IMG=mysql-operator-ansible:latest
```

### 本地测试

```bash
# 运行测试
make test

# 部署到集群
make deploy IMG=mysql-operator-ansible:latest
```

## 故障排除

### 常见问题

1. **Pod一直处于Pending状态**
   - 检查存储类是否存在
   - 检查节点资源是否充足

2. **MySQL启动失败**
   - 检查密码是否符合MySQL要求
   - 查看Pod日志获取详细错误信息

3. **连接MySQL失败**
   - 确认Service已创建
   - 检查网络策略配置

### 查看日志

```bash
# 查看Operator日志
kubectl logs -n mysql-operator-system deployment/mysql-operator-controller-manager

# 查看MySQL Pod日志
kubectl logs mysql-sample-xxx
```

## 许可证

Apache License 2.0