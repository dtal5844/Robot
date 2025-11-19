pipeline {
    agent any

    environment {
        XRAY_CLIENT_ID     = credentials('xray-client-id')
        XRAY_CLIENT_SECRET = credentials('xray-client-secret')
        PROJECT_KEY        = 'AUT'
    }

        stages {
        stage('Checkout') {
            steps { checkout scm }
        }

        stage('Install Robot') {
    steps {
        sh '''
          set -e

          if [ ! -d ".venv" ]; then
            echo "Creating venv and installing libs (first time only)..."
            python3 -m venv .venv
            . .venv/bin/activate
            pip install --upgrade pip
            pip install robotframework robotframework-browser
            rfbrowser init
            touch .rfbrowser_done
          else
            echo "Reusing existing venv..."
            . .venv/bin/activate

            pip show robotframework >/dev/null 2>&1 || pip install robotframework
            pip show robotframework-browser >/dev/null 2>&1 || pip install robotframework-browser
            [ -f .rfbrowser_done ] || rfbrowser init
          fi
        '''
    }
}



        stage('Run Sanity') {
            steps {
                sh '''
                  set -e
                  . .venv/bin/activate
                  robot --output sanity-output.xml --report sanity-report.html --log sanity-log.html tests/sanity
                '''
            }
            post {
                always {
                    archiveArtifacts artifacts: 'sanity-*.html,sanity-output.xml', fingerprint: true
                }
            }
        }

        stage('Run Regression') {
            steps {
                sh '''
                  set -e
                  . .venv/bin/activate
                  robot --output reg-output.xml --report reg-report.html --log reg-log.html tests/regression
                '''
            }
            post {
                always {
                    archiveArtifacts artifacts: 'reg-*.html,reg-output.xml', fingerprint: true
                }
            }
        }

        stage('Upload Sanity to Xray') {
            steps {
                sh '''
                  set -e
                  TOKEN=$(curl -s -H "Content-Type: application/json" -X POST \
                    --data "{ \\"client_id\\": \\"$XRAY_CLIENT_ID\\", \\"client_secret\\": \\"$XRAY_CLIENT_SECRET\\" }" \
                    https://xray.cloud.getxray.app/api/v2/authenticate | tr -d '"')

                  curl -s -o /dev/stdout \
                    -H "Authorization: Bearer $TOKEN" \
                    -H "Content-Type: text/xml" \
                    --data @sanity-output.xml \
                    "https://xray.cloud.getxray.app/api/v2/import/execution/robot?projectKey=$PROJECT_KEY&testPlanKey=AUT-1"
                '''
            }
        }

        stage('Upload Regression to Xray') {
            steps {
                sh '''
                  set -e
                  TOKEN=$(curl -s -H "Content-Type: application/json" -X POST \
                    --data "{ \\"client_id\\": \\"$XRAY_CLIENT_ID\\", \\"client_secret\\": \\"$XRAY_CLIENT_SECRET\\" }" \
                    https://xray.cloud.getxray.app/api/v2/authenticate | tr -d '"')

                  curl -s -o /dev/stdout \
                    -H "Authorization: Bearer $TOKEN" \
                    -H "Content-Type: text/xml" \
                    --data @reg-output.xml \
                    "https://xray.cloud.getxray.app/api/v2/import/execution/robot?projectKey=$PROJECT_KEY&testPlanKey=AUT-1"
                '''
            }
        }
    }

}
