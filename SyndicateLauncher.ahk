#Requires AutoHotkey v2
#SingleInstance force   ; Allow only a single instance of the script to run.
#Warn                   ; Enable warnings to assist with detecting common errors.

; The whole reason for this script is that the game may refuse to run due to error code "0xc0000142".
; For some reason, attempting to run the game multiple times in a short timespan does make it run.
; You can do that by selecting the game executable and holding Enter until you see the splash screen.
; This is tedious and will make a lot of error pop-ups appear. Therefore, this script will automate
; the whole process and make sure all error pop-ups are closed.

; DO NOT EDIT THOSE
global sWinTitleErrorPopup := "Syndicate.exe -" ; normally "Syndicate.exe - Application Error" but we omit the last part for non-English Windows
global sWinTitleGame := "ahk_class MOS Win32/D3D9.x ahk_exe Syndicate.exe" ; Game window
global sWinTitleSplash := "ahk_class #32770 ahk_exe Syndicate.exe" ; Splash screen

; How many times we should try running the game (run the script multiple times or increase this value if the game still doesn't run)
global g_nAttempts := 50
; How many milliseconds to wait between each running attempt
global g_nTimeBetweenAttempts := 50
; The full path to Syndicate.exe, it'll fall back to the current directory if not found
global g_sExePath := A_WorkingDir "\Syndicate.exe"
; Wait for the game process to close between each unsuccessful attempt (the game will take much longer to launch and any potential error pop-up
; won't be closed until after the game closes)
global g_bUseRunWait := false

ReadConfigfile()
RunGame()

; Display an error message and exit
ExitWithErrorMessage(p_sErrorMessage)
{
	MsgBox(p_sErrorMessage, "Error", 16)
	ExitApp(1)
}

Output(p_sMessage)
{
	OutputDebug(p_sMessage "`n")
}

ReadConfigfile()
{
	global

	local l_sConfigFileName := "SyndicateLauncher.ini"

	g_nAttempts            := IniRead(l_sConfigFileName, "General", "attempts",            50)
	g_nTimeBetweenAttempts := IniRead(l_sConfigFileName, "General", "timeBetweenAttempts", 50)
	g_sExePath             := IniRead(l_sConfigFileName, "General", "exePath",             A_WorkingDir "\Syndicate.exe")
	g_bUseRunWait          := IniRead(l_sConfigFileName, "General", "useRunWait",          false)

	; Enforce default values in case they're incorrect
	try g_nAttempts := Max(g_nAttempts, 1)
	catch ; not an integer
		g_nAttempts := 50

	try g_nTimeBetweenAttempts := Max(g_nTimeBetweenAttempts, 1)
	catch ; not an integer
		g_nTimeBetweenAttempts := 50

	g_bUseRunWait := g_bUseRunWait = true ? true : false ; 0 or 1
}

RunGame()
{
	global

	; Game is already running, just activate it
	if (WinExist(sWinTitleGame))
	{
		WinActivate(sWinTitleGame)
		return
	}

	; If the user somehow forgot to include the executable name in the path, we do it for them
	if (FileExist(g_sExePath) == "D")
		g_sExePath := RTrim(g_sExePath, "\") "\Syndicate.exe"

	; Search in the current directory if the executable doesn't exist
	if (!FileExist(g_sExePath))
	{
		g_sExePath := A_WorkingDir "\Syndicate.exe"

		if (!FileExist(g_sExePath))
			ExitWithErrorMessage(g_sExePath " not found! The script will now exit.")
	}

	; Try to run the game multiple times
	Output("Attempting to launch the game " g_nAttempts " times")
	loop g_nAttempts
	{
		Output("Attempt " A_Index " to launch the game")

		if (!g_bUseRunWait && !WinExist(sWinTitleSplash))
		{
			try Run(g_sExePath)
			Sleep(g_nTimeBetweenAttempts)

			; The game ran successfully, stop trying
			if (WinExist(sWinTitleSplash))
			{
				Output("Splash window detected")
				break
			}
		}
		else if (g_bUseRunWait)
		{
			local l_errCode := -1
			try l_errCode := RunWait(g_sExePath)

			; The game closed after a successful run, stop trying
			if (l_errCode == 0)
			{
				Output("The game closed after running successfully")
				break
			}
		}
	}

	; Wait a bit before closing pop-ups
	if (!g_bUseRunWait)
	{
		Output("Waiting for the game window to exist")

		if (!WinWait(sWinTitleGame, , 5))
			Output("Timeout reached")
	}

	Output("Closing all existing error pop-ups")
	local l_nMaxLoops := Max(g_nAttempts, 200)

	; Close all existing error pop-ups
	while (WinExist(sWinTitleErrorPopup))
	{
		Output("Closing error pop-up number " A_Index)
		WinClose() ; Use the last found window
		;PostMessage(0x0112, 0xF060) ; 0x0112 = WM_SYSCOMMAND, 0xF060 = SC_CLOSE
		;WinKill()

		; Prevent infinite loop in case WinClose() did nothing
		if (A_Index > l_nMaxLoops)
		{
			Output("Reached maximum loop count, exiting")
			break
		}
	}
}
