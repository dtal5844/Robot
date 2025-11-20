*** Settings ***
Documentation  AUT-20
Library    Browser
Default Tags   AUT-20

*** Test Cases ***
Parking App Loads - Sanity
    New Browser    chromium    headless=${True}
    New Page    http://host.docker.internal:4000/
    Wait For Elements State    h1    visible    timeout=10s
    ${title}=    Get Text    h1
    Should Contain    ${title}    ניהול חניון מגורים
    Close Browser
