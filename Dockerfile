# escape=`

FROM jetbrains/teamcity-minimal-agent:latest-windowsservercore-1709 AS tools

SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

# Install Chocolatey
RUN [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; `
    Set-ExecutionPolicy Bypass -Scope Process -Force; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'));

# Install Build Agent Software
RUN choco install git.install -y -f -r
RUN choco install nodejs.install -y -f -r
RUN choco install yarn -y -f -r
RUN choco install nuget.commandline -y -f -r
RUN choco install nunit-console-runner -y -f -r

# Install Open JDK
RUN [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; `
    Invoke-WebRequest -URI https://github.com/ojdkbuild/ojdkbuild/releases/download/1.8.0.151-1/java-1.8.0-openjdk-1.8.0.151-1.b12.ojdkbuild.windows.x86_64.zip -OutFile openjdk.zip; `
    Expand-Archive openjdk.zip -DestinationPath $Env:ProgramFiles\Java; `
    Get-ChildItem -Path $Env:ProgramFiles\Java -Filter "java-*-openjdk*" | ForEach-Object {$_ | Rename-Item -NewName "OpenJDK" }; `
	Remove-Item -Force $Env:ProgramFiles\Java\OpenJDK\src.zip; `
    Remove-Item -Force openjdk.zip;

FROM microsoft/dotnet-framework:4.7.2-runtime-windowsservercore-1803
SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

ENV CONFIG_FILE="C:/BuildAgent/conf/buildAgent.properties" `
    JRE_HOME="C:\Program Files\Java\Oracle\jre\bin" `
    NUGET_XMLDOC_MODE=skip `
    DOTNET_CLI_TELEMETRY_OPTOUT=true `
    DOTNET_SKIP_FIRST_TIME_EXPERIENCE=true `
    GIT_PATH="C:\Program Files\Git\bin" `
    NODEJS_PATH="C:\Program Files\NodeJS" `
    YARN_PATH="C:\Program Files (x86)\Yarn\bin" `
    NUGET_PATH="C:\ProgramData\Chocolatey\lib\NuGet.CommandLine\tools" `
    NUNIT_PATH="C:\ProgramData\Chocolatey\lib\nunit-console-runner\tools" `
    MSBUILD_PATH="C:\Program Files (x86)\Microsoft Visual Studio\2017\BuildTools\MSBuild\15.0\Bin"

EXPOSE 9090

VOLUME C:/BuildAgent/conf

COPY --from=tools /BuildAgent /BuildAgent
COPY --from=tools ["C:/Program Files/Git", "C:/Program Files/Git"]
COPY --from=tools ["C:/Program Files/NodeJS", "C:/Program Files/NodeJS"]
COPY --from=tools ["C:/Program Files (x86)/Yarn/bin", "C:/Program Files (x86)/Yarn/bin"]
COPY --from=tools ["C:/Program Files/Java/Oracle", "C:/Program Files/Java/Oracle"]
COPY --from=tools ["C:/Program Files/Java/OpenJDK", "C:/Program Files/Java/OpenJDK"]

# Set PATH in one layer to keep image size down.
RUN setx /M PATH $(${Env:PATH} + ';' + ${Env:JRE_HOME} +';' + ';' + ${Env:GIT_PATH} + ';' + ${Env:NODEJS_PATH} + ';' + ${Env:YARN_PATH} + ';' + ${Env:NUNIT_PATH} + ';' + ${Env:NUGET_PATH} + ';');

CMD ./BuildAgent/run-agent.ps1