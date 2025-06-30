#!/bin/bash

# MySQL Operator 部署测试脚本
# 用于测试单实例和主从架构部署

set -e

echo "=== MySQL Operator 部署测试脚本 ==="
echo

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 函数：打印带颜色的消息
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 函数：检查命令是否存在
check_command() {
    if ! command -v $1 &> /dev/null; then
        print_error "$1 命令未找到，请先安装"
        exit 1
    fi
}

# 函数：等待Pod就绪
wait_for_pods() {
    local label=$1
    local timeout=${2:-300}
    
    print_info "等待Pod就绪: $label"
    kubectl wait --for=condition=Ready pod -l $label --timeout=${timeout}s
    if [ $? -eq 0 ]; then
        print_success "Pod已就绪"
    else
        print_error "Pod启动超时"
        return 1
    fi
}

# 函数：清理资源
cleanup() {
    print_info "清理测试资源..."
    kubectl delete mysql mysql-standalone --ignore-not-found=true
    kubectl delete mysql mysql-cluster --ignore-not-found=true
    
    # 等待Pod删除
    sleep 10
    
    # 清理PVC（可选）
    read -p "是否删除PVC？这将删除所有数据 (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        kubectl delete pvc -l app=mysql-standalone --ignore-not-found=true
        kubectl delete pvc -l app=mysql-cluster --ignore-not-found=true
        print_success "PVC已删除"
    fi
}

# 函数：测试MySQL连接
test_mysql_connection() {
    local pod_name=$1
    local password=$2
    
    print_info "测试MySQL连接: $pod_name"
    kubectl exec $pod_name -- mysql -u root -p$password -e "SELECT VERSION();" > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        print_success "MySQL连接成功"
        return 0
    else
        print_error "MySQL连接失败"
        return 1
    fi
}

# 函数：测试主从复制状态
test_replication_status() {
    local master_pod=$1
    local slave_pod=$2
    local password=$3
    
    print_info "检查主从复制状态..."
    
    # 检查主库状态
    print_info "检查主库状态"
    kubectl exec $master_pod -- mysql -u root -p$password -e "SHOW MASTER STATUS\\G"
    
    # 检查从库状态
    print_info "检查从库状态"
    kubectl exec $slave_pod -- mysql -u root -p$password -e "SHOW SLAVE STATUS\\G" | grep -E "Slave_IO_Running|Slave_SQL_Running|Seconds_Behind_Master"
}

# 主函数
main() {
    print_info "开始MySQL Operator测试"
    
    # 检查必要的命令
    check_command kubectl
    check_command docker
    
    # 检查Kubernetes连接
    print_info "检查Kubernetes连接..."
    kubectl cluster-info > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        print_error "无法连接到Kubernetes集群"
        exit 1
    fi
    print_success "Kubernetes连接正常"
    
    # 选择测试模式
    echo
    echo "请选择测试模式:"
    echo "1) 单实例模式测试"
    echo "2) 主从架构测试"
    echo "3) 完整测试（单实例 + 主从）"
    echo "4) 清理资源"
    echo "5) 退出"
    echo
    read -p "请输入选择 (1-5): " choice
    
    case $choice in
        1)
            test_standalone
            ;;
        2)
            test_master_slave
            ;;
        3)
            test_standalone
            echo
            test_master_slave
            ;;
        4)
            cleanup
            ;;
        5)
            print_info "退出测试"
            exit 0
            ;;
        *)
            print_error "无效选择"
            exit 1
            ;;
    esac
}

# 函数：测试单实例模式
test_standalone() {
    print_info "=== 开始单实例模式测试 ==="
    
    # 部署单实例MySQL
    print_info "部署单实例MySQL..."
    kubectl apply -f config/samples/mysql_v1alpha1_mysql.yaml
    
    # 等待Pod就绪
    wait_for_pods "app=mysql-sample" 300
    
    # 获取Pod名称
    POD_NAME=$(kubectl get pods -l app=mysql-sample -o jsonpath='{.items[0].metadata.name}')
    print_info "Pod名称: $POD_NAME"
    
    # 测试连接
    sleep 30  # 等待MySQL完全启动
    test_mysql_connection $POD_NAME "Root@1234!"
    
    # 显示服务信息
    print_info "服务信息:"
    kubectl get svc mysql-sample
    
    print_success "单实例模式测试完成"
}

# 函数：测试主从架构
test_master_slave() {
    print_info "=== 开始主从架构测试 ==="
    
    # 部署主从MySQL
    print_info "部署主从MySQL..."
    kubectl apply -f config/samples/mysql_v1alpha1_mysql_master_slave.yaml
    
    # 等待主库Pod就绪
    print_info "等待主库启动..."
    wait_for_pods "app=mysql-cluster,role=master" 300
    
    # 等待从库Pod就绪
    print_info "等待从库启动..."
    wait_for_pods "app=mysql-cluster,role=slave" 300
    
    # 获取Pod名称
    MASTER_POD=$(kubectl get pods -l app=mysql-cluster,role=master -o jsonpath='{.items[0].metadata.name}')
    SLAVE_POD=$(kubectl get pods -l app=mysql-cluster,role=slave -o jsonpath='{.items[0].metadata.name}')
    
    print_info "主库Pod: $MASTER_POD"
    print_info "从库Pod: $SLAVE_POD"
    
    # 等待MySQL完全启动
    sleep 60
    
    # 测试主库连接
    test_mysql_connection $MASTER_POD "Root@1234!"
    
    # 测试从库连接
    test_mysql_connection $SLAVE_POD "Root@1234!"
    
    # 测试主从复制状态
    test_replication_status $MASTER_POD $SLAVE_POD "Root@1234!"
    
    # 显示服务信息
    print_info "服务信息:"
    kubectl get svc -l app=mysql-cluster
    
    print_success "主从架构测试完成"
}

# 捕获中断信号
trap 'print_warning "测试被中断"; exit 1' INT TERM

# 运行主函数
main