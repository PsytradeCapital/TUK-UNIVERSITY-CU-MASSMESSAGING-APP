@echo off 
echo Building Complete TUK CU App... 
set JAVA_HOME=C:\Program Files\Android\Android Studio\jbr 
set PATH=%C:\Program Files\Android\Android Studio\jbr%\bin;%C:\Program Files\Android\Android Studio\jbr\bin;C:\Program Files\Android\Android Studio\jbr\bin;%PATH%;C:\Users\Martin Mbugua\AppData\Local\Android\Sdk\platform-tools;C:\Users\Martin Mbugua\AppData\Local\Android\Sdk\tools;C:\Program Files (x86)\Falcon\MinGW\bin;C:\Program Files (x86)\Common Files\Intel\Shared Libraries\redist\intel64_win\compiler;C:\WINDOWS\system32;C:\WINDOWS;C:\WINDOWS\System32\Wbem;C:\WINDOWS\System32\WindowsPowerShell\v1.0\;C:\WINDOWS\System32\OpenSSH\;C:\Program Files\dotnet\;C:\ProgramData\chocolatey\bin;C:\Users\Martin Mbugua\AppData\Local\Programs\Python\Launcher\;C:\Users\Martin Mbugua\AppData\Local\Microsoft\WindowsApps;C:\ProgramData\Martin Mbugua\GitHubDesktop\bin;C:\Users\Martin Mbugua\AppData\Local\Programs\Microsoft VS Code\bin;C:\Users\Martin Mbugua\AppData\Local\Microsoft\WinGet\Packages\Schniz.fnm_Microsoft.Winget.Source_8wekyb3d8bbwe;C:\Program Files\nodejs\;C:\Program Files\PostgreSQL\17\bin;C:\Program Files\Git\cmd;C:\Users\Martin Mbugua\AppData\Local\Programs\Python\Launcher\;C:\Users\Martin Mbugua\AppData\Local\Microsoft\WindowsApps;C:\ProgramData\Martin Mbugua\GitHubDesktop\bin;C:\Users\Martin Mbugua\AppData\Local\Programs\Microsoft VS Code\bin;C:\Users\Martin Mbugua\AppData\Local\Programs\Kiro\bin;C:\Users\Martin Mbugua\AppData\Roaming\npm% 
echo Testing Java... 
"%C:\Program Files\Android\Android Studio\jbr%\bin\java.exe" -version 
if errorlevel 1 goto :java_error 
echo Java OK, building app... 
C:\flutter\bin\flutter.bat build apk --release 
goto :end 
:java_error 
echo Java not found, using Android Studio instead 
echo Please use Android Studio: Build -> Generate Signed Bundle / APK 
:end 
pause 
