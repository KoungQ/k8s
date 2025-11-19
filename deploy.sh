#!/bin/bash

set -e

echo "🚀 Back Office 로컬 쿠버네티스 배포 스크립트"
echo "=========================================="

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# kubectl 설치 확인
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}❌ kubectl이 설치되어 있지 않습니다.${NC}"
    exit 1
fi

# 쿠버네티스 클러스터 연결 확인
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}❌ 쿠버네티스 클러스터에 연결할 수 없습니다.${NC}"
    echo "Minikube: minikube start"
    echo "Kind: kind create cluster"
    exit 1
fi

echo -e "${GREEN}✅ kubectl 및 클러스터 연결 확인 완료${NC}"

# 현재 디렉토리 확인
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

# Secret 파일 확인
if [ ! -f "secret.yaml" ]; then
    echo -e "${RED}❌ secret.yaml 파일이 없습니다.${NC}"
    echo "secret.yaml 파일을 생성하고 필요한 값들을 설정하세요."
    exit 1
fi

# Docker 이미지 빌드 여부 확인
read -p "Docker 이미지를 빌드하시겠습니까? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    BACK_OFFICE_DIR="$(dirname "$SCRIPT_DIR")/back-office"
    if [ ! -d "$BACK_OFFICE_DIR" ]; then
        echo -e "${RED}❌ back-office 디렉토리를 찾을 수 없습니다: $BACK_OFFICE_DIR${NC}"
        exit 1
    fi
    
    echo "📦 Docker 이미지 빌드 중..."
    cd "$BACK_OFFICE_DIR"
    docker build -t back-office:latest .
    
    # Minikube 또는 Kind에 이미지 로드
    if command -v minikube &> /dev/null && minikube status &> /dev/null; then
        echo "📥 Minikube에 이미지 로드 중..."
        minikube image load back-office:latest
    elif kubectl get nodes -o jsonpath='{.items[0].metadata.name}' | grep -q kind; then
        echo "📥 Kind에 이미지 로드 중..."
        kind load docker-image back-office:latest
    else
        echo -e "${YELLOW}⚠️  Minikube 또는 Kind를 감지할 수 없습니다.${NC}"
        echo "이미지를 수동으로 로드하거나 이미지 레지스트리에 푸시하세요."
    fi
    
    cd "$SCRIPT_DIR"
fi

# 배포 순서
echo ""
echo "📋 리소스 배포 시작..."
echo ""

# 1. Namespace
echo "1️⃣  Namespace 생성 중..."
kubectl apply -f namespace.yaml

# 2. ConfigMap
echo "2️⃣  ConfigMap 생성 중..."
kubectl apply -f configmap.yaml

# 3. Secret
echo "3️⃣  Secret 생성 중..."
kubectl apply -f secret.yaml

# 4. MySQL
echo "4️⃣  MySQL 배포 중..."
kubectl apply -f mysql.yaml
echo "   ⏳ MySQL이 준비될 때까지 대기 중..."
kubectl wait --for=condition=ready pod -l app=mysql -n back-office --timeout=300s || true

# 5. Redis
echo "5️⃣  Redis 배포 중..."
kubectl apply -f redis.yaml
echo "   ⏳ Redis가 준비될 때까지 대기 중..."
kubectl wait --for=condition=ready pod -l app=redis -n back-office --timeout=300s || true

# 6. Zookeeper
echo "6️⃣  Zookeeper 배포 중..."
kubectl apply -f zookeeper.yaml
echo "   ⏳ Zookeeper가 준비될 때까지 대기 중..."
kubectl wait --for=condition=ready pod -l app=zookeeper -n back-office --timeout=300s || true

# 7. Kafka
echo "7️⃣  Kafka 배포 중..."
kubectl apply -f kafka.yaml
echo "   ⏳ Kafka가 준비될 때까지 대기 중..."
kubectl wait --for=condition=ready pod -l app=kafka -n back-office --timeout=300s || true

# 8. Loki
echo "8️⃣  Loki 배포 중..."
kubectl apply -f loki.yaml
echo "   ⏳ Loki가 준비될 때까지 대기 중..."
kubectl wait --for=condition=ready pod -l app=loki -n back-office --timeout=300s || true

# 9. Promtail
echo "9️⃣  Promtail 배포 중..."
kubectl apply -f promtail.yaml

# 10. Grafana
echo "🔟 Grafana 배포 중..."
kubectl apply -f grafana.yaml
echo "   ⏳ Grafana가 준비될 때까지 대기 중..."
kubectl wait --for=condition=ready pod -l app=grafana -n back-office --timeout=300s || true

# 11. Back Office 애플리케이션
echo "1️⃣1️⃣  Back Office 애플리케이션 배포 중..."
kubectl apply -f back-office-app.yaml
echo "   ⏳ 애플리케이션이 준비될 때까지 대기 중..."
kubectl wait --for=condition=ready pod -l app=back-office -n back-office --timeout=600s || true

echo ""
echo -e "${GREEN}✅ 배포 완료!${NC}"
echo ""
echo "📊 배포 상태 확인:"
kubectl get all -n back-office

echo ""
echo "🌐 접근 정보:"
echo "   - Back Office: http://localhost:30080"
echo "   - Grafana: http://localhost:30000 (admin/admin)"
echo ""
echo "포트 포워딩을 사용하려면:"
echo "   kubectl port-forward svc/back-office 8080:8080 -n back-office"
echo "   kubectl port-forward svc/grafana 3000:3000 -n back-office"

