Set-Location -Path $env:localappdata\Android\Sdk\platform-tools\
.\adb disconnect localhost:5555
Set-Location -Path $env:C:\Files\flutter_application_2\android\
.\gradlew --stop