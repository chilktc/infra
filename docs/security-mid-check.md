## 1.결과물

깃헙 레포: https://github.com/chilktc/infra

SIEM 테라폼: https://github.com/chilktc/infra/tree/main/aws/siem

오픈소스 스캐너: https://github.com/504s2n/s2n

### AWS SIEM 보안 아키텍처

Terraform으로 정의한 AWS 기반 SIEM 파이프라인이며, 로그 수집부터 저장·분석까지 전 구간을 코드로 관리한다.

#### 로그 수집 흐름

```text
EC2 Web Server / VPC Flow Logs
        ↓  (CloudWatch Log Group)
CloudWatch Subscription Filter
        ↓  (IAM Role: cw-to-kinesis)
Kinesis Data Stream  (shard 1, 24h 보존)
        ↓  (ECS Fargate: Logstash)
OpenSearch  (일별 인덱스: siem-logs-YYYY.MM.dd)
```

#### 구성 요소별 요약

| 구성 요소     | 리소스                                            | 비고                                                |
| ------------- | ------------------------------------------------- | --------------------------------------------------- |
| 네트워크      | VPC (10.0.0.0/16), Public/Private Subnet, NAT GW  | Private Subnet에 OpenSearch·ECS 격리                |
| 로그 소스     | EC2 Web Server (Amazon Linux 2, t3.micro)         | CloudWatch Agent로 `/aws/ec2/webserver` 전송        |
| 네트워크 로그 | VPC Flow Logs                                     | ALL 트래픽, `/aws/vpc/flowlogs` 수집                |
| 스트리밍      | Kinesis Data Stream                               | EC2 로그·VPC Flow Logs 2개 Subscription Filter 연결 |
| 파이프라인    | ECS Fargate + Logstash (opensearch-output-plugin) | Private Subnet, CPU 1024 / Mem 2048                 |
| 분석 저장소   | OpenSearch 2.11 (t3.small, 10GB gp3)              | VPC 내부 배치, IAM 기반 액세스                      |
| 로그 아카이브 | S3 (AES256 서버 사이드 암호화)                    | 장기 보존용                                         |

#### IAM 역할 구성

- `vpc-flow-logs-role`: VPC Flow Logs → CloudWatch 쓰기
- `cw-to-kinesis-role`: CloudWatch Logs → Kinesis `PutRecord`
- `ec2-role`: EC2 인스턴스 프로파일 (SSM, CloudWatch Agent 관리형 정책 연결)
- `ecs-execution-role`: ECS 태스크 이미지 pull·CW 로그 쓰기
- `ecs-task-role`: Logstash가 Kinesis 읽기(`Get*`) + OpenSearch 쓰기(`ESHttpPost/Put`)

#### 보안 그룹 정책

| SG             | 인바운드                                | 아웃바운드                     |
| -------------- | --------------------------------------- | ------------------------------ |
| EC2            | SSH(22), HTTP(80) — 0.0.0.0/0           | 전체 허용                      |
| ECS (Logstash) | 없음                                    | 전체 허용 (NAT 경유 외부 통신) |
| OpenSearch     | HTTPS(443) — VPC CIDR(10.0.0.0/16) 한정 | —                              |

## 2. 과정 (강조)

### IaC / 정책 관리

- Terraform으로 인프라 전 구간 코드화
- IAM 권한, 보안 그룹, 역할 정책 문서화
- Network / Application 계층별 정책 수립 및 문서화

### 로그 수집 / 데이터 보호

- 탐지 시나리오별로 필요한 로그만 수집·저장하도록 기준 수립
- 로그에 상담 데이터 등 민감 정보가 남지 않도록 정책 수립
- 로그·테스트 환경에서 민감 데이터 마스킹 적용
- DB / Storage 계층 민감 정보 마스킹

### 스캐너 (정적 분석)

- 자체 개발 오픈소스 스캐너 외 검증된 툴 병행 활용 검토
- 후보: Semgrep, CodeQL, Trivy, Snyk, OWASP Dependency Check

### 카오스 엔지니어링 / 위험 모델링

- 보안 관련 시나리오: 토큰 검증 실패, 인증 서버 장애, 로그 시스템 장애, KMS 지연
- 위험 모델링을 통한 보안 설계 검토

### 사고 대응 프로세스 (Incident Response)

- 이상 탐지 시 알림 발송
- 대응 절차 수립 및 실행
- 접근 키 회전
- 계정 차단
