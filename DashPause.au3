#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Version=Beta
#AutoIt3Wrapper_Icon=icon.ico
#AutoIt3Wrapper_Compile_Both=y
#AutoIt3Wrapper_UseX64=y
#AutoIt3Wrapper_Res_Comment=Compiled 8/18/2020 @ 9:50 EST
#AutoIt3Wrapper_Res_Description=Beat Saber Dash Pause
#AutoIt3Wrapper_Res_Fileversion=0.1.0.0
#AutoIt3Wrapper_Res_LegalCopyright=Robert Maehl, using LGPL 3 License
#AutoIt3Wrapper_Res_Language=1033
#AutoIt3Wrapper_Res_requestedExecutionLevel=asInvoker
#AutoIt3Wrapper_Run_Au3Stripper=y
#Au3Stripper_Parameters=/pe /so
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****
#include "WinHTTP.au3"

#include <WinAPI.au3> ; _WinAPI_GetLastError
#include <String.au3> ; _HexToString
#include <EditConstants.au3>
#include <GUIConstantsEx.au3>
#include <WindowsConstants.au3>

Main()

Func Main()

	Local $bDev = False
	Local $sData = ""
	Local $hSocket = 0
	Local $iTimeout = 500
	Local $bRunning = False
	Local $bSuspended = False

	Local $bInLevel = False
	Local $bLevelPaused = False

	If $bDev Then
		Local $hGUI = GUICreate("Dash Pause", 640, 480, -1, -1, BitOr($WS_MINIMIZEBOX, $WS_CAPTION, $WS_SYSMENU))
		Local $hData = GUICtrlCreateEdit("", 0, 20, 640, 460, BitOR($ES_MULTILINE, $WS_VSCROLL, $ES_AUTOVSCROLL, $ES_READONLY))
		GUISetState(@SW_SHOW, $hGUI)
	EndIf

	While 1

		$hMsg = GUIGetMsg()

		Select

			Case $hMsg = $GUI_EVENT_CLOSE
				GUIDelete($hGUI)
				TCPShutdown()
				Exit

			Case ProcessExists("Beat Saber.exe") and $hSocket = 0
				TraySetToolTip("Connecting...")
				$hSocket = _StartListener("127.0.0.1", 2946, "/BSDataPuller")
				TraySetToolTip("Connected")
				$bRunning = True

			Case $hSocket <> 0 And Not ProcessExists("Beat Saber.exe")
				TraySetToolTip("Disconnecting...")
				_StopListener($hSocket)
				TraySetToolTip("Disconnected")
				$bRunning = False
				$hSocket = 0

			Case $bRunning
				$sData =  _GetData($hSocket, $iTimeout)
				If $bDev Then GUICtrlSetData($hData, $sData)
				$bInLevel = _StringBetween($sData, '"InLevel": ', ",")[0]
				$bLevelPaused = _StringBetween($sData, '"LevelPaused": ', ",")[0]
				If $bInLevel = "true" And $bLevelPaused = "false" Then
					If Not $bSuspended Then
						ConsoleWrite("Suspending" & @CRLF)
						_ProcessSuspend("OculusDash.exe")
						_ProcessSuspend("VRDashboard.exe")
						$bSuspended = True
					EndIf
				ElseIf $bInLevel = "false" Then
					If $bSuspended Then
						ConsoleWrite("Resuming" & @CRLF)
						_ProcessResume("OculusDash.exe")
						_ProcessResume("VRDashboard.exe")
						$bSuspended = False
					EndIf
				EndIf

			Case Else
				;;;

		EndSelect

	WEnd

EndFunc

Func _GetData($hWebSocket, $iTimeout)

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
            ConsoleWrite("WebSocketReceive error" & @CRLF)
            Return False
        EndIf

        ; If we receive just part of the message restart the receive operation.

        $bRecv &= BinaryMid(DllStructGetData($tBuffer, 1), 1, $iBytesRead)
        $tBuffer = 0

        $iBufferLen -= $iBytesRead
		;If TimerDiff($hTimer) > $iTimeout Then Return False
    Until $iBufferType <> $WINHTTP_WEB_SOCKET_UTF8_FRAGMENT_BUFFER_TYPE

    ; We expected server just to echo single binary message.

    If $iBufferType <> $WINHTTP_WEB_SOCKET_UTF8_MESSAGE_BUFFER_TYPE Then
        ConsoleWrite("Unexpected buffer type" & @CRLF)
        $iError = $ERROR_INVALID_PARAMETER
        Return False
    EndIf

	Return _HexToString($bRecv)

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

Func _SendData($hWebSocket, $sData) ; Why are you using this <_<

	Local Const $WINHTTP_WEB_SOCKET_BINARY_MESSAGE_BUFFER_TYPE = 0

    $iError = _WinHttpWebSocketSend($hWebSocket, _
		$WINHTTP_WEB_SOCKET_BINARY_MESSAGE_BUFFER_TYPE, _
		$sData)
    If @error Or $iError <> 0 Then
        ConsoleWrite("WebSocketSend error" & @CRLF)
        Return False
    EndIf
	Return True
EndFunc

Func _StartListener($sIP = "127.0.0.1", $iPort = 1337, $sPath = "")

	Local Const $WINHTTP_OPTION_UPGRADE_TO_WEB_SOCKET = 114

    $hOpen = _WinHttpOpen("DashPause 0.1", $WINHTTP_ACCESS_TYPE_DEFAULT_PROXY)
    If $hOpen = 0 Then
        $iError = _WinAPI_GetLastError()
        ConsoleWrite("Open error" & @CRLF)
        Return False
    EndIf

    $hConnect = _WinHttpConnect($hOpen, $sIP, $iPort)
    If $hConnect = 0 Then
        $iError = _WinAPI_GetLastError()
        ConsoleWrite("Connect error" & @CRLF)
        Return False
    EndIf

    $hRequest = _WinHttpOpenRequest($hConnect, "GET", $sPath, "")
    If $hRequest = 0 Then
        $iError = _WinAPI_GetLastError()
        ConsoleWrite("OpenRequest error" & @CRLF)
        Return False
    EndIf

    ; Request protocol upgrade from http to websocket.

    Local $fStatus = _WinHttpSetOptionNoParams($hRequest, $WINHTTP_OPTION_UPGRADE_TO_WEB_SOCKET)
    If Not $fStatus Then
        $iError = _WinAPI_GetLastError()
        ConsoleWrite("SetOption error" & @CRLF)
        Return False
    EndIf

    ; Perform websocket handshake by sending a request and receiving server's response.
    ; Application may specify additional headers if needed.

    $fStatus = _WinHttpSendRequest($hRequest)
    If Not $fStatus Then
        $iError = _WinAPI_GetLastError()
        ConsoleWrite("SendRequest error" & @CRLF)
        Return False
    EndIf

    $fStatus = _WinHttpReceiveResponse($hRequest)
    If Not $fStatus Then
        $iError = _WinAPI_GetLastError()
        ConsoleWrite("SendRequest error" & @CRLF)
        Return False
    EndIf

    ; Application should check what is the HTTP status code returned by the server and behave accordingly.
    ; WinHttpWebSocketCompleteUpgrade will fail if the HTTP status code is different than 101.

    $hWebSocket = _WinHttpWebSocketCompleteUpgrade($hRequest, 0)
    If $hWebSocket = 0 Then
        $iError = _WinAPI_GetLastError()
        ConsoleWrite("WebSocketCompleteUpgrade error" & @CRLF)
        Return False
    EndIf

    _WinHttpCloseHandle($hRequest)
    $hRequestHandle = 0

    ConsoleWrite("Succesfully upgraded to websocket protocol" & @CRLF)
	Return $hWebSocket
EndFunc

Func _StopListener($hWebSocket)

	Local Const $WINHTTP_WEB_SOCKET_SUCCESS_CLOSE_STATUS = 1000

    $iError = _WinHttpWebSocketClose($hWebSocket, _
            $WINHTTP_WEB_SOCKET_SUCCESS_CLOSE_STATUS)
    If @error Or $iError <> 0 Then
        ConsoleWrite("WebSocketClose error" & @CRLF)
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
        ConsoleWrite("QueryCloseStatus error" & @CRLF)
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