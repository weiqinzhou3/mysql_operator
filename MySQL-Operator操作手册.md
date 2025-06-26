# MySQL Operator 操作手册

## 项目目录结构

```
mysql-operator-ansible/
├── Dockerfile                    # 构建operator镜像的配置文件
├── Makefile                     # 构建、部署和管理的自动化脚本
├── PROJECT                      # Operator SDK项目配置
├── README.md                    # 项目说明文档
├── config/                      # Kubernetes配置文件目录
│   ├── crd/                     # 自定义资源定义(CRD)
│   ├── default/                 # 默认配置
│   ├── manager/                 # Operator管理器配置
│   │   └── manager.yaml         # 主要的deployment配置
│   ├── rbac/                    # 权限控制配置
│   └── samples/                 # 示例CR文件
├── roles/                       # Ansible角色目录
│   └── mysql/                   # MySQL相关的Ansible任务
│       └── tasks/
│           └── main.yml         # 主要的MySQL部署逻辑
├── playbooks/                   # Ansible playbook目录
├── requirements.yml             # Ansible依赖配置
└── watches.yaml                 # 监听的资源配置
```

## 在干净的K8s环境中部署MySQL Operator

### 前置条件
1. 已安装并配置好kubectl
2. 已安装Docker
3. 有权限访问容器镜像仓库
4. K8s集群已运行

### 部署步骤

#### 1. 克隆项目
```bash
git clone <your-repo-url>
cd mysql-operator-ansible
```

#### 2. 配置镜像仓库
编辑 `Makefile`，修改镜像仓库地址：
```makefile
# 修改为你的镜像仓库地址
IMG ?= your-registry.com/your-namespace/mysql-operator-ansible:$(TIMESTAMP)
```

#### 3. 构建并推送镜像
```bash
# 构建镜像
make docker-build

# 推送镜像到仓库
make docker-push
```

#### 4. 部署Operator到K8s
```bash
# 部署CRD和Operator
make deploy
```

#### 5. 验证部署
```bash
# 检查operator pod状态
kubectl get pods -n mysql-operator-ansible-system

# 检查CRD是否创建成功
kubectl get crd mysqls.mysql.qwzhou.local
```

## 创建MySQL实例

### 基本MySQL CR示例
创建文件 `mysql-instance.yaml`：
```yaml
apiVersion: mysql.qwzhou.local/v1alpha1
kind: MySQL
metadata:
  name: mysql-sample
  namespace: default
spec:
  # MySQL版本
  version: "8.0"
  
  # 数据库配置
  database: "myapp"
  
  # 密码配置
  rootPassword: "mySecretPassword123"
  
  # 存储配置
  storage:
    size: "10Gi"
    storageClass: "standard"  # 根据你的K8s环境调整
  
  # 资源配置
  resources:
    requests:
      cpu: "500m"
      memory: "512Mi"
    limits:
      cpu: "1"
      memory: "1Gi"
  
  # 服务配置
  service:
    type: "NodePort"
    nodePort: 30306
```

### 应用MySQL CR
```bash
kubectl apply -f mysql-instance.yaml
```

### 验证MySQL部署
```bash
# 检查MySQL CR状态
kubectl get mysql mysql-sample

# 检查MySQL pod状态
kubectl get pods -l app=mysql-sample

# 检查MySQL service
kubectl get svc mysql-sample

# 查看详细信息
kubectl describe mysql mysql-sample
```

## 修改MySQL配置

### 修改密码
编辑现有的MySQL CR：
```bash
kubectl edit mysql mysql-sample
```

或者更新YAML文件中的密码字段：
```yaml
spec:
  rootPassword: "newSecretPassword456"
```

然后重新应用：
```bash
kubectl apply -f mysql-instance.yaml
```

### 修改MySQL版本
更新YAML文件中的版本字段：
```yaml
spec:
  version: "8.0.35"  # 更新到新版本
```

重新应用配置：
```bash
kubectl apply -f mysql-instance.yaml
```

### 修改存储大小
```yaml
spec:
  storage:
    size: "20Gi"  # 扩容到20GB
```

### 修改资源配置
```yaml
spec:
  resources:
    requests:
      cpu: "1"
      memory: "1Gi"
    limits:
      cpu: "2"
      memory: "2Gi"
```

## 连接MySQL

### 获取连接信息
```bash
# 获取NodePort端口
kubectl get svc mysql-sample

# 获取节点IP
kubectl get nodes -o wide

# 获取密码（从secret中）
kubectl get secret mysql-sample-secret -o jsonpath='{.data.mysql-root-password}' | base64 -d
```

### 连接命令示例
```bash
# 使用mysql客户端连接
mysql -h <NODE_IP> -P 30306 -u root -p

# 或者通过kubectl port-forward
kubectl port-forward svc/mysql-sample 3306:3306
mysql -h localhost -P 3306 -u root -p
```

## 清理资源

### 删除MySQL实例
```bash
# 删除特定的MySQL实例
kubectl delete mysql mysql-sample

# 删除所有MySQL实例
kubectl delete mysql --all
```

### 删除相关资源
```bash
# 删除PVC（注意：这会删除数据）
kubectl delete pvc mysql-sample-pvc

# 删除Secret
kubectl delete secret mysql-sample-secret
```

### 完全卸载Operator
```bash
# 删除所有MySQL实例
kubectl delete mysql --all --all-namespaces

# 卸载operator
make undeploy

# 或者手动删除
kubectl delete namespace mysql-operator-ansible-system
kubectl delete crd mysqls.mysql.qwzhou.local
kubectl delete clusterrole mysql-operator-ansible-manager-role
kubectl delete clusterrolebinding mysql-operator-ansible-manager-rolebinding
```

## 故障排查

### 查看Operator日志
```bash
# 获取operator pod名称
kubectl get pods -n mysql-operator-ansible-system

# 查看日志
kubectl logs -n mysql-operator-ansible-system <operator-pod-name>
```

### 查看MySQL pod日志
```bash
kubectl logs <mysql-pod-name>
```

### 检查事件
```bash
# 查看namespace中的事件
kubectl get events --sort-by=.metadata.creationTimestamp

# 查看特定资源的事件
kubectl describe mysql mysql-sample
kubectl describe pod <mysql-pod-name>
```

## 注意事项

1. **数据持久化**：删除MySQL CR时，PVC不会自动删除，需要手动清理
2. **密码安全**：生产环境中建议使用Kubernetes Secret管理密码
3. **存储类**：确保K8s集群中有可用的StorageClass
4. **网络策略**：根据需要配置网络策略和防火墙规则
5. **备份**：定期备份MySQL数据
6. **监控**：建议配置监控和告警

这份手册涵盖了MySQL Operator的完整生命周期管理，从部署到清理的所有关键步骤。