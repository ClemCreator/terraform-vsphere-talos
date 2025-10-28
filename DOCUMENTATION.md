# 📚 Documentation Complète - Terraform vSphere Talos

> **Projet**: Déploiement automatisé d'un cluster Kubernetes Talos Linux sur VMware vSphere
> 
> **Auteur**: ClemCreator
> 
> **Date**: 20 Octobre 2025

---

## 📋 Table des Matières

1. [Vue d'Ensemble](#-vue-densemble)
2. [Architecture Globale](#-architecture-globale)
3. [Architecture Réseau](#-architecture-réseau)
4. [Composants Terraform](#-composants-terraform)
5. [Stack Applicative](#-stack-applicative)
6. [Flux de Déploiement](#-flux-de-déploiement)
7. [Structure des Fichiers](#-structure-des-fichiers)
8. [Versions et Dépendances](#-versions-et-dépendances)
9. [Sécurité et Certificats](#-sécurité-et-certificats)
10. [Guide d'Utilisation](#-guide-dutilisation)

---

## 🎯 Vue d'Ensemble

Ce projet automatise le déploiement d'un cluster Kubernetes basé sur **Talos Linux** dans un environnement VMware vSphere. Il utilise Terraform pour l'infrastructure as code et déploie automatiquement une stack complète d'applications.

### Objectifs Principaux

- ✅ **Infrastructure as Code** : Tout est versionné et reproductible
- ✅ **Sécurité** : Gestion automatique des certificats TLS via cert-manager
- ✅ **Observabilité** : Hubble UI pour la visualisation du réseau
- ✅ **GitOps** : Argo CD pour le déploiement continu (App of Apps pattern)
- ✅ **Storage Persistant** : DRBD + LINSTOR + Piraeus Operator
- ✅ **WebAssembly** : Support des applications Spin (Wasm)

### 🚀 Nouveauté : Architecture GitOps

Ce projet implémente le pattern **"App of Apps"** d'ArgoCD pour une gestion déclarative et automatisée des applications :

```
Git Repository (Source of Truth)
        ↓
    Terraform Bootstrap
        ↓
    ┌─────────────────┐
    │   app-root      │  ← Application racine ArgoCD
    │  (App of Apps)  │
    └────────┬────────┘
             ↓
    ┌────────┴────────┐
    │  manifests/apps │
    └────────┬────────┘
             ↓
    ┌────────┴────────────────┐
    │  Applications ArgoCD    │
    ├─────────────────────────┤
    │  • gitea                │
    │  • trust-manager        │
    │  • reloader             │
    └─────────────────────────┘
```

**Avantages** :
- 🔄 Sync automatique depuis Git
- 📊 Visibilité complète dans l'UI ArgoCD
- ↩️ Rollback facile (git revert)
- 🔒 Self-healing automatique
- ➕ Ajout d'applications simplifié

---

## 🏗️ Architecture Globale

```mermaid
graph TB
    subgraph "🖥️ vSphere Infrastructure"
        vCenter[vCenter Server]
        DC[Datacenter]
        Cluster[Compute Cluster]
        DS[Datastore]
        Net[VM Network]
        
        vCenter --> DC
        DC --> Cluster
        DC --> DS
        DC --> Net
    end
    
    subgraph "🎯 Terraform Orchestration"
        TF[Terraform]
        Providers[Providers]
        
        TF --> Providers
    end
    
    subgraph "☸️ Talos Kubernetes Cluster"
        direction TB
        
        subgraph "🎛️ Control Plane"
            C0[Controller c0<br/>10.17.3.80]
            API[Kube API<br/>VIP: 10.17.3.9:6443]
        end
        
        subgraph "⚙️ Worker Nodes"
            W0[Worker w0<br/>10.17.3.90]
            W1[Worker w1<br/>10.17.3.91]
            W2[Worker w2<br/>10.17.3.92]
        end
        
        subgraph "📦 Applications"
            Cilium[Cilium CNI<br/>+ Ingress + L2LB]
            CertMgr[cert-manager<br/>v1.19.1]
            Trust[trust-manager<br/>v0.19.0]
            ArgoCD[Argo CD<br/>v9.0.3]
            Gitea[Gitea<br/>v11.0.0]
            Reloader[Reloader<br/>v1.2.1]
        end
        
        subgraph "💾 Storage Stack"
            LVM[LVM]
            DRBD[DRBD v9.2.14]
            LINSTOR[LINSTOR]
            Piraeus[Piraeus Operator<br/>v2.5.2]
        end
    end
    
    Providers -.->|vsphere| vCenter
    Providers -.->|talos| C0
    Providers -.->|helm| API
    
    TF -->|Creates VMs| Cluster
    TF -->|Stores Data| DS
    TF -->|Network Config| Net
    
    C0 --> W0
    C0 --> W1
    C0 --> W2
    
    W0 --> LVM
    W1 --> LVM
    W2 --> LVM
    
    LVM --> DRBD
    DRBD --> LINSTOR
    LINSTOR --> Piraeus
    
    style vCenter fill:#326CE5,stroke:#fff,stroke-width:2px,color:#fff
    style TF fill:#7B42BC,stroke:#fff,stroke-width:2px,color:#fff
    style API fill:#FF6B6B,stroke:#fff,stroke-width:2px,color:#fff
    style Cilium fill:#F8C502,stroke:#000,stroke-width:2px
    style ArgoCD fill:#EF7B4D,stroke:#fff,stroke-width:2px,color:#fff
```

---

## 🌐 Architecture Réseau

```mermaid
graph LR
    subgraph "🌍 External Network"
        Client[Client Browser]
        DNS[DNS Server<br/>1.1.1.1]
    end
    
    subgraph "🔌 Cluster Network - 10.17.3.0/24"
        GW[Gateway<br/>10.17.3.1]
        
        subgraph "🎛️ Control Plane"
            VIP[VIP<br/>10.17.3.9:6443]
            C0[c0<br/>10.17.3.80]
        end
        
        subgraph "⚙️ Workers"
            W0[w0<br/>10.17.3.90]
            W1[w1<br/>10.17.3.91]
            W2[w2<br/>10.17.3.92]
        end
        
        subgraph "⚖️ LoadBalancer Pool"
            LB[L2 LoadBalancer<br/>10.17.3.130-230]
        end
        
        subgraph "🔐 Services"
            ArgoSvc[argocd.example.test]
            GiteaSvc[gitea.example.test]
        end
    end
    
    Client -->|HTTPS| GW
    GW -->|Route| LB
    LB -->|Cilium L2 Announce| W0
    LB -->|Cilium L2 Announce| W1
    LB -->|Cilium L2 Announce| W2
    
    W0 -.->|Ingress| ArgoSvc
    W0 -.->|Ingress| GiteaSvc
    
    C0 -->|API Server| VIP
    W0 -->|kubePrism<br/>localhost:7445| VIP
    W1 -->|kubePrism<br/>localhost:7445| VIP
    W2 -->|kubePrism<br/>localhost:7445| VIP
    
    W0 -->|NTP| pool.ntp.org
    W1 -->|NTP| pool.ntp.org
    W2 -->|NTP| pool.ntp.org
    
    W0 -->|DNS| DNS
    W1 -->|DNS| DNS
    W2 -->|DNS| DNS
    
    style VIP fill:#FF6B6B,stroke:#fff,stroke-width:3px,color:#fff
    style LB fill:#4ECDC4,stroke:#fff,stroke-width:2px,color:#fff
    style Client fill:#95E1D3,stroke:#000,stroke-width:2px
```

---

## 🔧 Composants Terraform

### Providers Utilisés

```mermaid
graph TD
    subgraph "📦 Terraform Providers"
        TF[Terraform v1.13.4]
        
        subgraph "Cloud Providers"
            VSphere[vmware/vsphere<br/>v2.12.0]
        end
        
        subgraph "Kubernetes Providers"
            Talos[siderolabs/talos<br/>v0.9.0]
            Helm[hashicorp/helm<br/>v3.0.0]
        end
        
        subgraph "Utility Providers"
            Random[hashicorp/random<br/>v3.6.3]
        end
    end
    
    TF --> VSphere
    TF --> Talos
    TF --> Helm
    TF --> Random
    
    VSphere -.->|Gère| VM[VMs vSphere]
    Talos -.->|Configure| TalosOS[Talos OS]
    Helm -.->|Déploie| Apps[Applications K8s]
    Random -.->|Génère| Secrets[Secrets/Tokens]
    
    style TF fill:#7B42BC,stroke:#fff,stroke-width:3px,color:#fff
    style VSphere fill:#326CE5,stroke:#fff,stroke-width:2px,color:#fff
    style Talos fill:#FF6B35,stroke:#fff,stroke-width:2px,color:#fff
    style Helm fill:#0F1689,stroke:#fff,stroke-width:2px,color:#fff
```

### Structure des Fichiers Terraform

```mermaid
graph TD
    subgraph "📁 Configuration Files"
        Providers[providers.tf<br/>Provider definitions]
        Variables[variables.tf<br/>Input variables]
        Outputs[outputs.tf<br/>Outputs]
    end
    
    subgraph "🏗️ Infrastructure Files"
        VSphere[vsphere.tf<br/>VMs creation]
        Talos[talos.tf<br/>Talos configuration]
    end
    
    subgraph "🎨 Application Files"
        Cilium[cilium.tf<br/>CNI + Ingress]
        CertManager[cert-manager.tf<br/>Certificate management]
        Trust[trust-manager.tf<br/>CA bundle distribution]
        ArgoCD[argocd.tf<br/>GitOps platform]
        Gitea[gitea.tf<br/>Git server]
        Reloader[reloader.tf<br/>ConfigMap/Secret reloader]
    end
    
    subgraph "🛠️ Scripts"
        Do[do<br/>Main orchestration script]
        Secrets[secrets.sh<br/>Environment variables]
        Renovate[renovate.sh<br/>Dependency updates]
    end
    
    Providers --> VSphere
    Providers --> Talos
    Variables --> VSphere
    Variables --> Talos
    
    Talos --> Cilium
    Cilium --> CertManager
    CertManager --> Trust
    Trust --> ArgoCD
    Trust --> Gitea
    
    Do -.->|Executes| Providers
    Secrets -.->|Configures| Do
    
    style Providers fill:#7B42BC,stroke:#fff,stroke-width:2px,color:#fff
    style Do fill:#2ECC71,stroke:#fff,stroke-width:2px,color:#fff
```

---

## 📦 Stack Applicative

```mermaid
graph TB
    subgraph "🌐 Network Layer"
        Cilium[Cilium v1.16.4<br/>🔹 CNI Plugin<br/>🔹 L2 LoadBalancer<br/>🔹 Ingress Controller<br/>🔹 Hubble Observability]
    end
    
    subgraph "🔐 Security Layer"
        CertManager[cert-manager v1.19.1<br/>🔹 Certificate automation<br/>🔹 Let's Encrypt integration]
        TrustManager[trust-manager v0.19.0<br/>🔹 CA bundle distribution<br/>🔹 Secret sync]
    end
    
    subgraph "🚀 GitOps Layer"
        ArgoCD[Argo CD v9.0.3<br/>App: v3.1.9<br/>🔹 Continuous deployment<br/>🔹 Git sync<br/>🔹 Web UI]
    end
    
    subgraph "📝 Development Layer"
        Gitea[Gitea v11.0.0<br/>App: v1.23.4<br/>🔹 Git repositories<br/>🔹 CI/CD webhooks<br/>🔹 User management]
    end
    
    subgraph "🔄 Automation Layer"
        Reloader[Reloader v1.2.1<br/>🔹 Auto-reload on config change<br/>🔹 ConfigMap watcher<br/>🔹 Secret watcher]
    end
    
    subgraph "💾 Storage Layer"
        Storage[Storage Stack<br/>🔹 LVM<br/>🔹 DRBD v9.2.14<br/>🔹 LINSTOR<br/>🔹 Piraeus Operator v2.5.2]
    end
    
    subgraph "🌐 WebAssembly Layer"
        Spin[Spin Extension v0.21.0<br/>🔹 containerd-shim-spin<br/>🔹 Wasm runtime<br/>🔹 Fermyon support]
    end
    
    Cilium -->|Provides networking| CertManager
    CertManager -->|Issues certs| ArgoCD
    CertManager -->|Issues certs| Gitea
    TrustManager -->|Distributes CA| ArgoCD
    TrustManager -->|Distributes CA| Gitea
    
    ArgoCD -->|Deploys from| Gitea
    Reloader -->|Monitors| ArgoCD
    Reloader -->|Monitors| Gitea
    
    Storage -->|Persistent volumes| Gitea
    Storage -->|Persistent volumes| ArgoCD
    
    Cilium -->|Network for| Spin
    
    style Cilium fill:#F8C502,stroke:#000,stroke-width:3px
    style CertManager fill:#2ECC71,stroke:#fff,stroke-width:2px,color:#fff
    style ArgoCD fill:#EF7B4D,stroke:#fff,stroke-width:2px,color:#fff
    style Storage fill:#9B59B6,stroke:#fff,stroke-width:2px,color:#fff
    style Spin fill:#00D9FF,stroke:#000,stroke-width:2px
```

---

## 🔄 Flux de Déploiement

```mermaid
sequenceDiagram
    autonumber
    participant User as 👤 Utilisateur
    participant Script as 🛠️ do script
    participant TF as 🔧 Terraform
    participant vSphere as 🖥️ vSphere
    participant Talos as 🐧 Talos OS
    participant K8s as ☸️ Kubernetes
    participant Apps as 📦 Applications
    
    User->>Script: ./do init
    Script->>Script: Build Talos OVA image<br/>(with extensions)
    Script->>TF: terraform init
    TF-->>Script: ✅ Initialized
    
    User->>Script: ./do plan-apply
    Script->>TF: terraform plan
    TF->>vSphere: Query resources<br/>(datacenter, cluster, etc)
    vSphere-->>TF: Resources info
    TF-->>Script: Plan created
    
    Script->>TF: terraform apply
    
    rect rgb(200, 220, 250)
        Note over TF,vSphere: 🏗️ Infrastructure Creation
        TF->>vSphere: Create VM folder
        TF->>vSphere: Create Controller VMs
        TF->>vSphere: Create Worker VMs
        TF->>vSphere: Attach Talos config<br/>(via guestinfo)
    end
    
    rect rgb(220, 250, 200)
        Note over Talos,K8s: 🚀 Cluster Bootstrap
        vSphere->>Talos: Boot VMs
        Talos->>Talos: Apply machine config
        Talos->>Talos: Install system extensions<br/>(vmtools, drbd, spin)
        TF->>Talos: Bootstrap cluster
        Talos->>K8s: Initialize Kubernetes
        K8s-->>TF: Cluster ready
    end
    
    rect rgb(250, 220, 200)
        Note over TF,Apps: 📦 Application Deployment
        TF->>K8s: Deploy Cilium CNI
        TF->>K8s: Deploy cert-manager
        TF->>K8s: Deploy trust-manager
        TF->>K8s: Deploy Reloader
        TF->>K8s: Deploy Argo CD
        TF->>K8s: Deploy Gitea
    end
    
    rect rgb(250, 250, 200)
        Note over Apps: 🔐 Certificate Provisioning
        Apps->>Apps: cert-manager issues certs
        Apps->>Apps: trust-manager distributes CA
        Apps->>Apps: Services use TLS
    end
    
    TF->>Script: Generate talosconfig.yml
    TF->>Script: Generate kubeconfig.yml
    Script-->>User: ✅ Deployment complete!
    
    User->>K8s: kubectl get nodes
    K8s-->>User: Cluster status
    
    User->>Talos: talosctl dashboard
    Talos-->>User: System metrics
```

---

## 📂 Structure des Fichiers

```
terraform-vsphere-talos/
│
├── 📄 Terraform Configuration
│   ├── providers.tf              # Définition des providers
│   ├── variables.tf              # Variables d'entrée
│   ├── outputs.tf                # Outputs (kubeconfig, talosconfig)
│   ├── vsphere.tf               # Création des VMs
│   ├── talos.tf                 # Configuration Talos (inline manifests)
│   └── manifests-bootstrap.tf   # 🆕 Bootstrap ArgoCD app-root
│
├── 🎨 Applications (Terraform Helm Templates)
│   ├── cilium.tf                # CNI + Ingress + L2 LB
│   ├── cert-manager.tf          # Gestion des certificats
│   ├── trust-manager.tf         # Distribution des CA (template only)
│   ├── argocd.tf                # GitOps platform
│   ├── gitea.tf                 # Serveur Git (template only)
│   └── reloader.tf              # Auto-reload configs (template only)
│
├── 📦 Manifests GitOps (🆕 ArgoCD)
│   ├── README.md                # Documentation manifests
│   ├── apps/                    # Applications ArgoCD
│   │   ├── kustomization.yaml
│   │   ├── gitea.yaml          # App definition
│   │   ├── trust-manager.yaml  # App definition
│   │   └── reloader.yaml       # App definition
│   ├── bootstrap/              # Bootstrap manifests
│   │   └── app-root.yaml       # App of Apps racine
│   ├── gitea/                  # Gitea Helm config
│   │   ├── kustomization.yaml
│   │   ├── values.yaml
│   │   └── certificate.yaml
│   ├── trust-manager/          # trust-manager config
│   │   ├── kustomization.yaml
│   │   └── values.yaml
│   └── reloader/               # reloader config
│       ├── kustomization.yaml
│       └── values.yaml
│
├── 🛠️ Scripts
│   ├── do                       # Script principal d'orchestration
│   ├── secrets.sh               # Variables d'environnement
│   ├── argocd-helper.sh         # 🆕 Helper ArgoCD
│   ├── validate.sh              # 🆕 Validation pre-deploy
│   ├── renovate.sh              # Mise à jour des dépendances
│   └── renovate.json5           # Configuration Renovate
│
├── 📋 Configuration
│   ├── .tflint.hcl              # Linter Terraform
│   ├── .gitignore               # Fichiers ignorés
│   └── .github/                 # GitHub Actions (CI/CD)
│
├── 📁 Runtime Files (Generated)
│   ├── talosconfig.yml          # Configuration Talos CLI
│   ├── kubeconfig.yml           # Configuration kubectl
│   ├── terraform.tfstate        # État Terraform
│   └── tmp/                     # Fichiers temporaires
│       └── talos/               # Images Talos OVA
│
└── 📚 Documentation
    ├── README.md                # Documentation principale
    ├── DOCUMENTATION.md         # Ce fichier
    ├── MIGRATION-GUIDE.md       # 🆕 Guide de migration GitOps
    ├── CHANGELOG.md             # 🆕 Historique des changements
    └── example*.yml             # Exemples de manifests
```

### 🔄 Flux de Déploiement des Applications

```mermaid
graph LR
    subgraph "1️⃣ Inline Manifests"
        Cilium[Cilium CNI]
        CertMgr[cert-manager]
        ArgoCD[ArgoCD]
    end
    
    subgraph "2️⃣ Bootstrap"
        AppRoot[app-root<br/>App of Apps]
    end
    
    subgraph "3️⃣ ArgoCD Managed"
        Gitea[Gitea]
        Trust[trust-manager]
        Reload[reloader]
    end
    
    Terraform --> Cilium
    Terraform --> CertMgr
    Terraform --> ArgoCD
    ArgoCD --> AppRoot
    AppRoot --> Gitea
    AppRoot --> Trust
    AppRoot --> Reload
    
    style Cilium fill:#326CE5
    style CertMgr fill:#326CE5
    style ArgoCD fill:#FF6B35
    style AppRoot fill:#FFD700
    style Gitea fill:#2ECC71
    style Trust fill:#2ECC71
    style Reload fill:#2ECC71
```

---

## 📊 Versions et Dépendances

### Versions Actuelles

| Composant | Version Chart | Version App | Date Release |
|-----------|--------------|-------------|--------------|
| **Infrastructure** |
| Terraform | 1.13.4 | - | - |
| Talos Linux | 1.11.3 | - | Oct 2025 |
| Kubernetes | 1.34.1 | - | Oct 2025 |
| **Providers** |
| vSphere Provider | 2.12.0 | - | Avr 2025 |
| Talos Provider | 0.9.0 | - | - |
| Helm Provider | 3.0.0 | - | Juin 2025 |
| Random Provider | 3.6.3 | - | - |
| **Applications** |
| Cilium | 1.16.4 | - | - |
| cert-manager | 1.19.1 | - | Oct 2025 |
| trust-manager | 0.19.0 | - | Août 2025 |
| Argo CD | 9.0.3 | v3.1.9 | Sept 2025 |
| Gitea | 11.0.0 | 1.23.4 | - |
| Reloader | 1.2.1 | - | Sept 2025 |
| **Extensions** |
| VMtools Guest Agent | 1.4.0 | - | - |
| DRBD | 9.2.14 | - | - |
| Spin Runtime | 0.21.0 | - | - |
| Piraeus Operator | 2.5.2 | - | - |

### Dépendances

```mermaid
graph TD
    subgraph "🔧 Base Infrastructure"
        Terraform[Terraform 1.13.4]
        Talos[Talos Linux 1.11.3]
        K8s[Kubernetes 1.34.1]
    end
    
    subgraph "🌐 Network Stack"
        Cilium[Cilium 1.16.4]
    end
    
    subgraph "🔐 Security Stack"
        CertMgr[cert-manager 1.19.1]
        Trust[trust-manager 0.19.0]
    end
    
    subgraph "📦 Application Stack"
        Argo[Argo CD 9.0.3]
        Gitea[Gitea 11.0.0]
        Reload[Reloader 1.2.1]
    end
    
    subgraph "💾 Storage Stack"
        DRBD[DRBD 9.2.14]
        Piraeus[Piraeus 2.5.2]
    end
    
    Terraform -->|Provisions| Talos
    Talos -->|Runs| K8s
    K8s -->|Requires| Cilium
    Cilium -->|Networking for| CertMgr
    CertMgr -->|Dependency of| Trust
    Trust -->|Secures| Argo
    Trust -->|Secures| Gitea
    Reload -->|Watches| Argo
    Reload -->|Watches| Gitea
    K8s -->|Uses| DRBD
    DRBD -->|Managed by| Piraeus
    
    style Terraform fill:#7B42BC,stroke:#fff,stroke-width:2px,color:#fff
    style K8s fill:#326CE5,stroke:#fff,stroke-width:2px,color:#fff
    style Cilium fill:#F8C502,stroke:#000,stroke-width:2px
```

---

## 🔐 Sécurité et Certificats

### Architecture de Sécurité

```mermaid
graph TB
    subgraph "🔑 Certificate Authority"
        CA[Cluster CA<br/>Self-signed]
        IngressCA[Ingress CA<br/>ClusterIssuer]
    end
    
    subgraph "🎫 Certificate Manager"
        CertMgr[cert-manager]
        CertMgr -->|Issues| Certs[Certificates]
    end
    
    subgraph "📦 Trust Distribution"
        TrustMgr[trust-manager]
        TrustMgr -->|Distributes| Bundles[CA Bundles]
        TrustMgr -->|Syncs to| Secrets[Namespace Secrets]
    end
    
    subgraph "🌐 Applications"
        Argo[Argo CD<br/>argocd.example.test]
        Gitea[Gitea<br/>gitea.example.test]
    end
    
    subgraph "🔒 TLS Certificates"
        ArgoCert[argocd-server-tls<br/>ECDSA P-256<br/>180 days]
        GiteaCert[gitea-tls<br/>ECDSA P-256<br/>180 days]
    end
    
    CA -->|Signs| IngressCA
    IngressCA -->|Used by| CertMgr
    
    CertMgr -->|Creates| ArgoCert
    CertMgr -->|Creates| GiteaCert
    
    ArgoCert -->|Secures| Argo
    GiteaCert -->|Secures| Gitea
    
    TrustMgr -->|Injects CA| Argo
    TrustMgr -->|Injects CA| Gitea
    
    style CA fill:#E74C3C,stroke:#fff,stroke-width:2px,color:#fff
    style CertMgr fill:#2ECC71,stroke:#fff,stroke-width:2px,color:#fff
    style TrustMgr fill:#3498DB,stroke:#fff,stroke-width:2px,color:#fff
    style ArgoCert fill:#F39C12,stroke:#fff,stroke-width:2px,color:#fff
    style GiteaCert fill:#F39C12,stroke:#fff,stroke-width:2px,color:#fff
```

### Caractéristiques de Sécurité

#### 🔒 Certificats TLS
- **Algorithme**: ECDSA P-256 (compatibilité navigateurs modernes)
- **Durée de vie**: 180 jours (rotation automatique à 90 jours)
- **Émetteur**: ClusterIssuer "ingress"
- **Renouvellement**: Automatique via cert-manager

#### 🛡️ Fonctionnalités
- ✅ TLS end-to-end pour tous les services exposés
- ✅ Distribution automatique des CA bundles
- ✅ Rotation automatique des certificats
- ✅ Synchronisation des secrets entre namespaces
- ✅ Validation des certificats avant renouvellement

---

## 🚀 Guide d'Utilisation

### Prérequis

```mermaid
graph LR
    subgraph "🖥️ Système Hôte"
        OS[Ubuntu 22.04]
    end
    
    subgraph "🔧 Outils CLI"
        TF[Terraform 1.13.4]
        Talosctl[talosctl 1.11.3]
        Kubectl[kubectl]
        Govc[govc 0.37.3]
        Cilium[cilium-cli 0.16.13]
        Hubble[hubble 1.16.0]
    end
    
    subgraph "🌐 Accès Réseau"
        vSphere[vSphere API<br/>:443]
        TalosAPI[Talos API<br/>:50000]
        K8sAPI[Kubernetes API<br/>:6443]
    end
    
    OS --> TF
    OS --> Talosctl
    OS --> Kubectl
    OS --> Govc
    OS --> Cilium
    OS --> Hubble
    
    TF -.->|HTTPS| vSphere
    Talosctl -.->|gRPC| TalosAPI
    Kubectl -.->|HTTPS| K8sAPI
    
    style OS fill:#E67E22,stroke:#fff,stroke-width:2px,color:#fff
```

### Workflow de Déploiement

```mermaid
stateDiagram-v2
    [*] --> Preparation: Installation des outils
    
    Preparation --> Configuration: Créer secrets.sh
    Configuration --> ImageBuild: ./do init
    
    ImageBuild --> TemplateImport: govc import.ova
    TemplateImport --> Planning: terraform plan
    
    Planning --> Apply: terraform apply
    
    state Apply {
        [*] --> CreateVMs
        CreateVMs --> ConfigureTalos
        ConfigureTalos --> BootstrapCluster
        BootstrapCluster --> DeployApps
        DeployApps --> [*]
    }
    
    Apply --> Verification: Cluster Ready
    
    state Verification {
        [*] --> CheckNodes
        CheckNodes --> CheckPods
        CheckPods --> CheckIngress
        CheckIngress --> [*]
    }
    
    Verification --> Running: ✅ All Green
    Running --> [*]
    
    Running --> Destroy: ./do destroy (cleanup)
    Destroy --> [*]
```

### Commandes Principales

#### 1️⃣ Installation Initiale

```bash
# Charger les variables d'environnement
source secrets.sh

# Initialiser (build image + terraform init)
./do init

# Importer le template dans vSphere
govc import.ova \
  -ds $TF_VAR_vsphere_datastore \
  -name "talos-1.11.3-amd64" \
  tmp/talos/talos-1.11.3-vmware-amd64.ova
```

#### 2️⃣ Déploiement

```bash
# Plan et Apply en une commande
./do plan-apply

# OU séparément
./do plan
./do apply
```

#### 3️⃣ Vérification

```bash
# Exporter les configs
export TALOSCONFIG=$PWD/talosconfig.yml
export KUBECONFIG=$PWD/kubeconfig.yml

# Vérifier Talos
talosctl -n $(terraform output -raw controllers) version
talosctl -n $(terraform output -raw controllers) dashboard

# Vérifier Kubernetes
kubectl get nodes -o wide
kubectl get pods -A

# Vérifier Cilium
cilium status
cilium connectivity test
```

#### 4️⃣ Accès aux Applications

```bash
# Argo CD
echo "https://argocd.example.test"
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d

# Gitea
echo "https://gitea.example.test"

# Hubble UI (Port-forward)
cilium hubble ui
```

#### 5️⃣ Nettoyage

```bash
# Détruire l'infrastructure
./do destroy

# Supprimer le template vSphere
govc vm.destroy "talos-1.11.3-amd64"
```

### Variables d'Environnement Importantes

```bash
# vSphere
export TF_VAR_vsphere_server='vsphere.local'
export TF_VAR_vsphere_user='administrator@vsphere.local'
export TF_VAR_vsphere_password='your-password'
export TF_VAR_vsphere_datacenter='Datacenter'
export TF_VAR_vsphere_compute_cluster='Cluster'
export TF_VAR_vsphere_datastore='Datastore'

# Réseau
export TF_VAR_cluster_vip='10.17.3.9'
export TF_VAR_cluster_endpoint='https://10.17.3.9:6443'
export TF_VAR_cluster_node_network='10.17.3.0/24'
export TF_VAR_cluster_node_network_gateway='10.17.3.1'

# Domaine
export TF_VAR_ingress_domain='example.test'
```

---

## 🎯 Cas d'Usage

### 1. Développement Local
```mermaid
graph LR
    Dev[👨‍💻 Developer] -->|Push code| Gitea
    Gitea -->|Webhook| ArgoCD
    ArgoCD -->|Deploy| K8s[Kubernetes]
    K8s -->|Expose| Ingress[Cilium Ingress]
    Ingress -->|HTTPS| Dev
    
    style Gitea fill:#34495E,stroke:#fff,stroke-width:2px,color:#fff
    style ArgoCD fill:#EF7B4D,stroke:#fff,stroke-width:2px,color:#fff
```

### 2. CI/CD Pipeline
```mermaid
graph TD
    Code[📝 Code Change] -->|git push| Gitea
    Gitea -->|Trigger| Pipeline[CI Pipeline]
    Pipeline -->|Build| Image[Container Image]
    Image -->|Update| Manifest[K8s Manifest]
    Manifest -->|Commit| Gitea
    Gitea -->|Sync| ArgoCD
    ArgoCD -->|Deploy| K8s[Cluster]
    
    style Pipeline fill:#3498DB,stroke:#fff,stroke-width:2px,color:#fff
```

### 3. WebAssembly Apps
```mermaid
graph LR
    Wasm[🕸️ Wasm App] -->|Spin| Runtime[containerd-shim-spin]
    Runtime -->|Run in| K8s[Kubernetes Pod]
    K8s -->|Network| Cilium
    Cilium -->|Expose| LB[LoadBalancer]
    
    style Wasm fill:#00D9FF,stroke:#000,stroke-width:2px
    style Runtime fill:#00D9FF,stroke:#000,stroke-width:2px
```

---

## 🔍 Monitoring et Observabilité

```mermaid
graph TB
    subgraph "👁️ Observability Stack"
        Hubble[Hubble UI<br/>Network Observability]
        Metrics[Talos Metrics]
        Logs[Pod Logs]
    end
    
    subgraph "📊 Data Sources"
        Network[Network Traffic]
        Pods[Pod Events]
        Nodes[Node Status]
    end
    
    subgraph "🖥️ Dashboards"
        TalosDash[talosctl dashboard]
        HubbleUI[Hubble Web UI]
        K8sDash[kubectl top]
    end
    
    Network -->|Capture| Hubble
    Pods -->|Stream| Logs
    Nodes -->|Export| Metrics
    
    Hubble -->|Visualize| HubbleUI
    Metrics -->|Display| TalosDash
    Logs -->|Query| K8sDash
    
    style Hubble fill:#F8C502,stroke:#000,stroke-width:2px
    style HubbleUI fill:#95E1D3,stroke:#000,stroke-width:2px
```

### Commandes de Monitoring

```bash
# Talos Dashboard
talosctl -n 10.17.3.80 dashboard

# Network Flow avec Hubble
cilium hubble ui

# Logs en temps réel
kubectl logs -f -n cilium -l k8s-app=cilium

# Métriques des nodes
kubectl top nodes
kubectl top pods -A
```

---

## 🛠️ Troubleshooting

```mermaid
flowchart TD
    Start{Problème?} -->|VMs ne démarrent pas| CheckvSphere[Vérifier vSphere]
    Start -->|Cluster inaccessible| CheckNetwork[Vérifier réseau]
    Start -->|Pods en erreur| CheckLogs[Vérifier logs]
    Start -->|Certificats invalides| CheckCerts[Vérifier cert-manager]
    
    CheckvSphere -->|Template manquant| ImportOVA[Importer template OVA]
    CheckvSphere -->|Permissions| FixPerms[Ajuster permissions vSphere]
    
    CheckNetwork -->|VIP inaccessible| CheckL2[Vérifier Cilium L2]
    CheckNetwork -->|DNS| FixDNS[Configurer nameservers]
    
    CheckLogs -->|ImagePullBackOff| CheckRegistry[Vérifier accès registry]
    CheckLogs -->|CrashLoopBackOff| CheckConfig[Vérifier configuration]
    
    CheckCerts -->|Expired| RenewCerts[Renouveler certificats]
    CheckCerts -->|Not Ready| CheckIssuer[Vérifier ClusterIssuer]
    
    ImportOVA --> Resolved[✅ Résolu]
    FixPerms --> Resolved
    CheckL2 --> Resolved
    FixDNS --> Resolved
    CheckRegistry --> Resolved
    CheckConfig --> Resolved
    RenewCerts --> Resolved
    CheckIssuer --> Resolved
    
    style Start fill:#E74C3C,stroke:#fff,stroke-width:2px,color:#fff
    style Resolved fill:#2ECC71,stroke:#fff,stroke-width:2px,color:#fff
```

### Commandes de Debug

```bash
# Vérifier l'état du cluster Talos
talosctl -n 10.17.3.80 health
talosctl -n 10.17.3.80 services

# Vérifier les logs Kubernetes
kubectl logs -n kube-system -l k8s-app=kube-apiserver

# Vérifier Cilium
cilium status --wait
cilium connectivity test

# Vérifier les certificats
kubectl get certificates -A
kubectl describe certificate -n argocd argocd-server

# Vérifier le stockage
kubectl linstor storage-pool list
kubectl get pv,pvc -A
```

---

## 📈 Améliorations Futures

```mermaid
mindmap
  root((Roadmap))
    Sécurité
      Vault integration
      OPA policies
      Network policies
    Monitoring
      Prometheus
      Grafana
      AlertManager
    Storage
      Backup automation
      Snapshot policies
    GitOps
      ApplicationSets
      Progressive delivery
      Canary deployments
    Networking
      Service Mesh
      mTLS
      Rate limiting
```

---

## 📚 Références

### Documentation Officielle
- [Talos Linux](https://www.talos.dev/)
- [Cilium](https://cilium.io/)
- [Argo CD](https://argo-cd.readthedocs.io/)
- [cert-manager](https://cert-manager.io/)
- [Piraeus](https://piraeus.io/)

### Terraform Providers
- [VMware vSphere Provider](https://registry.terraform.io/providers/vmware/vsphere/)
- [Talos Provider](https://registry.terraform.io/providers/siderolabs/talos/)
- [Helm Provider](https://registry.terraform.io/providers/hashicorp/helm/)

### Repositories GitHub
- [Talos](https://github.com/siderolabs/talos)
- [Cilium](https://github.com/cilium/cilium)
- [Argo CD Helm Chart](https://github.com/argoproj/argo-helm)
- [Piraeus Operator](https://github.com/piraeusdatastore/piraeus-operator)

---

## 👥 Contribution

Ce projet est maintenu par **ClemCreator** (cld@civadis.be).

### Comment Contribuer

1. Fork le projet
2. Créer une branche feature (`git checkout -b feature/AmazingFeature`)
3. Commit les changements (`git commit -m 'Add AmazingFeature'`)
4. Push vers la branche (`git push origin feature/AmazingFeature`)
5. Ouvrir une Pull Request

---

## 📄 License

Ce projet est basé sur le travail original de [rgl/terraform-vsphere-talos](https://github.com/rgl/terraform-vsphere-talos).

---

## 🎉 Remerciements

- **Rui Lopes (rgl)** - Projet original
- **Sidero Labs** - Talos Linux
- **Cilium Team** - Networking solution
- **CNCF** - Kubernetes ecosystem

---

<div align="center">

**🚀 Fait avec ❤️ par ClemCreator**

*Dernière mise à jour: 20 Octobre 2025*

</div>
