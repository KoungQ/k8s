#!/bin/bash

set -e

echo "🗑️  Back Office 로컬 쿠버네티스 리소스 삭제 스크립트"
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

# 현재 디렉토리 확인
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

# 확인 메시지
read -p "정말로 모든 리소스를 삭제하시겠습니까? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "취소되었습니다."
    exit 0
fi

echo ""
echo "🗑️  리소스 삭제 중..."
echo ""

# 역순으로 삭제 (의존성 고려)
kubectl delete -f back-office-app.yaml --ignore-not-found=true
kubectl delete -f grafana.yaml --ignore-not-found=true
kubectl delete -f promtail.yaml --ignore-not-found=true
kubectl delete -f loki.yaml --ignore-not-found=true
kubectl delete -f kafka.yaml --ignore-not-found=true
kubectl delete -f zookeeper.yaml --ignore-not-found=true
kubectl delete -f redis.yaml --ignore-not-found=true
kubectl delete -f mysql.yaml --ignore-not-found=true
kubectl delete -f secret.yaml --ignore-not-found=true
kubectl delete -f configmap.yaml --ignore-not-found=true
kubectl delete -f namespace.yaml --ignore-not-found=true

echo ""
echo -e "${GREEN}✅ 리소스 삭제 완료!${NC}"
echo ""
echo "네임스페이스가 완전히 삭제될 때까지 잠시 기다려주세요..."
sleep 5

# 네임스페이스 확인
if kubectl get namespace back-office &> /dev/null; then
    echo -e "${YELLOW}⚠️  네임스페이스가 아직 존재합니다. 수동으로 삭제하세요:${NC}"
    echo "   kubectl delete namespace back-office"
else
    echo -e "${GREEN}✅ 네임스페이스가 성공적으로 삭제되었습니다.${NC}"
fi

