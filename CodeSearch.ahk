;-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
;--------------------------------------------						   Code Search - originally from fischgeek					 --------------------------------------------
;-------------------------------------------- 				  https://github.com/fischgeek/AHK-CodeSearch                  --------------------------------------------
;--------------------------------------------						modified by Ixiko - look below for version 					 --------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

version:= "2023-06-23"
vnumber:= 1.45

/*										        		VERSION HISTORY

																	V1.45
				- added area for displaying line numbers
				- the colours of the rest of the gui have been adapted to the codestyle
				- fixed incorrect behaviour when resizing the Treeview and RichCode controls

																	V1.44
				- Search in files and/or file names
				- Added an RichCode (/Edit)-Control to show your found code highlighted
				- class_RichCode.ahk got additional functions
				- Removed the ListView for a TreeView control
				- Click on a sub-item in TreeView and it scrolls into view!
				- Add a context menu to the TreeView control with the options to Edit, Execute and Open Script Folder.
				- The width of TreeView and RichEdit-Control can be adjusted with a mouse drag in the gap between both controls.
				- Window position, size and the sizes of TreeView and RichCode control will be stored after closing the Gui.

																	V1.3
				- Gui Resize for ListView control is working
				- Showing the last number of files in directory
				- Change the code to the coding conventions of AHK_L V 1.1.30.0
				- Ready to enter the search string right after the start
				- Pressing Enter after entering the search string starts the search immediately
				- The buttons R, W, C now show their long names

																	V1.2
				- Stop/Resume Button is added - so the process can be interrupted even to start a new search
				- a. from fischgeek Todo -  Find an icon - i take yours and it looks great!

																	V1.1
				- the window displays the number of files read so far and the number of digits found during the search process
				- Font size and window size is adapted to 4k monitors (Size of Gui is huge - over 3000 pixel width) - at the moment, no resize or
						any settings for the size of the contents is possible - i'm sorry for that

	Fischgeeks TODO:
		- Add ability to double-click open a file to that line number -> I can still do that
		- Possibly add an extension manager?
		- Add pre-search checks (extension selection, directory)
		- Add auto saving of selected options and filters

*/

;{ script defaults --------------------------------------------------------------------------------------------------------------------------------------------------------------------

	#NoEnv
	SetBatchLines               	, -1
	CoordMode                   	, Pixel, Screen
	CoordMode                  	, Mouse, Screen
	CoordMode                  	, Menu, Screen
	SetTitleMatchMode       	, 2

	#MaxThreads                	, 250
	#MaxThreadsBuffer        	, On
	#MaxThreadsPerHotkey	, 4
	#MaxHotkeysPerInterval	, 99000000
	#HotkeyInterval            	, 99000000
	;#KeyHistory                 	, Off

	ListLines, Off

	Menu, Tray, Icon, % A_ScriptDir "\CodeSearch.ico"

;}

;{ variables -------------------------------------------------------------------------------------------------------------------------------------------------------------------------

		global hCSGui, hTV, hTP, RC
		global config, mFiles, TV, cbxCase, keyword, cbxWholeWord
		global txtInitialDirectory, AHKPath, AHKEditor

		global hCursor1    	:= DllCall("LoadCursor", "Ptr", 0, "Ptr", 32644, "Ptr")
		global hCursor2    	:= DllCall("LoadCursor", "Ptr", 0, "Ptr", 32512, "Ptr")
		global SearchBuffer	:= Object()
		global                  q	:= Chr(0x22)
		global dbg            	:= false

	; get default Autohotkey files editor
		RegRead, EditWith, HKEY_CLASSES_ROOT\AutoHotkeyScript\Shell\Edit\Command
		RegExMatch(EditWith, "[A-Z]\:[A-Za-z\pL\s\-_.\\\(\)]+", path)
		SplitPath, A_AhkPath,, AHKPath
		AHKEditor := path
		config   	:= new Config()

	;maybe later for Resizefeature
		baserate              	:= 1.8     ;(4k)
		WinSizeBase      	:= 3000
		GroupBoxBaseW	:= 500
		GroupBoxBaseH 	:= 120
		StaticTextBase    	:= 400
		MarginX            	:= 10
		MarginY            	:= 10
		StopIT               	:= 0
		icount               	:= 0
		maxCount         	:= 0

	;Column width's
		wFile                 	:= 500
		wLineText          	:= 495
		wLine                	:= 100
		wPosition	        	:= 100

	; load last window position and size
		gP	:= GetSavedGuiPos(MarginX, MarginY)
		TVw	:=  config.getValue("TV_Width", "Settings", 800)
		TVw	:= TVw < 600 ? 600 : TVw
		TPw := isObject(gP) ? gP.W-TVw-5-(2*MarginX) :  600

	; for gui resize:
		wF1 := TVw/gP.W
		wF2	:= 1-wF1

	; load last used search directory
		If (lastDirectory := config.getValue("LastDir", "Settings", ""))
			thisDirLastMaxCount := config.getValue(txtInitialDirectory, "LastFilesInDir", 0)

		dirs := GetLastDirs()

	; richedit settings
		Settings :=
		( LTrim Join Comments
		{
		"TabSize"           	: 4,
		"Indent"             	: "`t",
		"FGColor"           	: 0xEDEDCD,
		"BGColor"           	: 0x3F3F3F,
		"GuiBGColor1"       	: "555453",
		"GuiBGColor2"       	: "B8B7B6",
		"Font"                	: {"Typeface": "Futura Bk Bt", "Size": 9},
		"WordWrap"      	: false,

		"Gutter": {
			;"Width"          	: 40,
			"FGColor"     	: 0x9FAFAF,
			"BGColor"     	: 0x262626
		},

		"UseHighlighter"	: True,
		"Highlighter"       	: "HighlightAHK",
		"HighlightDelay"	: 200,

		"Colors": {
			"Comments"  	:	0x9FBF9F,
			"Functions"    	:	0x7CC8CF,
			"Keywords"     	:	0xE4EDED,
			"Multiline"      	:	0x7F9F7F,
			"Numbers"     	:	0xF79B57,
			"Punctuation" 	:	0x97C0EB,
			"Strings"        	:	0xCC9893,

			; AHK
			"A_Builtins"    	:	0xF79B57,
			"Commands" 	:	0xCDBFA3,
			"Directives"    	:	0x7CC8CF,
			"Flow"            	:	0xE4EDED,
			"KeyNames"  	:	0xCB8DD9,
			"Descriptions"	:	0xF0DD82,
			"Link"            	:	0x47B856,

			; PLAIN-TEXT
			"PlainText" 		:	0x7F9F7F
			}
		}
		)

		Settings2 :=
		( LTrim Join Comments
		{
		"TabSize"           	: 4,
		"Indent"             	: "`t",
		"FGColor"         	: 0xEDEDCD,
		"BGColor"         	: 0x3F3F3F,
		"GuiBGColor1"       	: "555453",
		"GuiBGColor2"       	: "B8B7B6",
		"Font"                	: {"Typeface": "Futura Bk Bt", "Size": 9},
		"WordWrap"      	: false,

		"Gutter": {
			"Width"          	: 40,
			"FGColor"     	: 0x9FAFAF,
			"BGColor"     	: 0x262626
		},

		"UseHighlighter"	: True,
		"Highlighter"       	: "HighlightAHK",
		"HighlightDelay"	: 200,

		"Colors": {
			"Comments"  	:	0x9FBF9F,
			"Functions"    	:	0x7CC8CF,
			"Keywords"     	:	0xE4EDED,
			"Multiline"      	:	0x7F9F7F,
			"Numbers"     	:	0xF79B57,
			"Punctuation" 	:	0x97C0EB,
			"Strings"        	:	0xCC9893,

			; AHK
			"A_Builtins"    	:	0xF79B57,
			"Commands" 	:	0xCDBFA3,
			"Directives"    	:	0x7CC8CF,
			"Flow"            	:	0xE4EDED,
			"KeyNames"  	:	0xCB8DD9,
			"Descriptions"	:	0xF0DD82,
			"Link"            	:	0x47B856,

			; PLAIN-TEXT
			"PlainText" 		:	0x7F9F7F
			}
		}
		)

		Settings3 :=
		( LTrim Join Comments
		{
		; When True, this setting may conflict with other instances of CQT
		"GlobalRun": False,

		; Script options
		"AhkPath": A_AhkPath,
		"Params": "",

		; Editor (colors are 0xBBGGRR)
		"FGColor": 0xEDEDCD,
		"BGColor": 0x3F3F3F,
		"GuiBGColor1"       	: "555453",
		"GuiBGColor2"       	: "D8D7D6",
		"TabSize": 4,
		"Font": {
			"Typeface": "Consolas",
			"Size": 11,
			"Bold": False
		},

		"Gutter": {
			"Width"        	: 75,
			"FGColor"     	: 0x9FAFAF,
			"BGColor"     	: 0x262626
		},

		; Highlighter (colors are 0xRRGGBB)
		"UseHighlighter": True,
		"Highlighter": "HighlightAHK",
		"HighlightDelay": 200, ; Delay until the user is finished typing
		"Colors": {
			"Comments":     0x7F9F7F,
			"Functions":    0x7CC8CF,
			"Keywords":     0xE4EDED,
			"Multiline":    0x7F9F7F,
			"Numbers":      0xF79B57,
			"Punctuation":  0x97C0EB,
			"Strings":      0xCC9893,
			"A_Builtins":   0xF79B57,
			"Commands":     0xCDBFA3,
			"Directives":   0x7CC8CF,
			"Flow":         0xE4EDED,
			"KeyNames":     0xCB8DD9
		},

		; Auto-Indenter
		"Indent": "`t",

		; Pastebin
		"DefaultName": A_UserName,
		"DefaultDesc": "Pasted with CodeQuickTester",

		; AutoComplete
		"UseAutoComplete": True,
		"ACListRebuildDelay": 500 ; Delay until the user is finished typing
	}
	)

;}

;{ the Gui ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------

	; context menu
	funcEdit 	:= Func("ContextMenu").Bind("Edit")
	funcRun 	:= Func("ContextMenu").Bind("Run")
	funcExpl	:= Func("ContextMenu").Bind("Explorer")
	SearchIn 	:= ["Search in files and names", "Search only in files", "Search only filenames"]
	InNum   	:= 1

	Menu, CM, Add, Open in your code editor    	, % funcEdit
	Menu, CM, Add, Run code                    	, % funcRun
	Menu, CM, Add, open directory in explorer  	, % funcExpl


	;gui begin
	Gui, Color, % "c" StrReplace(Settings.GuiBGColor1, "0x"), % "c" StrReplace(Settings.GuiBGColor2, "0x")
	Gui, -DPIScale +Resize +LastFound +MinSize1920x800 HwndhCSGui	0x91CF0000 ; +LastFound and all controls will be shown at start without any problems
	Gui, Margin          	, % MarginX , % MarginY
	Gui, Font, s9 q5 cWhite Bold	, Segoe UI Light
	Gui, Add, Text       	,, % "Initial Directory:"
	Gui, Font, cBlack Normal
	Gui, Add, ComboBox, Section w450 h27 r10 -Wrap vtxtInitialDirectory gIDirectory hwndhtxtInitialDirectory       	, % dirs ;txtInitialDirectory
	Gui, Add, Button    	, hp+1 w40 ys-1 gbtnDirectoryBrowse_Click vbtnDirectoryBrowse                                    	, % "..."
	Gui, Font, s9 q5 cWhite Bold	, Segoe UI Light
	Gui, Add, Text       	, xm, % "String to search for:"


	;search field
	Gui, Font, cBlack Normal
	Gui, Add, Edit     	, Section w420 HWNDhsearch vtxtSearchString                     	, % ""
	Gui, Add, Button   	, ys-1 hp+1 vbtnSearch gbtnSearch_Click                         	, % "Search"
	Gui, Add, Checkbox	, Section checked xm h30 0x1000 vcbxRecurse                     	, % "RECURSE"
	Gui, Add, Checkbox	, ys 			hp 0x1000 vcbxWholeWord                               	, % "WHOLE WORD"
	Gui, Add, Checkbox	, ys       	hp 0x1000 vcbxCase                                   	, % "CASESENSITIVE"
	Gui, Add, Checkbox	, ys       	hp 0x1000 vcbxSearchWhat  gcbxClick                 	, % SearchIn[InNum]
	Gui, Add, Button   	, ys w200 	hp 0x1000 Center vSearchStop gbtnSearchStop           , % "STOP SEARCHING"


	;filetypes
	Gui, Font, s9 cWhite Bold
	GuiControlGet, p, Pos, btnDirectoryBrowse
	x := pX+pW+20
	Gui, Add, GroupBox	, % "x" x " ym w580 h145 Center vGBFileTypes"                   	, % "File Types"
	Gui, Add, Checkbox	, % "yp+30 xp+15 Section checked vcbxAhk"                     		, % ".ahk/ah2"
	Gui, Add, Checkbox	, ys vcbxHtml   BackgroundTrans                                 	, % ".html"
	Gui, Add, Checkbox	, ys vcbxCss     BackgroundTrans                                	, % ".css"
	Gui, Add, Checkbox	, ys vcbxJs       BackgroundTrans                               	, % ".js"
	Gui, Add, Checkbox	, ys vcbxPy       BackgroundTrans                               	, % ".py"
	Gui, Add, Checkbox	, ys vcbxIni      BackgroundTrans                               	, % ".ini"
	Gui, Add, Checkbox	, ys vcbxTxt      BackgroundTrans                                	, % ".txt"
	Gui, Add, Text        	, xs y+5                                                     	, % "Additional extension (ex. xml,cs,aspx)"
	Gui, Font, cBlack Normal
	Gui, Add, Edit        	, w550 vtxtAdditionalExtensions


	;statics
	Gui, Font, s9 cWhite, Segoe UI Light
	GuiControlGet, p, Pos, GBFileTypes
	x := pX+pW+10
	Gui, Add, GroupBox, x%x% ym w380 h145 Center                                        	, % "Statistics"
	Gui, Add, Text, yp+30 xp+15 w180 Right Section                                      	, % "File counter: "
	Gui, Font, s9 Bold, Consolas
	Gui, Add, Text, ys+3 w150 	vStatCount                                               	, % SubStr("000000" icount, -3) "/" (StrLen(thisDirLastMaxCount) = 0 ? "" : SubStr("00000" thisDirLastMaxCount, -3))
	Gui, Font, s9 Normal, Segoe UI Light
	Gui, Add, Text, xs w180 Right Section vTFiles                                       	, % "Files with search string: "
	Gui, Font, s9 Bold, Consolas
	Gui, Add, Text, ys+3 w150  	vStatFiles                                               	, % ifiles
	Gui, Font, s9 Normal, Segoe UI Light
	Gui, Add, Text, xs w180 Right Section vTString                                      	, % "Searchstring found: "
	Gui, Font, s9 Bold, Consolas
	Gui, Add, Text, ys+3 w150   vStatFound                                              	, % isub
	Gui, Font, s9 Normal, Segoe UI Light
	Gui, Add, Picture, x+180 ym w150 h140 gCSReload vCSReload hwndCShReload              	, % A_ScriptDir "\assets\4293840.png"   ;w135 h130
	Gui, Add, Picture, xp yp w150 h140 vCSReload1 hwndCShReload1                        	, % A_ScriptDir "\assets\4293840.png"   ;w135 h130
	Gui, Font, s9 Bold cB4CBE4, Segoe UI Light
	Gui, Add, Text, xp-120 yp+130 w400 Center BackgroundTrans                            	, % "a script by Fishgeek"
	Gui, Add, Text, yp+25  w400 Center BackgroundTrans                                   	, %  "modified by Ixiko V" vnumber " (" version ")"


	;debug
	GuiControlGet, p, Pos, CSReload
	Gui, Font, s8 q5 cBlack, Segoe UI Light
	Gui, Add, Text, % "x" px+pW+30   	" y20 w800 h120 Wrap vDebug1"
	Gui, Add, Text, % "x" px+pW+840 	" y20 w800 h120 Wrap vDebug2"

	;treeview
	GuiControlGet, p, Pos, cbxRecurse
	h := gP.H-pY-pH-10-MarginY
	Gui, Font, s9 q5, Consolas
	Gui, Add, Treeview, % "xm y" pY+pH+20 " w" TVw " h" h " AltSubmit gResultsTV vtvResults HWNDhTV Section"

	;richcode
	GuiControlGet, p, Pos, tvResults
	RCPos 	:=  "x" pX+pW+5 " y" pY " w" TPw-10 " h" pH " "
	RC    	:= new RichCode(Settings3, RCPos, 1)
	hTP   	:= RC.hwnd
	hGtr		:= RC.gutter.hwnd
	DocObj  := RC.GetTomObject("IID_ITextDocument")
	;~ RC.AddMargins(5, 5, 5, 5)
	RC.ShowScrollBar(0, False)

	GuiControl, Disable   	, SearchStop
	GuiControl,           	, txtInitialDirectory, % lastDirectory
	GuiControl, ChooseString, txtInitialDirectory, % lastDirectory
	GuiControl, Focus     	, txtSearchString

	LV_ModifyCol(1, wFile)
	LV_ModifyCol(2, wLineText)
	LV_ModifyCol(3, wLine)
	LV_ModifyCol(4, wPosition)

	If (gP.X < -20) {
		Gui, Show,      	, Code Search
		Gui, Maximize
	}
	else {
		Gui, Show, % "x" gP.X " y" gP.Y " w" gP.W " h" gP.H	, Code Search
	}

	If gP.M
		Gui, Maximize

	;hope this will fix the empty gui effect
	wp := GetWindowSpot(hCSGui)
	SetWindowPos(hCSGui, wp.X, wp.Y, wp.W+2	, wp.H+2, 0, 0x40)
	SetWindowPos(hCSGui, wp.X, wp.Y, wp.W 	, wp.H	, 0, 0x40)


	hTP := GetHex(hTP), hTV := GetHex(hTV)
	OnMessage(0x200 	, "OnWM_MOUSEMOVE")
	OnMessage(0x020  	, "OnWM_SETCURSOR")

	GuiControlGet	, TV, Pos, tvResults

	SearchIsFocused:= Func("ControlIsFocused").Bind("Edit2")
	Hotkey, If         	, % SearchIsFocused
	Hotkey, ~Enter    	, btnSearch_Click
	Hotkey, If




return

GuiSize: ;{
	if (A_EventInfo = 1)
		return
GuiSizePre:
	GuiControl, -Redraw, % "tvResults"
	GuiControl, -Redraw, % RC.gutter.hwnd
	GuiControl, -Redraw, % RC.hwnd
	wNew	:= A_GuiWidth     	, hNew	:= A_GuiHeight
	TVw  	:= Floor(wNew*wF1)	, PrW	:=  Floor(wNew*wF2)- RC.gutter.W - 1
	Critical Off
	Critical
	GuiControl, Move, tvResults         	, % " h" hNew - TVy - 5   	"w"	TVw - 5
	GuiControl, Move, % RC.gutter.hwnd  	, % " h" hNew - TVy - 5   	"x"	TVw + 1
	GuiControl, Move, % RC.hwnd         	, % " h" hNew - TVy - 5   	"x"	TVw + RC.gutter.W + 1 " w" PrW
	Critical Off
	GuiControl, +Redraw, % "tvResults"
	GuiControl, +Redraw, % RC.gutter.hwnd
	GuiControl, +Redraw, % RC.hwnd
	RedrawWindow(hCSGui)
return ;}

cbxClick: ;{

	InNum := InNum+1 >3 ? 1 : InNum+1
	GuiControl, Text	, cbxSearchWhat, % SearchIn[InNum]
	GuiControl,      	, cbxSearchWhat, 0

return ;}

TOff:
	ToolTip,,,, 14
return


;}

;{ gui dialogs -----------------------------------------------------------------------------------------------------------------------------------------------------------------------
btnDirectoryBrowse_Click:	;{

	Gui, Submit, NoHide
	startingPath := txtInitialDirectory && Instr(FileExist(txtInitialDirectory), "D") ? txtInitialDirectory : "*C:"

	FileSelectFolder, targetDir, % startingPath "\", 3, % "Select a starting directory."
	if !targetDir
		return

	If !CB_ItemExist(htxtInitialDirectory, targetDir) {

		GuiControl, Disable, SearchStop
		GuiControl,, txtInitialDirectory, % targetDir
		GuiControl, Choosestring, txtInitialDirectory, % targetDir
		GuiControl, Focus, txtSearchString
		config.setValue(targetDir, "LastDir")

	}

return ;}

btnSearchStop:                      	;{

	If (StopIT = 0)	{
		StopIT := 1
		WinSetTitle, % "ahk_id " hCSGui,, % "Code Search - searching ist stopped"
		GuiControl,, SearchStop, % "RESUME SEARCHING"
		DisEnable("Enable")
	}
	else if (StopIT = 1)	{
		StopIT := 0
		WinSetTitle, % "ahk_id " hCSGui ,, Code Search - I am searching
		GuiControl,, SearchStop, % "STOP SEARCHING"
		DisEnable("Disable")
	}

return ;}

btnSearch_Click:                  		;{

	global TV          	:= Array()
	global mFiles     	:= Object()
	global TVIndex1	:= TVIndex2:= StopIT:= icount := ifiles := isub := StopIT := 0
	PreviewFile_old := ""

	Gui, Submit, NoHide
	TV_Delete()

    SetWorkingDir, % txtInitialDirectory

	WinSetTitle, % "ahk_id " hCSGui ,, Code Search - I am searching
	GuiControl,           	, StatFiles   	, 0
	GuiControl,           	, StatFound	, 0
	GuiControl,           	, SearchStop, % "STOP SEARCHING"
	GuiControl, Enable	, SearchStop
	DisEnable("Disable")

	thisDirMaxCount := config.getValue(txtInitialDirectory, "LastFilesInDir")
	keyword       		:= txtSearchString
	extensions       	:= getExtensions()

	If (last_txtInitialDirectory <> txtInitialDirectory) || (last_extensions <> extensions) {
		last_txtInitialDirectory	:= txtInitialDirectory
		last_extensions       	:= extensions
		SearchBuffer          	:= Object()
		fullindexed             	:= false
		config.setValue(txtInitialDirectory, "LastDir")
	}

	If (!SearchBuffer.Count() || !fullindexed)
		gosub FilesSearch
	Else
		gosub Buffersearch


	SetStatCount(icount, icount)
	config.setValue(icount , txtInitialDirectory, "LastFilesInDir")

	WinSetTitle, % "ahk_id " hCSGui,, Code Search - ready with searching
	GuiControl,           	, SearchStop    	, % "STOP SEARCHING"
	GuiControl, Disable	, SearchStop
	DisEnable("Enable")

return ;}

FilesSearch:                        	;{

	fullindexed := false
	Loop, Files, % txtInitialDirectory "\*.*", % (cbxRecurse ? "R":"")
	{
		While (StopIT = 1)
			loop 30
				sleep 10

		if A_LoopFileAttrib contains H,S,R
			continue
		if A_LoopFileExt not in %extensions%
			continue

		icount ++
		SetStatCount(icount, (icount > thisDirMaxCount ? icount : thisDirMaxCount))

		filePath		:= A_LoopFileFullPath
		fileName 	:= A_LoopFileName
		txt     		:= FileOpen(filepath, "r").Read()

		SearchBuffer.Push({"path":filePath, "txt":txt})
		FindAndShow(txt, filepath)

	}

	GuiControl,, StatFound, % isub
	fullindexed := true

return ;}

BufferSearch:                       	;{

	Sciteoutput(SearchBuffer.Count() "`n" SearchBuffer[1].txt)
	modDiv := StrLen(SearchBuffer.Count()) < 3 ? 1 : 100

	For buffIndex, file in SearchBuffer {

		While (StopIT = 1)
			loop 30
				sleep 10

		FindAndShow(file.txt, file.path)
		If (Round(Mod(buffIndex, modDiv)) = 0)
			SetStatCount(buffIndex, SearchBuffer.Count())

	}

	SetStatCount(buffIndex, SearchBuffer.Count())
	icount := buffIndex

return ;}

FindAndShow(txt, filepath)          	{                                       	; search txt, filenames and show matches in TreeView

	global ; cbxCase, keyword,cbxWholeWord

	  ; Filename matching
	  ; only search in filenames all things continues here, InNum holds the search mode: [1] is search in files and filenames, [2] only in files , [3] only in filenames
		If (InNum ~= "^(1|3)$") {
			RegExMatch(filename, getRegExOptions(cbxCase) getExpression(keyword, cbxWholeWord), obj)
			If (obj.Len() > 0)
				If !mFiles.HasKey(filepath) {
					SplitPath, filepath, outFileName, OutDir
					TVIndex1 ++
					TV[TVIndex1]   	:= Array()
					TV[TVIndex1]   	:= TV_Add(outFileName " [" OutDir "]" )
					mFiles[filepath] 	:= Object()
					mFiles[filepath].Push({"line":lineNr, "linepos":obj.Pos(), "TVIndex1":TVIndex1})
				}

	  ; search only in filenames continues here
			If (InNum=3)
				return
		}

	  ; search in file text
		For lineNr, lineText in StrSplit(txt, "`n", "`r") 		{

			RegExMatch(lineText, getRegExOptions(cbxCase) getExpression(keyword, cbxWholeWord), obj)
			if (obj.Len() > 0) {

				; file is always listed
					If mFiles.HasKey(filepath) {

						idx1 := mFiles[filepath][1].TVIndex1
						idx2 := mFiles[filepath].MaxIndex() + 1
						TV[idx1][idx2] := TV_Add("[l:" Substr("0000" lineNr, -4) " p:" SubStr("000" obj.pos(), -2) "] " truncate(lineText, 120), TV[idx1])

						mFiles[filepath].Push({"line":lineNr, "linepos":obj.Pos()})

					}
					else {

						SplitPath, filepath, outFileName, OutDir
						TVIndex1 ++
						TV[TVIndex1]   	:= Array()
						TV[TVIndex1]   	:= TV_Add(outFileName " [" OutDir "]" )
						TV[TVIndex1][1]	:= TV_Add("[l:" Substr("0000" lineNr, -4) " p:" SubStr("000" obj.pos(), -2) "] " truncate(lineText, 120), TV[TVIndex1])

						mFiles[filepath] 	:= Object()
						mFiles[filepath].Push({"line":lineNr, "linepos":obj.Pos(), "TVIndex1":TVIndex1})

					}

					If (filePath <> filePath_old) {
						ifiles ++
						GuiControl,, StatFiles, % ifiles
						filePath_old := filePath
					}

					isub++
					If Mod(isub, 30) = 0
						GuiControl,, StatFound, % isub

			}
		}


}

ResultsTV:	                        	;{

	Gui, Submit, NoHide

	CrtLine1 := RC.GetCaretLine()
	global EventInfo:= A_EventInfo

	If RegExMatch(A_GuiEvent , "i)Normal|S$") && (A_EventInfo <> 0)	{

			TVText := TV_GetInfo(EventInfo)
			RegExMatch(TVText.parent, "(.*)\s+\[(.*)\]", match)
			PreviewFile := match2 "\" match1

			If (PreviewFile <> PreviewFile_old) {
				RC.Settings.Highlighter := GetHighlighter(PreviewFile)
				RC.Value   	:= FileOpen(PreviewFile, "r").Read()
				RC.UpdateGutter()

				CurrentSel 	:= RC.GetSel()                           	; get the current selection

				CF2 := RC.GetCharFormat()
				CF2.Mask      	:= 0x40000001	    	    		; set Mask (CFM_COLOR = 0x40000000, CFM_BOLD = 0x00000001)
				CF2.Effects    	:= 0x01                                   	; set Effects to bold (CFE_BOLD = 0x00000001)
				CF2.TextColor 	:= 0x006666
				CF2.BackColor 	:= 0xFFFF00
				RC.SetFont({BkColor:"YELLOW", Color:"BLACK"})
				;RC.SetSel(0,0)
				;RC.SetScrollPos(0,CaretLine-1)
				;RC.SetScrollPos(LineX+0,LineY+0)
				;RC.FindText(txtSearchString, ["Down"])
				;RC.SetScrollPos(0,0)
				PreviewFile_old := PreviewFile
			}

			upOrWhat := 0
			RegExMatch(TVText.child, "\[l\:(?<Y>\d+)\s+p\:(?<X>\d+)\]\s+(?<Text>.*)$", Line)
			If !RC.FindText(lineText, ["Down"])        	; search down
				RC.FindText(lineText), upOrWhat := 1    	; search up
			RC.ScrollCaret()
			RC.ScrollLines(upOrWhat ? "-40": "40")
			RC.ScrollCaret()
			RC.SyncGutter()

			;DocObj.
			CrtLine2 := RC.GetCaretLine()
			If dbg
				GuiControl,, Debug1,  % "CaretLine1: " CrtLine1 "`nCaretLine2: " CrtLine2 "`nLine: x" LineX+0 " y" LineY+0 "`nScrollPos x" ScrollPos.X " y" ScrollPos.Y

	}
	else if InStr(A_GuiEvent, "RightClick") && (A_EventInfo <> 0) {
			MouseGetPos, mx, my, mWin, mCtrl, 2
			Menu, CM, Show, % mx - 20, % my + 10
    }

return ;}

IDirectory:                          	;{

	Gui, Submit, NoHide

	If Instr(A_GuiControl, "txtInitialDirectory") && Instr(A_GuiControlEvent, "Normal") {
		DirMaxCount := config.getValue(txtInitialDirectory, "LastFilesInDir", 0)
		SetStatCount(0, DirMaxCount)
		GuiControl,, StatFiles   	, % ""
		GuiControl,, StatFound	, % ""
	}

return ;}

CSReload:                           	;{
	SaveGuiPos()
	Reload
return ;}

GuiClose: 	                        	;{
	SaveGuiPos()
ExitApp
;}

RCHandler(p1,p2,p3,p4)              	{
	If dbg
		GuiControl,, Debug2,  % "GCE: " p1 " | GE: " p2 " | AEI: " p3 "`nCL: " p4
}

ContextMenu(MenuName)               	{

	TVText := TV_GetInfo(Eventinfo)

	If Instr(MenuName, "Edit")
		Run, % q AHKEditor q " " q TVText.fullfilepath q,, Hide
	else If Instr(MenuName, "Run") {
		scriptText := FileOpen(TVText.fullFilePath, "r", "UTF-8").Read()
		RegExMatch(scriptText, "i)#Requires\s+AutoHotkey\s+v(?<v>\d+)", AHK)
		AHKv := !AHKv ? 1 : AHKv

		Run, % q A_AhkPath q " " q TVText.fullfilepath q,, Hide
	}
	else If Instr(MenuName, "Explorer")
		Run % COMSPEC " /c explorer.exe /select, " q TVText.fullfilepath q,, Hide

}

;}

;{ functions --------------------------------------------------------------------------------------------------------------------------------------------------------------------------
OnWM_MOUSEMOVE(wParam, lParam, msg, hWnd) 		{

  Global hCursor1, hCursor2, hCSGui, hFooter, CShReload, hTV, hTP, hGtr
	Static hOldCursor, lasthwnd
	Static mCursor 	:= false
	Static moving 	:= false
  Static PrevX  	:= -1, x2 := -1

	hwnd := GetHex(hwnd)

	If (lasthwnd != hwnd) {

		If (hwnd = CShReload) {

			callfunc := Func("FishMove").Bind(CShReload)
			SetTimer, % callfunc, -1

		}

		lasthwnd := hwnd
	}

	If (hwnd = hTV || hwnd = hTP) {

		focused 	:= GetFocusedControlHwnd(hCSGui)
		If (hwnd != focused)
			ControlFocus,, % "ahk_id " hwnd

	}

	CoordMode Mouse, Client
	MouseGetPos, x1, y1, hWin, hCtrl, 2

	GuiControlGet lv	, Pos, % hTV
	GuiControlGet gtr	, Pos, % hGtr
	GuiControlGet tp	, Pos, % hTP
	WinGetPos,,, csW,, % "ahk_id " hCSGui

	If dbg {
		ToolTip, % "MMove: " hCtrl " [hTV: " hTV ", hTP: " hTP "]`n"
							. "hWin: " hWin ", w" w "`n"
							. "mx > hTV = " (x1>=(lvX+lvW-10)) " : mx < hTP = " (x1<=tpX+10) "`n"
							. "LButton Down: " GetKeyState("LButton", "P"), 2000, 300, 2
	}

	If  (x1 > (lvX + lvW - 10) && (x1 < tpX + 10) && (y1<(tpy+tph)) && (y1>tpy)) { ; (hWnd == hCSGui) ||

		 If (x1 > (lvX + lvW - 10) && (x1 < tpX + 10) && (y1<(tpy+tph)) && (y1>tpy)) {
			hOldCursor := DllCall("SetCursor", "Ptr", hCursor1, "Ptr")
			mCursor := true
			}
			else {
				if mCursor && !moving {
					mCursor := false
					hOldCursor := DllCall("SetCursor", "Ptr", hCursor2, "Ptr")
				}
			}

		PrevX := 0
		Offset := x1 - lvW
		RCw := RC.gutter.W

    While (GetKeyState("LButton", "P")) {

			moving := true

			MouseGetPos x2


			If (x2 == PrevX)
				Continue

			PrevX 	:= x2
			x      	:= gtrX + (x2 - x1)
			w      	:= gtrW + tpW	+ (x1 - PrevX)

			If (w<csW*0.25) || (w>csW*0.85)
				continue

			GuiControl Move, % hTV	, % "w" (x2 - Offset)
			GuiControl Move, % hGtr	, % "x" x
			GuiControl Move, % hTP	, % "x" x+gtrW+1 " w" w-gtrW-1

			;~ ToolTip, % "hTV " hTV ", % w" (x2 - Offset) "`nhTP " hTP ", % x" x " w" w

			Sleep 1

		}

		moving := false

	}

}
OnWM_SETCURSOR(wParam, lParam, msg, hWnd)        	{

    CoordMode Mouse, Client
    MouseGetPos x, y
    GuiControlGet tp	, Pos, % hTP
    GuiControlGet lv	, Pos, % hTV

     If (x>(lvX+lvW-10) && (x<tpX+10) && (y<(tpy+tph)) && (y>tpy))  {
		hOldCursor := DllCall("SetCursor", "Ptr", hCursor1, "Ptr")
       Return True
     }

}

FishMove(hwnd) {

	static _initMove:=false
	static movePix := [[6,1],[8,3],[10,6]]
	static aniPos:=1, aniLoop := 0, retZPos := 0, dir := 1
	static horizontal, maxDelta, velocity, maxXa, maxXb
	static cpX, cpY, cpXo, cpYo, move

	CoordMode, ToolTip, Screen

	If !_initMove {
		GuiControlGet, cp, Pos, % hwnd
		cpXo := cpX, cpYo := cpY
		Random horizontal, 0, 1
		Random maxDelta, 30, 120
		maxDPlus := Round(maxDelta//(movePix.Count()*2))
		SciTEOutput(maxDelta ", " maxDPlus)
		;~ Random velocity, 1, 15

		move := dir ? 1 : -1
		_initMove := true
	}

	Critical, Off
	Critical

	newX := cpX+(move*movePix[aniPos].1)
	If 	(newX < maxXa)
	 || (newX > maxXb)
	 || (newX = cpXo	&& retZPos) {

		dir     := !dir
		move  	:= dir ? 1 : -1
		aniLoop += 0.5
		If (aniPos <= movePix.Count()) {

			If (aniLoop > movePix[aniPos].2) && !retZPos {
				retZPos := true
			} else if (aniLoop > movePix[aniPos].2) && retZPos {
				aniPos  += 1
				aniLoop := 0
				retZPos := false
				maxXa := cpXo - maxDelta + maxDPlus*(aniPos-1)
				maxXb := cpXo + maxDelta - maxDPlus*(aniPos-1)
			}

		}

		if (aniPos > movePix.Count()) {

				GuiControl, MoveDraw, CSReload , % "x" cpXo " y" cpYo
				GuiControl, MoveDraw, CSReload1, % "x" cpXo " y" cpYo
				aniPos		:= 1
				aniLoop 	:= 0
				retZPos 	:= false
				dir       := 1
				move    	:= dir ? 1 : -1
				_initMove := false
				;~ ToolTip, % "cpX: " cpX "`nmove: " move " delta(" move*movePix[aniPos].1 ")" "`naniPos: " aniPos "`naniLoop: " aniLoop, 2000, 400, 3
				return


		}


	}

	cpX += move*movePix[aniPos].1
	GuiControl, MoveDraw, CSReload, % "x" cpX " y" cpY
	GuiControl, MoveDraw, CSReload1, % "x" cpX " y" cpY
	;~ ToolTip, % "cpX: " maxXa " < "  cpXo  " > " maxXb "`n                    " cpX "`nmove: " move " delta(" move*movePix[aniPos].1 ")"
					;~ .  "`naniPos: " aniPos "`naniLoop: " aniLoop "`nretZPos: " retZPos, 2000, 400, 3

	Critical, Off

	If _initMove {
		callfunc := Func("FishMove").Bind(hnwd)
		SetTimer, % callfunc, %  -1 ;*velocity
	}

}
TV_GetInfo(EventInfo)                                                       	{

	If !TV_GetParent(EventInfo) {
		TV_GetText(PText, EventInfo)
		SText := ""
	}	else 	{
		TV_GetText(SText, EventInfo)
		TV_GetText(PText, TV_GetParent(EventInfo))
	}

	RegExMatch(PText, "(.*)\s+\[(.*)\]", match)
	FullFilePath	:= match2 "\" match1
	FilePath     	:= match2 "\"

return {"parent": PText, "child": SText, "fullfilepath": fullFilePath, "filepath": FilePath, "EventInfo": EventInfo}
}
GetLastDirs()                                                                	{                         	;-- loads last folders

	lastDirs := ""
	FileRead, tmpFile, % A_ScriptDir "\config.ini"
	RegExMatch(StrReplace(tmpFile, "`r`n", "|"), "i)\[LastFilesInDir\](.*)", dir)
	For itemNr, item in StrSplit(dir1, "|") {
		dir := RegExReplace(A_LoopField, "\s*\=\s*\d+", "")
		If Instr(FileExist(dir), "D")
			lastDirs .= dir "|"
	}

return LTrim(RTrim(lastDirs, "|"), "|")
}
SetStatCount(now, max)                                                      	{
	maxLen := Max(StrLen(now), StrLen(max))
	GuiControl,, StatCount, % SubStr("0000000" now, -1*(maxLen-1)) "/" SubStr("0000000" max, -1*(maxLen-1))
}
DisEnable(status)                                                           	{
	; use Enable or Disable
	GuiControl, % status, btnDirectoryBrowse
	GuiControl, % status, txtInitialDirectory
	GuiControl, % status, txtSearchString
	GuiControl, % status, btnSearch
}
ControlIsFocused(ControlID)                                                  	{                          	;-- true or false if specified gui control is active or not
	GuiControlGet, FControlID, Focus
	If Instr(FControlID, ControlID)
			return true
return false
}
GetWindowSpot(hWnd)                                                         	{                          	;-- like GetWindowInfo, but faster because it only returns position and sizes
    NumPut(VarSetCapacity(WINDOWINFO, 60, 0), WINDOWINFO)
    DllCall("GetWindowInfo", "Ptr", hWnd, "Ptr", &WINDOWINFO)
    wi := Object()
    wi.X   	:= NumGet(WINDOWINFO, 4	, "Int")
    wi.Y   	:= NumGet(WINDOWINFO, 8	, "Int")
    wi.W  	:= NumGet(WINDOWINFO, 12, "Int") 	- wi.X
    wi.H  	:= NumGet(WINDOWINFO, 16, "Int") 	- wi.Y
    wi.CX	:= NumGet(WINDOWINFO, 20, "Int")
    wi.CY	:= NumGet(WINDOWINFO, 24, "Int")
    wi.CW 	:= NumGet(WINDOWINFO, 28, "Int") 	- wi.CX
    wi.CH  	:= NumGet(WINDOWINFO, 32, "Int") 	- wi.CY
	wi.S   	:= NumGet(WINDOWINFO, 36, "UInt")
    wi.ES 	:= NumGet(WINDOWINFO, 40, "UInt")
	wi.Ac	:= NumGet(WINDOWINFO, 44, "UInt")
    wi.BW	:= NumGet(WINDOWINFO, 48, "UInt")
    wi.BH	:= NumGet(WINDOWINFO, 52, "UInt")
	wi.A    	:= NumGet(WINDOWINFO, 56, "UShort")
    wi.V  	:= NumGet(WINDOWINFO, 58, "UShort")
Return wi
}
SetWindowPos(hWnd, x, y, w, h, hWndInsertAfter := 0, uFlags := 0x40) {                                		;--works better than the internal command WinMove - why?

	/*  ; https://docs.microsoft.com/en-us/windows/desktop/api/winuser/nf-winuser-setwindowpos

	SWP_NOSIZE                 	:= 0x0001	; Retains the current size (ignores the cx and cy parameters).
	SWP_NOMOVE                 	:= 0x0002	; Retains the current position (ignores X and Y parameters).
	SWP_NOZORDER              	:= 0x0004	; Retains the current Z order (ignores the hWndInsertAfter parameter).
	SWP_NOREDRAW              	:= 0x0008	; Does not redraw changes.
	SWP_NOACTIVATE            	:= 0x0010	; Does not activate the window.
	SWP_DRAWFRAME             	:= 0x0020	; Draws a frame (defined in the window's class description) around the window.
	SWP_FRAMECHANGED          	:= 0x0020	; Applies new frame styles set using the SetWindowLong function.
	SWP_SHOWWINDOW             	:= 0x0040	; Displays the window.
	SWP_HIDEWINDOW            	:= 0x0080	; Hides the window
	SWP_NOCOPYBITS            	:= 0x0100	; Discards the entire contents of the client area.
	SWP_NOOWNERZORDER         	:= 0x0200	; Does not change the owner window's position in the Z order.
	SWP_NOREPOSITION          	:= 0x0200	; Same as the SWP_NOOWNERZORDER flag.
	SWP_NOSENDCHANGING        	:= 0x0400	; Prevents the window from receiving the WM_WINDOWPOSCHANGING message.
	SWP_DEFERERASE             	:= 0x2000	; Prevents generation of the WM_SYNCPAINT message.
	SWP_ASYNCWINDOWPOS        	:= 0x4000	; This prevents the calling thread from blocking its execution while other threads process the request.

	 */

Return DllCall("SetWindowPos", "Ptr", hWnd, "Ptr", hWndInsertAfter, "Int", x, "Int", y, "Int", w, "Int", h, "UInt", uFlags)
}

RedrawWindow(hwnd=0)                                                        	{
	static RDW_INVALIDATE 	:= 0x0001
	static	RDW_ERASE           	:= 0x0004
	static RDW_FRAME          	:= 0x0400
	static RDW_ALLCHILDREN	:= 0x0080
return dllcall("RedrawWindow", "Ptr", hwnd, "Ptr", 0, "Ptr", 0, "UInt", RDW_INVALIDATE | RDW_ERASE | RDW_FRAME | RDW_ALLCHILDREN)
}
WinGetMinMaxState(hwnd)                                                      	{                 			;-- get state if window ist maximized or minimized
	; this function is from AHK-Forum: https://autohotkey.com/board/topic/13020-how-to-maximize-a-childdocument-window/
	; it returns z for maximized("zoomed") or i for minimized("iconic")
	; it's also work on MDI Windows - use hwnd you can get from FindChildWindow()
	zoomed:= DllCall("IsZoomed", "UInt", hwnd)		; Check if maximized
	iconic	:= DllCall("IsIconic"	, "UInt", hwnd)		; Check if minimized
return (zoomed>iconic) ? "z":"i"
}
GetSavedGuiPos(MarginX, MarginY)                                            	{                       	;-- loads last gui position

	gP 	:= Object()

	If (tmp := config.getValue("GuiPos", "Settings"))
		tmp := StrSplit(tmp, "|")

	If isObject(tmp)
		gP.X:=tmp.1, gP.Y:=tmp.2, gP.W:=tmp.3, gP.H:=tmp.4, gP.M:=(tmp.5=1 ? true:false)
	else
		gP.X:=0, gP.Y:=0, gP.W:=1600, gP.H:=1000, 	gP.M	:=false

return gP
}
SaveGuiPos()                                                                 	{
	winMax 	:= Instr(WinGetMinMaxState(hCSGui), "z") ? 1 : 0
	win 			:= GetWindowSpot(hCSGui)
	winPos	 	:= win.X "|" win.Y "|" win.CW "|" win.CH "|" winMax
	trv	    		:= GetWindowSpot(hTV)
	IniWrite, % winpos	, % A_ScriptDir "\config.ini", Settings, GuiPos
	IniWrite, % trv.CW	, % A_ScriptDir "\config.ini", Settings, TV_Width
}
GetHighlighter(file)                                                        	{
	SplitPath, file,,, extension
return isFunc("Highlight" extension) ? ("Highlight" extension) : ""
}
GetFocusedControlHwnd(hwnd:="A")                                            	{
	ControlGetFocus, FocusedControl, % (hwnd = "A") ? "A" : "ahk_id " hwnd
	ControlGet, FocusedControlId, Hwnd,, %FocusedControl%, % (hwnd = "A") ? "A" : "ahk_id " hwnd
return GetHex(FocusedControlId)
}
GetHex(hwnd)                                                                 	{
return Format("0x{:x}", hwnd)
}
GetDec(hwnd)                                                                 	{
return Format("{:u}", hwnd)
}
listfunc(file)                                                               	{

	fileread, z, % file
	z:= StrReplace(z, "`r")     		                        	; important
	z := RegExReplace(z, "mU)""[^`n]*""", "")          	; strings
	z := RegExReplace(z, "iU)/\*.*\*/", "")              	; block comments
	z := RegExReplace(z, "m);[^`n]*", "")               	; single line comments
	p:=1 , z := "`n" z

	while q:=RegExMatch(z, "iU)`n[^ `t`n,;``\(\):=\?]+\([^`n]*\)[ `t`n]*{", o, p)
		lst .= Substr( RegExReplace(o, "\(.*", ""), 2) "`n"
		, p := q + Strlen(o)-1

	Sort, lst

return lst
}
adjHdrs(listView:="")                                                       	{
	Gui, ListView, % listView
	Loop, % LV_GetCount("Col")
		LV_ModifyCol(A_Index, "autoHdr")
	LV_ModifyCol(1,"Integer Left")
return
}
truncate(s, c="50")                                                         	{
return (StrLen(s) > c) ? SubStr(s, 1, c) " (...)" : LTrim(s)
}
getExtensions()                                                              	{
	global
return RTrim((cbxAhk ? "ahk,ah2" : "") (cbxTxt ? "txt,": "") (cbxIni ? "ini," : "") (cbxHtml ? "html," : "") (cbxCss ? "css," : "") (cbxPy ? "py," : "") (cbxJs ? "js," : ""), ",")
}
getExpression(keyword, wholeWord)                                           	{
return (wholeWord) ? "[\s|\W]?" keyword "[\s|\W]" : keyword
}
getRegExOptions(caseSense)                                                  	{
; if casesense is negativ use "i" regexoption for searching searching
return "O" (!caseSense ? "i" : "") ")"
}
GenHighlighterCache(Settings)                                                	{

		if Settings.HasKey("Cache")
			return
		Cache := Settings.Cache := {}

	; Process Colors
		Cache.Colors := Settings.Colors.Clone()

	; Inherit from the Settings array's base
		BaseSettings := Settings
		While (BaseSettings := BaseSettings.Base)
			For Name, Color in BaseSettings.Colors
				If !Cache.Colors.HasKey(Name)
					Cache.Colors[Name] := Color

	; Include the color of plain text
		if !Cache.Colors.HasKey("Plain")
			Cache.Colors.Plain := Settings.FGColor

	; Create a Name->Index map of the colors
		Cache.ColorMap := {}
		For Name, Color in Cache.Colors
			Cache.ColorMap[Name] := A_Index

	; Generate the RTF headers
		RTF := "{\urtf"

	; Color Table
		RTF .= "{\colortbl;"
		For Name, Color in Cache.Colors	{
			RTF .= "\red"    	Color>>16	& 0xFF
			RTF .= "\green"	Color>>8 	& 0xFF
			RTF .= "\blue"  	Color        	& 0xFF ";"
		}
		RTF .= "}"

	; Font Table
		If Settings.Font	{
			FontTable .= "{\fonttbl{\f0\fmodern\fcharset0 "
			FontTable .= Settings.Font.Typeface
			FontTable .= ";}}"
			RTF .= "\fs" Settings.Font.Size * 2 ; Font size (half-points)
			if Settings.Font.Bold
				RTF .= "\b"
		}

	; Tab size (twips)
		RTF .= "\deftab" GetCharWidthTwips(Settings.Font) * Settings.TabSize
		Cache.RTFHeader := RTF

}
GetCharWidthTwips(Font)                                                     	{

	static Cache := {}

	if Cache.HasKey(Font.Typeface "_" Font.Size "_" Font.Bold)
		return Cache[Font.Typeface "_" font.Size "_" Font.Bold]

	; Calculate parameters of CreateFont
	Height	:= -Round(Font.Size*A_ScreenDPI/72)
	Weight	:= 400+300*(!!Font.Bold)
	Face 	:= Font.Typeface

	; Get the width of "x"
	hDC 	:= DllCall("GetDC", "UPtr", 0)
	hFont 	:= DllCall("CreateFont"
					, "Int", Height 	; _In_ int       	  nHeight,
					, "Int", 0         	; _In_ int       	  nWidth,
					, "Int", 0        	; _In_ int       	  nEscapement,
					, "Int", 0        	; _In_ int       	  nOrientation,
					, "Int", Weight ; _In_ int        	  fnWeight,
					, "UInt", 0     	; _In_ DWORD   fdwItalic,
					, "UInt", 0     	; _In_ DWORD   fdwUnderline,
					, "UInt", 0     	; _In_ DWORD   fdwStrikeOut,
					, "UInt", 0     	; _In_ DWORD   fdwCharSet, (ANSI_CHARSET)
					, "UInt", 0     	; _In_ DWORD   fdwOutputPrecision, (OUT_DEFAULT_PRECIS)
					, "UInt", 0     	; _In_ DWORD   fdwClipPrecision, (CLIP_DEFAULT_PRECIS)
					, "UInt", 0     	; _In_ DWORD   fdwQuality, (DEFAULT_QUALITY)
					, "UInt", 0     	; _In_ DWORD   fdwPitchAndFamily, (FF_DONTCARE|DEFAULT_PITCH)
					, "Str", Face   	; _In_ LPCTSTR  lpszFace
					, "UPtr")
	hObj := DllCall("SelectObject", "UPtr", hDC, "UPtr", hFont, "UPtr")
	VarSetCapacity(SIZE, 8, 0)
	DllCall("GetTextExtentPoint32", "UPtr", hDC, "Str", "x", "Int", 1, "UPtr", &SIZE)
	DllCall("SelectObject", "UPtr", hDC, "UPtr", hObj, "UPtr")
	DllCall("DeleteObject", "UPtr", hFont)
	DllCall("ReleaseDC", "UPtr", 0, "UPtr", hDC)

	; Convert to twpis
	Twips := Round(NumGet(SIZE, 0, "UInt")*1440/A_ScreenDPI)
	Cache[Font.Typeface "_" Font.Size "_" Font.Bold] := Twips
	return Twips
}
EscapeRTF(Code)                                                             	{
	for each, Char in ["\", "{", "}", "`n"]
		Code := StrReplace(Code, Char, "\" Char)
return StrReplace(StrReplace(Code, "`t", "\tab "), "`r")
}
GetKeywordFromCaret(rc) 	                                                  	{

	; https://autohotkey.com/boards/viewtopic.php?p=180369#p180369
		static Buffer
		IsUnicode := !!A_IsUnicode

		;rc := this.RichCode
		sel := rc.Selection

	; Get the currently selected line
		LineNum := rc.SendMsg(0x436, 0, sel[1]) ; EM_EXLINEFROMCHAR

	; Size a buffer according to the line's length
		Length := rc.SendMsg(0xC1, sel[1], 0) ; EM_LINELENGTH
		VarSetCapacity(Buffer, Length << !!A_IsUnicode, 0)
		NumPut(Length, Buffer, "UShort")

	; Get the text from the line
		rc.SendMsg(0xC4, LineNum, &Buffer) ; EM_GETLINE
		lineText := StrGet(&Buffer, Length)

	; Parse the line to find the word
		LineIndex := rc.SendMsg(0xBB, LineNum, 0) ; EM_LINEINDEX
		RegExMatch(SubStr(lineText, 1, sel[1]-LineIndex), "[#\w]+$", Start)
		RegExMatch(SubStr(lineText, sel[1]-LineIndex+1), "^[#\w]+", End)

return Start . End
}
Scite_CurrentWord()                                                         	{
	sci := GV_ST_SciEdit1
	StartingPos := sci.GetCurrentPos() ; store current position
	; Select current 'word'
	sci.SetSelectionStart(sci.WordStartPosition(StartingPos, 1))
	sci.SetSelectionEnd(sci.WordEndPosition(StartingPos, 1))
	; UTF-8 jiggery-pokery begins...
	SelLength := Sci.GetSelText() - 1
	VarSetCapacity(SelText, SelLength, 0)
	Sci.GetSelText(0, &SelText)
	thisWord := StrGet(&SelText, SelLength, "UTF-8")
	; UTF-8 jiggery-pokery ends...
	Sci.SetSelectionStart(StartingPos) ; clear selection start
	Sci.SetSelectionEnd(StartingPos) ; clear selection end
	Return thisWord
}
CB_ItemExist(cbhwnd, item)                                                  	{

	ControlGet, cbList, List,,, % "ahk_id " cbhwnd
	For each, cbitem in StrSplit(cbList, "`n")
		If (cbitem = item)
			return true

return false
}
GetAppImagePath(appname) {                                                                                   	;-- Installationspfad eines Programmes

	headers:= {	"DISPLAYNAME"                  	: 1
					, 	"VERSION"                         	: 2
					, 	"PUBLISHER"             	         	: 3
					, 	"PRODUCTID"                    	: 4
					, 	"REGISTEREDOWNER"        	: 5
					, 	"REGISTEREDCOMPANY"    	: 6
					, 	"LANGUAGE"                     	: 7
					, 	"SUPPORTURL"                    	: 8
					, 	"SUPPORTTELEPHONE"       	: 9
					, 	"HELPLINK"                        	: 10
					, 	"INSTALLLOCATION"          	: 11
					, 	"INSTALLSOURCE"             	: 12
					, 	"INSTALLDATE"                  	: 13
					, 	"CONTACT"                        	: 14
					, 	"COMMENTS"                    	: 15
					, 	"IMAGE"                            	: 16
					, 	"UPDATEINFOURL"            	: 17}

   appImages := GetAppsInfo({mask: "IMAGE", offset: A_PtrSize*(headers["IMAGE"] - 1) })
   Loop, Parse, appImages, "`n"
	If Instr(A_loopField, appname)
		return A_loopField

return ""
}
GetAppsInfo(infoType) {

	static CLSID_EnumInstalledApps := "{0B124F8F-91F0-11D1-B8B5-006008059382}"
        , IID_IEnumInstalledApps     	:= "{1BC752E1-9046-11D1-B8B3-006008059382}"

        , DISPLAYNAME            	:= 0x00000001
        , VERSION                    	:= 0x00000002
        , PUBLISHER                  	:= 0x00000004
        , PRODUCTID                	:= 0x00000008
        , REGISTEREDOWNER    	:= 0x00000010
        , REGISTEREDCOMPANY	:= 0x00000020
        , LANGUAGE                	:= 0x00000040
        , SUPPORTURL               	:= 0x00000080
        , SUPPORTTELEPHONE  	:= 0x00000100
        , HELPLINK                     	:= 0x00000200
        , INSTALLLOCATION     	:= 0x00000400
        , INSTALLSOURCE         	:= 0x00000800
        , INSTALLDATE              	:= 0x00001000
        , CONTACT                  	:= 0x00004000
        , COMMENTS               	:= 0x00008000
        , IMAGE                        	:= 0x00020000
        , READMEURL                	:= 0x00040000
        , UPDATEINFOURL        	:= 0x00080000

   pEIA := ComObjCreate(CLSID_EnumInstalledApps, IID_IEnumInstalledApps)

   while DllCall(NumGet(NumGet(pEIA+0) + A_PtrSize*3), Ptr, pEIA, PtrP, pINA) = 0  {
      VarSetCapacity(APPINFODATA, size := 4*2 + A_PtrSize*18, 0)
      NumPut(size, APPINFODATA)
      mask := infoType.mask
      NumPut(%mask%, APPINFODATA, 4)

      DllCall(NumGet(NumGet(pINA+0) + A_PtrSize*3), Ptr, pINA, Ptr, &APPINFODATA)
      ObjRelease(pINA)
      if !(pData := NumGet(APPINFODATA, 8 + infoType.offset))
         continue
      res .= StrGet(pData, "UTF-16") . "`n"
      DllCall("Ole32\CoTaskMemFree", Ptr, pData)  ; not sure, whether it's needed
   }
   Return res
}


;}

#Include %A_ScriptDir%\Classes\class_Config.ahk
#Include %A_ScriptDir%\Classes\Highlighters\AHK.ahk
#Include %A_ScriptDir%\Classes\Highlighters\CSS.ahk
#Include %A_ScriptDir%\Classes\Highlighters\JS.ahk
#Include %A_ScriptDir%\Classes\Highlighters\HTML.ahk
#Include %A_ScriptDir%\Classes\class_RichCode.ahk
#Include %A_ScriptDir%\Classes\class_WinEvents.ahk
#Include %A_ScriptDir%\Includes\SciTEOutput.ahk





