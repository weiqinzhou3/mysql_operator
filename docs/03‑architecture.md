# 03‑architecture

> **MySQL Operator – 总体架构（Draft v0.1）**\
> 更新时间：2025‑07‑16

---

## 1. 顶层视图

```mermaid
flowchart LR
    subgraph Kubernetes Cluster
        direction TB
        classDef cr fill:#e0f7fa,stroke:#006064;
        MySQLClusterCR[MySQLCluster CR]:::cr
        MySQLBackupCR[MySQLBackup CR]:::cr
        OperatorPod[[mysql‑operator<br>(controller‑manager)]]
        StatefulSetSTS[StatefulSet mysql-ss]
        ServicesSvc[NodePort & ClusterIP Services]
        PVC[(Local PVs)]
        BackupJob((Backup<br>Job))

        MySQLClusterCR -->|Watch| OperatorPod
        MySQLBackupCR  -->|Watch| OperatorPod
        OperatorPod -->|Create/Update| StatefulSetSTS
        OperatorPod -->|Create/Update| ServicesSvc
        StatefulSetSTS --> PVC
        OperatorPod -->|Spawn| BackupJob
        BackupJob -->|Upload| ObjectStorage[(S3/NAS)]
    end
```

---

## 2. 组件说明

| 编号 | 组件                                         | 作用                                                                           |
| -- | ------------------------------------------ | ---------------------------------------------------------------------------- |
| ①  | **CRDs** (`mysqlclusters`, `mysqlbackups`) | 声明集群 / 备份所需的期望状态；Operator 监听这些变动。                                            |
| ②  | **Operator Pod**                           | `controller-runtime` 管理的主控制循环；负责创建/维护所有 Kubernetes 原生资源，并写入 CR Status。       |
| ③  | **StatefulSet**                            | 每个 `MySQLCluster` 对应 1 个 STS；保证有序启动、稳定网络标识、挂载 PVC。                           |
| ④  | **Pods**                                   | 由主容器 `mysqld`、监控容器 `mysqld_exporter`、可选 Sidecar（如 log‑agent）组成。              |
| ⑤  | **Services**                               | `mysql-write`：NodePort，指向 Primary；`mysql-read`：NodePort，指向所有 Replica，简易负载均衡。 |
| ⑥  | **Backup Job**                             | `kubectl cronjob` 风格实现：拉起 *xtrabackup* 或 *mysqldump* 容器，将全量备份上传至 PVC 或对象存储。  |
| ⑦  | **Storage**                                | Local PV（`local-path` SC）或用户提供的 SC；每 Pod 一个 PVC。                             |
| ⑧  | **监控**                                     | `mysqld_exporter` 暴露主机指标；Operator 额外暴露自身指标。Prometheus Server 已存在集群中。         |

---

## 3. Pod 详细拓扑

| 容器                     | 镜像                             | 关键挂载                                                    | 端口   |
| ---------------------- | ------------------------------ | ------------------------------------------------------- | ---- |
| `mysql`                | `mysql:8.0.36`                 | `/var/lib/mysql` (PVC)`/etc/mysql/secret` (root Secret) | 3306 |
| `exporter`             | `prom/mysqld-exporter:v0.15`   | 共享 `/etc/mysql/secret`                                  | 9104 |
| `xtrabackup` (仅备份 Job) | `percona/percona-xtrabackup:8` | PVC or EmptyDir                                         | —    |

注：所有 Sidecar 使用统一 `log-format=json` 输出，方便 Loki / Elasticsearch 收集。

---

## 4. 数据流

1. **应用流量**：
   - 写 → NodePort:30306 → Primary Pod。
   - 读 → NodePort:30307 → 随机 Replica。
2. **备份流**：备份 Job → (xtrabackup) → 本地 /tmp → 压缩 → PVC 或 S3。
3. **监控流**：Prometheus `scrape` Operator(8080) & Exporter(9104)。

---

## 5. 安全与隔离

| 维度   | 实现                                                                                                               |
| ---- | ---------------------------------------------------------------------------------------------------------------- |
| 密码   | Root 密码存 Kubernetes Secret；Pod 只以 `readOnly=true` 投射。                                                            |
| TLS  | MVP 不启用；后续版本通过 cert‑manager 注入。                                                                                  |
| RBAC | Operator ServiceAccount 仅获 `get, list, watch, create, update, patch` 指 CRD / Pods / Services / PVC / Jobs 等必需资源。 |
| 网络   | 可选 NetworkPolicy；默认允许同 Namespace 内访问。                                                                            |

---

## 6. 伸缩 & 升级序列

| 场景     | 执行顺序                                                                   |
| ------ | ---------------------------------------------------------------------- |
| **扩容** | 新 Pod → `mysqld --relay-log-recovery` → 同步完 → Service.read 加 Endpoint。 |
| **缩容** | 选 Replica → Drain 连接 → `STOP SLAVE` → 删除 Pod。                          |
| **升级** | 先升级 Replica（滚动）→ Primary 切写只读 → Replica 提升 → 原主升 Replica → 升级。         |

---

> **后续**：如架构图或流向有偏差，请直接评论；确认无误后，将同步到 `README` 的高层介绍部分。


