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

    /* === 3. SCA - OWASP Dependency-Check (Docker) === */
    stage('SCA - Dependency-Check') {
      steps {
        script {
          // On marque le build UNSTABLE si CVSS >= 7 mais on ne casse pas tout le pipeline
          catchError(buildResult: 'UNSTABLE', stageResult: 'FAILURE') {
            sh '''
              set -e
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
                  --failOnCVSS 7.0 \
                  --nvdApiKey "$NVD_API_KEY" \
                  --exclude /src/odc-data \
                  --exclude /src/reports \
                  --exclude /src/target \
                  --exclude /src/**/dc.zip

              test -s reports/dependency-check/dependency-check-report.html
            '''
          }
        }
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
          set +e
          mkdir -p reports

          # Rapport SARIF (utilisable dans des outils de sécurité)
          docker run --rm \
            -v /var/run/docker.sock:/var/run/docker.sock \
            -v "$PWD/reports":/report \
            aquasec/trivy:latest image \
              --exit-code 0 \
              --severity HIGH,CRITICAL \
              --ignore-unfixed \
              --format sarif \
              --output /report/trivy-image.sarif \
              ${IMAGE_NAME}:${IMAGE_TAG}

          # Rapport texte lisible dans Jenkins (non bloquant)
          docker run --rm \
            -v /var/run/docker.sock:/var/run/docker.sock \
            -v "$PWD/reports":/report \
            aquasec/trivy:latest image \
              --exit-code 0 \
              --severity HIGH,CRITICAL \
              --ignore-unfixed \
              --format table \
              --output /report/trivy-image.txt \
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

  post {
    success {
      echo "✅ Build #${BUILD_NUMBER} OK. Rapports disponibles dans 'Artifacts'."
    }
    unstable {
      echo "⚠️ Build #${BUILD_NUMBER} UNSTABLE : voir SonarQube / Dependency-Check / Trivy."
    }
    failure {
      echo "❌ Build #${BUILD_NUMBER} FAILED. Corrige les erreurs indiquées dans les logs."
    }
    always {
      echo "Fin du pipeline pour ${JOB_NAME} (#${BUILD_NUMBER})."
    }
  }
}
