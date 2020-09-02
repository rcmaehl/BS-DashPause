#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Version=Beta
#AutoIt3Wrapper_Icon=icon.ico
#AutoIt3Wrapper_Compile_Both=y
#AutoIt3Wrapper_UseX64=y
#AutoIt3Wrapper_Res_Comment=Compiled 8/28/2020 @ 19:15 EST
#AutoIt3Wrapper_Res_Description=Beat Saber Dash Pause
#AutoIt3Wrapper_Res_Fileversion=0.4.0.0
#AutoIt3Wrapper_Res_LegalCopyright=Robert Maehl, using LGPL 3 License
#AutoIt3Wrapper_Res_Language=1033
#AutoIt3Wrapper_Res_requestedExecutionLevel=asInvoker
#AutoIt3Wrapper_Run_Au3Stripper=y
#Au3Stripper_Parameters=/pe /so
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****
#include "includes\WinHTTP.au3"

#include <WinAPI.au3> ; _WinAPI_GetLastError
#include <WinAPIProc.au3> ; _WinAPI_GetProcessFileName
#include <String.au3> ; _HexToString
#include <EditConstants.au3>
#include <FileConstants.au3> ; _LogOpen(), FileGetVersion
#include <GUIConstantsEx.au3>
#include <WindowsConstants.au3>

Global $sVer = "0.4"
Global $sLocation = ""

Main()

Func Main()

	Local $bDev = False
	Local $sData = ""
	Local $hSocket = 0
	Local $iTimeout = 500
	Local $bRunning = False
	Local $bSuspended = False

	Local $hLogHandle = ""

	Local $bInLevel = False
	Local $bLevelPaused = False

	If $bDev Then
		Local $hGUI = GUICreate("DashPause", 640, 480, -1, -1, BitOr($WS_MINIMIZEBOX, $WS_CAPTION, $WS_SYSMENU))
		Local $hData = GUICtrlCreateEdit("", 0, 20, 640, 460, BitOR($ES_MULTILINE, $WS_VSCROLL, $ES_AUTOVSCROLL, $ES_READONLY))
		GUISetState(@SW_SHOW, $hGUI)
	EndIf

	TraySetToolTip("DashPause")

	While 1

		$hMsg = GUIGetMsg()

		Select

			Case $hMsg = $GUI_EVENT_CLOSE
				GUIDelete($hGUI)
				Exit

			Case ProcessExists("Beat Saber.exe") and $hSocket = 0
				TraySetToolTip("Connecting...")
				If $sLocation <> StringReplace(_WinAPI_GetProcessFileName(ProcessExists("Beat Saber.exe")), "Beat Saber.exe", "") Then
					$sLocation = StringReplace(_WinAPI_GetProcessFileName(ProcessExists("Beat Saber.exe")), "Beat Saber.exe", "")
					_Log($sLocation, "Got " & $sLocation & " as Beat Saber install location")
				EndIf
				If Not FileExists($sLocation & "Plugins\DataPuller.dll") Then
					MsgBox($MB_OK+$MB_ICONERROR+$MB_TOPMOST, "DashPause", "The required plugin DataPuller was not found! DashPause will now close.")
					_Log($sLocation, "[FATAL] DataPuller was not found in " & $sLocation & "\Plugins")
					Exit 1
				EndIf
				Switch FileGetVersion($sLocation & "Plugins\DataPuller.dll", $FV_FILEVERSION)

					Case "0.0.1", "0.0.2", "0.0.3"
						_Log($sLocation, "Found DataPuller Version <= 0.0.3, Linking to 127.0.0.1/BSDataPuller")
						$hSocket = _StartListener("127.0.0.1", 2946, "/BSDataPuller")
						If $hSocket = 0 Then Sleep(5000)

					Case Else
						_Log($sLocation, "Found DataPuller Version >= 1.0, Linking to 127.0.0.1/BSDataPuller/LiveData")
						$hSocket = _StartListener("127.0.0.1", 2946, "/BSDataPuller/LiveData")
						If $hSocket = 0 Then Sleep(5000)

				EndSwitch
				If Not $hSocket Then
					TraySetToolTip("DashPause")
					ContinueLoop
				EndIf
				TraySetToolTip("Connected")
				$bRunning = True
				ConsoleWrite($sLocation & @CRLF)

			Case $hSocket = -1
				ContinueCase

			Case $hSocket <> 0 And Not ProcessExists("Beat Saber.exe")
				TraySetToolTip("Disconnecting...")
				_Log($sLocation, "Shutting down with Beat Saber")
				_StopListener($hSocket)
				TraySetToolTip("Disconnected")
				$bRunning = False
				$hSocket = 0
				_LogClose($hLogHandle)
				Exit

			Case $bRunning
				$sData =  _ReceiveData($hSocket, $iTimeout)
				Switch $sData
					Case -1
						$hSocket = -1
						ContinueLoop
					Case 0
						ContinueLoop
					Case Else
						If $bDev Then GUICtrlSetData($hData, $sData)
						$bInLevel = _StringBetween($sData, '"InLevel": ', ",")[0]
						$bLevelPaused = _StringBetween($sData, '"LevelPaused": ', ",")[0]
						If $bInLevel = "true" And $bLevelPaused = "false" Then
							If Not $bSuspended Then
								ConsoleWrite("Suspending" & @CRLF)
								_ProcessSuspend("Cortanalistenui.exe") ; WMR
								_ProcessSuspend("DesktopView.exe") ; WMR
								_ProcessSuspend("EnvironmentsApp.exe") ; WMR
								_ProcessSuspend("OculusDash.exe") ; Oculus
								_ProcessSuspend("VRCompositor.exe") ; SteamVR
								_ProcessSuspend("VRDashboard.exe") ; SteamVR
								_ProcessSuspend("VRServer.exe") ; SteamVR
								$bSuspended = True
							EndIf
						ElseIf $bInLevel = "false" Then
							If $bSuspended Then
								ConsoleWrite("Resuming" & @CRLF)
								_ProcessResume("Cortanalistenui.exe") ; WMR
								_ProcessResume("DesktopView.exe") ; WMR
								_ProcessResume("EnvironmentsApp.exe") ; WMR
								_ProcessResume("OculusDash.exe") ; Oculus
								_ProcessResume("VRCompositor.exe") ; SteamVR
								_ProcessResume("VRDashboard.exe") ; SteamVR
								_ProcessResume("VRServer.exe") ; SteamVR
								$bSuspended = False
							EndIf
						EndIf
				EndSwitch

			Case Else
				;;;

		EndSelect

	WEnd

EndFunc

Func _LogClose($hLogHandle)
	If Not $hLogHandle = "" Then FileClose($hLogHandle)
EndFunc

Func _LogOpen($sLocation)

	Select

		Case Not FileExists($sLocation & "\Logs\BS-DashPause")
			If Not DirCreate($sLocation & "\Logs\BS-DashPause") Then
				MsgBox($MB_OK+$MB_ICONERROR+$MB_TOPMOST, "DashPause", "DashPause is unable to create a log file directory and will not log diagnostic data.")
				Return False
			EndIf
			ContinueCase

		Case Not FileExists($sLocation & "\Logs\BS-DashPause\latest.log")
			Local $hLogHandle = FileOpen($sLocation & "\Logs\BS-DashPause\latest.log", $FO_APPEND+$FO_CREATEPATH)
			If $hLogHandle = -1 Then
				MsgBox($MB_OK+$MB_ICONERROR+$MB_TOPMOST, "DashPause", "DashPause is unable to create a log file and will not log diagnostic data.")
				Return False
			EndIf

		Case Else
			$hLogHandle = FileOpen($sLocation & "\Logs\BS-DashPause\latest.log", $FO_APPEND)
			If $hLogHandle = -1 Then
				MsgBox($MB_OK+$MB_ICONERROR+$MB_TOPMOST, "DashPause", "DashPause is unable to open its' log file and will not log diagnostic data.")
				Return False
			EndIf

	EndSelect

	Return $hLogHandle

EndFunc

Func _Log($sLocation, $sMessage)

	Static Local $hLogHandle = _LogOpen($sLocation)

	If $hLogHandle = 0 Then Return False

	If Not FileWrite($hLogHandle, @YEAR & @MON & @MDAY & "@" & @HOUR & @MIN & @SEC & ": " & $sMessage & @CRLF) Then
		MsgBox($MB_OK+$MB_ICONERROR+$MB_TOPMOST, "DashPause", "DashPause is unable to write to its' log file and will not log diagnostic data.")
		_LogClose($hLogHandle)
		Return False
	Else
		FileFlush($hLogHandle)
		Return $hLogHandle
	EndIf

EndFunc

Func _ProcessSuspend($sProcess)
	$iPID = ProcessExists($sProcess)
	If $iPID Then
		$ai_Handle = DllCall("kernel32.dll", 'int', 'OpenProcess', 'int', 0x1f0fff, 'int', False, 'int', $iPID)
		$i_success = DllCall("ntdll.dll","int","NtSuspendProcess","int",$ai_Handle[0])
		DllCall('kernel32.dll', 'ptr', 'CloseHandle', 'ptr', $ai_Handle)
		If IsArray($i_success) Then
			Return 1
		Else
			SetError(1)
			Return 0
		Endif
	Else
		SetError(2)
		Return 0
	EndIf
EndFunc

Func _ProcessResume($sProcess)
	$iPID = ProcessExists($sProcess)
	If $iPID Then
		$ai_Handle = DllCall("kernel32.dll", 'int', 'OpenProcess', 'int', 0x1f0fff, 'int', False, 'int', $iPID)
		$i_success = DllCall("ntdll.dll","int","NtResumeProcess","int",$ai_Handle[0])
		DllCall('kernel32.dll', 'ptr', 'CloseHandle', 'ptr', $ai_Handle)
		If IsArray($i_success) Then
			Return 1
		Else
			SetError(1)
			Return 0
		Endif
	Else
		SetError(2)
		Return 0
	EndIf
EndFunc

Func _ReceiveData($hWebSocket, $iTimeout)

	Local $hTimer = TimerInit()

	Local Const $WINHTTP_WEB_SOCKET_BINARY_MESSAGE_BUFFER_TYPE = 0
	Local Const $WINHTTP_WEB_SOCKET_BINARY_FRAGMENT_BUFFER_TYPE = 1
	Local Const $WINHTTP_WEB_SOCKET_UTF8_MESSAGE_BUFFER_TYPE = 2
	Local Const $WINHTTP_WEB_SOCKET_UTF8_FRAGMENT_BUFFER_TYPE = 3

	Local Const $ERROR_NOT_ENOUGH_MEMORY = 8
	Local Const $ERROR_INVALID_PARAMETER = 87

    Local $iBufferLen = 1024
    Local $tBuffer = 0, $bRecv = Binary("")

    Local $iBytesRead = 0, $iBufferType = 3
    Do
        If $iBufferLen = 0 Then
            $iError = $ERROR_NOT_ENOUGH_MEMORY
            Return False
        EndIf

        $tBuffer = DllStructCreate("byte[" & $iBufferLen & "]")

        $iError = _WinHttpWebSocketReceive($hWebSocket, _
                $tBuffer, _
                $iBytesRead, _
                $iBufferType)
        If @error Or $iError <> 0 Then
			If $iError = $ERROR_WINHTTP_CONNECTION_ERROR Then
				_Log($sLocation, "Socket Closed. Shutting down.")
				Return -1
			Else
				_Log($sLocation, "[ERROR] Unable to Receive data from WebSocket: " & @error & " - " & @extended & " - " & $iError)
				Return False
			EndIf
        EndIf

        ; Continue if not complete
        $bRecv &= BinaryMid(DllStructGetData($tBuffer, 1), 1, $iBytesRead)
        $tBuffer = 0

        $iBufferLen -= $iBytesRead
		;If TimerDiff($hTimer) > $iTimeout Then Return False
    Until $iBufferType <> $WINHTTP_WEB_SOCKET_UTF8_FRAGMENT_BUFFER_TYPE

    ; We expected server just to echo single binary message.

    If $iBufferType <> $WINHTTP_WEB_SOCKET_UTF8_MESSAGE_BUFFER_TYPE Then
		_Log($sLocation, "[ERROR] Unexpected buffer type from WebSocket")
        $iError = $ERROR_INVALID_PARAMETER
        Return False
    EndIf

	Return _HexToString($bRecv)

EndFunc

Func _SendData($hWebSocket, $sData) ; Why are you using this <_<

	Local Const $WINHTTP_WEB_SOCKET_BINARY_MESSAGE_BUFFER_TYPE = 0

    $iError = _WinHttpWebSocketSend($hWebSocket, _
		$WINHTTP_WEB_SOCKET_BINARY_MESSAGE_BUFFER_TYPE, _
		$sData)
    If @error Or $iError <> 0 Then
        _Log($sLocation, "[ERROR] Unable to send requested data to WebSocket")
        Return False
    EndIf
	Return True
EndFunc

Func _StartListener($sIP = "127.0.0.1", $iPort = 1337, $sPath = "")

	Local Const $WINHTTP_OPTION_UPGRADE_TO_WEB_SOCKET = 114

    $hOpen = _WinHttpOpen("DashPause " & $sVer, $WINHTTP_ACCESS_TYPE_DEFAULT_PROXY)
    If $hOpen = 0 Then
        $iError = _WinAPI_GetLastError()
        _Log($sLocation, "[ERROR] Unable to Open a Connection")
        Return False
    EndIf

    $hConnect = _WinHttpConnect($hOpen, $sIP, $iPort)
    If $hConnect = 0 Then
        $iError = _WinAPI_GetLastError()
        _Log($sLocation, "[ERROR] Unable to Connect to " & $sIP & ":" & $iPort)
        Return False
    EndIf

    $hRequest = _WinHttpOpenRequest($hConnect, "GET", $sPath, "")
    If $hRequest = 0 Then
        $iError = _WinAPI_GetLastError()
        _Log($sLocation, "[ERROR] Error Getting data from " & $sIP & ":" & $iPort)
        Return False
    EndIf

    ; Request protocol upgrade from http to websocket.

    Local $fStatus = _WinHttpSetOptionNoParams($hRequest, $WINHTTP_OPTION_UPGRADE_TO_WEB_SOCKET)
    If Not $fStatus Then
        $iError = _WinAPI_GetLastError()
        _Log($sLocation, "[ERROR] Error Preparing upgrade from TCP to WebSocket")
        Return False
    EndIf

    ; Perform websocket handshake by sending a request and receiving server's response.
    ; Application may specify additional headers if needed.

    $fStatus = _WinHttpSendRequest($hRequest)
    If Not $fStatus Then
        $iError = _WinAPI_GetLastError()
        _Log($sLocation, "[ERROR] Unable to Start WebSocket handshake")
        Return False
    EndIf

    $fStatus = _WinHttpReceiveResponse($hRequest)
    If Not $fStatus Then
        $iError = _WinAPI_GetLastError()
        _Log($sLocation, "[ERROR] Unable to Complete WebSocket handshake")
        Return False
    EndIf

    ; Application should check what is the HTTP status code returned by the server and behave accordingly.
    ; WinHttpWebSocketCompleteUpgrade will fail if the HTTP status code is different than 101.


    $hWebSocket = _WinHttpWebSocketCompleteUpgrade($hRequest, 0)
    If $hWebSocket = 0 Then
        $iError = _WinAPI_GetLastError()
        _Log($sLocation, "[ERROR] Unable to Upgrade from TCP to WebSocket")
        Return False
    EndIf

    _WinHttpCloseHandle($hRequest)
    $hRequestHandle = 0

    _Log($sLocation, "Succesfully Connected and Upgraded to WebSocket")
	Return $hWebSocket
EndFunc

Func _StopListener($hWebSocket)

	Local Const $WINHTTP_WEB_SOCKET_SUCCESS_CLOSE_STATUS = 1000

    $iError = _WinHttpWebSocketClose($hWebSocket, _
            $WINHTTP_WEB_SOCKET_SUCCESS_CLOSE_STATUS)
    If @error Or $iError <> 0 Then
        _Log($sLocation, "[ERROR] Unable to Close WebSocket")
        Return False
    EndIf

    ; Check close status returned by the server.

    Local $iStatus = 0, $iReasonLengthConsumed = 0
    Local $tCloseReasonBuffer = DllStructCreate("byte[123]")

    $iError = _WinHttpWebSocketQueryCloseStatus($hWebSocket, _
            $iStatus, _
            $iReasonLengthConsumed, _
            $tCloseReasonBuffer)
    If @error Or $iError <> 0 Then
        _Log($sLocation, "[ERROR] Unable to Check status of WebSocket closure")
        Return False
    EndIf

    ConsoleWrite("The server closed the connection with status code: '" & $iStatus & "' and reason: '" & _
		BinaryToString(BinaryMid(DllStructGetData($tCloseReasonBuffer, 1), 1, $iReasonLengthConsumed)) & "'" & @CRLF)
EndFunc

Func _WinHttpSetOptionNoParams($hInternet, $iOption)
    Local $aCall = DllCall($hWINHTTPDLL__WINHTTP, "bool", "WinHttpSetOption", _
            "handle", $hInternet, "dword", $iOption, "ptr", 0, "dword", 0)
    If @error Or Not $aCall[0] Then Return SetError(4, 0, 0)
    Return 1
EndFunc   ;==>_WinHttpSetOptionNoParams

Func _WinHttpWebSocketCompleteUpgrade($hRequest, $pContext = 0)
    Local $aCall = DllCall($hWINHTTPDLL__WINHTTP, "handle", "WinHttpWebSocketCompleteUpgrade", _
            "handle", $hRequest, _
            "DWORD_PTR", $pContext)
    If @error Then Return SetError(@error, @extended, -1)
    Return $aCall[0]
EndFunc   ;==>_WinHttpWebSocketCompleteUpgrade

Func _WinHttpWebSocketSend($hWebSocket, $iBufferType, $vData)
    Local $tBuffer = 0, $iBufferLen = 0
    If IsBinary($vData) = 0 Then $vData = StringToBinary($vData)
    $iBufferLen = BinaryLen($vData)
    If $iBufferLen > 0 Then
        $tBuffer = DllStructCreate("byte[" & $iBufferLen & "]")
        DllStructSetData($tBuffer, 1, $vData)
    EndIf

    Local $aCall = DllCall($hWINHTTPDLL__WINHTTP, "DWORD", "WinHttpWebSocketSend", _
            "handle", $hWebSocket, _
            "int", $iBufferType, _
            "ptr", DllStructGetPtr($tBuffer), _
            "DWORD", $iBufferLen)
    If @error Then Return SetError(@error, @extended, -1)
    Return $aCall[0]
EndFunc   ;==>_WinHttpWebSocketSend

Func _WinHttpWebSocketReceive($hWebSocket, $tBuffer, ByRef $iBytesRead, ByRef $iBufferType)
    Local $aCall = DllCall($hWINHTTPDLL__WINHTTP, "handle", "WinHttpWebSocketReceive", _
            "handle", $hWebSocket, _
            "ptr", DllStructGetPtr($tBuffer), _
            "DWORD", DllStructGetSize($tBuffer), _
            "DWORD*", $iBytesRead, _
            "int*", $iBufferType)
    If @error Then Return SetError(@error, @extended, -1)
    $iBytesRead = $aCall[4]
    $iBufferType = $aCall[5]
    Return $aCall[0]
EndFunc   ;==>_WinHttpWebSocketReceive

Func _WinHttpWebSocketClose($hWebSocket, $iStatus, $tReason = 0)
    Local $aCall = DllCall($hWINHTTPDLL__WINHTTP, "handle", "WinHttpWebSocketClose", _
            "handle", $hWebSocket, _
            "USHORT", $iStatus, _
            "ptr", DllStructGetPtr($tReason), _
            "DWORD", DllStructGetSize($tReason))
    If @error Then Return SetError(@error, @extended, -1)
    Return $aCall[0]
EndFunc   ;==>_WinHttpWebSocketClose

Func _WinHttpWebSocketQueryCloseStatus($hWebSocket, ByRef $iStatus, ByRef $iReasonLengthConsumed, $tCloseReasonBuffer = 0)
    Local $aCall = DllCall($hWINHTTPDLL__WINHTTP, "handle", "WinHttpWebSocketQueryCloseStatus", _
            "handle", $hWebSocket, _
            "USHORT*", $iStatus, _
            "ptr", DllStructGetPtr($tCloseReasonBuffer), _
            "DWORD", DllStructGetSize($tCloseReasonBuffer), _
            "DWORD*", $iReasonLengthConsumed)
    If @error Then Return SetError(@error, @extended, -1)
    $iStatus = $aCall[2]
    $iReasonLengthConsumed = $aCall[5]
    Return $aCall[0]
EndFunc   ;==>_WinHttpWebSocketQueryCloseStatus