pipeline {
    agent any

    parameters {
        string(
            name: 'TEST_PLAN_KEY',
            defaultValue: '',
            description: 'Optional: Xray Test Plan key (e.g. AUT-12). Leave empty to skip linking to a Test Plan.'
        )
    }

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

TOKEN=$(echo "$RAW_RESPONSE" | tr -d '"')

if [ -z "$TOKEN" ]; then
  echo "!!! TOKEN is empty, cannot upload to Xray"
  exit 1
fi

echo ">>> Got Xray token"


####################################
# Helper: build info JSON for TE
####################################
build_info_json() {
  OUTPUT_FILE="$1"
  SUMMARY="$2"
  INFO_JSON="$3"

  if [ -n "$TEST_PLAN_KEY" ]; then
    # עם Test Plan
    cat > "$INFO_JSON" <<EOF
{
  "fields": {
    "project": { "key": "${PROJECT_KEY}" },
    "summary": "${SUMMARY}",
    "issuetype": { "name": "Test Execution" }
  },
  "xrayFields": {
    "testPlanKey": "${TEST_PLAN_KEY}"
  }
}
EOF
  else
    # בלי Test Plan
    cat > "$INFO_JSON" <<EOF
{
  "fields": {
    "project": { "key": "${PROJECT_KEY}" },
    "summary": "${SUMMARY}",
    "issuetype": { "name": "Test Execution" }
  }
}
EOF
  fi
}


####################################
# Sanity Execution -> Xray
####################################
if [ -f sanity-output.xml ]; then
  echo ">>> Preparing Sanity info JSON"
  build_info_json "sanity-output.xml" "Parking App - Sanity (build ${BUILD_NUMBER})" "sanity-info.json"

  echo ">>> Uploading sanity-output.xml to Xray..."
  SANITY_HTTP_CODE=$(curl -s -o xray_sanity_response.json -w "%{http_code}" \
    -X POST \
    -H "Authorization: Bearer $TOKEN" \
    -F "results=@sanity-output.xml;type=text/xml" \
    -F "info=@sanity-info.json;type=application/json" \
    https://xray.cloud.getxray.app/api/v2/import/execution/robot/multipart)

  echo ">>> Xray HTTP code (Sanity): $SANITY_HTTP_CODE"
  echo ">>> Xray response body (Sanity):"
  cat xray_sanity_response.json

  if [ "$SANITY_HTTP_CODE" != "200" ] && [ "$SANITY_HTTP_CODE" != "201" ]; then
    echo "!!! Xray upload for Sanity failed with HTTP $SANITY_HTTP_CODE"
    exit 1
  fi
else
  echo ">>> sanity-output.xml missing, skipping Sanity upload"
fi


####################################
# Regression Execution -> Xray
####################################
if [ -f reg-output.xml ]; then
  echo ">>> Preparing Regression info JSON"
  build_info_json "reg-output.xml" "Parking App - Regression (build ${BUILD_NUMBER})" "reg-info.json"

  echo ">>> Uploading reg-output.xml to Xray..."
  REG_HTTP_CODE=$(curl -s -o xray_reg_response.json -w "%{http_code}" \
    -X POST \
    -H "Authorization: Bearer $TOKEN" \
    -F "results=@reg-output.xml;type=text/xml" \
    -F "info=@reg-info.json;type=application/json" \
    https://xray.cloud.getxray.app/api/v2/import/execution/robot/multipart)

  echo ">>> Xray HTTP code (Regression): $REG_HTTP_CODE"
  echo ">>> Xray response body (Regression):"
  cat xray_reg_response.json

  if [ "$REG_HTTP_CODE" != "200" ] && [ "$REG_HTTP_CODE" != "201" ]; then
    echo "!!! Xray upload for Regression failed with HTTP $REG_HTTP_CODE"
    exit 1
  fi
else
  echo ">>> reg-output.xml missing, skipping Regression upload"
fi

echo ">>> All uploads to Xray completed"
            '''
        }
    }
}
