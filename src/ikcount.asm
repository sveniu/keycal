.386
.model		flat,stdcall
option		casemap:none

include		\masm32\include\windows.inc
include		\masm32\include\masm32.inc
include		\masm32\include\user32.inc
include		\masm32\include\kernel32.inc
include		\masm32\include\shell32.inc
include		\masm32\include\comctl32.inc
include		\masm32\include\advapi32.inc
include		\masm32\include\Fpu.inc
include		ikcount.inc

includelib	kbhook.lib
includelib	\masm32\lib\masm32.lib
includelib	\masm32\lib\user32.lib
includelib	\masm32\lib\kernel32.lib
includelib	\masm32\lib\shell32.lib		;For tray icon.
includelib	\masm32\lib\comctl32.lib	;Progress bars.
includelib	\masm32\lib\advapi32.lib
includelib	\masm32\lib\Fpu.lib


.const
IDD_MAINDLG	equ 1001
IDC_CAPTURE	equ 1101
IDC_EXIT	equ 1102
IDC_RESET	equ 1103
IDC_ONTOP	equ 1201
MSG_ONTOP	equ WM_USER+9
ID_TIMER	equ WM_USER+10

IDC_PA		equ 2101
IDC_CA		equ 2201
IDC_CTOTAL	equ 2233
IDC_DATE	equ 3002

IDC_CSECOND	equ 3109
IDC_CMINUTE	equ 3110
IDC_CHOUR	equ 3111
IDC_CDAY	equ 3112
IDC_TRIVIA1	equ 3211
IDC_TRIVIA2	equ 3212
IDC_TRIVIA3	equ 3213
IDC_TRIVIA4	equ 3214
IDC_TRIVIA5	equ 3215

IDI_TRAY	equ 0
IDM_RESTORE	equ 4001
IDM_EXIT	equ 4002

WM_KEYBOARDHOOK	equ WM_USER+6
WM_SHELLNOTIFY	equ WM_USER+5

DlgFunc			PROTO :DWORD, :DWORD, :DWORD, :DWORD
ResetCounters		PROTO
UpdateCounters		PROTO :DWORD
InitProgressBars	PROTO :DWORD
UpdateProgressBars	PROTO :DWORD
RescaleProgressBars	PROTO :DWORD
LoadInfo		PROTO :DWORD
SaveInfo		PROTO
ResetDate		PROTO :DWORD
RefreshDateDisplay	PROTO :DWORD
GetStoredTimestamp	PROTO
GetCurrentTimestamp	PROTO
UpdateTimers		PROTO :DWORD
UpdateTrivia		PROTO :DWORD

.data
lpcbData	dd 0
RegKeyHandle	dd 0
RegKeyFolder	db "SOFTWARE\Intrikat_keycounter",0
RegValueName	db "Counters",0
RegValueName2	db "TopMost",0
RegValueName3	db "StartDate",0

Multiplier1	dd 24
Multiplier2	dd 60

HookFlag	dd FALSE
HookText	db "Capture keys",0
UnhookText	db "Stop capture",0

AppName		db "Intrikat keycounter",0
RestoreString	db "&Restore",0
ExitString 	db "E&xit Program",0
IconName	db "ikc.ico",0

DateFormat	db "%04d-%02d-%02d %02d:%02d",0

TriviaFormat1	db "- Lifting %s elephants.",0
TriviaFormat2	db "- Resting for %s secs.",0
TriviaFormat3	db "- Walking for %s secs.",0
TriviaFormat4	db "- Having sex for %s secs.",0
TriviaFormat5	db "- Running for %s secs.",0

;Stuff for the trivia section:
ForcePerKey	REAL10 0.59f
CalPerKey	REAL10 0.000506f

;Force needed to lift an elephant (5 tons):
ElephantForce	REAL10 49050.0f

;Calories burned per second for various activities:
CalRest		REAL10 29.3f
CalWalk		REAL10 82.7f
CalSex		REAL10 150.0f
CalRun		REAL10 366.7f

;Calories burned per minute for various activities:
;CalRest		REAL10 1760f
;CalWalking	REAL10 4960f
;CalSex		REAL10 9000f
;CalRun		REAL10 22000f

.data?
;MULTIPLIER	db ?
icex		INITCOMMONCONTROLSEX <>	;Structure for Controls.
note		NOTIFYICONDATA <>	;Structure for use with minimize to tray.
hInstance	dd ?
hHook		dd ?
hPopupMenu	dd ?	;Popup menu for the systray icon.

setTopMost	dd ?
topMost		dd ?

CountKPS	db 35 dup (?)	;Keys/second
CountKPM	db 35 dup (?)	;Keys/minute
CountKPH	db 35 dup (?)
CountKPD	db 35 dup (?)
CountKtotal	dd ?

Trivianum1	db 35 dup (?)	;Trivia1 (number only)
Trivianum2	db 35 dup (?)	;Trivia2 (number only)
Trivianum3	db 35 dup (?)	;Trivia3 (number only)
Trivianum4	db 35 dup (?)	;Trivia4 (number only)
Trivianum5	db 35 dup (?)	;Trivia5 (number only)
Triviastring1	db 42 dup (?)	;Trivia1 (entire string)
Triviastring2	db 42 dup (?)	;Trivia2 (entire string)
Triviastring3	db 42 dup (?)	;Trivia3 (entire string)
Triviastring4	db 42 dup (?)	;Trivia4 (entire string)
Triviastring5	db 42 dup (?)	;Trivia5 (entire string)

date		dd 6 dup (?)	;Array for storing dates.
counters	dd 33 dup (?)	;A home made counter array.
progressBars	dd 32 dup (?)	;An array holding the progress bar values.
highValue	dd ?		;Stores highest key counter value, for
				;progress bar rescaling.
DateString	db 17 dup (?)

currentTime	dd ?
storedTime	dd ?
scaleFactor	REAL10 ?
scaleResult	REAL10 ?
scaleResultDW	dd ?
progressTemp	dd ?
fpuTemp1	dd ?
fpuTemp2	dd ?

kpsecond	REAL10 ?
kpminute	REAL10 ?
kphour		REAL10 ?
kpday		REAL10 ?

.code
start:
	invoke	GetModuleHandle, NULL
	mov	hInstance, eax
	mov	icex.dwSize, sizeof INITCOMMONCONTROLSEX
	mov	icex.dwICC, 0FFFFh
        invoke	InitCommonControlsEx, ADDR icex

	invoke	DialogBoxParam, hInstance, IDD_MAINDLG, NULL, ADDR DlgFunc, NULL
	invoke	ExitProcess, NULL

DlgFunc proc USES ebx esi edi hDlg:DWORD, uMsg:DWORD, wParam:DWORD, lParam:DWORD
	LOCAL	rect:RECT
	LOCAL	pt:POINT	;Finds cursor position. For positioning the popup menu.

	.if uMsg==WM_CLOSE
		.if HookFlag==TRUE
			invoke	UninstallHook
		.endif
		invoke	SaveInfo
		invoke	KillTimer, hDlg, ID_TIMER
		invoke	EndDialog, hDlg, NULL

	.elseif uMsg==WM_INITDIALOG
		invoke	CreatePopupMenu
		mov	hPopupMenu, eax
		invoke	AppendMenu, hPopupMenu, MF_STRING, IDM_RESTORE ,ADDR RestoreString
		invoke	AppendMenu, hPopupMenu, MF_STRING, IDM_EXIT, ADDR ExitString

		invoke	LoadInfo, hDlg
		invoke	RefreshDateDisplay, hDlg
		invoke	UpdateCounters, hDlg
		invoke	InitProgressBars, hDlg
		invoke	UpdateProgressBars, hDlg
		invoke	RescaleProgressBars, hDlg
		invoke	UpdateTrivia, hDlg
		invoke	SetTimer, hDlg, ID_TIMER, 2000, NULL	;Maintains per sec statistics.
		invoke	InstallHook, hDlg
		.if eax!=NULL
			mov	HookFlag, TRUE
			invoke	SetDlgItemText, hDlg, IDC_CAPTURE, ADDR UnhookText
		.endif

	.elseif uMsg==WM_SIZE	;Handles minimizing to tray.
		.if wParam==SIZE_MINIMIZED
			mov	note.cbSize, sizeof NOTIFYICONDATA
			push	hDlg
			pop	note.hwnd
			mov	note.uID, IDI_TRAY
			mov	note.uFlags, NIF_ICON+NIF_MESSAGE+NIF_TIP
			mov	note.uCallbackMessage, WM_SHELLNOTIFY
			invoke	LoadIcon,NULL, IDI_WINLOGO;	HEYHEY!
			mov	note.hIcon, eax
			invoke	lstrcpy, ADDR note.szTip, ADDR AppName
			invoke	ShowWindow, hDlg, SW_HIDE
			invoke	Shell_NotifyIcon, NIM_ADD, ADDR note
		.endif

	.elseif uMsg==WM_KEYBOARDHOOK
;		invoke	UpdateTimers, hDlg
		invoke	UpdateTrivia, hDlg

		mov	ecx, wParam		;wParam contains the keycode.
		.if wParam==VK_SPACE
			mov	ecx, 26
		.elseif wParam==VK_RETURN
			mov	ecx, 27
		.elseif ((wParam >= VK_0 && wParam <= VK_9) || (wParam >= VK_NUMPAD0 && wParam <= VK_NUMPAD9))
			mov	ecx, 28
		.elseif (wParam >= VK_SHIFT && wParam <= VK_MENU)
			mov	ecx, 29
		.elseif (wParam >= VK_LEFT && wParam <= VK_DOWN)
			mov	ecx, 30
		.elseif (ecx < VK_A || ecx > VK_Z)	;If the key is not within A-Z, set wParam
			mov	ecx, 31			;to 31 to indicate "other" key is pressed.
		.else
			sub	ecx, VK_A		;ECX can now act as an offset.
		.endif
		mov	eax, dword ptr [counters+4*ecx]	;Fetch value from counter array.
		inc	eax				;Increase value by 1.
		mov	dword ptr [counters+4*ecx], eax	;Store value.

		add	ecx, IDC_CA			;ECX now equals the correct ID for the counter label.
		invoke	SetDlgItemInt, hDlg, ecx, eax, FALSE

		mov	eax, dword ptr [counters+4*32]	;Update the totals counter.
		inc	eax
		mov	dword ptr [counters+4*32], eax
		invoke	SetDlgItemInt, hDlg, IDC_CTOTAL, eax, FALSE
		invoke	UpdateProgressBars, hDlg
		invoke	RescaleProgressBars, hDlg

	.elseif uMsg==WM_TIMER
		.if wParam==ID_TIMER
			invoke	UpdateTimers, hDlg
		.endif

	.elseif uMsg==WM_COMMAND
		.if lParam==0
			invoke	Shell_NotifyIcon, NIM_DELETE, ADDR note
			mov	eax, wParam
			.if ax==IDM_RESTORE
				invoke	ShowWindow, hDlg, SW_RESTORE
			.else
				invoke	SendMessage, hDlg, WM_CLOSE, 0, 0
			.endif
		.endif

		.if lParam!=0
			mov	eax, wParam
			mov	edx, eax
			shr	edx, 16
			.if dx==BN_CLICKED
				.if ax==IDC_EXIT
					invoke	SendMessage, hDlg, WM_CLOSE, 0, 0
				.elseif ax==IDC_CAPTURE
					.if HookFlag==FALSE
						invoke	InstallHook, hDlg
						.if eax!=NULL
							mov	HookFlag, TRUE
							invoke	SetDlgItemText, hDlg, IDC_CAPTURE, ADDR UnhookText
						.endif
					.else
						invoke	UninstallHook
						invoke	SetDlgItemText, hDlg, IDC_CAPTURE, ADDR HookText
						mov	HookFlag, FALSE
					.endif
				.elseif ax==IDC_RESET
					invoke	ResetDate, hDlg
					invoke	ResetCounters
					invoke	UpdateCounters, hDlg
					invoke	UpdateProgressBars, hDlg
					invoke	RescaleProgressBars, hDlg
				.elseif ax==IDC_ONTOP
					.if topMost==FALSE
						mov	topMost, TRUE
						invoke	GetWindowRect, hDlg, ADDR rect
						mov	ecx, rect.right
						sub	ecx, rect.left
						mov	rect.right, ecx
						mov	ecx, rect.bottom
						sub	ecx, rect.top
						mov	rect.bottom, ecx
						invoke	SetWindowPos, hDlg, HWND_TOPMOST, rect.left,\
							rect.top, rect.right, rect.bottom, SWP_SHOWWINDOW
						invoke	SendDlgItemMessage, hDlg, IDC_ONTOP,BM_SETCHECK, 1, 0
					.else
						mov	topMost, FALSE
						invoke	GetWindowRect, hDlg, ADDR rect
						mov	ecx, rect.right
						sub	ecx, rect.left
						mov	rect.right, ecx
						mov	ecx, rect.bottom
						sub	ecx, rect.top
						mov	rect.bottom, ecx
						invoke	SetWindowPos, hDlg, HWND_NOTOPMOST, rect.left,\
							rect.top, rect.right, rect.bottom, SWP_SHOWWINDOW
						invoke	SendDlgItemMessage, hDlg, IDC_ONTOP,BM_SETCHECK, 0, 0
					.endif
				.endif
			.endif
		.endif
	.elseif uMsg==WM_SHELLNOTIFY
		.if wParam==IDI_TRAY
			.if lParam==WM_RBUTTONDOWN
				invoke	GetCursorPos, ADDR pt
				invoke	TrackPopupMenu, hPopupMenu, TPM_RIGHTALIGN, pt.x, pt.y, NULL, hDlg, NULL
			.elseif lParam==WM_LBUTTONDBLCLK
				invoke	SendMessage, hDlg, WM_COMMAND, IDM_RESTORE,0
			.endif
		.endif
	
	.else
		mov	eax, FALSE
		ret
	.endif

	mov	eax, TRUE
	ret

DlgFunc endp



;Stuff for the trivia section:
;ForcePerKey	REAL10 0.59f
;CalPerKey	REAL10 0.000506f

;Force needed to lift an elephant (5 tons):
;ElephantForce	REAL10 49050.0f

;Calories burned per second for various activities:
;CalRest		REAL10 29.3f
;CalWalk	REAL10 82.7f
;CalSex		REAL10 150.0f
;CalRun		REAL10 366.7f


UpdateTrivia proc hDlg:DWORD
	mov	eax, dword ptr [counters+4*32]	;HMM!
	mov	dword ptr [CountKtotal], eax

	;Find how many elephants are lifted:
	finit
	fld	tbyte ptr [ForcePerKey]		;->st(0) = force per key.
	fimul	dword ptr [CountKtotal]		;->st(0) = total force exerted.
	fld	tbyte ptr [ElephantForce]	;->st(0) = elephantforce, st(1) = total force
	fdivp	st(1),st			;->st(0) = elephants lifted, st(1) = unused
	invoke	FpuFLtoA, 0, 3, ADDR Trivianum1, SRC1_FPU or SRC2_DIMM
	invoke	wsprintf, ADDR Triviastring1, ADDR TriviaFormat1, ADDR Trivianum1
	invoke	SetDlgItemText, hDlg, IDC_TRIVIA1, ADDR Triviastring1

	;Find how many seconds you've been resting: (cps = calories per second)
	finit
	fld	tbyte ptr [CalPerKey]		;->st(0) = calories per key.
	fimul	dword ptr [CountKtotal]		;->st(0) = total calories used.
	fld	tbyte ptr [CalRest]		;->st(0) = cps resting, st(1) = total cals used.
	fdivp	st(1),st			;->st(0) = ?, st(1) = ?
	invoke	FpuFLtoA, 0, 3, ADDR Trivianum2, SRC1_FPU or SRC2_DIMM
	invoke	wsprintf, ADDR Triviastring2, ADDR TriviaFormat2, ADDR Trivianum2
	invoke	SetDlgItemText, hDlg, IDC_TRIVIA2, ADDR Triviastring2

	;Find how many seconds you've been walking: (cps = calories per second)
	finit
	fld	tbyte ptr [CalPerKey]		;->st(0) = calories per key.
	fimul	dword ptr [CountKtotal]		;->st(0) = total calories used.
	fld	tbyte ptr [CalWalk]		;->st(0) = cps resting, st(1) = total cals used.
	fdivp	st(1),st			;->st(0) = ?, st(1) = ?
	invoke	FpuFLtoA, 0, 3, ADDR Trivianum3, SRC1_FPU or SRC2_DIMM
	invoke	wsprintf, ADDR Triviastring3, ADDR TriviaFormat3, ADDR Trivianum3
	invoke	SetDlgItemText, hDlg, IDC_TRIVIA3, ADDR Triviastring3

	;Find how many seconds you've been resting: (cps = calories per second)
	finit
	fld	tbyte ptr [CalPerKey]		;->st(0) = calories per key.
	fimul	dword ptr [CountKtotal]		;->st(0) = total calories used.
	fld	tbyte ptr [CalSex]		;->st(0) = cps resting, st(1) = total cals used.
	fdivp	st(1),st			;->st(0) = ?, st(1) = ?
	invoke	FpuFLtoA, 0, 3, ADDR Trivianum4, SRC1_FPU or SRC2_DIMM
	invoke	wsprintf, ADDR Triviastring4, ADDR TriviaFormat4, ADDR Trivianum4
	invoke	SetDlgItemText, hDlg, IDC_TRIVIA4, ADDR Triviastring4

	;Find how many seconds you've been resting: (cps = calories per second)
	finit
	fld	tbyte ptr [CalPerKey]		;->st(0) = calories per key.
	fimul	dword ptr [CountKtotal]		;->st(0) = total calories used.
	fld	tbyte ptr [CalRun]		;->st(0) = cps resting, st(1) = total cals used.
	fdivp	st(1),st			;->st(0) = ?, st(1) = ?
	invoke	FpuFLtoA, 0, 3, ADDR Trivianum5, SRC1_FPU or SRC2_DIMM
	invoke	wsprintf, ADDR Triviastring5, ADDR TriviaFormat5, ADDR Trivianum5
	invoke	SetDlgItemText, hDlg, IDC_TRIVIA5, ADDR Triviastring5






	ret
UpdateTrivia endp

UpdateTimers proc hDlg:DWORD
	invoke	GetStoredTimestamp
	invoke	GetCurrentTimestamp

	mov	eax, dword ptr [counters+4*32]	;HMM!
	mov	dword ptr [CountKtotal], eax

	finit
	fild	dword ptr [currentTime]
	fisub	dword ptr [storedTime]	;->st(0) == uptime in seconds.
	fidivr	dword ptr [CountKtotal]	;->st(0) == keys per second.
	invoke	FpuFLtoA, 0, 2, ADDR CountKPS, SRC1_FPU or SRC2_DIMM
	fimul	dword ptr [Multiplier2]
	invoke	FpuFLtoA, 0, 2, ADDR CountKPM, SRC1_FPU or SRC2_DIMM
	fimul	dword ptr [Multiplier2]
	invoke	FpuFLtoA, 0, 2, ADDR CountKPH, SRC1_FPU or SRC2_DIMM
	fimul	dword ptr [Multiplier1]
	invoke	FpuFLtoA, 0, 2, ADDR CountKPD, SRC1_FPU or SRC2_DIMM

	invoke	SetDlgItemText, hDlg, IDC_CSECOND, ADDR CountKPS
	invoke	SetDlgItemText, hDlg, IDC_CMINUTE, ADDR CountKPM
	invoke	SetDlgItemText, hDlg, IDC_CHOUR, ADDR CountKPH
	invoke	SetDlgItemText, hDlg, IDC_CDAY, ADDR CountKPD
	ret
UpdateTimers endp

ResetCounters proc
	xor	ecx, ecx
	@@:
		mov	dword ptr [counters+4*ecx], 0
		inc	ecx
		cmp	ecx, 33
		jl	@B
	ret
ResetCounters endp

UpdateCounters proc hDlg:DWORD
	xor	ecx, ecx
	@@:
		mov	eax, dword ptr [counters+4*ecx]	;Fetch value of counter.
		add	ecx, IDC_CA		;ECX now equals the correct ID for the counter label.
		push	ecx			;ECX is destroyed in the invoke.
		invoke	SetDlgItemInt, hDlg, ecx, eax, FALSE
		pop	ecx
		sub	ecx, IDC_CA		;Now ECX is a normal counter.
		inc	ecx
		cmp	ecx, 33		;Update totals too.
		jl	@B
	ret
UpdateCounters endp

InitProgressBars proc hDlg:DWORD
	xor	ecx, ecx
	@@:
		add	ecx, IDC_PA
		push	ecx
		invoke	SendDlgItemMessage,hDlg,ecx,PBM_SETRANGE32,0,10000
		pop	ecx
		sub	ecx, IDC_PA
		inc	ecx
		cmp	ecx, 32
		jl	@B
	ret
InitProgressBars endp

;The process bars show relative count values in regards
;to the total key count. In other words, the bars show
;the statistical distribution of the key presses.
UpdateProgressBars proc hDlg:DWORD
	LOCAL	tenK:DWORD
	mov	dword ptr [tenK], 10000
	xor	ecx, ecx
	@@:
		mov	eax, dword ptr [counters+4*ecx]	;Fetch value of counter.
		mov	ebx, dword ptr [counters+4*32]	;Fetch the total count.
		.if ebx==0
			mov	eax, 0		;This omits division by zero.
		.else
			mov	dword ptr [fpuTemp1], eax
			mov	dword ptr [fpuTemp2], ebx

			finit				;Initialize FPU
			fild	dword ptr [fpuTemp1]	;->st(0) = value of counter.
			fidiv	dword ptr [fpuTemp2]	;->st(0) = scale factor.
			fimul	dword ptr [tenK]	;->st(0) = 10000*scale factor.
			fist	dword ptr [progressTemp]

			mov	eax, dword ptr [progressTemp]
		.endif
		mov	dword ptr [progressBars+4*ecx], eax	;Store progress bar value.

		inc	ecx
		cmp	ecx, 33		;Totals has no progress bar.
		jl	@B
	ret
UpdateProgressBars endp

;To fill out the progress bars more nicely, they are rescaled
;based on the bar with the highest value. First we find the
;bar with the highest value, then find the rescale factor, and
;then update all bars.
RescaleProgressBars proc hDlg:DWORD
	LOCAL	tenK:DWORD
	mov	dword ptr [tenK], 10000
	xor	ecx, ecx
	mov	highValue, 0
	@@:
		mov	eax, dword ptr [progressBars+4*ecx]	;Fetch value of progress bar.
		.if eax > highValue
			mov	dword ptr [highValue], eax
		.endif
		inc	ecx
		cmp	ecx, 33
		jl	@B

	.if highValue==0
		mov	dword ptr [highValue], 10000	;This omits division by zero.
	.endif

	;Execute division. 10000 / highest value = scalefactor.
	finit
	fild	dword ptr [tenK]	;->st(0) == 10000
	fidiv	dword ptr [highValue]	;->st(0) == scalefactor
	fstp	tbyte ptr [scaleFactor]
	
	;For each progress bar value, multiply by the scalefactor.
	xor	ecx, ecx
	@@:
		mov	eax, dword ptr [progressBars+4*ecx]
		mov	dword ptr [fpuTemp1], eax

		;Calculate new bar values based on the scalefactor.
		fld	tbyte ptr [scaleFactor]
		fimul	dword ptr [fpuTemp1]	;->st(0) == new value of prog.bar.
		fistp	dword ptr [scaleResultDW]
		mov	eax, dword ptr [scaleResultDW]

		add	ecx, IDC_PA
		push	ecx
		invoke	SendDlgItemMessage, hDlg, ecx, PBM_SETPOS, eax, 0
		pop	ecx
		sub	ecx, IDC_PA
		inc	ecx
		cmp	ecx, 33
		jl	@B
	ret
RescaleProgressBars endp

;LoadDate proc
;LoadDate endp

;Loads the counters from the registry.
LoadInfo proc hDlg:DWORD
	invoke	RegOpenKeyEx,HKEY_LOCAL_MACHINE,ADDR RegKeyFolder,0,\
		KEY_QUERY_VALUE,ADDR RegKeyHandle
	.if eax==ERROR_SUCCESS
		mov	lpcbData, 132	;Size of data to store.
		invoke	RegQueryValueEx,RegKeyHandle,ADDR RegValueName,0,NULL,
			ADDR counters,ADDR lpcbData

		mov	lpcbData, 4	;Size of data to store.
		invoke	RegQueryValueEx,RegKeyHandle,ADDR RegValueName2,0,NULL,
			ADDR setTopMost,ADDR lpcbData
	;	invoke	RegCloseKey,RegKeyHandle
		.if setTopMost==TRUE
			mov	topMost, FALSE
			invoke	SendMessage, hDlg, WM_COMMAND, IDC_ONTOP, 1
		.endif

		mov	lpcbData, 24	;Size of data to store.
		invoke	RegQueryValueEx,RegKeyHandle,ADDR RegValueName3,0,NULL,
			ADDR date,ADDR lpcbData
		invoke	RegCloseKey,RegKeyHandle
	.else
		invoke	RegCreateKeyEx,HKEY_LOCAL_MACHINE,ADDR RegKeyFolder,0,\
			0,REG_OPTION_NON_VOLATILE,KEY_SET_VALUE,\
			0,ADDR RegKeyHandle,0
;		invoke	RegOpenKeyEx,HKEY_LOCAL_MACHINE,ADDR RegKeyFolder,0,\
;			KEY_QUERY_VALUE,ADDR RegKeyHandle
		invoke	ResetDate, hDlg
		invoke	ResetCounters
		invoke	RegSetValueEx,RegKeyHandle,ADDR RegValueName,0,REG_BINARY,ADDR counters,sizeof counters
		invoke	RegSetValueEx,RegKeyHandle,ADDR RegValueName2,0,REG_DWORD,ADDR topMost,sizeof topMost
		invoke	RegSetValueEx,RegKeyHandle,ADDR RegValueName3,0,REG_BINARY,ADDR date,sizeof date
		invoke	RegCloseKey,RegKeyHandle
	.endif
	ret
LoadInfo endp

;Saves all info to the registry
SaveInfo proc
	invoke	RegCreateKeyEx,HKEY_LOCAL_MACHINE,ADDR RegKeyFolder,0,\
		0,REG_OPTION_NON_VOLATILE,KEY_SET_VALUE,\
		0,ADDR RegKeyHandle,0
	invoke	RegSetValueEx,RegKeyHandle,ADDR RegValueName,0,REG_BINARY,ADDR counters,sizeof counters
	invoke	RegSetValueEx,RegKeyHandle,ADDR RegValueName2,0,REG_DWORD,ADDR topMost,sizeof topMost
	invoke	RegSetValueEx,RegKeyHandle,ADDR RegValueName3,0,REG_BINARY,ADDR date,sizeof date
	invoke	RegCloseKey,RegKeyHandle
	ret
SaveInfo endp

ResetDate proc hDlg:DWORD
	LOCAL	stm:SYSTEMTIME

	invoke	GetLocalTime,ADDR stm
	movzx	eax, stm.wYear
	mov	dword ptr [date], eax
	movzx	eax, stm.wMonth
	mov	dword ptr [date+4], eax
	movzx	eax, stm.wDay
	mov	dword ptr [date+8], eax
	movzx	eax, stm.wHour
	mov	dword ptr [date+12], eax
	movzx	eax, stm.wMinute
	mov	dword ptr [date+16], eax
	movzx	eax, stm.wSecond
	mov	dword ptr [date+20], eax

	invoke	RefreshDateDisplay, hDlg

	ret
ResetDate endp

RefreshDateDisplay proc hDlg:DWORD
	LOCAL	tmpstr:DWORD
	LOCAL	year:DWORD
	LOCAL	month:DWORD
	LOCAL	day:DWORD
	LOCAL	hour:DWORD
	LOCAL	minute:DWORD

	mov	eax, dword ptr [date]
	mov	year, eax
	mov	eax, dword ptr [date+4]
	mov	month, eax
	mov	eax, dword ptr [date+8]
	mov	day, eax
	mov	eax, dword ptr [date+12]
	mov	hour, eax
	mov	eax, dword ptr [date+16]
	mov	minute, eax

	invoke wsprintf, ADDR DateString, ADDR DateFormat, year, month, day, hour, minute

	;mov	tmpstr, cat$(tmpstr,year,"-",month,"-",day," ",hour,":",minute)
	mov	byte ptr [DateString+16], 0	;Ensure null-terminating. wsprintf does not.
	invoke	SetDlgItemText, hDlg, IDC_DATE, ADDR DateString

	ret
RefreshDateDisplay endp

GetStoredTimestamp proc
	LOCAL	year:DWORD
	LOCAL	month:DWORD
	LOCAL	day:DWORD
	LOCAL	hour:DWORD
	LOCAL	minute:DWORD
	LOCAL	second:DWORD

	LOCAL	ryear:REAL10
	LOCAL	rmonth:REAL10
	LOCAL	rday:REAL10
	LOCAL	rhour:REAL10
	LOCAL	rminute:REAL10

	mov	eax, dword ptr [date]
	sub	eax, 1970
	mov	year, eax
	invoke	FpuMul, year, 31446926, ADDR ryear, SRC1_DIMM or SRC2_DIMM; or DEST_FPU

	mov	eax, dword ptr [date+4]
	mov	month, eax
	invoke	FpuMul, month, 2620577, ADDR rmonth, SRC1_DIMM or SRC2_DIMM; or DEST_FPU

	mov	eax, dword ptr [date+8]
	mov	day, eax
	invoke	FpuMul, day, 86400, ADDR rday, SRC1_DIMM or SRC2_DIMM; or DEST_FPU

	mov	eax, dword ptr [date+12]
	mov	hour, eax
	invoke	FpuMul, hour, 3600, ADDR rhour, SRC1_DIMM or SRC2_DIMM; or DEST_FPU

	mov	eax, dword ptr [date+16]
	mov	minute, eax
	invoke	FpuMul, minute, 60, ADDR rminute, SRC1_DIMM or SRC2_DIMM; or DEST_FPU

	mov	eax, dword ptr [date+20]
	mov	second, eax

	invoke	FpuAdd, ADDR ryear, ADDR rmonth, 0, SRC1_REAL or SRC2_REAL or DEST_FPU
	invoke	FpuAdd, ADDR rday, 0, 0, SRC1_REAL or SRC2_FPU or DEST_FPU
	invoke	FpuAdd, ADDR rhour, 0, 0, SRC1_REAL or SRC2_FPU or DEST_FPU
	invoke	FpuAdd, ADDR rminute, 0, 0, SRC1_REAL or SRC2_FPU or DEST_FPU
	invoke	FpuAdd, second, 0, 0, SRC1_DIMM or SRC2_FPU or DEST_FPU
	invoke	FpuRound, 0, ADDR storedTime, SRC1_FPU or DEST_IMEM

	mov	eax, dword ptr [storedTime]
	xor	eax, eax

	ret
GetStoredTimestamp endp

GetCurrentTimestamp proc
	LOCAL	stm:SYSTEMTIME
	LOCAL	year:DWORD
	LOCAL	month:DWORD
	LOCAL	day:DWORD
	LOCAL	hour:DWORD
	LOCAL	minute:DWORD
	LOCAL	second:DWORD

	LOCAL	ryear:REAL10
	LOCAL	rmonth:REAL10
	LOCAL	rday:REAL10
	LOCAL	rhour:REAL10
	LOCAL	rminute:REAL10

	invoke	GetLocalTime,ADDR stm

	movzx	eax, stm.wYear
	sub	eax, 1970
	mov	dword ptr [year], eax
	invoke	FpuMul, ADDR year, 31446926, ADDR ryear, SRC1_DMEM or SRC2_DIMM; or DEST_FPU

	movzx	eax, stm.wMonth
	mov	dword ptr [month], eax
	invoke	FpuMul, ADDR month, 2620577, ADDR rmonth, SRC1_DMEM or SRC2_DIMM; or DEST_FPU

	movzx	eax, stm.wDay
	mov	dword ptr [day], eax
	invoke	FpuMul, ADDR day, 86400, ADDR rday, SRC1_DMEM or SRC2_DIMM; or DEST_FPU

	movzx	eax, stm.wHour
	mov	dword ptr [hour], eax
	invoke	FpuMul, ADDR hour, 3600, ADDR rhour, SRC1_DMEM or SRC2_DIMM; or DEST_FPU

	movzx	eax, stm.wMinute
	mov	dword ptr [minute], eax
	invoke	FpuMul, ADDR minute, 60, ADDR rminute, SRC1_DMEM or SRC2_DIMM; or DEST_FPU

	movzx	eax, stm.wSecond
	mov	second, eax

	invoke	FpuAdd, ADDR ryear, ADDR rmonth, 0, SRC1_REAL or SRC2_REAL or DEST_FPU
	invoke	FpuAdd, ADDR rday, 0, 0, SRC1_REAL or SRC2_FPU or DEST_FPU
	invoke	FpuAdd, ADDR rhour, 0, 0, SRC1_REAL or SRC2_FPU or DEST_FPU
	invoke	FpuAdd, ADDR rminute, 0, 0, SRC1_REAL or SRC2_FPU or DEST_FPU
	invoke	FpuAdd, second, 0, 0, SRC1_DIMM or SRC2_FPU or DEST_FPU
	invoke	FpuRound, 0, ADDR currentTime, SRC1_FPU or DEST_IMEM

	mov	eax, dword ptr [currentTime]
	xor	eax, eax

	ret
GetCurrentTimestamp endp

end start
