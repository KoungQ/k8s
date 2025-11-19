# 로컬 쿠버네티스 환경 설정

이 디렉토리는 Back Office 애플리케이션을 로컬 쿠버네티스 환경에서 실행하기 위한 리소스 파일들을 포함합니다.

## 사전 요구사항

1. **쿠버네티스 클러스터**
   - Minikube: `minikube start`
   - Kind: `kind create cluster`
   - Docker Desktop (Kubernetes 활성화)

2. **kubectl**: 쿠버네티스 CLI 도구

3. **Docker**: 이미지 빌드용

## 설정 단계

### 1. Secret 파일 수정

`secret.yaml` 파일을 열어 실제 값으로 수정하세요:

```bash
# secret.yaml 파일 편집
vim secret.yaml
```

다음 값들을 실제 값으로 변경해야 합니다:
- `RDB_PASSWORD`: MySQL 루트 비밀번호
- `AWS_ACCESS_KEY`, `AWS_SECRET_KEY`, `AWS_S3_BUCKET_NAME`: AWS 자격 증명
- `JWT_KEY`: JWT 서명 키 (최소 256비트)
- `SMTP_USERNAME`, `SMTP_PASSWORD`: 이메일 발송용 SMTP 자격 증명

### 2. Docker 이미지 빌드

Back Office 애플리케이션 이미지를 빌드합니다:

```bash
# back-office 디렉토리로 이동
cd ../back-office

# Docker 이미지 빌드
docker build -t back-office:latest .

# Minikube를 사용하는 경우, 이미지를 Minikube에 로드
minikube image load back-office:latest

# 또는 Kind를 사용하는 경우
kind load docker-image back-office:latest
```

### 3. 리소스 배포

모든 리소스를 배포합니다:

```bash
# 현재 디렉토리로 이동
cd local-k8s

# 모든 리소스 배포
kubectl apply -f .

# 또는 kustomize 사용
kubectl apply -k .
```

### 4. 배포 상태 확인

```bash
# 네임스페이스 확인
kubectl get namespace back-office

# 모든 리소스 상태 확인
kubectl get all -n back-office

# Pod 상태 확인
kubectl get pods -n back-office

# Pod 로그 확인
kubectl logs -f <pod-name> -n back-office
```

### 5. 서비스 접근

#### Back Office 애플리케이션
- **NodePort**: `http://localhost:30080`
- **포트 포워딩**: `kubectl port-forward svc/back-office 8080:8080 -n back-office`
  - 접근: `http://localhost:8080`

#### Grafana
- **NodePort**: `http://localhost:30000`
- 기본 로그인: `admin` / `admin` (secret.yaml에서 변경 가능)

#### 데이터베이스 접근 (포트 포워딩)
```bash
# MySQL
kubectl port-forward svc/mysql 3306:3306 -n back-office

# Redis
kubectl port-forward svc/redis 6379:6379 -n back-office

# Kafka
kubectl port-forward svc/kafka 9092:9092 -n back-office
```

## 배포 순서

의존성 관계를 고려하여 다음 순서로 배포하는 것을 권장합니다:

1. **Namespace, ConfigMap, Secret**
2. **MySQL, Redis** (데이터베이스)
3. **Zookeeper** (Kafka 의존성)
4. **Kafka** (Zookeeper 필요)
5. **Loki** (로그 수집)
6. **Promtail** (Loki 필요)
7. **Grafana** (Loki 필요)
8. **Back Office 애플리케이션** (모든 의존성 필요)

## 리소스 파일 설명

- `namespace.yaml`: back-office 네임스페이스
- `configmap.yaml`: 애플리케이션 설정 (비밀 정보 제외)
- `secret.yaml`: 민감한 정보 (비밀번호, 키 등)
- `mysql.yaml`: MySQL 데이터베이스
- `redis.yaml`: Redis 캐시
- `zookeeper.yaml`: Zookeeper (Kafka 의존성)
- `kafka.yaml`: Kafka 메시지 브로커
- `loki.yaml`: 로그 수집 시스템
- `promtail.yaml`: 로그 수집 에이전트 (DaemonSet)
- `grafana.yaml`: 로그 시각화 대시보드
- `back-office-app.yaml`: Back Office 애플리케이션
- `kustomization.yaml`: Kustomize 설정

## 문제 해결

### Pod가 시작되지 않는 경우

```bash
# Pod 상태 확인
kubectl describe pod <pod-name> -n back-office

# Pod 로그 확인
kubectl logs <pod-name> -n back-office

# 이벤트 확인
kubectl get events -n back-office --sort-by='.lastTimestamp'
```

### 이미지를 찾을 수 없는 경우

```bash
# 이미지 확인
kubectl describe pod <pod-name> -n back-office | grep Image

# Minikube에 이미지 로드
minikube image load back-office:latest

# 또는 이미지 Pull Policy 확인
# back-office-app.yaml에서 imagePullPolicy를 Always로 변경
```

### 데이터베이스 연결 실패

```bash
# MySQL Pod 로그 확인
kubectl logs -f deployment/mysql -n back-office

# MySQL 연결 테스트
kubectl exec -it deployment/mysql -n back-office -- mysql -uroot -p
```

### PersistentVolume 문제

로컬 환경에서는 기본적으로 `hostPath` 또는 동적 프로비저닝을 사용합니다.
Minikube의 경우 자동으로 처리되지만, 다른 환경에서는 StorageClass를 확인하세요:

```bash
# StorageClass 확인
kubectl get storageclass

# PVC 상태 확인
kubectl get pvc -n back-office
```

## 리소스 정리

모든 리소스를 삭제하려면:

```bash
# 모든 리소스 삭제
kubectl delete -f .

# 또는 네임스페이스 삭제 (모든 리소스 포함)
kubectl delete namespace back-office
```

## 참고사항

- 로컬 환경에서는 리소스 제한이 낮게 설정되어 있습니다. 프로덕션 환경에서는 적절히 조정하세요.
- Secret 파일은 Git에 커밋하지 마세요. `.gitignore`에 추가하는 것을 권장합니다.
- 프로덕션 환경에서는 Secret을 Kubernetes Secret 또는 외부 Secret 관리 시스템(예: Vault)을 사용하세요.

