pipeline {
    agent any

    environment {
        XRAY_CLIENT_ID     = credentials('xray-client-id')
        XRAY_CLIENT_SECRET = credentials('xray-client-secret')
        PROJECT_KEY        = 'AUT'   // להחליף ל-project key שלך
    }

    stages {
        stage('Checkout') {
            steps { checkout scm }
        }

        stage('Install Robot') {
            steps {
                sh '''
                  set -e
                  python3 --version
                  python3 -m pip install --upgrade pip
                  python3 -m pip install robotframework
                '''
            }
        }

        stage('Run Robot Tests') {
            steps {
                sh '''
                  set -e
                  python3 -m robot --output output.xml --report report.html --log log.html tests
                '''
            }
            post {
                always {
                    archiveArtifacts artifacts: 'output.xml,report.html,log.html', fingerprint: true
                }
            }
        }

        stage('Upload Results to Xray') {
            steps {
                sh '''
                  set -e
                  TOKEN=$(curl -s -H "Content-Type: application/json" -X POST \
                    --data "{ \\"client_id\\": \\"$XRAY_CLIENT_ID\\", \\"client_secret\\": \\"$XRAY_CLIENT_SECRET\\" }" \
                    https://xray.cloud.getxray.app/api/v2/authenticate | tr -d '"')

                  echo "Xray token length: ${#TOKEN}"

                  curl -v \
                    -H "Authorization: Bearer $TOKEN" \
                    -H "Content-Type: text/xml" \
                    --data @output.xml \
                    "https://xray.cloud.getxray.app/api/v2/import/execution/robot?projectKey=$PROJECT_KEY"
                '''
            }
        }
    }
}
