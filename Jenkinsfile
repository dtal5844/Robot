pipeline {
    agent any

    environment {
        XRAY_CLIENT_ID     = credentials('xray-client-id')
        XRAY_CLIENT_SECRET = credentials('xray-client-secret')
        PROJECT_KEY        = 'AUT'   // <- change to your Jira/Xray project key
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Setup Python & Robot') {
            steps {
                sh '''
                    set -e
                    # Install Python in the Jenkins container (only needed first times)
                    if ! command -v python3 >/dev/null 2>&1; then
                      apt-get update
                      apt-get install -y python3 python3-venv python3-pip
                    fi

                    python3 -m venv venv
                    . venv/bin/activate
                    pip install --upgrade pip
                    pip install robotframework
                '''
            }
        }

        stage('Run Robot Tests') {
            steps {
                sh '''
                    set -e
                    . venv/bin/activate
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
