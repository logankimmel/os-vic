# This installs docker
invoke-webrequest -UseBasicparsing -Outfile docker-17.06.2-ee-7.zip https://download.docker.com/components/engine/windows-server/17.06/docker-17.06.2-ee-7.zip

Expand-Archive docker-17.06.2-ee-7.zip -DestinationPath $Env:ProgramFiles

Remove-Item -Force docker-17.06.2-ee-7.zip

# Install Docker. This requires rebooting.
$null = Install-WindowsFeature containers
