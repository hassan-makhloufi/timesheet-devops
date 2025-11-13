pipeline {
  agent any

  environment {
    IMAGE_NAME  = "hassan/timesheet-devops"
    IMAGE_TAG   = "1.0.${BUILD_NUMBER}"
    NVD_API_KEY = credentials('nvd-api-key')
  }

  stages {

    /* --- GIT Checkout --- */
    stage('GIT') {
      steps {
        git branch: 'main',
            changelog: false,
            credentialsId: 'hassan-makhloufi',
            url: 'https://github.com/tarek-ayari/devops.git'
      }
    }

    /* --- BUILD MAVEN --- */
    stage('MAVEN Build') {
      steps {
        sh 'mvn -B clean verify'
      }
      post {
        always {
          junit allowEmptyResults: true, testResults: '**/target/surefire-reports/*.xml'
        }
      }
    }

    /* --- SCA : Dependency-Check (Docker) non bloquant --- */
    stage('SCA - Dependency-Check (Docker)') {
      steps {
        script {
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
          archiveArtifacts artifacts: 'reports/dependency-check/**', fingerprint: true
        }
      }
    }

    /* --- SAST SonarQube --- */
    stage('SAST - SonarQube Analysis') {
      steps {
        withSonarQubeEnv('sonarqube') {
          sh 'mvn -B sonar:sonar -Dsonar.projectKey=devops_git'
        }
      }
    }

    stage('SAST - Quality Gate') {
      steps {
        script {
          timeout(time: 1, unit: 'HOURS') {
            waitForQualityGate(abortPipeline: true)
          }
        }
      }
    }
   /* stage('Docker Build') {
        steps {
            sh 'docker build -t hsanmk/timesheet-devops:1.0.3 -f docker/Dockerfile .'
             }
    }*/
    stage('Docker Build') {
        steps {
            sh '''
                echo "Workspace = $WORKSPACE"
                echo "Recherche du Dockerfile…"
                find "$WORKSPACE" -maxdepth 3 -type f -name 'Dockerfile' -print

                DOCKERFILE_PATH=$(find "$WORKSPACE" -maxdepth 3 -type f -name 'Dockerfile' | head -n 1)

                if [ -z "$DOCKERFILE_PATH" ]; then
                  echo "ERREUR : aucun Dockerfile trouvé dans $WORKSPACE"
                  exit 1
                fi

                echo "Dockerfile trouvé : $DOCKERFILE_PATH"
                CONTEXT_DIR=$(dirname "$DOCKERFILE_PATH")
                echo "Contexte Docker : $CONTEXT_DIR"

                docker build -t hsanmk/timesheet-devops:1.0.3 -f "$DOCKERFILE_PATH" "$CONTEXT_DIR"
            '''
        }
    }
    /* --- Docker Build ---
    stage('Docker Build') {
      steps {
        sh 'docker build -t ${IMAGE_NAME}:${IMAGE_TAG} .'
      }
    }
 */
    /* --- Docker Scan : Trivy non bloquant (Report Only) --- */
    stage('Docker Scan - Trivy (REPORT ONLY)') {
      steps {
        sh '''
          set +e
          mkdir -p reports

          # Rapport SARIF (ne bloque pas)
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

          # Rapport lisible en TXT
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
          archiveArtifacts artifacts: 'reports/trivy-image.*', fingerprint: true
        }
      }
    }
  }

  post {
    always {
      echo "Build terminé. Les rapports sont disponibles dans 'Artifacts'."
    }
  }
}
