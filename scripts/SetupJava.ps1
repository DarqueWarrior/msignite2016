###############################################################################
# Download JDK and Microsoft SQL Server JDBC driver into $downloadFolder.
# Run script in elevated PowerShell to install JDK, JRE, JDBC, Maven, Tomcat
# and Eclipse to $baseFolder

cls

$skipEnvVars = $false
$baseFolder = "c:\java"
$downloadFolder = "c:\temp"

$mavenUri = "http://ftp.wayne.edu/apache/maven/maven-3/3.3.9/binaries/apache-maven-3.3.9-bin.zip"
$tomcatUri = "http://mirror.reverse.net/pub/apache/tomcat/tomcat-8/v8.0.30/bin/apache-tomcat-8.0.30-windows-x64.zip"
$eclipseUri = "http://mirror.cc.columbia.edu/pub/software/eclipse/technology/epp/downloads/release/mars/1/eclipse-jee-mars-1-win32-x86_64.zip"

###############################################################################
# Load System.IO.Compression.Filesystem so we can unzip the files we are going
# to download. 
[Reflection.Assembly]::LoadWithPartialName("System.IO.Compression.FileSystem") | Out-Null

Function UnZip ($zipFile)
{
    # Unzips file into the $baseFolder folder
    # Used to extract files
    [IO.Compression.ZipFile]::ExtractToDirectory($zipFile, $baseFolder)
}

Function DownloadAndExtract($name, $uri, $filter)
{
    if((Test-Path -Path "$downloadFolder\$name.zip") -eq $false)
    {
        Download -url $uri -localFile "$downloadFolder\$name.zip" -activity "Downloading $name"
    }
    else
    {
        Write-Host "$name zip found. Skipping download."
    }

    $destination = "$baseFolder\$name"

    if((Test-Path -Path "$baseFolder\$name") -eq $false)
    {
        Write-Host "Extracting $name to $destination"
        Unzip "$downloadFolder\$name.zip"
    
        $source = (Get-ChildItem -Path $baseFolder -Filter $filter).FullName

        if($source -ne $destination)
        {
            Rename-Item $source $destination
        }
    }
    else
    {
        Write-Host "$name folder found. Skipping install."
    }
}

Function Download($url, $localFile, $activity = 'Downloading file')
{
    if($skipDownload -eq $true)
    {
        return
    }

    $client = New-Object System.Net.WebClient
    $Global:downloadComplete = $false

    $eventDataComplete = Register-ObjectEvent $client DownloadFileCompleted `
        -SourceIdentifier WebClient.DownloadFileComplete `
        -Action {$Global:downloadComplete = $true}
    $eventDataProgress = Register-ObjectEvent $client DownloadProgressChanged `
        -SourceIdentifier WebClient.DownloadProgressChanged `
        -Action { $Global:DPCEventArgs = $EventArgs }

    try 
    {
        Write-Progress -Activity $activity -Status $url
        $client.DownloadFileAsync($url, $localFile)
        
        while (!($Global:downloadComplete))
        {                
            $pc = $Global:DPCEventArgs.ProgressPercentage
            if ($pc -ne $null) 
            {
                Write-Progress -Activity $activity -Status $url -PercentComplete $pc
            }
        }
    
        Write-Progress -Activity $activity -Status $url -Complete
    } 
    finally 
    {
       Unregister-Event -SourceIdentifier WebClient.DownloadProgressChanged
       Unregister-Event -SourceIdentifier WebClient.DownloadFileComplete
       $client.Dispose()
       $Global:downloadComplete = $null
       $Global:DPCEventArgs = $null
       Remove-Variable client
       Remove-Variable eventDataComplete
       Remove-Variable eventDataProgress
       [GC]::Collect()    
    }
}

###############################################################################
# Create the target for all the installs
New-Item $baseFolder -type directory -Force | Out-Null
New-Item $downloadFolder -type directory -Force | Out-Null

Write-Host "Creating Workspace folder $baseFolder\workspace"
New-Item "$baseFolder\workspace" -type directory -Force | Out-Null

try 
{
    ###########################################################
    # Download and Install JDK and JRE to
    # $baseFolder\jdk
    # $baseFolder\jre

    if((Test-Path -Path "$downloadFolder\jdk*.exe"))
    {
        if((Test-Path -Path "$baseFolder\jdk") -eq $false -and
           (Test-Path -Path "$baseFolder\jre") -eq $false)
        {
            Write-Host "Installing JDK to $baseFolder\jdk"
            Write-Host "Installing JRE to $baseFolder\jre"
            $source = (Get-ChildItem -Path $downloadFolder -Filter 'jdk*.exe').FullName

            $arguments = "/s INSTALLDIR=$baseFolder\jdk /INSTALLDIRPUBJRE=$baseFolder\jre"
            Start-Process -FilePath "$source" -ArgumentList $arguments -Wait -PassThru | Out-Null
        }
        else
        {
            Write-Host "JDK and/or JRE folder found. Skipping install."
        }
    }
    else
    {
        Write-Host "JDK not found. Skipping Install. To install download JDK to $downloadFolder"
        Write-Host "from http://www.oracle.com/technetwork/java/javase/downloads/index.html and run script again."
    }
    
    ###########################################################
    # Extract Maven to
    # $baseFolder\maven
    
    DownloadAndExtract -name "maven" -uri $mavenUri -filter "apache-maven*"

    ###########################################################
    # Extract Tomcat Development to
    # $baseFolder\tomcat

    DownloadAndExtract -name "tomcat" -uri $tomcatUri -filter "apache-tomcat*"
    
    ###########################################################
    # Extract Eclipse

    DownloadAndExtract -name "eclipse" -uri $eclipseUri -filter "eclipse*"
    
    ###########################################################
    # Extract SQL JDBC
    if((Test-Path -Path "$downloadFolder\sqljdbc*.exe"))
    {
        if((Test-Path -Path "$baseFolder\jdbc") -eq $false)
        {
            Write-Host "Installing SQL JDBC driver to $baseFolder\jdbc"
            $source = (Get-ChildItem -Path $downloadFolder -Filter 'sqljdbc*.exe').Name

            $arguments = "/c $source /auto ""$baseFolder\jdbc\"""
            Start-Process -WorkingDirectory $downloadFolder -FilePath "cmd" -ArgumentList $arguments -Wait -PassThru | Out-Null
        }
        else
        {
            Write-Host "JDBC folder found. Skipping install."
        }
    }
    else
    {
        Write-Host "SQL JDBC not found. Skipping Install. To install download SQL JDBC driver to $downloadFolder"
        Write-Host "from https://msdn.microsoft.com/en-us/sqlserver/aa937724.aspx and run script again."
    }
    
    ###########################################################
    # Set the enviroment variables
    if($skipEnvVars -eq $false)
    {
        Write-Host "Setting the eviroment variables"
        
        Write-Host "Setting JAVA_HOME to ""$baseFolder\jdk"""
        [System.Environment]::SetEnvironmentVariable("JAVA_HOME", "$baseFolder\jdk", "Machine")
        
        Write-Host "Setting M2_HOME to ""$baseFolder\maven"""
        [System.Environment]::SetEnvironmentVariable("M2_HOME", "$baseFolder\maven", "Machine")

        Write-Host "Setting MAVEN_HOME to ""$baseFolder\maven"""
        [System.Environment]::SetEnvironmentVariable("MAVEN_HOME", "$baseFolder\maven", "Machine")

        Write-Host "Setting M2 to ""%M2_HOME%\bin"""
        [System.Environment]::SetEnvironmentVariable("M2", "%M2_HOME%\bin", "Machine")

        if($env:Path.Contains("JAVA_HOME") -eq $false)
        {
            Write-Host "Adding JAVA_HOME to path"
            [System.Environment]::SetEnvironmentVariable("PATH", "$baseFolder\jdk\bin;$baseFolder\maven\bin;" + $Env:Path, "Machine")
        }
        else
        {
            Write-Host "JAVA_HOME found in path. Skipping."
        }       
    }

    ###########################################################
    Write-Host "Opening Eclipse folder"
    start C:\java\eclipse
} 
finally 
{
}