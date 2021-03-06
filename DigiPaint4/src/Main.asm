*** DigiPaint 3.0 *** main.asm module
*** This program was written by Jamie Purdon (Cleveland, Ohio) for
*** NewTek (Topeka, Kansas) to market as an upgrade to DigiPaint.
*** This program's (this section and all modules on disk) code (ALL forms) is
***	Copyright � 1989  by  Jamie D. Purdon  (Cleveland, Ohio)
*** Versions delivered to NewTek and mass marketted are ALSO
***	Copyright � 1989  by  NewTek  (Topeka, Kansas)

NOTICE:	dc.b $0a,0,0,0 ;just lf ;$0d	;just lf,cr
NOTICELen	equ *-NOTICE

HIPRI	set 1 ;1=workbench 2=better/best?
MINHT	set 20	;MAY23...minimum picture ht

	xdef _main		;startup.o 'jsr's here
	xdef AutoMove		;moves the bigpicture based on mouse
	xdef CheckIDCMP		;returns zero//NULL if no mesg
	xdef CloseBigPic
	xdef CloseScreenRoutine
	xdef CloseWindowRoutine
	xdef CloseWindowAndScreen
	xdef cva2i ;a0=string, returns d0=#, a0 just past # (DESTROYS D1)
	xdef DoAction		;arg d0=action code
	xdef DoInlineAction	;arg longword inline before caller's rts
	xdef EndIDCMP	;turn off messages (only, don't close window etc)
	xdef ExecSetTaskPri	;argD0=new priority, returns d0=old pri BLOWS A0
	xdef FixInterLace	;iffload, after automove call, gadgetrtns//undo
	xdef KeyRoutine	;only called by 'CANCEL-CHECK-GLUE' code
	xdef key_rtn_dn
	xdef key_rtn_lt
	xdef key_rtn_rt
	xdef key_rtn_up
	xdef OpenBigPic		;alloc's chip, opens 'bigpicture' screen
	xdef ResetIDCMP		;sets up normal idcmp message events
	xdef ReturnMessage	;EVERYONE goes thru HERE for idcmp "ReplyMsg"s
	xdef ScanIDCMP	;d1=i'class to look for, returns ZERO found, notequal for notfnd
	xdef ResetPriority
	xdef ForceDefaultPriority	;mousertns...force 'foregrnd' MAY14
	;xdef SetDefaultPriority	;setsit to zero, if not background
	xdef SetHigherPriority	;generally quicker, for long stuff (noone?)
	xdef SetLowerPriority	;checkcancel, canceler.o, uses this

	include "ds:basestuff.i"
	include "lotsa-includes.i"
	include "intuition/intuition.i"
	include "intuition/intuitionbase.i"	;ib_activewindow
	include "exec/memory.i" ;needed for AllocMem requirements
	include "exec/ports.i"
	include "libraries/dosextens.i" ;for pr_{Process} structure
	include "graphics/gfxbase.i"
	include	"ds:minimalrex.i"

GWIDCMP   set MENUVERIFY!MENUPICK!MOUSEMOVE!GADGETDOWN!GADGETUP!RAWKEY

GWIDCMP	set GWIDCMP!MOUSEBUTTONS	;MAY16 to handle 'brush sizer'

TOOLIDCMP set MOUSEBUTTONS!MOUSEMOVE!GADGETUP

;JUNE;BPIDCMP   set MOUSEBUTTONS!MOUSEMOVE ;removed LATE May22;!RAWKEY	;ACTIVEWINDOW!RAWKEY
BPIDCMP   set MOUSEBUTTONS!MOUSEMOVE!RAWKEY	;ACTIVEWINDOW
	;note: see main.key.i for...
	;bigpic rawkeys only good when in 'special' modes, line,rect,etc

	;note: want(?) 'rawkeys' on hamtools so can 'close toolbox' for picking

	xref IntServer_
	xref Ticker_
	include "exec/interrupts.i"
	include "hardware/intbits.i"

	xref ActionCode_
	xref BB_BitMap_
	xref BigNewScreen_
	xref BigNewWindow_
	xref BigPicHt_
	xref BigPicWt_
	xref BigPicWt_W_
	xref bmhd_pageheight_
	xref bmhd_pagewidth_
	xref bmhd_rastheight_
	xref bmhd_rastwidth_
	xref bmhd_xaspect_
	xref bmhd_yaspect_
	xref bytes_per_row_
	xref bytes_row_less1_
	xref CAMG_
	xref CPUnDoBitMap_
	xref SwapBitMap_
	xref DirNameLen_	;var. program name, 1st part is dirname
	xref dosCmdLen_		;scratch.o 2 longwords for len, adr
	xref FileHandle_
	xref FilenameBuffer_
	xref FlagBitMapSaved_	;automove uses this to see if go slow
	xref FlagCutPaste_
	xref FlagDisplayBeep_
	xref FlagFrbx_
	xref FlagLace_
	xref FlagLaceNEW_
	xref FlagMagnifyStart_
	xref FlagNeedIntFix_	;interlace fixzit, handled by msg code
	xref FlagNeedMagnify_
	xref FlagNeedMakeScr_
	xref FlagNeedShowPaste_	;need 'new' brush display
	xref FlagNeedRepaint_
	xref FlagNeedText_	;if scrollvport get called, redisplay coords
	xref FlagNeedGadRef_	;need gadget refresh?
	xref FlagOpen_
	xref FlagPick_
	xref FlagQuit_
	xref FlagRedrawPal_	;used by/for openhamtools
	xref FlagRefHam_
	xref FlagRepainting_
	xref FlagSingleBit_	;indicates 'single bitplane undo' of cutpaste
	xref FlagSizer_
	xref GWindowPtr_	;gadgets window on HIRES screen
	xref Initializing_	;(103*$01000000) ;error103,nomemory ;0=no,-1=yes
	xref lwords_row_less1_
	xref MsgPtr_
	xref MScreenPtr_	;magnify screen
	xref MWindowPtr_	;magnify window (blown up pic) on mag scr
	xref NewSizeX_
	xref NewSizeY_
	xref NormalWidth_
	xref NormalHeight_
	xref OnlyPort_		;this is a STRUCT on the basepage
	xref OSKillNest_	;main.o;nest/unnest kill en/disable overscan
	xref our_task_
	xref PasteBitMap_
	xref PasteMaskBitMap_
	xref pixels_row_less1_
	xref PlaneSize_	;number of bytes in a bitplane (8000 or 16000)
	xref ProgNameLen_	;word size
	xref ProgNamePtr_	;ptr to ascii, now (SCANNABLE FOR DIR)
	xref ProgramNameBuffer_	;<=60 bytes filled in by main.cmd.i (@ end)
	xref RastPortPtr_	;RastPort for this window
	xref RememberKey_
	xref saveexecwindow_	;JULY07
	xref SBMPlane1_
	xref ScreenBitMap_
	xref ScreenBitMap_Planes_
	xref ScreenPtr_
	xref startup_taskpri_
	xref UnDoBitMap_
	xref UnDoBitMap_Planes_
	xref TextAttr_
	xref ToolBitMap_
	xref ToolWindowPtr_	;gadgets window on ham tool screen
	xref TScreenPtr_
	xref Where_We_Came_From_
	;xref WindowIDCMP_
	xref WindowPtr_
	xref words_row_less1_
	xref XAspect_
	xref XTScreenPtr_
	xref Zeros_

	xref _WBenchArgName_

;port=INITPORTE(),exec
;D0		   A6	;<<== returns	;z=error
INITPORTE:	MACRO
		moveq	#-1,D0
		CALLIB	Exec,AllocSignal  ;D0=return'd signal NUMBER
		tst.l	D0	;-1 indicates bad signal (neg/minus)
		bpl.s	cp_sigok
cp_nomemory:	moveq	#0,D0
		bra.s	end_initp		rts

cp_sigok:	move.b	D0,MP_SIGBIT(a2)
		move.b	#PA_SIGNAL,MP_FLAGS(a2)
		;move.b	#PA_IGNORE,MP_FLAGS(a2)	;dont take time to signal
		move.b	#NT_MSGPORT,LN_TYPE(a2)
		clr.b	LN_PRI(a2)	;port struct = lnode+portstuff+mlist
		move.l	our_task_(BP),MP_SIGTASK(a2) ;our_task setup in startup
		lea	MP_MSGLIST(a2),A0  ;Point to list header
		NEWLIST	A0		;Init new list macro
		move.l	a2,D0		;ensure non-zero return flag
end_initp:
	ENDM	;	rts

 xref StdOut_	;may01
PRTMSG:	MACRO ;areg-ptr-to-message,#len-of-msg
	move.l	\1,-(sp)	;adr of name
	CALLIB	DOS,Output	;get file handle, already open (cli window)
	move.l	(sp)+,d2	;d2=original string arg
	move.l	D0,StdOut_(BP)
	move.l	D0,-(sp)	;save 'stdout' file handle
	beq.s	nofileh\@	;noprint if no stdout (run from wbench?)
	move.l	D0,d1		;d1=output file handle
	moveq.l	#\2,d3		;d2=length of string
	CALLIB	SAME,Write	;>>>print it

	move.l	(sp),d1		;d1=output file handle
	lea	NOTICE(pc),a2
	move.l	a2,d2		;d2='cr,lf,...'
	moveq.l	#1,d3	;may02#NOTICELen,d3	;d3=length of 'cr,lf...'
	CALLIB	SAME,Write	;>>>print it

nofileh\@:
	lea	4(sp),sp
	ENDM

;**** CODE START ****;

	cnop 0,4	;longword align so no-one comp-lains
StartQuitting:
	;;;bsr	KillMyLevel6		;spurious code killer

		;JUNE04
	xjsr	SafeEndFonts	;textstuff.o...might clear quit flag
	;tst.b	FlagQuit_(BP)	;start quitting AFTER msg queue empties
	bne	EventLoop	;restart if subr SafeEndFonts "not ok"

	bsr	EndIDCMP		;stop intui-msgs NOW
	bsr	SetDefaultPriority	;close @ "normal" speed
	xjsr	CloseSkinny		;window, if any, for rgb # display
	xjsr	EndMagnify		;DOmagnify.o
	xjsr	RemoveXGadgets		;so cant gadget click while printer wait
	;JUNE04;xjsr	EndFonts		;textstuff.o

Abort:
;	move.l	our_task_(BP),A0
;	move.l	saveexecwindow_(BP),d0
;	beq.s	1$
;	move.l	d0,pr_WindowPtr(A0)	;for system requesters
;1$
	xjsr	AbortPrint		;printrtns.o
	xjsr	EndPrint
	bsr	CloseBigPic
	xjsr	EndMenu			;gadgetrtns.o
	xjsr	CloseConsoleBase	;printrtns.o
	xjsr	DeleteDirsaveLock	;dirrtns.o;delete "parent"/old lock
	xjsr	CleanupDirRemember	;dirtns.o, clear saved "dir" fib's
	xjsr	CleanupDiskObject	;iconstuff.o
Abort_nomem:
		;JULY07
	move.l	our_task_(BP),A0
;	move.l	saveexecwindow_(BP),d0
;	beq.s	1$
;	move.l	d0,pr_WindowPtr(A0)	;for system requesters
;1$
	move.l	saveexecwindow_(BP),pr_WindowPtr(A0)

	xjsr	GoodByeHamTool		;ham palette
	CALLIB	Intuition,OpenWorkBench	;MAY12 open it BEFORE closing all scrs
	xjsr	GoodByeToolWindows	;tool.o close hires and ham palette
	xjsr	FreeAllMemory		;memories.o, frees RememberKey list

;may14;	xjsr	CleanupMemory	;may13

	;NO NEED?;CALLIB	Intuition,OpenWorkBench
	bsr	OffInt		;remove interrupt server

	lea	OnlyPort_(BP),a1
	CALLIB	Exec,RemPort	;remove our 'only' message port
	lea	OnlyPort_(BP),a1

	moveq	#0,D0
	move.b	MP_SIGBIT(a1),D0
	CALLIB	SAME,FreeSignal	;a6=execbase
abort_portdone:

	move.l	startup_taskpri_(BP),D0
	bsr	ExecSetTaskPri

	xjsr	CleanupMemory	;may14

	move.l	Where_We_Came_From_(BP),a7	;fix stack back to entry point
	move.b  Initializing_(BP),D0	;system error code return (103nomem)
	ext.w	d0
	ext.l	d0
	rts				;for good.(whew!).(return to startup.)

_main:	move.l	a7,Where_We_Came_From_(BP)	;save our stack

	bsr	SetDefaultPriority	;main.o;returns old pri in D0 BLOWS A0/D0
	move.l	D0,startup_taskpri_(BP) ;restore original pri when done
	bsr	ExecSetTaskPri		;restore original pri "now", too
	move.b	#103,Initializing_(BP)	;error103,nomemory
	xjsr	InitScratch		;scratch.o

	;PRTMSG NOTICE		;version #, CopyRight to cli(if any) output

	lea	OnlyPort_(BP),a2
	INITPORTE		;sets A6:=execbase, gets signal, inits portA2
	beq	abort_portdone
	lea	(a2),a1			;port (again, for adding)
	lea	ProgramNameBuffer_(BP),a0	;port name is now program name
	move.l	A0,LN_NAME(a1)		;broadcast our port name now...
	CALLIB	SAME,AddPort		;"hey system, *here* I am!"

	include "ds:main.cmd.i"	;setup ScreenHeight,FlagLace,bmhd_w/h,ns_VMode

		;KLUDGE....
	;xjsr	SupBottomAscii ;showtxt.o ;rtns a0=already sup text bottom row
	;move.b	#$0a,46(a0)
	;move.b	#$0d,47(a0)
	;PRTMSG a0,80 		;version #, CopyRight to cli(if any) output



	;move.l	#BPIDCMP,WindowIDCMP_(BP)	;STARTUP/default

		;disable system ("insert disk...")requesters...JULY06
	move.l	our_task_(BP),A0		;startup.o
	move.l	pr_WindowPtr(A0),D0		;current/original err screen
	move.l	D0,saveexecwindow_(BP)		;...restore it later
	move.l	#-1,pr_WindowPtr(A0)		;no window now, auto-cancels



	xjsr	ForceToolWindow  ;first time open tool windows, disabled 'idcmp
	tst.l	GWindowPtr_(BP)		;hires gadget window get opened?
	beq	Abort_nomem

	;june28;xjsr	ByeByeWorkBench		;memories.o May12'89
	CALLIB	Intuition,CloseWorkBench	;june28...explicit call here

	bsr OnInt ;adds vertb intserver, do after ProgNamePtr setup in main.cmd

	;APRIL27;xjsr	SetAltPointerWait	;1st time//startup sup 'sleepycloud'
	xjsr	AllocDetermineTable	;memories.asm;getitifwedonthave it
	beq	Abort_nomem

;	move.l	our_task_(BP),A0		;startup.o
;	move.l	pr_WindowPtr(A0),D0		;current/original err screen
;	move.l	D0,saveexecwindow_(BP)		;...restore it later
;	move.l	GWindowPtr_(BP),pr_WindowPtr(A0) ;hires screen for SYSTEM MSGS

	xjsr	InitShortMulTable	;memories.o, shortmultable for paintcode
	;beq	Abort			;_nomem
	beq	Abort_nomem

	;xjsr	BeginMenu	;'pmcl' a-code needs menu on hires

	;xjsr	SetAltPointerWait	;1st time//startup sup 'sleepycloud'
	;MAY28;bsr	ReallyReallyActivate	;turns on sleep cloud
	st	FlagNeedHiresAct_(BP)
	bsr	ReallyActivate		;only if not background...may28


	xjsr	SetAltPointerWait	;1st time//startup sup 'sleepycloud' APRIL27
	bsr	ResetIDCMP		;pointer? yea? idcmp too...

	xjsr	_Aoff_rx		;gadgetrtns.o
	xjsr	_Dflt_rx		;gadgetrtns.o

		;did the picture get loaded?...if not...bye! june28
	xref PicFilePtr_	;hp.gads, the entire file, in memory
	tst.l	PicFilePtr_(BP)	;hp.gads, the entire file, in memory
	beq	StartQuitting

	move.l	_WBenchArgName_(BP),d1
	beq.s	startupname			;no wbarg (ascii ptr)
	move.l	d1,a1
	lea	FilenameBuffer_(BP),a2
	xjsr	copy_string_a1_to_a2	;copy wbench's filename to gadget buffer
	
startupname:
	moveq	#0,d0			;move.l	#'Opsc',d0
	lea	FilenameBuffer_(BP),a0
	tst.b	(A0)			;ascii string? "have a filename"?
	sne	FlagOpen_(BP)		;yes/no set/clear "file open" status
	beq.s	1$			;HAVE filename?...if so, load it
	bsr	DoInlineAction	
	dc.w	'Ok'
	dc.w	'ls'
1$:

*** main loop ***;GRAND MAIN HIGHEST TOTAL UPPERMOST TOP BIGGEST LOOP START
	;"action"s have the highest "priority" in the digipaint paradigm
	;...handle all "waiting to be done" actions before any msgs
	;...btw:msgs usually just set up an 'action code'

restart_if_msg:	MACRO	;quick check, any msgs?, if so go get
	;lea	OnlyPort_(BP),a0
 	;lea	MP_MSGLIST(a0),a1
	;cmpa.l	8(a1),a1
	;bne	trymsg
	bsr	reloop_if_msg
	ENDM

	bra.s	EventLoop

reloop_if_msg:	;bsr here...
	move.l	(sp)+,a6		;very temporary, pop subr rtn
	lea	OnlyPort_(BP),a0
 	lea	MP_MSGLIST(a0),a1
	cmpa.l	8(a1),a1
	bne.s	trymsg	;event loop
	jmp	(a6)	;"return from subr"

EventLoop:
	lea	ActionCode_(BP),a0
	move.l	(a0),d0			;do 'actions' until none indicated
	beq.s	trymsg			;no action, go do message
	moveq	#0,d1
	move.l	d1,(a0)			;clears ActionCode_(BP)
	bsr	DoAction
trymsg:
	;;;bsr	SetMyLevel6		;do this OFTEN

	bsr	CheckIDCMP		;check msg port
	beq.s	nomsg
gotmsg:	bsr	Process_IDCMP_Mesg	;grand master msg handler
	bra.s	EventLoop		;RESTART MAIN LOOP
nomsg:
		;empty msg queue, start doing "slower" things
	;tst.b	FlagQuit_(BP)	;start quitting AFTER msg queue empties
	;bne	StartQuitting
	;MAY30
	tst.b	FlagQuit_(BP)	;start quitting AFTER msg queue empties
	beq.s	008$
	xjsr	SafeEndFonts	;textstuff.o...might clear quit flag
	tst.b	FlagQuit_(BP)	;start quitting AFTER msg queue empties
	bne	StartQuitting
008$

		;open "bigpic" screen, but only "upon conditions"
	tst.l	ScreenPtr_(BP)		;big painting picture still there?
	bne.s	afterFORCEscreen	;not when already have a bigpic
	tst.b	FlagSizer_(BP)
	bne.s	afterFORCEscreen	;not when "screen sizer" active
	tst.W	FlagOpen_(BP)		;filerequester? (load/save/font/brush)
	bne.s	afterFORCEscreen	;not when file request "open"
	move.l	#'Opsc',ActionCode_(BP)	;if 'opsc' no go, then sups sizer mode
	bra	EventLoop
afterFORCEscreen:

;;  IFC 'T','F' ;JUNE01
		;handle "autoscroll" of "bigpicture"
	bsr	AutoMove	;move//scroll bigpic
	tst.b	FlagNeedIntFix_(BP) ;did picture-move-scroll happen?
	beq.s	noscr		;skip scrol-loop, didnt/not scrolling
	xjsr	DoMinDisplayText ;showtxt.o, minimum timered text
	bsr	FixInterLace
	bra	EventLoop	;RESTART...handles menus,ptr,etc(scrolling)
noscr:
	clr.w	ScrollSpeedX_(BP)	;STOP scrolling
	clr.w	ScrollSpeedY_(BP)
;;   ENDC ;JUNE01
		;MAY14
	xjsr	CheckKillMagnify
	xjsr	CheckBegMagnify	;begin magnify
	restart_if_msg

	xjsr	ReDoHires	;hires display, gadget update/refresh
	restart_if_msg

		;INITIALIZING/STARTUP stuff
	tst.l	ScreenPtr_(BP)	;bigpic?
	beq.s	after_inittime	;bigpic not opened yet
	tst.b	Initializing_(BP)
	beq.s	after_inittime	;not sup time
	clr.b	Initializing_(BP)	;ALRIGHT!

	xjsr	SupBottomAscii ;showtxt.o ;rtns a0=already sup text bottom row
	move.b	#$0a,46(a0)
	move.b	#$0d,47(a0)
	PRTMSG a0,80 		;version #, CopyRight to cli(if any) output

	xjsr	CreateDetermine		;displays new pallette, too
	xjsr	BeginMenu	;'pmcl' a-code needs menu on hires
	bsr	DoInlineAction
	dc.w	'Pm'
	dc.w	'cl'		;Paint Mode CLear
	move.l	#'Boot',d0	;d0=LONG # (equiv 4 ascii) ('boot' code(s))
	bsr	ZipKeyFileAction ;main.key.i, reads keyfile for startup cond
	bra	EventLoop
after_inittime:

	;	;JUNE04...do asap(?), elim "workbench blue"
	;xjsr	HiresColorsOnly		;pointers.o, sup colors on hires
	;xjsr	UseColorMap		;(pointers.o, for now)
	;restart_if_msg

	xjsr	OpenHamTools	;reserve the memory (pmcl wants hamtools?)
	restart_if_msg

		;ARRANGE SCREENS
;may05;	move.b	FlagDisplayBeep_(BP),d0	;error stat?
;may05;	or.b	d0,FlagFrbx_(BP)	;...gets 'screen arrange' to show err
	xjsr	ScreenArrange		;gadgetrtns.o (call b4 displaybeep)
	restart_if_msg

	xjsr	AproPointer		;appropriate hires ptr
	xjsr	FixPointer		;helps out 'customized brush'
	restart_if_msg

;june04;	xjsr	HiresColorsOnly		;pointers.o, sup colors on hires
;june04;	xjsr	UseColorMap		;(pointers.o, for now)
;june04;	restart_if_msg
		;JUNE04...also still now "now"
	xjsr	HiresColorsOnly		;pointers.o, sup colors on hires
	xjsr	UseColorMap		;(pointers.o, for now)
	restart_if_msg


	tst.b	FlagDisplayBeep_(BP)
	beq.s	dontbeep
	sf	FlagDisplayBeep_(BP)	;so dont happen 2x
	suba.l	a0,a0			;may05'89
	CALLIB	Intuition,DisplayBeep	;may05'89
	restart_if_msg			;may05'89
dontbeep:

	bsr	ResetIDCMP	;change idcmp ONLY when no msgs (or new scr) MAY13
	bsr ReallyActivate	;activate hires (ifneeded) asap, helps w/Clbx ;APRIL30
	restart_if_msg
;may15late...no need;	xjsr	BeginMenu	;may15...late...helps magnify
;may13;	bsr	ResetIDCMP	;change idcmp ONLY when no msgs (or new scr)
	xjsr	SupHamGads	;tool.code.i, add gadgets to hamtools
	restart_if_msg

	lea	FlagRedrawPal_(BP),a0
	tst.b	(a0)
	beq.s	easetc
	sf	(a0)
	xjsr	RedrawPalette	;tool.code.i,refreshes needed hamtool gads
	restart_if_msg
easetc:

		;late..may02...moved *here*
		;update rgb sliders on hamtools
	lea	FlagRefHam_(BP),a0
	tst.b	(a0)			;asking for new colormaps?
	beq.s	earefh			;...nope.
	;;;sf	(a0)			;clear flag so don't reset cmaps again
;may02;	xjsr	DoMinDisplayText	;showtxt.o, min'timered text
;may02;	restart_if_msg			;msg after showtxt? (sys uses 756bytes)
	sf	FlagRefHam_(BP)		;flag so dont happen 2x
	xjsr	UpdatePalette		;showpal.o, show rgb sliders, cbrites
	restart_if_msg
	xjsr	DoMinDisplayText	;showtxt.o, min'timered text
	restart_if_msg			;msg after showtxt? (sys uses 756bytes)
earefh:



  ifc 't','f'		;JUNE01...moved 'here'...to not interfere w/keys?
		;handle "autoscroll" of "bigpicture"
	;clr.w	ScrollSpeedX_(BP)	;STOP scrolling
	;clr.w	ScrollSpeedY_(BP)
	bsr	AutoMove	;move//scroll bigpic
	tst.b	FlagNeedIntFix_(BP) ;did picture-move-scroll happen?
	beq.s	noscr		;skip scrol-loop, didnt/not scrolling
	xjsr	DoMinDisplayText ;showtxt.o, minimum timered text
	bsr	FixInterLace
	bra	EventLoop	;RESTART...handles menus,ptr,etc(scrolling)
noscr:
	clr.w	ScrollSpeedX_(BP)	;STOP scrolling
	clr.w	ScrollSpeedY_(BP)
  endc ;june01

;may14;	xref FlagMagnify_
;may14;	tst.b	FlagMagnify_(BP)
;may14;	beq.s	20$
;may14;	tst.b	FlagMagnifyStart_(BP)
;may14;	bne.s	20$
;may14;	xjsr	DoMinMagnify	;MAY14...before showpaste if magnot locked
;may14;	restart_if_msg
;may14;20$


	xjsr	DoShowPaste	;cutpaste.o, TIMERED shows cutout brush
		;show magnify asap...in 'mintimered loop'...june
	tst.l	PasteBitMap_Planes_(BP)	;carrying a brush?
	beq.s	379$
	xjsr	DoMagnify	;min'timer'd...(this one's for draw/cut-ing) JUNE..."faster"
379$
	restart_if_msg

;		;late..april26...moved *here*
;		;update rgb sliders on hamtools
;	lea	FlagRefHam_(BP),a0
;	tst.b	(a0)			;asking for new colormaps?
;	beq.s	earefh			;...nope.
;	sf	(a0)			;clear flag so don't reset cmaps again
;	xjsr	UpdatePalette		;showpal.o, show rgb sliders, cbrites
;	xjsr	DoMinDisplayText ;showtxt.o, minimum timered text MAY01 helpsw/pickmode
;	restart_if_msg
;earefh:


	move.b	FlagSingleBit_(BP),d0	;cutpaste/blits/only 1 bitplane up?
	or.b	FlagNeedShowPaste_(BP),d0 ;need 'new' brush display
	beq.s	oknosho
	xjsr	ReallyShowPaste		;NON timer'd brush display (c/b SLOW)
oknosho:

	xjsr	DoSpecialMode	;drawb.mode.i, (rectangle, circle, line, curve)
	xjsr	DoMinDisplayText ;showtxt.o, minimum timered text APRIL25
	xjsr	DoMinMagnify	;min'timer'd...(this one's for draw/cut-ing)
	restart_if_msg		;check for msg AFTER text, palette update

	xjsr	ReallyDoMagnify		;force magnify display
	xjsr	ReallyDisplayText	;force text display (clrs FlagNeedText)
	bsr	FixInterLace		;slow?
	restart_if_msg

	tst.b	FlagRefHam_(BP)	;openhamtool just happen?
	bne	EventLoop
	xjsr	ShowPalette	;showpal.o, checks/clears FlagNeedShowPal
	restart_if_msg		;check for msg AFTER text, palette update

	bsr	ResetPriority	;(showpaste//blits?...coulda upped it)
	restart_if_msg

	;;;;bsr	ResetIDCMP	;change idcmp ONLY when no msgs (or new scr) APRIL30

	xjsr	ViewPage	;viewpage.o, only does it if flag set
	bne.s	afterwait	;happen'd...restart (ViewPage contains a Wait)

	move.l	our_task_(BP),a0 ;ptr to task(|process) structure
	tst.b	LN_PRI(a0)	;BYTE LN_PRI in task struct already?
	bpl.s	yesalive
	xjsr	FreeDouble	;kills//frees chipmem copy of picture
yesalive:

	xjsr	ActivateText	;only happens upon apro' conditions ;may01

	moveq	#-1,D0		;indicate signal set of all//any
	CALLIB	Exec,Wait
afterwait:

	xref RemagTick_
	xref ShowPasteTick_
	xref RetextTick_
	move.l	Ticker_(BP),d0		;'clocktime'
	move.l	d0,RemagTick_(BP)	;reset 'clock's so
	move.l	d0,ShowPasteTick_(BP)	;...'natural' priority happens...
	move.l	d0,RetextTick_(BP)	;...can then call domintext b4 showpaste

	bra	EventLoop


 xdef ReallyActivate	;only xref'd by repaint/scratch.o ;APRIL15'89....
ReallyActivate:		;APRIL15'89....

	xjsr	AreWeAlive
	beq.s	noneedact			;no window, cant activate it

	lea	FlagNeedHiresAct_(BP),a0
	tst.b	(a0)
	beq.s	noneedact			;no window, cant activate it
	sf	(a0)				;clear flag, "doing" it

	move.l	LastM_Window_(BP),d0
	;may28;beq.s	noneedact ;april25;ReallyReallyActivate
	beq.s	001$	;may28
	cmp.l	GWindowPtr_(BP),d0		;already active ?
	beq.s	noneedact
001$
;may28, label not needed ;ReallyReallyActivate:	;called *here* at sup
	move.l	GWindowPtr_(BP),D0
	beq.s	noneedact			;no window, cant activate it
	;JUNE08'89;move.l	d0,LastM_Window_(BP)		;kludgey but needed....(?)

	move.l	IntuitionLibrary_(BP),a6
	;JUNE08'89;cmp.l	ib_ActiveWindow(a6),d0		;hires already active?
	;JUNE08'89;beq.s	noneedact			;no window, cant activate it
	move.l	d0,a0				;a0=hires window
	JMPLIB	SAME,ActivateWindow	
noneedact:
	rts



	include "ds:main.msg.i"	;CheckIDCMP,Process,Return
	include "ds:main.key.i"	;RawKeyRoutine (AutoMove too)
	include "ds:main.int.i"	;interrupt server (decrements "Ticker_(BP)")
	;;;include "ds:main.level6.i"

	;#1=OK=wbench,#3=SEEMS TO WORK,#4=Rexx,#5=trackdisk,console.device

SetHigherPriority:	xjsr	AreWeAlive
			beq.s	prirts		;background....

ForceHigherPriority:	moveq	#HIPRI,D0
			bra.s	ExecSetTaskPri

SetLowerPriority:	moveq	#-1,D0
			bra.s	ExecSetTaskPri

ResetPriority:	;set to default if 'foreground', nochg if bkgnd
	move.l	our_task_(BP),a1	;ptr to our task(|process) structure
	cmp.b	#HIPRI,LN_PRI(a1)	;BYTE LN_PRI in task struct already?
	beq.s	SetDefaultPriority	;at highest?, then 'go normal'

	move.l	IntuitionLibrary_(BP),a1

	;JUNE02;move.l	ib_FirstScreen(a1),d0
	move.l	ib_ActiveWindow(a6),d0		;hires already active?

	beq.s	prirts	;wha?
	;june02;cmp.l	XTScreenPtr_(BP),d0	;hires screen in front?
	cmp.l	GWindowPtr_(BP),d0	;june02
	beq.s	SetDefaultPriority	;yup...come alive
prirts:	rts

ForceDefaultPriority:	;xdef'd for mousertns
SetDefaultPriority:	moveq	#0,D0	;we FORCE this
			;bra.s	ExecSetTaskPri

ExecSetTaskPri:	;D0=new desired priority, returns OLD pri in D0, blows A0/D0
	move.l	our_task_(BP),a0	;ptr to our task(|process) structure
	cmp.b	LN_PRI(a0),D0		;BYTE LN_PRI in task struct already?
	beq.s	aatpri			;already at priority, dont_call_exec

	movem.l	d1/a1/A6,-(sp)
	move.l	a0,a1 ;our_task_(BP),a1	;ptr to our task(|process) structure
	CALLIB	Exec,SetTaskPri
	movem.l	(sp)+,d1/a1/A6

aatpri:	rts

	;ConVertAscii2Integer:
	;-skips digits after decimal point
	;-no negative #s, result must be WORD size....64k-1

cva2i:	;a0=point to string, returns d0=#, a0 advanced just past # (DESTROYS D1)
	;"suitably" commented out to 1) NOT ALLOW NEGATIVE, 2) MAX=64K-1(?)
	move.l	d3,-(sp)
	moveq	#0,d0		;d0=result to build, start with zero
	moveq	#0,d1		;clear upper bytes
	moveq	#10,d3		;assume BASE 10

cva_findstart:
	move.b	(a0)+,d1	;get characters from start
	beq	bodyDone
	cmp.b	#$0a,d1
	beq	err_cvaout
	cmp.b	#'.',d1		;DOT endzittoo
	beq	skipfrac	;bodyDone	;boom
	; cmpi.b	#'0',d1
	; beq.s	cva_findstart	;chuck initial zeros
	cmpi.b	#' ',d1
	beq.s	cva_findstart	;chuck initial blanks
	cmpi.b	#'x',d1		;check for hex forms
	beq.s	initialHex
	cmpi.b	#'$',d1	
	beq.s	initialHex
	bra.s	cva_ck1st
initialHex:
	move.w	#16,d3		;show base of 16, preserving minus

bodyStr:
	move.b	(a0)+,d1	;get next character
bodyConvert:
	beq	bodyDone	;null @ end of string?
	cmp.b	#' ',d1		;blank endzittoo
	beq	bodyDone
	cmp.b	#'/',d1		;slash is a delimiter, too
	beq	bodyDone
	cmp.b	#'.',d1		;DOT endzittoo
	beq.s	skipfrac	;bodyDone
cva_ck1st:
	cmp.b	#$0d,d1		;cr?
	beq	bodyDone
	cmp.b	#$0a,d1		;lf?
	beq	bodyDone
	cmp.b	#$09,d1		;tab?
	beq.s	bodyDone
				;prob'ly have a valid digit, shift accum
	mulu	d3,d0		;result=result*base
	cmpi.b	#'0',d1
	blt.s	badChar
	cmpi.b	#'9',d1
	bgt.s	perhapsHex
	subi.b	#'0',d1
	add.W	d1,d0		;binary value now, accum.
	bra.s	bodyStr		;go get another char

perhapsHex:
	cmp.w	#16,d3		;working in hex (base 16) now?
	bne.s	badChar
	cmpi.b	#'A',d1
	blt.s	badChar
	cmpi.b	#'F',d1
	bgt.s	perhapsLCHex
	subi.b	#'A'-10,d1
	add.w	d1,d0
	bra.s	bodyStr

perhapsLCHex:
	cmpi.b	#'a',d1
	blt.s	badChar
	cmpi.b	#'f',d1
	bgt.s	badChar
	subi.b	#'a'-10,d1
	add.w	d1,d0		;binary, accum.
	bra.s	bodyStr

badChar:
	tst.l	d0		;if we already have a #...
	bne.s	enda_cva2i	;... end on non-# char
err_cvaout:
	moveq	#-1,d0		;else flag error as minus
	bra.s	enda_cva2i
skipfrac:		;done scanning, found a 'dot'...skip fract digits
	move.b	(a0)+,d1
	beq.s	bodyDone	;null @ end of string?
	cmp.b	#' ',d1		;blank endzittoo
	beq.s	bodyDone
	cmp.b	#'.',d1		;DOT endzittoo
	beq.s	skipfrac	;bodyDone
	cmp.b	#$0d,d1		;cr?
	beq.s	bodyDone
	cmp.b	#$0a,d1		;lf?
	beq.s	bodyDone
	cmp.b	#$09,d1		;tab?
	beq.s	bodyDone
	cmp.b	#'/',d1		;slash ok too
	;beq.s	bodyDone
	bne.s	skipfrac
bodyDone:
enda_cva2i:
	move.l	(sp)+,d3
	tst.l	d0	;be nice, test for minus after subr call for errchk
	rts	;cva2i

	;note: for TABLE BELOW, UnDoBitMap FAST MEM WANTED alloc'd 1st
	;note: ...this should help when you say 'fastmemfirst','digipaint'
	;DEPTH,BasePageADDRESS,type#0=CHIP,#1=FAST,#-1=NONE(listend),#-2=NONE
BitMap_Data:
	dc.w 6,ScreenBitMap_,0		;visible work screen
	dc.w 2,BB_BitMap_,0		;drawing mask SECOND BITPLANE IS TMPRAS
	dc.w 6,CPUnDoBitMap_,-1 	;6 plane brush picture (NOT ALLOCATED)
	dc.w 6,SwapBitMap_,-1		;alternate (NOT ALLOCATED)
	dc.w -1				;-1 indicates "END OF LIST"

OpenBigPic:	;opens screen & window as per scratch var specs MESSES ALOT W/a4
	;args are: NewSizeX_(BP),NewSizeY_(BP),FlagLaceNEW_(BP),

		;prevent 'cli startup' with ODD # lines...mustbe EVEN may05'89
	lea	NewSizeY_(BP),a0
	move.w	(a0),d0
	addq.w	#1,d0
	and.w	#~1,d0	;remove bottom ("odd") bit
	move.w	d0,(a0)	;NewSizeY

		;ensure 32<=x<=1024,   y<=1024
	move.w	#1024,d1
	cmp.w	d1,d0		;y max?
	bcs.s	10$
	move.w	d1,d0 ;(a0)	;ymax=1024
10$	moveq	#MINHT,d2		;min y
	cmp.w	d2,d0
	bcc.s	11$
	move.w	d2,d0
11$	move.w	d0,(a0)	;newsizeY

	lea	NewSizeX_(BP),a0
	move.w	(a0),d0
	add.w	#32-1,d0	;round up, even longwords...
	and.w	#~(32-1),d0
	;moveq	#32,d2
	;cmp.w	d2,d0	;<32?
	;bcc.s	2$
	;move.w	d2,d0	;x=32
2$
	cmp.w	d1,d0	;<1024?
	bcs.s	3$
	move.w	d1,d0
3$	move.w	d0,(a0)	;newsizeX
	

		;ask "delete swap screen?"
	lea	SwapBitMap_(BP),a0
	tst.l	bm_Planes(a0)
	beq.s	onoswap
	move.w	(a0),d0			;bm_BytesPerRow(a0),d0
	asl.w	#3,d0			;=pixels per row
	cmp.w	NewSizeX_(BP),d0
	bne.s	askdel
	move.w	bm_Rows(a0),d0
	cmp.w	NewSizeY_(BP),d0
	beq.s	onoswap
askdel:	xjsr	AskDelSwapRtn
	bne.s	godelswap	;ok...go delete swap (continue like norm)
		;else, user said "no! cancel size chg...no delete swap"
	tst.L	ScreenPtr_(BP)	;ok, then, HAVE a screen?
	bne	obp_sup_end	;openbigpic, setup end.....all set now?
		;...simply sup NEWSIZE x,y to be same as swap
	lea	SwapBitMap_(BP),a0
	move.w	(a0),d0			;bm_BytesPerRow(a0)
	asl.w	#3,d0			;=pixels per row
	move.w	d0,NewSizeX_(BP)
	move.w	bm_Rows(a0),NewSizeY_(BP)
	bra.s	onoswap			;april01'89
		;delete swap screen since it's a different ht/wt than new
godelswap:
	xjsr	FreeSwap
onoswap:
	bsr	CloseBigPic	;closes screen, kill chip bitmap+2brush bitplanes
	;?;re-in-stated april26

	xjsr	ByeByeWorkBench	;memories.o, may13
	xjsr	CleanupMemNoWb		;cleans up, but doesnt force flag closewb JUNE28
;june28;	xjsr	CleanupMemory	;wbench and HAMTOOLS and ....(always)
;may13;	xjsr	ByeByeWorkBench	;memories.o, may12

	tst.l	FileHandle_(BP)	;file open?
	bne.s	5$		;yes file open...else sup bmhd_xaspect
	moveq	#10,d0		;lores aspect
	tst.b	FlagLaceNEW_(BP)
	beq.s	3$
	add.w	d0,d0		;hires aspect (=20)
3$	move.w	d0,bmhd_xaspect_(BP)

5$	move.b	FlagLaceNEW_(BP),FlagLace_(BP)

	moveq	#0,D0			;global vars from BMHD_rastwidth/height
	move.w	NewSizeX_(BP),d0	;bmhd_rastwidth_(BP),D0
	add.w	#$1f,D0			;round up to longword
	and.w	#~$1f,D0
	move.l	D0,BigPicWt_(BP)
;	tst.w	bmhd_rastwidth_(BP)	;file???
;	bne.s	66$
;	move.w	d0,bmhd_rastwidth_(BP)
;66$
	subq.l	#1,D0
	move.l	D0,pixels_row_less1_(BP)

	asr.w	#3,D0			;/8 converts pixels to bytes
	move.l	D0,bytes_row_less1_(BP)	;#bytes -1 for 'dbxx' loops
	move.w	d0,d1
	asr.w	#2,d1
	move.w	d1,lwords_row_less1_(BP) ;#longwords  -1 for 'dbxx' loops

	addq.l	#1,D0
	move.l	D0,bytes_per_row_(BP)
	move.l	D0,d1			;used INAMOMENT for planesize calc
	asr.w	#1,D0			;/2 converts BYTEsperrow to WORDsperrow
	subq.w	#1,D0
	move.l	D0,words_row_less1_(BP)

	move.w	NewSizeY_(BP),d2	;bmhd_rastheight_(BP),d2
	move.w	d2,BigPicHt_(BP)	;global BITMAP HT really RASTHEIGHT
;	tst.w	bmhd_rastheight_(BP)	;FILE???
;	bne.s	77$
;	move.w	d2,bmhd_rastheight_(BP)
;77$
	mulu	d2,d1			;* bytes_per_row
	move.l	d1,PlaneSize_(BP)	;used "everywhere"

		;INTERPRET BMHD X ASPECT -->> turn on interlace?
	sf	FlagLace_(BP)
	moveq	#0,d0
	tst.b	FlagLaceNEW_(BP)
	bne.s	saylace
	moveq	#10,d1			;build aspect ratio in d1, d0=work
	move.B	bmhd_xaspect_(BP),d0	;5,10,20
	beq.s	golores			;ZERO aspect?
	cmp.b	#5,d0
	bne.s	nhires
golores	moveq	#10,d0			;hires goes to lores ham FOR MY SCREENS
nhires:	cmp.b	#20,d0
	bne.s	nhamlace
saylace	moveq	#20,d1
	st	FlagLaceNEW_(BP)
nhamlace:
	move.W	d1,XAspect_(BP)

		;ensure SCREEN(not bitmap) not bigger than 'normal' (booo....)
	move.L	BigPicWt_(BP),d1	;'desired width' (elim page junk?)
	move.w	BigPicHt_(BP),d2
	move.w	NormalWidth_(BP),d3
	move.w	NormalHeight_(BP),d4
	tst.b	FlagLaceNEW_(BP)
	beq.s	1$
	add.w	d4,d4
1$	cmp.w	#600,d4
	bcs.s	2$
	asr.w	#1,d4		;=ht/2
	and.w	#$7fff,d4	;top bit rolls down a zero if loop here
	bra.s	1$
2$
	cmp.w	d3,d1	;normal width,desired width
	bcs.s	5$	;normal>desired, ok to use smaller (?) yes
	move.w	d3,d1	;d3<=d1, use 'normal' width
5$
	cmp.w	d4,d2	;normal ht, desired ht
	bcs.s	6$	;branch when d4>d2
	move.w	d4,d2	;d4<=d2, use 'normal' (not bitmap, which is taller) ht
6$
	move.w	d1,bmhd_pagewidth_(BP)	;re-save bmhd 'page' fields after adj'
	move.w	d2,bmhd_pageheight_(BP)

	move.L	#V_HAM,d3		;lores screen mode
	tst.b	FlagLaceNEW_(BP)
	beq.s	101$
	or.w	#V_LACE,d3		;modes + I'LACE
101$:
	lea	BigNewScreen_(BP),A0	;A0=newscreen struct for 'big picture'
	move.w	d1,ns_Width(a0)
	move.w	d2,ns_Height(a0)
	move.w	d3,ns_ViewModes(a0)	;zap NewScreen struct
	move.L	d3,CAMG_(BP)
	move.b	FlagLaceNEW_(BP),FlagLace_(BP)

	;initialize & alloc 'primary' bitmaps/planes
	lea	BitMap_Data(pc),a3  	;A3 := data table for init function
init_one_map:
	movem.l	Zeros_(BP),D0/d1/d2
	move.w	(a3)+,D0		;number of bitplanes -or- endoflist

	bmi.s	end_ibm			;end of list (-1), leave w/notzeroflag
	moveq	#0,d1			;d1 using LONG MODE ensures bp offset ok
	move.w	(a3)+,d1		;address-base-offset
	cmp.w	#BB_BitMap_,d1	;drawing mask,2bitplane, initbitmap with 1
	bne.s	1$
	subq.w	#1,d0		;reduce bitplane count for InitBitMap purposes
1$
	lea	0(BP,d1.L),A0		;A0 bitmap struct Graphics Arg
	lea	bm_Planes(A0),a2	;A2 BitMap -> bm_Planes{table.of.addrs}
	tst.l	(a2)			;ALREADY have bitplane(s)?
	bne.s	end_this_bitmap		;...skip if already alive

	move.L	BigPicWt_(BP),d1	;"working bitmap" size
	moveq	#0,d2
	move.W	BigPicHt_(BP),d2	;bmhd_rastheight_(BP),d2
	CALLIB	Graphics,InitBitMap

	cmpi.w	#-1,(a3)		;our "type"
	beq.s	end_this_bitmap  	;-1 from table means "init only"

	;a2="pointer to table of bitplane addresses" a3=input/build spec
	move.w	-4(a3),d3		;# planes (1st entry eachrecordintable)
	subq.w	#1,d3			;for dbf loop (# WAS used by initbitmap)
alloc_planes:
	move.l	PlaneSize_(BP),D0	;type zero is "normal" bitmap dimensions
	cmpi.w	#1,(a3)			;alloc type from table
	bne.s	gchip
	xjsr	IntuitionAllocMain	;memories.o;fast prefer'd else chip
	bra.s	gmem
gchip:	xjsr	IntuitionAllocChipJunk	;memories.o;preserves reg d1
gmem:	beq.s	end_ibm			;no mem? stop init of all remaining
	move.l	D0,(a2)+		;extra lines display cut/paste stuff
	move.l	d0,a0		;address to clear
	xjsr	ClearPlaneA0	;strokeB.o, clearzit
	dbf	d3,alloc_planes

end_this_bitmap:
	lea	2(a3),a3	;skip planesize, prep re-loop next bitmap
	bra.s	init_one_map
end_ibm:	;"end of init'g bitmaps from table" ZERO/minus flag set

	beq	bummout		;couldn't get required bitmaps
	xjsr	AllocUnDo	;1st time?
	beq	bummout
	xjsr	EnsureExtraChip	;yeas, this chops up chip on a lowmem
	beq	bummout		;after "all the above"...notnuff chip for system

justopenscreen:
	xjsr	InitBitPlanes	;Scratch.o;inits rastports, too
9$
	lea	BigNewScreen_(BP),A0	;A0=NEWSCREEN STRUCT FOR OPENBIGSCREEN
	move.w	#6,ns_Depth(A0)		;width, ht already setup earlier?
	move.b	#1,ns_BlockPen(A0)

sctype set CUSTOMSCREEN!CUSTOMBITMAP!SCREENQUIET ;!SCREENBEHIND
	move.l	a0,-(sp)
	xjsr	AreWeAlive
	seq	d0		;if background (pri=-1) then d0=-1
	ext.w	d0		;=0foreground or -1bkgnd
	and.w	#SCREENBEHIND,d0
	or.w	#sctype,d0
	move.l	(sp)+,a0	;uck, short term stack clup
	move.w	d0,ns_Type(A0)

	lea	TextAttr_(BP),a1	;fontname, ht, style
	move.l	a1,ns_Font(A0)

	lea	ProgramNameBuffer_(BP),a1
	move.l	a1,ns_DefaultTitle(A0)

	lea	ScreenBitMap_(BP),a1
	move.l	a1,ns_CustomBitMap(A0)
	CALLIB	Intuition,OpenScreen

	move.l	D0,ScreenPtr_(BP)	;save pointer to new screen
	beq	bummout			;no screen?

	;out....may12
	;	;the following 'paragraph' helps to glue memory?
	;CALLIB	Intuition,RethinkDisplay	;may08'89
	;moveq	#4,d0	;4/50s of a second

	;moveq	#4,d1	;4/50s of a second
	;CALLIB	DOS,Delay
	;xjsr	CleanupMemory

	;st	FlagRefHam_(BP)		;gets "usecolormap" in main loop
	xref FlagColorMap_	;april26, alright, ALREADY declared
	st	FlagColorMap_(BP)

		;JUNE04...do asap(?), elim "workbench blue"
	xjsr	HiresColorsOnly		;pointers.o, sup colors on hires
	xjsr	UseColorMap		;(pointers.o, for now)


	move.l	ScreenPtr_(BP),A2	;bigpic
	move.l	A2,A0			;ScreenPtr
	moveq	#0,D0			;false argument
	CALLIB	Intuition,ShowTitle	;hides the Screen title bar

	;june28....why?;;;xjsr	CleanupMemory

;RmbTrap		equ $00010000	;Catching RMB events as button on bigpic
;Nocarerefresh	equ $00020000!SIMPLE_REFRESH
mywinf	equ	BORDERLESS!REPORTMOUSE!NOCAREREFRESH!RMBTRAP

		;open WINDOW on bigpic screen
	lea	BigNewWindow_(BP),A0		;STRUCTURE NewWindow
	move.l	ScreenPtr_(BP),A2		;bigpic

	move.b	#1,nw_DetailPen(A0)		;textpen for system requests
	move.w	sc_Width(a2),nw_Width(A0)	;A2 still=screenptr
	move.w	sc_Height(a2),nw_Height(A0)
	move.l	a2,nw_Screen(A0)
	move.w	#CUSTOMSCREEN,nw_Type(A0)
	move.L	#mywinf,nw_Flags(A0)
	CALLIB	SAME,OpenWindow
	move.l	D0,WindowPtr_(BP)	;pointer to newly opened window
	beq	bummout			;Abort with ZERO set, not everyone alive
	move.l	D0,A0

	;move.l	our_task_(BP),A1	;...because hires aint tall enuff
	;move.l	a0,pr_WindowPtr(A1)	;ham window for SYSTEM MSGS

	tst.b	Initializing_(BP)
	bne.s	getnewu	;APRIL22'89;obp_sup_end

	lea	UnDoBitMap_(BP),a0	;a0=from normal undo (fastramifpossible)
	lea	ScreenBitMap_(BP),a1	;a1=to visible screen
	xjsr	Crit			;copy odd/diff shaped undo -> screen
	xjsr	FreeUnDo		;get ridda the 'old' one
getnewu:
	sf	FlagBitMapSaved_(BP)	;forces saveundo to work
	xjsr	SaveUnDo		;allocs undo bitmap as neede

obp_sup_end:	;openbigpic, setup end.....bra's here from 'delete swap?'
	tst.l	UnDoBitMap_Planes_(BP)	;normal undo alloc'd?(fastramifpossible)
	beq.s	bummout			;no undo->go closebigpic

	;april26
	;;xjsr	CreateDetermine		;displays new pallette, too
	;xjsr	UseColorMap		;pointers.o, sup 'all screens' cmaps
	;xjsr	ForceToolWindow	;tool.code.i, st frbx, toolwindow
	xref FlagToolWindow_
	st	FlagToolWindow_(BP)
	st	FlagFrbx_(BP)	;ask for screen arrange
	;st	FlagRefHam_(BP)	;colormap...
	xref FlagColorMap_	;april26, alright, ALREADY declared
	st	FlagColorMap_(BP)

	moveq	#-1,d0		;set 'ne' flag, "ok" ending, did/had pic
	rts
bummout:			;bummount-bigpic didnt open
	;july01;bsr.s	CloseBigPic	;save apro undo, 'frees' alloc'd bitplanes
	bsr.s	skipundosave ;fixes BUG with sizer "losing picture" JULY01
	;APRIL27;xjsr	CleanupMemory	;wbench and hamtools and ....(always) april01'89
	;xjsr	ForceToolWindow	;tool.code.i, st frbx, toolwindow
	st	FlagToolWindow_(BP)
	st	FlagFrbx_(BP)	;ask for screen arrange
	moveq	#0,d0		;returns flagset for didnt/couldnt open screen
zzrts:	rts

CloseBigPic:			;note: does not delete "undobitmap"
	;move.l	our_task_(BP),A0
	;move.l	GWindowPtr_(BP),pr_WindowPtr(A0) ;hires screen for SYSTEM MSGS

	;xjsr	InitBitPlanes		;does initrastport, which removes font... JULY03
	xjsr	SafeEndFonts		;JULY03 kludgy but needed ?...fixes mem loss?
	xjsr	GoodByeHamTool		;close hamtools MAY13'89

	tst.l	ScreenPtr_(BP)	;screen open'd?
	beq.s	cbp_freedata	;no scr?
	xjsr	UnShowPaste	;remove brush from screen
	xjsr	FreeDouble	;double bitmap (if any)
	xjsr	CopyScreenSuper	;visible//chip -> undo//fastifpossible
	xjsr	FreeDouble	;chip ram double buffer (when "chip rich")
	xjsr	FreeCPUnDo	;'extra' copy used while showing brush
	;march29'89;xref	CleanupMemory	;memories.o, closes wbench, hamtools, too
	;march29'89;PEA	CleanupMemory	;memories.o, closes wbench, hamtools, too
	;april23'89, re-instated
	;APRIL27;PEA	CleanupMemory	;memories.o, closes wbench, hamtools, too

skipundosave:


		;JULY05'89...help prevent the leading cause of screen loss
	tst.l	UnDoBitMap_Planes_(BP)	;normal undo alloc'd?(fastramifpossible)
	bne.s	okhaveundo
	xref DefaultX_	;sizer vars...."restore" undo?
	xref DefaultY_
	moveq	#0,d0
	moveq	#0,d1
	movem.W	DefaultX_(BP),d0/d1
	move.L	d0,BigPicWt_(BP)
	move.w	d1,BigPicHt_(BP)
	mulu	d0,d1
	move.l	d1,PlaneSize_(BP)	;used "everywhere"
	beq.s	okhaveundo		;oops? bomb-pruf?
	xjsr	AllocUnDo
	tst.l	UnDoBitMap_Planes_(BP)	;normal undo alloc'd?(fastramifpossible)
	beq.s	okhaveundo		;really, didn't get the ram, no copy
	lea	ScreenBitMap_(BP),a0	;a0=FROM visible screen
	lea	UnDoBitMap_(BP),a1	;a1=TO normal undo (fastramifpossible)
	xjsr	Crit			;copy odd/diff shaped undo -> screen
	xjsr	InitSizer		;since HAD NO UNDO, came from sizer(?)
okhaveundo:


	lea	WindowPtr_(BP),A0	;point to variable on basepage
	lea	ScreenPtr_(BP),A1	;big picture (if any)
	bsr	CloseWindowAndScreen
cbp_freedata:
;may13;	xjsr	GoodByeHamTool		;close hamtools MAY07'89

	lea	ScreenBitMap_(BP),a3	;FREE SCREEN (CHIP) BITPLANE MEMORY
	lea	bm_Planes(a3),a3
	moveq	#6-1,d3		;d3=loopcounter, a3=ptr to bitplane addresses
freescreen:			;note:freeonevar is ok to call if vardata=0
	lea	(a3),A0		;"address of bitplane data"
	bsr.s	free1v
	lea	4(a3),a3	;pointer to next bitplane adr in bitmap struct
	dbf	d3,freescreen

	lea	BB_BitMap_(BP),A0	;drawing mask
	lea	bm_Planes(A0),A0	;a0=points "right at variable" to free
	bsr.s	free1v			;free var (a0=adr), rtns a0 same
	addq.l	#4,a0			;2nd bitplane, 'tmpras' usage
free1v:			;A0=Address of variable to free, RETURNS a0 unmolested
	xjmp	FreeOneVariable	;memories.o, frees from remember list


CloseWindowRoutine:
	move.l	(A0),D0
	beq.s	eawini		;no window, outta here
	clr.l	(A0)		;clear var windowptr_(bp)
	move.l	D0,A0

	xjsr	ReturnMessages	;a0=windowptr  (destroys d0/d1/a1)
		;scans the 'input message list' and ReplyMsg's all
		;the msgs for window a0 (for use just before CloseWindow)

	clr.l	wd_UserPort(A0)		;NEVER let intwit delete *my* port....
  ifc 't','f' ;july03
	JMPLIB	Intuition,CloseWindow
	;CALLIB	Intuition,CloseWindow
	;nohelp;xjmp	GraphicsWaitBlit
  endc
	CALLIB	Intuition,CloseWindow
	xjmp	GraphicsWaitBlit	;wait! for closewindow's blit...

eawini:	rts


CloseWindowAndScreen:	;a0=window variable a1=screen variable
			;doesn't really closewindow, lets closescreen do it
  IFC 't','f'
	move.l	(A1),D0		;no screen pointed to, anyway?
	beq.s	after_scr2back

	movem.l	a0/a1,-(sp)
	move.l	d0,a0		;a0=screenptr for ->back
	CALLIB	Intuition,ScreenToBack
	movem.l	(sp)+,a0/a1
after_scr2back:
  ENDC
	move.l	a1,-(sp)
	bsr	CloseWindowRoutine
	move.l	(sp)+,a0

CloseScreenRoutine:	;A0=address of screen var
	move.l	(A0),D0			;no screen pointed to, anyway?
	beq	zzrts
	clr.l	(A0)			;clear'd var. sez "it's gone now"
	move.l	D0,A0			;A0=screenptr

	JMPLIB	Intuition,CloseScreen
;may15;
;may15;	CALLIB	Intuition,CloseScreen
;may15;
;may15;	CALLIB	SAME,RethinkDisplay		;may13
;may15;	xjmp	CleanupMemory			;may12


	;moveq	#4,d1	;4/50s of a second
	;CALLIB	DOS,Delay
	;xjmp	CleanupMemory


	;nohelp;xjmp	GraphicsWaitBlit
	;rts
***
	dc.l	'JAMI'!$80818283
	dc.l	'E PU'!$84858687
	dc.l	'RDON'!$88898A8B
****
