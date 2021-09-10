[CmdletBinding()]
param()

#$DebugPreference = 'Continue'
$starttime = Get-Date

Write-Host "Start - $starttime"
$reporoot = 'C:\Git\AzureDocs\azure-docs-pr\articles'
$linkpattern = '.*(?<link>!?\[(?<label>[^\]]*)\]\((?<file>[^)#\?]*)?(?<query>\?[^)#]*)?(?<anchor>#[^)]+)?\)).*'

$targetmap = @{
  '/powershell' = '/powershell/azure/overview'
  '/powershell/azure/get-started-azureps' = '/powershell/azure/get-started-azureps'
  '/powershell/azure/install-azurerm-ps' = '/powershell/azure/install-azurerm-ps'
  '/powershell/azure/overview' = '/powershell/azure/overview'
  '/powershell/azuread' = '/powershell/azure/install-adv2?view=azureadps-2.0'
  '/powershell/azuread/v2/azureactivedirectory' = '/powershell/azure/install-adv2?view=azureadps-2.0'
  '/powershell/azureps-cmdlets-docs' = '/powershell/azure/overview'
  '/powershell/module/servicefabric' = '/powershell/azure/overview?view=azureservicefabricps'
  '/powershell/msonline' = '/powershell/azure/install-msonlinev1?view=azureadps-2.0'
  '/powershell/resourcemanager' = '/powershell/azure/overview'
  '/powershell/servicefabric/vlatest/servicefabric' = '/powershell/azure/overview?view=azureservicefabricps'
  '/powershell/servicemanagement' = '/powershell/azure/overview?view=azuresmps-3.7.0'
  '/powershell/storage' = '/powershell/module/azure.storage'
}

$msdnmappings = @{
  'active-directory\active-directory-deploying-ws-ad-guidelines.md' = @{
    'https://msdn.microsoft.com/library/azure/jj152841' = '/powershell/module/azurerm.compute/#virtual_machines'
  }
  '.\active-directory\active-directory-install-replica-active-directory-domain-controller.md' = @{
    'https://msdn.microsoft.com/library/azure/jj554332.aspx' = '/powershell/azure/overview'
    'https://msdn.microsoft.com/library/azure/jj554330.aspx' = '/powershell/azure/get-started-azureps'
    'https://msdn.microsoft.com/library/azure/jj156055.aspx' = '/powershell/azure/overview'
    'https://msdn.microsoft.com/library/azure/jj152841' = '/powershell/module/azurerm.compute/#virtual_machines'
  }
  '.\active-directory\active-directory-new-forest-virtual-machine.md' = @{
    'https://msdn.microsoft.com/library/azure/jj554332.aspx' = '/powershell/azure/overview'
    'https://msdn.microsoft.com/library/azure/jj554330.aspx' = '/powershell/azure/get-started-azureps'
    'https://msdn.microsoft.com/library/azure/jj156055.aspx' = '/powershell/azure/overview'
  }
  '.\active-directory\active-directory-self-service-signup.md' = @{
    'https://msdn.microsoft.com/library/azure/jj554330.aspx' = '/powershell/azure/get-started-azureps'
    'https://msdn.microsoft.com/library/azure/jj156055.aspx' = '/powershell/azure/overview'
    'https://msdn.microsoft.com/library/azure/dn194127.aspx' = '/powershell/module/msonline/set-msolcompanysettings?view=azureadps-1.0'
  }
  '.\active-directory\role-based-access-control-manage-access-powershell.md' = @{
    'https://msdn.microsoft.com/library/mt125356.aspx' = '/powershell/azure/overview'
    'https://msdn.microsoft.com/library/dn495302.aspx' = '/powershell/module/azure/get-azuresubscription?view=azuresmps-3.7.0'
  }
  '.\automation\automation-credentials.md' = @{
    'http://msdn.microsoft.com/library/dn913781.aspx' = '/powershell/module/azure/get-azureautomationcredential?view=azuresmps-3.7.0'
    'http://msdn.microsoft.com/library/azure/jj554330.aspx' = '/powershell/module/azure/new-azureautomationcredential?view=azuresmps-3.7.0'
  }
  '.\automation\automation-dsc-compile.md' = @{
    'https://msdn.microsoft.com/library/mt244118.aspx' = '/powershell/module/azurerm.automation/start-azurermautomationdsccompilationjob'
    'https://msdn.microsoft.com/library/mt244120.aspx' = '/powershell/module/azurerm.automation/get-azurermautomationdsccompilationjob'
    'https://msdn.microsoft.com/library/mt244103.aspx' = '/powershell/module/azurerm.automation/get-azurermautomationdsccompilationjoboutput'
  }
  '.\automation\automation-dsc-getting-started.md' = @{
    'https://msdn.microsoft.com/library/mt244122.aspx' = '/powershell/module/azurerm.automation/#automation'
  }
  '.\automation\automation-dsc-onboarding.md' = @{
    'https://msdn.microsoft.com/library/mt603833.aspx' = '/powershell/module/azurerm.automation/register-azurermautomationdscnode'
    'https://msdn.microsoft.com/library/mt244122.aspx' = '/powershell/module/azurerm.automation/#automation'
  }
  '.\automation\automation-dsc-overview.md' = @{
    'https://msdn.microsoft.com/library/mt244122.aspx' = '/powershell/module/azurerm.automation/#automation'
  }
  '.\automation\automation-schedules.md' = @{
    'https://msdn.microsoft.com/library/mt603733.aspx' = '/powershell/module/azurerm.automation/get-azurermautomationschedule'
    'https://msdn.microsoft.com/library/mt603577.aspx' = '/powershell/module/azurerm.automation/new-azurermautomationschedule'
    'https://msdn.microsoft.com/library/mt603691.aspx' = '/powershell/module/azurerm.automation/remove-azurermautomationschedule'
    'https://msdn.microsoft.com/library/mt603566.aspx' = '/powershell/module/azurerm.automation/set-azurermautomationschedule'
    'https://msdn.microsoft.com/library/mt619406.aspx' = '/powershell/module/azurerm.automation/set-azurermautomationscheduledrunbook'
    'https://msdn.microsoft.com/library/mt603575.aspx' = '/powershell/module/azurerm.automation/register-azurermautomationscheduledrunbook'
    'https://msdn.microsoft.com/library/mt603844.aspx' = '/powershell/module/azurerm.automation/unregister-azurermautomationscheduledrunbook'
    'http://msdn.microsoft.com/library/dn690274.aspx' = '/powershell/module/azure/get-azureautomationschedule?view=azuresmps-3.7.0'
    'http://msdn.microsoft.com/library/azure/dn690271.aspx' = '/powershell/module/azure/new-azureautomationschedule?view=azuresmps-3.7.0'
    'http://msdn.microsoft.com/library/dn690271.aspx' = '/powershell/module/azure/new-azureautomationschedule?view=azuresmps-3.7.0'
    'http://msdn.microsoft.com/library/dn690279.aspx' = '/powershell/module/azure/remove-azureautomationschedule?view=azuresmps-3.7.0'
    'http://msdn.microsoft.com/library/dn690270.aspx' = '/powershell/module/azure/set-azureautomationschedule?view=azuresmps-3.7.0'
    'http://msdn.microsoft.com/library/dn913778.aspx' = '/powershell/module/azure/get-azureautomationscheduledrunbook?view=azuresmps-3.7.0'
    'http://msdn.microsoft.com/library/dn690265.aspx' = '/powershell/module/azure/register-azureautomationscheduledrunbook?view=azuresmps-3.7.0'
    'http://msdn.microsoft.com/library/dn690273.aspx' = '/powershell/module/azure/unregister-azureautomationscheduledrunbook?view=azuresmps-3.7.0'
  }
  '.\automation\automation-sec-configure-azure-runas-account.md' = @{
    'https://msdn.microsoft.com/library/mt619263.aspx' = '/powershell/module/azurerm.profile/set-azurermcontext'
  }
  '.\automation\automation-variables.md' = @{
    'http://msdn.microsoft.com/library/dn913767.aspx' = '/powershell/module/azurerm.automation/set-azurermautomationvariable'
    'https://msdn.microsoft.com/library/mt603601.aspx' = '/powershell/module/azurerm.automation/set-azurermautomationvariable'
    'https://msdn.microsoft.com/library/mt603613.aspx' = '/powershell/module/azurerm.automation/new-azurermautomationvariable'
    'https://msdn.microsoft.com/library/mt603849.aspx' = '/powershell/module/azurerm.automation/get-azurermautomationvariable'
    'https://msdn.microsoft.com/library/mt619354.aspx' = '/powershell/module/azurerm.automation/remove-azurermautomationvariable'
    'http://msdn.microsoft.com/library/dn913771.aspx' = '/powershell/module/azure/new-azureautomationvariable?view=azuresmps-3.7.0'
  }
  '.\azure-classic-rm.md' = @{
    'https://msdn.microsoft.com/library/azure/mt125356.aspx' = '/powershell/azure/overview'
    'https://msdn.microsoft.com/library/azure/dn708504.aspx' = '/powershell/azure/overview?view=azuresmps-3.7.0'
  }
  '.\azure-government\documentation-government-get-started-connect-with-ps.md' = @{
    'https://msdn.microsoft.com/library/dn708504.aspx' = '/powershell/module/azure/add-azureaccount?view=azuresmps-3.7.0'
    'https://msdn.microsoft.com/library/mt125356.aspx' = '/powershell/module/azurerm.profile/add-azurermaccount'
    'https://msdn.microsoft.com/library/azure/mt757189.aspx' = '/powershell/module/azuread/connect-azuread?view=azureadps-2.0'
  }
  '.\batch\batch-powershell-cmdlets-get-started.md' = @{
    'https://msdn.microsoft.com/library/azure/mt125957.aspx' = '/powershell/module/azurerm.batch/#batch'
    'https://msdn.microsoft.com/library/azure/mt603739.aspx' = '/powershell/module/azurerm.resources/new-azurermresourcegroup'
  }
  '.\cloud-services\cloud-services-diagnostics-powershell.md' = @{
    'https://msdn.microsoft.com/library/azure/mt589089.aspx' = '/powershell/module/azure/new-azuredeployment?view=azuresmps-3.7.0'
    'https://msdn.microsoft.com/library/azure/mt589168.aspx' = '/powershell/module/azure/new-azureservicediagnosticsextensionconfig?view=azuresmps-3.7.0'
    'https://msdn.microsoft.com/library/azure/mt589140.aspx' = '/powershell/module/azure/set-azureservicediagnosticsextension?view=azuresmps-3.7.0'
    'https://msdn.microsoft.com/library/azure/mt589204.aspx' = '/powershell/module/azure/get-azureservicediagnosticsextension?view=azuresmps-3.7.0'
    'https://msdn.microsoft.com/library/azure/mt589183.aspx' = '/powershell/module/azure/remove-azureservicediagnosticsextension?view=azuresmps-3.7.0'
  }
  '.\cloud-services\cloud-services-powershell-create-cloud-container.md' = @{
    'https://msdn.microsoft.com/library/Dn654594.aspx' = '/powershell/module/azure/new-azureresourcegroup?view=azuresmps-3.7.0'
  }
  '.\cloud-services\cloud-services-role-enable-remote-desktop-powershell.md' = @{
    'https://msdn.microsoft.com/library/azure/dn495117.aspx' = '/powershell/module/azure/set-azureserviceremotedesktopextension?view=azuresmps-3.7.0'
    'https://msdn.microsoft.com/library/azure/dn495261.aspx' = '/powershell/module/azure/get-azureremotedesktopfile?view=azuresmps-3.7.0'
    'https://msdn.microsoft.com/library/azure/dn495280.aspx' = '/powershell/module/azure/remove-azureserviceremotedesktopextension?view=azuresmps-3.7.0'
  }
  '.\data-factory\data-factory-create-data-factories-programmatically.md' = @{
    'https://msdn.microsoft.com/library/Dn654594.aspx' = '/powershell/module/azure/new-azureresourcegroup?view=azuresmps-3.7.0'
  }
  '.\data-factory\data-factory-faq.md' = @{
    'https://msdn.microsoft.com/library/mt603721.aspx' = '/powershell/module/azurerm.datafactories/suspend-azurermdatafactorypipeline'
  }
  '.\key-vault\key-vault-get-started.md' = @{
    'https://msdn.microsoft.com/library/azure/dn868052\(v=azure.98\).aspx' = '/powershell/module/azurerm.keyvault/#key_vault'
    'https://msdn.microsoft.com/library/azure/mt603736\(v=azure.300\).aspx' = '/powershell/module/azurerm.keyvault/new-azurermkeyvault'
    'https://msdn.microsoft.com/library/azure/mt759831\(v=azure.300\).aspx' = '/powershell/module/azurerm.resources/register-azurermresourceprovider'
    'https://msdn.microsoft.com/library/azure/dn868048\(v=azure.300\).aspx' = '/powershell/module/azurerm.keyvault/add-azurermkeyvaultkey'
    'https://msdn.microsoft.com/library/azure/mt603625\(v=azure.300\).aspx' = '/powershell/module/azurerm.keyvault/set-azurermkeyvaultaccesspolicy'
    'https://msdn.microsoft.com/library/azure/mt619485\(v=azure.300\).aspx' = '/powershell/module/azurerm.keyvault/remove-azurermkeyvault'
    'https://msdn.microsoft.com/library/azure/dn868052\(v=azure.300\).aspx' = '/powershell/module/azurerm.keyvault/#key_vault'
  }
  '.\key-vault\key-vault-hsm-protected-keys.md' = @{
    'https://msdn.microsoft.com/library/azure/dn790366.aspx' = '/powershell/module/azure/get-azuresubscription?view=azuresmps-3.7.0'
    'https://msdn.microsoft.com/library/azure/dn868048\(v=azure.300\).aspx' = '/powershell/module/azurerm.keyvault/add-azurermkeyvaultkey'
  }
  '.\key-vault\key-vault-logging.md' = @{
    'https://msdn.microsoft.com/library/azure/dn868052.aspx' = '/powershell/module/azurerm.keyvault/#key_vault'
  }
  '.\machine-learning\machine-learning-data-science-move-sql-azure-adf.md' = @{
    'https://msdn.microsoft.com/library/azure/dn790372.aspx' = '/powershell/module/azure/add-azureaccount?view=azuresmps-3.7.0'
  }
  '.\remoteapp\remoteapp-tutorial-arawithpowershell.md' = @{
    'https://msdn.microsoft.com/library/mt428031.aspx' = '/powershell/module/azure?view=azuresmps-3.7.0'
  }
  '.\scheduler\scheduler-powershell-reference.md' = @{
    'https://msdn.microsoft.com/library/mt125356\(v=azure.200\).aspx' = '/powershell/azure/overview'
    'https://msdn.microsoft.com/library/mt490133\(v=azure.200\).aspx' = '/powershell/module/azurerm.scheduler/disable-azurermschedulerjobcollection'
    'https://msdn.microsoft.com/library/mt490135\(v=azure.200\).aspx' = '/powershell/module/azurerm.scheduler/enable-azurermschedulerjobcollection'
    'https://msdn.microsoft.com/library/mt490125\(v=azure.200\).aspx' = '/powershell/module/azurerm.scheduler/get-azurermschedulerjob'
    'https://msdn.microsoft.com/library/mt490132\(v=azure.200\).aspx' = '/powershell/module/azurerm.scheduler/get-azurermschedulerjobcollection'
    'https://msdn.microsoft.com/library/mt490126\(v=azure.200\).aspx' = '/powershell/module/azurerm.scheduler/get-azurermschedulerjobhistory'
    'https://msdn.microsoft.com/library/mt490136\(v=azure.200\).aspx' = '/powershell/module/azurerm.scheduler/new-azurermschedulerhttpjob'
    'https://msdn.microsoft.com/library/mt490141\(v=azure.200\).aspx' = '/powershell/module/azurerm.scheduler/new-azurermschedulerjobcollection'
    'https://msdn.microsoft.com/library/mt490134\(v=azure.200\).aspx' = '/powershell/module/azurerm.scheduler/new-azurermschedulerservicebusqueuejob'
    'https://msdn.microsoft.com/library/mt490142\(v=azure.200\).aspx' = '/powershell/module/azurerm.scheduler/new-azurermschedulerservicebustopicjob'
    'https://msdn.microsoft.com/library/mt490127\(v=azure.200\).aspx' = '/powershell/module/azurerm.scheduler/new-azurermschedulerstoragequeuejob'
    'https://msdn.microsoft.com/library/mt490140\(v=azure.200\).aspx' = '/powershell/module/azurerm.scheduler/remove-azurermschedulerjob'
    'https://msdn.microsoft.com/library/mt490131\(v=azure.200\).aspx' = '/powershell/module/azurerm.scheduler/remove-azurermschedulerjobcollection'
    'https://msdn.microsoft.com/library/mt490130\(v=azure.200\).aspx' = '/powershell/module/azurerm.scheduler/set-azurermschedulerhttpjob'
    'https://msdn.microsoft.com/library/mt490129\(v=azure.200\).aspx' = '/powershell/module/azurerm.scheduler/set-azurermschedulerjobcollection'
    'https://msdn.microsoft.com/library/mt490143\(v=azure.200\).aspx' = '/powershell/module/azurerm.scheduler/set-azurermschedulerservicebusqueuejob'
    'https://msdn.microsoft.com/library/mt490137\(v=azure.200\).aspx' = '/powershell/module/azurerm.scheduler/set-azurermschedulerservicebustopicjob'
    'https://msdn.microsoft.com/library/mt490128\(v=azure.200\).aspx' = '/powershell/module/azurerm.scheduler/set-azurermschedulerstoragequeuejob'
  }
  '.\security\azure-security-disk-encryption.md' = @{
    'https://msdn.microsoft.com/library/azure/dn903607.aspx' = '/powershell/module/azure/set-azurekeyvaultaccesspolicy?view=azuresmps-3.7.0'
    'https://msdn.microsoft.com/library/dn868052.aspx' = '/powershell/module/azurerm.keyvault/#key_vault'
    'https://msdn.microsoft.com/library/dn868048.aspx' = '/powershell/module/azurerm.keyvault/add-azurermkeyvaultkey'
    'https://msdn.microsoft.com/library/azure/mt603746.aspx' = '/powershell/module/azurerm.compute/set-azurermvmosdisk'
    'https://msdn.microsoft.com/library/azure/mt622700.aspx' = '/powershell/azure/overview'
    'https://msdn.microsoft.com/library/azure/mt715776.aspx' = '/powershell/module/azurerm.compute/disable-azurermvmdiskencryption'
    'https://msdn.microsoft.com/library/dn868050.aspx' = '/powershell/module/azurerm.keyvault/set-azurekeyvaultsecret'
  }
  '.\service-fabric\service-fabric-cluster-capacity.md' = @{
    'https://msdn.microsoft.com/library/mt126012.aspx' = '/powershell/module/servicefabric/get-servicefabricclusterupgrade?view=azureservicefabricps'
  }
  '.\site-recovery\site-recovery-deploy-with-powershell.md' = @{
    'https://msdn.microsoft.com/library/dn850420.aspx' = '/powershell/azure/overview'
    'https://msdn.microsoft.com/library/azure/jj554332.aspx' = '/powershell/azure/get-started-azureps'
  }
  '.\site-recovery\site-recovery-vmm-to-azure-powershell-resource-manager.md' = @{
    'https://msdn.microsoft.com/library/dn850420.aspx' = '/powershell/azure/overview'
    'https://msdn.microsoft.com/library/azure/jj554332.aspx' = '/powershell/azure/get-started-azureps'
    'https://msdn.microsoft.com/library/azure/mt637930.aspx' = '/powershell/module/azurerm.recoveryservices.backup/#recovery'
  }
  '.\site-recovery\site-recovery-vmm-to-vmm-powershell-resource-manager.md' = @{
    'https://msdn.microsoft.com/library/dn850420.aspx' = '/powershell/azure/overview'
    'https://msdn.microsoft.com/library/azure/jj554332.aspx' = '/powershell/azure/get-started-azureps'
    'https://msdn.microsoft.com/library/azure/mt637930.aspx' = '/powershell/module/azurerm.recoveryservices.backup/#recovery'
  }
  '.\sql-database\sql-database-aad-authentication-configure.md' = @{
    'https://msdn.microsoft.com/library/azure/jj151815.aspx' = '/powershell/azure/overview?view=azureadps-2.0'
    'https://msdn.microsoft.com/library/azure/mt603544.aspx' = '/powershell/module/azurerm.sql/set-azurermsqlserveractivedirectoryadministrator'
    'https://msdn.microsoft.com/library/azure/mt619340.aspx' = '/powershell/module/azurerm.sql/remove-azurermsqlserveractivedirectoryadministrator'
    'https://msdn.microsoft.com/library/azure/mt603737.aspx' = '/powershell/module/azurerm.sql/get-azurermsqlserveractivedirectoryadministrator'
  }
  '.\sql-database\sql-database-elastic-jobs-powershell.md' = @{
    'https://msdn.microsoft.com/library/mt346063.aspx' = '/powershell/module/elasticdatabasejobs/new-azuresqljobcredential?view=azureelasticdbjobsps-0.8.33'
    'https://msdn.microsoft.com/library/mt346062.aspx' = '/powershell/module/elasticdatabasejobs/set-azuresqljobcredential?view=azureelasticdbjobsps-0.8.33'
    'https://msdn.microsoft.com/library/mt346085.aspx' = '/powershell/module/elasticdatabasejobs/new-azuresqljobcontent?view=azureelasticdbjobsps-0.8.33'
    'https://msdn.microsoft.com/library/mt346058.aspx' = '/powershell/module/elasticdatabasejobs/new-azuresqljobexecution?view=azureelasticdbjobsps-0.8.33'
    'https://msdn.microsoft.com/library/mt346053.aspx' = '/powershell/module/elasticdatabasejobs/stop-azuresqljobexecution?view=azureelasticdbjobsps-0.8.33'
    'https://msdn.microsoft.com/library/mt346083.aspx' = '/powershell/module/elasticdatabasejobs/remove-azuresqljob?view=azureelasticdbjobsps-0.8.33'
    'https://msdn.microsoft.com/library/mt346077.aspx' = '/powershell/module/elasticdatabasejobs/new-azuresqljobtarget?view=azureelasticdbjobsps-0.8.33'
    'https://msdn.microsoft.comlibrary/mt346064.aspx' = '/powershell/module/elasticdatabasejobs/add-azuresqljobchildtarget?view=azureelasticdbjobsps-0.8.33'
    'https://msdn.microsoft.com/library/mt346078.aspx' = '/powershell/module/elasticdatabasejobs/new-azuresqljob?view=azureelasticdbjobsps-0.8.33'
    'https://msdn.microsoft.com/library/mt346055.aspx' = '/powershell/module/elasticdatabasejobs/start-azuresqljobexecution?view=azureelasticdbjobsps-0.8.33'
    'https://msdn.microsoft.com/library/mt346068.aspx' = '/powershell/module/elasticdatabasejobs/new-azuresqljobschedule?view=azureelasticdbjobsps-0.8.33'
    'https://msdn.microsoft.com/library/mt346069.aspx' = '/powershell/module/elasticdatabasejobs/new-azuresqljobtrigger?view=azureelasticdbjobsps-0.8.33'
    'https://msdn.microsoft.com/library/mt346070.aspx' = '/powershell/module/elasticdatabasejobs/remove-azuresqljobtrigger?view=azureelasticdbjobsps-0.8.33'
    'https://msdn.microsoft.com/library/mt346067.aspx' = '/powershell/module/elasticdatabasejobs/get-azuresqljobtrigger?view=azureelasticdbjobsps-0.8.33'
    'https://msdn.microsoft.com/library/mt346074.aspx' = '/powershell/module/elasticdatabasejobs/set-azuresqljobcontentdefinition?view=azureelasticdbjobsps-0.8.33'
  }
  '.\storage\storage-e2e-troubleshooting-classic-portal.md' = @{
    'http://msdn.microsoft.com/library/azure/dn722528.aspx' = '/powershell/module/azure/add-azureaccount?view=azuresmps-3.7.0'
  }
  '.\storage\storage-e2e-troubleshooting.md' = @{
    'http://msdn.microsoft.com/library/azure/dn722528.aspx' = '/powershell/module/azure/add-azureaccount?view=azuresmps-3.7.0'
  }
  '.\storage\storage-introduction.md' = @{
    'https://msdn.microsoft.com/library/azure/mt269418.aspx' = '/powershell/module/azurerm.storage/#storage'
  }
  '.\storage\storage-powershell-guide-full.md' = @{
    'https://msdn.microsoft.com/library/azure/mt269418.aspx' = '/powershell/module/azurerm.storage/#storage'
    'http://msdn.microsoft.com/library/azure/dn806380.aspx' = '/powershell/module/azure.storage/new-azurestoragecontext'
    'http://msdn.microsoft.com/library/azure/dn495235.aspx' = '/powershell/module/azure.storage/get-azurestoragekey'
    'http://msdn.microsoft.com/library/azure/dn806416.aspx' = '/powershell/module/azure.storage/new-azurestoragecontainersastoken'
    'http://msdn.microsoft.com/library/azure/dn806379.aspx' = '/powershell/module/azure.storage/set-azurestorageblobcontent'
    'http://msdn.microsoft.com/library/azure/dn806392.aspx' = '/powershell/module/azure.storage/get-azurestorageblob'
    'http://msdn.microsoft.com/library/azure/dn806418.aspx' = '/powershell/module/azure.storage/get-azurestorageblobcontent'
    'http://msdn.microsoft.com/library/azure/dn806394.aspx' = '/powershell/module/azure.storage/start-azurestorageblobcopy'
    'http://msdn.microsoft.com/library/azure/dn806406.aspx' = '/powershell/module/azure.storage/start-azurestorageblobcopystate'
    'http://msdn.microsoft.com/library/azure/dn806399.aspx' = '/powershell/module/azure.storage/remove-azurestorageblob'
    'http://msdn.microsoft.com/library/azure/dn806417.aspx' = '/powershell/module/azure.storage/new-azurestoragetable'
    'http://msdn.microsoft.com/library/azure/dn806393.aspx' = '/powershell/module/azure.storage/remove-azurestoragetable'
    'http://msdn.microsoft.com/library/azure/dn806411.aspx' = '/powershell/module/azure.storage/get-azurestoragetable'
    'http://msdn.microsoft.com/library/azure/dn806382.aspx' = '/powershell/module/azure.storage/new-azurestoragequeue'
    'http://msdn.microsoft.com/library/azure/dn806377.aspx' = '/powershell/module/azure.storage/get-azurestoragequeue'
    'http://msdn.microsoft.com/library/azure/dn806400.aspx' = '/powershell/module/azure.storage/new-azurestoragetablesastoken'
    'https://msdn.microsoft.com/library/azure/dn790368.aspx' = '/powershell/module/azure/get-azureenvironment?view=azuresmps-3.7.0'
    'http://msdn.microsoft.com/library/azure/dn806401.aspx' = '/powershell/module/azurerm.storage/#storage'
  }
  '.\storsimple\storsimple-overview.md' = @{
    'https://msdn.microsoft.com/library/dn920427.aspx' = '/powershell/module/azure/?view=azuresmps-3.7.0#azure'
  }
  '.\virtual-machine-scale-sets\virtual-machine-scale-sets-windows-autoscale.md' = @{
    'https://msdn.microsoft.com/library/azure/jj554332.aspx' = '/powershell/azure/get-started-azureps'
  }
  '.\virtual-machines\linux\classic\freebsd-create-upload-vhd.md' = @{
    'https://msdn.microsoft.com/library/azure/jj554332.aspx' = '/powershell/azure/get-started-azureps'
  }
  '.\virtual-machines\virtual-machines-windows-index.md' = @{
    'https://msdn.microsoft.com/library/azure/dn708504.aspx' = '/powershell/azure/overview?view=azuresmps-3.7.0'
  }
  '.\virtual-machines\windows\aws-to-azure.md' = @{
    'https://msdn.microsoft.com/library/mt607148.aspx' = '/powershell/module/azurerm.storage/new-azurermstorageaccount'
    'https://msdn.microsoft.com/library/mt603554.aspx' = '/powershell/module/azurerm.compute/add-azurermvhd'
  }
  '.\virtual-machines\windows\classic\create-powershell.md' = @{
    'https://msdn.microsoft.com/library/azure/dn495299.aspx' = '/powershell/module/azure/add-azureprovisioningconfig'
  }
  '.\virtual-machines\windows\classic\createupload-vhd.md' = @{
    'http://msdn.microsoft.com/library/dn495173.aspx' = 'https://docs.microsoft.com/en-us/powershell/module/azure/add-azurevhd'
    'https://msdn.microsoft.com/library/mt589167.aspx' = 'https://docs.microsoft.com/en-us/powershell/module/azure/add-azurevmimage'
  }
  '.\virtual-machines\windows\ps-extensions-diagnostics.md' = @{
    'https://msdn.microsoft.com/library/mt603499.aspx' = '/powershell/module/azurerm.compute/set-azurermvmdiagnosticsextension'
    'https://msdn.microsoft.com/library/mt603678.aspx' = '/powershell/module/azurerm.compute/get-azurermvmdiagnosticsextension'
    'https://msdn.microsoft.com/library/mt603782.aspx' = '/powershell/module/azurerm.compute/remove-azurermvmdiagnosticsextension'
    'https://msdn.microsoft.com/library/mt589189.aspx' = '/powershell/module/azure/set-azurevmdiagnosticsextension'
    'https://msdn.microsoft.com/library/mt589152.aspx' = '/powershell/module/azure/get-azurevm'
    'https://msdn.microsoft.com/library/mt589121.aspx' = '/powershell/module/azure/update-azurevm'
  }
  '.\virtual-machines\windows\reset-rdp.md' = @{
    'https://msdn.microsoft.com/library/mt619447.aspx' = '/powershell/module/azurerm.compute/set-azurermvmaccessextension'
  }
  '.\virtual-machines\windows\sql\virtual-machines-windows-ps-sql-create.md' = @{
    'https://msdn.microsoft.com/library/azure/dn495252.aspx' = '/powershell/module/azure/add-azuredisk'
    'https://msdn.microsoft.com/library/mt603620.aspx' = '/powershell/module/azurerm.network/new-azurermpublicipaddress'
    'https://msdn.microsoft.com/library/mt603657.aspx' = '/powershell/module/azurerm.network/new-azurermvirtualnetwork'
    'https://msdn.microsoft.com/library/mt603727.aspx' = '/powershell/module/azurerm.compute/new-azurermvmconfig'
    'https://msdn.microsoft.com/library/mt603746.aspx' = '/powershell/module/azurerm.compute/set-azurermvmosdisk'
    'https://msdn.microsoft.com/library/mt603754.aspx' = '/powershell/module/azurerm.compute/new-azurermvm'
    'https://msdn.microsoft.com/library/mt603843.aspx' = '/powershell/module/azurerm.compute/set-azurermvmoperatingsystem'
    'https://msdn.microsoft.com/library/mt607148.aspx' = '/powershell/module/azurerm.storage/new-azurermstorageaccount'
    'https://msdn.microsoft.com/library/mt619344.aspx' = '/powershell/module/azurerm.compute/set-azurermvmsourceimage'
    'https://msdn.microsoft.com/library/mt619351.aspx' = '/powershell/module/azurerm.compute/add-azurermvmnetworkinterface'
    'https://msdn.microsoft.com/library/mt619370.aspx' = '/powershell/module/azurerm.network/new-azurermnetworkinterface'
    'https://msdn.microsoft.com/library/mt619412.aspx' = '/powershell/module/azurerm.network/new-azurermvirtualnetworksubnetconfig'
    'https://msdn.microsoft.com/library/mt759837.aspx' = '/powershell/module/azurerm.resources/new-azurermresourcegroup'
  }
  '.\virtual-machines\windows\troubleshoot-rdp-connection.md' = @{
    'https://msdn.microsoft.com/library/mt619447.aspx' = '/powershell/module/azurerm.compute/set-azurermvmaccessextension'
  }
  '.\virtual-machines\windows\upload-generalized-managed.md' = @{
    'https://msdn.microsoft.com/library/mt607148.aspx' = '/powershell/module/azurerm.storage/new-azurermstorageaccount'
  }
  '.\virtual-machines\windows\upload-image.md' = @{
    'https://msdn.microsoft.com/library/mt607148.aspx' = '/powershell/module/azurerm.storage/new-azurermstorageaccount'
    'https://msdn.microsoft.com/library/mt603554.aspx' = '/powershell/module/azurerm.compute/add-azurermvhd'
  }
  '.\virtual-machines\windows\upload-specialized.md' = @{
    'https://msdn.microsoft.com/library/mt607148.aspx' = '/powershell/module/azurerm.storage/new-azurermstorageaccount'
    'https://msdn.microsoft.com/library/mt603554.aspx' = '/powershell/module/azurerm.compute/add-azurermvhd'
  }
  '.\virtual-machines\windows\vhd-copy.md' = @{
    'https://msdn.microsoft.com/library/mt607148.aspx' = '/powershell/module/azurerm.storage/new-azurermstorageaccount'
  }
}

function normalizeTarget {
  param([string]$linkpath)
  [string]$outtarget = ($linkpath.tolower()).trim() -replace 'https://docs.microsoft.com', ''
  $outtarget = $outtarget -replace '/en-us',''
  if ($outtarget.EndsWith('/')) {
    $outtarget = $outtarget.Substring(0,$outtarget.Length-1)
  }
  Write-Output $outtarget
}

function getNewTarget {
  param([string]$intarget)

  $outtarget = $targetmap.$intarget
  if ($outtarget -eq $null) {
    switch -Regex ($intarget) {
      '/powershell/azuread/v2/.*' {
        $cmdlet = ($intarget -split '/')[-1]
        $outtarget = '/powershell/module/azuread/{0}?view=azureadps-2.0' -f $cmdlet
      }
      '/powershell/module/servicefabric/.*' {
        $cmdlet = ($intarget -split '/')[-1]
        $outtarget = '/powershell/module/servicefabric/{0}?view=azureservicefabricps' -f $cmdlet
      }
      '/powershell/msonline/v1/.*' {
        $cmdlet = ($intarget -split '/')[-1]
        $outtarget = '/powershell/module/msonline/{0}?view=azureadps-1.0' -f $cmdlet
      }
      '/powershell/resourcemanager/.*' {
        $cmdlet = ($intarget -split '/')[-1]
        $module = ($intarget -split '/')[3]
        if ($cmdlet -eq $module) {
          $outtarget = '/powershell/module/{0}' -f $module
        } else {
          $outtarget = '/powershell/module/{0}/{1}' -f $module,$cmdlet
        }
      }
      '/powershell/servicefabric/vlatest/.*' {
        $cmdlet = ($intarget -split '/')[-1]
        $outtarget = '/powershell/module/servicefabric/{0}?view=azureservicefabricps' -f $cmdlet
      }
      '/powershell/servicemanagement/.*' {
        $cmdlet = ($intarget -split '/')[-1]
        $module = ($intarget -split '/')[3]
        if ($cmdlet -eq $module) {
          $outtarget = '/powershell/module/azure/?view=azuresmps-3.7.0'
        } else {
          $outtarget = '/powershell/module/azure/{0}?view=azuresmps-3.7.0' -f $cmdlet
        }
      }
      '/powershell/module/azurerm.*' {
        $outtarget = $intarget
      }
      '/powershell/storage/azure.storage/.*' {
        $cmdlet = ($intarget -split '/')[-1]
        $outtarget = '/powershell/module/azure.storage/{0}' -f $cmdlet
      }
    } ## switch
  } ## if null
  Write-Output $outtarget
} ## function

Write-Host 'Searching repo...'
$files = findstr /ms /c:"/powershell/" "$reporoot\*.md"

Write-Host 'Processing found files...'
foreach ($file in $files) {
  $links = select-string -path $file -Pattern $linkpattern
  Write-Debug -Message "File = $file"
  $mdtext = $null
  foreach ($link in $links) {
    $url = $link.Matches[0].groups['file'].value
    #if ($url.contains('msdn.microsoft.com')) { Write-Debug "   $url" }
    if ($url.contains('/powershell/') -and
      (-not $url.contains('amazon.com')) -and
      (-not $link.Matches[0].value.contains('msdn.microsoft.com'))
    ) {
      $mdlink = $link.Matches[0].groups
      if ($mdlink['link'].value.Contains('/powershell/')) {
        $target = normalizeTarget $mdlink['file'].value
        #Write-Debug "   $target"
        if ($target.StartsWith('/powershell')) {
          $newtarget = getNewTarget $target
          #Write-Debug -Message "      $target ==> $newtarget"
          $linkobj = new-object -TypeName psobject -Property ([ordered]@{
              file = $link.path
              link = $mdlink['link'].value
              newlink = '[' + $mdlink['label'].value + '](' + $newtarget + ')'
          })
          if ($mdtext -eq $null) { $mdtext = Get-Content $linkobj.file -Encoding UTF8 }
          $mdtext = $mdtext -replace  [Regex]::Escape($linkobj.link), $linkobj.newlink
        } ## if target starts with /powershell
      } ## if link contains /powershell
    } ## if /powershell
  } ## foreach link
  if ($mdtext -ne $null) {
    Write-Debug "Write = $file"
    $null = Set-Content -Value $mdtext -Path $file -Encoding UTF8 -Force
  }
} ## foreach file

Push-Location $reporoot

Write-Host 'Processing MSDN links...'
foreach ($file in $msdnmappings.Keys)
{
  $mdtext = Get-Content $file -Encoding UTF8
  foreach ($linklist in $msdnmappings[$file])
  {
    foreach ($item in $linklist.keys)
    {
      $mdtext = $mdtext -replace [Regex]::Escape($item),$linklist[$item]
    }
  }
  Write-Debug -Message "MSDN link = $file"
  Set-Content -Value $mdtext -Path $file -Encoding UTF8 -Force
}
Pop-Location
$endtime = Get-Date
Write-Host "Finished -  $endtime"
Write-Host ('Total time -  {0:N2}' -f ($endtime - $starttime).TotalSeconds)
