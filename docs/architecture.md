# MindQuery SystemArchitecture

- AWS 배포
- 개발팀(BE/FE), AI팀, 클라우드 인프라/보안팀 개발 아키텍처

## 유저 플로우

```mermaid
flowchart TD
    Start([사용자 방문]) --> Login[구글 OAuth 로그인]
    Login --> AuthCheck{인증 성공?}

    AuthCheck -->|실패| LoginFail[로그인 실패 Alert]
    LoginFail --> Login

    AuthCheck -->|성공| UserCheck{첫 방문?}

    UserCheck -->|기존 사용자| GreenRoomHome[그린룸 홈페이지]
    UserCheck -->|신규 사용자| Consent[개인정보 동의 페이지]

    Consent --> ConsentCheck{동의 완료?}
    ConsentCheck -->|미동의| Consent
    ConsentCheck -->|동의| GreenRoomHome

    GreenRoomHome --> CreateTicket[그린룸 입장권 작성]

    CreateTicket --> InputSituation[상황/생각/행동/동료반응 입력]
    InputSituation --> ValidateInput{입력값 검증}

    ValidateInput -->|유효하지 않음| CreateTicket
    ValidateInput -->|유효함| Loading[로딩 화면<br/>최대 8초]

    Loading --> FetchPersonalData[개인화 정보 조회<br/>DB에서 사용자 데이터 추출]
    FetchPersonalData --> GeneratePodcast[AI 팟캐스트 스크립트 생성<br/>3-5분 분량]

    GeneratePodcast --> GenerateImage[AI 개인화 이미지 생성<br/>만평 형식]

    GenerateImage --> DisplayPodcast[팟캐스트 + 이미지 제공]

    DisplayPodcast --> ScheduleTracking[트래킹 알림 스케줄 등록<br/>직후/3일/7일/2주 단위]

    ScheduleTracking --> ReceivePush[웹 푸시 알림 수신]

    ReceivePush --> UserResponse{사용자 응답}

    UserResponse -->|해결됨| ResolvedFlow[해결 이유 선택 + 텍스트 입력]
    ResolvedFlow --> ShareCheck{익명화 이야기<br/>공유 허락?}
    ShareCheck -->|허락| SaveToRAG[RAG 데이터베이스에 저장]
    ShareCheck -->|거부| StopTracking[해당 입장권 트래킹 종료]
    SaveToRAG --> StopTracking

    UserResponse -->|미해결| UnresolvedFlow[미해결 이유 선택 + 텍스트 입력]
    UnresolvedFlow --> ContinueTracking[다음 푸시 알림 대기]

    ContinueTracking --> ReceivePush

    StopTracking --> End1([종료])

    %% 조직 관리자 플로우
    AdminStart([조직 관리자 로그인]) --> AdminDashboard[B2B 대시보드]
    AdminDashboard --> ViewOntology[마인드 온톨로지 조회]

    ViewOntology --> AnalyzeData{조직 심리 분석}
    AnalyzeData --> ShowResolved[자연스럽게 해결되는 어려움]
    AnalyzeData --> ShowUnresolved[구조적으로 해결되지 않는 어려움]

    ShowResolved --> OrgInsight[조직 인사이트 도출]
    ShowUnresolved --> OrgInsight

    OrgInsight --> AdminEnd([종료])

    style Start fill:#e1f5e1
    style End1 fill:#ffe1e1
    style AdminStart fill:#e1f5e1
    style AdminEnd fill:#ffe1e1
    style Loading fill:#fff4e1
    style GeneratePodcast fill:#e1f0ff
    style GenerateImage fill:#e1f0ff
    style DisplayPodcast fill:#f0e1ff
```

## 데이터 플로우

```mermaid
flowchart LR
    subgraph Client ["클라이언트 (Frontend)"]
        User[사용자 입력]
        Display[UI 표시]
    end

    subgraph Auth ["인증 서비스"]
        GoogleOAuth[Google OAuth]
        AuthService[인증 서비스]
    end

    subgraph Backend ["백엔드 API"]
        API[REST API]
        Validation[입력 검증<br/>XSS 방지]
        BusinessLogic[비즈니스 로직]
    end

    subgraph Database ["데이터베이스"]
        UserDB[(사용자 DB)]
        TicketDB[(입장권 DB)]
        TrackingDB[(트래킹 DB)]
        ConsentDB[(동의 정보 DB)]
        AuditLog[(감사 로그)]
    end

    subgraph AIServices ["AI 서비스"]
        DataRetrieval[개인화 데이터 조회]
        PodcastGen[팟캐스트 생성 AI]
        ImageGen[이미지 생성 AI]
        Anonymization[익명화 처리]
    end

    subgraph RAG ["RAG 시스템"]
        VectorDB[(벡터 DB)]
        SimilaritySearch[유사성 검색]
    end

    subgraph Notification ["알림 시스템"]
        Scheduler[스케줄러]
        PushService[웹 푸시 서비스]
    end

    subgraph Analytics ["조직 분석"]
        OntologyEngine[온톨로지 생성 엔진]
        DashboardDB[(대시보드 DB)]
        B2BDashboard[B2B 대시보드]
    end

    %% 인증 플로우
    User -->|1. 로그인 요청| GoogleOAuth
    GoogleOAuth -->|2. 토큰| AuthService
    AuthService -->|3. 검증 및 조회| UserDB
    UserDB -->|4. 사용자 정보| API
    API -->|5. 세션 생성| Display

    %% 입장권 작성 플로우
    User -->|6. 입장권 입력| API
    API -->|7. 검증| Validation
    Validation -->|8. 저장| TicketDB
    Validation -->|9. 감사 로그| AuditLog

    %% AI 처리 플로우
    TicketDB -->|10. 입장권 데이터| DataRetrieval
    UserDB -->|11. 사용자 이력| DataRetrieval
    VectorDB -->|12. 유사 사례| SimilaritySearch
    SimilaritySearch -->|13. RAG 컨텍스트| DataRetrieval

    DataRetrieval -->|14. 개인화 데이터| PodcastGen
    DataRetrieval -->|15. 개인화 데이터| ImageGen

    PodcastGen -->|16. 팟캐스트 스크립트| BusinessLogic
    ImageGen -->|17. 생성 이미지| BusinessLogic

    BusinessLogic -->|18. AI 생성 로그| AuditLog
    BusinessLogic -->|19. 콘텐츠 전달| Display

    %% 트래킹 플로우
    BusinessLogic -->|20. 스케줄 등록| Scheduler
    Scheduler -->|21. 트래킹 데이터 저장| TrackingDB
    Scheduler -->|22. 알림 발송| PushService
    PushService -->|23. 웹 푸시| Display

    %% 사용자 응답 처리
    User -->|24. 해결 상태 응답| API
    API -->|25. 응답 저장| TrackingDB
    API -->|26. 익명화 요청| Anonymization
    Anonymization -->|27. 익명화 데이터| VectorDB
    Anonymization -->|28. 공유 로그| AuditLog

    %% 조직 분석 플로우
    TicketDB -.->|29. 주기적 집계| OntologyEngine
    TrackingDB -.->|30. 해결/미해결 데이터| OntologyEngine
    OntologyEngine -.->|31. 온톨로지 데이터| DashboardDB
    DashboardDB -.->|32. 조직 인사이트| B2BDashboard

    %% 모든 데이터 접근 로깅
    UserDB -.->|감사 로그| AuditLog
    TicketDB -.->|감사 로그| AuditLog
    TrackingDB -.->|감사 로그| AuditLog

    style Client fill:#e1f5e1
    style Auth fill:#fff4e1
    style Backend fill:#e1f0ff
    style Database fill:#f0e1ff
    style AIServices fill:#ffe1e1
    style RAG fill:#e1ffe1
    style Notification fill:#ffe1f0
    style Analytics fill:#f0ffe1
    style AuditLog fill:#ffcccc
```

## 시스템 아키텍처

AWS## 시스템 아키텍처

```mermaid
flowchart TB
    subgraph Internet ["인터넷"]
        Users([사용자])
        AdminUsers([조직 관리자])
    end

    subgraph AWS ["AWS Cloud"]
        subgraph Security ["보안 계층 (인프라팀)"]
            WAF[AWS WAF]
            Cognito[Amazon Cognito<br/>Google OAuth 연동]
            Secrets[AWS Secrets Manager<br/>API Keys, DB Credentials]
        end

        subgraph CDN ["CDN & 엣지 (인프라팀)"]
            CloudFront[Amazon CloudFront<br/>글로벌 CDN]
            S3Static[S3 Bucket<br/>정적 파일<br/>프론트엔드 빌드]
        end

        subgraph Network ["네트워크 계층 (인프라팀)"]
            ALB[Application Load Balancer]

            subgraph VPC ["VPC - 10.0.0.0/16"]
                subgraph PublicSubnet ["Public Subnet"]
                    NAT[NAT Gateway]
                end

                subgraph PrivateSubnet1 ["Private Subnet - App Tier"]
                    subgraph DevTeam ["개발팀 영역"]
                        subgraph Frontend ["Frontend 서비스"]
                            NextJS[Next.js App<br/>ECS Fargate<br/>SSR/ISR]
                        end

                        subgraph Backend ["Backend 서비스"]
                            API1[FastAPI Service<br/>ECS Fargate<br/>Auto Scaling]
                            API2[FastAPI Service<br/>ECS Fargate<br/>Auto Scaling]
                        end
                    end

                    subgraph AITeam ["AI팀 영역"]
                        AIOrchestrator[AI Orchestrator<br/>Lambda/ECS<br/>AI 요청 관리]
                    end

                    Redis[(Amazon ElastiCache<br/>Redis<br/>세션 & 캐시)]
                end

                subgraph PrivateSubnet2 ["Private Subnet - Data Tier"]
                    RDS[(Amazon RDS<br/>PostgreSQL<br/>Multi-AZ<br/>사용자/입장권/트래킹)]

                    VectorDB[(Amazon Aurora<br/>pgvector<br/>RAG 벡터 저장소)]

                    S3Data[S3 Bucket<br/>AI 생성 콘텐츠<br/>이미지/오디오]
                end
            end
        end

        subgraph AIServices ["AI 서비스 (AI팀)"]
            Bedrock[Amazon Bedrock<br/>Claude/GPT<br/>팟캐스트 생성]

            BedrockImage[Amazon Bedrock<br/>Stable Diffusion<br/>이미지 생성]

            SageMaker[Amazon SageMaker<br/>커스텀 AI 모델<br/>온톨로지 분석]

            Comprehend[Amazon Comprehend<br/>감정 분석<br/>텍스트 분류]
        end

        subgraph Monitoring ["모니터링 & 로깅 (인프라팀)"]
            CloudWatch[Amazon CloudWatch<br/>메트릭 & 로그]
            CloudTrail[AWS CloudTrail<br/>감사 로그]
            XRay[AWS X-Ray<br/>분산 추적]
        end

        subgraph Notification ["알림 서비스 (인프라팀)"]
            EventBridge[Amazon EventBridge<br/>이벤트 스케줄링]
            SNS[Amazon SNS<br/>알림 발송]
            SQS[Amazon SQS<br/>메시지 큐]
        end

        subgraph Analytics ["분석 & 대시보드 (개발팀 + AI팀)"]
            Athena[Amazon Athena<br/>쿼리 엔진]
            QuickSight[Amazon QuickSight<br/>B2B 대시보드]
            S3Analytics[S3 Bucket<br/>분석 데이터]
        end
    end

    %% 사용자 흐름
    Users --> WAF
    AdminUsers --> WAF
    WAF --> CloudFront
    CloudFront --> S3Static
    CloudFront --> ALB

    %% 인증 흐름
    ALB --> Cognito
    Cognito -.->|OAuth Token| NextJS

    %% 프론트엔드 흐름
    ALB --> NextJS
    NextJS --> API1
    NextJS --> API2
    NextJS <--> Redis

    %% 백엔드 데이터 흐름
    API1 --> RDS
    API2 --> RDS
    API1 <--> Redis
    API2 <--> Redis
    API1 -.->|Secrets 조회| Secrets
    API2 -.->|Secrets 조회| Secrets

    %% AI 처리 흐름
    API1 --> AIOrchestrator
    API2 --> AIOrchestrator

    AIOrchestrator -->|팟캐스트 생성 요청| Bedrock
    AIOrchestrator -->|이미지 생성 요청| BedrockImage
    AIOrchestrator -->|RAG 검색| VectorDB
    AIOrchestrator -->|감정 분석| Comprehend

    Bedrock -->|생성 결과| S3Data
    BedrockImage -->|생성 이미지| S3Data

    AIOrchestrator -->|온톨로지 분석| SageMaker
    SageMaker --> S3Analytics

    %% 트래킹 & 알림 흐름
    API1 -->|스케줄 등록| EventBridge
    API2 -->|스케줄 등록| EventBridge
    EventBridge --> SNS
    EventBridge --> SQS
    SQS --> API1
    SNS -.->|웹 푸시| Users

    %% 분석 흐름
    RDS -.->|ETL| S3Analytics
    VectorDB -.->|ETL| S3Analytics
    S3Analytics --> Athena
    Athena --> QuickSight
    QuickSight -.-> AdminUsers

    %% 모니터링
    NextJS -.->|로그| CloudWatch
    API1 -.->|로그| CloudWatch
    API2 -.->|로그| CloudWatch
    AIOrchestrator -.->|로그| CloudWatch

    RDS -.->|감사 로그| CloudTrail
    VectorDB -.->|감사 로그| CloudTrail
    S3Data -.->|접근 로그| CloudTrail

    NextJS -.->|추적| XRay
    API1 -.->|추적| XRay
    API2 -.->|추적| XRay

    %% 스타일링 - 팀별 구분
    style DevTeam fill:#e1f0ff,stroke:#0066cc,stroke-width:3px
    style AITeam fill:#ffe1e1,stroke:#cc0000,stroke-width:3px
    style Security fill:#fff4e1,stroke:#ff9900,stroke-width:3px
    style CDN fill:#fff4e1,stroke:#ff9900,stroke-width:3px
    style Network fill:#fff4e1,stroke:#ff9900,stroke-width:3px
    style Monitoring fill:#fff4e1,stroke:#ff9900,stroke-width:3px
    style Notification fill:#fff4e1,stroke:#ff9900,stroke-width:3px

    style AIServices fill:#ffe1e1,stroke:#cc0000,stroke-width:3px
    style Analytics fill:#f0e1ff,stroke:#6600cc,stroke-width:3px

    style Frontend fill:#cce5ff
    style Backend fill:#cce5ff
    style AIOrchestrator fill:#ffcccc

    style RDS fill:#d4edda
    style VectorDB fill:#d4edda
    style Redis fill:#fff3cd
```

### 팀별 책임 영역 (R&R)

#### 🏗️ **인프라팀 (Infrastructure Team)**

- **네트워크 & 보안**: VPC, Subnet, NAT Gateway, ALB, WAF, Cognito
- **CDN & 스토리지**: CloudFront, S3 (정적 파일)
- **모니터링**: CloudWatch, CloudTrail, X-Ray
- **알림 인프라**: EventBridge, SNS, SQS
- **비밀 관리**: Secrets Manager
- **배포 환경**: ECS 클러스터, Auto Scaling 설정

#### 💻 **개발팀 (Frontend/Backend Team)**

- **Frontend**: Next.js 애플리케이션 (SSR/ISR)
- **Backend**: FastAPI 서비스 (비즈니스 로직, API)
- **데이터베이스 스키마**: RDS PostgreSQL 스키마 설계
- **캐싱 로직**: ElastiCache Redis 활용
- **인증/인가**: Cognito 연동 및 세션 관리
- **비즈니스 로직**: 입장권, 트래킹, 사용자 관리

#### 🤖 **AI팀 (AI Team)**

- **AI 오케스트레이션**: AI 요청 관리 및 조율
- **팟캐스트 생성**: Bedrock Claude/GPT 활용
- **이미지 생성**: Bedrock Stable Diffusion 활용
- **RAG 시스템**: 벡터 DB 구축 및 유사성 검색
- **감정 분석**: Comprehend 활용
- **온톨로지 분석**: SageMaker 커스텀 모델
- **AI 모델 최적화**: 비용 및 품질 관리

#### 📊 **협업 영역 (개발팀 + AI팀)**

- **B2B 대시보드**: QuickSight 기반 조직 인사이트
- **데이터 분석**: Athena를 통한 쿼리 및 분석
