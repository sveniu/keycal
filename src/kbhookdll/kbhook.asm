;This DLL installs a system-wide keyboard hook.
;It is based heavily on Iczelion's tutorial on
;Windows hooks.

.386
.model		flat, stdcall
option		casemap:none

include		\masm32\include\windows.inc
include		\masm32\include\kernel32.inc
includelib	\masm32\lib\kernel32.lib
include		\masm32\include\user32.inc
includelib	\masm32\lib\user32.lib

.const
WM_KEYBOARD	equ WM_USER+6

.data
hInstance	dd 0

.data?
hHook	dd ?
hWnd	dd ?

.code
DllEntry proc hInst:HINSTANCE, reason:DWORD, reserved1:DWORD
	push	hInst
	pop	hInstance
	mov	eax, TRUE
	ret
DllEntry Endp

KeyboardProc proc nCode:DWORD, wParam:DWORD, lParam:DWORD
	invoke	CallNextHookEx, hHook, nCode, wParam, lParam
	mov	ebx, wParam	;Contains the virtual keycode.
	mov	edx, lParam	;Contains additional keypress info.

	and	edx, 0C0000000h	;Check if the two leftmost bits are unset. They indicate both
				;that a key was pressed, and that the previous state of the
				;key was 'unpressed'. Holding the key down will not generate
				;a bunch of messages - only one. For more info, see
				;http://tinyurl.com/s0u9 (MSDN Keyboard Input reference).

	.if edx == 0
		invoke	PostMessage, hWnd, WM_KEYBOARD, ebx, 0
	.endif
	xor	eax, eax
	ret
KeyboardProc endp

InstallHook proc hwnd:DWORD
	push	hwnd
	pop	hWnd
	invoke	SetWindowsHookEx, WH_KEYBOARD, ADDR KeyboardProc, hInstance, NULL
	mov	hHook, eax
	ret 
InstallHook endp

UninstallHook proc
	invoke	UnhookWindowsHookEx, hHook
	ret
UninstallHook endp

End DllEntry
