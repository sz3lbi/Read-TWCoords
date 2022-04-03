<#
    .SYNOPSIS
    Reads coords from the 5x5 areas provided villages are in.

    .DESCRIPTION
    Takes one or multiple coordinates and returns coordinates from 5x5 areas where villages are located.
    Works for every language version of the Tribal Wars game, offers the ability to save the result to a text file.

    .PARAMETER ServerKey
    The server key which contains 2-3 characters specifying the language version of the game and 2-3 digits with the server number.

    .PARAMETER Coords
    Single coordinates or an array of coordinates in the form "123|456".

    .PARAMETER OutputFile
    The path to the output file. In case the file already exists, it will not be overwritten and the script will display an error.

    .EXAMPLE
    .\Read-TWCoords.ps1 -ServerKey pl150 -Coords "123|456", "456|123" -OutputFile "C:\Users\UserName\Desktop\file.txt"

    .NOTES
    Author: szelbi 
    Version: 1.0
#>
Param(
    [Parameter(Mandatory)]
    [ValidatePattern("^[a-zA-Z]{2,3}[0-9]{2,3}$")]
    [string]$ServerKey,
    [Parameter(Mandatory)]
    [ValidatePattern("^[0-9]{3}\|[0-9]{3}$")]
    [string[]]$Coords,
    [string]$OutputFile
)

$OutputFileProvided = $PSBoundParameters.ContainsKey('OutputFile');

If ($OutputFileProvided -And (Test-Path $OutputFile)) {
    Throw "The file already exists. Try another name.";
}

class CoordsPair {
    [int]$x
    [int]$y

    CoordsPair(
        [int]$x,
        [int]$y
    ) {
        $this.x = $x
        $this.y = $y
    }
}

[string[]]$UniqueCoords = $Coords | Sort-Object | Get-Unique;
$UniqueCoordsLength = $UniqueCoords.Length;

$CoordsPairs = [CoordsPair[]]::new($UniqueCoordsLength);
for ($i = 0; $i -lt $UniqueCoordsLength; $i++) {
    $CoordsPairArray = $UniqueCoords[$i].Split("|");
    $CoordsPairs[$i] = [CoordsPair]::new([int]$CoordsPairArray[0], [int]$CoordsPairArray[1]);
}

function Measure-SquareStart {
    param (
        [CoordsPair]$CoordsPair
    )
    $XLastDigit = $CoordsPair.x % 10;
    $YLastDigit = $CoordsPair.y % 10;
    
    $SquareStartX = $CoordsPair.x - $XLastDigit;
    if ($XLastDigit -gt 5) {
        $SquareStartX += 5;
    }
    $SquareStartY = $CoordsPair.y - $YLastDigit;
    if ($YLastDigit -gt 5) {
        $SquareStartY += 5;
    }
    $SquareStart = [CoordsPair]::new($SquareStartX, $SquareStartY);

    return $SquareStart;
}

function Measure-SquareEnd {
    param (
        [CoordsPair]$SquareStart
    )
    $SquareEnd = [CoordsPair]::new($SquareStart.x + 4, $SquareStart.y + 4);
    return $SquareEnd;
}

$SquarePrefix = 'square';
$CoordsPairsLength = $CoordsPairs.Length;
$QueryElements = [string[]]::new($CoordsPairsLength);
for ($i = 0; $i -lt $CoordsPairsLength; $i++) {
    $SquareStart = Measure-SquareStart($CoordsPairs[$i]);
    $SquareEnd = Measure-SquareEnd($SquareStart);
    $QueryElements[$i] = "${SquarePrefix}${i}:villages(server:\`"${ServerKey}\`",filter:{xGTE:$($SquareStart.x),xLTE:$($SquareEnd.x),yGTE:$($SquareStart.y),yLTE:$($SquareEnd.y)}){items{x,y,player{name}}}";
}

$Uri = 'https://api.tribalwarshelp.com/graphql';
$Headers = @{
    'Accept-Encoding' = 'gzip, deflate, br'
    'Content-Type'    = 'application/json'
    'Accept'          = 'application/json'
    'DNT'             = '1'
    'Origin'          = 'https://api.tribalwarshelp.com'
}
$QueryElementsJoined = $QueryElements -join "";
$Body = "{`"query`":`"query{${QueryElementsJoined}}`"}";

$Response = Invoke-RestMethod -Uri $Uri -Method Post -Headers $Headers -Body $Body;

if ($Response.errors) {
    Throw "An API error occured. Check your input parameters and try again.";
}

for ($i = 0; $i -lt $CoordsPairsLength; $i++) {
    $PlayerCoords = [System.Collections.Generic.List[string]]::new()
    $BarbarianCoords = [System.Collections.Generic.List[string]]::new()

    $Square = $Response.data."${SquarePrefix}${i}";
    [PSCustomObject[]]$Villages = $Square.items;

    foreach ($Village in $Villages) {
        $CoordsJoined = "$($Village.x)|$($Village.y)";
        if ($Village.player) {
            $PlayerCoords.Add($CoordsJoined);
        }
        else {
            $BarbarianCoords.Add($CoordsJoined);
        }
    }

    $SquareNoString = "Square ${i}";
    
    Write-Host $SquareNoString -ForegroundColor Yellow;

    $PlayersVillagesString = "Players' villages:";    
    Write-Host $PlayersVillagesString -ForegroundColor Red;
    $PlayerCoords    

    $BarbarianVillagesString = 'Barbarian villages:';    
    Write-Host $BarbarianVillagesString -ForegroundColor Red;
    $BarbarianCoords

    If ($OutputFileProvided) {
        $SquareNoString | Out-File -FilePath $OutputFile -Append;
        $PlayersVillagesString | Out-File -FilePath $OutputFile -Append;
        $PlayerCoords | Out-File -FilePath $OutputFile -Append;
        $BarbarianVillagesString | Out-File -FilePath $OutputFile -Append;
        $BarbarianCoords | Out-File -FilePath $OutputFile -Append;
    }
}
