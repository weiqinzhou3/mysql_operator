# MySQL Operator 问题修复方案

## 问题诊断
根据operator日志分析，问题出现在Ansible playbook执行时：
```
ERROR! couldn't resolve module/action 'kubernetes.core.k8s_status'
The error appears to be in '/opt/ansible/roles/mysql/tasks/main.yml': line 147
```

## 根本原因
1. **模块不可用**：operator镜像中缺少`kubernetes.core.k8s_status`模块
2. **依赖问题**：requirements.yml中可能缺少必要的Ansible collection
3. **版本兼容性**：operator镜像的Ansible版本与所需collection不兼容

## 修复步骤

### 1. 更新requirements.yml
确保包含必要的Kubernetes collection：

```yaml
---
collections:
  - name: kubernetes.core
    version: ">=2.3.0"
  - name: community.general
    version: ">=5.0.0"
  - name: community.docker
    version: ">=3.0.0"
```

### 2. 修复tasks/main.yml
移除或替换有问题的k8s_status模块：

```yaml
# 方案1：完全移除状态更新（推荐）
# 注释掉k8s_status相关任务

# 方案2：使用普通k8s模块更新状态
- name: Update MySQL CR status
  kubernetes.core.k8s:
    state: present
    definition:
      apiVersion: mysql.qwzhou.local/v1alpha1
      kind: MySQL
      metadata:
        name: "{{ ansible_operator_meta.name }}"
        namespace: "{{ ansible_operator_meta.namespace }}"
      status:
        phase: "Ready"
        conditions:
        - type: "Ready"
          status: "True"
          reason: "DeploymentReady"
          message: "MySQL deployment is ready"
```

### 3. 重新构建和部署
```bash
# 重新构建operator镜像
TAG=ansible-$(date +%Y%m%d%H%M%S)
IMG=crpi-oedkuzepm53hblsq.cn-shanghai.personal.cr.aliyuncs.com/qwzhou_test/operator:$TAG

make docker-build IMG=$IMG
make docker-push IMG=$IMG

# 更新deployment
kubectl -n mysql-operator-ansible-system set image deploy/mysql-operator-ansible-controller-manager manager=$IMG
```

### 4. 验证修复
```bash
# 检查operator状态
kubectl get pods -n mysql-operator-ansible-system

# 创建测试MySQL实例
kubectl apply -f config/samples/mysql_v1alpha1_mysql.yaml

# 检查资源创建
kubectl get mysql,pvc,secret,svc,deployment -l app=mysql-sample
```

## 预期结果
修复后，operator应该能够：
1. 成功执行Ansible playbook
2. 创建MySQL相关资源（PVC、Secret、Deployment、Service）
3. MySQL Pod正常启动并运行

## 故障排查
如果问题仍然存在：
1. 检查operator日志：`kubectl logs -n mysql-operator-ansible-system deployment/mysql-operator-ansible-controller-manager`
2. 验证CRD定义：`kubectl describe crd mysqls.mysql.qwzhou.local`
3. 检查RBAC权限：`kubectl describe clusterrole mysql-operator-ansible-manager-role`