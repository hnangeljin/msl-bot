#include-once
#include "../imports.au3"

#cs
	Function: Captures region and if there is saves into bmp if there is a specified file name.
	Parameters:
		$iMode: Change mode of capture: $MODE_BITMAP(0) uses WinAPI to create a bitmap. $MODE_ADB(1) sends screencap command and creates bitmap from file created.
		$sFileName: File name saved to main folder.
#ce
Func captureRegion($sFileName = "", $iX = 0, $iY = 0, $iWidth = $g_aControlSize[0], $iHeight = $g_aControlSize[1], $iBackgroundMode = $g_iBackgroundMode)
	getBitmapHandles($g_hHBitmap, $g_hBitmap, $iX, $iY, $iWidth, $iHeight, $iBackgroundMode)

	If $sFileName <> "" Then
		$sFileName = StringReplace($sFileName, ".bmp", "")
		saveHBitmap($sFileName)
	EndIf
EndFunc

#cs
    Function: Retrieves current game location.
	Parameters:
		$aLocations: Format=[["LOCATION_NAME", "PIXEL_SET"], [...]]
	Returns: String game location.
	Extended: Location pixel data.
#ce
Func getLocation($aLocations = $g_aLocations, $bUpdate = True)
	If $g_hTimerLocation = Null Then $g_hTimerLocation = TimerInit()
	Local $sOldLocation = $g_sLocation

	If $bUpdate = True Then captureRegion() ;Updates global bitmap

	;Going through location data and using isPixelAND() function to check each location.
	Local Const $iSize = UBound($aLocations, $UBOUND_ROWS)
	If ($iSize = 0) Or (isArray($aLocations) = False) Then
		$g_sErrorMessage = "getLocation() => Invalid argument."
		Return -1
	EndIf

	Local $t_sLocation = "" ;Temporary location to double check location.
	For $i = 0 To $iSize-1
		If ($aLocations[$i][0] = "") Or (StringMid($aLocations[$i][0], 0, 1) = ";") Then ContinueLoop

		If isPixelOR($aLocations[$i][1], 20) = True Then
			If $bUpdate = False Then 
				Global $g_vDebug = [$aLocations[$i][0], $aLocations[$i][1]]

				$g_sLocation = $aLocations[$i][0]
				If $g_sLocation <> $sOldLocation Then $g_hTimerLocation = TimerInit()

				Return $aLocations[$i][0] ;no double check if update is false.
			EndIf

			;checks in 200 miliseconds for same location.
			If ($g_iBackgroundMode <> $BKGD_ADB) And (_Sleep(200) = True) Then Return ""
			captureRegion()

			If isPixelOR($aLocations[$i][1], 20) = True Then
				Global $g_vDebug = [$aLocations[$i][0], $aLocations[$i][1]]

				$g_sLocation = $aLocations[$i][0]
				If $g_sLocation <> $sOldLocation Then $g_hTimerLocation = TimerInit()

				Return $aLocations[$i][0] ;Returns confirmed location.
			EndIf
		EndIf
	Next

	$g_vDebug = ""

	$g_sLocation = "unknown"
	If $g_sLocation <> $sOldLocation Then $g_hTimerLocation = TimerInit()

	Return "unknown" ;If no location from database is found.
EndFunc

#cs
	Function: Waits for a location to appear and returns when it does.
	Parameters:
		$vLocations: Array or stirng of locations. Format=["location", "..."] or "location,..."
		$iSeconds: How long to wait for in seconds
		$bReturnBool: If false, returns the location string found.
	Returns: String or Boolean depending on $bReturnBool
#ce
Func waitLocation($vLocations, $iSeconds, $bReturnBool = True)
	Local $iTimerInit = TimerInit()
	While (TimerDiff($iTimerInit) < $iSeconds*1000)
		Local $t_vResult = isLocation($vLocations, $bReturnBool)
		If $t_vResult <> "" Then
			Return $t_vResult
		EndIf

		If _Sleep(200) Then Return False
	WEnd

	;Not found within timeframe
	If $bReturnBool = True Then Return False
	Return ""
EndFunc

#cs
	Function: Checks if any one of the locations from the specified set of locations are
	Parameters:
		$vLocations: Array or stirng of locations. Format=["location", "..."] or "location,..."
		$bReturnBool: If false, returns the location string found.
	Returns: String or Boolean depending on $bReturnBool
#ce
Func isLocation($vLocations, $bReturnBool = True)
	Local $aLocations = Null
	Local $sCurrLocation = getLocation()

	If $sCurrLocation = -1 Then Return False

	;Fixing argument format= ["location", "..."]
	If isArray($vLocations) = False Then
		;Expected format: "location, ..."
		$vLocations = StringStripWS($vLocations, $STR_STRIPALL) ;Removes all whitespace.
		$aLocations = StringSplit($vLocations, ",", $STR_NOCOUNT)
	Else
		$aLocations = $vLocations
	EndIf

	;Checking array if location exists
	For $i = 0 To UBound($aLocations)-1
		Local $sLocation = $aLocations[$i]
		If $sLocation = $sCurrLocation Then
			;found
			If $bReturnBool = True Then Return True
			Return $sLocation
		EndIf
	Next

	;not found
	If $bReturnBool = True Then Return False
	Return ""
EndFunc

#cs 
	Function: Creates a local location data.
	Parameters:
		$sLocation: New or exisiting location.
		$aData: If location does not exist, will create location based on array of points. Format: "123,321|564,456|..." or ["123, 321", "321, 123", "...,..."]
	Returns: 
		- On successful, true
		- On failure, false
#ce
Func setLocation($sLocation, $aData = Null)
	Local $aLocation = getArg($g_aLocations, $sLocation)
	Local $aPoints[0][2] ;Will store points to find colors for.
	
	If $aLocation = -1 Then
		;Creates new location.
		If isArray($aData) = False Then 
			$aData = StringSplit($aData, "|", $STR_NOCOUNT)
		EndIf

		For $sData In $aData
			Local $aPoint = StringSplit($sData, ",", $STR_NOCOUNT)

			ReDim $aPoints[UBound($aPoints)+1][2]
			$aPoints[UBound($aPoints)-1][0] = $aPoint[0]
			$aPoints[UBound($aPoints)-1][1] = $aPoint[1]
		Next
	Else
		;Creates local version of the location. This location will be prioritized versus the remote location.
		Local $sPixelSet = $aLocation
		If StringInStr($sPixelSet, "/") = True Then
			$sPixelSet = StringSplit($sPixelSet, "/", $STR_NOCOUNT)[0]
		EndIf

		Local $aPixels = StringSplit($sPixelSet, "|", $STR_NOCOUNT)
		ReDim $aPoints[UBound($aPixels)][2]
		For $i = 0 To UBound($aPixels)-1
			Local $aPixel = StringSplit($aPixels[$i], ",", $STR_NOCOUNT)

			$aPoints[$i][0] = $aPixel[0]
			$aPoints[$i][1] = $aPixel[1]
		Next
	EndIf

	CaptureRegion()

	Local $sNewPixels = "" ;Will store new pixel set
	For $i = 0 To UBound($aPoints)-1
		$sNewPixels &= "|" & $aPoints[$i][0] & "," & $aPoints[$i][1] & "," & getColor($aPoints[$i][0], $aPoints[$i][1])
	Next
	$sNewPixels = StringMid($sNewPixels, 2)

	Local $hFile = FileOpen($g_sLocationsLocal, $FO_APPEND+$FO_CREATEPATH)
	Local $bOutput = (FileWriteLine($hFile, $sLocation & ":" & $sNewPixels) = 1)
	FileClose($hFile)

	Log_Add("You must restart for the new location to take effect.", $LOG_INFORMATION)
	Return $bOutput
EndFunc

#cs
	Function: Retrieves which round the battle is currently.
	Parameters:
		$aPixels: List where the pixel rounds are.
	Return: Current round and the number of total rounds: Array format=[current, max]
#ce
Func getRound($aPixels = $g_aPixels)
	Local $iMax = 0 ;Max number of rounds
	;Getting max number of rounds
	For $i = 2 To 4
		Local $t_sArgument = getArg($aPixels, "max-round-" & $i)
		If ($t_sArgument = "") Or ($t_sArgument = -1) Then ContinueLoop

		If isPixel($t_sArgument) = True Then
			$iMax = $i
			ExitLoop
		EndIf
	Next
	If $iMax = 0 Then 
		$g_sErrorMessage = "getRound() => Could not find max."
		Return -1
	EndIf

	Local $iCurr = 0 ;Current round
	;Getting current round
	For $i = 1 To $iMax
		Local $t_sArgument = getArg($aPixels, "curr-round-" & $i)
		If ($t_sArgument = "") Or ($t_sArgument = -1) Then ContinueLoop

		If isPixel($t_sArgument) = True Then
			$iCurr = $i
			ExitLoop
		EndIf
	Next
	If $iCurr = 0 Then 
		$g_sErrorMessage = "getRound() => Could not find current."
		Return -1
	EndIf

	Local $t_aResult = [$iCurr, $iMax]
	Return $t_aResult
EndFunc

#cs 
	Function: Tries to close a in game window interface.
	Parameters:
		$sPixelName: Name for argument within a formated argument array.
		$aPixelList: Formatted argument array.
	Return: If window was closed successfully then return true. Else return false.
#ce
Func closeWindow($sPixelName = "window_exit", $aPixelList = $g_aPixels)
	Local $t_sPixels = getArg($aPixelList, $sPixelName)

	If $t_sPixels = "" Or $t_sPixels = -1 Then
		$g_sErrorMessage = "closeWindow() => No pixel found."
		Return -1
	EndIf

	Local $aPixelSet = StringSplit($t_sPixels, "/", $STR_NOCOUNT)
	For $i = 0 To UBound($aPixelSet)-1
		Local $t_iTimerInit = TimerInit()
		While isPixel($aPixelSet[$i], 10) = True
			If TimerDiff($t_iTimerInit) >= 2000 Then Return False ;two seconds
			;Closing until pixel is not the same.
			Local $t_aPixel = StringSplit($aPixelSet[$i], ",", $STR_NOCOUNT)
			
			clickPoint($t_aPixel, 1, 0)

			If _Sleep(500) Then Return False
			CaptureRegion()

			If isPixel($aPixelSet[$i], 10) = False Then Return True
		WEnd
	Next

	Return False
EndFunc

#cs 
	Function: Tries to close dialogue between players in game
	Return: If dialogue has been closed successfully then return true. Else return false.
#ce
Func skipDialogue()
	Local $t_iTimerInit = TimerInit()
	Local $sLocation = getLocation()
	
	While getLocation() = "dialogue"
		If TimerDiff($t_iTimerInit) >= 20000 Then Return False ;twenty seconds

		clickPoint(getArg($g_aPoints, "dialogue-skip"))
		If _Sleep(200) Then Return False
	WEnd

	Return True
EndFunc