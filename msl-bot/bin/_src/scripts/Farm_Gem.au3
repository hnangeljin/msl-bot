#include-once
#include "../imports.au3"

Func Farm_Gem($Gems_To_Farm, $Catch_Image, $Astromon, $Finish_Round, $Final_Round, $Map, $Difficulty, $Stage_Level, $Capture, $Gems_To_Sell, $Usable_Astrogems, $Guardian_Mode, $Collect_Quests, $Hourly_Script)
    Log_Level_Add("Farm_Gem")
    Log_Add("Farm Gem has started.")
    
    ;Declaring variables and data
    Data_Add("Status", $DATA_TEXT, "")
    Data_Add("Farmed Gems", $DATA_RATIO, "0/" & $Gems_To_Farm)

    Data_Add("Refill", $DATA_RATIO, "0/" & $Usable_Astrogems, True)

    Data_Add("Need Catch", $DATA_NUMBER, "0")
    Data_Add("Error", $DATA_NUMBER, "0")

    ;Adding to display order
    Data_Order_Insert("Status", 0)
    Data_Order_Insert("Farmed Gems", 1)
    Data_Order_Insert("Refill", 2)

    Data_Display_Update()

    ;Script Process
    #cs 
        Script will evolve in monsters location and catch astromons using Farm_Astormon script.
    #ce
    While Data_Get_Ratio("Farmed Gems") < 1
        Local $sLocation = getLocation()
        If $Hourly_Script = "Enabled" Then Common_Hourly($sLocation)
        If _Sleep(10) Then ExitLoop

        ;Handles catching process
        While Data_Get("Need Catch") > 0
            Log_Add("Going to catch " & Data_Get("Need Catch") & " astromons.", $LOG_INFORMATION)
            Local $t_aOrder = $g_aOrder
            Farm_Astromon(Data_Get("Need Catch"), $Catch_Image, $Finish_Round, $Final_Round, $Map, $Difficulty, $Stage_Level, $Capture, $Gems_To_Sell, $Usable_Astrogems, $Guardian_Mode, $Collect_Quests, $Hourly_Script)
            If _Sleep(10) Then ExitLoop(2)
            $g_aOrder = $t_aOrder
            Data_Display_Update()

            $sLocation = getLocation()
            Switch $sLocation
                Case "astromon-full"
                    Data_Set("Need Catch", "0")
                Case Else
                    If Data_Get_Ratio("Caught") < 1 Then
                        Log_Add("Something went wrong with Farm Astromon.", $LOG_ERROR)
                        ExitLoop(2)
                    EndIf
            EndSwitch

            Data_Increment("Need Catch", "-" & Data_Get($Catch_Image, True)[0])
        WEnd

        ;Handles evolving process
        Data_Set("Status", "Evolving astromon.")
        $vResult = evolve($Astromon, True)
        Switch $vResult
            Case -1, -2, -3, -4, -6 ;Normal errors.
                Log_Add("Could not evolve, error code: " & $vResult, $LOG_ERROR)
                Data_Increment("Error", 1)
                If Data_Get("Error") > 5 Then 
                    Log_Add("Too many errors has occurred.", $LOG_ERROR)
                    ExitLoop
                EndIf
            Case -5 ;No currency.
                Log_Add("Not enough gold to procceed.", $LOG_ERROR)
                ExitLoop
            Case Else ;Success
                If $vResult = 0 Then Data_Increment("Farmed Gems", 100)
                Log_Add("Farmed Gems " & Data_Get("Farmed Gems"), $LOG_INFORMATION)
                Data_Increment("Need Catch", $vResult)
        EndSwitch
    WEnd

    ;End script
    Log_Add("Farm Astromon has ended.")
    Log_Level_Remove()
EndFunc