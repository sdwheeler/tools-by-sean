#Warn  ; Enable warnings to assist with detecting common errors.
#SingleInstance force
SendMode("Input")  ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir(A_ScriptDir)  ; Ensures a consistent starting directory.
SetTitleMatchMode("RegEx")

; -----------------------------------
; Window locations
; -----------------------------------
Apps3Mon := []
Apps3Mon.InsertAt( 1, { x: 1913, y: -360, w: 1215, h: 850, state: 1, name: "Inbox", tag: "ahk_class rctrl_renwnd32", id: 0} )
Apps3Mon.InsertAt( 2, { x: 1913, y: 277, w: 1215, h: 850, state: 1, name: "Calendar", tag: "Calendar - .* - Outlook", id: 0} )
Apps3Mon.InsertAt( 3, { x: 1913, y: 675, w: 1212, h: 843, state: 1, name: "swsamwa", tag: "ahk_exe olk.exe", id: 0} )
Apps3Mon.InsertAt( 4, { x: -7, y: 0, w: 1129, h: 631, state: 1, name: "WinTerm", tag: "ahk_exe WindowsTerminal.exe", id: 0} )
Apps3Mon.InsertAt( 5, { x: 285, y: 0, w: 1508, h: 1159, state: 1, name: "Edge", tag: "ahk_exe msedge.exe", id: 0} )
Apps3Mon.InsertAt( 6, { x: -7, y: 505, w: 1335, h: 652, state: 1, name: "Notetab", tag: "ahk_class TfrmNoteTab", id: 0} )

; -----------------------------------
; Functions
; -----------------------------------
FindMyWindows(&AppList)
{
    Loop AppList.Length
    {
        ;msgBox % Format("A - {1}:{2}", AppList[A_Index].tag,WinExist(AppList[A_Index].tag))
        ; check for WinText
        AppList[A_Index].id := WinExist(, AppList[A_Index].tag)
        if (AppList[A_Index].id = 0) {
            ; check for WinTitle
            AppList[A_Index].id := WinExist(AppList[A_Index].tag)
        }
    }
}

MoveMyWindows(AppList)
{
    Loop AppList.Length
    {
        id    := AppList[A_Index].id
        x     := AppList[A_Index].x
        y     := AppList[A_Index].y
        w     := AppList[A_Index].w
        h     := AppList[A_Index].h
        state := AppList[A_Index].state
        name  := AppList[A_Index].name
        if (id != 0)
        {
            WinActivate("ahk_id " id)
            WinMove(x, y, w, h, "ahk_id " id)
            if (state != 1)
            {
                WinMinimize("ahk_id " id)
            }
        }
    }
}

ListMyWindows(AppList)
{
    MyMessage := ""
    Loop AppList.Length
    {
        id    := AppList[A_Index].id
        x     := AppList[A_Index].x
        y     := AppList[A_Index].y
        w     := AppList[A_Index].w
        h     := AppList[A_Index].h
        state := AppList[A_Index].state
        tag   := AppList[A_Index].tag
        name  := AppList[A_Index].name
        MyMessage :=  MyMessage . Format("{6}[{7}] x={1} y={2} w={3} h={4} s={5}`r`n", x,y,w,h,state,name,id)
    }
    MsgBox(MyMessage, "Window List", 0)
}

GetWindow(AppList, WinId)
{
    Loop AppList.Length
    {
        id    := AppList[A_Index].id
        x     := AppList[A_Index].x
        y     := AppList[A_Index].y
        w     := AppList[A_Index].w
        h     := AppList[A_Index].h
        state := AppList[A_Index].state
        name  := AppList[A_Index].name
        if (WinId = id)
        {
            MsgBox(Format("x={1} y={2} w={3} h={4} s={5}", x, y, w, h, state), name " " id, 0)
        }
    }
}

MoveOneWindow(AppList, WinId)
{
    Loop AppList.Length
    {
        id    := AppList[A_Index].id
        x     := AppList[A_Index].x
        y     := AppList[A_Index].y
        w     := AppList[A_Index].w
        h     := AppList[A_Index].h
        state := AppList[A_Index].state
        name  := AppList[A_Index].name
        if (WinId = id)
        {
            WinActivate("ahk_id " id)
            if (name = "PowerShell") {
                WinMove(x, y, , , "ahk_id " id)
            } else {
                WinMove(x, y, w, h, "ahk_id " id)
            }
            if (state != 1)
            {
                WinMinimize("ahk_id " id)
            }
        }
    }
}

; -----------------------------------
;            Key Mappings
; -----------------------------------
; Arrange current window
; -----------------------------------
;Win+Alt+Home - move window under mouse to 0,0
#!Home::
{
    global
    MouseGetPos(, , &MouseWin)
    WinMove(0, 0, , , "ahk_id " MouseWin)
    return
}

;Win+Alt+4 - move window under mouse to it's position
#!4::
{
    global
    MouseGetPos(&xpos, &ypos, &MouseWin)
    FindMyWindows(&Apps3Mon)
    MoveOneWindow(Apps3Mon, MouseWin)
    return
}

;Win+Alt+y
#!y::
{
    global
    MouseGetPos(, , &MouseWin)
    WinMove(-1208, 1107, 1215, 790, "ahk_id " MouseWin)
    return
}

;Win+Alt+- - move window under mouse to it's position
#!-::
{
    global
    MouseGetPos(&xpos, &ypos, &MouseWin)
    ; Msgbox, Move to (162-%xpos%) (12-%ypos%).
    MouseMove(162 - xpos, 12 - ypos, 2, "R")
    MouseClick()
    MouseGetPos(, , &MouseWin)
    FindMyWindows(&Apps3Mon)
    MoveOneWindow(Apps3Mon, MouseWin)
    return
}

PrintScreen::
{
    global
    Send("#S")
    return
}

;Win+z - Shutdown
#z::
{
    global
    Send("#x")
    Send("u")
    Send("u")
    return
}

;Win+Alt+.
#!.::
{
    global
    WinActivate("ahk_exe msedge.exe")
    WinMove(285, 0, 1200, 950, "ahk_exe msedge.exe")
return
}

; -----------------------------------
; Arrange all windows
; -----------------------------------
; Win+Alt+3 - 3 monitor setup
#!3::
{
    global
    FindMyWindows(&Apps3Mon)
    MoveMyWindows(Apps3Mon)
    return
}

; -----------------------------------
; Map keys to functions
; -----------------------------------
; Win+Alt+l - List Windows
#!l::
{
    global
    FindMyWindows(&Apps3Mon)
    ListMyWindows(Apps3Mon)
    return
}

; Win+Alt+i - List current window
#!i::
{
    global
    MouseGetPos(, , &MouseWin)
    FindMyWindows(&Apps3Mon)
    GetWindow(Apps3Mon, MouseWin)
    return
}

; -----------------------------------
; Content macros
; -----------------------------------
; Alt+Win+d
!#d::
{
    global
    Date := A_Now
    nDate := FormatTime(Date, "MM/dd/yyyy")
    Send(nDate)
    Return
}