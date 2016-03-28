$SCRIPT_NAME = $MyInvocation.MyCommand.Name

function USAGE
{
    echo "Error, invalid usage. expected folder name"
    echo "Usage: $SCRIPT_NAME [folder_name] [address]"
    echo "For example - $SCRIPT_NAME course_name http://.../"
    echo "              $SCRIPT_NAME "
    echo ""
    echo "If this is the first run, the address parameter is mendatory"
    echo "If this is not the first run, you must not specify the address command or leave it empty"
    exit
}

if ($args.count -eq 0)
{
    [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms")
    $folder_form = New-Object System.Windows.Forms.FolderBrowserDialog

    if($folder_form.ShowDialog() -ne "OK")
    {
        echo "Cancelling"
        $x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        exit
    }   

    $FOLDER=$folder_form.SelectedPath
}
else
{
    $FOLDER=$args.Get(0)
    
    if ([string]::IsNullOrEmpty($FOLDER))
    {
        USAGE
    }
}


if (Test-Path $FOLDER -PathType Leaf)
{
    echo "Error, given parameter '$FOLDER' must be a folder or not exist"
    USAGE
}


if (!(Test-Path -Path $FOLDER))
{
    mkdir $FOLDER
}

# check again if mkdir fails
if (!(Test-Path -Path $FOLDER))
{
    echo "Bad folder"
    $x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit
}

$ADDR_FILE="$FOLDER/addr"

function create_addr_file
{
    $args.Get(0) | Out-File $ADDR_FILE
}

function addr_file_exists
{
    return Test-Path -Path $ADDR_FILE -PathType Leaf
}

if ($args.count -eq 2)
{
    $ADDRESS_ARG=$args.Get(1);
    
    if (addr_file_exists)
    {
        $ADDRESS_FROM_FILE=cat $ADDR_FILE
        if ($ADDRESS_ARG.CompareTo($ADDRESS_FROM_FILE) -ne 0)
        {
            echo "Error - file 'addr' exists from previous runs and it's different from given address."
            echo "From file $ADDR_FILE = '$ADDRESS_FROM_FILE'"
            echo ""
            echo "From argument = '$ADDRESS_ARG'"
            echo "Either delete the file or change the running argument. Note: Some other leftovers may still exist in the folder"
            exit
        }
    }
    else
    {
        create_addr_file $ADDRESS_ARG
    }
    
    $ADDRESS=$ADDRESS_ARG
}
else
{
    if (!(addr_file_exists))
    {
        [System.Reflection.Assembly]::LoadWithPartialName('Microsoft.VisualBasic') | Out-Null
        $ADDRESS = [Microsoft.VisualBasic.Interaction]::InputBox("Enter the media file address, normally it ends with .m3u8 extention", "Address chooser", "http://")
        
        create_addr_file $ADDRESS
    }
    else
    {
        $ADDRESS=Get-Content $ADDR_FILE
    }
}

Unblock-File -Path "$PSScriptRoot\fetch_video.ps1"
powershell -noexit -file "$PSScriptRoot\fetch_video.ps1" "$FOLDER" "$ADDRESS"
Read-Host -Prompt "Press Enter to exit"