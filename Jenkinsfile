pipeline {
  agent any

  options {
    skipDefaultCheckout(true)
    timestamps()
  }

  environment {
    IMAGE_NAME  = "hassan/timesheet-devops"
    IMAGE_TAG   = "1.0.${BUILD_NUMBER}"
    NVD_API_KEY = "demo-nvd-key"
  }

  stages {

    /* === 1. Checkout GIT === */
    stage('Checkout') {
      steps {
        echo "=== [DEMO] Checkout du code (mock) ==="
      }
    }

    /* === 2. Secrets Scan - Gitleaks (BLOQUANT) === */
    stage('Secrets Scan - Gitleaks') {
      steps {
        echo "=== [DEMO] Gitleaks : scan des secrets (mock, toujours OK) ==="
      }
    }

    /* === 3. SAST - Semgrep (BLOQUANT) === */
    stage('SAST - Semgrep') {
      steps {
        echo "=== [DEMO] Semgrep : analyse statique (mock, toujours OK) ==="
      }
    }

    /* === 4. Build + Tests Maven (BLOQUANT) === */
    stage('Maven Build & Tests') {
      steps {
        echo "=== [DEMO] mvn clean verify (mock, toujours OK) ==="
      }
    }

    /* === 5. SCA - Dependency-Check (BLOQUANT) === */
    stage('SCA - Dependency-Check') {
      steps {
        echo "=== [DEMO] OWASP Dependency-Check (mock, toujours OK) ==="
      }
    }

    /* === 6. SAST - SonarQube + Quality Gate (BLOQUANT) === */
    stage('SAST - SonarQube Analysis') {
      steps {
        echo "=== [DEMO] Analyse SonarQube (mock) ==="
      }
    }

    stage('SAST - Quality Gate') {
      steps {
        echo "=== [DEMO] Quality Gate SonarQube = PASSED (mock) ==="
      }
    }

    /* === 7. Docker Build & Run App (pour DAST) === */
    stage('Docker Build & Run App') {
      steps {
        echo "=== [DEMO] Build & run Docker de l'app (mock) ==="
      }
    }

    /* === 8. DAST - OWASP ZAP Baseline (BLOQUANT) === */
    stage('DAST - ZAP Baseline') {
      steps {
        echo "=== [DEMO] ZAP Baseline DAST (mock, toujours OK) ==="
      }
    }

    /* === 9. Docker Scan - Trivy (BLOQUANT) === */
    stage('Docker Scan - Trivy') {
      steps {
        echo "=== [DEMO] Trivy scan de l'image Docker (mock, toujours OK) ==="
      }
    }

    /* === 10. DEPLOY : déploiement du conteneur de prod === */
    stage('Deploy') {
      steps {
        echo "=== [DEMO] Déploiement du conteneur PROD (mock) ==="
      }
    }

    /* === 11. Cleanup Docker (environnement de test DAST) === */
    stage('Cleanup Docker') {
      steps {
        echo "=== [DEMO] Nettoyage des conteneurs (mock) ==="
      }
    }
  }

  /* === 12. Post global (simple echo pour rester 100% vert) === */
  post {
    always {
      echo "=== [DEMO] Fin du pipeline DevSecOps (tout vert pour la capture) ==="
    }
  }
}
