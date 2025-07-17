# 04‑crd‑design

> **MySQL Operator – CRD 设计（Draft v0.3）**  
> 更新时间：2025‑07‑16

---

## 1. 总览

| CRD              | API Group / Version        | 作用 |
| ---------------- | -------------------------- | -------- |
| **MySQLCluster** | `mysql.qwzhou.io/v1alpha1` | 描述一个主从集群及其生命周期 |
| **MySQLBackup**  | `mysql.qwzhou.io/v1alpha1` | 触发并追踪一次全量备份 / 恢复作业 |

---

## 2. MySQLCluster

### 2.1 重要字段速查

| 路径 | 类型 | 默认值 | 说明 |
|------|------|---------|------|
| `.spec.replicas` | `integer (1‑9)` | `2` | 集群总 Pod 数 = 1 Primary + n‑1 Replicas |
| `.spec.mysqlVersion` | `string` | `"8.0"` | 支持 `8.0.*` |
| `.spec.rootPassword` | `string` | `""` | **初始化 root 密码**；若为空 Operator 随机生成并写入 `Secret/<cluster>-root` |
| `.spec.storageClassName` | `string` | `local-path` | 为空时 Operator 注入／自动安装 local‑path‑provisioner |
| `.spec.storageSize` | `string` | `"20Gi"` | 单 Pod PVC 大小 |
| `.spec.service.nodePort.write` | `int` | `30306` | Primary NodePort |
| `.spec.service.nodePort.read` | `int` | `30307` | Read‑LB NodePort（Replicas 轮询） |
| `.spec.backup.enabled` | `bool` | `false` | 是否允许自动备份（需同时配置 `schedule`） |
| `.spec.resources` | `corev1.ResourceRequirements` | *见 2.4* | CPU / Memory 限制 |
| `.status.phase` | `string` | — | `Creating / Running / Failed / Scaling / Upgrading` |
| `.status.primary` | `string` | — | 当前 Primary Pod 名称 |
| `.status.replicas` | `int` | — | 已就绪 Replica 数 |

### 2.2 OpenAPI v3 Schema（节选）
<details>
<summary>点击展开 YAML Schema</summary>

```yaml
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: mysqlclusters.mysql.qwzhou.io
spec:
  group: mysql.qwzhou.io
  scope: Namespaced
  names:
    kind: MySQLCluster
    plural: mysqlclusters
    singular: mysqlcluster
    shortNames: [mc]
  versions:
    - name: v1alpha1
      served: true
      storage: true
      schema:
        openAPIV3Schema:
          type: object
          properties:
            spec:
              type: object
              required: ["replicas", "mysqlVersion"]
              properties:
                rootPassword:
                  type: string
                  minLength: 1
                  maxLength: 128
                  description: "Plain password; Operator 将存入 Secret 并在容器中通过 env 变量注入。强烈建议生产改为 SecretRef。"
                replicas:
                  type: integer
                  minimum: 1
                  maximum: 9
                  default: 2
                mysqlVersion:
                  type: string
                  pattern: "^8\\.0(\\.\\d+)?$"
                  default: "8.0"
                storageClassName:
                  type: string
                  default: "local-path"
                storageSize:
                  type: string
                  default: "20Gi"
                  pattern: "^[1-9]\\d*(Gi|Mi)$"
                service:
                  type: object
                  properties:
                    nodePort:
                      type: object
                      properties:
                        write:
                          type: integer
                          default: 30306
                          minimum: 30000
                          maximum: 32767
                        read:
                          type: integer
                          default: 30307
                          minimum: 30000
                          maximum: 32767
                backup:
                  type: object
                  properties:
                    enabled:
                      type: boolean
                      default: false
                    schedule:
                      type: string
                      description: Cron 表达式，启用后才必填
                resources:
                  x-kubernetes-preserve-unknown-fields: true
            status:
              type: object
              properties:
                phase:
                  type: string
                primary:
                  type: string
                replicas:
                  type: integer
</details>

```

### 2.3 示例 YAML

```yaml
apiVersion: mysql.qwzhou.io/v1alpha1
kind: MySQLCluster
metadata:
  name: demo-cluster
spec:
  replicas: 3
  mysqlVersion: "8.0.36"
  rootPassword: "Root@1234!"  # 建议仅在 PoC 使用明文
  storageSize: "50Gi"
  backup:
    enabled: true
    schedule: "0 3 * * *"   # 每天 03:00 全量备份
```

> **安全提示**：Operator 注入的 Secret 会挂载到每个 Pod，并通过 `MYSQL_ROOT_PASSWORD` 环境变量被 `entrypoint.sh` 消费。

### 2.4 资源默认值（由 Operator 注入）

```yaml
resources:
  requests:
    cpu: "500m"
    memory: "1Gi"
  limits:
    cpu: "1"
    memory: "2Gi"
```

---

## 3. MySQLBackup

### 3.1 重要字段速查

| 路径 | 类型 | 必填 | 默认值 | 说明 |
|------|------|------|--------|------|
| `.spec.clusterName` | `string` | ✔ | — | 关联的 MySQLCluster 名称 |
| `.spec.method` | `string` | ✖ | `xtrabackup` | `xtrabackup` / `mysqldump` |
| `.spec.storage.s3.bucket` | `string` | ✖ | — | 目标对象存储桶，不填则写入同集群 PVC |
| `.spec.storage.s3.prefix` | `string` | ✖ | — | 路径前缀 |
| `.spec.restoreToNewCluster` | `bool` | ✖ | `false` | 若为 `true`，备份完成后直接创建新集群并恢复 |

### 3.2 OpenAPI v3 Schema（节选）

```yaml
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: mysqlbackups.mysql.qwzhou.io
spec:
  group: mysql.qwzhou.io
  scope: Namespaced
  names:
    kind: MySQLBackup
    plural: mysqlbackups
    singular: mysqlbackup
    shortNames: [mb]
  versions:
    - name: v1alpha1
      served: true
      storage: true
      schema:
        openAPIV3Schema:
          type: object
          properties:
            spec:
              required: ["clusterName"]
              properties:
                clusterName:
                  type: string
                method:
                  type: string
                  enum: ["xtrabackup", "mysqldump"]
                  default: "xtrabackup"
                storage:
                  type: object
                  properties:
                    s3:
                      type: object
                      properties:
                        bucket:
                          type: string
                        prefix:
                          type: string
                restoreToNewCluster:
                  type: boolean
                  default: false
            status:
              type: object
              properties:
                phase:
                  type: string
                startedAt:
                  type: string
                  format: date-time
                completedAt:
                  type: string
                  format: date-time
                reason:
                  type: string
                message:
                  type: string
```

### 3.3 状态机

```
Pending → Running → Completed
        ↘ Failed ↘ Retrying (最多 3 次)
```

### 3.4 示例 YAML

```yaml
apiVersion: mysql.qwzhou.io/v1alpha1
kind: MySQLBackup
metadata:
  name: demo-full-20250716
spec:
  clusterName: demo-cluster
  method: xtrabackup
  storage:
    s3:
      bucket: my-backup-bucket
      prefix: demo/
```

---

## 4. CRD 兼容性与版本策略

| 阶段 | 规则 |
|------|------|
| `v1alpha1` → `v1beta1` | 字段只增不删；必要破坏性变动保持双版本并迁移工具 |
| `v1beta1` → `v1` | Schema 定型；仅允许新增可选字段；升级教程写入 Release Note |
| 废弃字段 | 标记 `deprecated: true`，保留两个小版本后移除 |

---

## 5. 验证与测试

| 层级 | 工具 | 覆盖点 |
|------|------|--------|
| **单元** | `controller-runtime/fake` | 默认值注入、ValidateCreate/Update |
| **集成** | Kind + kuttl | ① 部署集群 → Phase=Running ② 修改 replicas → 扩缩容成功 ③ 删除 Primary → 自动 Failover |
| **E2E 备份** | kuttl | 创建 MySQLBackup → Job 成功 → Phase=Completed |

---

## 6. FAQ

**Q : 如果集群已存在其他 StorageClass，如何避免 Operator 强制安装 local-path‑provisioner？**  
A : Helm Chart 暴露 `installLocalPath: false`。将值设为 `false` 即可跳过安装。

**Q : rootPassword 明文存 Git 有风险，如何改为 SecretRef？**  
A : 从 `v0.2` 起 `.spec.rootPassword` 可设置为 `"ref://<namespace>/<secret>/<key>"`，Operator 检测到 `ref://` 前缀即去读取指定 Secret。

**Q : 备份文件多大会导致 Job 超时？**  
A : 默认 Job ActiveDeadlineSeconds=6h；若数据库 >1 TB，建议改用分片备份或调大时限。

---
