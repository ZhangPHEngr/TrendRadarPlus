#!/bin/bash
# ========================================
# wewe-rss 一键启动/管理脚本
# 启动服务
#  ./start.sh
# 或者指定命令
#  ./start.sh start    # 启动服务
#  ./start.sh stop     # 停止服务
#  ./start.sh restart  # 重启服务
#  ./start.sh status   # 查看状态
#  ./start.sh logs     # 查看日志
#  ./start.sh update   # 更新服务
#  ./start.sh clean    # 清理数据（危险）
#  ./start.sh help     # 显示帮助

# docker源更新
# bash <(wget -qO- https://xuanyuan.cloud/docker.sh)
# 登陆轩辕云免费版镜像
# docker login docker.xuanyuan.run
# ========================================

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 配置
WEB_PORT=4000
AUTH_CODE=123567
DB_PASSWORD=123456

# 打印带颜色的消息
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

print_header() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
}

# 检查 Docker 是否运行
check_docker() {
    if ! docker info > /dev/null 2>&1; then
        print_error "Docker 未运行，请先启动 Docker"
        exit 1
    fi
}

# 检查 docker-compose 是否安装
check_docker_compose() {
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        print_error "docker-compose 未安装"
        exit 1
    fi
}

# 获取 docker-compose 命令
get_compose_cmd() {
    if command -v docker-compose &> /dev/null; then
        echo "docker-compose"
    else
        echo "docker compose"
    fi
}

# 等待服务健康检查
wait_for_service() {
    local max_wait=60
    local waited=0

    print_info "等待服务启动..."
    while [ $waited -lt $max_wait ]; do
        # 检查容器是否都在运行
        local running=$($COMPOSE_CMD ps -q | xargs -r docker inspect --format='{{.State.Health.Status}}' 2>/dev/null | grep -c "healthy\|running" 2>/dev/null || echo 0)
        local total=$($COMPOSE_CMD ps -q | wc -l)

        if [ "$running" -eq "$total" ] && [ "$total" -gt 0 ]; then
            return 0
        fi

        sleep 2
        waited=$((waited + 2))
    done

    return 1
}

# 启动服务
start_service() {
    print_header "启动 wewe-rss 服务"

    COMPOSE_CMD=$(get_compose_cmd)

    print_info "启动服务..."
    if ! $COMPOSE_CMD up -d; then
        print_error "服务启动失败！"
        echo ""
        print_info "查看日志获取详细信息: $0 logs"
        exit 1
    fi

    # 等待服务健康检查通过
    if ! wait_for_service; then
        print_warning "服务已启动，但健康检查未通过，请查看日志"
    fi

    echo ""
    print_success "服务启动成功！"
    echo ""
    show_access_info
}

# 停止服务
stop_service() {
    print_header "停止 wewe-rss 服务"

    COMPOSE_CMD=$(get_compose_cmd)
    if ! $COMPOSE_CMD down; then
        print_error "服务停止失败！"
        exit 1
    fi

    print_success "服务已停止"
}

# 重启服务
restart_service() {
    print_header "重启 wewe-rss 服务"

    COMPOSE_CMD=$(get_compose_cmd)
    if ! $COMPOSE_CMD restart; then
        print_error "服务重启失败！"
        exit 1
    fi

    # 等待服务健康检查通过
    if ! wait_for_service; then
        print_warning "服务已重启，但健康检查未通过，请查看日志"
    fi

    print_success "服务已重启"
    echo ""
    show_access_info
}

# 查看日志
view_logs() {
    print_header "查看 wewe-rss 日志"

    COMPOSE_CMD=$(get_compose_cmd)
    $COMPOSE_CMD logs -f app
}

# 查看状态
show_status() {
    print_header "wewe-rss 服务状态"

    COMPOSE_CMD=$(get_compose_cmd)
    $COMPOSE_CMD ps
}

# 显示访问信息
show_access_info() {
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}  wewe-rss 访问信息${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "  🌐 Web 界面:     ${BLUE}http://localhost:${WEB_PORT}${NC}"
    echo -e "  🔑 授权码:       ${YELLOW}${AUTH_CODE}${NC}"
    echo -e "  🗄️  数据库密码:   ${YELLOW}${DB_PASSWORD}${NC}"
    echo ""
    echo -e "  📝 RSS 订阅示例:"
    echo -e "     ${BLUE}http://localhost:${WEB_PORT}/rss/{订阅ID}${NC}"
    echo ""
    echo -e "  🔧 常用命令:"
    echo -e "     查看日志: $0 logs"
    echo -e "     停止服务: $0 stop"
    echo -e "     重启服务: $0 restart"
    echo -e "     查看状态: $0 status"
    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# 更新服务
update_service() {
    print_header "更新 wewe-rss 服务"

    COMPOSE_CMD=$(get_compose_cmd)

    print_info "拉取最新镜像..."
    if ! $COMPOSE_CMD pull; then
        print_error "镜像拉取失败！"
        exit 1
    fi

    print_info "重启服务..."
    if ! $COMPOSE_CMD up -d; then
        print_error "服务启动失败！"
        exit 1
    fi

    # 等待服务健康检查通过
    if ! wait_for_service; then
        print_warning "服务已更新，但健康检查未通过，请查看日志"
    fi

    print_success "服务已更新并重启"
    echo ""
    show_access_info
}

# 清理数据
clean_data() {
    print_header "清理 wewe-rss 数据"
    print_warning "此操作将删除所有数据，不可恢复！"

    read -p "确定要继续吗？(yes/no): " confirm
    if [ "$confirm" != "yes" ]; then
        echo "操作已取消"
        return
    fi

    COMPOSE_CMD=$(get_compose_cmd)
    $COMPOSE_CMD down -v

    print_success "数据已清理"
}

# 显示帮助
show_help() {
    print_header "wewe-rss 管理脚本"
    echo ""
    echo "用法: $0 [命令]"
    echo ""
    echo "命令:"
    echo "  start     启动服务 (默认)"
    echo "  stop      停止服务"
    echo "  restart   重启服务"
    echo "  status    查看状态"
    echo "  logs      查看日志"
    echo "  update    更新服务"
    echo "  clean     清理数据 (危险)"
    echo "  help      显示帮助"
    echo ""
}

# 主函数
main() {
    # 检查环境
    check_docker
    check_docker_compose

    # 获取命令
    local command="${1:-start}"

    case "$command" in
        start)
            start_service
            ;;
        stop)
            stop_service
            ;;
        restart)
            restart_service
            ;;
        status)
            show_status
            ;;
        logs)
            view_logs
            ;;
        update)
            update_service
            ;;
        clean)
            clean_data
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            print_error "未知命令: $command"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

# 执行主函数
main "$@"
