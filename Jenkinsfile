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
  echo ">>> Creating venv (first time only)"
  python3 -m venv .venv
  . .venv/bin/activate
  pip install --upgrade pip
  pip install robotframework robotframework-browser
  rfbrowser init
  touch .rfbrowser_done
else
  echo ">>> Reusing existing venv"
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
        }

        stage('Run Regression') {
            steps {
                sh '''
set -e
. .venv/bin/activate
robot --output reg-output.xml --report reg-report.html --log reg-log.html tests/regression
                '''
            }
        }
    }

    post {
        success {
            sh '''
. .venv/bin/activate

echo ">>> Authenticating to Xray Cloud..."
RAW_RESPONSE=$(curl -s -H "Content-Type: application/json" -X POST \
  --data "{ \\"client_id\\": \\"$XRAY_CLIENT_ID\\", \\"client_secret\\": \\"$XRAY_CLIENT_SECRET\\" }" \
  https://xray.cloud.getxray.app/api/v2/authenticate)

echo ">>> Raw auth response: $RAW_RESPONSE"

TOKEN=$(echo "$RAW_RESPONSE" | tr -d '"')

if [ -z "$TOKEN" ]; then
  echo "!!! TOKEN is empty, cannot upload to Xray"
  exit 1
fi

echo ">>> Got Xray token successfully"

if [ -f sanity-output.xml ]; then
  echo ">>> Creating Sanity info file"
cat > sanity-info.json <<EOF
{
  "fields": {
    "project": { "key": "${PROJECT_KEY}" },
    "summary": "Parking App - Sanity (build ${BUILD_NUMBER})",
    "issuetype": { "name": "Test Execution" }
  }
}
EOF

  echo ">>> Uploading sanity-output.xml to Xray..."
  HTTP_CODE=$(curl -s -o xray_sanity_response.json -w "%{http_code}" \
    -X POST \
    -H "Authorization: Bearer $TOKEN" \
    -F "results=@sanity-output.xml;type=text/xml" \
    -F "info=@sanity-info.json;type=application/json" \
    https://xray.cloud.getxray.app/api/v2/import/execution/robot/multipart)

  echo ">>> Xray HTTP code (Sanity): $HTTP_CODE"
  echo ">>> Xray response body (Sanity):"
  cat xray_sanity_response.json

  if [ "$HTTP_CODE" != "200" ] && [ "$HTTP_CODE" != "201" ]; then
    echo "!!! Xray upload for Sanity failed with HTTP $HTTP_CODE"
    exit 1
  fi
else
  echo ">>> sanity-output.xml missing, skipping upload"
fi
            '''
        }
    }
}
