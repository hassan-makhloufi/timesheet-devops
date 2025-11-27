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

    /* === 2. Secrets Scan - Gitleaks (non bloquant) === */
    stage('Secrets Scan - Gitleaks') {
      steps {
        sh '''
          echo "=== Gitleaks : scan des secrets dans le repo ==="

          mkdir -p reports

          docker run --rm \
            -v "$PWD":/repo \
            zricethezav/gitleaks:latest \
              detect \
                -s /repo \
                -f json \
                -r /repo/reports/gitleaks-report.json || true
        '''
      }
      post {
        always {
          archiveArtifacts artifacts: 'reports/gitleaks-report.json',
                           fingerprint: true,
                           onlyIfSuccessful: false
        }
      }
    }

    /* === 3. Build + Tests Maven === */
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

    /* === 4. SCA - Dependency-Check (non bloquant) === */
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
              --failOnCVSS 9.0 \
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

    /* === 5. SAST - SonarQube === */
    stage('SAST - SonarQube Analysis') {
      steps {
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
            waitForQualityGate abortPipeline: true
          }
        }
      }
    }

    /* === 6. Docker Build & Run App (pour DAST) === */
    stage('Docker Build & Run App') {
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

          echo "=== Démarrage du conteneur applicatif pour les tests DAST ==="
          docker rm -f timesheet-app || true

          docker run -d --name timesheet-app \
            -p 8082:8080 \
            ${IMAGE_NAME}:${IMAGE_TAG}

          echo "Attente du démarrage de l'application..."
          sleep 20
        '''
      }
    }

    /* === 7. DAST - OWASP ZAP Baseline (non bloquant) === */
        /* === 7. DAST - ZAP Baseline (non bloquant) === */
        stage('DAST - ZAP Baseline') {
          steps {
            sh '''
              echo "=== ZAP BASELINE : scan DAST de l'application ==="

              mkdir -p reports

              docker run --rm \
                -v "$PWD/reports":/zap/wrk \
                owasp/zap2docker-stable zap-baseline.py \
                  -t http://host.docker.internal:8082/timesheet-devops/user/retrieve-all-users \
                  -r zap-report.html || true

              echo "Contenu du répertoire reports après ZAP :"
              ls -l reports || true
            '''
          }
          post {
            always {
              archiveArtifacts artifacts: 'reports/zap-report.html',
                               fingerprint: true,
                               allowEmptyArchive: true
            }
          }
        }


    /* === 8. Docker Scan - Trivy === */
    stage('Docker Scan - Trivy') {
      steps {
        sh '''
          mkdir -p reports

          echo "=== TRIVY SCAN: SARIF & TEXTE ==="

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

    /* === 9. Cleanup Docker === */
    stage('Cleanup Docker') {
      steps {
        sh '''
          echo "=== Nettoyage du conteneur applicatif ==="
          docker rm -f timesheet-app || true
        '''
      }
    }

  }

  /* === 10. Notifications email globales === */
  post {
    always {
      emailext(
        to: 'hsan.mk2020@gmail.com',
        subject: "DevSecOps - ${env.JOB_NAME} #${env.BUILD_NUMBER} : ${currentBuild.currentResult}",
        mimeType: 'text/html',
        body: """
        <html>
          <body>
            <h2>Rapport d'exécution du pipeline DevSecOps</h2>
            <p><b>Job :</b> ${env.JOB_NAME}</p>
            <p><b>Build :</b> #${env.BUILD_NUMBER}</p>
            <p><b>Résultat :</b> <span style='color:${currentBuild.currentResult == "SUCCESS" ? "green" : "red"}'>
              ${currentBuild.currentResult}
            </span></p>
            <h3>Liens utiles</h3>
            <ul>
              <li><a href="${env.BUILD_URL}">Détail du build Jenkins</a></li>
              <li><a href="${env.BUILD_URL}artifact/reports/dependency-check/dependency-check-report.html">
                Rapport OWASP Dependency-Check (HTML)
              </a></li>
              <li><a href="${env.BUILD_URL}artifact/reports/trivy-image.txt">
                Rapport Trivy (texte)
              </a></li>
              <li><a href="${env.BUILD_URL}artifact/reports/trivy-image.sarif">
                Rapport Trivy (SARIF)
              </a></li>
              <li><a href="${env.BUILD_URL}artifact/reports/gitleaks-report.json">
                Rapport Gitleaks (secrets)
              </a></li>
              <li><a href="${env.BUILD_URL}artifact/reports/zap-report.html">
                Rapport OWASP ZAP (DAST)
              </a></li>
            </ul>
            <p>Envoyé automatiquement par Jenkins le ${new Date()}</p>
          </body>
        </html>
        """
      )
    }
  }

}
