# This configures the docker engine

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
# Start the Docker service.
Start-Service docker
