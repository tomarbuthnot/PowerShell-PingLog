Function Powershell-PingLog {
<#
.SYNOPSIS  
		Pings a list of hostnames or IP's and writes to a CSV Log file

.DESCRIPTION  
		Pings a list of hostnames or IP's and writes to a CSV Log file

.LINK  
    http://link.com
                
.NOTES  
    Version:		0.8
  
    Author/Copyright:	Copyright Tom Arbuthnot - All Rights Reserved
    
    Email/Blog/Twitter:	tom@tomarbuthnot.com tomarbuthnot.com @tomarbuthnot
    
    Disclaimer:   	THIS CODE IS MADE AVAILABLE AS IS, WITHOUT WARRANTY OF ANY KIND. THE ENTIRE RISK
                        OF THE USE OR THE RESULTS FROM THE USE OF THIS CODE REMAINS WITH THE USER.
                        While these scripts are tested and working in my environment, it is recommended 
                        that you test these scripts in a test environment before using in your production 
                        environment. Tom Arbuthnot further disclaims all implied warranties including, 
			without limitation, any implied warranties of merchantability or of fitness for 
			a particular purpose. The entire risk arising out of the use or performance of 
			this script and documentation remains with you. In no event shall Tom Arbuthnot, 
			its authors, or anyone else involved in the creation, production, or delivery of 
			this script/tool be liable for any damages whatsoever (including, without limitation, 
                        damages for loss of business profits, business interruption, loss of business 
			information, or other pecuniary loss) arising out of the use of or inability to use 
			the sample scripts or documentation, even if Tom Arbuthnot has been advised of 
			the possibility of such damages.
    
     
    Acknowledgements: 	
    
    Assumptions:	 ExecutionPolicy of AllSigned (recommended), RemoteSigned or Unrestricted (not recommended)
    
    Limitations:		  										
    		
    Ideas/Wish list:	
    
    Rights Required:	

    Known issues:	


.EXAMPLE
		Powershell-PingLog -Hostnames 'TALAB01','TALAB02' -DiskToLogTo c:
 
#>
  
  
  #############################################################
  # Param Block
  #############################################################
  
  # Sets that -Whatif and -Confirm should be allowed
  [cmdletbinding(SupportsShouldProcess=$true)]
  
  Param 	(
    [Parameter(Mandatory=$True,
    HelpMessage='List of hostnames to ping, can be an IP or hostname')]
    $HostNames,
    
    
    [Parameter(Mandatory=$false,
    HelpMessage='Disk to Log to in format ''D:''')]
    $DiskToLogTo = 'c:',
    
    [Parameter(Mandatory=$false,
    HelpMessage='Error Log location, default C:\<Command Name>_ErrorLog.txt')]
    [string]$ErrorLog = "c:\$($myinvocation.mycommand)_ErrorLog.txt",
    [switch]$LogErrors
    
  ) #Close Parameters
  
  
  #############################################################
  # Begin Block
  #############################################################
  
  Begin 	{
    Write-Verbose "Starting $($myinvocation.mycommand)"
    Write-Verbose "Error log will be $ErrorLog"
    
    
    # Get Local IP (source IP for Script)
    [string]$SourceIP = (Get-WmiObject -class win32_NetworkAdapterConfiguration -Filter 'ipenabled = "true"').ipaddress[0]
    
    # Get HostName
    $SourceHost = $env:COMPUTERNAME
    

    ##########################################
    # Check for disk space and stop before logs fill drive
    
    # First FreeSpace Test to Start Loop
    #Disk to Watch in format e.g. "D:"
    $Disk = Get-WmiObject -Class Win32_LogicalDisk -Filter 'DriveType = 3' | Where-Object {$_.DeviceID -eq "$DiskToLogTo"}
    $FreeSpace = $disk.FreeSpace / 1GB
    Write-Host "Free Space is $FreeSpace"
    
    ###############################################
    # Create Output Log Directory

    $Path = "$DiskToLogTo\Powershell-PingLog"

    Test-Path $DiskToLogTo\Powershell-PingLog

    if(!(Test-Path -Path $Path))
      {
       New-Item -ItemType directory -Path $Path
      }
    else
      {
       Write-Verbose "Log Path Exists at $Path"
      }


    #######################################################
    
    $Pattern = "^([1-9]|[1-9][0-9]|1[0-9][0-9]|2[0-4][0-9]|25[0-5])(\.([0-9]|[1-9][0-9]|1[0-9][0-9]|2[0-4][0-9]|25[0-5])){3}$"
    
    #################
    # work out IP addresses once, create IPCollection Object
    $IPCollection=  @()
    
    Foreach ($HostName in $HostNames)
    {
      IF ($hostname -eq $env:COMPUTERNAME -or $hostname -eq $env:COMPUTERNAME)
      {
        Write-host 'Preventing from Pinging Self'
        # Do not add this to the object to process
      }
      elseIf ($HostName -match $Pattern)
      {
        Write-Verbose "$HostName is an IP address, doing reverse lookup"
        $DestIP = $HostName
        Write-Verbose "IP is $DestIP"
        $hostname = ([System.Net.Dns]::GetHostbyAddress("$HostName")).hostname    
        
        $output = New-Object -TypeName PSobject 
        $output | add-member NoteProperty 'Hostname' -value $($HostName)
        $output | add-member NoteProperty 'IPAddress' -value $($destIP)
        $IPCollection += $output
        
      }
      elseIf ($HostName -notmatch $Pattern)
      {
        Write-Verbose "Hostname does not match IP Pattern: $HostName"
        # DestIP will often list more than 1 address
        $DestIPs =  [System.Net.Dns]::GetHostAddresses("$hostname")
        
        # Work through returned IP's to find IPv4
        Foreach ($IPdetails in $DestIPs)
            {
            Write-Verbose "$($IPdetails.IPAddressToString)"
            IF ( $($IPdetails.IPAddressToString) -match $Pattern)
                {
                Write-Verbose "IPv4 Address Found $($IPdetails.IPAddressToString)"
                $DestIPv4 = "$($IPdetails.IPAddressToString)"
                }
              
            }
        
        $output = New-Object -TypeName PSobject 
        $output | add-member NoteProperty 'Hostname' -value $($HostName)
        $output | add-member NoteProperty 'IPAddress' -value $($DestIPv4)
        $IPCollection += $output
        Write-Verbose "IP for $HostName is $DestIP"
      }
      
    } # close foreach 
    ##################################################
    
    # Script Level Variable to Stop Execution if there is an issue with any stage of the script
    $script:EverythingOK = $true
    
    #############################################################
    # Function to Deal with Error Output to Log file
    #############################################################
    
    Function ErrorCatch-Action 
    {
      Param 	(
        [Parameter(Mandatory=$false,
        HelpMessage='Switch to Allow Errors to be Caught without setting EverythingOK to False, stopping other aspects of the script running')]
        # By default any errors caught will set $EverythingOK to false causing other parts of the script to be skipped
        [switch]$SetEverythingOKVariabletoTrue
      ) # Close Parameters
      
      # Set EverythingOK to false to avoid running dependant actions
      If ($SetEverythingOKVariabletoTrue) {$script:EverythingOK = $true}
      else {$script:EverythingOK = $false}
      Write-Verbose "EverythingOK set to $script:EverythingOK"
      
      # Write Errors to Screen
      Write-Error $Error[0]
      # If Error Logging is runnning write to Error Log
      
      if ($LogErrors) {
        # Add Date to Error Log File
        Get-Date -format 'dd/MM/yyyy HH:mm' | Out-File $ErrorLog -Append
        $Error | Out-File $ErrorLog -Append
        '## LINE BREAK BETWEEN ERRORS ##' | Out-File $ErrorLog -Append
        Write-Warning "Errors Logged to $ErrorLog"
        # Clear Error Log Variable
        $Error.Clear()
      } #Close If
    } # Close Error-CatchActons Function
    
  } #Close Function Begin Block
  
  #############################################################
  # Process Block
  #############################################################
  
  Process {
    
    # First Code To Run
    If ($script:EverythingOK)
    {
      Try 	
      {
        
        # Run while loop on IPs
        
        # While FreeSpace is Greater than X GB
        while($FreeSpace -gt 10)
        {
          
          $loopstarttime = Get-Date
          
          Foreach ($Instance in $IPCollection)
          {
            
            
            $HostName = $($Instance.hostname)
            $DestIP = $($Instance.IPAddress)
            
            Write-Verbose "Hostname is $HostName"
            Write-Verbose "IP address is $DestIP"
            
            # Check if IP is valid
            If ($DestIP -match $Pattern)
            {

              [string]$LogCSV = "$DiskToLogTo\Powershell-PingLog\Ping-$SourceHost-$($SourceIP)-To-$HostName-$($DestIP).csv"
              
              $Ping = @()
              
              #Test if path exists, if not, create it
              If (-not (Test-Path (Split-Path $LogCSV) -PathType Container))
              {   Write-Verbose "Folder doesn't exist $(Split-Path $LogCSV), creating..."
                New-Item (Split-Path $LogCSV) -ItemType Directory | Out-Null
              }
              
              #Test if log file exists, if not seed it with a header row
              If (-not (Test-Path $LogCSV))
              {   Write-Verbose "Log file doesn't exist: $($LogCSV), creating..."
                Add-Content -Value '"TimeStamp","Source","Destination","Status","ResponseTime"' -Path $LogCSV
              }
              
              #Log collection loop
              Write-Verbose "Beginning Ping monitoring of $DestIP"
              
              # Check each log file isn't bigger than 250Mb
              IF ((Get-ChildItem $LogCSV).Length -lt 250Mb)
              
              {   
                $Ping = Get-WmiObject Win32_PingStatus -Filter "Address = '$DestIP'" | 
                Select @{Label='TimeStamp';Expression={Get-Date}},@{Label='Source';Expression={ $SourceIP }},@{Label='Destination';Expression={ $_.Address }},@{Label='Status';Expression={ If ($_.StatusCode -ne 0) {'Failed'} Else {'Success'}}},ResponseTime
                
                $Result = $Ping | Select TimeStamp,Source,Destination,Status,ResponseTime | ConvertTo-Csv -NoTypeInformation
                
                $Result[1] | Add-Content -Path $LogCSV
                
                Write-verbose ($Ping | Select TimeStamp,Source,Destination,Status,ResponseTime | Format-Table -AutoSize | Out-String)
                
              } # close ping test if log less than 250Mb
              
              
            } # Close test if IP address is valid
            
          } # Close For-Each IP loop
          
          $loopEndtime = Get-Date
          
          
          $RuntimetotalMillisconds = ($loopendtime - $loopstarttime).TotalMilliseconds
          
          Write-Verbose "Start Loop time: $loopstarttime"
          Write-Verbose "End Loop time: $loopEndtime"
          Write-Verbose "Run time in Millisconds $RuntimetotalMillisconds"
          
          If ($RuntimetotalMillisconds -lt 1000)
          {
            Write-Verbose 'Sleeping as loop time is less than a second'
            Start-Sleep -Milliseconds (1000 -$RuntimetotalMillisconds)
          }
          
          
        } # close While
        
        
      } # Close Try Block
      
      Catch 	{ErrorCatch-Action} # Close Catch Block
      
      
    } # Close If EverthingOK Block 1
    
    #############################################################
    # Next Script Action or Try,Catch Block
    #############################################################
    
    # Second Code To Run
    If ($script:EverythingOK)
    {
      Try 	
      {
        
        # Code Goes here
        
        
      } # Close Try Block
      
      Catch 	{ErrorCatch-Action} # Close Catch Block
      
      
    } # Close If EverthingOK Block 2
    
    
  } #Close Function Process Block 
  
  #############################################################
  # End Block
  #############################################################
  
  End 	{
    Write-Verbose "Ending $($myinvocation.mycommand)"
  } #Close Function End Block
  
} #End Function


