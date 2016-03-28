$METADATA_PREFIX='^#'
$WANTED_QUALITY=1200000
$PLAYLIST_FILENAME="playlist.m3u8"
$RETRY_NUM=5

$FOLDER=(Get-Item $args.Get(0)).FullName
$URL=$args.Get(1)

$PLAYLIST_FILE="$FOLDER\$PLAYLIST_FILENAME"

function remove_last_url_part
{
    $Local:Parts=$args.Get(0).Split('/')
    $Local:STR=""
    for ($i=0; $i -lt $Local:PARTS.Count - 1; $i++) 
    { 
        $Local:STR+=$Local:PARTS.Get($i)
        $Local:STR+='/' 
    }

    return $Local:STR
}

function fetch_playlist_file
{
    $Local:BASE_URL=$args.Get(0)
	$PLAY_LIST_URL="$BASE_URL/$PLAYLIST_FILENAME"
    $r=Invoke-WebRequest $PLAY_LIST_URL -PassThru -OutFile $PLAYLIST_FILE
	if ($r.StatusCode -ne 200)
    {
		Write-Host "Could not find playlist at the given url = '$PLAY_LIST_URL', either bad url or the site changed the format... exiting"
        Read-Host -Prompt "Press Enter to exit"
		exit 1
	}
}

function fetch_chunks_file
{
	fetch_playlist_file $args.Get(0)

    $Local:CHUNKS_URL=(Get-Content $PLAYLIST_FILE | Select-String -Pattern ":BANDWIDTH=$WANTED_QUALITY" -Context 0,1).Context.PostContext.Get(0)
	$Global:VIDEO_BASE_URL=(remove_last_url_part $CHUNKS_URL)
	$Global:CHUNKS_FILE="$FOLDER\chunks_$WANTED_QUALITY.m3u8"
	
    $r=Invoke-WebRequest -PassThru -OutFile $Global:CHUNKS_FILE $Local:CHUNKS_URL
	if ($r.StatusCode -ne 200)
    {
		Write-Host "Playlist file was not built as expected, possible problems might be bad internet connection or the site changed the format and thus this script will no longer work... exiting"
        Read-Host -Prompt "Press Enter to exit"
		exit 2
	}
}

function recover_needed_chunks
{
	$Local:CHUNKS_TO_FETCH=New-Object System.Collections.Generic.List[System.Object]

	foreach ($Local:chunk in $args.Get(0))
    {
        $Local:chunkName=$Local:chunk.Matches.Value
		if (Test-Path "$FOLDER\$Local:chunkName" -PathType Leaf)
        {
            Write-Host "$FOLDER\$Local:chunkName exists, not fetching again"
			
        }
		else
		{
        	Write-Host "$FOLDER/$Local:chunkName does not exist"
	        $Local:CHUNKS_TO_FETCH.Add($Local:chunkName)
		}
	}

    return $Local:CHUNKS_TO_FETCH
}

function parse_url
{
	$Local:BASE_URL=remove_last_url_part $URL
	fetch_chunks_file $Local:BASE_URL

	$Local:CHUNKS=Get-Content $Global:CHUNKS_FILE | Select-String -Pattern ".*.ts" | Select Matches

    (Get-Content $Global:CHUNKS_FILE) | Foreach-Object { $_ -replace "\?.*", "" } | Set-Content $Global:CHUNKS_FILE

	return recover_needed_chunks $Local:CHUNKS
}

$Global:VIDEO_BASE_URL

$Local:chunks_to_fetch=parse_url

$fetch_part = 
{
    $TEMP_NAME="$FOLDER/${_}_not_yet_ready"
    Write-Host "Fetching '$_' into temporary file"
    $Local:first=True
    $i=0
    do 
    {
        $r=Invoke-WebRequest -PassThru -OutFile $TEMP_NAME -Uri "$Global:VIDEO_BASE_URL/$_"
        if ($r.StatusCode -eq 200)
        {
            Write-Host "Done fetching part '$_', renaming termporary file"
            mv $TEMP_NAME $FOLDER/${_}
            return
        }
        if ($i -ne 0)
        {
            Write-Host "Problem happened with $_, error code was" + $r.StatusCode
        }
        $i++
    } while ($i -lt $RETRY_NUM)
    
    throw "Too many failed attempts to fetch $_, try again later!"
}

$SCRIPTS_FOLDER=Split-Path $MyInvocation.InvocationName
Unblock-File -Path "$SCRIPTS_FOLDER\Invoke-Parallel.ps1"
. "$SCRIPTS_FOLDER\Invoke-Parallel.ps1"

Invoke-Parallel -InputObject $Local:chunks_to_fetch -Throttle 30 -ScriptBlock $fetch_part -ImportVariables

try
{
    Push-Location ($FOLDER)

    $NAME_=$args.Get(0)
    $NAME="$FOLDER\$NAME_.mp4"
    Write-Host "Converting the files to one big file, this may take a while, you will be prompted when it's done"
    ffmpeg.exe -i $Global:CHUNKS_FILE -c copy -bsf:a aac_adtstoasc $NAME 

    Write-Host "Done converting. Deleting .ts files, waiting for confirmation!"

    $choices = New-Object Collections.ObjectModel.Collection[Management.Automation.Host.ChoiceDescription]
    $choices.Add((New-Object Management.Automation.Host.ChoiceDescription -ArgumentList '&Everything went Superb'))
    $choices.Add((New-Object Management.Automation.Host.ChoiceDescription -ArgumentList '&Something went bad. Keep the temporary files'))

    $decision = $Host.UI.PromptForChoice($message, $question, $choices, 1)

    if ($decision -eq 0) 
    {
        Write-Host "Alrighty then, deleting the temporary files. Have a nice day, and may the force be with you :)"
        rm -Recurse media_*
    }
    else
    {
        Write-Host "The servers sometimes can't handle the load, you may want to try again in a few minutes."
        Write-Host "Also, it could be that this software stopped working, you may contact me and let me know :)"
    }
}
finally
{
    Pop-Location
}