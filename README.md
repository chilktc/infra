# Cloud-Native Platform Infrastructure

AWS 기반의 **Production-Ready Cloud-Native 플랫폼 아키텍처**를 코드 중심으로 설계하고 관리하기 위한 인프라 repo입니다.

**Infra → Platform → Workload → GitOps** 구조를 기반으로  
확장 가능하고 운영 가능한 클라우드 플랫폼 구성을 목표로 합니다.

---

## 프로젝트 목적

- Kubernetes 기반 애플리케이션 플랫폼 구축
- GitOps 기반 자동 배포 구조
- Istio Service Mesh 기반 트래픽 제어
- 통합 Observability 환경 (Monitoring, Tracing, Alerting)
- 클라우드 네이티브 오토스케일링
- 보안 중심 Private 네트워크 아키텍처

---

## 아키텍처 개요

```
Users
↓
DNS
↓
ALB (HTTPS/ACM)
↓
Istio Ingress Gateway
↓
Frontend (Next.js)
↓
Backend (Spring Boot)
↓
RDS / Redis / S3
```
### `CI`/`CD` 흐름

```
Developer → GitHub → GitHub Actions → ECR
↓
ArgoCD
↓
EKS
```
---

## 주요 구성 요소

| 영역 | 구성 요소 |
|------|-----------|
| Network | VPC, Subnets, ALB, NAT, VPC Endpoints |
| Compute | Amazon EKS |
| Service Mesh | Istio |
| CI/CD | GitHub Actions, ArgoCD |
| Observability | Prometheus, Grafana, Alertmanager, Jaeger |
| Autoscaling | HPA, Karpenter |
| Backup | Velero |
| Data | RDS, S3, Redis |
| Security | Bastion Host, KMS, Private Access |
---

## `Repository Structure`
```
infra/
├── README.md # 프로젝트 개요
├── aws/ # 클라우드 인프라 레이어
├── platform/ # Kubernetes 플랫폼 구성 요소
├── apps/ # 애플리케이션 매니페스트
└── gitops/ # ArgoCD GitOps 루트
```

---

### `aws/`

클라우드 인프라 리소스 영역

- VPC, Subnet, NAT, ALB
- EKS Cluster
- RDS, S3
- KMS, IAM, VPC Endpoints

---

### `platform/`

EKS 내부 플랫폼 구성 요소

- Istio
- ArgoCD
- Prometheus / Grafana / Alertmanager
- Jaeger
- HPA / Karpenter
- Velero

---

### `apps/`

비즈니스 워크로드 영역

- Frontend (Next.js)
- Backend (Spring Boot)
- Redis / Mongo 등

---

### `gitops/`

ArgoCD가 감시하는 GitOps 루트

- Platform Apps
- Workload Apps
- Bootstrap 설정

---

## 보안 설계 원칙

- Private Subnet 중심 설계
- Bastion 기반 운영 접근
- VPC Endpoint 통한 AWS 서비스 Private 접근
- KMS 기반 데이터 암호화
- Service Mesh 기반 트래픽 제어

