pipeline {
  agent any

  options {
    skipDefaultCheckout(true)
    timestamps()
  }

  environment {
    // Image Docker produite par le pipeline
    IMAGE_NAME  = "hassan/timesheet-devops"
    IMAGE_TAG   = "1.0.${BUILD_NUMBER}"

    // Clé NVD utilisée par OWASP Dependency-Check (credentials Jenkins)
    NVD_API_KEY = credentials('nvd-api-key')
  }

  stages {

    /* === 1. Checkout GIT === */
    stage('Checkout') {
      steps {
        git branch: 'main',
            changelog: false,
            credentialsId: 'hassan-makhloufi',
            url: 'https://github.com/hassan-makhloufi/timesheet-devops.git'
      }
    }

    /* === 2. Build + Tests Maven === */
    stage('Maven Build & Tests') {
      steps {
        sh 'mvn -B clean verify'
      }
      post {
        always {
          junit allowEmptyResults: true,
                testResults: '**/target/surefire-reports/*.xml'
        }
      }
    }

    stage('SCA - Dependency-Check') {
      steps {
        sh '''
          set +e
          mkdir -p odc-data reports/dependency-check

          docker run --rm \
            -u $(id -u):$(id -g) \
            -v "$PWD":/src \
            -v "$PWD/reports/dependency-check":/report \
            -v "$PWD/odc-data":/usr/share/dependency-check/data \
            owasp/dependency-check:latest \
              --scan /src \
              --format HTML \
              --out /report \
              --log /report/dc.log \
              --disableOssIndex \
              --failOnCVSS 11.0 \
              --nvdApiKey "$NVD_API_KEY" \
              --exclude /src/odc-data \
              --exclude /src/reports \
              --exclude /src/target \
              --exclude /src/**/dc.zip || true

          test -s reports/dependency-check/dependency-check-report.html || true
        '''
      }
      post {
        always {
          archiveArtifacts artifacts: 'reports/dependency-check/**',
                           fingerprint: true
        }
      }
    }


    /* === 4. SAST - SonarQube === */
    stage('SAST - SonarQube Analysis') {
      steps {
        // "sonarqube" = nom du serveur dans Manage Jenkins → Configure System
        withSonarQubeEnv('sonarqube') {
          sh '''
            mvn -B sonar:sonar \
              -Dsonar.projectKey=devops_git \
              -Dsonar.projectName=timesheet-devops
          '''
        }
      }
    }

    stage('SAST - Quality Gate') {
      steps {
        script {
          timeout(time: 10, unit: 'MINUTES') {
            // Bloque le pipeline si le Quality Gate est "FAILED"
            waitForQualityGate abortPipeline: true
          }
        }
      }
    }

    /* === 5. Docker Build === */
    stage('Docker Build') {
      steps {
        sh '''
          echo "Workspace = $WORKSPACE"
          echo "Recherche du Dockerfile…"

          DOCKERFILE_PATH=$(find "$WORKSPACE" -maxdepth 4 -type f -name 'Dockerfile' | head -n 1)

          if [ -z "$DOCKERFILE_PATH" ]; then
            echo "ERREUR : aucun Dockerfile trouvé dans $WORKSPACE"
            exit 1
          fi

          echo "Dockerfile trouvé : $DOCKERFILE_PATH"
          CONTEXT_DIR=$(dirname "$DOCKERFILE_PATH")
          echo "Contexte Docker : $CONTEXT_DIR"

          docker build -t ${IMAGE_NAME}:${IMAGE_TAG} \
                       -f "$DOCKERFILE_PATH" "$CONTEXT_DIR"
        '''
      }
    }

    /* === 6. Docker Scan - Trivy (REPORT ONLY) === */
    stage('Docker Scan - Trivy') {
      steps {
        sh '''
          mkdir -p reports

          echo "=== TRIVY SCAN: HTML & SARIF ==="

          # 1) Analyse SARIF
          docker run --rm \
            -v /var/run/docker.sock:/var/run/docker.sock \
            -v /var/trivy-cache:/root/.cache/ \
            -v "$PWD/reports":/report \
            aquasec/trivy:latest image \
              --timeout 15m \
              --format sarif \
              --output /report/trivy-image.sarif \
              --ignore-unfixed \
              --severity HIGH,CRITICAL \
              ${IMAGE_NAME}:${IMAGE_TAG} || true

          # 2) Rapport lisible en texte
          docker run --rm \
            -v /var/run/docker.sock:/var/run/docker.sock \
            -v /var/trivy-cache:/root/.cache/ \
            -v "$PWD/reports":/report \
            aquasec/trivy:latest image \
              --timeout 15m \
              --format table \
              --output /report/trivy-image.txt \
              --ignore-unfixed \
              --severity HIGH,CRITICAL \
              ${IMAGE_NAME}:${IMAGE_TAG} || true
        '''
      }
      post {
        always {
          archiveArtifacts artifacts: 'reports/trivy-image.*',
                           fingerprint: true
        }
      }
    }

}
