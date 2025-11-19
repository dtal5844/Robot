pipeline {
    agent any

    parameters {
        string(
            name: 'TEST_PLAN_KEY',
            defaultValue: 'AUT-1',
            description: 'Xray Test Plan key, e.g. AUT-12'
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
                // אם יש כשל – ה-stage נכשל, אבל הפייפליין ממשיך
                catchError(buildResult: 'FAILURE', stageResult: 'FAILURE') {
                    sh '''
                      set -e
                      . .venv/bin/activate
                      robot --output sanity-output.xml --report sanity-report.html --log sanity-log.html tests/sanity
                    '''
                }
            }

            post {
                always {

                    // ⬇️ טעינת הדוחות אוטומטית ב-Jenkins
                    robot(
                        outputPath: '.',
                        outputFileName: '*-output.xml',
                        reportFileName: '*-report.html',
                        logFileName: '*-log.html',
                        otherFiles: "**/*.png",
                        passThreshold: 100.0,
                        unstableThreshold: 0.0,
                        enableCache: true
                    )

                    // ⬇️ העלאה ל-Xray (תמיד, גם אם יש כשל), בלי להפיל את ה-build
                    sh '''
                      . .venv/bin/activate

                      cat > sanity-info.json << EOF
                      {
                        "fields": {
                          "project": { "key": "${PROJECT_KEY}" },
                          "summary": "Sanity - Parking App (build ${BUILD_NUMBER})",
                          "issuetype": { "name": "Test Execution" }
                        },
                        "xrayFields": {
                          "testPlanKey": "${TEST_PLAN_KEY}"
                        }
                      }
                      EOF

                      echo ">>> Authenticating to Xray Cloud"
                      TOKEN=$(curl -s -H "Content-Type: application/json" -X POST \
                        --data "{ \\"client_id\\": \\"$XRAY_CLIENT_ID\\", \\"client_secret\\": \\"$XRAY_CLIENT_SECRET\\" }" \
                        https://xray.cloud.getxray.app/api/v2/authenticate | tr -d '"')

                      if [ -z "$TOKEN" ]; then
                        echo "!!! Failed to get Xray token (TOKEN is empty), skipping upload (not failing build)"
                        exit 0
                      fi

                      echo ">>> Uploading Sanity results to Xray (plan ${TEST_PLAN_KEY})"

                      set +e
                      curl -s -X POST \
                        -H "Authorization: Bearer $TOKEN" \
                        -F "results=@sanity-output.xml;type=text/xml" \
                        -F "info=@sanity-info.json;type=application/json" \
                        https://xray.cloud.getxray.app/api/v2/import/execution/robot/multipart
                      XRAY_STATUS=$?
                      set -e

                      if [ $XRAY_STATUS -ne 0 ]; then
                        echo "!!! Xray upload for Sanity failed with status $XRAY_STATUS (NOT failing build)"
                      else
                        echo ">>> Xray upload for Sanity finished successfully"
                      fi
                    '''
                }
            }
        }

        stage('Run Regression') {
            steps {
                // גם כאן – לא עוצר את הפייפליין אם הטסטים נופלים
                catchError(buildResult: 'FAILURE', stageResult: 'FAILURE') {
                    sh '''
                      set -e
                      . .venv/bin/activate
                      robot --output reg-output.xml --report reg-report.html --log reg-log.html tests/regression
                    '''
                }
            }

            post {
                always {

                    robot(
                        outputPath: '.',
                        outputFileName: '*-output.xml',
                        reportFileName: '*-report.html',
                        logFileName: '*-log.html',
                        otherFiles: "**/*.png",
                        passThreshold: 100.0,
                        unstableThreshold: 0.0,
                        enableCache: true
                    )

                    sh '''
                      . .venv/bin/activate

                      cat > reg-info.json << EOF
                      {
                        "fields": {
                          "project": { "key": "${PROJECT_KEY}" },
                          "summary": "Regression - Parking App (build ${BUILD_NUMBER})",
                          "issuetype": { "name": "Test Execution" }
                        },
                        "xrayFields": {
                          "testPlanKey": "${TEST_PLAN_KEY}"
                        }
                      }
                      EOF

                      echo ">>> Authenticating to Xray Cloud"
                      TOKEN=$(curl -s -H "Content-Type: application/json" -X POST \
                        --data "{ \\"client_id\\": \\"$XRAY_CLIENT_ID\\", \\"client_secret\\": \\"$XRAY_CLIENT_SECRET\\" }" \
                        https://xray.cloud.getxray.app/api/v2/authenticate | tr -d '"')

                      if [ -z "$TOKEN" ]; then
                        echo "!!! Failed to get Xray token (TOKEN is empty), skipping upload (not failing build)"
                        exit 0
                      fi

                      echo ">>> Uploading Regression results to Xray (plan ${TEST_PLAN_KEY})"

                      set +e
                      curl -s -X POST \
                        -H "Authorization: Bearer $TOKEN" \
                        -F "results=@reg-output.xml;type=text/xml" \
                        -F "info=@reg-info.json;type=application/json" \
                        https://xray.cloud.getxray.app/api/v2/import/execution/robot/multipart
                      XRAY_STATUS=$?
                      set -e

                      if [ $XRAY_STATUS -ne 0 ]; then
                        echo "!!! Xray upload for Regression failed with status $XRAY_STATUS (NOT failing build)"
                      else
                        echo ">>> Xray upload for Regression finished successfully"
                      fi
                    '''
                }
            }
        }
    }
}
