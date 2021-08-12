param (
    [String]  $root = "$(Get-Location)",
    $localPath = "C:\tmp\",
    $remotePath = "/tmp/John",
    $LogFile_Session = "$root\SessionLogX.log"
)

$logfile = "process.log" 


function logger {
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline =$true)]
        [String[]]$messages,
        [string]$logPath,
        [string]$logFileName,
        [string]$errortype = "Infor",
        [switch]$timestamp = $true,
        [switch]$WriteHost = $false

    )
    
    #Date and Time Format
    process{
        $currDateTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        try {
        #region -- Validation
        if([string]::IsNullOrEmpty($logPath)) { $logPath = "$(Get-Location)" }
        if([string]::IsNullOrEmpty($logFileName)) { $logFileName = "system" }
        $logfile = "{0}\{1}" -f $logPath, $logFileName
        #endregion
      
        
              foreach ($message in $messages){
              if ($timestamp) {
                "[{0,19}]  <{1:10}> - {2}" -f $currDateTime,$errortype,$message | Out-File -Append $logfile -NoClobber
                if ($WriteHost) {
                   $display = "[{0,19}]  <{1:10}> - {2}" -f $currDateTime,$errortype,$message 
                   write-host $display
                }
               }else
               {
                "{0,21}  <{1:10}> - {2}" -f "",$errortype,$message | Out-File -Append $logfile -NoClobber
                if ($WriteHost) {
                   $display = "{0,21}  <{1:10}> - {2}" -f "",$errortype,$message
                   write-host $display
                }
               }
             }
         } 
            
            #endregion
       catch {
        #region -- Implementation --
        "[$($currDateTime)] - Caught an exception:" | Out-File -Append $logfile -NoClobber
        "[$($currDateTime)] - Exception Type: $($_.Exception.GetType().FullName)" | Out-File -Append $logfile -NoClobber
        "[$($currDateTime)] - Exception Message: $($_.Exception.Message)" | Out-File -Append $logfile -NoClobber
        #endregion
    
            }
       }
  }
try
{

    # Load WinSCP .NET assembly
    Add-Type -Path "WinSCPnet.dll"

    $Profile = @{
            Protocol = [WinSCP.Protocol]::Sftp
            HostName = "192.168.142.138"
            UserName = "admin"
            Password = "password"
            SshHostKeyFingerprint = "ssh-ed25519 256 fhHfYU6zhx+10XpF2oCEbLMtpOD4mJqHBz5h6cEAI6M="
        }


    
    # Setup session options
    # Set up session options
    $sessionOptions = New-Object WinSCP.SessionOptions -Property $Profile 
 
 
    $session = New-Object WinSCP.Session
    $session.SessionLogPath = $LogFile_Session
    
    try
    {
        # Connect
        "Connecting to {1}" -f (Get-Date), $Profile.HostName | logger -logFileName $logfile -WriteHost:$true
        $session.Open($sessionOptions)

       
       #Transfer options
        $transferOptions = New-Object WinSCP.TransferOptions
        $transferOptions.ResumeSupport.State = [WinSCP.TransferResumeSupportState]::On
        $file_mask = "*.exe; *.txt"
        $transferOptions.FileMask = $file_mask

        # Synchronize files to local directory, collect results
        "Downloading to Local --> '{1}' ..." -f (Get-Date), $localPath | logger -logFileName $logfile -WriteHost:$true
        "synchronizing files from --> Remote '{1}' to Local --> '{2}'" -f (Get-Date), $remotePath , $localPath | logger -logFileName $logfile -WriteHost:$true
        $synchronizationResult = $session.SynchronizeDirectories(
            [WinSCP.SynchronizationMode]::Local, $localPath, $remotePath, $false,  $false, [WinSCP.SynchronizationCriteria]::time, $transferOptions)
      
        # Deliberately not calling $synchronizationResult.Check
        # as that would abort our script on any error.
        # We will find any error in the loop below
        # (note that $synchronizationResult.Uploads is the only operation
        # collection of SynchronizationResult that can contain any items,
        # as we are not removing nor uploading anything)
      
        # Iterate over every downloads
        
        foreach ($Upload in $synchronizationResult.Downloads)
        {
            # Success or error?
             $currDateTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            if ($Upload.Error -eq $Null)
            {
               "Download of {1} succeeded" -f (Get-Date), $Upload.FileName  | logger -logFileName $logfile -WriteHost:$true
            }
            else
            {
           
               "Download of {1} failed: {2}" -f (Get-Date), $Upload.FileName, $Upload.Error.Message  | logger -logFileName $logfile -WriteHost:$true -errortype "Error"
            }
        }
    }
    finally
    {
        # Disconnect, clean up
        $session.Dispose()
        "Session Disconnected" -f (Get-Date) | logger -logFileName $logfile -WriteHost:$true
    }
   
    # exit 0
}
catch
{
    "Error: $($_.Exception.Message)" | logger -logFileName $logfile -WriteHost:$true
   # exit 1
}
