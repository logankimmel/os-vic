# This configures the docker engine
$ErrorActionPreference = "Stop"

# Add Docker to the path for the current session.
$env:path += ";$env:ProgramFiles\docker"

# Modify PATH to persist across sessions.
$newPath = "$env:ProgramFiles\docker;" +
[Environment]::GetEnvironmentVariable("PATH", [EnvironmentVariableTarget]::Machine)

[Environment]::SetEnvironmentVariable("PATH", $newPath,
[EnvironmentVariableTarget]::Machine)

# Register the Docker daemon as a service and listen on 2375
dockerd -H tcp://0.0.0.0:2375 --register-service

# Open the firewall for the docker API
New-NetFirewallRule -DisplayName 'Docker Inbound' -Profile @('Domain', 'Public', 'Private') -Direction Inbound -Action Allow -Protocol TCP -LocalPort 2375

If ($args.Length -eq 0) {
    echo "No Admiral enpoint supplied. Will function as standalone Docker Host"
    exit
} Else {
    $endpoint=$args[0]
    $admiralAdmin=$args[1]
    $admiralPass=$args[2]
    mkdir C:\ProgramData\docker\config
    echo "{`"insecure-registries`" : [`"$endpoint`:443`", `"$endpoint`"] }" | Out-File C:\ProgramData\docker\config\daemon.json -Encoding ascii

}

# Start the Docker service.
Start-Service docker

# Register the docker host to the Admiral endpoint

$url = "http://" + $endpoint + ":8282/core/authn/basic"
$Data = @{
    requestType = "LOGIN"
} | ConvertTo-Json
$secpasswd = ConvertTo-SecureString $admiralPass -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential ($admiralAdmin, $secpasswd)

$res = Invoke-WebRequest -Method Post -Uri $url -Credential $Cred -ContentType "application/json" -Body $Data

$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("x-xenon-auth-token", $res.Headers.'x-xenon-auth-token')
$headers.Add("x-project", "/projects/default-project")

$ip = Get-NetIPAddress -InterfaceAlias 'Ethernet0' -AddressFamily IPv4
$addr = $ip.IPv4Address

$url = "http://192.168.88.128:8282/resources/clusters?%24limit=50&expand=true&documentType=true&%24count=true"
$res = Invoke-RestMethod -Method Get -Uri $url -ContentType "application/json" -Headers $headers

If ($res.documentLinks.Length -eq 0) {
  echo "No current clusters, adding host to Default Cluster"
  $data = @{
    hostState = @{
      address = "http://" + $addr + ":2375"
      customProperties = @{
        __containerHostType = "DOCKER"
        __adapterDockerType = "API"
        __clusterName = "Default"
      }
    }
    acceptCertificate = "false"
  } | ConvertTo-Json
  $url = "http://" + $endpoint + ":8282/resources/clusters"
  $res = Invoke-RestMethod -Method Post -Uri $url -ContentType "application/json" -Body $Data -Headers $headers
  echo "Successfully added new Docker host to Admiral cluster"
} Else {
  echo "Adding host to existing Default Cluster"
  foreach ($documentLink in $res.documentLinks) {
    if ($res.documents.$documentLink.Name -eq "Default") {
      $data = @{
        hostState = @{
          address = "http://" + $addr + ":2375"
          customProperties = @{
            __containerHostType = "DOCKER"
            __adapterDockerType = "API"
            __hostAlias = hostname
          }
        }
        acceptCertificate = "false"
      } | ConvertTo-Json
      $url = "http://" + $endpoint + ":8282" + $documentLink + "/hosts"
      $res = Invoke-RestMethod -Method POST -Uri $url -ContentType "application/json" -Body $data -Headers $Headers
      echo "Successfully added Host to existing default cluster in default project"
      break
    }
  }
}
exit 0
