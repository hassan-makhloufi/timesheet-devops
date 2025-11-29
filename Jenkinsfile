pipeline {
  agent any

  options {
    skipDefaultCheckout(true)
    timestamps()
  }

  environment {
    IMAGE_NAME  = "hassan/timesheet-devops"
    IMAGE_TAG   = "1.0.${BUILD_NUMBER}"
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

    /* === 2. Secrets Scan - Gitleaks (BLOQUANT) === */
    stage('Secrets Scan - Gitleaks') {
      steps {
        sh '''
          echo "=== Gitleaks : scan des secrets dans le repo (BLOQUANT) ==="

          mkdir -p reports

          # Si Gitleaks trouve des secrets -> exit code != 0 -> stage FAILED -> pipeline arrêté
          docker run --rm \
            -v "$PWD":/repo \
            zricethezav/gitleaks:latest \
              detect \
                -s /repo \
                -f json \
                -r /repo/reports/gitleaks-report.json
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

   stage('SAST - Semgrep') {
     steps {
       sh '''
         echo "=== SEMGREP : Analyse statique du code (BLOQUANT) ==="

         mkdir -p reports

         docker run --rm \
           -v "$PWD":/src \
           -w /src \
           returntocorp/semgrep semgrep \
             --config=auto \
             --severity=ERROR \
             --error \
             --json \
             --output=reports/semgrep-report.json \
             src/main/java

         # Explications :
         # -w /src              : Semgrep se lance à la racine du projet
         # .semgrepignore       : sera pris en compte (ignore reports/, target/…)
         # src/main/java        : on limite le scan au code applicatif
         # --severity=ERROR     : seuls les problèmes en ERROR cassent le build
         # Les WARNING (comme ceux du rapport HTML) n'arrêtent plus le pipeline.
       '''
     }
     post {
       always {
         archiveArtifacts artifacts: 'reports/semgrep-report.json',
                          fingerprint: true,
                          allowEmptyArchive: true
       }
     }
   }


    /* === 4. Build + Tests Maven (BLOQUANT) === */
    stage('Maven Build & Tests') {
      steps {
        sh '''
          echo "=== Build & Tests Maven (BLOQUANT) ==="
          mvn -B clean verify
        '''
      }
      post {
        always {
          junit allowEmptyResults: true,
                testResults: '**/target/surefire-reports/*.xml'
        }
      }
    }

    /* === 5. SCA - Dependency-Check (BLOQUANT) === */
    stage('SCA - Dependency-Check') {
      steps {
        sh '''
          echo "=== Dependency-Check (BLOQUANT si CVSS >= 7.0) ==="

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

          # Si vulnérabilité CVSS >= 7 -> exit != 0 -> pipeline FAIL
        '''
      }
      post {
        always {
          archiveArtifacts artifacts: 'reports/dependency-check/**',
                           fingerprint: true
        }
      }
    }

    /* === 6. SAST - SonarQube + Quality Gate (BLOQUANT) === */
    stage('SAST - SonarQube Analysis') {
      steps {
        withSonarQubeEnv('sonarqube') {
          sh '''
            echo "=== Analyse SonarQube ==="
            mvn -B sonar:sonar \
              -Dsonar.projectKey=devops_git \
              -Dsonar.projectName=timesheet-devops
          '''
        }
      }
    }

    stage('SAST - Quality Gate') {
      steps {
        timeout(time: 10, unit: 'MINUTES') {
          script {
            // Ici, si Quality Gate = FAILED -> le pipeline s'arrête (abortPipeline: true)
            def qg = waitForQualityGate abortPipeline: true
            echo "Quality Gate status = ${qg.status}"
          }
        }
      }
    }

    /* === 7. Docker Build & Run App (pour DAST) === */
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
            -p 8082:8082 \
            ${IMAGE_NAME}:${IMAGE_TAG}

          echo "Attente du démarrage de l'application..."
          sleep 20
        '''
      }
    }

    /* === 8. DAST - OWASP ZAP Baseline (BLOQUANT) === */
    stage('DAST - ZAP Baseline') {
      steps {
        sh '''
          echo "=== ZAP BASELINE : scan DAST de l'application (BLOQUANT) ==="

          mkdir -p reports

          # zap-baseline retourne exit != 0 si alertes au-dessus d'un certain niveau
          docker run --rm \
            -v "$PWD/reports":/zap/wrk \
            owasp/zap2docker-stable zap-baseline.py \
              -t http://host.docker.internal:8082/timesheet-devops \
              -r zap-report.html

          if [ ! -f reports/zap-report.html ]; then
            echo "ZAP n'a pas généré de rapport, on considère ça comme une erreur."
            exit 1
          fi

          echo "=== Contenu du répertoire reports après ZAP ==="
          ls -l reports || true
        '''
      }
      post {
        always {
          archiveArtifacts artifacts: 'reports/zap-report.html',
                           fingerprint: true
        }
      }
    }

    /* === 9. Docker Scan - Trivy (BLOQUANT) === */
    stage('Docker Scan - Trivy') {
      steps {
        sh '''
          mkdir -p reports

          echo "=== TRIVY SCAN: BLOQUANT si HIGH/CRITICAL ==="

          # Analyse SARIF + exit-code 1 si vulnérabilités HIGH/CRITICAL
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
              --exit-code 1 \
              ${IMAGE_NAME}:${IMAGE_TAG}

          # Rapport lisible en texte (si celui-là fail aussi, ça casse le stage)
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
              --exit-code 1 \
              ${IMAGE_NAME}:${IMAGE_TAG}
        '''
      }
      post {
        always {
          archiveArtifacts artifacts: 'reports/trivy-image.*',
                           fingerprint: true
        }
      }
    }

    /* === 10. Cleanup Docker === */
    stage('Cleanup Docker') {
      steps {
        sh '''
          echo "=== Nettoyage du conteneur applicatif ==="
          docker rm -f timesheet-app || true
        '''
      }
    }

  }

  /* === 11. Notifications email globales === */
  post {
    always {
      emailext(
        to: 'hsan.mk2020@gmail.com',
        subject: "DevSecOps - ${env.JOB_NAME} #${env.BUILD_NUMBER} : ${currentBuild.currentResult}",
        mimeType: 'text/html',
        body: """
        <html>
          <body>
            <h2>Rapport d'exécution du pipeline DevSecOps (BLOQUANT)</h2>
            <p><b>Job :</b> ${env.JOB_NAME}</p>
            <p><b>Build :</b> #${env.BUILD_NUMBER}</p>
            <p><b>Résultat :</b> <span style='color:${currentBuild.currentResult == "SUCCESS" ? "green" : "red"}'>
              ${currentBuild.currentResult}
            </span></p>
            <h3>Liens utiles</h3>
            <ul>
              <li><a href="${env.BUILD_URL}">Détail du build Jenkins</a></li>
              <li><a href="${env.BUILD_URL}artifact/reports/gitleaks-report.json">
                Rapport Gitleaks (secrets)
              </a></li>
              <li><a href="${env.BUILD_URL}artifact/reports/semgrep-report.json">
                Rapport Semgrep (SAST)
              </a></li>
              <li><a href="${env.BUILD_URL}artifact/reports/dependency-check/dependency-check-report.html">
                Rapport OWASP Dependency-Check (SCA)
              </a></li>
              <li><a href="${env.BUILD_URL}artifact/reports/trivy-image.txt">
                Rapport Trivy (texte)
              </a></li>
              <li><a href="${env.BUILD_URL}artifact/reports/trivy-image.sarif">
                Rapport Trivy (SARIF)
              </a></li>
              <li><a href="${env.BUILD_URL}artifact/reports/zap-report.html">
                Rapport OWASP ZAP (DAST)
              </a></li>
              <li><a href="http://192.168.50.4:9000/dashboard?id=devops_git">
                Tableau de bord SonarQube
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
