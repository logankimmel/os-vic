# Open Source VIC Appliance
This repository contains scripts for automating the setup of a VM
that contains [Admiral](https://github.com/vmware/admiral),
[Harbor](http://vmware.github.io/harbor/), and [Admiral IDM](https://github.com/logankimmel/Admiral-IDM).

In addition, there are scripts for automating setting up a windows and linux
docker container host and automatically adding them to the Admiral instance.

### Requirements
* RHEL 7 / CentOS (for vic appliance and Linux DCH)
* Windows 2016 (for Windows DCH)

### Usage

#### VIC Appliance provisioning
* Deploy new RHEL or CentOS 7 Machine
* Set the env vars `VICADMIN` and `VICPASS` to override the
default username and password.  *note*, `VICADMIN` must be in email format.
* Run `vic_appliance.sh` script as an admin
* Services can be reached at:
  * Admiral: `http://{ip}:8282`
  * Harbor: `https://{ip}`
  * Admiral IDM: `http://{ip}:8080`

#### Adding Linux DCH to VIC Appliance
* Deploy new RHEL or CentOS 7 Machine
* To have the machine automatically added to the previously deployed
VIC Appliance, set the Environment vars: `VICHOSTNAME, VICADMIN, VICPASS`.
Otherwise, the script will set up a Docker Container Host that can be accessed
externally
* Run `dch_linx.sh`

#### Adding Windows DCH to VIC appliance
* Deploy new Windows 2016 machine
* To have the machine automatically added to the previously deployed
VIC Appliance, set the Environment vars: `VICHOSTNAME, VICADMIN, VICPASS`.
Otherwise, the script will set up a Docker Container Host that can be accessed
externally
* Run `dch_windows1_1.ps1`
* restart
* Run `dch_windows_2.ps1`
