pipeline {
    agent {
        docker {
            image 'python:3.11'   // build runs inside this container
            args '-u root:root'  // run as root inside the build container
        }
    }

    environment {
        XRAY_CLIENT_ID     = credentials('xray-client-id')
        XRAY_CLIENT_SECRET = credentials('xray-client-secret')
        PROJECT_KEY        = 'QAT'   // <-- change to your Jira/Xray project key
    }

    stages {

        stage('Checkout') {
            steps {
                // get your code from GitHub
                checkout scm
            }
        }

        stage('Install Robot') {
            steps {
                sh '''
                    set -e
                    python --version
                    pip install --no-cache-dir --upgrade pip
                    pip install --no-cache-dir robotframework
                '''
            }
        }

        stage('Run Robot Tests') {
            steps {
                sh '''
                    set -e
                    # adjust "tests" if your folder name is different
                    robot --output output.xml --report report.html --log log.html tests
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

                    echo "Requesting Xray token..."
                    TOKEN=$(curl -s -H "Content-Type: application/json" -X POST \
                      --data "{ \\"client_id\\": \\"$XRAY_CLIENT_ID\\", \\"client_secret\\": \\"$XRAY_CLIENT_SECRET\\" }" \
                      https://xray.cloud.getxray.app/api/v2/authenticate | tr -d '"')

                    echo "Xray token length: ${#TOKEN}"

                    echo "Uploading Robot results to Xray..."
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
