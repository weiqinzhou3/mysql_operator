# MySQL Operator 使用指南

## 概述

本MySQL Operator支持两种部署模式：
- **standalone**: 单实例MySQL部署
- **master-slave**: 主从架构MySQL部署

## 功能特性

### 单实例模式 (standalone)
- 单个MySQL实例
- 自动配置优化
- 持久化存储
- 健康检查
- 资源限制

### 主从模式 (master-slave)
- 一个主库 (Master)
- 可配置的从库数量 (1-5个)
- 自动主从复制配置
- GTID复制支持
- 读写分离支持
- 独立的存储卷

## 部署示例

### 1. 单实例部署

```yaml
apiVersion: mysql.qwzhou.local/v1alpha1
kind: MySQL
metadata:
  name: mysql-standalone
  namespace: default
spec:
  mode: "standalone"
  image: "mysql:8.0"
  rootPassword: "Root@1234!"
  database: "myapp"
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

### 2. 主从架构部署

```yaml
apiVersion: mysql.qwzhou.local/v1alpha1
kind: MySQL
metadata:
  name: mysql-cluster
  namespace: default
spec:
  mode: "master-slave"
  image: "mysql:8.0"
  rootPassword: "Root@1234!"
  database: "myapp"
  replication:
    user: "replicator"
    password: "Repl@1234!"
    slaveReplicas: 2
  storage:
    size: "50Gi"
  resources:
    requests:
      memory: "1Gi"
      cpu: "1000m"
    limits:
      memory: "2Gi"
      cpu: "2000m"
```

## 连接信息

### 单实例模式
- **服务名**: `<mysql-name>`
- **端口**: 3306
- **NodePort**: 30306
- **连接字符串**: `mysql-standalone:3306`

### 主从模式
- **主库服务**: `<mysql-name>-master:3306`
- **从库服务**: `<mysql-name>-slave:3306`
- **负载均衡服务**: `<mysql-name>:3306` (指向主库)
- **NodePort**: 30306 (指向主库)

## 配置说明

### 必需字段
- `rootPassword`: MySQL root用户密码 (最少8位)

### 可选字段
- `mode`: 部署模式，默认为 "standalone"
- `image`: MySQL镜像，默认为 "mysql:8.0"
- `database`: 初始数据库名称
- `storage.size`: 存储大小，默认为 "20Gi"
- `storage.storageClass`: 存储类名称
- `resources`: 资源限制配置

### 主从模式专用字段
- `replication.user`: 复制用户名，默认为 "replicator"
- `replication.password`: 复制用户密码
- `replication.slaveReplicas`: 从库数量 (1-5)，默认为 1

## 部署步骤

1. **应用CRD定义**:
   ```bash
   kubectl apply -f config/crd/bases/mysql.qwzhou.local_mysqls.yaml
   ```

2. **部署Operator**:
   ```bash
   kubectl apply -f config/default/
   ```

3. **创建MySQL实例**:
   ```bash
   kubectl apply -f config/samples/mysql_v1alpha1_mysql.yaml
   ```

4. **查看状态**:
   ```bash
   kubectl get mysql
   kubectl get pods
   kubectl get svc
   ```

## 监控和维护

### 查看主从状态
```bash
# 连接到主库
kubectl exec -it mysql-cluster-master-0 -- mysql -u root -p

# 查看主库状态
SHOW MASTER STATUS;

# 连接到从库
kubectl exec -it mysql-cluster-slave-0 -- mysql -u root -p

# 查看从库状态
SHOW SLAVE STATUS\G
```

### 日志查看
```bash
# 查看主库日志
kubectl logs mysql-cluster-master-0

# 查看从库日志
kubectl logs mysql-cluster-slave-0
```

## 注意事项

1. **密码安全**: 确保使用强密码，特别是在生产环境中
2. **存储**: 主从模式下每个实例都有独立的存储卷
3. **网络**: 确保Pod间网络通信正常
4. **资源**: 主从模式需要更多的计算和存储资源
5. **备份**: 定期备份数据，特别是主库数据

## 故障排除

### 常见问题

1. **Pod启动失败**:
   - 检查存储类是否存在
   - 检查资源配额是否足够
   - 查看Pod事件: `kubectl describe pod <pod-name>`

2. **主从复制失败**:
   - 检查网络连接
   - 验证复制用户权限
   - 查看MySQL错误日志

3. **连接问题**:
   - 检查Service状态
   - 验证密码正确性
   - 确认防火墙规则

### 清理资源
```bash
# 删除MySQL实例
kubectl delete mysql <mysql-name>

# 手动清理PVC（如果需要）
kubectl delete pvc -l app=<mysql-name>
```