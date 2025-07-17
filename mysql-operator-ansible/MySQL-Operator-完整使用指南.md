# MySQL Operator 完整使用指南

## 概述

这是一个生产级别的 MySQL Kubernetes Operator，基于 Ansible Operator 框架开发，支持MySQL单实例和主从架构的部署和运维。

## 主要功能

1. **MySQL单实例和主从部署**
2. **自动主从切换 (Failover)**
3. **数据备份和还原**
4. **健康检查和监控**
5. **Prometheus指标暴露**
6. **生产级别的配置和安全**

## 快速开始

### 1. 部署 Operator

```bash
# 安装 CRDs
make install

# 创建镜像拉取密钥
kubectl create secret docker-registry aliyun-registry \
  --docker-server=crpi-oedkuzepm53hblsq.cn-shanghai.personal.cr.aliyuncs.com \
  --docker-username=aliyun9300206566 \
  --docker-password=Love9810@ \
  --docker-email=qwzhou@163.com \
  -n mysql-operator-ansible-system

# 部署 Operator
make deploy
```

### 2. 部署 MySQL 主从实例

```bash
kubectl apply -f mysql-master-slave-with-backup.yaml
```

## 功能详解

### 1. MySQL 主从架构部署

创建一个包含主从架构的MySQL实例：

```yaml
apiVersion: mysql.qwzhou.local/v1alpha1
kind: MySQL
metadata:
  name: mysql-production
  namespace: default
spec:
  mode: "master-slave"
  image: "crpi-oedkuzepm53hblsq.cn-shanghai.personal.cr.aliyuncs.com/qwzhou_test/mysql:8.0"
  rootPassword: "Root@1234!"
  database: "production_db"
  replication:
    user: "replicator"
    password: "Repl@1234!"
    slaveReplicas: 2
  storage:
    size: "50Gi"
  resources:
    requests:
      memory: "1Gi"
      cpu: "500m"
    limits:
      memory: "2Gi"
      cpu: "1000m"
```

### 2. 主从切换 (Failover)

当主节点故障时，可以触发自动故障转移：

```yaml
spec:
  operations:
    failover:
      enabled: true
      # targetSlave: "mysql-production-slave-0"  # 可选：指定要提升的从节点
```

**操作步骤：**

1. 修改 MySQL 资源，设置 `failover.enabled: true`
2. Operator 会自动检测主节点状态
3. 选择一个健康的从节点提升为新主节点
4. 重新配置其他从节点指向新主节点
5. 更新服务指向新的主节点

### 3. 数据备份

支持定时自动备份和S3存储：

```yaml
spec:
  operations:
    backup:
      enabled: true
      schedule: "0 2 * * *"  # 每天凌晨2点备份
      s3Config:
        endpoint: "https://oss-cn-shanghai.aliyuncs.com"
        bucket: "mysql-backups"
        accessKey: "your-access-key"
        secretKey: "your-secret-key"
```

**备份功能特性：**

- 使用 mysqldump 进行全量备份
- 支持本地存储和S3兼容存储
- 自动清理7天前的备份文件
- 备份过程中支持事务一致性

### 4. 数据还原

从备份文件还原数据：

```yaml
spec:
  operations:
    restore:
      enabled: true
      backupPath: "/backup/production_db_20250702_020000.sql"
      # 或者从S3还原
      # backupPath: "s3://mysql-backups/mysql-backups/production_db_20250702_020000.sql"
```

### 5. 监控和健康检查

Operator 自动部署监控组件：

- **MySQL Exporter**: 暴露 Prometheus 指标
- **健康检查**: 每5分钟检查MySQL连接性和基本状态
- **复制监控**: 每2分钟检查主从复制状态

**监控指标包括：**

- 连接数使用率
- InnoDB缓冲池状态
- 慢查询数量
- 复制延迟
- 复制线程状态

### 6. 生产级别特性

#### 安全配置
- 使用 Kubernetes Secrets 管理敏感信息
- MySQL 配置遵循安全最佳实践
- 支持 GTID 复制模式

#### 高可用性
- StatefulSet 确保持久化存储
- 就绪性和存活性探针
- 优雅的Pod终止处理

#### 性能优化
- 根据资源配置优化 MySQL 参数
- InnoDB 缓冲池大小自动调整
- 复制性能优化配置

## 运维操作示例

### 1. 检查 MySQL 状态

```bash
# 查看 MySQL 实例状态
kubectl get mysql mysql-production -o yaml

# 查看相关的 Pods
kubectl get pods -l app=mysql-production

# 查看服务
kubectl get services -l app=mysql-production
```

### 2. 连接到 MySQL

```bash
# 连接到主节点
kubectl exec -it mysql-production-master-0 -- mysql -u root -p

# 连接到从节点
kubectl exec -it mysql-production-slave-0 -- mysql -u root -p
```

### 3. 查看复制状态

```bash
# 在主节点上查看
kubectl exec -it mysql-production-master-0 -- mysql -u root -p -e "SHOW MASTER STATUS;"

# 在从节点上查看
kubectl exec -it mysql-production-slave-0 -- mysql -u root -p -e "SHOW SLAVE STATUS\\G"
```

### 4. 手动触发备份

```bash
# 创建立即备份任务
kubectl create job mysql-production-manual-backup --from=cronjob/mysql-production-backup
```

### 5. 查看监控数据

```bash
# 查看 MySQL Exporter 指标
kubectl port-forward service/mysql-production-monitoring 9104:9104
curl http://localhost:9104/metrics
```

## 故障排除

### 1. Operator 日志

```bash
kubectl logs -f deployment/controller-manager -n qwzhou-mysql-trae
```

### 2. MySQL Pod 日志

```bash
kubectl logs mysql-production-master-0
kubectl logs mysql-production-slave-0
```

### 3. 健康检查任务日志

```bash
kubectl get jobs -l component=mysql-health-check
kubectl logs job/mysql-production-health-check-xxx
```

### 4. 常见问题

**Q: 从节点复制延迟过高**
A: 检查网络连接和资源配置，可能需要增加CPU/内存资源

**Q: 主从切换失败**
A: 确保至少有一个健康的从节点，检查复制状态和网络连通性

**Q: 备份任务失败**
A: 检查存储空间和S3配置，确认访问凭证正确

## 配置参数说明

### 基础配置
- `mode`: 部署模式，"standalone" 或 "master-slave"
- `image`: MySQL Docker 镜像
- `rootPassword`: MySQL root 密码
- `database`: 初始化数据库名

### 复制配置
- `replication.user`: 复制用户名
- `replication.password`: 复制用户密码
- `replication.slaveReplicas`: 从节点数量 (1-5)

### 存储配置
- `storage.size`: 存储大小
- `storage.storageClass`: 存储类

### 资源配置
- `resources.requests`: 资源请求
- `resources.limits`: 资源限制

### 操作配置
- `operations.failover`: 故障切换配置
- `operations.backup`: 备份配置
- `operations.restore`: 还原配置

## 最佳实践

1. **资源配置**: 根据实际负载配置合适的 CPU 和内存
2. **存储**: 使用高性能存储类（如SSD）
3. **备份策略**: 配置定期备份和异地存储
4. **监控**: 接入 Prometheus 和 Grafana 进行监控
5. **安全**: 使用强密码和网络策略
6. **测试**: 定期进行故障切换和恢复测试

## 版本信息

- Operator 版本: v1.1.0
- 支持的 MySQL 版本: 8.0+
- Kubernetes 版本: 1.20+

## 支持和维护

如有问题，请查看日志或联系运维团队。