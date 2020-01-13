# Dynamics 365 Business Central on Azure Setup - D365BCOnAzureHelper-Module
This modules is used to execute commands on prepared VM. If you have no idea, what this is about, please read [this blog-post series](http://simonofhh.tech/2020/01/12/load-balanced-dynamics-365-business-central-scale-sets-on-azure-introduction/).

## Command Documentation
Command | Description | Parameter 1 | Parameter 2
--- | --- | --- | ---
`SetupNotDone` | Stops automatic VM-update (used during setup, when VMs are still rebooting) | `ClearLog` (optional; will remove existing bogus logs from "C:\Install\Log") | none
`CreateInstances` | Creates NAV/BC-instances, based on the data in the "Environments"-storage table | `TypeFilter` (optional; see *TypeFilter-explanation*) | none
`UpdateInstanceConfiguration` | Updates existing NAV/BC-instances, based on the data in the "Environments"- and "EnvironmentDefaultValues"-storage tables | `TypeFilter` (optional; see *TypeFilter-explanation*) | none
`UpdateLicense` | Updates the license for existing NAV/BC-instances | `TypeFilter` (optional; see *TypeFilter-explanation*) | `LicenseFileUri` (add URI to a downloadable license-file; script will first receive the file and then update all instances)
`CreateWebInstances` | Creates NAV/BC-Webclient-instances, based on the data in the "Environments"-storage table | `TypeFilter` (optional; see *TypeFilter-explanation*) | none
`UpdateWebInstances` | Updates existing NAV/BC-Webclient-instances, based on the data in the "Environments"- and "EnvironmentDefaultValues"-storage tables | `TypeFilter` (optional; see *TypeFilter-explanation*) | none
`SetLoadbalancerDNSRecord` | Adds an DNS-entry for the Load Balancer Hostname on the Domain Controller, based on the data in the "Environments"- and "Infrastructure"-storage tables | none | none
`CreateSPN` | Registers Service Principal Names (SPN) on the Domain Controller for the Load Balancer Hostname, based on the data in the "Environments"- and "Infrastructure"-storage tables | `TypeFilter` (optional; see *TypeFilter-explanation*) | none
`SetupDelegation` | Configures delegation, based on previously registered Service Principal Names (SPN) on the Domain Controller to enable Windows-authentication from the Webserver, over the Load Balancer, on the Application Server; based on the data in the "Environments"- and "Infrastructure"-storage tables | `TypeFilter` (optional; see *TypeFilter-explanation*) | none
`RestartServices` | Restarts NAV/BC-instances, based on the data in the "Environments"-storage table | `TypeFilter` (optional; see *TypeFilter-explanation*) | none
`RestartIIS` | Restarts IIS (Internet Information Service) on the Webserver | none | none
`AddUsers` | Adds users to existing NAV/BC-instances; based on the data in the "Environments"- and "Users"-storage tables | `TypeFilter` (optional; see *TypeFilter-explanation*) | none

### TypeFilter-explanation
The `TypeFilter`-parameter is used to differentiate between test- and production-environments (or even more different environments) in the setup. E.g. you could have the following tables, where "Parameter 1" of the Setup-table is the TypeFilter for "Environments"

#### Setup
Command | ObjectName | Parameter 1 | Parameter 2 | RestartNecessary
--- | --- | --- | --- | --- 
CreateInstances | AppScaleSet | TEST |  | true
UpdateInstanceConfiguration | AppScaleSet | PROD |  | true

#### Environments
ServiceName | DatabaseName | DatabaseServer | ClientServicesPort | ... | TypeFilter
--- | --- | --- | --- | --- | ---
BCDEfault | Demo Database NAV (14-0) | SQL01 | 8046 | ... | TEST
PROD_DB | ProductionCompanyDB | SQL01 | 7046 | ... | PROD