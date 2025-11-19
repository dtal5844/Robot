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

##############################################
# Authenticate
##############################################
echo ">>> Authenticating to Xray Cloud..."

RAW_RESPONSE=$(curl -s -H "Content-Type: application/json" -X POST \
  --data "{ \\"client_id\\": \\"$XRAY_CLIENT_ID\\", \\"client_secret\\": \\"$XRAY_CLIENT_SECRET\\" }" \
  https://xray.cloud.getxray.app/api/v2/authenticate)

echo ">>> Raw auth response: $RAW_RESPONSE"

TOKEN=$(echo "$RAW_RESPONSE" | tr -d '"')

if [ -z "$TOKEN" ]; then
  echo "!!! TOKEN is empty"
  exit 1
fi

echo ">>> Got Xray token"


##############################################
# Create Test Plan (dynamic)
##############################################
TP_SUMMARY="Parking App - Full Test Plan (build ${BUILD_NUMBER})"

cat > tp.json <<EOF
{
  "fields": {
    "project": { "key": "${PROJECT_KEY}" },
    "summary": "${TP_SUMMARY}",
    "issuetype": { "name": "Test Plan" }
  }
}
EOF

echo ">>> Creating Test Plan in Xray: $TP_SUMMARY"

TP_RESPONSE=$(curl -s -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  --data @tp.json \
  https://xray.cloud.getxray.app/api/v2/issues)

echo ">>> TP Response: $TP_RESPONSE"

# חילוץ ה-key מה-JSON בלי grep עם מרכאות שבורות
TP_KEY=$(printf "%s\n" "$TP_RESPONSE" | sed -n "s/.*\"key\":\"\\([^\"]*\\)\".*/\\1/p")

if [ -z "$TP_KEY" ]; then
  echo "!!! Failed to extract TP key from response"
  exit 1
fi

echo ">>> Created Test Plan: $TP_KEY"


##############################################
# Upload Sanity
##############################################
if [ -f sanity-output.xml ]; then

cat > sanity-info.json <<EOF
{
  "fields": {
    "project": { "key": "${PROJECT_KEY}" },
    "summary": "Parking App - Sanity (build ${BUILD_NUMBER})",
    "issuetype": { "name": "Test Execution" }
  },
  "xrayFields": {
    "testPlanKey": "${TP_KEY}"
  }
}
EOF

echo ">>> Uploading Sanity Execution to TP: ${TP_KEY}"

curl -s -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -F "results=@sanity-output.xml;type=text/xml" \
  -F "info=@sanity-info.json;type=application/json" \
  https://xray.cloud.getxray.app/api/v2/import/execution/robot/multipart

fi


##############################################
# Upload Regression
##############################################
if [ -f reg-output.xml ]; then

cat > reg-info.json <<EOF
{
  "fields": {
    "project": { "key": "${PROJECT_KEY}" },
    "summary": "Parking App - Regression (build ${BUILD_NUMBER})",
    "issuetype": { "name": "Test Execution" }
  },
  "xrayFields": {
    "testPlanKey": "${TP_KEY}"
  }
}
EOF

echo ">>> Uploading Regression Execution to TP: ${TP_KEY}"

curl -s -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -F "results=@reg-output.xml;type=text/xml" \
  -F "info=@reg-info.json;type=application/json" \
  https://xray.cloud.getxray.app/api/v2/import/execution/robot/multipart

fi

echo ">>> All uploads completed"
            '''
        }
    }
}
