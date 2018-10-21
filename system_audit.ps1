 
 
  function systemAudit(){

<#

.SYNOPSIS
    SystemAudit will show you how cool is a task automation using OOP in Powershell.
    It is a system inventory script or system audit if you prefer. What is it for?
    You can gather some information about your local or even remote systems and create a trivial html report.
    Also with few small modifications you could customise nearly everything and add more details to the output.

    YOU NEED AT LEAST POWERSHELL 5.x as it's using classes !

.DESCRIPTION
	How it works. We have two classes here
    1. First class [InfObj] which is our blueprint class with the following properties:
    - ComputerName;
    - Shares
    - OsInfo;
    - SystemInfo;
    - startUp;
    - Processes;
    - Disks;
    - UserAccounts;

    And multiple methods.
    Main ones are : getOsInfo(), getSystemInfo(), getShares(), getDiskInfo(), getStartUp(), getProcess(), getUserAccounts()

    Constructors.
    InfObj() - creates an object for local system only
    InfObj([String]$computerName) - creates all objects (empty ones too)
    InfObj([String]$computerName,[Object]$masterpassword) - you will need to provide user and password to collect from remote hosts

    
    2.And Second class [startAudit], our "control class", which will hold all [infobj] objects in array.

    Properties
    - holder that's the  array where all [infobj] will be saved

    Methods: 
    doReport([object]$obj) creates html report
    fetchAllData([array]$obj) gets all data, however you will need to setup user name and password to access remote devices 

    Constructors: 

    StartAudit() - creates an [InfObj] for local machine and save it in our holder array
    StartAudit([String]$computers,[Password]$pass) - it will create [InfObj]
    only if the second parameter is set to TRUE ([password]::true), but if set to ([password]::false) 
    it will create an array with "empty objects" and only 2 properties populated (computername and alive)


.EXAMPLE
    $obj=[startAudit]::new()   -creates a new object for local machine
    $obj.holder                -displays all the properties with their values, as it is an array plese use $obj.holder[x] (x = array index)
    $obj.holder[0].osinfo, 
    $obj.holder[0].shares
    $obj.holder[0].disks 
    $obj | get-member to see all the methods and properties for your $obj
    $obj.holder | gm to see even more methods and properties for the holder's array
    $obj.doReport($obj.holder) - creates a simple html report and saves it in you home directory
    $obj.fetchAllData($obj.holder) gets "fresh" data 


.EXAMPLE
    	$obj=[startAudit]::new('.\computers.txt',[password]::True) - creates objects for all the IP's found in a file, 
    but only if you provide correct user name and password. You will get access denied otherwise.


.EXAMPLE
	$obj=[startAudit]::new('.\computers.txt',[password]::False) - same as above but it won't ask for user name and password
    It means that all objects will be created but only 2 properties get their values assigned (computername and alive)
    To populate all the properties please use the following static method
    
    [infObj]::setMasterPassword, after that you can set creds properties for each alive object !
    
    $obj.holder | ?{$_.alive -eq $true} | %{$_.creds=[infobj]::masterPasswd} or you can play with foreach loop
    
    foreach($i in $obj.holder){$i.creds=[infobj]::masterPasswd} or if you need to assign different password to each object use setcreds() method instead 
    
    $obj.holder | ?{$_.alive -eq $true} | %{$_.setcreds()}

.EXAMPLE
    
    Left it for you to fill it out. 

.NOTES
	Its pre beta version, do not expect miracles.


#>

}


class InfObj {

    static [String] $userLocation = $(Get-Item Env:\USERPROFILE | select -ExpandProperty value)
    static [Array] $objectsCreated=@()
    static [Object]$masterPasswd;
    [String]$computerName;
    [Array]$shares
    [Array]$osInfo;
    [Array]$systemInfo;
    [Array]$startUp;
    [Array]$processes;
    [Array]$disks;
    [Object]$creds;
    [Array]$userAccounts;
    [Bool]$alive=$false;
    static [Array]$errorList=@()
    
     
     
    #Constructor for localhost only

     InfObj(){
         $this.computerName='localhost'
         $this.alive=$true #you are on localhost now ;) 
         #$this.osInfo = Get-WmiObject win32_OperatingSystem -computername $this.computerName -ErrorAction Stop
         #$this.systemInfo= Get-WmiObject Win32_computersystem -computername $this.computerName -ErrorAction Stop
         $this.osInfo=$this.getOsInfo()
         $this.systemInfo=$this.getSystemInfo()
         $this.shares=$this.getShares()
         $this.disks=$this.getDiskInfo()            
         $this.startUp=$this.getStartUp()
         $this.processes=$this.getProcess()
         $this.userAccounts=$this.getUserAccounts()
         [infobj]::objectsCreated+=$this.computerName
         write-host " Object for $($this.computerName) created"  -BackgroundColor green -ForegroundColor blue 
     
     }

    #Basic constructor, it will initialize 2 variables only (computername and alive), purpose ? for learning OOP :)
    #Once object is created, you will need to play with the object itself to populate all the variables with some data ;) 

    InfObj([String]$computerName){
    
        
        $this.computerName=$computerName 
        $this.alive=$this.isAlive($computerName)
        [infobj]::objectsCreated+=$this.computerName
        
    
    }

    #3rd Constructor, it will check whether access to the remote endpoint is possible, object creation will fail otherwise
     
    InfObj([String]$computerName,[Object]$masterpassword){


        $this.creds=$masterpassword
        $this.computerName=$computerName 
        $this.alive=$this.isAlive($computerName)
        if ($this.alive -eq $true){

            try{

            

                #$this.osInfo = Get-WmiObject win32_OperatingSystem -computername $computerName -Credential $this.creds -ErrorAction Stop
                #$this.systemInfo= Get-WmiObject Win32_computersystem -computername $computerName -Credential $this.creds -ErrorAction Stop
                $this.osInfo=$this.getOsInfo()
                $this.shares=$this.getShares()
                
                $this.systemInfo=$this.getSystemInfo()
                $this.disks=$this.getDiskInfo()
                $this.startUp=$this.getStartUp()
                $this.processes=$this.getProcess()
                $this.userAccounts=$this.getUserAccounts()
                [infobj]::objectsCreated+=$computerName
                write-host " Object for $($this.computerName) created"  -BackgroundColor green -ForegroundColor blue
        
            }catch{
                $err=$_.Exception.message
                [infobj]::errorList+=$err
                write-host $this.computerName  $err -BackgroundColor red -ForegroundColor black
                continue
            }
        }else{ Write-Host "$($computername) check network connection please " -BackgroundColor red
                continue
                
                
        }
    
    }

    [Bool] isAlive([String]$computername){
        $ping = New-Object System.Net.NetworkInformation.Ping

        $ping_status=$ping.Send($computername)
        if($ping_status.Status -eq 'Success'){
            $this.alive=$true
            Write-Host "$($computername) is UP" -BackgroundColor green -ForegroundColor blue
        }else {
            Write-Host "$($computername) is DOWN " -BackgroundColor red
            $this.alive=$false
        
        }
    
    return $this.alive
    
    }

    static [String] getUserLocation(){

        return [InfObj]::userLocation; 
    }

    [Object] setCreds(){

        try{
                
            $this.creds=Get-Credential'' -ErrorAction Stop

        }catch{

            Write-Host "Maybe you should do it again?"
            

        }
    return $this.creds

    }

    static [Object] setMasterPassword(){
        try{
                
            [InfObj]::masterPasswd=Get-Credential'' -ErrorAction stop

        }catch{

            Write-Host "Not really, no ...?"
            
        
        }

    return [InfObj]::masterPasswd
    }

    [Array] getName(){
        return $this.computerName | select @{name='Computer';expr={$this.computerName}};
    }




    [Array] getDiskInfo(){

    $objHolder=@()

        if ($this.computerName -eq 'localhost'){
    
            $diskHolder=Get-WmiObject -Class win32_logicaldisk -ComputerName $this.computerName  | where {$_.drivetype -eq 3}`
            | select name ,@{name='size';expr={[math]::round($_.size/1GB,2)}},`
            @{name='free';expr={[math]::round($_.freespace/1GB,2)}},`
            @{name='percent';expr={[math]::round($_.freespace/$_.size,3)*100} } 
            }else {
                $diskHolder=Get-WmiObject -Class win32_logicaldisk -ComputerName $this.computerName -Credential $this.creds  | where {$_.drivetype -eq 3}`
                | select name ,@{name='size';expr={[math]::round($_.size/1GB,2)}},`
                @{name='free';expr={[math]::round($_.freespace/1GB,2)}},`
                @{name='percent';expr={[math]::round($_.freespace/$_.size,3)*100} } 
            }
    
                foreach($disk in $diskHolder){
                    
                    $obj=New-Object -TypeName psobject -Property @{
                    Disk=$disk.name 
                    size=$disk.size
                    free=$disk.free
                    "free(%)"=$disk.percent
            
                    }     
                $objHolder+=$obj

                }
                   
    return $this.disks=$objHolder

    }

    

    
    [Array] getShares(){

    if ($this.computerName -eq 'localhost') {
         try{

            $this.shares= Get-WmiObject -class Win32_Share -ComputerName $this.computerName -ErrorAction stop
        }catch
        {
            [infobj]::errorList+=$_.exception.message+" Cannot grab share drives for $($this.computerName) $(Get-Date)"
            Write-Host $_.exception.message
            continue
            
        }
        

    }else
        {
         try
            {
                $this.shares= Get-WmiObject -class Win32_Share  -ComputerName $this.computerName -Credential $this.creds -ErrorAction stop
            }catch
            {
                [infobj]::errorList+=$_.exception.message+" Cannot grab share drives for $($this.computerName) $(Get-Date)"
                Write-Host $_.exception.message
                continue
            }
        
        }


    return $this.shares
    
    }

    


    [Array] getProcess(){

    if ($this.computerName -eq 'localhost') {

            $this.processes = Get-WmiObject Win32_Process -ComputerName $this.computerName 

        }else {
            try{
            $this.processes = Get-WmiObject Win32_Process -ComputerName $this.computerName -Credential $this.creds -ErrorAction stop
             }catch{
            
               [infobj]::errorList+=$_.exception.message +"  Error to execute getProcess method -> $($this.computerName) $(Get-Date)"
               Write-Host $_.exception.message 
               continue
            }
        }


    return $this.processes

    }
    

    [Array] getStartUp(){

        if ($this.computerName -eq 'localhost') {

            $this.startup = Get-WmiObject Win32_StartupCommand -ComputerName $this.computerName 

        }else{
            try{
            $this.startup = Get-WmiObject Win32_StartupCommand -ComputerName $this.computerName -Credential $this.creds -ErrorAction stop
             }catch{
            
               [infobj]::errorList+=$_.exception.message +"  Error to execute getStartup method -> $($this.computerName) $(Get-Date)"
               Write-Host $_.exception.message 
               continue
            }
        }

    return $this.startup    

    
    }

    [Array] getUserAccounts(){

        if ($this.computerName -eq 'localhost') {

            $this.userAccounts = Get-WmiObject -Class Win32_UserAccount -ComputerName $this.computerName 

        }else{
            try{
            $this.userAccounts = Get-WmiObject -Class Win32_UserAccount -ComputerName $this.computerName -Credential $this.creds -ErrorAction stop
             }catch{
            
               [infobj]::errorList+=$_.exception.message +"  Error to execute getUserAccounts method -> $($this.computerName) $(Get-Date)"
               Write-Host $_.exception.message 
               continue
            }
        }

    return $this.userAccounts    

    
    }

    [Array] getOsInfo(){

        if ($this.computerName -eq 'localhost') {

            $this.osInfo = Get-WmiObject win32_OperatingSystem -ComputerName $this.computerName            
           
        }else{
            try{
                $this.osInfo = Get-WmiObject win32_OperatingSystem -ComputerName $this.computerName -Credential $this.creds -ErrorAction stop
            }catch{
            
               [infobj]::errorList+=$_.exception.message +"  Error to execute getOsInfo method -> $($this.computerName) $(Get-Date)"
               Write-Host $_.exception.message 
               continue
            }
        }
      
      return $this.osInfo
    
    }

    [Array] getSystemInfo(){

        if ($this.computerName -eq 'localhost') {

            $this.systemInfo = Get-WmiObject Win32_computersystem -ComputerName $this.computerName 

        }else{
            try{
                $this.systemInfo = Get-WmiObject Win32_computersystem -ComputerName $this.computerName -Credential $this.creds -ErrorAction stop
            }catch{
            
               [infobj]::errorList+=$_.exception.message +"  Error to execute getSystemInfo method -> $($this.computerName) $(Get-Date)"
               Write-Host $_.exception.message 
               continue
            }
        }
     return $this.systemInfo 
    
    }

} #  class ends here

Enum PASSWORD
{
    True
    False

}

class StartAudit  {



   hidden [Array]$file=$null;
   [Array]$holder

   
   StartAudit() {
   
        
        
        $this.holder=[infobj]::new()
        

    }
    
   

    StartAudit([String]$computers,[Password]$pass) {
        
        try{
            $this.file=Get-Content $computers -ErrorAction Stop
        }catch{
            write-host $_.exception.message  '
            
            Please specify a file you want to use which contain list of IP addresses
            example $object=[startaudit]::new(".\computers.txt",[password]::True)
            
            '
            break
        }
               

            if ($pass -eq [password]::True){
                
                [InfObj]::setMasterPassword()
            
                $this.holder=foreach($end in $this.file) {
                [infobj]::new($end,[infobj]::masterPasswd)    
        
            }

            }else{
                
                $this.holder=foreach($end in $this.file) {
   
                [infobj]::new($end)
                }
            }        
      
   }

   [void] fetchAllData([array]$obj){
   
        for($x=0;$x -le $this.holder.Length -1;$x++){
            
            if($obj[$x].isAlive($obj[$x].computerName) -eq $true){
                $obj[$x].alive=$true
                $obj[$x].getOsInfo()
                $obj[$x].getSystemInfo()
                $obj[$x].getShares()
                $obj[$x].getDiskInfo()
                $obj[$x].getStartUp()
                $obj[$x].getProcess()
                $obj[$x].getUserAccounts()
         
            }else{
                "Probaby system is down !"
                } 
        
        }
   
   }

   [void] doReport([object]$obj){

  

   $head = "
<style>
TABLE {border-width: 1px;border-style: solid;border-color: black;border-collapse: collapse;}
TH {border-width: 1px;padding: 2px;border-style: solid;border-color: blue ;background-color: #EDDA74;}
TD {border-width: 1px;padding: 2px;border-style: solid;border-color: blue;}
</style>
"
  
   
   $post = "<BR><p  align=center><i>Report generated on $((Get-Date).ToString()) from $($Env:Computername)</i></p>"
   $fileName=[infobj]::userLocation+"\report_"+$(get-date).ToString('MM-dd-yyyy')+".html"

        for($x=0;$x -le $this.holder.Length-1;$x++){
            $pre = "<h1 align='center'><BR>Report for $($this.holder[$x].computername)</h1>"

            
            $obj[$x].systeminfo| select Name,SystemType,domain,manufacturer,model | ConvertTo-Html -Head $head  -PreContent $pre | Out-File $fileName -Append
            $obj[$x].osinfo |select caption,version, osarchitecture | ConvertTo-Html  | Out-File $fileName -Append
            Write-Output "<h3><br>info about Disk</h3>" |  Out-File $fileName -Append
            $obj[$x].disks|select disk, size,free,"free(%)" | ConvertTo-Html  | Out-File $fileName  -Append
            Write-Output "<h3>Info about Start-up applications</h3>" | Out-File $fileName  -Append
            $obj[$x].startup |select name,description,location, command, path| ConvertTo-Html  | Out-File $fileName  -Append
            Write-Output "<h3><br>Info about Shared Folders</h3>" | Out-File $fileName -Append
            $obj[$x].shares|select name , description, path| ConvertTo-Html  | Out-File $fileName  -Append
            Write-Output "<h3><br>Info about accounts</h3>" | Out-File $fileName -Append 
            $obj[$x].useraccounts | select Name,Domain,Disabled,Lockout,Description,PasswordRequired | ConvertTo-Html  -PostContent $post| Out-File $fileName  -Append
   
        }
   }

}
  CLS


  Write-Host '
        Please use the following command import-module .\system_audit.ps1 first, unless you are doing this step now :)
                
        How to use it ?: for collection from your local machine use the following

        $obj=[startAudit]::new() 

        for remote hosts

        Export list of your computers to a file and copy it to the script folder 
        
        if you  want to initialize all objects for all IPs from a file.
        $obj=[startAudit]::new(".\yourComputerList.txt".[password]::false)
        
        $obj=[startAudit]::new(".\yourComputerList.txt".[password]::true) same as above 
        but you will be asked for user name ans password to access remote PCs, 
        if password/user is incorrect object creation will fail 
       
        
        -== FOR MORE DETAILS TYPE "get-help systemAudit -detailed"
        '
        
  
