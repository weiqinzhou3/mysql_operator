# 01‑project‑overview

> **MySQL Operator – 项目总览（Draft v0.2）**  
> 更新时间：2025‑07‑16

## 1. 项目背景

- **痛点**  
  - 现有 MySQL 实例以手工或脚本方式部署，运维与扩缩容成本高。  
  - 主从拓扑在 Kubernetes 内缺乏自动故障转移与滚动升级能力。  
  - 备份、监控、容量规划等仍依赖外部脚本，缺乏统一声明式接口。

- **目标**  
  - 基于 Golang operator‑sdk（v1.40+）实现生产级 **MySQL Operator**。  
  - **首期支持 MySQL 8.0 主从拓扑**；后续可扩展到 **MGR / InnoDB Cluster**。  
  - 生命周期覆盖：部署、扩缩、升级、故障转移、全量备份、监控暴露。  
  - 对接现有 **Prometheus**；备份采用 *xtrabackup* / *mysqldump*（全量）。  
  - **SLA 99.95 % / RTO < 5 min / RPO≈0**。

## 2. 环境与约束

| 项        | 约束 |
|-----------|------|
| **K8s**   | ≥ v1.29（私有集群，运行于虚拟机；存储：**本地盘**） |
| **网络**  | NodePort 暴露：<br>‑ `mysql-write`（Primary 写）<br>‑ `mysql-read`（Replica 读，Service 配置 `sessionAffinity=None` + `externalTrafficPolicy=Cluster` 以便简单负载均衡） |
| **监控**  | Prometheus + 可选 Grafana dashborads |
| **备份**  | 首期仅全量；PITR 置于后续 Roadmap |
| **秘钥**  | 先用 K8s Secret；后期可评估接入 Vault |
| **镜像仓库** | 私有阿里云 Registry（见 § 5） |
| **CI / CD** | **GitHub Actions**（Kind 集成测试） |

## 3. 范围（MVP v0.1）

| 范畴 | 说明 |
|------|------|
| **CRD**          | `MySQLCluster`、`MySQLBackup` |
| **拓扑**         | 1 Primary + N Replicas |
| **服务暴露**     | 两个 NodePort Service（Primary / Read‑LB） |
| **存储**         | StatefulSet + 本地盘 PVC |
| **备份恢复**     | 全量备份 Job；手动恢复 |
| **CI / CD**      | GitHub Actions → UT → Kind e2e → 镜像推送阿里云 Registry |
| **交付**         | Helm Chart |

## 4. 非功能需求
（同 v0.1，已调整网络与 CI/CD 描述，略）

## 5. 镜像仓库与推送流程

> **‼️ 不要将真实密码写入 Git！**  
> 以下示例中用 `${ALIYUN_PASSWORD}` 环境变量替代，请在 CI/CD 或本地 shell 中注入。

```bash
# 1. 登录
docker login \
  --username=aliyun9300206566 \
  -p "${ALIYUN_PASSWORD}" \
  crpi-oedkuzepm53hblsq.cn-shanghai.personal.cr.aliyuncs.com

# 2. 拉取
docker pull crpi-oedkuzepm53hblsq.cn-shanghai.personal.cr.aliyuncs.com/qwzhou_test/operator:<tag>

# 3. 推送
docker tag <IMAGE_ID> crpi-oedkuzepm53hblsq.cn-shanghai.personal.cr.aliyuncs.com/qwzhou_test/operator:<tag>
docker push crpi-oedkuzepm53hblsq.cn-shanghai.personal.cr.aliyuncs.com/qwzhou_test/operator:<tag>

