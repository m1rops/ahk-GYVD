#SingleInstance Force
#NoEnv
SetWorkingDir %A_ScriptDir%
SetBatchLines -1

; --- НАСТРОЙКИ АВТООБНОВЛЕНИЯ ---
Global ScriptVersion := "1.2"
GH_Host := "https://raw." . "githubusercontent.com"
GH_Path := "/m1rops/ahk-GYVD/refs/heads/main/"
Global ScriptUpdateURL := GH_Host . GH_Path . "script.ahk"
Global UpdateURL := GH_Host . GH_Path . "config.ini"


ConfigFile := A_ScriptDir "\config.ini"
UserSettingsFile := A_ScriptDir "\user_settings.ini"

; --- ЗАГРУЗКА ЛИЧНЫХ ДАННЫХ ---
if !FileExist(UserSettingsFile) {
    IniWrite, Капитан Михайлов, %UserSettingsFile%, Profile, Rang
    IniWrite, Начальник УГАИ, %UserSettingsFile%, Profile, Doljnost
    IniWrite, Михайлов, %UserSettingsFile%, Profile, Familiya
}
IniRead, Rang, %UserSettingsFile%, Profile, Rang, Капитан Михайлов
IniRead, Doljnost, %UserSettingsFile%, Profile, Doljnost, Начальник УГАИ
IniRead, Familiya, %UserSettingsFile%, Profile, Familiya, Михайлов

Global CurrentSearchSource := ""
Global BtnMap := {}
Global LastHoveredHwnd := 0
Global ManualUpdateCheck := false

; --- ТЕКСТЫ ПО УМОЛЧАНИЮ ---
KoapText := "Информация КоАП не загружена"
UkText := "Информация УК не загружена"
MainArticles_GAI := "Основные статьи КоАП/УК ГАИ не загружены"
OrientText := "Ориентировки не загружены"
GunText := "Оффлайн информация:`nСотрудник органов внутренних дел имеет право на применение оружия, то есть на производство выстрела (выстрелов) из него, в отношении лица:`n1. Совершающего нападение на сотрудника органов внутренних дел и (или) иного гражданина, когда их жизнь или здоровье подвергаются опасности;`n2. Совершающего нападение в составе группы или нападение, сопряженное с применением оружия либо взрывов, поджогов и иных общеопасных способов, использованием транспортных средств, машин или механизмов, на жилые помещения или иные законные владения граждан, помещения, иные объекты организаций, войсковой или служебный наряд органов внутренних дел, на лиц или объекты, охраняемые органами внутренних дел;`n3. Совершающего действие, непосредственно направленное на насильственное завладение находящимися у сотрудника органов внутренних дел оружием, боеприпасами к нему, боевой и специальной техникой или специальными средствами;`n4. Совершающего захват или удержание лица в качестве заложника;`n5. Застигнутого при совершении действий, указанных в абзацах втором–пятом настоящей части, и пытающегося скрыться;`n6. Совершающего побег из-под стражи, конвоя;`n7. Не подчинившегося законному требованию сотрудника органов внутренних дел немедленно сдать (положить) оружие, взрывчатое вещество, взрывное устройство или другие предметы, применение которых может угрожать жизни или здоровью сотрудника органов внутренних дел или иных граждан."

; --- ОБРАБОТЧИКИ СОБЫТИЙ ОКНА ---
OnMessage(0x200, "OnMouseMove")
OnMessage(0x138, "OnCtlColorStatic")

; --- СТАРТ ОБНОВЛЕНИЙ И ИНФОРМАЦИОННОЕ ОКНО ---
GoSub, CheckFullUpdate
SetTimer, CheckFullUpdate, 300000

Gui, StartInfo:New, +AlwaysOnTop +Owner -Caption +Border
Gui, StartInfo:Color, F3F4F6
Gui, StartInfo:Font, s10 Bold c1E293B, Segoe UI
Gui, StartInfo:Add, Text, x10 y12 w250 center, СКРИПТ УГАИ ЗАПУЩЕН
Gui, StartInfo:Add, Text, x10 y38 w250 center c0284C7, Нажмите F9 для законки
Gui, StartInfo:Show, xCenter yCenter w270 h70
SetTimer, DestroyStartInfo, -2500
Return

DestroyStartInfo:
{
    Gui, StartInfo:Destroy
    Return
}

; --- ОБНОВЛЕНИЕ БЕЗ КЭША ---
ManualCheckUpdate:
{
    ManualUpdateCheck := true
    GoSub, CheckFullUpdate
    Return
}

CheckFullUpdate:
{
    ScriptChecked := false
    ConfigUpdated := false
    NoCache := "?nocache=" . A_TickCount

    if (!A_IsCompiled) {
        TempScript := A_Temp "\gyvd_update_temp.ahk"
        DllCall("wininet\DeleteUrlCacheEntry", "Str", ScriptUpdateURL)
        UrlDownloadToFile, % ScriptUpdateURL . NoCache, %TempScript%
        
        if (!ErrorLevel && FileExist(TempScript)) {
            FileEncoding, UTF-8
            FileRead, RemoteCode, %TempScript%
            
            if RegExMatch(RemoteCode, "i)Global\s+ScriptVersion\s*:=\s*""([^""]+)""", MatchVer) {
                ScriptChecked := true
                RemoteVersion := MatchVer1
                if (RemoteVersion != "" && RemoteVersion != ScriptVersion) {
                    FileDelete, %A_ScriptFullPath%
                    FileAppend, %RemoteCode%, %A_ScriptFullPath%, UTF-8
                    FileDelete, %TempScript%
                    
                    MsgBox, 64, Автообновление, Скрипт успешно обновлен до версии %RemoteVersion%!`nСейчас произойдет перезапуск., 3
                    Reload
                    ExitApp
                }
            }
            FileDelete, %TempScript%
        }
    }

    DllCall("wininet\DeleteUrlCacheEntry", "Str", UpdateURL)
    UrlDownloadToFile, % UpdateURL . NoCache, %ConfigFile%
    
    if (!ErrorLevel && FileExist(ConfigFile)) {
        FileEncoding, UTF-8
        FileRead, IniContent, %ConfigFile%
        
        if (IniContent != "" && !InStr(IniContent, "404: Not Found")) {
            ConfigUpdated := true
            RegExMatch(IniContent, "i)Koap\s*=\s*([^\r\n]*)", MatchKoap)
            RegExMatch(IniContent, "i)Uk\s*=\s*([^\r\n]*)", MatchUk)
            RegExMatch(IniContent, "i)MainArticlesGAI\s*=\s*([^\r\n]*)", MatchMainGAI)
            RegExMatch(IniContent, "i)Orient\s*=\s*([^\r\n]*)", MatchOrient)
            RegExMatch(IniContent, "i)Gun\s*=\s*([^\r\n]*)", MatchGun)
            
            if (MatchKoap1 != "")
                KoapText := StrReplace(MatchKoap1, "\n", "`n")
            if (MatchUk1 != "")
                UkText := StrReplace(MatchUk1, "\n", "`n")
            if (MatchMainGAI1 != "")
                MainArticles_GAI := StrReplace(MatchMainGAI1, "\n", "`n")
            if (MatchOrient1 != "")
                OrientText := StrReplace(MatchOrient1, "\n", "`n")
            if (MatchGun1 != "")
                GunText := StrReplace(MatchGun1, "\n", "`n")
        }
    }

    if (ManualUpdateCheck) {
        ManualUpdateCheck := false
        if (ScriptChecked || ConfigUpdated) {
            StatusMsg := "Актуальная версия скрипта: v" . ScriptVersion
            if (ConfigUpdated)
                StatusMsg .= "`nБаза статей и ориентировок успешно обновлена!"
            MsgBox, 64, Проверка обновлений, %StatusMsg%
        } else {
            MsgBox, 48, Ошибка обновления, Не удалось подключиться к GitHub. Проверьте интернет-соединение.
        }
    }
    Return
}

; --- ПОДСКАЗКА БИНДОВ ---
!q::
{
    Gui, 2:Destroy    
    Gui, 2:+LastFound +AlwaysOnTop -Caption +ToolWindow +E0x20    
    Gui, 2:Color, EEAA99    
    Gui, 2:Font, s11 Bold, Segoe UI    
    
    Gui, 2:Add, Text, cYellow, БИНДЫ (v%ScriptVersion%)`n----------------------------------`nF1 - Представиться`nF2 - Требование остановки`nF3 - Разбить стекло`nF4 - Подножка`nF5 - Повалить`nF6 - Обыск`nF9 - Законка
    
    WinSet, TransColor, EEAA99  
    Gui, 2:Show, x10 y420 NoActivate
    
    SetTimer, HideOSD, -10000
    return
}

HideOSD:
{
    Gui, 2:Destroy
    return
}

; --- ГЛАВНОЕ МЕНЮ ЗАКОНКИ (СВЕТЛАЯ ТЕМА, ТОЛЬКО ГАИ) ---
F9::
{
    Gui, 1:Destroy
    CleanUpBrushes()
    BtnMap := {}
    LastHoveredHwnd := 0
    
    Gui, 1:+AlwaysOnTop
    Gui, 1:Color, F3F4F6
    Gui, 1:Font, s9 Bold c1E293B, Segoe UI
    
    ; Формат цветов BGR для светлой темы: Обычный, ПриНаведении, ЦветТекста
    AddSolidButton(1, 10, 10, 145, 50, "КоАП РБ", "ShowKoap", 0xFFFFFF, 0xE2E8F0, 0x1E293B, false)
    AddSolidButton(1, 165, 10, 145, 50, "УК РБ", "ShowUk", 0xFFFFFF, 0xE2E8F0, 0x1E293B, false)
    AddSolidButton(1, 10, 70, 145, 50, "Основные статьи`nКоАП/УК ГАИ", "ShowMainArticles", 0xFFFFFF, 0xE2E8F0, 0x1E293B, true)
    AddSolidButton(1, 165, 70, 145, 50, "Ориентировки", "ShowOrient", 0xFFFFFF, 0xE2E8F0, 0x1E293B, false)
    AddSolidButton(1, 10, 130, 300, 42, "Мануал использования оружия", "ShowGun", 0xFFFFFF, 0xE2E8F0, 0x1E293B, false)
    AddSolidButton(1, 10, 182, 145, 38, "Настройки профиля", "OpenProfileSettings", 0xF5E8DB, 0xEBCEB2, 0x1E293B, false)
    AddSolidButton(1, 165, 182, 145, 38, "Обновить базу/код", "ManualCheckUpdate", 0xE1F2E8, 0xC4E5D2, 0x1E293B, false)
    AddSolidButton(1, 10, 228, 300, 35, "ЗАКРЫТЬ", "CloseAllGUIs", 0xE2E2FC, 0xC7C7F9, 0x991B1B, false)
    
    Gui, 1:Show, w320 h273, Законка - ГАИ (v%ScriptVersion%)
    Return
}

; --- ОКНО НАСТРОЙКИ ПРОФИЛЯ (СВЕТЛАЯ ТЕМА) ---
OpenProfileSettings:
{
    Gui, ProfileGui:New, +AlwaysOnTop
    Gui, ProfileGui:Color, F3F4F6, FFFFFF
    Gui, ProfileGui:Font, s9 Bold c1E293B, Segoe UI
    
    Gui, ProfileGui:Add, Text, x15 y15 w270 c0284C7, Личные данные для отыгровок (F1, F6):
    
    Gui, ProfileGui:Add, Text, x15 y45 w270 c1E293B, Звание и фамилия (пример: Капитан Михайлов):
    Gui, ProfileGui:Add, Edit, x15 y65 w270 h24 c1E293B vInputRang, %Rang%
    
    Gui, ProfileGui:Add, Text, x15 y100 w270 c1E293B, Должность (пример: Начальник УГАИ):
    Gui, ProfileGui:Add, Edit, x15 y120 w270 h24 c1E293B vInputDoljnost, %Doljnost%
    
    Gui, ProfileGui:Add, Text, x15 y155 w270 c1E293B, Фамилия для /do (пример: Михайлов):
    Gui, ProfileGui:Add, Edit, x15 y175 w270 h24 c1E293B vInputFamiliya, %Familiya%
    
    Gui, ProfileGui:Add, Button, x15 y215 w130 h32 gSaveProfileSettings, СОХРАНИТЬ
    Gui, ProfileGui:Add, Button, x155 y215 w130 h32 gProfileGuiGuiClose, ОТМЕНА
    
    Gui, ProfileGui:Show, w300 h260, Настройки профиля
    Return
}

SaveProfileSettings:
{
    Gui, ProfileGui:Submit
    if (InputRang != "")
        Rang := InputRang
    if (InputDoljnost != "")
        Doljnost := InputDoljnost
    if (InputFamiliya != "")
        Familiya := InputFamiliya
        
    IniWrite, %Rang%, %UserSettingsFile%, Profile, Rang
    IniWrite, %Doljnost%, %UserSettingsFile%, Profile, Doljnost
    IniWrite, %Familiya%, %UserSettingsFile%, Profile, Familiya
    
    Gui, ProfileGui:Destroy
    MsgBox, 64, Профиль сохранен, Данные обновлены!`n`nЗвание: %Rang%`nДолжность: %Doljnost%`nФамилия: %Familiya%, 3
    Return
}

ProfileGuiGuiClose:
ProfileGuiGuiEscape:
{
Gui, ProfileGui:Destroy
Return
}
; --- ФУНКЦИИ ОТРИСОВКИ КНОПОК ---
AddSolidButton(GuiName, X, Y, W, H, Text, Label, BgBGR, HoverBGR, TextBGR := 0x1E293B, IsMultiLine := false) {
Global BtnMap
bgBrush := DllCall("CreateSolidBrush", "UInt", BgBGR, "Ptr")
hoverBrush := DllCall("CreateSolidBrush", "UInt", HoverBGR, "Ptr")
if (IsMultiLine) {
Gui, %GuiName%:Add, Text, x%X% y%Y% w%W% h9 g%Label% hwndPadHwnd
TextY := Y + 9
TextH := H - 9
Gui, %GuiName%:Add, Text, x%X% y%TextY% w%W% h%TextH% Center g%Label% hwndBtnHwnd, %Text%
btnObj := {bgBrush: bgBrush, hoverBrush: hoverBrush, textCol: TextBGR, hovered: false, pair: PadHwnd}
padObj := {bgBrush: bgBrush, hoverBrush: hoverBrush, textCol: TextBGR, hovered: false, pair: BtnHwnd}
BtnMap[BtnHwnd] := btnObj
BtnMap[PadHwnd] := padObj
} else {
Gui, %GuiName%:Add, Text, x%X% y%Y% w%W% h%H% +0x200 Center g%Label% hwndBtnHwnd, %Text%
BtnMap[BtnHwnd] := {bgBrush: bgBrush, hoverBrush: hoverBrush, textCol: TextBGR, hovered: false, pair: 0}
}
}
OnCtlColorStatic(wParam, lParam) {
Global BtnMap
if (BtnMap.HasKey(lParam)) {
btn := BtnMap[lParam]
DllCall("SetTextColor", "Ptr", wParam, "UInt", btn.textCol)
DllCall("SetBkMode", "Ptr", wParam, "Int", 1)
return btn.hovered ? btn.hoverBrush : btn.bgBrush
}
}
OnMouseMove(wParam, lParam, msg, hwnd) {
Global BtnMap, LastHoveredHwnd
if (hwnd = LastHoveredHwnd)
return
if (LastHoveredHwnd && BtnMap.HasKey(LastHoveredHwnd)) {
prev := BtnMap[LastHoveredHwnd]
if (prev.pair != hwnd) {
SetButtonHover(LastHoveredHwnd, false)
}
}
if (BtnMap.HasKey(hwnd)) {
SetButtonHover(hwnd, true)
LastHoveredHwnd := hwnd
SetTimer, CheckMouseLeave, 50
} else {
LastHoveredHwnd := 0
}
}
SetButtonHover(hwnd, state) {
Global BtnMap
btn := BtnMap[hwnd]
if (btn.hovered = state)
return
btn.hovered := state
DllCall("InvalidateRect", "Ptr", hwnd, "Ptr", 0, "Int", 1)
if (btn.pair) {
BtnMap[btn.pair].hovered := state
DllCall("InvalidateRect", "Ptr", btn.pair, "Ptr", 0, "Int", 1)
}
}
CheckMouseLeave() {
Global BtnMap, LastHoveredHwnd
MouseGetPos,,, winHwnd, ctrlHwnd, 2
if (!BtnMap.HasKey(ctrlHwnd)) {
if (LastHoveredHwnd && BtnMap.HasKey(LastHoveredHwnd)) {
SetButtonHover(LastHoveredHwnd, false)
}
LastHoveredHwnd := 0
SetTimer, CheckMouseLeave, Off
}
}
CleanUpBrushes() {
Global BtnMap
for hwnd, btn in BtnMap {
if (btn.bgBrush)
DllCall("DeleteObject", "Ptr", btn.bgBrush)
if (btn.hoverBrush)
DllCall("DeleteObject", "Ptr", btn.hoverBrush)
}
}
; --- ОКНА С ЖИВЫМ ПОИСКОМ (СВЕТЛАЯ ТЕМА) ---
ShowKoap:
{
OpenSearchWindow("КоАП РБ", KoapText)
return
}
ShowUk:
{
OpenSearchWindow("УК РБ", UkText)
return
}
ShowMainArticles:
{
OpenSearchWindow("Основные статьи КоАП/УК ГАИ", MainArticles_GAI)
return
}
ShowOrient:
{
OpenSearchWindow("Текущие ориентировки", OrientText)
return
}
OpenSearchWindow(Title, SourceText) {
Global CurrentSearchSource, SearchQuery, SearchOutput
CurrentSearchSource := SourceText
Gui, SearchGui:New, +AlwaysOnTop +Resize
Gui, SearchGui:Color, F3F4F6, FFFFFF
Gui, SearchGui:Font, s10 c1E293B, Segoe UI
Gui, SearchGui:Add, Text, x10 y14 c1E293B, Поиск:
Gui, SearchGui:Add, Edit, x65 y10 w525 h25 c1E293B vSearchQuery gFilterSearchText
Gui, SearchGui:Add, Edit, x10 y45 w580 h445 c1E293B vSearchOutput ReadOnly +VScroll -WantReturn, %SourceText%
Gui, SearchGui:Show, w600 h500, %Title%
GuiControl, SearchGui:Focus, SearchQuery
}
FilterSearchText:
{
Gui, SearchGui:Submit, NoHide
if (SearchQuery = "") {
GuiControl, SearchGui:, SearchOutput, %CurrentSearchSource%
return
}
FilteredResult := ""
Loop, Parse, CurrentSearchSource, n, r
{
if InStr(A_LoopField, SearchQuery, false) {
FilteredResult .= A_LoopField . "rn"
}
}
if (FilteredResult = "")
FilteredResult := "По запросу «" . SearchQuery . "» ничего не найдено."
GuiControl, SearchGui:, SearchOutput, %FilteredResult%
return
}
SearchGuiGuiClose:
SearchGuiGuiEscape:
{
Gui, SearchGui:Destroy
return
}
; --- ОСТАЛЬНЫЕ ОКНА ---
ShowGun:
{
MsgBox, 64, Мануал использования оружия, %GunText%
return
}
; --- ОТЫГРОВКИ ---
F1::
Send, .
Sleep, 200
Send, Здравия желаю
Sleep, 200
Send, {Enter}
Sleep, 200
Send, .
Sleep, 200
Send, %Doljnost% ГУВД по г. Минску
Sleep, 200
Send, {Enter}
Sleep, 200
Send, .
Sleep, 200
Send, %Rang%.
Sleep, 200
Send, {Enter}
return
F2::
Send, .
Sleep, 200
Send, [М]Спереди движущееся авто, остановитесь справа и прижмитесь к обочине.
Sleep, 500
Send, {Enter}
return
F3::
Send, .
Sleep, 200
Send, me приложив силу, разбил...
Sleep, 200
Send, {Enter}
Sleep, 200
Send, .
Sleep, 200
Send, ...стекло авто и, открыв дверь, вытащил гражданина
Sleep, 200
Send, {Enter}
return
F4::
Send, .
Sleep, 200
Send, me догнав гражданина, дал тому подножку
Sleep, 200
Send, {Enter}
return
F5::
Send, .
Sleep, 200
Send, me разбежавшись накинулся на человека...
Sleep, 200
Send, {Enter}
Sleep, 200
Send, .
Sleep, 200
Send, ..., после чего заломал тому руки
Sleep, 200
Send, {Enter}
return
F6::
Send, .
Sleep, 200
Send, me достав с пояса перчатки, надел те на руки
Sleep, 200
Send, {Enter}
Sleep, 200
Send, .
Sleep, 200
Send, me прохлопал гражданина напротив, осмотрел его карманы
Sleep, 200
Send, {Enter}
Sleep, 200
Send, .
Sleep, 200
Send, do Что нашел %Familiya% при обыске?
Sleep, 200
Send, {Enter}
return
; --- ЗАКРЫТИЕ ---
CloseAllGUIs:
{
Loop, 99
{
Gui, %A_Index%:Destroy
}
Gui, SearchGui:Destroy
Gui, ProfileGui:Destroy
Return
}
GuiEscape:
GuiClose:
Gui, 1:Destroy
Return
