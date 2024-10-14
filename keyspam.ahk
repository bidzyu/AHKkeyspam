#Persistent
#NoEnv
SendMode Input
SetBatchLines -1
ListLines Off

global PRESS_TICK_LIMIT := 30
global TIMER_FREQUENCY := 10
global KEYS_TO_REPEAT := { "1": "1", "2": "2", "3": "3", "4": "4", "e": "у", "r": "к", "q": "й", "c": "с", "x": "ч" }

global pressedKeysList := Array()
global pressDurationList := Array()
global keysPressStatus := false
global shouldReboot := false
global active := true

FillStuckKeysArray()
FillPressDurationArray()
SetTimer, AllChecks, %TIMER_FREQUENCY%
return

AllChecks() {
  if (active) {
    CheckReboot()

    if (shouldReboot) {
      Reboot()
      return
    }
  
    UdpKeyPressStatus()
    UpdAllPressedKeys()

    if (keysPressStatus) {
      CheckKeys()
    }
  }  
}

FillStuckKeysArray() { 
  index := 0

  for key, s in KEYS_TO_REPEAT {
    pressedKeysList[index] := key
    index += 1
  }
}

FillPressDurationArray() {
  for i, key in pressedKeysList {
    pressDurationList[i] := 0
  }
}

CheckReboot() {
  for i, key in pressDurationList {
    if (key >= PRESS_TICK_LIMIT) {
      shouldReboot := true
      return
    }
  }
}


UdpKeyPressStatus() {   
    for key, s in KEYS_TO_REPEAT {
        physical := GetKeyState(key, "P") ; Проверяем физическое состояние клавиши

        if (physical) {
	  keysPressStatus := true
	  return
	} 
    }
    
    keysPressStatus := false
    return
}


CheckKeys() {
    if (active) {
        ; Получаем текущую раскладку
        currentLayout := GetLayout("") == "ru"
        
        for key, symbol in KEYS_TO_REPEAT {
             if (GetKeyState(key, "P")) {
                 ; Проверяем состояние управляющих клавиш
                 ctrlState := GetKeyState("Control", "P") ? "^" : ""
                 altState := GetKeyState("Alt", "P") ? "!" : ""
                 shiftState := GetKeyState("Shift", "P") ? "+" : ""

                 ; Если раскладка русская, используем русский символ, иначе английский
                 combo := shiftState . ctrlState . altState . (currentLayout ? symbol : key)
                 ; Отправляем комбинацию клавиш
                 Send, %combo%
                 Sleep, %TIMER_FREQUENCY%
             }
        }
    }
    return
}

UpdAllPressedKeys() {
    ; keyStatus := "" ; Для хранения статуса клавиш
    
    for i, key in pressedKeysList {
	keyState := GetKeyState(key, "P") ; Проверяем физическое состояние клавиши
	if (keyState) {
          pressDurationList[i]++
        } else {
	  pressDurationList[i] := 0
        }

        ; keyStatus .= pressedKeysList[i] ": " pressDurationList[i] "`n" ; Добавляем информацию о состоянии клавиши
	
    }

    ; keyStatus .= "press: " keysPressStatus "`n"

    ; ToolTip, % "Key Status:`n" keyStatus ; Отображаем статус всех клавиш
    ; SetTimer, RemoveToolTip, 1000 ; Убираем ToolTip через 1 секунду
    return
}

Reboot() {
    Run, %A_ScriptFullPath%, , Hide  ; Запускаем скрипт в скрытом режиме
    ExitApp  ; Закрываем текущий экземпляр скрипта
    return
}

; Переключение состояния скрипта
toggleActive() {
    active := !active
    if (active) {
        CenteredToolTip("Spam On")
    } else {
        CenteredToolTip("Spam Off")
    }
}

; Горячая клавиша для запуска/остановки
Up:: toggleActive()

CenteredToolTip(text, duration = 999) {
    ToolTip, %text%, A_ScreenWidth/2, A_ScreenHeight/2
    SetTimer, RemoveToolTip, -%duration%
}

RemoveToolTip() {
    ToolTip
}

GetLayout(ByRef Language := "")
{
    hWnd := WinExist("A")
    ThreadID := DllCall("GetWindowThreadProcessId", "Ptr",hWnd, "Ptr",0)
    KLID := DllCall("GetKeyboardLayout", "Ptr",ThreadID, "Ptr")
    KLID := Format("0x{:x}", KLID)
    Lang := "0x" A_Language
    Locale := KLID & Lang
    Info := KeyboardInfo()
    return Info.Layout[Locale], Language := Info.Language[Locale]
}

KeyboardInfo()
{
    static Out := {}
    if Out.Count()
        return Out
    Layout := {}
    loop reg, HKLM\SYSTEM\CurrentControlSet\Control\Keyboard Layout\DosKeybCodes
    {
        RegRead Data
        Code := "0x" A_LoopRegName
        Layout[Code + 0] := Data
    }
    Language := {}
    loop reg, HKLM\SYSTEM\CurrentControlSet\Control\Keyboard Layouts, KVR
    {
        RegRead Data
        if ErrorLevel
            Name := "0x" A_LoopRegName
        else if (A_LoopRegName = "Layout Text")
            Language[Name + 0] := Data
    }
    return Out := { "Layout":Layout, "Language":Language }
}
