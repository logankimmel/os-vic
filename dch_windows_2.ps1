# This configures the docker engine
# Stop on failure
Try {
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

    echo "VICHOSTNAME = $VICHOSTNAME"
    # Add Harbor registry (insecure due to self-signed cert)
    If (!$VICHOSTNAME) {
        echo "No Admiral enpoint supplied. Will function as standalone Docker Host"
        # Start the Docker service.
        echo "Starting Docker service"
        Start-Service docker
        exit 0
    } Else {
        echo "Adding Harbor registry to Docker daemon"
        mkdir C:\ProgramData\docker\config
        echo "{`"insecure-registries`" : [`"$VICHOSTNAME`:443`", `"$VICHOSTNAME`"] }" | Out-File C:\ProgramData\docker\config\daemon.json -Encoding ascii
        # Start the Docker service.
        echo "Starting Docker service"
        Start-Service docker
    }

    # Register the docker host to the Admiral VICHOSTNAME
    $url = "http://" + $VICHOSTNAME + ":8282/core/authn/basic"
    $Data = @{
        requestType = "LOGIN"
    } | ConvertTo-Json
    $secpasswd = ConvertTo-SecureString $VICPASS -AsPlainText -Force
    $cred = New-Object System.Management.Automation.PSCredential ($VICADMIN, $secpasswd)

    echo "Authenticating to Admiral"
    $res = Invoke-WebRequest -Method Post -UseBasicParsing -Uri $url -Credential $Cred -ContentType "application/json" -Body $Data

    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("x-xenon-auth-token", $res.Headers.'x-xenon-auth-token')
    $headers.Add("x-project", "/projects/default-project")

    $ip = Get-NetIPAddress -InterfaceAlias 'Ethernet0' -AddressFamily IPv4
    $addr = $ip.IPv4Address

    echo "Getting current clusters"
    $url = "http://$VICHOSTNAME`:8282/resources/clusters?%24limit=50&expand=true&documentType=true&%24count=true"
    $res = Invoke-RestMethod -UseBasicParsing -Method Get -Uri $url -ContentType "application/json" -Headers $headers
    $winCluster = ""
    foreach ($documentLink in $res.documentLinks) {
      if ($res.documents.$documentLink.Name -eq "Default-Windows") {
        $winCluster = $documentLink
        break
      }
    }
    If ($winCluster -eq "") {
      echo "No current clusters, adding host to Default Cluster"
      $data = @{
        hostState = @{
          address = "http://" + $addr + ":2375"
          customProperties = @{
            __containerHostType = "DOCKER"
            __adapterDockerType = "API" #TODO Investigate this (maybe there's a better adapter for win)
            __clusterName = "Default-Windows"
          }
        }
        acceptCertificate = "false"
      } | ConvertTo-Json
      $url = "http://" + $VICHOSTNAME + ":8282/resources/clusters"
      $res = Invoke-RestMethod -UseBasicParsing -Method Post -Uri $url -ContentType "application/json" -Body $Data -Headers $headers
      echo "Successfully added new Docker host to Admiral cluster"
    } Else {
      echo "Adding host to existing Default Cluster"
      $data = @{
        hostState = @{
          address = "http://" + $addr + ":2375"
          customProperties = @{
            __containerHostType = "DOCKER"
            __adapterDockerType = "API" #TODO: see above
            __hostAlias = hostname
          }
        }
        acceptCertificate = "false"
      } | ConvertTo-Json
      $url = "http://" + $VICHOSTNAME + ":8282" + $winCluster + "/hosts"
      $res = Invoke-RestMethod -UseBasicParsing -Method POST -Uri $url -ContentType "application/json" -Body $data -Headers $Headers
      echo "Successfully added Host to existing default cluster in default project"
    }
exit 0
}
Catch {
  echo $_.Exception.Message
  echo $_.Exception.ItemName
}
