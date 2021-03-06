*********************************************************************
*
* flyer.library - Flyer interface library
*
* $Id: flyerlib.asm,v 1.28 1997/05/14 11:42:57 Holt Exp Holt $
*
* $Log: flyerlib.asm,v $
*Revision 1.28  1997/05/14  11:42:57  Holt
*Highspeed xfer on files to/from amiga done.
*NewFileWrite,NewFileRead.
*
*Revision 1.27  1997/04/18  16:55:36  Holt
*added working NewFileWrite.
*
*Revision 1.26  1997/04/12  15:11:50  Holt
*added filehsread.
*
*Revision 1.25  1997/03/26  16:41:11  Holt
*no real changes to speak of.
*
*Revision 1.24  1997/01/31  19:47:56  Hayes
*Changed FlyerFileSeek to handle 64-bit positions
*
*Revision 1.23  1997/01/09  14:15:39  Holt
*interim SRAM fixes
*
*Revision 1.22  1996/12/19  18:05:11  Holt
*added FileExtend funtion that extends a file without writing data to it.
*
*Revision 1.21  1996/11/13  19:07:22  Hayes
*added InitFlyerForce
*moved chip programming from InitFlyers to ProgramChips
*added LoadFlyerBin to handle new .dat file format
*added GetChipID to read in chipset.dat file and determine
*   the chipID for the installed board
*
*Revision 1.20  96/11/12  15:31:13  Holt
*Added code to devide audio envelops into smaller 2500 frame parts
*
*Revision 1.19  1996/08/13  15:30:07  Holt
*added moresupport for HQ6 mode.
*
*Revision 1.18  1996/07/16  13:00:08  Holt
*worked on aud env.
*
*Revision 1.17  1996/06/25  17:17:23  Holt
*made many changes to support audio envelopes
*
*Revision 1.16  1996/04/29  10:39:07  Holt
**** empty log message ***
*
*Revision 1.15  1995/11/30  10:52:31  Flick
*Bumped all rev's to 4.10
*
*Revision 1.14  1995/11/06  14:05:48  Flick
*New/improved versions of functions to make them async/abortable/status ready:
*-->CopyClipNew,EndSequenceNew,DeFragNew
*New functions for 3rd pty support: Get/PutFrameHeader
*New internal-only function "CheckProgressNew" does status updating now
*RunModule changed to allow downloading code or just running internal test
*CPUDMA no longer a private, undocumented function
*Added test descriptions for 2 new SCSI errors and 4 new sequencing errors
*
*Revision 1.13  1995/09/13  18:05:35  Flick
*CacheTest was trashing d0-d1/a0-a1!!!
*Released as 4.07
*
*Revision 1.12  1995/08/31  16:31:01  Flick
*Bumped rev/dates for 4.06
*
*Revision 1.11  1995/08/11  15:06:57  Flick
*EasyOpenWriteField now supplies a NULL DataSize, which allows Flyer to pick
*the correct size based on the stored HQ5 switch
*
*Revision 1.10  1995/08/11  13:04:10  Flick
*Expanded GetClrSeqError f'n to get 3 more pieces of info
*Moved cache test/fix code into a sub to be called anywhere needed
*
*Revision 1.9  1995/08/04  10:48:48  Flick
*Added CacheTest function, if detects bug does CacheClear before retrieving
*error code or data back from Flyer thru shared RAM (fixes BIG BUGs on 2000)
*Changed AbsExecBase ref's to fl_SysLib where possible (faster)
*Added optional code to use Exec Allocate/Deallocate functions for shared
*RAM resource (on NEWMEMALLOC switch, which is currently OFF)
*Added another arg in FlyerParent function to return block number
*
*Revision 1.8  1995/07/19  11:39:34  Flick
*Added new LocateField() call to library, bumped dates, fixed some autodocs
*
*Revision 1.7  1995/07/06  17:32:57  Flick
*Folded in autodocs (GULP!)
*
*Revision 1.6  1995/06/27  13:13:19  Flick
*Added FlyerOptions function
*
*Revision 1.5  1995/06/19  18:13:53  Flick
*CopyData function converts volume names to drive #'s like 4.04 did
*MakeFile function improved to handle non-block aligned sizes (like 4.04 did)
*Bumped rev to 4.05
*
*Revision 1.4  1995/05/19  14:23:04  Flick
*Removed wait for commands to abort on abortaction(0)
*
*Revision 1.3  1995/05/11  15:36:44  Flick
*Bumped date and rev to 4.04
*
*Revision 1.2  1995/05/11  13:04:21  Flick
*Added 4.1 sequencing functions
*
*Revision 1.1  1995/05/08  10:05:51  Flick
*Removed assembler.i include
*
*Revision 1.0  1995/05/05  15:49:51  Flick
*FirstCheckIn
*
*
* Copyright (c) 1994 NewTek, Inc.
* Confidental and Proprietary. All rights reserved. 
*
* 02/17/94	Marty	created
*
*********************************************************************
* This library locates and maintains the SRAM block on each Flyer card.
* Currently supports up to four Flyer cards in the system ("unit" field)
* Provides interface to the Flyer cards' SRAM command structure.
*
* Used by the FlyerFileSystem, but also called directly from an application
* which performs audio/video (and might not be multitasking)
*********************************************************************

	include "exec/types.i"
	include "exec/nodes.i"
	include "exec/lists.i"
	include "exec/libraries.i"
	include "exec/initializers.i"
	include "exec/resident.i"
	include "exec/memory.i"
	include "exec/ables.i"
	include "dos/dos.i"
	include "libraries/configvars.i"
	include	"devices/scsidisk.i"

	include "asmsupp.i"
	include "macros.i"
	include "Flyer.i"
	include "FlyerPrivate.i"
	include "opcodes.i"
;;	include "//switcher/inc/instinct.i"
	include "//switcher/inc/elh.i"
	include "serialdebug.i"

	INT_ABLES			;Macro from exec/ables.i




BINDEBUG	EQU	0
*SERDEBUG EQU 	1
*DEBUGGEN	EQU	1
;DEBUGNEW	EQU	1
;DEBUGBUG	EQU	1
TB_VTSetUp	equ	1
	ALLDUMPS

;;	RDUMP

NEWMEMALLOC	equ	0

;******* Exported *******************************************************

	XDEF	Init
	XDEF	Open
	XDEF	Close
	XDEF	Expunge
	XDEF	Null

	XDEF	Read10,Write10,CPUDMA,FastCopy,GetCompInfo,GetCardUnit,FIRquery
	XDEF	LocateField
	XDEF	OpenWriteField1,CloseField1

	IFNE	SERDEBUG
	XDEF	DB_DUMP_HEXI
	ENDC

;******* Imported *******************************************************

	XREF	EndCode

	XREF	OpenReadField2,OpenWriteField2,CloseField2
	XREF	ReadLine2,WriteLine2
	XREF	SetFillColor2,SkipLines2

;;;	XREF	HideFlyer,RestoreFlyer

************************************************************************
*
*       Standard Program Entry Point
*
************************************************************************

Start
	CLEAR	d0
	rts

initDDescrip
	DC.W	RTC_MATCHWORD
	DC.L	initDDescrip
	DC.L	EndCode
	DC.B	RTF_AUTOINIT
	DC.B	VERSION
	DC.B	NT_LIBRARY
	DC.B	FLYER_PRI
	DC.L	FlyerName
	DC.L	idString
	DC.L	Init

FlyerName	dc.b	'flyer.library',0

VERSION		EQU	4
REVISION	EQU	43

RevString	dc.b	'$VER: flyer.library 4.44 (28.04.98)',0
Copyright	dc.b	'Copyright (C) 1998 NewTek, Inc.',0
WhoDoedIt	dc.b	'Written by Flickinger, Holt, Hayes',0

idString	dc.b	'flyer.library 4.44  (28 Apr 1998)',13,10,0

DosName		dc.b	'dos.library',0
ExpansionName	dc.b	'expansion.library',0

	CNOP	0,2


Init
	DC.L	FlyerLib_Sizeof
	DC.L	funcs
	DC.L	dataTable
	DC.L	InitRoutine


funcs
	dc.w	-1		;Word offsets
	dc.w	Open-funcs
	dc.w	Close-funcs
	dc.w	Expunge-funcs
	dc.w	Null-funcs

;***** Library Operation *****
	dc.w	AbortCmd-funcs
	dc.w	CheckProgress-funcs
	dc.w	WaitAction-funcs
	dc.w	CheckAction-funcs
	dc.w	AbortAction-funcs
	dc.w	Error2String-funcs

;********** Setup *********
	dc.w	InitFlyers-funcs
	dc.w	Firmware-funcs
	dc.w	RunModule-funcs
	dc.w	PgmFPGA-funcs
	dc.w	SBusWrite-funcs
	dc.w	SBusRead-funcs
	dc.w	FIRinit-funcs
	dc.w	FIRcustom-funcs
	dc.w	FIRmapRAM-funcs
	dc.w	DSPboot-funcs
	dc.w	GetFieldClock-funcs
	dc.w	QuitFlyer-funcs
	dc.w	PlayMode-funcs
	dc.w	RecordMode-funcs

;******** Video Stuff ********
	dc.w	FlyerPlay-funcs
	dc.w	FlyerRecord-funcs
	dc.w	ChangeAudio-funcs
	dc.w	StartHeadList-funcs
	dc.w	EndHeadList-funcs
	dc.w	MakeClipHead-funcs
	dc.w	VoidClipHead-funcs
	dc.w	VoidCardHeads-funcs
	dc.w	VoidAllHeads-funcs
	dc.w	AudioParams-funcs
	dc.w	BeginFindField-funcs
	dc.w	DoFindField-funcs
	dc.w	EndFindField-funcs
	dc.w	FindFieldAudio-funcs
	dc.w	GetSMPTE-funcs

;******** Mode and Misc Stuff ********
	dc.w	VideoParams-funcs
	dc.w	StillMode-funcs
	dc.w	SetPlayMode-funcs
	dc.w	SetRecMode-funcs
	dc.w	SetNoMode-funcs
	dc.w	ToasterMux-funcs
	dc.w	InputSelect-funcs
	dc.w	Termination-funcs
	dc.w	SetFlooby-funcs
	dc.w	Defaults-funcs

;******** Direct Field Access ********
	dc.w	OpenReadField-funcs
	dc.w	OpenWriteField-funcs
	dc.w	CloseField-funcs
	dc.w	ReadLine-funcs
	dc.w	WriteLine-funcs
	dc.w	SetFillColor-funcs
	dc.w	SkipLines-funcs

;******** SCSI Operations ********
	dc.w	SCSIreset-funcs
	dc.w	SCSIinit-funcs
	dc.w	FindDrives-funcs
	dc.w	CopyData-funcs
	dc.w	ReqSense-funcs
	dc.w	Inquiry-funcs
	dc.w	ModeSelect-funcs
	dc.w	ModeSense-funcs
	dc.w	ReadSize-funcs
	dc.w	Read10-funcs
	dc.w	Write10-funcs
	dc.w	SCSIseek-funcs
	dc.w	SCSIdirect-funcs

;******* FileSystem Stuff ********
	dc.w	DriveCheck-funcs
	dc.w	DriveInfo-funcs
	dc.w	Locate-funcs
	dc.w	FileInfo-funcs		;This is not to be used anymore!!!
	dc.w	FreeGrip-funcs
	dc.w	CopyGrip-funcs
	dc.w	CmpGrips-funcs
	dc.w	Parent-funcs
	dc.w	Examine-funcs
	dc.w	DirList-funcs
	dc.w	FileOpen-funcs
	dc.w	FileClose-funcs
	dc.w	FileSeek-funcs
	dc.w	FileRead-funcs
	dc.w	FileWrite-funcs
	dc.w	CreateDir-funcs
	dc.w	Delete-funcs
	dc.w	Rename-funcs
	dc.w	RenameDisk-funcs
	dc.w	Format-funcs
	dc.w	DeFrag-funcs
	dc.w	SetBits-funcs
	dc.w	SetDate-funcs
	dc.w	SetComment-funcs
	dc.w	WriteProt-funcs
	dc.w	ChangeMode-funcs
	dc.w	MakeFlyerFile-funcs
	dc.w	GetClipInfo-funcs
	dc.w	CopyClip-funcs

;*********** Testing ************
	dc.w	CPUwrite-funcs
	dc.w	CPUread-funcs
	dc.w	CPUDMA-funcs
	dc.w	DebugMode-funcs
	dc.w	ReadTest-funcs
	dc.w	WriteTest-funcs

;*********** Stuff which needs sorted ************
	dc.w	SetFlyerTime-funcs
	dc.w	StripAudio-funcs
	dc.w	WriteCalib-funcs
	dc.w	ReadCalib-funcs
	dc.w	WriteEE-funcs
	dc.w	ReadEE-funcs
	dc.w	ResetFlyer-funcs
	dc.w	SetClockGen-funcs
	dc.w	TeachFPGA-funcs
	dc.w	FlyerRunning-funcs
	dc.w	LoadVideo-funcs
	dc.w	SetSerDevice-funcs
	dc.w	SelfTest-funcs
	dc.w	CompressModes-funcs
	dc.w	FIRquery-funcs
	dc.w	GetClrSeqErr-funcs
	dc.w	LockFlyVolList-funcs
	dc.w	UnLockFlyVolList-funcs

;*********** New Stuff for 4.0 ************
	dc.w	TBCcontrol-funcs
	dc.w	PauseAction-funcs
	dc.w	StartClipCutList-funcs
	dc.w	AddClipCut-funcs
	dc.w	EndClipCutList-funcs
	dc.w	EasyOpenWriteField-funcs
	dc.w	AudioControl-funcs
	dc.w	AppendFields-funcs

;*********** New Stuff for 4.05 ************
	dc.w	NewSequence-funcs
	dc.w	AddSeqClip-funcs
	dc.w	EndSequence-funcs
	dc.w	PlaySequence-funcs
	dc.w	FlyerOptions-funcs
	dc.w	LocateField-funcs
	dc.w	CacheTest-funcs

;*********** New Stuff for 4.1 ************
	dc.w	CopyClipNew-funcs
	dc.w	EndSequenceNew-funcs
	dc.w	DeFragNew-funcs
	dc.w	GetFrameHeader-funcs
	dc.w	PutFrameHeader-funcs
	dc.w	AddAudEKey-funcs
	dc.w	AddAudEnv-funcs
	dc.w	InitFlyerForce-funcs

;*********** New Stuff for 4.2 ************
	dc.w	FileExtend-funcs	
	dc.w	FileHSRead-funcs	
	dc.w	FileHSWrite-funcs	
	dc.w	NewFileRead-funcs
	dc.w	NewFileWrite-funcs
	dc.w	-1	;end


dataTable
	INITBYTE	LH_TYPE,NT_LIBRARY
	INITLONG	LN_NAME,FlyerName
	INITBYTE	LIB_FLAGS,LIBF_SUMUSED!LIBF_CHANGED
	INITWORD	LIB_VERSION,VERSION
	INITWORD	LIB_REVISION,REVISION
	INITLONG	LIB_IDSTRING,idString
	DC.L	0


*********************************************************
* InitRoutine
*	Called once to setup library
*
* Entry:
*	d0: Flyerbase (library base)
*	a0: SegList
*	a6: ExecBase
*
* Exit:
*	d0: Flyerbase (if Init took okay -- 0 if failed)
*********************************************************
InitRoutine
	movem.l	d1/d5/a0-a1/a4-a6,-(sp)

	IFD	DEBUGINIT
	DUMPHEXI.L <Flyer Library Init Called\Flyerbase = >,d0,<\>
	ENDC

	move.l	a6,a1			;ExecBase
	move.l	d0,a6			;Flyerbase
	move.l	a1,fl_SysLib(a6)
	move.l	a0,fl_SegList(a6)

	lea.l	fl_Volumes(a6),a0
	NEWLIST	a0			;Clear list of mounted volumes

;------ Ensure chip definitions are clear
	clr.l	fl_Mencode(a6)
	clr.l	fl_Pencode(a6)
	clr.l	fl_Mdecode(a6)
	clr.l	fl_Pdecode(a6)

;------ Blank out unit structure for each Flyer card ------
	lea.l	fl_Units(a6),a0		;Ptr to unit structures
	move.l	#((FlyerUnit_Sizeof*MAX_FLYER_CARDS)/2)-1,d0
.clrunits
	clr.w	(a0)+			;Clear unit's struct
	dbf	d0,.clrunits

;------ Look for Flyer card(s) ------
	lea.l	fl_Units(a6),a5		;Ptr to unit structure
	move.l	a6,-(sp)

	move.l	fl_SysLib(a6),a6	;Get ExecBase
	lea.l	ExpansionName(pc),a1
	CLEAR	d0
	XSYS	OpenLibrary		;Open Expansion library
	tst.l	d0			;Succeeded?
	beq	.expfail
	move.l	d0,a6

	sub.l	a4,a4			;Prev configdev ptr = NULL
	moveq.l	#MAX_FLYER_CARDS-1,d5
.nextboard
	move.l	a4,a0			;Prev configdev
	move.l	#NEWTEK_ID,d0		;Manufacturer ID
	moveq.l	#FLYER_ID,d1		;Product ID
	XSYS	FindConfigDev		;Find Flyer board
	tst.l	d0			;Found (another) one?
	beq	.nomore

	move.l	d0,a4			;(Start from here next time)
	move.l	cd_BoardAddr(a4),d0	;Get board's address
	move.l	d0,unit_SRAMbase(a5)	;Store in unit's structure

	IFD	DEBUGINIT
	DUMPHEXI.L <Found Flyer board at >,d0,<\>
	ENDC

	lea.l	FlyerUnit_Sizeof(a5),a5	;Advance to next unit
	dbf	d5,.nextboard		;Do up to 'n' cards
.nomore
	move.l	a6,a1
	move.l	(_AbsExecBase).w,a6
	XSYS	CloseLibrary		;Close Expansion library
.expfail
	move.l	(sp)+,a6

;============= TEST VERSION ONLY ===================
;	lea.l	fl_Units(a6),a5		;Get ptr to first unit
;	tst.l	unit_SRAMbase(a5)	;Found at least one real card?
;	bne	.gotreal
;	move.l	#SRAMSIZE,d0		;If not, fake one for now
;	move.l	#MEMF_PUBLIC,d1
;	move.l	a6,-(sp)
;	move.l	(_AbsExecBase).w,a6
;	XSYS	AllocMem		;Allocate simulated SRAM
;	move.l  (sp)+,a6
;	move.l	d0,fl_Test(a6)
;	IFD	DEBUGINIT
;	DUMPHEXI.L <Pseudo SRAM Allocation = >,d0,<\>
;	ENDC
;	tst.l	d0
;	beq	.fail			;If fails, dump library
;	move.l	d0,unit_SRAMbase(a5)
;.gotreal
;==========================================================

	lea.l	fl_Units(a6),a5		;Get ptr to first unit
	tst.l	unit_SRAMbase(a5)	;Any cards found?
	beq	.fail

	moveq.l	#MAX_FLYER_CARDS-1,d5
.eachFlyer

	IFD	DEBUGINIT
	moveq.l	#MAX_FLYER_CARDS-1,d0
	sub.l	d5,d0
	DUMPHEXI.L <----Flyer Card #>,d0,<----\>
	ENDC

;------ Clear each card's SRAM ------
	move.l	unit_SRAMbase(a5),d0	;Skip this card?

	IFD	DEBUGINIT
	DUMPHEXI.L <   SRAM addr:>,d0,<\>
	ENDC

	tst.l	d0
	beq.s	.thatsall

;	IFD	DEBUGGEN
;	DUMPMSG <ACCESS 1>
;	ENDC

	move.l	d0,a0
	lea.l	CMDBASE(a0),a0		;Skip to Amiga-accessible area
	move.l	#((SHAREDTOP-CMDBASE)/2)-1,d0
.clrSRAM
	clr.w	(a0)+			;Clear unit's SRAM
	dbf	d0,.clrSRAM

;------ Compute Data SRAM size, add to FreeList Pool for this card ------
	move.l	unit_SRAMbase(a5),a0
	move.l	#SHAREDTOP,d0
	move.l	#CMDBASE+(MAX_FLYER_CMDS*FLYER_CMD_LEN),d1
	add.l	d1,a0
	sub.l	d1,d0

	IFEQ	NEWMEMALLOC
	bsr	AddChunk		;Add Data Area SRAM chunk into pool
	ENDC
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	IFNE	NEWMEMALLOC
	move.l	a0,d1
	addq.l	#7,d1
	and.w	#$FFF8,d1		;Round start up to next boundary (8)
	exg	a0,d1			;a0 = start of pool
	sub.l	a0,d1			;d1 = -adj size
	add.l	d1,d0			;Adjust total pool size
	and.w	#$FFF8,d0		;And round down to even multiple of (8)

	clr.l	MC_NEXT(a0)		;Setup one big SRAM chunk
	move.l	d0,MC_BYTES(a0)

	lea.l	unit_MemHdr(a5),a1	;a1 = memHeader structure
	move.b	#NT_MEMORY,LN_TYPE(a1)
	move.l	d0,MH_FREE(a1)		;Number of free bytes
	move.l	a0,MH_FIRST(a1)		;First free region
	move.l	a0,MH_LOWER(a1)		;Lower memory bound
	add.l	d0,a0
	move.l	a0,MH_UPPER(a1)		;Upper memory bound
	lea.l	FlyerName(pc),a0
	move.l	a0,LN_NAME(a1)
	ENDC

	lea.l	FlyerUnit_Sizeof(a5),a5	;Advance to next unit

	dbf	d5,.eachFlyer		;Do up to 'n' cards

.thatsall
	move.l	a6,d0			;Init'd okay
	bra.s	.okay
.fail
	CLEAR	d0			;Do this if failed to init
.okay
	IFD	DEBUGINIT
	DUMPHEXI.L <Init returning: >,d0,<\>
	ENDC

	movem.l	(sp)+,d1/d5/a0-a1/a4-a6
	rts



*********************************************************************
* Open - Somebody called OpenLibrary
*
* Entry:
*	a6: Flyerbase (Library Base)
*
* Exit:
*********************************************************************
Open
;	IFD	DEBUGGEN
;	DUMPMSG <Open called>
;	ENDC

	addq.w	#1,LIB_OPENCNT(a6)
	bclr	#FLB_DELEXP,fl_PrivFlags(a6)
	move.l	a6,d0
	rts


*********************************************************************
* Close - Somebody called CloseLibrary
*
* Entry:
*	a6: Flyerbase (Library Base)
*
* Exit:
*********************************************************************
Close
;	IFD	DEBUGGEN
;	DUMPMSG <Close called>
;	ENDC

	CLEAR	d0
	subq.w	#1,LIB_OPENCNT(a6)
	bne.s	.NoExpunge

	btst	#FLB_DELEXP,fl_PrivFlags(a6)
	beq.s	.NoExpunge

;	IFD	DEBUGGEN
;	DUMPMSG <Calling expunge>
;	ENDC

	bsr	Expunge
.NoExpunge
	rts


*******************************************************************
* Expunge - System is trying to expunge me or I'm expunging myself.
*
* Entry:
*	a6:Flyerbase (Library Base)
*
* Exit:
*******************************************************************
Expunge
	movem.l	d1-d2/a0-a2/a5-a6,-(sp)
	move.l	a6,a5
	move.l	fl_SysLib(a6),a6	;Get ExecBase

;	IFD	DEBUGGEN
;	DUMPMSG <Expunge called>
;	ENDC

;Disable expunge for now (OS calling expunge sometimes for no apparent
;reason -- causes me to lose M/Pcoder chip definitions!
;	tst.w	LIB_OPENCNT(a5)		;Anyone left open?
;	beq.s	.okay

;----- Somebody still has me open, so set the delayed expunge flag
	bset	#FLB_DELEXP,fl_PrivFlags(a5)
	CLEAR	d0			;"Can't do it just now"
	bra.s	.exit

.okay
;============= TEST VERSION ONLY ===================
;	move.l	fl_Test(a5),d0
;	beq.s	.nomem
;	move.l	d0,a1
;	move.l	#SRAMSIZE,d0
;	XSYS	FreeMem
;.nomem
;==========================================================

;----- Free all mounted volumes
	lea.l	fl_Volumes(a5),a2
.nextvol
	move.l	(a2),a2		;Get next node
	tst.l	(a2)		;A valid node?
	beq	.finis
	move.l	a2,a1
	moveq.l	#FVN_sizeof,d0
	XSYS	FreeMem		;Free VolNode
	bra.s	.nextvol
.finis

;----- Free all chip definitions
	lea.l	fl_Mencode(a5),a0
	bsr	FreeChipDef
	lea.l	fl_Pencode(a5),a0
	bsr	FreeChipDef
	lea.l	fl_Mdecode(a5),a0
	bsr	FreeChipDef
	lea.l	fl_Pdecode(a5),a0
	bsr	FreeChipDef


	move.l	fl_SegList(a5),d2

	move.l	a5,a1
	XSYS	Remove			;Unlink from library list

	CLEAR   d0
	move.l  a5,a1
	move.w  LIB_NEGSIZE(a5),d0	;Compute size of library
	sub.l   d0,a1
	add.w   LIB_POSSIZE(a5),d0
	XSYS FreeMem			;Free library memory

	move.l	d2,d0			;SegList to UnLoadSeg
.exit
	movem.l	(sp)+,d1-d2/a0-a2/a5-a6
	rts

*****************************************************************
* Null - Does nothing
*
* Entry:
*	a6:Flyerbase (Library Base)
*
* Exit:
*****************************************************************
Null
	CLEAR	d0
	rts


**************************************************************************
*************************** UTILITY ROUTINES *****************************
**************************************************************************


***************************************************************************
* *** GetCardUnit ***
* 
* Returns the unit structure (in a5) for the Flyer card specified.  Fails
* if unit is out of range or no such physical card exists.
* 
* Entry:
*	d0:(BYTE) unit byte 0-n
*	a6:Flyerbase (library)
*
* Exit:
*	 Z=set on success, clr on failure
*	d0=error code
*	a5=unit ptr
***************************************************************************
GetCardUnit
	move.l	d1,-(sp)
	cmp.b	#MAX_FLYER_CARDS,d0	;In legal range?
	bcc	.faildude		;If not, abort with error
	CLEAR	d1
	move.b	d0,d1
	move.w	#FlyerUnit_Sizeof,d0
	mulu	d1,d0
	lea.l	fl_Units(a6,d0.l),a5	;Get pointer to spec'd unit structure
	tst.l	unit_SRAMbase(a5)	;Is there a card here?
	beq	.fail			;No, uhoh
	moveq.l	#FERR_OKAY,d0		;No error
	bra	.exit
.faildude
	IFD	DEBUGSKELL
	DUMPHEXI.L <There is no board # >,d0,<!!!\>
	ENDC
.fail
	sub.l	a5,a5			;Return w/failure
	moveq.l	#FERR_NOCARD,d0		;Error code
.exit
	move.l	(sp)+,d1
	tst.l	d0			;Set Z if success
	rts


***************************************************************************
* *** Get_Vol_Cmd ***
* 
* First, processes the FlyerVolume structure, converting a volume name to
* numbers (board/channel/drive).  Then finds the proper Flyer unit structure
* for the board specified.  Then searches the Flyer unit's command list,
* looking for a blank spot that can be used for a new command.  If necessary
* to get one, older complete commands may be flushed out.
*
* If an error occurs, Z flag will be clr, d0 will contain error code
* If no error, Z flag will be set, but d0 will be unchanged
* 
* Entry:
*	a0:struct FlyerVolume *volume
*	a6:Flyerbase (library)
*
* Exit:
*	 Z=set on success, clr on error
*	d0=untouched on success, error code on error
*	a3=cmd SRAM ptr
*	a4=cmd struct ptr
*	a5=unit ptr
***************************************************************************
Get_Vol_Cmd
	move.l	d0,-(sp)
	bsr	FindVolume		;Convert volume to brd/chan/drv
	bne.s	.error			;Failed? Exit

	move.b	fv_Board(a0),d0		;Board #
	bsr.s	Get_Brd_Cmd		;Proceed w/ board number
	bne.s	.error
	move.l	(sp)+,d0		;Restore d0
	cmp.l	d0,d0			;Z set
	rts
.error
	addq.l	#4,sp			;Throw away old d0
	tst.l	d0			;Return error w/Z clr
	rts

***************************************************************************
* *** Get_Brd_Cmd ***
* 
* Finds the requested Flyer unit structure, then searches the Flyer unit's
* command list, looking for a blank spot that can be used for a new command.
* If necessary to get one, older complete commands may be flushed out.
* 
* Entry:
*	d0:(BYTE) unit byte 0-n
*	a6:Flyerbase (library)
*
* Exit:
*	 Z=set on success, clr on error
*	d0=error code
*	a3=cmd SRAM ptr
*	a4=cmd struct ptr
*	a5=unit ptr
***************************************************************************
Get_Brd_Cmd
	IFD	DEBUGCMD
	DUMPMSG <*** Get_Brd_Cmd ***>
	ENDC

	bsr	GetCardUnit
	bne	.exit			;Failed? Exit
	bsr	FindFreeCmd
	tst.l	d0
	bne.s	.noretry
	moveq.l	#0,d0
	bsr	FlushAsyncs	;Try flushing complete commands
	bsr	FindFreeCmd	;Now try again
	tst.l	d0
	bne.s	.noretry
	moveq.l	#1,d0
	bsr	FlushAsyncs	;Getting really desparate
	bsr	FindFreeCmd	;Now try again
	tst.l	d0
	beq	.nosuccess
.noretry
	IFD	DEBUGVERBOSE
	DUMPHEXI.L <Found free cmd at >,a3,<\>
	ENDC

	move.b	#RT_STOPPED,cmd_RetTime(a4)	;Default = synchronous

	moveq.l	#FERR_OKAY,d0
	bra.s	.exit

.nosuccess
	moveq.l	#FERR_NOFREECMD,d0		;Could not get a command

.exit
	tst.l	d0		;Error?
	rts


***************************************************************************
* *** FindFreeCmd ***
* This searches the Flyer unit's command list, looking for a blank spot that
* can be used for a new command.  If one is found it is entirely cleared.
* 
* Entry:
*	a5:Unit ptr
*	a6:Flyerbase (Library Base)
*
* Exit:
*	a3,d0=cmd SRAM ptr (0 if failed)
*	a4=cmd struct ptr
***************************************************************************
FindFreeCmd
	movem.l	d1/a0-a1/a6,-(sp)

	IFD	DEBUGVERBOSE
	DUMPHEXI.L <*** FindFreeCmd ***\(Unit ptr = >,a5,<)\>
	ENDC

	move.l	fl_SysLib(a6),a6	;Get ExecBase
	move.l	unit_SRAMbase(a5),a3
	lea.l	CMDBASE(a3),a3		;a3 = start of SRAM command area
	lea.l	unit_Cmds(a5),a4	;a4 = start of command structures

	IFD	DEBUGVERBOSE
	DUMPHEXI.L <a3 starts at >,a3,<\>
	DUMPHEXI.L <a4 starts at >,a4,<\>
	ENDC

	moveq.l	#MAX_FLYER_CMDS-1,d1
	FORBID				;This search loop is atomic
.scanloop
	move.w	(a3),d0			;Opcode $0000 = free
	beq.s	.gotfree
	lea.l	FLYER_CMD_LEN(a3),a3	;Not free, advance both ptrs
	lea.l	FlyerCmd_Sizeof(a4),a4
	dbf	d1,.scanloop
	PERMIT				;DOES NOT kill d0,d1,a0,a1
	CLEAR	d0			;Found none!
	bra	.exit

.gotfree
	IFD	DEBUGVERBOSE
	DUMPHEXI.L <Going to take one at >,a3,<\>
	ENDC

	moveq.l	#1,d0
	move.w	d0,(a3)			;Opcode $0001 = blank, but taken

	PERMIT				;DOES NOT kill d0,d1,a0,a1

	CLEAR	d0
	moveq.l	#FLYER_CMD_LEN-3,d1
.clearloop
	move.b	d0,2(a3,d1.w)		;Blank SRAM command except for opcode
	dbf	d1,.clearloop
	move.b	d0,cmd_RetTime(a4)	;Clear most info for this command
	move.l	d0,cmd_Dataptr1(a4)
	move.l	d0,cmd_Datalen1(a4)
	move.l	d0,cmd_Dataptr2(a4)
	move.l	d0,cmd_Datalen2(a4)
	move.l	d0,cmd_FollowUp(a4)
	move.l	d0,cmd_CopySrc(a4)
	move.l	d0,cmd_CopyDest(a4)
	move.l	d0,cmd_CopySize(a4)
	move.l	d0,cmd_CopyExtra(a4)
	move.l	a3,d0			;Return ptr to buffer in SRAM
.exit
	movem.l	(sp)+,d1/a0-a1/a6
	rts

***************************************************************************
* *** FreeCmdSlot ***
* Frees up cmd slot for someone else to use.  Normally used to gracefully
* handle an error after command was reserved.
* 
* Entry:
*	a3:cmd SRAM ptr
*	a4:cmd struct ptr
*
* Exit:
***************************************************************************
FreeCmdSlot
	bsr	FreeCmdMem		;Add any SRAM back into pool
FreeJustCmdSlot
	move.w	#0,(a3)	   ;Clear opcode to make slot free! (avoid clr.w???)
	rts


***********************************************************************
* *** FlushAsyncs ***
* Change any completed asyncronous commands back into blanks for future use
* Knows not to touch ones which have the FLYB_ASYNC option set.
*
* If "desparate" flag set, will ignore the FLYB_ASYNC bit, and will
* stop after flushing just one.
*
* Entry:
*	a5:Unit ptr
*	d0:Desparate flag
*	a6:Flyerbase (Library Base)
*
* Exit:
***********************************************************************
FlushAsyncs
	movem.l	d0-d2/a0-a1/a3-a4,-(sp)

	IFD	DEBUGGEN
	DUMPMSG <Trying "FlushAsyncs">
	ENDC

	move.b	d0,d2

	move.l	a6,-(sp)
	move.l	fl_SysLib(a6),a6	;Get ExecBase
	FORBID				;Search loop is atomic
	move.l	(sp)+,a6

	move.l	unit_SRAMbase(a5),a3
	lea.l	CMDBASE(a3),a3		;a3 = start of SRAM command area
	lea.l	unit_Cmds(a5),a4	;a4 = start of command structures
	moveq.l	#MAX_FLYER_CMDS-1,d1
.flushloop
	move.w	(a3),d0			;Check status of this command
	and.w	#STATMASK,d0
	cmp.w	#STAT_DONE,d0		;Done?
	bne.s	.skipcmd			;If not, skip
	move.b	cmd_RetTime(a4),d0
	cmp.b	#RT_STOPPED,d0		;Command invoked synchronously?
	beq.s	.skipcmd			;If so, is still processing
	cmp.b	#RT_ATTACHED,d0		;Command invoked synchronously?
	beq.s	.skipcmd			;If so, is still processing
	cmp.b	#RT_FREE,d0		;Free to reclaim anytime?
	beq.s	.takeit				;If so, do it!
	tst.b	d2			;Desparate for a command?
	beq.s	.skipcmd			;No, leave other asyncs alone
.takeit
	bsr	FreeCmdMem		;Add any SRAM back into pool
	CLEAR	d0
	move.w	d0,(a3)			;Okay, this command can be used now
	tst.b	d2			;Stop after just 1?
	bne.s	.finis
.skipcmd
	lea.l	FLYER_CMD_LEN(a3),a3
	lea.l	FlyerCmd_Sizeof(a4),a4	;Advance both ptrs to next cmd
	dbf	d1,.flushloop
.finis
	move.l	a6,-(sp)
	move.l	fl_SysLib(a6),a6	;Get ExecBase
	PERMIT				;DOES NOT kill d0,d1,a0,a1
	move.l	(sp)+,a6
	movem.l	(sp)+,d0-d2/a0-a1/a3-a4
	rts



***********************************************************************
* *** FreeCmdMem ***
* Free any SRAM that may have been allocated to the command
*
* Entry:
*	a4:cmd struct ptr
*
* Exit:
***********************************************************************
FreeCmdMem
	movem.l	d0/a0/a5,-(sp)		;Must save d0 (return code)
	move.l	cmd_Unit(a4),a5
	move.l	cmd_Dataptr1(a4),a0
	clr.l	cmd_Dataptr1(a4)
	move.l	cmd_Datalen1(a4),d0
	clr.l	cmd_Datalen1(a4)
	bsr	AddChunk		;Add back into pool
	move.l	cmd_Dataptr2(a4),a0
	clr.l	cmd_Dataptr2(a4)
	move.l	cmd_Datalen2(a4),d0
	clr.l	cmd_Datalen2(a4)
	bsr	AddChunk		;Add back into pool
	movem.l	(sp)+,d0/a0/a5
	rts


***********************************************************************
* *** IDtoA3A4 ***
* Convert given ID to proper a3 & a4 ptrs for command.
* Also, checks ID to see if it is bogus.
*
* Entry:
*	d0:ID
*
* Exit:
*	 Z=set if okay, clr if bogus
*	d0=error code
*	a3,a4 = pointers for command
***********************************************************************
IDtoA3A4
	tst.l	d0				;Null pointer?
	beq.s	.bogus
	btst.l	#0,d0				;Not word-aligned?
	bne.s	.bogus
	move.l	d0,a4				;Get a4 from ID
	move.l	cmd_SRAMptr(a4),a3		;Get a3 from a4
	cmp.b	#MAJIC_ID,cmd_Majic(a4)		;Authentic mark?
	bne.s	.bogus
	moveq.l	#FERR_OKAY,d0			;Set Z flag
	bra.s	.exit
.bogus
	moveq.l	#FERR_BADID,d0			;Clr Z flag
.exit
	rts

***********************************************************************
* *** IDdone ***
* Remove memory of ID from channel register
*
* Entry:
*	a4:ID
*
* Exit:
***********************************************************************
IDdone
;	movem.l	d0-d1/a0,-(sp)
;	move.l	a4,d0
;	move.l	cmd_Unit(a4),a0
;	lea.l	unit_ChanIDs(a0),a0
;	moveq.l	#NUMIDS-1,d1
;.loop
;	cmp.l	(a0),d0			;Found it?
;	bne	.skipit
;	clr.l	(a0)			;Remove and exit
;
;	IFD	DEBUGASYNC
;	DUMPHEXI.L <ID >,d0,< removed\>
;	ENDC
;
;	bra.s	.exit
;.skipit
;	addq.l	#4,a0
;	dbf	d1,.loop
;.exit
;	movem.l	(sp)+,d0-d1/a0
	rts


***********************************************************************
* *** FireCmd ***
* *** FireAction ***
* These commands place command code into SRAM buffer for Flyer to execute
* FireAction also expects a ClipAction ptr in a0, will store async ID if
* needed
*
* Entry:
*	d0:operation code (word)
*	a0:ClipAction ptr ("FireAction" only)
*	a1:FollowUp routine (or 0)
*	a3:cmd SRAM ptr
*	a4:cmd struct ptr
*	a5:Unit ptr
*	a6:Flyerbase (Library Base)
*
* Exit:
*	d0=Error code (ID is now planted in ClipAction Results when applicable)
***********************************************************************
FireCmd
	movem.l	a0-a1/a3-a4,-(sp)		;Must do to be parallel
	sub.l	a0,a0				;No ClipAction for this command
	bra.s	FireMerge
FireAction
	movem.l	a0-a1/a3-a4,-(sp)		;Must do to be parallel
FireMerge
	move.l	a1,cmd_FollowUp(a4)		;Rout to call when done
	move.l	a3,cmd_SRAMptr(a4)		;Link to SRAM buffer
	move.l	a5,cmd_Unit(a4)			;Link to unit structure
	move.b	#MAJIC_ID,cmd_Majic(a4)		;Mark as authentic

	btst	#FUB_RUNNING,unit_PrivFlags(a5)	;Not running anymore
	beq	.isdead				;If Flyer not alive, reject cmd

;	cmp.w	#0,a0				;A ClipAction included?
;	beq.s	.noaction
;	clr.b	ca_Done(a0)			;Init this field
;.noaction

	move.l	a0,cmd_Action(a4)

	or.w	#STAT_NEW,d0

	IFD	DEBUGCMD
	DUMPHEXI.w <Cmd:>,d0,<\>
	DUMPHEX	<# SRAM cmd #>,(a3),#16	;32
	ENDC

	move.w	d0,(a3)				;Plug in opcode (Go Flyer!)

	move.b	cmd_RetTime(a4),d0

	IFD	DEBUGCMD
	DUMPHEXI.b <RetTime: >,d0,<\>
	ENDC

	cmp.b	#RT_STOPPED,d0			;Busy wait til done?
	beq	BusyWait			; -> Do sync
	cmp.b	#RT_ATTACHED,d0			;Attached to main command?
	beq	BusyWait			; -> Do sync, leave ID
	cmp.b	#RT_FREE,d0			;Return nothing?
	beq.s	.setfree
	cmp.b	#RT_STARTED,d0
	bne.s	.nowaitstart
	bsr	_WaitStart			;Wait for start or error
	tst.l	d0				;Error from cmd already?
	bne	BusyWait			;If so, wrap up command!
.nowaitstart
	bsr	MakeID				;Assign async ID
	bra.s	.exit				;Sets error/okay code

.setfree
	bsr	ZonkID				;Clear out async ID
.okay
	moveq.l	#FERR_OKAY,d0
	bra.s	.exit
.isdead
	moveq.l	#FERR_NOCARD,d0
	bra	FlyerDead
.exit
	movem.l	(sp)+,a0-a1/a3-a4
	rts


***********************************************************************
* WaitCmdStart -- Wait until a play command has begun
* 
* Entry:
*	d0:ID (returned from asyncronous command)
*
* Exit:
*	d0: Return code
***********************************************************************
WaitCmdStart:
	movem.l	a3-a4,-(sp)
	bsr	IDtoA3A4	;Check for bogus ID, retrieve ptrs
	bne.s	.exit

	bsr	_WaitStart

.exit
	movem.l	(sp)+,a3-a4
	rts


***********************************************************************
* _WaitStart -- Wait until a command has begun to operate
* 
* Entry:
*	a3:cmd SRAM ptr
*	a4:cmd ctrl structure
*	a6:Flyerbase (Library Base)
*
* Exit:
*	d0=error code
***********************************************************************
_WaitStart:
.until
	move.b	2(a3),d0	;Check cont flag
	cmp.b	#2,d0		;Started?
	beq.s	.broke

;	tst.b	3(a3)		;Error?
;	bne.s	.broke

	move.w	(a3),d0
	and.w	#STATMASK,d0
	cmp.w	#STAT_DONE,d0	;Command totally done?
	bne.s	.until

.broke
	bsr	DoFollowUp		;Update action struct, get error code
.exit
	rts



*****i* flyer.library/AbortCmd ******************************************
*
*   NAME
*	AbortCmd -- abort a Flyer command then wait for completion
*
*   SYNOPSIS
*	error = AbortCmd(ID)
*	D0               D0
*
*	ULONG AbortCmd(ULONG);
*
*   FUNCTION
*
*   INPUTS
*	ID - returned from asyncronous command invocation
*
*   RESULT
*	error - result code
*
*   EXAMPLE
*
*   NOTES
*
*   BUGS
*
*   SEE ALSO
*
*****************************************************************************
AbortCmd:
	IFD	DEBUGGEN
	DUMPMSG <AbortCmd>
	ENDC
	movem.l	a0-a1/a3-a4,-(sp)
	bsr	IDtoA3A4	;Check for bogus ID, retrieve ptrs
	bne.s	.exit
	CLEAR	d0
	move.b	d0,2(a3)	;Clear "cont" flag
	bra	BusyWait	;Now wait for completion...
.exit
	movem.l	(sp)+,a0-a1/a3-a4
	rts

*****i* flyer.library/CheckCmd ******************************************
*
*   NAME
*	CheckCmd -- Check if a previously started command has completed
*
*   SYNOPSIS
*	error = CheckCmd(ID)
*	D0               D0
*
*	ULONG CheckCmd(ULONG);
*
*   FUNCTION
*	Checks if a previously started command is complete.  If so,
*	wrap-up command entirely.  If not, copyback any data that might
*	need updated.
*
*   INPUTS
*	ID - returned from asyncronous command invocation
*
*   RESULT
*	error - FERR_BUSY if not done, else result code
*
*   EXAMPLE
*
*   NOTES
*
*   BUGS
*
*   SEE ALSO
*
*****************************************************************************
CheckProgress
	IFD	DEBUGGEN
	DUMPMSG <CheckProg>
	ENDC
	movem.l	a0-a1/a3-a4,-(sp)

	sub.l	a0,a0			;No CA
	bra.s	Check_join

CheckProgressNew
	IFD	DEBUGGEN
	DUMPMSG <CheckProgNew>
	ENDC
	movem.l	a0-a1/a3-a4,-(sp)
					;a0 = valid CA ptr

Check_join
	IFD	DEBUGASYNC
	DUMPHEXI.L <Check Progress on: >,d0,<\>
	ENDC

	bsr	IDtoA3A4	;Check for bogus ID, retrieve ptrs
	bne	.exit

	bsr	MaybeClearCache		;Clear cache for some CPU's (when needed)

	cmp.w	#0,a0			;Have ptr to CA structure?
	beq.s	.nostatus
	move.l	28(a3),ca_Status(a0)	;If so, update Status
.nostatus

	CLEAR	d0
	move.w	(a3),d0

	IFD	DEBUGASYNC
	DUMPHEXI.L <Prog Opcode: >,d0,<\>
	ENDC

	and.w	#STATMASK,d0	;Done?
	cmp.w	#STAT_DONE,d0
	beq	FollowUpCmd

;??	bsr	DoFollowUp		;Update data anyway
	moveq.l	#FERR_BUSY,d0
.exit
	movem.l	(sp)+,a0-a1/a3-a4
	rts


***********************************************************************
* WaitDone -- Wait for a previously started command to complete
* 
* Entry:
*	d0: ID
*	a6:Flyerbase (Library Base)
*
* Exit:
*	d0: Return code
***********************************************************************
WaitDone
	movem.l	a0-a1/a3-a4,-(sp)
	bsr	IDtoA3A4	;Check for bogus ID, retrieve ptrs
	bne	BusyExit

BusyWait

***
*** Maybe watch for Flyer disk change messages here
***

	move.w	(a3),d0
	and.w	#STATMASK,d0	;Wait til done before returning
	cmp.w	#STAT_DONE,d0
	bne.s	BusyWait

FollowUpCmd
	bsr	DoFollowUp		;Do follow-up routine, get error code

FlyerDead
	IFD	DEBUGCMD
	DUMPHEXI.L <Return value: >,d0,<\>
	DUMPHEX	<# Follow-up #>,(a3),#16	;32
	ENDC

	bsr	ZonkID			;Clear out async ID
;	bsr	IDdone			;Remove ID from list, if present
;	bsr	FreeCmdMem		;Add any SRAM back into pool
	bsr	FreeCmdSlot		;Free cmd slot
BusyExit
	movem.l	(sp)+,a0-a1/a3-a4
	rts


***********************************************************************
* DoFollowUp -- Do command-specific copyback operation
* 
* Entry:
*	a3:cmd SRAM ptr
*	a4:cmd ctrl structure
*	a6:Flyerbase (Library Base)
*
* Exit:
*	d0: Return code
***********************************************************************
DoFollowUp
	movem.l	a0-a1/a5,-(sp)

	bsr	MaybeClearCache		;Clear cache for some CPU's (when needed)

	move.l	cmd_FollowUp(a4),d0	;Get Followup vector

	IFD	DEBUGCMD
	DUMPHEXI.L <Follow-Up Rout: >,d0,<\>
	ENDC

	tst.l	d0
	beq	.no_fup			;Any?
	move.l	d0,a1
	move.l	cmd_Unit(a4),a5		;Get card's unit structure in a5
	jsr	(a1)
	ext.w	d0
	ext.l	d0			;Extend BYTE to LONG (result)
.no_fup
	movem.l	(sp)+,a0-a1/a5
	rts


***********************************************************************
* ZonkID -- Clear out asynchronous ID for this command
* 
* Entry:
*	a4:cmd ctrl structure
*
* Exit:
***********************************************************************
ZonkID
	movem.l	d0/a0,-(sp)
	move.b	cmd_RetTime(a4),d0
	cmp.b	#RT_ATTACHED,d0			;Don't touch ID if attached
	beq.s	.donttouch
	move.l	cmd_Action(a4),a0		;Skip if no Results struct
	cmp.w	#0,a0
	beq.s	.donttouch
	clr.l	ca_ID(a0)			;Cmd done, clear async ID
.donttouch
	movem.l	(sp)+,d0/a0
	rts


***********************************************************************
* MakeID -- Give this command an asynchronous ID
* 
* Entry:
*	a4:cmd ctrl structure
*
* Exit:
*	d0: Return code
***********************************************************************
MakeID
	move.l	a0,-(sp)
	move.l	cmd_Action(a4),a0	;Error if no Action structure
	cmp.w	#0,a0
	beq.s	.error
	move.l	a4,ca_ID(a0)		;Store async ID
	moveq.l	#FERR_OKAY,d0
	bra.s	.exit
.error
	moveq.l	#FERR_ASYNCFAIL,d0
.exit
	move.l	(sp)+,a0
	rts

******* flyer.library/WaitAction ******************************************
*
*   NAME
*	WaitAction - Wait for a previously issued action to complete
*
*   SYNOPSIS
*	error = WaitAction(action)
*	D0                 A0
*
*	ULONG WaitAction(struct ClipAction *);
*
*   FUNCTION
*	Does not return until the specified action is complete.
*
*   INPUTS
*	action - pointer to structure that was used to issue the original
*	   command
*
*   RESULT
*	error - return code (from command)
*
*   EXAMPLE
*
*   NOTES
*
*   BUGS
*
*   SEE ALSO
*	CheckAction
*
*****************************************************************************
WaitAction
	IFD	DEBUGGEN
	DUMPMSG <WaitAction>
	ENDC
	cmp.w	#0,a0
	beq.s	.error

	move.l	ca_ID(a0),d0		;Get ID from structure
	beq.s	.isdone			;If none, already done

	bsr	WaitDone
	bra.s	.exit
.isdone
	moveq.l	#FERR_OKAY,d0
	bra.s	.exit
.error
	moveq.l	#FERR_BADPARAM,d0
.exit
	rts

******* flyer.library/CheckAction ******************************************
*
*   NAME
*	CheckAction - Check progress of an actions
*
*   SYNOPSIS
*	status = CheckAction(action)
*	D0                   A0
*
*	ULONG CheckAction(struct ClipAction *);
*
*   FUNCTION
*	Checks if the operation associated with the provided ClipAction
*	pointer has finished or not.  Returns FERR_OKAY if the action has
*	finished, or FERR_BUSY if it is still in progress.
*
*	Also, starting with rev 4.08, updates the (new) ca_Status field with
*	current status for the command.  This data is only available with
*	certain commands that use ClipAction structures (still "RSN").
*
*   INPUTS
*	action - pointer to structure that was used to issue the original
*	         command
*
*   RESULT
*	status = FERR_OKAY or FERR_BUSY
*
*   EXAMPLE
*
*   NOTES
*
*   BUGS
*
*   SEE ALSO
*	WaitAction
*
*****************************************************************************
* Does copyback of a specific or all pending actions.
* Checks if an action is still pending or is done.
*********************************************************************
CheckAction
	IFD	DEBUGGEN
	DUMPMSG <CheckAction>
	ENDC
	cmp.w	#0,a0			;Provided ClipAction pointer?
	beq.s	.error

	move.l	ca_ID(a0),d0		;Get ID from structure
	beq.s	.isdone			;If none, already done

	bsr	CheckProgressNew	;(New version also updates "ca_Status")
	bra.s	.exit			;Sets error code/okay/busy

.isdone
	moveq.l	#FERR_OKAY,d0
	bra.s	.exit
.error
	moveq.l	#FERR_BADPARAM,d0
.exit
	IFD	DEBUGSKELL
	DUMPHEXI.L <*** Result = >,d0,< ***\>
	ENDC
	rts


******* flyer.library/AbortAction ******************************************
*
*   NAME
*	AbortAction - abort a previously started action
*
*   SYNOPSIS
*	error = AbortAction(action)
*	D0                  A0
*
*	ULONG AbortAction(struct ClipAction *);
*
*   FUNCTION
*	Attempts to abort an action that was previously initiated.  Does
*	nothing if it has already finished.
*
*	If ClipAction ptr is NULL, aborts all pending operations to all
*	Flyers.
*
*   INPUTS
*	action - ptr to ClipAction structure used to start the action
*	    (or NULL to abort everything)
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*
*   BUGS
*
*   SEE ALSO
*
*****************************************************************************
AbortAction
	IFD	DEBUGGEN
	DUMPMSG <AbortAction>
	ENDC
	movem.l	d1-d2/a0-a6,-(sp)

	cmp.w	#0,a0
	beq.s	.abortall

	move.l	ca_ID(a0),d0		;Get ID from structure
	beq	.isdone			;If none, already done

	bsr	AbortCmd
	bra	.exit

.abortall
	IFD	DEBUGGEN
	DUMPMSG <Trying "Aborting everything!">
	ENDC

	moveq.l	#0,d0			;SHOULD REALLY SCAN FROM 1 to n!!!
	bsr	GetCardUnit
	bne	.isdone			;Failed? Exit

	move.l	unit_SRAMbase(a5),a3
	lea.l	CMDBASE(a3),a3		;a3 = start of SRAM command area
	lea.l	unit_Cmds(a5),a4	;a4 = start of command structures
	move.l	a6,-(sp)
	move.l	fl_SysLib(a6),a6	;Get ExecBase
	FORBID				;Search loop is atomic
	move.l	(sp)+,a6
	moveq.l	#MAX_FLYER_CMDS-1,d1
.flushloop
	move.w	(a3),d0
	and.w	#STATMASK,d0
	beq.s	.skipslot		;Skip unused cmd slots
	cmp.w	#STAT_DONE,d0
	beq.s	.skipslot		;Skip completed cmds

	CLEAR	d0
	move.b	d0,2(a3)		;Signal to abort

.skipslot
	lea.l	FLYER_CMD_LEN(a3),a3
	lea.l	FlyerCmd_Sizeof(a4),a4	;Advance both ptrs to next cmd
	dbf	d1,.flushloop
	move.l	a6,-(sp)
	move.l	fl_SysLib(a6),a6	;Get ExecBase
	PERMIT				;DOES NOT kill d0,d1,a0,a1
	move.l	(sp)+,a6

;**** Now wait for all who are aborted to complete
;**** (As each stops, shouldn't we do wrap-up?!?!?!?!)
;	moveq.l	#-1,d2			;Timeout value
;	move.l	unit_SRAMbase(a5),a3
;	lea.l	CMDBASE(a3),a3		;a3 = start of SRAM command area
;	lea.l	unit_Cmds(a5),a4	;a4 = start of command structures
;	moveq.l	#MAX_FLYER_CMDS-1,d1
;.flushloop2
;	tst.b	2(a3)			;Was aborted, right?
;	bne.s	.skipslot2		;No, skip this one
;.waittildone
;	subq.l	#1,d2			;More time expired
;	beq.s	.timeout		;Don't hang with Flyer!
;	move.w	(a3),d0
;	and.w	#STATMASK,d0
;	beq.s	.skipslot2		;Completed?
;	cmp.w	#STAT_DONE,d0
;	bne.s	.waittildone		;Completed?
;
;.skipslot2
;	lea.l	FLYER_CMD_LEN(a3),a3
;	lea.l	FlyerCmd_Sizeof(a4),a4	;Advance both ptrs to next cmd
;	dbf	d1,.flushloop2

.timeout

	CLEAR	d0
	CLEAR	d1
	bsr	ResetFlyer		;Reset Flyer to default states
.isdone
	moveq.l	#FERR_OKAY,d0
	bra.s	.exit

.error
	moveq.l	#FERR_BADPARAM,d0
.exit
	movem.l	(sp)+,d1-d2/a0-a6
	rts


******* flyer.library/PauseAction ******************************************
*
*   NAME
*	PauseAction - pause/resume a previously started action
*
*   SYNOPSIS
*	error = PauseAction(action,pauseflag)
*	D0                  A0     D0
*
*	ULONG PauseAction(struct ClipAction *,UBYTE pauseflag);
*
*   FUNCTION
*	Pauses or resumes a Flyer action that has been previously started.
*	Provide a pointer to the ClipAction structure used to start the
*	action.  No error occurs if action is already in the state specified
*	(already paused, for example).  AbortAction can be used to terminate
*	a paused action.
*
*	Does nothing if the action has already finished.
*
*   INPUTS
*	action - ptr to ClipAction structure used to start the action
*
*	pauseflag - 1 to pause, 0 to resume
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*	Currently works only with FlyerRecord actions
*
*   BUGS
*
*   SEE ALSO
*	AbortAction
*
*****************************************************************************
PauseAction
	IFD	DEBUGGEN
	DUMPMSG <PauseAction>
	ENDC
	movem.l	d0-d1/a3-a4,-(sp)
	move.b	d0,d1

	cmp.w	#0,a0
	beq.s	.exit

	move.l	ca_ID(a0),d0		;Get ID from structure
	beq	.exit			;Already done?

	bsr	IDtoA3A4	;Check for bogus ID, retrieve ptrs
	bne.s	.exit

	move.b	#$FF,d0		;(Pause)
	tst.b	d1		;Pause flag true?
	bne.s	.doit
	move.b	#$01,d0		;(Go)
.doit
	move.b	d0,2(a3)	;Modify status to Flyer

.exit
	moveq.l	#FERR_OKAY,d0
	movem.l	(sp)+,d0-d1/a3-a4
	rts

***********************************************************************
* *** FastCopy ***
* 
* Entry:
*	d0:Size in bytes (LONG)
*	a0:Src data ptr
*	a1:Dest data ptr
*
***********************************************************************
* This could use some real optimization!
* Try to coerce copy to long boundary so we can copy fast!
* Double-odd copy should be sync'ed up to do long copies
FastCopy
	movem.l	d0-d1/a0-a1,-(sp)

	IFD	DEBUGCMD
	DUMPHEXI.L <  From: >,a0,<\>
	DUMPHEXI.L <    To: >,a1,<\>
	DUMPHEXI.L <   Len: >,d0,<\>
	ENDC

	tst.l	d0
	beq.s	.avoid			;Nothing to move?

	move.l	a0,d1	;Make sure src pointer is non-0
	beq.s	.avoid
	btst.l	#0,d1	;If odd, copy by bytes only
	bne.s	.bytecopy

	move.l	a1,d1	;Make sure dest pointer is non-0
	beq.s	.avoid
	btst.l	#0,d1	;If odd, copy by bytes only
	bne.s	.bytecopy

	move.l	d0,d1
	lsr.l	#2,d1	;# longs in d1
	and.w	#3,d0	;Residual bytes in d0

	bra.s	.intocopy1
.copyloop1
	swap	d1
.copyloop2
	move.l	(a0)+,(a1)+		;Copy 4-bytes at a time
.intocopy1
	dbf	d1,.copyloop2
	swap	d1
	dbf	d1,.copyloop1

.bytecopy
	bra.s	.intocopy2
.copyloop3
	move.b	(a0)+,(a1)+		;Copy 1-byte at a time
.intocopy2
	dbf	d0,.copyloop3
.avoid
	movem.l	(sp)+,d0-d1/a0-a1
	rts


***********************************************************************
* *** CopytoSRAM ***
*	Allocates a chunk of SRAM and copies data from source ptr into it
* 
* Entry:
*	d0:Size in bytes (LONG)
*	a1:Src data ptr
*	a3:cmd SRAM ptr
*	a4:cmd ctrl structure
*	a5:unit structure
*
* Exit:
*	Z: set on success, clr on failure
*	d0:SRAM offset address (or error code on failure)
***********************************************************************
CopytoSRAM
	movem.l	d1/a1,-(sp)

	IFD	DEBUGCMD
	DUMPMSG <*** CopytoSRAM ***>
	ENDC

	tst.l	d0		;Any to copy?
	beq.s	.success	;If not, just slip thru

	move.l	d0,d1		;Save size for later
				;d0=amount
	bsr	AllocSRAM	;Get SRAM memory for use
	tst.l	d0		;Succeeded?
	beq.s	.error

	move.l	a1,a0		;src ptr
	move.l	d0,a1		;dest ptr
	move.l	d1,d0		;length
	bsr	FastCopy	;Copy source data

	move.l	a1,d0		;Return address of SRAM (offset)
	sub.l	unit_SRAMbase(a5),d0
.success
	cmp.l	d0,d0		;Set Z flag for success
	bra.s	.exit
.error
	bsr	FreeCmdSlot		;Won't use cmd
	moveq.l	#FERR_LIBFAIL,d0	;Also clears Z flag
.exit
	movem.l	(sp)+,d1/a1
	rts


***********************************************************************
* *** AutoAllocSRAM ***
* Tries to acquire contiguous SRAM on the current Flyer card.
* Will flush older complete asyncronous commands, if necessary.
* If cannot get entire chunk, will reduce size until we get something.
*
* Entry:
*	d1:Size desired (LONG)
*	a4:cmd ctrl structure
*	a5:unit structure
*
* Exit:
*	d1 = Size allocated (LONG)
*	d0 = ptr to SRAM, or 0 if failed
***********************************************************************
AutoAllocSRAM
.Retry	move.l	d1,d0
	bsr	AllocSRAM	;Try this size
	tst.l	d0		;Got it?
	bne.s	.Done
	lsr.l	#1,d1		;Reduce size to 1/2
	beq.s	.Done		;All sizes failed? quit
	btst	#0,d1		;Does that leave an odd size?
	beq.s	.Retry
	addq.l	#1,d1		;If so, make even
	bra.s	.Retry
.Done	rts


***********************************************************************
* *** AllocSRAM ***
* Tries to acquire contiguous SRAM on the current Flyer card.
* Will flush older complete asyncronous commands, if necessary.
*
* Will always allocate even-size chunks, even if an odd size is requested
*
* Entry:
*	d0:Bytes needed (LONG)
*	a4:cmd ctrl structure
*	a5:unit structure
*
* Exit:
*	d0 = ptr to SRAM, or 0 if failed
***********************************************************************
AllocSRAM
	move.l	d1,-(sp)
	btst.l	#0,d0		;Odd size?
	beq.s	.even
	addq.l	#1,d0		;If so, bump up to even size
.even
	move.l	d0,d1
	bsr	GetChunk	;Try to get memory
	tst.l	d0		;Success?
	bne.s	.good
	moveq.l	#0,d0		;Not desparate
	bsr	FlushAsyncs	;Maybe this will help: flush complete commands
	move.l	d1,d0		;size
	bsr	GetChunk	;Try again
	tst.l	d0
	beq.s	.exit		;Exit if error
.good
	tst.l	cmd_Dataptr1(a4)	;Already got 1 chunk?
	bne.s	.use2nd
	move.l	d0,cmd_Dataptr1(a4)	;Keep track of memory alloc'd
	move.l	d1,cmd_Datalen1(a4)	;to this command
	bra.s	.exit
.use2nd
	move.l	d0,cmd_Dataptr2(a4)	;Keep track of memory alloc'd
	move.l	d1,cmd_Datalen2(a4)	;to this command
.exit
	move.l	(sp)+,d1
	rts


***********************************************************************
* *** GetChunk ***
* Tries to acquire 'd0' bytes of contiguous SRAM
* Should only get requests for even-sized chunks, since this routine
* does not guarantee word-alignment on the allocated chunks otherwise
*
* Entry:
*	d0:bytecount (LONG)
*	a5:unit structure
*	a6:Flyerbase (Library Base)
*
* Exit:
*	d0 = ptr to SRAM, or 0 if failed
***********************************************************************

	IFEQ	NEWMEMALLOC
GetChunk
	movem.l	d1-d2/a0-a2/a6,-(sp)

	IFD	DEBUGCMD
	DUMPHEXI.L <GetChunk called, wants bytes: >,d0,<\>
	ENDC

	move.l	fl_SysLib(a6),a6	;Get ExecBase
	FORBID				;Memory allocation must be atomic!
	lea.l	unit_FreeList(a5),a0	;a0 = start of freelist structure
	moveq.l	#MAX_POOL_FRAGS-1,d2
.findloop
	tst.l	fc_Size(a0)
	beq.s	.listthru
	cmp.l	fc_Size(a0),d0		;This one big enough?
	bls.s	.willdo
	lea.l	FC_Sizeof(a0),a0	;Try next chunk
	dbf	d2,.findloop
.listthru
	sub.l	a2,a2			;Uhoh, couldn't get memory!
	bra	.exit
.willdo
	move.l	fc_Start(a0),a2		;Get ptr to memory
	add.l	d0,fc_Start(a0)		;Deduct from free pool chunk
	sub.l	d0,fc_Size(a0)
	bne	.Someleft		;Took all of this chunk?
	bra.s	.closeup2
.closeup				;Move others up to take place
	move.l	fc_Start(a0),fc_Start-FC_Sizeof(a0)
	move.l	fc_Size(a0),fc_Size-FC_Sizeof(a0)
	clr.l	fc_Start(a0)		;Make hole properly blank
	clr.l	fc_Size(a0)
.closeup2
	lea.l	FC_Sizeof(a0),a0	;Advance to next chunk
	dbf	d2,.closeup		;Moved all?

.Someleft
	IFD	DEBUGCMD
	DUMPHEXI.L <GetChunk succeeded, Addr: >,a2,<\>
	ENDC
	IFD	DEBUGSRAM
	bsr	DumpFreeList
	ENDC
.exit
	PERMIT				;DOES NOT kill d0,d1,a0,a1
	move.l	a2,d0
	movem.l	(sp)+,d1-d2/a0-a2/a6
	rts

	ENDC

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

	IFNE	NEWMEMALLOC
GetChunk
	movem.l	d1/a0-a1/a6,-(sp)

	IFD	DEBUGCMD
	DUMPHEXI.L <GetChunk called, wants bytes: >,d0,<\>
	ENDC

	move.l	fl_SysLib(a6),a6	;Get ExecBase
	FORBID				;Memory allocation must be atomic!
	lea.l	unit_MemHdr(a5),a0	;a0 = memHeader structure
	XSYS	Allocate		;Allocate memory from our SRAM pool

	IFD	DEBUGCMD
	DUMPHEXI.L <GetChunk returned addr: >,d0,<\>
	ENDC

	PERMIT				;DOES NOT kill d0,d1,a0,a1

	movem.l	(sp)+,d1/a0-a1/a6
	rts

	ENDC


***********************************************************************
* *** AddChunk ***
* Add chunk of memory (back) into free SRAM pool.  Keeps all chunks of
* memory sorted in list, simplifies chunk list wherever possible.
*
* Entry:
*	d0:byte length (LONG)
*	a0:Memory pointer
*	a5:unit ptr
*	a6:Flyerbase (Library Base)
*
* Exit:
***********************************************************************

	IFEQ	NEWMEMALLOC

AddChunk
	movem.l	d0-d2/a0-a2/a6,-(sp)
	tst.l	d0			;Any to really add?
	beq	.addnone

	IFD	DEBUGSRAM
	DUMPHEXI.L <*** AddChunk ***\Addr: >,a0,<\>
	DUMPHEXI.L <Size: >,d0,<\>
	DUMPHEXI.L <(Unit ptr = >,a5,<)\>
	ENDC

	move.l	fl_SysLib(a6),a6	;Get ExecBase
	FORBID				;Memory management must be atomic
	lea.l	unit_FreeList(a5),a2	;a2 = start of freelist structure
	moveq.l	#MAX_POOL_FRAGS-1,d2
.findloop				;Find place to insert this in lis
	tst.l	fc_Size(a2)		;Past end of list?
	beq.s	.inserthere
	cmp.l	fc_Start(a2),a0		;Found insertion point?
	beq.s	.exit			;(Already free? -- exit)
	bcs.s	.inserthere
	lea.l	FC_Sizeof(a2),a2	;Move to next entry in list
	dbf	d2,.findloop
	bra.s	.exit			;List is full, cannot add in?!?
.inserthere
;Maybe check here to see if previous chunk contains my start address
;If so, do not add it (already free)
.moveloop
	move.l	fc_Start(a2),a1		;Add entry in free list, spread rest
	move.l	fc_Size(a2),d1
	move.l	a0,fc_Start(a2)
	move.l	d0,fc_Size(a2)
	move.l	a1,a0
	move.l	d1,d0
	lea.l	FC_Sizeof(a2),a2	;Move others toward end of list
	dbf	d2,.moveloop

	IFD	DEBUGSRAM
	bsr	DumpFreeList
	ENDC

	bsr	MergeFreeList		;Merge any consecutive chunks
.exit
	PERMIT				;DOES NOT kill d0,d1,a0,a1
.addnone
	movem.l	(sp)+,d0-d2/a0-a2/a6
	rts

	ENDC

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

	IFNE	NEWMEMALLOC

AddChunk
	movem.l	d0-d1/a0-a1/a6,-(sp)
	tst.l	d0			;Any to really add?
	beq	.addnone

	IFD	DEBUGSRAM
	DUMPHEXI.L <*** AddChunk ***\Addr: >,a0,<\>
	DUMPHEXI.L <Size: >,d0,<\>
	DUMPHEXI.L <(Unit ptr = >,a5,<)\>
	ENDC

	move.l	fl_SysLib(a6),a6
	FORBID				;Memory management must be atomic
	move.l	a0,a1			;a1 = pointer to memory to free
	lea.l	unit_MemHdr(a5),a0	;a0 = memHeader structure
	XSYS	Deallocate		;Allocate memory from our SRAM pool

	PERMIT				;DOES NOT kill d0,d1,a0,a1
.addnone
	movem.l	(sp)+,d0-d1/a0-a1/a6
	rts

	ENDC


***********************************************************************
* *** MergeFreeList ***
* Combine any chunks in free list which are contiguous
*
* Entry:
*	a5:unit ptr
*	a6:ExecBase!
*
* Exit:
***********************************************************************

	IFEQ	NEWMEMALLOC

MergeFreeList
	movem.l	d0/d2/a0/a2,-(sp)
.Retry
	lea.l	unit_FreeList(a5),a2		;a2 = start of free list
	moveq.l	#(MAX_POOL_FRAGS-1)-1,d2
.Loop
	tst.l	fc_Size(a2)		;Anything here?
	beq.s	.NoJoin
	move.l	fc_Size(a2),a0
	add.l	fc_Start(a2),a0		;Compute first addr after this chunk
	cmp.l	FC_Sizeof+fc_Start(a2),a0   ;Will I connect with next chunk?
	bne.s	.NoJoin
	move.l	FC_Sizeof+fc_Size(a2),d0
	add.l	d0,fc_Size(a2)		;Add next chunk into this one
	bra.s	.IntoRipple
.Ripple
	move.l	FC_Sizeof+fc_Start(a2),fc_Start(a2)	;Move others to
	move.l	FC_Sizeof+fc_Size(a2),fc_Size(a2)	; close up the gap
.IntoRipple
	lea.l	FC_Sizeof(a2),a2	;Move to next entry
	dbf	d2,.Ripple
	clr.l	fc_Start(a2)		;Blank out hole at end of list
	clr.l	fc_Size(a2)

	IFD	DEBUGSRAM
	DUMPMSG <Simplified FreeList...>
	bsr	DumpFreeList
	ENDC

	bra	.Retry			;Try again until no more join up

.NoJoin
	lea.l	FC_Sizeof(a2),a2
	dbf	d2,.Loop
	movem.l	(sp)+,d0/d2/a0/a2
	rts

	ENDC

***********************************************************************
* *** MeasureString ***
* Returns length of string (+1 for NULL)
*
* Entry:
*	a1:Ptr to string (null-term)
*
* Exit:
*	d0:Length of string
***********************************************************************
MeasureString
	move.l	a1,-(sp)
	CLEAR	d0
	cmp.w	#0,a1		;Null ptr?
	beq.s	.exit

* Changed to pass a string containing only a null rather than a null ptr
*	tst.b	(a1)		;Null string?
*	beq.s	.exit

.loop
	addq.l	#1,d0
	tst.b	(a1)+
	bne.s	.loop
.exit
	move.l	(sp)+,a1
	rts


***********************************************************************
* *** MakeEven ***
* Make d0 even (word-aligned) if it isn't already (rounds up if needed)
*
* Entry:
*	d0:Input longword
*
* Exit:
*	d0:Output longword
***********************************************************************
MakeEven
	btst.l	#0,d0
	beq.s	.iseven
	addq.l	#1,d0
.iseven
	rts

***********************************************************************
* *** PassFlyerVolume ***
* Allocate SRAM for FlyerVolume structure and path string, as well as
* leaving optional room for other data.  Copy data into allocated SRAM.
*
* Entry:
*	a0:Ptr to FlyerVolume structure
*	d0:Amount of room to leave for extra data
*	a4:cmd ctrl structure
*	a5:unit structure
*
* Exit:
*	d0:Ptr to start of SRAM copy (or 0 if failed)
***********************************************************************
PassFlyerVolume
	movem.l	d1-d6/a0-a3/a6,-(sp)
	move.l	a0,a2		;FlyerVolume structure
	sub.l	a3,a3		;No ClipAction structure
	bra.s	PassMerge

***********************************************************************
* *** PassClipAction ***
* Allocate SRAM for ClipAction & FlyerVolume structures and
* path string, as well as leaving optional room for other data.  Copy
* data into allocated SRAM and link them all together.
*
* Entry:
*	a0:Ptr to ClipAction structure
*	d0:Amount of room to leave for extra data (.l)
*	a4:cmd ctrl structure
*	a5:unit structure
*
* Exit:
*	d0:Ptr to start of SRAM copy (or 0 if failed)
***********************************************************************
PassClipAction
	movem.l	d1-d6/a0-a3/a6,-(sp)
	move.l	a0,a3			;ClipAction structure
	move.l	ca_Volume(a3),a2	;FlyerVolume structure

PassMerge

	IFD	DEBUGCLIP
	DUMPHEXI.L <PassClip/Vol - Action: >,a3,<\>
	DUMPHEXI.L <Volume: >,a2,<\>
	ENDC

	move.l	d0,d5			;Extra length
	CLEAR	d1			;String length
	CLEAR	d2			;ClipAction length
	CLEAR	d4			;FlyerVolume length
	cmp.w	#0,a3			;ClipAction too?
	beq	.justvolume
	CLEAR	d2
	move.w	#CA_sizeof,d2		;Length of ClipAction structure

.justvolume
	cmp.w	#0,a2			;FlyerVolume structure?
	beq.s	.novolume

	moveq.l	#FV_sizeof,d4		;Length of FlyerVolume structure

	move.l	fv_Path(a2),a1
	bsr	MeasureString		;Path string length
	bsr	MakeEven		;Round up if needed to make even
	move.l	d0,d1
.novolume

	IFD	DEBUGCLIP
	DUMPHEXI.L <String Length: >,d1,<\>
	DUMPHEXI.L <ClipAction Length: >,d2,<\>
	DUMPHEXI.L <Volume Length: >,d4,<\>
	DUMPHEXI.L <Extra Length: >,d5,<\>
	ENDC

	move.l	d1,d6
	add.l	d2,d6
	add.l	d4,d6
	add.l	d5,d6			;Total length of all SRAM needed
	beq	.exit			;None needed, exit

	move.l	d6,d0
				;d0=amount
	bsr	AllocSRAM		;Get the SRAM I need
	tst.l	d0			;Failed?
	beq	.exit
	move.l	d0,a6
	add.l	d6,a6			;Ptr to end of SRAM

;Copy string (if any)
	tst.l	d1
	beq.s	.nocopystring
	sub.l	d1,a6			;Back up to area
	move.l	a6,a1			;dest
	move.l	fv_Path(a2),a0		;src
	move.l	d1,d0			;length
	bsr	FastCopy		;Copy string
	move.l	a6,d1
	sub.l	unit_SRAMbase(a5),d1	;Keep offset to name
.nocopystring

;Copy FlyerVolume (if any)
	tst.l	d4
	beq.s	.nocopyFV
	sub.l	d4,a6			;Back up to area
	move.l	a6,a1			;dest
	move.l	a2,a0			;src
	move.l	d4,d0			;length
	bsr	FastCopy		;Copy FlyerVolume structure
	move.l	d1,fv_Path(a6)		;Plug in SRAM offset of string (or 0)
	move.l	a6,d4
	sub.l	unit_SRAMbase(a5),d4	;Keep offset to structure
.nocopyFV

;Copy ClipAction (if any)
	tst.l	d2
	beq.s	.nocopyCA
	sub.l	d2,a6			;Back up to area
	move.l	a6,a1			;dest
	move.l	a3,a0			;src
	move.l	d2,d0			;len
	bsr	FastCopy		;Copy ClipAction structure
	move.l	d4,ca_Volume(a6)	;Plug in SRAM offset->FlyerVolume (or 0)

	move.l	a6,cmd_CopySrc(a4)	;Ptr to SRAM area (src)
	move.l	a0,cmd_CopyDest(a4)	;Ptr to user area (dest)
	move.l	d2,cmd_CopySize(a4)	;Copyback size

.nocopyCA
	sub.l	d5,a6			;Back up to SRAM chunk start
	move.l	a6,d0			;Return this

.exit
	movem.l	(sp)+,d1-d6/a0-a3/a6
	rts


***********************************************************************
* *** NewVolume ***
* Add a new volume to the mounted list
*
* Entry:
*	a0:Ptr to FlyerVolume structure
*	a1:Ptr to FlyerVolInfo structure
*	a6:Flyerbase (library)
*
* Exit:
***********************************************************************
NewVolume
	movem.l	d0-d1/a0-a6,-(sp)
	cmp.w	#0,a0		;A Null structure ptr?
	beq	.exit		;Can't allow that

	move.l	a0,a3
	move.l	a1,a4

	move.l	a6,a5
	move.l	fl_SysLib(a5),a6

	FORBID			;This search loop is atomic

;****** Look for a previous listing with same board/chan/unit
	lea.l	fl_Volumes(a5),a2
.nextvol
	move.l	(a2),a2		;Get next node
	tst.l	(a2)		;A valid node?
	beq.s	.makenew

	move.b	fvn_Board(a2),d0
	cmp.b	fv_Board(a3),d0
	bne.s	.nextvol
	move.b	fvn_SCSIdrive(a2),d0
	cmp.b	fv_SCSIdrive(a3),d0
	bne.s	.nextvol

	bra	.copyname		;Just copy name again


;****** Create new VolNode
.makenew
	moveq.l	#FVN_sizeof,d0
	move.l	#MEMF_PUBLIC!MEMF_CLEAR,d1
	XSYS	AllocMem		;Allocate a new VolNode
	tst.l	d0			;Failed?
	beq	.bailout
	move.l	d0,a2

	move.l	a2,a1			;Node
	lea.l	fl_Volumes(a5),a0	;List
	ADDHEAD				;Add in!

	move.b	fv_Board(a3),fvn_Board(a2)
	move.b	fv_SCSIdrive(a3),fvn_SCSIdrive(a2)
	move.b	fvi_Flags(a4),fvn_Flags(a2)

	IFD	DEBUGGEN
	DUMPSTR	fvi_Title(a4)
	DUMPMSG	< - Mounted volume>
	ENDC

.copyname
	IFD	DEBUGGEN
	DUMPMSG <Copying volume name>
	ENDC

	lea.l	fvi_Title(a4),a0
	lea.l	fvn_Name(a2),a1
	moveq.l	#80,d0
	bsr	FastCopy		;fvi_Title(a4) ---> fvn_Name(a2)

.bailout
	PERMIT				;DOES NOT kill d0,d1,a0,a1

.exit
	movem.l	(sp)+,d0-d1/a0-a6
	rts



***********************************************************************
* *** KillVolume ***
* Remove a volume from the mounted list
*
* Entry:
*	a0:Ptr to FlyerVolume structure
*	a6:Flyerbase (library)
*
* Exit:
***********************************************************************
KillVolume
	movem.l	d0-d1/a0-a3/a5-a6,-(sp)
	cmp.w	#0,a0		;A Null structure ptr?
	beq	.exit		;Can't allow that

	move.l	a0,a3

	move.l	a6,a5
	move.l	fl_SysLib(a5),a6

	FORBID			;This procedure is atomic

;****** Look for a listing with the board/chan/unit
	lea.l	fl_Volumes(a5),a2
.nextvol
	move.l	(a2),a2		;Get next node
	tst.l	(a2)		;A valid node?
	beq	.listend

	move.b	fvn_Board(a2),d0
	cmp.b	fv_Board(a3),d0
	bne.s	.nextvol
	move.b	fvn_SCSIdrive(a2),d0
	cmp.b	fv_SCSIdrive(a3),d0
	bne.s	.nextvol

	IFD	DEBUGGEN
	DUMPSTR	fvn_Name(a2)
	DUMPMSG	< - UnMounted volume>
	DUMPHEXI.l <VolNode at address >,a2,<\>
	ENDC

;****** Remove from list and free volume node
	move.l	a2,a1
	REMOVE			;Remove from list

	move.l	a2,a1
	moveq.l	#FVN_sizeof,d0
	XSYS	FreeMem		;Free VolNode

.listend

	PERMIT				;DOES NOT kill d0,d1,a0,a1

.exit
	movem.l	(sp)+,d0-d1/a0-a3/a5-a6
	rts


***********************************************************************
* *** FindVolume ***
* Convert volume name to board/channel/drive numbers (unless override flag)
*
* Entry:
*	a0:Ptr to FlyerVolume structure
*	a6:Flyerbase (library)
*
* Exit:
*	 Z=set on success, clr on failure
*	d0=error code
***********************************************************************
FindVolume
	movem.l	d1/a0-a5,-(sp)
	cmp.w	#0,a0			;A Null structure ptr?
	beq	.fail			;Can't allow that
	move.l	a0,a4
	move.l	fv_Path(a4),a5
	cmp.w	#0,a5
	beq	.success	;Null ptr?
	move.l	a5,a3

	IFD	DEBUGVOL
	DUMPHEXI.L <!!!Vol = >,a4,<\>
	DUMPHEXI.L <!!!Path = >,a5,<\>
	ENDC
.findend
	tst.b	(a3)
	beq	.success	;No volume name, just exit
	cmp.b	#':',(a3)+
	bne	.findend

	move.l	a3,fv_Path(a4)	;Strip volume from name
	subq.l	#1,a3

	cmp.l	a3,a5		;Any volume name?
	beq	.success	;No, was just ':', exit

	btst	#FVB_USENUMS,fv_Flags(a4)	;Override volume name w/nums?
	bne	.success	;If so, exit without converting to numbers

	lea.l	fl_Volumes(a6),a2
.nextvol
	move.l	(a2),a2		;Get next node
	tst.l	(a2)		;A valid node?
	beq	.fail

	move.l	a5,a0		;Specified volume name
	lea.l	fvn_Name(a2),a1	;Each volume's name
.nextchar
	moveq.l	#0,d0
	cmp.l	a0,a3		;If at colon, use NULL
	beq.s	.atcolon
	move.b	(a0)+,d0	;Make upper-case
	cmp.b	#'a',d0
	blo.s	.notLC1
	cmp.b	#'z',d0
	bhi.s	.notLC1
	sub.b	#32,d0
.notLC1
.atcolon
	move.b	(a1)+,d1	;Get next volume char
	cmp.b	#'a',d1		;Make upper-case
	blo.s	.notLC2
	cmp.b	#'z',d1
	bhi.s	.notLC2
	sub.b	#32,d1
.notLC2
	cmp.b	d0,d1		;Characters match?
	bne.s	.nextvol
	tst.b	d0		;End of strings?
	bne.s	.nextchar

;Match found, copy volume numerical info into user's structure
	move.b	fvn_Board(a2),fv_Board(a4)
	move.b	fvn_SCSIdrive(a2),fv_SCSIdrive(a4)

	IFD	DEBUGGEN
	DUMPMSG <!Volume replacement!>
	ENDC

.success
	moveq.l	#FERR_OKAY,d0
	bra.s	.exit

.fail
	moveq.l	#FERR_VOLNOTFOUND,d0

.exit
	movem.l	(sp)+,d1/a0-a5
	tst.b	d0
	rts


**********************
* For Debugging Only *
**********************
	IFD	DEBUGSRAM
DumpFreeList
	move.l	a2,-(sp)
	DUMPMSG <--- FreeList --->
	lea.l	unit_FreeList(a5),a2	;a2 = start of freelist structure
	moveq.l	#MAX_POOL_FRAGS-1,d2
.loop
	tst.l	fc_Size(a2)
	beq	.break
	DUMPHEXI.L <*** Addr: >,fc_Start(a2),<\>
	DUMPHEXI.L <    Size: >,fc_Size(a2),<\>
	lea.l	FC_Sizeof(a2),a2
	dbf	d2,.loop
.break
	DUMPMSG <----->
	move.l	(sp)+,a2
	rts
	ENDC


********************************************************************

*** Vanilla follow-up that just gets the return code ***

StdFollowUp			;Can trash a0,a1,d0
	move.b	3(a3),d0	;Get error code
	rts


*** Specialty follow-up that copies a chunk of data from Flyer SRAM ***
*** back into the user's memory.  Also retrieves the return code    ***

FollowUpCopy				;Can trash a0,a1,d0
	move.l	cmd_CopySrc(a4),a0	;Ptr to SRAM src data
	move.l	cmd_CopyDest(a4),a1	;Ptr to user's buffer to receive
	move.l	cmd_CopySize(a4),d0	;Size of move
	bsr	FastCopy		;Copy data back to user
	move.b	3(a3),d0		;Get error code
	rts


*** Specialty follow-up that copies Action structure from Flyer to user RAM.
*** Knows to preserve ca_Volume and ca_ID fields (which we don't want changed
*** on us)

CopyBackAction				;Can trash a0,a1,d0
	move.l	cmd_CopySrc(a4),a0	;Ptr to SRAM src data
	move.l	cmd_CopyDest(a4),a1	;Ptr to user's buffer to receive
	move.l	cmd_CopySize(a4),d0	;Size of move
	beq.s	.nocopyback
	move.l	ca_Volume(a1),-(sp)	;Save Volume ptr
	move.l	ca_ID(a1),-(sp)		;Save ID
	bsr	FastCopy		;Copy data back to user
	move.l	(sp)+,ca_ID(a1)		;Restore ID
	move.l	(sp)+,ca_Volume(a1)	;Restore Volume

.nocopyback
	move.b	3(a3),d0		;Get error code
	rts


*** Specialty follow-up that copies a structure from Flyer SRAM ***
*** back into the user's memory.  Does not trash 'len' field.   ***

FollowUpCopyStruct			;Can trash a0,a1,d0
	move.l	cmd_CopySrc(a4),a0	;Ptr to SRAM src data
	addq.l	#2,a0			;(skip 'len' field)
	move.l	cmd_CopyDest(a4),a1	;Ptr to user's buffer to receive
	addq.l	#2,a1
	move.l	cmd_CopySize(a4),d0	;Size of move
	subq.l	#2,d0
	bsr	FastCopy		;Copy data back to user
	move.b	3(a3),d0		;Get error code
	rts

********************************************************************
********************************************************************
* These are the actual Flyer library calls
********************************************************************
********************************************************************


CodeName	dc.b	'Flyer.dat',0
DSPName		dc.b	'DSP.dat',0
ChipCfgName	dc.b	'chipset.dat',0

MEncoderName	dc.b	'ME.dat',0
PEncoderName	dc.b	'PE.dat',0
MDecoderName	dc.b	'MD.dat',0
PDecoderName	dc.b	'PD.dat',0

SkewName	dc.b	'SK.dat',0
TmrtName	dc.b	'TR.dat',0
DmaName		dc.b	'DMA.dat',0
AudioName	dc.b	'AUD.dat',0
AlignName	dc.b	'AL.dat',0

	CNOP	0,4

ChipSetupTable
	dc.l	SkewName
	dc.b	1,0
	dc.l	TmrtName
	dc.b	2,0
	dc.l	DmaName
	dc.b	7,0
	dc.l	AudioName
	dc.b	8,0
	dc.l	AlignName
	dc.b	9,0
	dc.l	0,0

ChipTeachTable:
	dc.l	MEncoderName
	dc.b	0,0
	dc.l	PEncoderName
	dc.b	1,0
	dc.l	MDecoderName
	dc.b	2,0
	dc.l	PDecoderName
	dc.b	3,0
	dc.l	0,0

******* flyer.library/InitFlyers ******************************************
*
*   NAME
*	InitFlyers - setup all attached Flyer cards
*
*   SYNOPSIS
*	error = InitFlyers(lock)
*	D0                 D0
*
*	ULONG InitFlyers(BPTR);
*
*   FUNCTION
*	Perform setup on all Flyer boards present (programs all chips,
*	places all video channels in play mode, playing black).  Must be
*	called from a process so that library can access DOS functions.
*	Looks for all chip files needed in the directory which 'lock' is on.
*
*   INPUTS
*	lock - lock on directory in which to look for chip files
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*
*   BUGS
*
*   SEE ALSO
*
*****************************************************************************
* Setup each Flyer card: define FPGA's, defaults, etc.
* Must be called from a process!!!
*****************************************************************************
InitFlyers
	movem.l	d1-d5/d7/a0-a2/a4-a6,-(sp)
	move.l	d0,d4

	moveq.l	#4,d7		;Start with this LED pattern

	IFD	DEBUGINIT
	DUMPHEXI.L <InitFlyers called on lock >,d4,<\>
	ENDC

	CLEAR	d0		;SHOULD REALLY SCAN THRU ALL FLYERS PRESENT!!!

	bsr	GetCardUnit		;Get unit struct for card in a5
	bne	.exit			;Failed? Exit

	IFD	DEBUGINIT
	DUMPHEXI.L <Unit @ >,a5,<\>
	ENDC

*** Maybe leave this out, as it would allow people to put patch file in
*** and "FlyerInit" to pick it up and test it!
	CLEAR	d0
	btst	#FUB_SETUP,unit_PrivFlags(a5)	;Already setup?
	bne	.exit				;If so, just return okay
***********************************

	move.l	a6,-(sp)
	move.l	fl_SysLib(a6),a6
	lea.l	DosName(pc),a1
	CLEAR	d0
	XSYS	OpenLibrary
	move.l	(sp)+,a6
	moveq.l	#1,d1			;Failed to open dos.library
	move.l	d0,fl_DosBase(a6)	;Keep for a while
	tst.l	d0
	beq	.nodos

	move.l	d4,d1
	move.l	a6,-(sp)
	move.l	fl_DosBase(a6),a6
	XSYS	CurrentDir		;CD to lock given to me
	move.l	(sp)+,a6
	move.l	d0,d4			;Keep old lock

;**** Read and download Flyer.dat ****

	lea.l		CodeName(pc),a0
	moveq.l	#0,d5					;load the first flyer.bin found

	IFNE BINDEBUG
	DUMPMSG	<calling LoadFlyerBin on flyer.dat>
	ENDC

	bsr		LoadFlyerBin		;Load file into memory
	IFNE BINDEBUG
	DUMPMSG	<finished LoadFlyerBin>
	ENDC
	moveq.l	#2,d1					;Failed to read "flyer.dat"
	tst.l		d0
	bne		.reterr

	moveq.l	#0,d0			;Flyer board
	move.l	fl_BinaryBuffer(a6),a0	;Ptr to bin file
	move.l	fl_BinaryLength(a6),d1			;Length of program
	move.l	#PROGAREA,d2		;Offset at which to plant/run code
	IFNE BINDEBUG
	DUMPMSG	<calling Firmware>
	ENDC
	bsr	Firmware
	IFNE BINDEBUG
	DUMPMSG	<calling updateLEDs>
	ENDC
	bsr	UpdateLEDs		;Next pattern
	IFNE BINDEBUG
	DUMPMSG	<calling FreeFlyerFile>
	ENDC
	bsr	FreeFlyerFile
	moveq.l	#6,d1
	tst.b	d0			;Error?
	bne	.reterr
	IFNE BINDEBUG
	DUMPMSG	<freed file>
	ENDC

;**** Get the serial number of the board
	lea.l		-4(sp),sp	;get temporary long in memory
	move.l	sp,a4			;let a4 point to our temporary long
	move.l	a4,a0			;place the ptr into a0 for ReadEE
	moveq.l	#0,d0			;Flyer Board
	moveq.l	#4,d1			;address of high word of serial number
	IFNE BINDEBUG
	DUMPMSG	<reading hi-word of serial number>
	ENDC
	bsr		ReadEE		;get the hi-word of the serial number
	
	lea.l		2(a4),a0		;place ptr to lo-word into a0 for ReadEE
	moveq.l	#0,d0			;Flyer Board
	moveq.l	#3,d1			;address of low word of serial number
	IFNE BINDEBUG
	DUMPMSG	<reading lo-word of serial number>
	ENDC
	bsr		ReadEE		;get the lo-work of the serial number
	
	move.l	(a4),d1		;place the serial number in d1
	lea.l		4(sp),sp		;pop temporary memory off the stack

	lea.l		ChipCfgName(pc),a0	;place the name of the rule file into a0
	IFNE BINDEBUG
	DUMPMSG	<calling GetChipID>
	ENDC
	bsr		GetChipID	;get the chip ID for this board

	move.l	#FERR_CMDFAILED,d1
	tst.l		d0				;did we get a chip ID?
	beq		.reterr

	move.l	d0,d5			;place chip ID in d5 so LoadFlyerBin will find it	
	IFNE BINDEBUG
	DUMPHEXI.L	<we got chipID >,d5,<\>
	ENDC

;**** we need to shut down the old flyer.bin code to load the new one ****
	CLEAR		d0						;Flyer board 0
	bsr		QuitFlyer			;shut down the old code
	move.l	#1000000,d0			;wait until the Flyer reboots back into ROM
.bigdelay
	nop
	nop
	nop
	nop
	subq.l	#1,d0
	bne.s		.bigdelay
	; chipID is already in d5
	bsr		ProgramChips		; program the chips with the correct chip files

.reterr
	IFNE BINDEBUG
	DUMPMSG	<returning to previous dir>
	ENDC
	and.l	#$FF,d1			;Strip off all but lo byte
	movem.l	d1/a6,-(sp)		;save retcode
	move.l	fl_DosBase(a6),a6
	move.l	d4,d1
	XSYS	CurrentDir		;CD to previous location
	movem.l	(sp)+,d1/a6

*------ Close dos.library
	IFNE BINDEBUG
	DUMPMSG	<closing dos library>
	ENDC
	move.l	d1,-(sp)		;save retcode
	move.l	fl_DosBase(a6),a1
	move.l	a6,-(sp)
	move.l	fl_SysLib(a6),a6
	XSYS	CloseLibrary		;Close DOS library
	move.l	(sp)+,a6
	clr.l	fl_DosBase(a6)
	move.l	(sp)+,d1
.nodos
	move.l	d1,d0			;Return code

.exit
	IFNE BINDEBUG
	DUMPMSG	<restoring registers>
	ENDC
	movem.l	(sp)+,d1-d5/d7/a0-a2/a4-a6
	rts

******* flyer.library/InitFlyerForce ******************************************
*
*   NAME
*	InitFlyerForce - setup the Flyer card using a caller specified chipID
*
*   SYNOPSIS
*	error = InitFlyerForce(lock, id)
*	D0                 D0	 D5
*
*	ULONG InitFlyerForce(BPTR, ULONG);
*
*   FUNCTION
*	Perform setup on all Flyer boards present (programs all chips,
*	places all video channels in play mode, playing black).  Must be
*	called from a process so that library can access DOS functions.
*	Looks for all chip files needed in the directory which 'lock' is on,
*	with the given chipID
*
*   INPUTS
*	lock - lock on directory in which to look for chip files
*	id - ChipID to use to locate chip files to use in initializing the Flyer
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*
*   BUGS
*
*   SEE ALSO
*
*****************************************************************************
* Setup each Flyer card: define FPGA's, defaults, etc.
* Must be called from a process!!!
*****************************************************************************
InitFlyerForce
	movem.l	d1-d5/d7/a0-a2/a4-a6,-(sp)
	move.l	d0,d4

	moveq.l	#4,d7		;Start with this LED pattern

	IFD	DEBUGINIT
	DUMPHEXI.L <InitFlyers called on lock >,d4,<\>
	ENDC

	CLEAR	d0		;SHOULD REALLY SCAN THRU ALL FLYERS PRESENT!!!

	bsr	GetCardUnit		;Get unit struct for card in a5
	bne	.exit			;Failed? Exit

	IFD	DEBUGINIT
	DUMPHEXI.L <Unit @ >,a5,<\>
	ENDC

*** Maybe leave this out, as it would allow people to put patch file in
*** and "FlyerInit" to pick it up and test it!
	CLEAR	d0
	btst	#FUB_SETUP,unit_PrivFlags(a5)	;Already setup?
	bne	.exit				;If so, just return okay
***********************************

	move.l	a6,-(sp)
	move.l	fl_SysLib(a6),a6
	lea.l	DosName(pc),a1
	CLEAR	d0
	XSYS	OpenLibrary
	move.l	(sp)+,a6
	moveq.l	#1,d1			;Failed to open dos.library
	move.l	d0,fl_DosBase(a6)	;Keep for a while
	tst.l	d0
	beq	.nodos

	move.l	d4,d1
	move.l	a6,-(sp)
	move.l	fl_DosBase(a6),a6
	XSYS	CurrentDir		;CD to lock given to me
	move.l	(sp)+,a6
	move.l	d0,d4			;Keep old lock

	;chipID is in d5
	bsr		ProgramChips	;Program the chips with the given chipID files
	
.reterr
	IFNE BINDEBUG
	DUMPMSG	<returning to previous dir>
	ENDC
	and.l	#$FF,d1			;Strip off all but lo byte
	movem.l	d1/a6,-(sp)		;save retcode
	move.l	fl_DosBase(a6),a6
	move.l	d4,d1
	XSYS	CurrentDir		;CD to previous location
	movem.l	(sp)+,d1/a6

*------ Close dos.library
	IFNE BINDEBUG
	DUMPMSG	<closing dos library>
	ENDC
	move.l	d1,-(sp)		;save retcode
	move.l	fl_DosBase(a6),a1
	move.l	a6,-(sp)
	move.l	fl_SysLib(a6),a6
	XSYS	CloseLibrary		;Close DOS library
	move.l	(sp)+,a6
	clr.l	fl_DosBase(a6)
	move.l	(sp)+,d1
.nodos
	move.l	d1,d0			;Return code

.exit
	IFNE BINDEBUG
	DUMPMSG	<restoring registers>
	ENDC
	movem.l	(sp)+,d1-d5/d7/a0-a2/a4-a6
	rts

*********************************************************************
* ProgramChips -- open all dat files and load the bin data for
*                 the specified type of chips
*
* Entry:
*  a6:Flyerbase ( library )( dos library must be open and pointed to in flyerbase )
*  d5:Chip ID ( if 0, then load first bin in the dat file )
*
* Exit:
*********************************************************************
ProgramChips

	movem.l	d2-d5/d7/a0-a2/a4-a6,-(sp)

;**** Now program with the proper flyer.bin ****
	lea.l		CodeName(pc),a0	;Put the name of the file in a0
	;chip ID is already in d5
	IFNE BINDEBUG
	DUMPMSG	<loading the proper flyer.dat chunk>
	ENDC
	bsr		LoadFlyerBin		;Load the bin file into memory
	moveq.l	#2,d1					;failed to read flyer.dat file
	tst.l		d0
	bne		.reterr

;**** now we can load the new code ****
	moveq.l	#0,d0							;Flyer Board
	move.l	fl_BinaryBuffer(a6),a0	;Ptr to the bin file
	move.l	fl_BinaryLength(a6),d1	;Length of bin file
	move.l	#PROGAREA,d2				;Offset at which to plant/run code
	IFNE BINDEBUG
	DUMPMSG	<calling firmware with new flyer.bin>
	ENDC
	bsr	Firmware
	IFNE BINDEBUG
	DUMPMSG	<calling updateLEDS>
	ENDC
	bsr	UpdateLEDs						;Next pattern
	IFNE BINDEBUG
	DUMPMSG	<freeing file>
	ENDC
	bsr	FreeFlyerFile
	moveq.l	#6,d1
	tst.b	d0			;Error?
	bne	.reterr
	IFNE BINDEBUG
	DUMPMSG	<freed file>
	ENDC

;	CLEAR	d0
;	move.l	#$2100,d1
;	bsr	DebugMode

;**** Test Flyer SRAM/CPU cache compatibility ****
	bsr	CacheTest
	IFNE BINDEBUG
	DUMPMSG	<tested cache>
	ENDC

;**** Read and program Skew,Tmrt,Dma,Audio,Align chips ****

	lea.l	ChipSetupTable(pc),a2
.eachchip
	move.l	(a2)+,a0		;Get name of chip file
	cmp.w	#0,a0			;End?
	beq.w	.chipsdone
	IFNE BINDEBUG
	move.b	(a2),d0	;put chip number in d0 for debugging
	DUMPHEXI.b	<setting up chip >,d0,<\>
	ENDC

	bsr	LoadFlyerBin		;Load file into memory
	bsr	UpdateLEDs		;Next pattern
	tst.l	d0
	beq.s	.loadedchipokay
	move.b	(a2),d1
	lsl.b	#4,d1
	add.b	#3,d1			;error = chip/3
	IFNE BINDEBUG
	DUMPMSG	<failed to load chip file>
	ENDC
	bra	.reterr			;3 = "failed to load chip file"
.loadedchipokay
	move.l	fl_BinaryBuffer(a6),a1	;Ptr to program
	move.b	(a2),d0			;Chip number we should be doing
	cmp.b	fch_chipnum(a1),d0	;Data is for correct chip?
	beq.s	.correctchip
	move.b	(a2),d1
	lsl.b	#4,d1
	add.b	#4,d1			;error = chip/4
	IFNE BINDEBUG
	DUMPMSG	<chip mismatch>
	ENDC
	bra	.reterr			;4 = "chip mismatch"
.correctchip

*** For DMA chip, set clock just before programming chip
	move.w	d0,-(sp)
	cmp.b	#7,d0		;DMA chip?
	bne.s	.nosetclock
	IFNE BINDEBUG
	DUMPMSG	<setting clock for dma chip>
	ENDC
	moveq.l	#0,d0		;Flyer #0
	moveq.l	#0,d1		;Clock 0 (DMA)
	move.l	fch_speed(a1),d2	;DMA clock speed
	beq.s	.nosetclock	;Real value?
	DUMPREG 	<D2 HAS CLOCK SPEED FOR DMA CLOCK>
	bsr	SetClockGen	;Do it
	bsr	UpdateLEDs		;Next pattern
.nosetclock
	move.w	(sp)+,d1	;Recall chip #

	moveq.l	#0,d0			;Flyer board
					;d1 = chipnum
	move.b	fch_chiprev(a1),d3	;Chip revision
	lea.l	fch_length(a1),a0	;a0 = ptr to chip length
	move.l	(a0)+,d2		;Length of data
	bsr	PgmFPGA			;Program Flyer chip
	bsr	UpdateLEDs		;Next pattern
	bsr	FreeFlyerFile
	tst.b	d0			;Error?
	beq.s	.chipokay
	move.b	(a2),d1
	lsl.b	#4,d1
	add.b	#5,d1			;error = chip/5
	bra	.reterr			;5 = "pgm failed"
.chipokay
	addq.l	#2,a2			;Skip to next table entry
	bra.w	.eachchip
.chipsdone


;**** Read and download DSP ****

	lea.l	DSPName(pc),a0
	IFNE BINDEBUG
	DUMPMSG	<loading dsp file>
	ENDC

	bsr	LoadFlyerBin		;Load file into memory
	bsr	UpdateLEDs		;Next pattern
	moveq.l	#7,d1			;Failed to read "DSP.bin"
	tst.l	d0
	bne	.reterr
	moveq.l	#0,d0			;Flyer board
	move.l	fl_BinaryLength(a6),d1	;Length of program
	move.l	fl_BinaryBuffer(a6),a0	;Ptr to program
	IFNE BINDEBUG
	DUMPMSG	<sending dsp file to flyer>
	ENDC
	bsr	DSPboot			;Send to Flyer
	bsr	UpdateLEDs		;Next pattern
	bsr	FreeFlyerFile
	moveq.l	#8,d1
	tst.b	d0			;Error?
	bne	.reterr


;**** Read and teach M/PEncoders, M/PDecoders ****

	lea.l	ChipTeachTable(pc),a2
.eachteach
	move.l	(a2)+,a0		;Get name of chip file
	cmp.w	#0,a0			;End?
	beq.w	.teachdone
	IFNE BINDEBUG
	move.b	(a2),d0		;place chip number in d0 for debugging
	DUMPHEXI.B	<loading teach file for chip >,d0,<\> 
	ENDC
	bsr	LoadFlyerBin		;Load file into memory
	bsr	UpdateLEDs		;Next pattern
	tst.l	d0
	beq.s	.loadeddefokay
	move.b	(a2),d1
	lsl.b	#4,d1
	add.b	#9,d1			;error = chip/9
	IFNE BINDEBUG
	DUMPMSG	<failed to load def file>
	ENDC
	bra.w	.reterr			;9 = "failed to load def file"
.loadeddefokay
	move.l	fl_BinaryBuffer(a6),a1	;Ptr to program
	tst.b	4(a1)			;This is a definition file, right?
	bne.s	.badfile
	move.b	(a2),d0			;Chip def we should be doing
	cmp.b	5(a1),d0		;Data is for correct definition?
	beq.s	.correctdef
.badfile
	IFNE BINDEBUG
	DUMPMSG	<bad def file>
	ENDC
	move.b	(a2),d1
	lsl.b	#4,d1
	add.b	#10,d1			;error = chip/A
	bra.w	.reterr			;A = "def mismatch"
.correctdef
	;d0 = definition number
	move.l	fl_BinaryLength(a6),d1	;Length of data
	move.l	a1,a0			;Ptr to data
	IFNE BINDEBUG
	DUMPMSG	<teaching fpga>
	ENDC
	bsr	TeachFPGA		;Store in library
	bsr	UpdateLEDs		;Next pattern
	bsr	FreeFlyerFile
	tst.b	d0
	beq.s	.teachokay		;Succeeded?

	move.b	(a2),d1
	lsl.b	#4,d1
	add.b	#11,d1			;error = chip/B
	IFNE BINDEBUG
	DUMPMSG	<failed to teach>
	ENDC
	bra.s	.reterr			;B = "failed to teach"
.teachokay
	IFNE BINDEBUG
	DUMPMSG	<teach succeeded>
	ENDC
	addq.l	#2,a2			;Skip to next table entry
	bra.w	.eachteach
.teachdone

	moveq.l	#0,d0			;Board 0
	IFNE BINDEBUG
	DUMPMSG	<setting play mode>
	ENDC
	bsr	PlayMode		;Start in play mode

	bset	#FUB_SETUP,unit_PrivFlags(a5)	;Setup okay
	moveq.l	#FERR_OKAY,d1		;Succeeded!


*------ Done, return to previous dir
.reterr
; returns error in d1
.exit
	IFNE BINDEBUG
	DUMPMSG	<restoring registers>
	ENDC
	movem.l	(sp)+,d2-d5/d7/a0-a2/a4-a6
	rts


UpdateLEDs
	addq.l	#1,d7

	movem.l	d0-d3,-(sp)

	CLEAR	d0			;Board 0
	CLEAR	d1			;Chan xxx
	move.b	#FLOOBY_LEDS,d2		;Item
	move.l	d7,d3			;Pattern -> value
	bsr	SetFlooby

	movem.l	(sp)+,d0-d3
	rts

*********************************************************************
* GetChipID -- Open a config file and find the long-word chipID
*              for the given Flyer serial number
* 
* Entry:
*  a0:Pointer to name of file
*  a6:FlyerBase ( library )
*  d1:serial number of the Flyer board
*
* Exit:
*********************************************************************
GetChipID:
	movem.l	d1-d4/a0-a2/a5-a6,-(sp)
	
	;Upon entry, everything is set up to go directly to LoadFlyerFile
	bsr		LoadFlyerFile					;Load the config file
	tst.l		d0									;was there an error loading the file?
	bne.s		.exit

	move.l	fl_BinaryBuffer(a6),a2		;place ptr to buffer in a2
	move.l	fl_BinaryLength(a6),d2		;place length of buffer in d2
	move.l	#0,d0								;place null in d0 for result

.nextid
	cmp.l		#12,d2							;check length of buffer left
	blt.s		.exit								;ran out of buffer

	move.l	a2,a1								;place pointer to current chip ID in a1
	lea.l		4(a1),a2							;place ptr to current rule in a2
	sub.l		#4,d2								;buffer now has 4 less unparsed bytes	

.nextrule
	cmp.l		#8,d2								;check length of buffer unparsed
	blt.s		.exit								;ran out of buffer

	move.l	(a2),d3							;place low bound in d3
	move.l	4(a2),d4							;place high bound in d4
	lea.l		8(a2),a2							;move ptr to new rule/chipid into a2
	sub.l		#8,d2								;we parsed 8 more bytes of the buffer		

	tst.l		d4									;see if high range is 0 ( terminator )
	beq.w		.nextid

	cmp.l		d1,d3								;compare serial number to low bound
	bgt.w		.nextrule						;serial number is lower than the low bound

	cmp.l		d1,d4								;compare serial number to high bound
	blt.w		.nextrule						;serial number is higher than the high bound

	;if we made it here, then the serial number is in this range
	move.l	(a1),d0							;place the chip ID in d0

.exit
	bsr		FreeFlyerFile					;free the memory used by this file
	movem.l	(sp)+,d1-d4/a0-a2/a5-a6		
	rts


*********************************************************************
* LoadFlyerBin -- open a dat file and load the bin data for
*                 the specified type of chip
*
* Entry:
*  a0:Pointer to name 
*  a6:Flyerbase ( library )( dos library must be open and pointed to in flyerbase )
*  d5:Chip ID ( if 0, then load first bin in the dat file )
*
* Exit:
*********************************************************************
LoadFlyerBin:
	movem.l	d1-d5/a0-a2/a5-a6,-(sp)
	move.l	a6,a5						;Store FlyerBase in a5
	IFNE BINDEBUG
	DUMPMSG	<   entered loadflyerbin>
	ENDC

	CLEAR		d4							;No file has been opened yet
	clr.l 	fl_BinaryBuffer(a5)	;no buffer has been allocated
	move.l	a0,a2						;preserve filename ptr in a2

	move.l	a0,d1						;prepare name for opening file
	move.l	#MODE_OLDFILE,d2		;access
	move.l	fl_DosBase(a5),a6 	;put dos.library in a6
	XSYS		Open						;open the file
	move.l	d0,d4						;did the file open?
	beq.w		.notopened				;if not
	IFNE BINDEBUG
	DUMPMSG	<   opened the file>
	ENDC

	move.l	d4,d1						;move the file handle to d1
	moveq.l	#0,d2						;move to the beginning of the file
	moveq.l	#OFFSET_BEGINNING,d3	
	XSYS		Seek						;seek to the beginning
	moveq.l	#-1,d1					;check for error( d0 == -1 )
	cmp.l		d0,d1						;compare the result with -1
	beq.w		.failed					;error
	IFNE BINDEBUG
	DUMPMSG	<   seeked to beginning of file>
	ENDC

	move.l	#fdc_data,d0			;read in a FlyerDatChunk up to the data
	IFNE BINDEBUG
	DUMPHEXI.L <   reading flyerdatchunk.  num bytes = >,d0,<\>
	ENDC
	move.l	d0,fl_BinaryLength(a5)	;copy size of buffer into fl struct
	move.l	#MEMF_PUBLIC!MEMF_CLEAR,d1
	move.l	fl_SysLib(a5),a6			;put exec.library in a6
	XSYS		AllocMem						;allocate memory for the FDC header
	move.l	d0,fl_BinaryBuffer(a5)
	tst.l		d0								;did we get the memory?
	beq.w		.failed						;no
	IFNE BINDEBUG
	DUMPMSG	<   allocated buffer>
	ENDC

.readnext
	move.l	d4,d1							;place filehandle in d1 again
	move.l	fl_BinaryBuffer(a5),d2	;read into this buffer
	move.l	fl_BinaryLength(a5),d3	;read up to the data area
	move.l	fl_DosBase(a5),a6			;put dos.library into a6
	XSYS		Read							;read chunk into buffer
	cmp.l 	fl_BinaryLength(a5),d0	;Read completely with no errors?
	bne.w		.failed						;no
	IFNE BINDEBUG
	DUMPMSG	<   read in flyerdatchunk header>
	ENDC

	moveq.l	#0,d1							;check to see if the bin length is > 0
	move.l	fl_BinaryBuffer(a5),a1	;temp let a6 point to buffer
	cmp.l		fdc_length(a1),d1			;compare the length to 0
	beq.w		.seekahead					;no data, read next header if possible
	IFNE BINDEBUG
	DUMPMSG	<   there is data in this chunk>
	ENDC
	cmp.l		#0,d5							;did we want the first bin chunk we could find?
	beq.w		.foundbin					;if so, we found it
	IFNE BINDEBUG
	DUMPMSG	<   we didnt ask for the first chunk>
	ENDC

	cmp.l		fdc_ChipID(a1),d5			;does this bin's chipID match the request?
	beq.w		.foundbin					;if so, we found it
	IFNE BINDEBUG
	DUMPMSG	<   this is not the correct chipid>
	ENDC

.seekahead									;if not, read the next one in
	move.l	d4,d1							;place filehandle in d1 again
	move.l	fdc_length(a1),d2			;place size of the chunk to skip in d2
	IFNE BINDEBUG
	DUMPHEXI.L	<   skipping chip of size >,d2,<\>
	ENDC
	move.l	#OFFSET_CURRENT,d3		;move forward from our current position
	move.l	fl_DosBase(a5),a6			;put dos.library into a6
	XSYS		Seek							;move to the next chunk
	moveq.l	#-1,d1
	cmp.l		d0,d1							;compare the result with -1
	beq.w		.failed						;error
	IFNE BINDEBUG
	DUMPMSG	<   moved forward in the file>	
	ENDC
	bra.w		.readnext

.foundbin	
	IFNE BINDEBUG
	DUMPHEXI.L	<   found chipID >,d5,<\>
	ENDC
	move.l	fdc_length(a1),d0			;place the size of the bin data in d0

	move.l	a5,a6							;place flyer.library in a6
	IFNE BINDEBUG
	DUMPMSG	<   freeing flyer file memory>
	ENDC
	bsr		FreeFlyerFile				;free the file area holding the header
	IFNE BINDEBUG
	DUMPMSG	<   allocating buffer for bin data>
	ENDC

	move.l	d0,fl_BinaryLength(a5)	;place size of the needed buffer in fl_
	move.l	#MEMF_PUBLIC!MEMF_CLEAR,d1
	move.l	fl_SysLib(a5),a6			;place exec.library in a6
	XSYS		AllocMem						;Allocate memory to hold bin file
	move.l	d0,fl_BinaryBuffer(a5)	;place ptr to buffer in fl_
	tst.l		d0								;make sure memory was allocated
	beq.w		.failed						;fail if no memory allocated
	IFNE BINDEBUG
	DUMPMSG	<   allocated memory for bin data>
	ENDC

	move.l	d4,d1							;replace file handle in d1
	move.l	fl_BinaryBuffer(a5),d2	;read into this buffer
	move.l	fl_BinaryLength(a5),d3	;read in this many bytes
	move.l	fl_DosBase(a5),a6			;place dos.library in a6
	XSYS		Read							;read in the bin data
	cmp.l		fl_BinaryLength(a5),d0	;did we get all of the data we wanted?
	
	bne.s		.failed
	IFNE BINDEBUG
	DUMPMSG	<   read bin data>
	ENDC

	moveq.l	#FERR_OKAY,d0
	bra.s		.exit

.failed
	IFNE BINDEBUG
	DUMPMSG	<   failure>
	ENDC
	moveq.l	#FERR_CMDFAILED,d0		;failed
	bsr		FreeFlyerFile				;Free the memory for the file if allocated

.exit
	IFNE BINDEBUG
	DUMPMSG	<   exiting>
	ENDC
	move.l	d4,d1							;is there a file open?
	beq.s 	.notopened

	move.l	d0,-(sp)						;preserve error code
	move.l	fl_DosBase(a5),a6			;put dos.library in a6
	XSYS		Close							;Close the file
	move.l	(sp)+,d0						;retrieve error code
	IFNE BINDEBUG
	DUMPMSG	<   closed file>
	ENDC

.notopened	
	IFNE BINDEBUG
	DUMPMSG	<   restoring registers>
	ENDC
	movem.l	(sp)+,d1-d5/a0-a2/a5-a6
	rts

*********************************************************************
* LoadFlyerFile -- open and load binary into memory
*
* Entry:
*	a0:Pointer to name
*	a6:Flyerbase (library)
*
* Exit:
*********************************************************************
LoadFlyerFile:
	movem.l	d1-d4/a0-a2/a5-a6,-(sp)
	move.l	a6,a5			;FlyerBase in a5

	CLEAR	d4			;No file open yet
	clr.l	fl_BinaryBuffer(a5)	;No buffer allocated yet
	move.l	a0,a2

	IFD	DEBUGINIT
	DUMPSTR	0(a2)
	DUMPMSG	< <-- looking for file>
	ENDC

	move.l	a2,d1			;name
	move.l	#MODE_OLDFILE,d2	;access
	move.l	fl_DosBase(a5),a6
	XSYS	Open
	move.l	d0,d4			;File handle
	bne.s	.didopen		;Okay?

	IFD	DEBUGINIT
	DUMPMSG	<Could not open file>
	ENDC
	bra.s	.failed

.didopen
	move.l	d4,d1	;handle
	moveq.l	#0,d2	;pos = end
	moveq.l	#OFFSET_END,d3
	XSYS	Seek
	moveq.l	#-1,d1
	cmp.l	d0,d1	;Error?
	beq.s	.failed

	move.l	d4,d1	;handle
	moveq.l	#0,d2	;pos = start
	moveq.l	#OFFSET_BEGINNING,d3
	XSYS	Seek
	moveq.l	#-1,d1
	cmp.l	d0,d1	;Error?
	beq.s	.failed
	move.l	d0,fl_BinaryLength(a5)		;Length

	;Length already in d0
	move.l	#MEMF_PUBLIC!MEMF_CLEAR,d1
	move.l	fl_SysLib(a5),a6
	XSYS	AllocMem	;Allocate memory to hold binary file
	move.l	d0,fl_BinaryBuffer(a5)		;Ptr
	tst.l	d0
	beq.s	.failed

	move.l	d4,d1			;handle
	move.l	fl_BinaryBuffer(a5),d2	;Buffer
	move.l	fl_BinaryLength(a5),d3
	move.l	fl_DosBase(a5),a6
	XSYS	Read			;Read file into buffer
	cmp.l	fl_BinaryLength(a5),d0	;Read completely with no errors?
	bne.s	.failed

	moveq.l	#FERR_OKAY,d0
	bra.s	.exit

.failed	moveq.l	#FERR_CMDFAILED,d0	;Failed
	bsr	FreeFlyerFile	;Free file

.exit	move.l	d4,d1		;File open?
	beq.s	.notopen
	move.l	d0,-(sp)	;save error code
	move.l	fl_DosBase(a5),a6
	XSYS	Close
	move.l	(sp)+,d0
.notopen
	movem.l	(sp)+,d1-d4/a0-a2/a5-a6
	rts


*********************************************************************
* FreeFlyerFile -- free binary loaded into memory
*
* Entry:
*	a6:Flyerbase (library)
*
* Exit:
*********************************************************************
FreeFlyerFile:
	movem.l	d0-d1/a0-a1,-(sp)

	tst.l	fl_BinaryBuffer(a6)		;Anything to free?
	beq.s	.none2free
	move.l	fl_BinaryBuffer(a6),a1
	move.l	fl_BinaryLength(a6),d0
	move.l	a6,-(sp)
	move.l	fl_SysLib(a6),a6
	XSYS	FreeMem
	move.l	(sp)+,a6
.none2free
	movem.l	(sp)+,d0-d1/a0-a1
	rts


******* flyer.library/SetFlyerTime ******************************************
*
*   NAME
*	SetFlyerTime - sets the Flyer's internal clock to a preset date/time
*
*   SYNOPSIS
*	error = SetFlyerTime(datestamp)
*	D0                   A0
*
*	ULONG SetFlyerTime(struct DateStamp *);
*
*   FUNCTION
*	Sets the internal real-time clock of all attached Flyers to the date
*	and time specified in the structure whose pointer is given.  They
*	maintain this date/time for the purpose of date-stamping files.
*
*   INPUTS
*	datestamp - pointer to an AmigaDOS DateStamp structure
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*
*   BUGS
*
*   SEE ALSO
*
*****************************************************************************
SetFlyerTime
	IFD	DEBUGGEN
	DUMPMSG <SetFlyerTime>
	ENDC

	movem.l	a0-a1/a3-a5,-(sp)

	moveq.l	#0,d0		;Hard-wire to board 0 for now!!!
	bsr	Get_Brd_Cmd	;Get a free spot to place command
	bne.s	.exit		;Failed? Exit

	move.b	#1,2(a3)	;Cont = 1
	move.l	ds_Days(a0),4(a3)	;Days
	move.l	ds_Minute(a0),8(a3)	;Minutes
	move.l	ds_Tick(a0),12(a3)	;Ticks

	moveq.l	#op_SETCLOCK,d0
	lea.l	StdFollowUp(pc),a1
	bsr	FireCmd		;Go!
.exit
	movem.l	(sp)+,a0-a1/a3-a5
	rts


******* flyer.library/Firmware ******************************************
*
*   NAME
*	Firmware - Download and run software on Flyer CPU
*
*   SYNOPSIS
*	error = Firmware(board,length,data,offset)
*	D0               D0    D1     A0   D2
*
*	ULONG Firmware(UBYTE,ULONG,APTR,ULONG);
*
*   FUNCTION
*	Downloads the provided binary file to the Flyer and executes it
*	as the controlling software.
*
*   INPUTS
*	board - specifies the Flyer board (0-3)
*
*	length - length of data provided
*
*	offset - offset address in shared SRAM
*
*	data - pointer to binary data
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*
*   BUGS
*
*   SEE ALSO
*
*****************************************************************************
* Offset address in SRAM was $20000 to 4.04, then $18000 from 4.05
*****************************************************************************
Firmware
	IFD	DEBUGGEN
	DUMPMSG <Firmware>
	ENDC
	movem.l	a0-a1/a3-a5,-(sp)

	bsr	Get_Brd_Cmd	;Get a free spot to place command
	bne	.exit		;Failed? Exit

	move.l	d1,8(a3)	;Length

;**** Check if Flyer code already running.  If so, better do a "quit" first
;	btst	#FUB_RUNNING,unit_PrivFlags(a5)
;	beq.s	.notrunning
;
;	CLEAR	d0			;Unit 0
;	bsr	QuitFlyer		;Shut down old code
;
;	IFD	DEBUGINIT
;	DUMPMSG	<Back>
;	ENDC
;
;***** Wait for Flyer to reboot back into ROM
;	move.l	#1000000,d0
;.bigdelay
;	nop
;	nop
;	nop
;	nop
;	subq.l	#1,d0
;	bne.s	.bigdelay
;
;	IFD	DEBUGINIT
;	DUMPMSG	<Done>
;	ENDC
;
;.notrunning
	bset	#FUB_RUNNING,unit_PrivFlags(a5)	;Now we are

					;a0=src
	move.l	unit_SRAMbase(a5),a1	;dest (ptr to special SRAM area)
	add.l	d2,a1			;Offset into SRAM for code
	move.l	d1,d0			;d0=len
	bsr	FastCopy	;Copy program into SRAM

;	move.l	#PROGAREA,d0
	move.l	d2,4(a3)		;Give Flyer go offset

	moveq.l	#op_FIRMWARE,d0
	lea.l	StdFollowUp(pc),a1
	bsr	FireCmd		;Go!
.exit
	movem.l	(sp)+,a0-a1/a3-a5
	rts

******* flyer.library/FlyerRunning ******************************************
*
*   NAME
*	FlyerRunning -- test if Flyer firmware is downloaded and running
*
*   SYNOPSIS
*	error = FlyerRunning(board)
*	D0                   D0
*
*	ULONG FlyerRunning(UBYTE);
*
*   FUNCTION
*
*   INPUTS
*	board - specifies the Flyer board (0-3)
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*
*   BUGS
*
*   SEE ALSO
*
*****************************************************************************
FlyerRunning
	move.l	a5,-(sp)

	IFD	DEBUGGEN
	DUMPMSG <FlyerRunning>
	ENDC

	bsr	GetCardUnit		;Get unit structure for card 'd0'
	bne	.exit			;Failed? Exit

	btst	#FUB_RUNNING,unit_PrivFlags(a5)	;Have we downloaded yet?
	beq.s	.notrunning
	btst	#FUB_SETUP,unit_PrivFlags(a5)	;Are we completely setup?
	beq.s	.notrunning
	moveq.l	#FERR_OKAY,d0
	bra.s	.exit
.notrunning
	moveq.l	#FERR_CMDFAILED,d0		;By default
.exit
	move.l	(sp)+,a5
	rts

*****i* flyer.library/RunModule ******************************************
*
*   NAME
*	RunModule -- load/call supplied software module on Flyer processor
*
*   SYNOPSIS
*	error = RunModule(board,length,data,ID,argc,argv)
*	D0                D0    D1     A0   A1 D2   A2
*
*	ULONG RunModule(UBYTE,ULONG,APTR,ULONG *,UWORD,ULONG *);
*
*   FUNCTION
*
*   INPUTS
*	board - specifies the Flyer board (0-3)
*
*	length - length of code module in bytes
*
*	data - pointer to code module data
*
*	ID - returned from asyncronous command invocation (or 0 for sync)
*
*	argc - number of arguments supplied
*
*	argv - pointer to first argument supplied
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*
*   BUGS
*
*   SEE ALSO
*
*****************************************************************************
RunModule
	IFD	DEBUGGEN
	DUMPMSG <RunModule>
	ENDC
	movem.l	a0-a1/a3-a5,-(sp)
	move.l	a2,-(sp)
	move.l	a1,a2

	bsr	Get_Brd_Cmd	;Get a free spot to place command
	bne.s	.exit		;Failed? Exit

	move.b	#1,2(a3)	;Continue flag

;***** Is a sub-module to execute, allocate temporary SRAM for code *****
	cmp.w	#0,a0		;Supplied code to run?
	beq.s	.nocode
	move.l	d1,d0		;d0 = size
	move.l	a0,a1		;a1 = ptr
	bsr	CopytoSRAM	;Copy stuff to SRAM
	bne.s	.exit		;Failed? Exit
	cmp.l	#CMDBASE+(MAX_FLYER_CMDS*FLYER_CMD_LEN),d0	;At correct address?
	bne.s	.exit
.nocode

	move.w	d2,4(a3)		;argc
	move.w	d1,6(a3)		;(new) test
	move.l	(sp),a0
	move.l	0(a0),$08(a3)		;arg 1
	move.l	4(a0),$0C(a3)		;arg 2
	move.l	8(a0),$10(a3)		;arg 3
	move.l	12(a0),$14(a3)		;arg 4
	move.l	16(a0),$18(a3)		;arg 5
	move.l	20(a0),$1C(a3)		;arg 6

	moveq	#RT_STOPPED,d0		;synchronous
	cmp.w	#0,a2
	beq.s	.doitsync
	move.l	a4,(a2)			;Send ID back to caller
	moveq	#RT_IMMED,d0		;asynchronous
.doitsync
	move.b	d0,cmd_RetTime(a4)	;Set return time

	moveq.l	#op_CALLMOD,d0
	lea.l	StdFollowUp(pc),a1
	bsr	FireCmd		;Go!
.exit
	move.l	(sp)+,a2
	movem.l	(sp)+,a0-a1/a3-a5
	rts

*****i* flyer.library/PgmFPGA ******************************************
*
*   NAME
*	PgmFPGA - Download and program one of the Flyer's FPGA chips.
*
*   SYNOPSIS
*	error = PgmFPGA(board,chip,length,data,rev)
*	D0              D0    D1   D2     A0   D3
*
*	ULONG PgmFPGA(UBYTE,UBYTE,ULONG,APTR,UBYTE);
*
*   FUNCTION
*	Downloads binary chip data and programs the selected FPGA.  If the
*	chip fails to program properly, it is reset and this command returns
*	FERR_CMDFAILED.
*
*   INPUTS
*	board - specifies the Flyer board (0-3)
*
*	chip - Flyer chip number:
*	   1 - Skew
*	   2 - Timer/Router
*	   3 - Pcoder 1
*	   4 - Pcoder 2
*	   5 - Mcoder 1
*	   6 - Mcoder 2
*	   7 - DMA controller
*	   8 - Audio DMA interface
*	   9 - Aligner
*
*	length - length of data provided
*
*	data - pointer to binary data
*
*	revision - rev code for chip file
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*
*   BUGS
*
*   SEE ALSO
*
*****************************************************************************
*	d0:Flyer board
*	d1:chip # (.b)
*	d2:byte length (.l)
*	a0:pointer to data
*	d3:revision (.b)
*	d4:Dual-programming operation flag (IntFPGA version only)
*****************************************************************************
PgmFPGA
	move.l	d4,-(sp)
	moveq.l	#0,d4		;Not a dual-programming operation
	bra.s	FPGAmerge

IntFPGA	move.l	d4,-(sp)	;But I can!

FPGAmerge
	movem.l	a0-a1/a3-a5,-(sp)

	IFD	DEBUGGEN
	DUMPMSG <PgmFPGA>
	DUMPHEXI.L <Chip # >,d1,<\>
	DUMPHEXI.L <Length >,d2,<\>
	DUMPHEXI.L <Rev >,d3,<\>
	DUMPHEXI.L <Data @ >,a0,<\>
	ENDC

	bsr	Get_Brd_Cmd		;Get a free spot to place command
	bne.s	.exit			;Failed? Exit

	move.b	d1,12(a3)	;Chip #
	move.b	d4,13(a3)	;Dual flag
	move.b	d3,14(a3)	;Chip revision

	move.l	d2,8(a3)	;bytecount
	move.l	a0,a1		;a1 = src ptr
	move.l	d2,d0		;d0 = size
	bsr	CopytoSRAM	;Copy stuff to SRAM
	bne.s	.exit		;Failed? Exit

	move.l	d0,4(a3)	;SRAM addr

	moveq.l	#op_PGMFPGA,d0
	lea.l	StdFollowUp(pc),a1
	bsr	FireCmd		;Go!
.exit
	movem.l	(sp)+,a0-a1/a3-a5
	move.l	(sp)+,d4
	rts


*****i* flyer.library/TeachFPGA ******************************************
*
*   NAME
*	TeachFPGA -- Teach flyer.library an FPGA chip definition
*
*   SYNOPSIS
*	error = TeachFPGA(chip,length,data)
*	D0                D0   D1     D2
*
*	ULONG TeachFPGA(UBYTE,ULONG,APTR);
*
*   FUNCTION
*
*   INPUTS
*	chip - chip number to define
*
*	length - length of definition in bytes
*
*	data - pointer to chip definition data
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*
*   BUGS
*
*   SEE ALSO
*
*****************************************************************************
TeachFPGA
	IFD	DEBUGGEN
	DUMPMSG	<TeachFPGA>
	ENDC
	movem.l	a0-a2/a6,-(sp)
	lea.l	fl_Mencode(a6),a2
	cmp.b	#0,d0
	beq.s	.got_chip
	lea.l	fl_Pencode(a6),a2
	cmp.b	#1,d0
	beq.s	.got_chip
	lea.l	fl_Mdecode(a6),a2
	cmp.b	#2,d0
	beq.s	.got_chip
	lea.l	fl_Pdecode(a6),a2
	cmp.b	#3,d0
	bne	.error
.got_chip
	move.l	a0,a1		;Keep ptr to new definition data

	move.l	a2,a0
	move.l	fl_SysLib(a6),a6	;Get execbase
	bsr	FreeChipDef	;Free old definition if one exists

	move.l	fch_length(a1),d0	;Get length of chip data
	add.l	#FlyerChipHdr_Sizeof,d0	;Leave room for header too
	move.l	d0,4(a2)	;Save length of our new definition
	move.l	#MEMF_PUBLIC!MEMF_CLEAR,d1
	move.l	a1,-(sp)
	XSYS	AllocMem		;Allocate a new VolNode
	move.l	(sp)+,a1
	tst.l	d0			;Failed?
	bne.s	.gotdefmem
	moveq.l	#FERR_NOMEM,d0
	bra.s	.exit
.gotdefmem
	move.l	d0,(a2)			;Save ptr to new definition
	move.l	a1,a0			;Src=ptr to header,data...
	move.l	d0,a1			;Dest = def buffer
	move.l	4(a2),d0		;Length of definition buffer
	bsr	FastCopy		;Copy to buffer
	moveq.l	#FERR_OKAY,d0
	bra.s	.exit
.error
	moveq.l	#FERR_BADPARAM,d0		;Uh Oh
.exit
	movem.l	(sp)+,a0-a2/a6
	rts

*****i* flyer.library/SBusWrite ******************************************
*
*   NAME
*	SBusWrite -- Write data to Flyer's internal fast sbus
*
*   SYNOPSIS
*	error = SBusWrite(board,addr,data)
*	D0                D0    D1   D2
*
*	ULONG SBusWrite(UBYTE,UBYTE,UBYTE);
*
*   FUNCTION
*
*   INPUTS
*	board - specifies the Flyer board (0-3)
*
*	addr - sbus address
*
*	data - data to write
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*
*   BUGS
*
*   SEE ALSO
*
*****************************************************************************
SBusWrite
	IFD	DEBUGGEN
	DUMPMSG <Sbuswrite>
	ENDC
	movem.l	a0-a1/a3-a5,-(sp)

	bsr	Get_Brd_Cmd	;Get a free spot to place command
	bne.s	.exit		;Failed? Exit

;	move.b	d3,2(a3)	;cont
	clr.b	2(a3)		;No cont!

	move.b	d1,4(a3)	;addr.b
	move.b	d2,5(a3)	;data
	moveq.l	#op_SBUSW,d0
	lea.l	StdFollowUp(pc),a1
	bsr	FireCmd		;Go!
.exit
	movem.l	(sp)+,a0-a1/a3-a5
	rts

*****i* flyer.library/SBusRead ******************************************
*
*   NAME
*	SBusRead -- Read data from Flyer's internal fast sbus
*
*   SYNOPSIS
*	error = SBusRead(board,addr,dataptr)
*	D0               D0    D1   A0
*
*	ULONG SBusRead(UBYTE,UBYTE,UBYTE *);
*
*   FUNCTION
*
*   INPUTS
*	board - specifies the Flyer board (0-3)
*
*	addr - sbus address
*
*	dataptr - pointer to variable to receive data
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*
*   BUGS
*
*   SEE ALSO
*
*****************************************************************************
SBusRead
	IFD	DEBUGGEN
	DUMPMSG <Sbusread>
	ENDC
	movem.l	a0-a1/a3-a5,-(sp)

	bsr	Get_Brd_Cmd	;Get a free spot to place command
	bne.s	.exit		;Failed? Exit

;	move.b	d2,2(a3)	;cont
	clr.b	2(a3)		;No cont!

	move.b	d1,4(a3)	;addr.b
	move.l	a0,cmd_CopyDest(a4)	;Save for follow-up
	moveq.l	#op_SBUSR,d0
	lea.l	.FollowUp(pc),a1
	bsr	FireCmd		;Go!
.exit
	movem.l	(sp)+,a0-a1/a3-a5
	rts

.FollowUp				;Can trash a0,a1,d0
	move.l	cmd_CopyDest(a4),d0	;Get storage address
	beq.s	.avoid
	move.l	d0,a0
	move.b	5(a3),d0
	move.b	d0,(a0)		;Send back to caller
.avoid
	move.b	3(a3),d0	;Get error code
	rts

*****i* flyer.library/CPUwrite ******************************************
*
*   NAME
*	CpuWrite -- Write data to Flyer's memory space
*
*   SYNOPSIS
*	error = CPUwrite(board,addr,data)
*	D0               D0    A0   D1
*
*	ULONG CPUwrite(UBYTE,ULONG,UWORD);
*
*   FUNCTION
*
*   INPUTS
*	board - specifies the Flyer board (0-3)
*
*	addr - memory address (in Flyer memory space)
*
*	data - data to write
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*
*   BUGS
*
*   SEE ALSO
*
*****************************************************************************
CPUwrite
	IFD	DEBUGGEN
	DUMPMSG <CpuWrite>
	ENDC
	movem.l	a0-a1/a3-a5,-(sp)

	bsr	Get_Brd_Cmd	;Get a free spot to place command
	bne.s	.exit		;Failed? Exit

	move.l	a0,4(a3)	;address
	move.w	d1,8(a3)	;data
	moveq.l	#op_CPUW,d0
	lea.l	StdFollowUp(pc),a1
	bsr	FireCmd		;Go!
.exit
	movem.l	(sp)+,a0-a1/a3-a5
	rts

*****i* flyer.library/CPUread ******************************************
*
*   NAME
*	CpuRead -- Read data word from Flyer's memory space
*
*   SYNOPSIS
*	error = CPUread(board,addr,dataptr)
*	D0              D0    A0   A1
*
*	ULONG CPUread(UBYTE,ULONG,UWORD *);
*
*   FUNCTION
*
*   INPUTS
*	board - specifies the Flyer board (0-3)
*
*	addr - memory address (in Flyer memory space)
*
*	dataptr - pointer to variable to receive data read
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*
*   BUGS
*
*   SEE ALSO
*
*****************************************************************************
CPUread
	IFD	DEBUGGEN
	DUMPMSG <CpuRead>
	ENDC
	movem.l	a0-a1/a3-a5,-(sp)

	bsr	Get_Brd_Cmd	;Get a free spot to place command
	bne.s	.exit		;Failed? Exit

	move.l	a0,4(a3)	;address
	move.l	a1,cmd_CopyDest(a4)	;Save for follow-up
	moveq.l	#op_CPUR,d0
	lea.l	.FollowUp(pc),a1
	bsr	FireCmd		;Go!
.exit
	movem.l	(sp)+,a0-a1/a3-a5
	rts

.FollowUp			;Can trash a0,a1,d0
	move.l	cmd_CopyDest(a4),d0
	beq.s	.avoid
	move.l	d0,a0
	move.w	8(a3),d0	;data read
	move.w	d0,(a0)		;Give to caller
.avoid
	move.b	3(a3),d0	;Get error code
	rts

*****i* flyer.library/FIRinit ******************************************
*
*   NAME
*	FIRinit - Initialize FIR filter
*
*   SYNOPSIS
*	error = FIRinit(board,ctrl0,ctrl1)
*	D0              D0    D1    D2
*
*	ULONG FIRinit(UBYTE,UWORD,UWORD);
*
*   FUNCTION
*	Initializes the FIR filter chip using the parameters provided.
*
*   INPUTS
*	board - specifies the Flyer board (0-3)
*
*	ctrl0,ctrl1 - chip specific register values
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*
*   BUGS
*
*   SEE ALSO
*
*****************************************************************************
FIRinit
	IFD	DEBUGGEN
	DUMPMSG <FirInit>
	ENDC
	movem.l	a0-a1/a3-a5,-(sp)

	bsr	Get_Brd_Cmd	;Get a free spot to place command
	bne.s	.exit		;Failed? Exit

	move.w	d1,4(a3)	;reg 0 data
	move.w	d2,6(a3)	;reg 1 data
	moveq.l	#op_FIRINIT,d0
	lea.l	StdFollowUp(pc),a1
	bsr	FireCmd		;Go!
.exit
	movem.l	(sp)+,a0-a1/a3-a5
	rts

*****i* flyer.library/FIRcustom ******************************************
*
*   NAME
*	FIRcustom - Define custom FIR coefficients
*
*   SYNOPSIS
*	error = FIRcustom(board,prepost,scale,data)
*	D0                D0    D1      D2    A0
*
*	ULONG FIRcustom(UBYTE,UBYTE,UWORD,UWORD *);
*
*   FUNCTION
*	Defines custom FIR filter coefficients (either for pre-compensation
*	or post-compensation).  Each set contains 8 coefficients each.  A FIR
*	coefficient is a signed 10 bit number extended to a WORD.
*
*   INPUTS
*	board - specifies the Flyer board (0-3)
*
*	prepost - determines which type of set is specified:
*	   0 - pre-compensation (recording)
*	   1 - post-compensation (playback)
*
*	scale - power-of-2 scaler value
*
*	data - pointer to 8 consecutive WORDs
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*
*   BUGS
*
*   SEE ALSO
*
*****************************************************************************
*	d0:Flyer board
*	d1:prepost (0-1)
*	d2:Scale value.w
*	a0:Ptr to 8 coefficient words
*****************************************************************************
FIRcustom
	IFD	DEBUGGEN
	DUMPMSG <FirCustom>
	ENDC
	movem.l	d1/a0-a1/a3-a5,-(sp)

	bsr	Get_Brd_Cmd		;Get a free spot to place command
	bne.s	.exit			;Failed? Exit

	clr.b	4(a3)		;Set 0 (custom)
	clr.b	5(a3)		;"Write"
	move.b	d1,6(a3)	;Pre/Post
	move.w	d2,24(a3)	;Scale

	moveq.l	#16-1,d0
.copycoefs
	move.b	(a0,d0.w),d1
	move.b	d1,8(a3,d0.w)
	dbf	d0,.copycoefs

	moveq.l	#op_FIRXCHG,d0
	lea.l	StdFollowUp(pc),a1
	bsr	FireCmd		;Go!
.exit
	movem.l	(sp)+,d1/a0-a1/a3-a5
	rts

*****i* flyer.library/FIRquery ******************************************
*
*   NAME
*	FIRquery -- Read out FIR coefficient/scale presets
*
*   SYNOPSIS
*	error = FIRquery(board,coefset,prepost,scaleptr,coefbuff)
*	D0               D0    D1      D2      A0       A1
*
*	ULONG FIRquery(UBYTE,UBYTE,UBYTE,UWORD *,UWORD *);
*
*   FUNCTION
*
*   INPUTS
*	board - specifies the Flyer board (0-3)
*
*	coefset - which set to read (0 - 31)
*
*	prepost - (0=pre, 1=post)
*
*	scaleptr - pointer to variable to receive scale value
*
*	coefbuff - pointer to buffer to receive 8 coefficient words
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*
*   BUGS
*
*   SEE ALSO
*
*****************************************************************************
FIRquery
	IFD	DEBUGGEN
	DUMPMSG <FirQuery>
	ENDC

	movem.l	d1/a0-a1/a3-a5,-(sp)

	bsr	Get_Brd_Cmd		;Get a free spot to place command
	bne.s	.exit			;Failed? Exit

	move.l	a0,cmd_CopyExtra(a4)
	move.l	a1,cmd_CopyDest(a4)	;Save these for wrap-up time

	move.b	d1,4(a3)		;Set #
	move.b	#1,5(a3)		;"Read"
	move.b	d2,6(a3)		;Pre/Post

	moveq.l	#op_FIRXCHG,d0
	lea.l	.FollowUp(pc),a1
	bsr	FireCmd		;Go!
.exit
	movem.l	(sp)+,d1/a0-a1/a3-a5
	rts

.FollowUp
	move.l	d1,-(sp)
	move.l	cmd_CopyDest(a4),d0
	beq.s	.avoid1
	move.l	d0,a0
	moveq.l	#16-1,d0
.copycoefs
	move.b	8(a3,d0.w),d1
	move.b	d1,(a0,d0.w)
	dbf	d0,.copycoefs
.avoid1
	move.l	cmd_CopyExtra(a4),d0
	beq.s	.avoid2
	move.l	d0,a0
	move.w	24(a3),(a0)		;Scale
.avoid2
	move.b	3(a3),d0	;Get error code
	move.l	(sp)+,d1
	rts

*****i* flyer.library/FIRmapRAM ******************************************
*
*   NAME
*	FIRmapRAM - Setup FIR map RAM
*
*   SYNOPSIS
*	error = FIRmapRAM(board,bank,scale,shape)
*	D0                D0    D1   D2    D3
*
*	ULONG FIRmapRAM(UBYTE,UBYTE,UBYTE,UBYTE);
*
*   FUNCTION
*	Loads the FIR filter's map RAM with the correct table
*
*   INPUTS
*	board - specifies the Flyer board (0-3)
*
*	bank - FIR coefficient bank to load (0-7)
*
*	scale - power-of-2 scaler (1,2,4)
*
*	shape - 0 for linear, 2 for inverse sin
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*
*   BUGS
*
*   SEE ALSO
*
*****************************************************************************
* Loads FIR Map RAM with Linear table
*
*	d0:Flyer board
*	d1:Bank.b
*	d2:Scale.b
*	d3:Shape.b
*****************************************************************************
FIRmapRAM
	IFD	DEBUGGEN
	DUMPMSG <FirMapRam>
	ENDC
	movem.l	a0-a1/a3-a5,-(sp)

	bsr	Get_Brd_Cmd	;Get a free spot to place command
	bne.s	.exit		;Failed? Exit

	move.b	d1,4(a3)	;Bank
	move.b	d2,5(a3)	;Scale
	move.b	d3,6(a3)	;Shape

	moveq.l	#op_FIRMAPRAM,d0
	lea.l	StdFollowUp(pc),a1
	bsr	FireCmd		;Go!
.exit
	movem.l	(sp)+,a0-a1/a3-a5
	rts

*****i* flyer.library/DSPboot ******************************************
*
*   NAME
*	DSPboot - Download and run DSP program
*
*   SYNOPSIS
*	error = DSPboot(board,length,data)
*	D0              D0    D1     A0
*
*	ULONG DSPboot(UBYTE,ULONG,APTR);
*
*   FUNCTION
*	Downloads supplied program into the DSP and executes it.
*
*   INPUTS
*	board - specifies the Flyer board (0-3)
*
*	length - length of data provided
*
*	data - pointer to DSP program
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*
*   BUGS
*
*   SEE ALSO
*
*****************************************************************************
DSPboot
	IFD	DEBUGGEN
	DUMPMSG <DSPboot>
	ENDC
	movem.l	a0-a1/a3-a5,-(sp)

	bsr	Get_Brd_Cmd	;Get a free spot to place command
	bne.s	.exit		;Failed? Exit

	move.l	d1,8(a3)	;bytecount
	move.l	a0,a1		;a1=src ptr
	move.l	d1,d0		;d0=size
	bsr	CopytoSRAM	;Copy stuff to SRAM
	bne.s	.exit		;Failed? Exit

	move.l	d0,4(a3)	;SRAM addr
	moveq.l	#op_DSPBOOT,d0
	lea.l	StdFollowUp(pc),a1
	bsr	FireCmd		;Go!
.exit
	movem.l	(sp)+,a0-a1/a3-a5
	rts


******* flyer.library/CPUDMA ******************************************
*
*   NAME
*	CPUDMA -- Transfer data between DMA memory and CPU memory
*
*   SYNOPSIS
*	error = CPUDMA(board,cpuptr,dmaptr,length,readflag)
*	D0             D0    A0     A1     D1     D2
*
*	ULONG CPUDMA(UBYTE,ULONG,ULONG,UWORD,UBYTE);
*
*   FUNCTION
*	This function transfers blocks of data between the Flyer's DRAM and SRAM
*	areas.  All pointers and sizes are in blocks (512 bytes).  "Writes" are
*	TO SRAM, "reads" are FROM SRAM.
*
*	CAUTION! These memory areas are highly private and dangerous to access.
*	Use only under advisement or based on sample code.
*
*   INPUTS
*	board - specifies the Flyer board (0-3)
*
*	cpuptr - CPU address (block)
*
*	dmaptr - DMA address (block)
*
*	length - length of transfer (in blocks)
*
*	readflag - 0=write, 1=read
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*
*   BUGS
*
*   SEE ALSO
*
*****************************************************************************
CPUDMA
	IFD	DEBUGGEN
	DUMPMSG <CPUDMA>
	ENDC
	movem.l	a0-a1/a3-a5,-(sp)

	bsr	Get_Brd_Cmd	;Get a free spot to place command
	bne.s	.exit		;Failed? Exit

	move.l	a0,4(a3)	;cpu ptr
	move.l	a1,8(a3)	;dma ptr
	move.w	d1,12(a3)	;blk count
	move.b	d2,14(a3)	;read flag
	moveq.l	#op_CPUDMA,d0
	lea.l	StdFollowUp(pc),a1
	bsr	FireCmd		;Go!
.exit
	movem.l	(sp)+,a0-a1/a3-a5
	rts

******* flyer.library/VideoCompressModes ******************************************
*
*   NAME
*	VideoCompressModes - set video compression modes and strategy
*
*   SYNOPSIS
*	error = VideoCompressModes(board,bestmode,worstmode,strategy)
*	D0                         D0    D1       D2        D3
*
*	ULONG VideoCompressModes(UBYTE,UBYTE,UBYTE,UBYTE);
*
*   FUNCTION
*	Sets the range of video compression qualities that the Flyer may use
*	when recording video.  The default is all modes.  But this may be
*	pared down by narrowing this range or one specific mode may be
*	forced.
*
*	Strategy picks the strategy the Flyer should use for auto-switching
*	between modes.  The only supported value currently is 0, which uses
*	compressed data size to switch modes.
*
*   INPUTS
*	board - specifies the Flyer board (0-3)
*
*	bestmode - specifies the best video compression quality mode to use
*	worstmode - specifies the worst video compression quality mode to use
*
*	     Currently supported modes, in order of decreasing video quality:
*
*	     0 (D2)  Best quality, worst compression
*	     1 (D2)
*	     2 (SN)
*	     3 (SN)
*	     4 (SN)  Worst quality, best compression
*
*	strategy - always 0 for now (size based strategy)
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*
*   BUGS
*
*   SEE ALSO
*
*****************************************************************************
CompressModes
	IFD	DEBUGGEN
	DUMPMSG <CompressModes>
	ENDC
	movem.l	d1-d6,-(sp)

	move.b	d1,d5			;Get data size from "best" mode
	lsr.b	#4,d5			;Upper nybble = data size code
	tst.b	d5			;= 0 (IBM)?
	beq	.size0			;= 1 (HQ5)!
	cmp.b	#1,d5		
	beq	.size1
					;= 2 (HQ6)!!!
	move.w	#VIDSIZE_2,d5		;NEW!!! and Improved data size
	bra.s	.sizemerge

.size1	move.w	#VIDSIZE_1,d5		;Improved data size
	bra.s	.sizemerge

.size0	move.w	#VIDSIZE_0,d5		;Standard data size
.sizemerge

	and.b	#$F,d1			;Strip data size nybbles off
	and.b	#$F,d2

	cmp.b	#5,d1			;Check valid range for compression modes
	bhs.s	.badarg
	cmp.b	#5,d2
	bhs.s	.badarg

	cmp.b	#2,d1			;Convert 0,1,2,3,4 to
	blo.s	.noSNcorr1		;        0,1,4,5,6
	addq.l	#2,d1
.noSNcorr1
	cmp.b	#2,d2
	blo.s	.noSNcorr2
	addq.l	#2,d2
.noSNcorr2

	cmp.b	#5,d1			;Is extened mode getting setup wrong?
	bne	.beep	
	move.b #4,d1		;It's 5 thats not right so set it to 4
.beep

	CLEAR	d7			;No special modes
	moveq.l	#FIRSET_33,d6		;Use 33% Precomp
;		d5			;Already computed video size
	CLEAR	d4			;Keep same PRN frequency
	move.b	d2,d3
	move.b	d1,d2
	CLEAR	d1			;Chan = 0
	bsr	VideoParams
	bra.s	.exit
.badarg
	moveq.l	#FERR_BADPARAM,d0
.exit
	movem.l	(sp)+,d1-d6
	rts

******* flyer.library/VideoParams ******************************************
*
*   NAME
*	VideoParams - set video compression parameters
*
*   SYNOPSIS
*	err=VideoParams(board,vchan,mintol,maxtol,freq,vidlen,FIRset,special)
*	D0              D0    D1    D2     D3     D4   D5     D6     D7
*
*	ULONG VideoParams(UBYTE,UBYTE,UBYTE,UBYTE,UBYTE,UWORD,UBYTE,UBYTE);
*
*   FUNCTION
*	Sets the default video compression parameters for each video channel.
*	For auto-adjusting compression modes, this is only used for the first
*	field of video.
*
*   INPUTS
*	board - specifies the Flyer board (0-3)
*
*	vchan - video channel (0 or 1)
*
*	mintol - minimum tolerance mode (0 best, 6 worst)
*
*	maxtol - maximum tolerance mode
*
*	freq - random noise frequency
*
*	vidlen - desired length of compressed field data (in SCSI blocks)
*
*	FIRset - FIR presets to use
*	   0 = custom
*	   1 = 25%
*	   2 = 33%
*	   3 = 50%
*	   4 = 100%
*
*	special - for testing only
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*	Use only tolerance modes 0, 1, 4, 5, and 6
*
*	****** This may change as we finalize how the user's controls the
*	amount of compression ******
*
*   BUGS
*
*   SEE ALSO
*
*****************************************************************************
*	d0:Flyer board
*	d1:video channel
*	d2:min tolerance
*	d3:max tolerance
*	d4:rnd frequency
*	d5:vid length.w
*	d6:FIRset
*	d7:special.b
*********************************************************************
VideoParams
	IFD	DEBUGGEN
	DUMPMSG <VidParams>
	ENDC
	movem.l	a0-a1/a3-a5,-(sp)

	bsr	Get_Brd_Cmd	;Get a free spot to place command
	bne.s	.exit		;Failed? Exit

	move.b	d1,4(a3)	;Video channel (unused)
	move.b	d2,5(a3)	;min tolerance
	move.b	d3,6(a3)	;max toleran`ce
	move.b	d4,7(a3)	;rnd freq
	move.w	d5,8(a3)	;video max length
	move.w	d5,d0
	sub.w	#10,d0		;Avg = max-10 for headroom
	DUMPREG	<d0 video max length>
	move.w	d0,10(a3)	;video avg length
	move.b	d6,12(a3)	;FIRset
	move.b	d7,13(a3)	;special

	moveq.l	#op_VIDPARAM,d0
	lea.l	StdFollowUp(pc),a1
	bsr	FireCmd		;Go!
.exit
	movem.l	(sp)+,a0-a1/a3-a5
	rts

******* flyer.library/StillMode ******************************************
*
*   NAME
*	StillMode - Set video looping method for video channel
*
*   SYNOPSIS
*	error = StillMode(board,chan,mode)
*	D0                D0    D1   D2
*
*	ULONG StillMode(UBYTE,UBYTE,UBYTE);
*
*   FUNCTION
*	Used to specify the type of video looping to use on stilled video.
*	The default at power-up is MODE_FRAME.
*
*   INPUTS
*	volume - pointer to structure which describes a volume (used to
*	   pick specific Flyer card).
*
*	chan - video channel (0 or 1)
*
*	mode - video looping mode:
*
*	   MODE_FIELD - loops a single field of video
*	   MODE_PAIR - loops an interlaced pair of video fields
*	   MODE_FRAME - loops an entire color frame (default)
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*
*   BUGS
*
*   SEE ALSO
*
*****************************************************************************
*	d0:Flyer board
*	d1:video channel
*	d2:mode
*****************************************************************************
StillMode
	IFD	DEBUGGEN
	DUMPMSG <StillMode>
	ENDC
	movem.l	d1-d3,-(sp)
					;d0 = Flyer board
					;d1 = Channel
	CLEAR	d3
	move.b	d2,d3			;Mode -> value
	move.b	#FLOOBY_STILLMODE,d2	;Item
	jsr	SetFlooby
	movem.l	(sp)+,d1-d3
	rts

*****i* flyer.library/GetClrSeqError ******************************************
*
*   NAME
*	GetClrSeqErr -- Check or clear Flyer sequencing error register
*
*   SYNOPSIS
*	error = GetClrSeqError(board,flag,doneptr,userIDptr,moreinfoptr)
*	D0                     D0    D1   A0      A1        A2
*
*	ULONG GetClrSeqError(UBYTE,UBYTE,UBYTE *,ULONG *,ULONG *);
*
*   FUNCTION
*	This is primarily used to check for timing errors during
*	sequencing.  It is capable of returning the exact event that
*	failed to sequence, and an argument that gives detailed info
*	about the returned error.
*
*	This function takes very little time to execute, and does not
*	involve the Flyer CPU at all, so sequencing performance is not
*	affected.
*
*   INPUTS
*	board - specifies the Flyer board (0-3)
*
*	flag - 0=get error, 1=clear error
*
*	doneptr - pointer to a variable to receive the "done" status
*                 (0 = still playing/recording, 1 = done)
*
*	userIDptr - pointer to a variable to receive the userID of the
*	            event in the sequence that failed.  This number is
*	            private to the application that downloaded the
*	            sequence.  Set to NULL to not use this feature.
*
*	moreinfoptr - pointer to a variable to receive details about the
*	              error, if any.  This may be used to give the exact
*	              number of fields an event was late, or how many fields
*	              were dropped, for example.  Set to NULL if not used.
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*	Certain Flyer functions may clear this error, such as PlaySequence
*	and FlyerRecord.
*
*	On a "get" operation, always updates variables to whom pointers are
*	provided, regardless of the type of error code returned (or none)
*
*   BUGS
*
*   SEE ALSO
*
*****************************************************************************
GetClrSeqErr
	IFD	DEBUGGEN
	DUMPMSG <GetClrSeqErr>
	ENDC
	movem.l	a3/a5,-(sp)

	bsr	GetCardUnit
	bne	.exit			;Failed? Exit

	move.l	unit_SRAMbase(a5),a3
	lea.l	SHAREDCTRL(a3),a3	;a3 = Amiga/Flyer shared ctrl structure

	tst.b	d1			;Test or clear it?
	bne.s	.clrit

	bsr	MaybeClearCache		;On systems with a cache problem

	cmp.w	#0,a0			;ptr provided?
	beq.s	.nodone
	move.b	sc_Done(a3),(a0)	;Return "Done"
.nodone	cmp.w	#0,a1			;ptr provided?
	beq.s	.nouid
	move.l	sc_UserID(a3),(a1)	;Return userID
.nouid	cmp.w	#0,a2			;ptr provided?
	beq.s	.noinfo
	move.l	sc_MoreInfo(a3),(a2)	;Return MoreInfo
.noinfo	move.b	sc_SeqError(a3),d0
	ext.w	d0
	ext.l	d0			;Extend BYTE to LONG (result)
	bra.s	.exit

.clrit
	clr.b	sc_SeqError(a3)		;Clear sequencing error
	clr.b	sc_Done(a3)		;Clear "done" flag
	clr.l	sc_UserID(a3)
	clr.l	sc_MoreInfo(a3)

	moveq.l	#FERR_OKAY,d0
.exit
	movem.l	(sp)+,a3/a5
	rts




******* flyer.library/AddAudEnv ******************************************
*
*   NAME
*	AddAudEnv - Adds an Audio Envelop to a clip 
*
*   SYNOPSIS
*	err=AddAudEnv(board,AudioEnv)
*	D0              D0   A0
*
*	ULONG AddAudEnv(UBYTE,APTR);
*
*   INPUTS
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*	Must be sent right after clip is added it sequence	
*	New for 4.3
*
*   BUGS
* 	Does not handle chan diff in vol or pan yet.
*
*   SEE ALSO
*			AddAudEKey
*****************************************************************************
*	d0:Flyer board
*****************************************************************************
*	WORD	opcode
*	BYTE	cont
*	BYTE	error
*	LONG	time		+4
*	LONG	durr		+8
*	WORD	Flags		+12
*	WORD	VOL1		+14
*	WORD	VOL2		+16
*	WORD	PAN1		+18
*	WORD	PAN2		+20
*****************************************************************************
AddAudEnv:
	movem.l	d1-d6/a0-a5,-(sp)
;	DUMPMSG	<AddAudEnv>
;	DUMPMEM	<AUDIOENV16>,(a0),#512
	move.w	AEH_KeysUsed(a0),d1
;	DUMPREG	<KEYS USED IN D1>
	sub.w	#1,d1	
	lea	AEH_HEADER_sizeof(a0),a0	
;	DUMPREG	<GOT 1ST KEY ADDRESS(A0)>

.loop1
	cmp.l	#1500,AE_Durr(a0)		;is gap too big?

	bls	.lenok
	move.l	a0,a2				;keep audio key index

	lea	-AE_KEY_sizeof(sp),sp
	move.l	sp,a0
;copy EKey
	move.l	(a2),(a0)			;copy time
	move.l	AE_Durr(a2),AE_Durr(a0)		;copy durr
	move.w	AE_Flags(a2),AE_Flags(a0)	;copy Flags
	move.l	AE_Vol1(a2),AE_Vol1(a0)		;copy Vol1,Vol2
	move.l	AE_Pan1(a2),AE_Pan1(a0)		;copy Pan1,Pan2

	move.l	(a2),d3				;time work		
	move.l	AE_Durr(a2),d4			;durr work


** calc how many patches
	move.l	d4,d6
	divu	#1500,d6
	sub.w	#1,d6				;dbf's exceed by 1

** calc the change $$$$.$$
	moveq	#0,d5
	move.w	AE_Vol1(a0),d5
	moveq	#0,d0
	move.w	AE_Vol1(a3),d0
	sub.l	d0,d5
	move.l	d5,d0				;keep long diff

	tst.l	d5	
	bpl.s	.notnegs
	neg.l	d5
.notnegs	

	mulu	#256,d5				;make room for Dec.	
** calc change per field
	divu	d4,d5
*	and.l	#$0000ffff,d5	
	mulu	#1500,d5
	divu	#256,d5
	and.l	#$0000ffff,d5
	tst.l	d0
	bpl.s	.notnegs2
	neg.w	d5
	ext.l	d5				;make d5 a long signed 
.notnegs2	

** get prev vol 
	moveq	#0,d2
	move.w	AE_Vol1(a3),d2


.gaperloop
	add.l	d5,d2
	move.w	d2,AE_Vol1(a0)	
	move.w	d2,AE_Vol2(a0)	
	
;	add.w	d5,AE_Vol1(a0)
;	add.w	d5,AE_Vol2(a0)
	move.l	#1500,AE_Durr(a0)
	bsr	AddAudEKey
	add.l	#1500,(a0)			;add durr to starttime
	add.l	#1500,d3			;inc final start
	sub.l	#1500,d4			;dec final durr
	dbf	d6,.gaperloop

;send last gapfix piece	
	move.l	AE_Vol1(a2),AE_Vol1(a0)		;copy Vol1,Vol2
	move.l	AE_Pan1(a2),AE_Pan1(a0)		;copy Pan1,Pan2
	move.l	d3,(a0)				;place final start time 
	move.l	d4,AE_Durr(a0)			;put final durr in place 
	bsr	AddAudEKey


	lea	AE_KEY_sizeof(sp),sp
	move.l	a2,a0				;restore ae ptr
	bra.s	.gaperdone

.lenok
;	DUMPREG <LEN OK, SENDING KEY(A0)> 
	bsr	AddAudEKey

.gaperdone	
	move.l	a0,a3				;prev node ptr
	lea	AE_KEY_sizeof(a0),a0
	dbf	d1,.loop1

	movem.l	(sp)+,d1-d6/a0-a5
	rts



 ifeq 1
	movem.l	d1-d4/a0-a5,-(sp)
	move.w	AEH_KeysUsed(a0),d1
	sub.w	#1,d1	
	lea	AEH_HEADER_sizeof(a0),a0	
.loop1	bsr	AddAudEKey
	lea	AE_KEY_sizeof(a0),a0
	dbf	d1,.loop1
	movem.l	(sp)+,d1-d4/a0-a5
	rts
 endc


******* flyer.library/AddAudEKey ******************************************
*
*   NAME
*	AddAudEKey - Adds an Audio Envelop key
*
*   SYNOPSIS
*	err=AddAudEKey(board,AUDEKEY)
*	D0              D0   A0
*
*	ULONG AddAudEKey(UBYTE,APTR);
*
*   INPUTS
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*	Now should only be called by AddAudEnv	
*	New for 4.2
*	
*   BUGS
*
*   SEE ALSO
*
*****************************************************************************
*	d0:Flyer board
*****************************************************************************
*	WORD	opcode
*	BYTE	cont
*	BYTE	error
*	LONG	time		+4
*	LONG	durr		+8
*	WORD	Flags		+12
*	WORD	VOL1		+14
*	WORD	VOL2		+16
*	WORD	PAN1		+18
*	WORD	PAN2		+20
*****************************************************************************
AddAudEKey;
	movem.l	d1-d6/a0-a5,-(sp)

;	DUMPREG	<AddAudEKey called>
	moveq	#0,d0			;board 0 for now
	bsr	Get_Brd_Cmd		;Get a free spot to place command
	bne	.exit			;Failed? Exit

	move.l	(a0),4(a3)		;time.
	move.l	4(a0),8(a3)		;derr
	move.w	8(a0),12(a3)		;flags
	move.w	10(a0),14(a3)		;vol1
	move.w	12(a0),16(a3)		;vol2
	move.w	14(a0),18(a3)		;pan1
	move.w	16(a0),20(a3)		;pan2


	move.l	d0,-(sp)

	move.l  0(a0),d0
;	DUMPREG	<Time(d0)>
	move.l  4(a0),d0
;	DUMPREG	<Durr(d0)>
	moveq	#0,d0
	move.w  8(a0),d0
;	DUMPREG	<Flags(d0)>
	move.w  10(a0),d0
;	DUMPREG	<Vol1(d0)>
	move.w  12(a0),d0
;	DUMPREG	<Vol2(d0)>
	move.w  14(a0),d0
;	DUMPREG	<Pan1>
	move.w  16(a0),d0
;	DUMPREG	<Pan2>

	move.l	(sp)+,d0

;	DUMPMEM	<AUDIOEKEY>,(A0),#64

	moveq.l	#op_AUDEKEY,d0
	lea.l	StdFollowUp(pc),a1
	bsr	FireCmd		;Go!
.exit
	movem.l	(sp)+,d1-d6/a0-a5
	rts



***************************************************************
*** All following functions work with ClipAction structures ***
***************************************************************

******* flyer.library/FlyerFileOpen ******************************************
*
*   NAME
*	FlyerFileOpen -- open a file on a Flyer drive for reading/writing
*
*   SYNOPSIS
*	error = FlyerFileOpen(clipaction)
*	D0                    A0
*
*	ULONG FlyerFileOpen(struct ClipAction *);
*
*   FUNCTION
*
*   INPUTS
*	clipaction - specifies the name of the file to open
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*
*   BUGS
*
*   SEE ALSO
*
*****************************************************************************
FileOpen
	IFD	DEBUGGEN
	DUMPMSG <FileOpen>
	ENDC
	movem.l	d1/d6-d7/a0-a1/a3-a5,-(sp)
	moveq.l	#op_FILEOPEN,d7
	moveq.l	#0,d6		;Unused
	bra	StdClipAction

******* flyer.library/FlyerCreateDir ******************************************
*
*   NAME
*	FlyerCreateDir -- create a sub-directory on a Flyer drive
*
*   SYNOPSIS
*	error = FlyerCreateDir(clipaction)
*	D0                     A0
*
*	ULONG FlyerCreateDir(struct ClipAction *);
*
*   FUNCTION
*
*   INPUTS
*	clipaction - specifies volume/path/name of the directory to create
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*
*   BUGS
*
*   SEE ALSO
*
*****************************************************************************
CreateDir
	IFD	DEBUGGEN
	DUMPMSG <CreateDir>
	ENDC
	movem.l	d1/d6-d7/a0-a1/a3-a5,-(sp)
	moveq.l	#op_CREATEDIR,d7
	moveq.l	#0,d6		;Unused
	bra	StdClipAction

******* flyer.library/FlyerDelete ******************************************
*
*   NAME
*	FlyerDelete -- Delete a file from a Flyer drive
*
*   SYNOPSIS
*	error = FlyerDelete(clipaction)
*	D0                  A0
*
*	ULONG FlyerDelete(struct ClipAction *);
*
*   FUNCTION
*
*   INPUTS
*	clipaction - specifies the path/name of the file to delete
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*
*   BUGS
*
*   SEE ALSO
*
*****************************************************************************
Delete
	IFD	DEBUGGEN
	DUMPMSG <Delete>
	ENDC
	movem.l	d1/d6-d7/a0-a1/a3-a5,-(sp)
	moveq.l	#op_DELETE,d7
	moveq.l	#0,d6		;Unused
	bra	StdClipAction

;*********************************************************************
;* Data2File -- Turn raw data into a file
;*
;* Entry:
;*	a0:struct ClipAction *ptr
;*	a6:Flyerbase (library)
;*
;* Exit:
;*********************************************************************
;Data2File
;	IFD	DEBUGGEN
;	DUMPMSG <Data2File>
;	ENDC
;	movem.l	d1/d6-d7/a0-a1/a3-a5,-(sp)
;	moveq.l	#op_DATA2FILE,d7
;	moveq.l	#0,d6		;Unused
;	bra	StdClipAction


*****i* flyer.library/FlyerLocate ******************************************
*
*   NAME
*	FlyerLocate -- obtain a "grip" on a file/dir, from a grip/name spec
*
*   SYNOPSIS
*	error = FlyerLocate(clipaction)
*	D0                  A0
*
*	ULONG FlyerLocate(struct ClipAction *);
*
*   FUNCTION
*
*   INPUTS
*	clipaction - specifies the path/name of the file
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*
*   BUGS
*
*   SEE ALSO
*
*****************************************************************************
Locate
	IFD	DEBUGGEN
	DUMPMSG <Locate>
	ENDC
	movem.l	d1/d6-d7/a0-a1/a3-a5,-(sp)
	moveq.l	#op_LOCATE,d7
	moveq.l	#0,d6		;Unused
	bra	StdClipAction


******* flyer.library/FlyerPlay ******************************************
*
*   NAME
*	FlyerPlay - Play a video/audio clip
*
*   SYNOPSIS
*	error = FlyerPlay(clipaction)
*	D0                A0
*
*	ULONG FlyerPlay(struct ClipAction *);
*
*   FUNCTION
*	Plays a video/audio clip as specified in the structure whose pointer
*	is given.  The definition of this structure is in "Flyer.h".
*
*	This call can be made to return at different times, depending on the
*	value of ReturnTime.
*
*	If the video channel or SCSI channel needed to accomplish this action
*	are in use when this clip needs to begin, the PermissFlags indicate
*	what actions the Flyer can take to free up the necessary resource(s).
*	CAPB_STEALOURVIDEO allows the Flyer to stop a clip on the video
*	channel specified for this new play.  CAPB_KILLOTHERVIDEO allows the
*	Flyer to stop clips on other video channels if needed to gain access
*	to the SCSI drive for this new clip.
*
*	If the CAPB_ERRIFBUSY flag is set, this call will return with error
*	FERR_CHANINUSE if the clip cannot be played without waiting for other
*	resources.  If this flag is not set, the Flyer will delay playback if
*	needed while waiting for resources it needs.
*
*	When using a ReturnTime of RTT_STOPPED, you may modify/recycle the
*	ClipAction structure once this call returns.  For RTT_IMMED and
*	RTT_STARTED, you must not modify the ClipAction structure until the
*	clip stops or is aborted.  Use AbortAction() to abort playback, and
*	CheckProgress(), CheckAction(), or WaitAction() to determine when
*	it's safe to reuse the structure.
*
*	If CAF_USEMATTE flag is true in the ClipAction structure, the video
*	channel this function uses will change to the matte color specified
*	in MatteY,MatteI,MatteQ fields when the clip finishes or is stopped.
*
*   INPUTS
*	clipaction - pointer to structure containing all information needed
*	   for playback, and to receive results when done.
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*	Only matte black is currently supported for CAF_USEMATTE
*
*   BUGS
*
*   SEE ALSO
*
*****************************************************************************
FlyerPlay
	IFD	DEBUGGEN
	DUMPMSG <FlyerPlay>
	ENDC
	movem.l	d1/d6-d7/a0-a1/a3-a5,-(sp)
	moveq.l	#op_FLYPLAY,d7
	moveq.l	#0,d6		;Unused
	bra	StdClipAction

******* flyer.library/FlyerRecord ******************************************
*
*   NAME
*	FlyerRecord - Record a video/audio clip
*
*   SYNOPSIS
*	error = FlyerRecord(clipaction)
*	D0                  A0
*
*	ULONG FlyerRecord(struct ClipAction *);
*
*   FUNCTION
*	Records a video/audio clip as specified in the structure whose
*	pointer is given.  The definition of this structure is in "Flyer.h".
*
*	Except when ReturnTime = RTT_STOPPED, recording can be stopped at any
*	time with the AbortAction() command (see below).
*
*	Do not call with both CAB_AUDIO1/2 and CAB_VIDEO flags clear, as this
*	is nonsensical.
*
*	If the video channel or SCSI channel needed to accomplish this action
*	are in use when this clip needs to begin, the PermissFlags indicate
*	what actions the Flyer can take to free up the necessary resource(s).
*	CAPB_STEALOURVIDEO allows the Flyer to stop a clip on the video
*	channel specified for this new record.  CAPB_KILLOTHERVIDEO allows
*	the Flyer to stop clips on other video channels if needed to gain
*	access to the SCSI drive for this new clip.
*
*	If the CAPB_ERRIFBUSY flag is set, this call will return with error
*	FERR_CHANINUSE if the clip cannot be recorded without waiting for
*	other resources.  If this flag is not set, the Flyer will delay
*	recording if needed while waiting for resources it needs.
*
*	When using a ReturnTime of RTT_STOPPED, you may modify/recycle the
*	ClipAction structure once this call returns.  For RTT_IMMED and
*	RTT_STARTED, you must not modify the ClipAction structure until the
*	clip stops or is aborted.  Use AbortAction() to abort recording, and
*	CheckProgress(), CheckAction(), or WaitAction() to determine when
*	it's safe to reuse the structure.
*
*   INPUTS
*	clipaction - pointer to structure containing all information needed
*	   for recording, and to receive results when done.
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*
*   BUGS
*
*   SEE ALSO
*
*****************************************************************************
FlyerRecord
	IFD	DEBUGGEN
	DUMPMSG <FlyerRecord>
	ENDC
	movem.l	d1/d6-d7/a0-a1/a3-a5,-(sp)
	moveq.l	#op_FLYRECORD,d7
	moveq.l	#0,d6		;Unused
	bra	StdClipAction

******* flyer.library/ChangeAudio ******************************************
*
*   NAME
*	ChangeAudio - Change audio parameters of a clip that is in progress
*
*   SYNOPSIS
*	error = ChangeAudio(clipaction)
*	D0                  A0
*
*	ULONG ChangeAudio(struct ClipAction *);
*
*   FUNCTION
*	This routine allows a clip that is in progress to have its audio
*	parameters adjusted.  Simply modify the audio field(s) desired
*	(or the CAB_AUDIO1/2 flags) in the structure used to initially start
*	the clip, then call this function with a pointer to that structure.
*
*   INPUTS
*	clipaction - pointer to same structure clip was initiated with
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*
*   BUGS
*
*   SEE ALSO
*
*****************************************************************************
ChangeAudio
	IFD	DEBUGGEN
	DUMPMSG <ChangeAudio>
	ENDC
	movem.l	d1/d6-d7/a0-a1/a3-a5,-(sp)
	moveq.l	#op_CHGAUDIO,d7
	moveq.l	#0,d6		;Unused
	bra	StdClipAttach

*********************************************************************
* _SearchArgs -- Set search arguments
*
* Entry:
*	a0:struct ClipAction *ptr
*	d1:flag.b (1=setup,2=change,0=end)
*	a6:Flyerbase (library)
*
* Exit:
*********************************************************************
_SearchArgs
	movem.l	d1/d6-d7/a0-a1/a3-a5,-(sp)
	moveq.l	#op_SRCHARGS,d7
	move.b	d1,d6			;Mode flag
	bra	StdClipAction

******* flyer.library/DoFindField ******************************************
*
*   NAME
*	DoFindField - find a specific field in clip (and view/hear it)
*
*   SYNOPSIS
*	error = DoFindField(clipaction)
*	D0                  A0
*
*	ULONG DoFindField(struct ClipAction *);
*
*   FUNCTION
*	Finds the color frame that contains the field number specified in
*	ca_VidStartField.  If the CAB_VIDEO flag was set, the frame's video
*	will loop on the output channel.  Also, if the CAB_AUDIO1/2 flag(s)
*	were set, the frame's audio will be heard.
*
*	Currently, when the user stops in a particular spot, the color frame
*	loops repeatedly, but the audio (if on) is heard once per new frame
*	only.
*
*	If the return value is non-0, something went wrong (such as the
*	requested field number is out of range for the clip).
*
*   INPUTS
*	clipaction - same pointer as was used with BeginFindField
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*
*   BUGS
*
*   SEE ALSO
*
*****************************************************************************
DoFindField
	IFD	DEBUGGEN
	DUMPMSG <DoFindField>
	ENDC
	movem.l	d1/d6-d7/a0-a1/a3-a5,-(sp)
	moveq.l	#op_DOSEARCH,d7
	moveq.l	#0,d6		;Unused
	bra	StdClipAction

******* flyer.library/LocateField *******************************************
*
*   NAME
*	LocateField - find a specific field in clip
*
*   SYNOPSIS
*	error = LocateField(clipaction)
*	D0                  A0
*
*	ULONG LocateField(struct ClipAction *);
*
*   FUNCTION
*	Finds the color frame that contains the field number specified in
*	ca_VidStartField.  This differs from the Begin/Do/EndFindField calls
*	in that this function just locates the field -- it does not attempt
*	to play its video or audio.  Also, the Begin/Do/End trio are designed
*	for multiple calls on the same clip (such as for jog/shuttling),
*	whereas this function is much simpler for just one lookup operation.
*
*	If the return value is not FERR_OKAY, something went wrong (such as
*	the requested field number is out of range for the clip).
*
*   INPUTS
*	clipaction - structure that contains the following data
*	   ca_Volume         -- ptr to FlyerVolume structure which contains
*	                        the board, SCSI drive, and pathname for clip
*	   ca_VidStartField  -- field number to locate
*
*   RESULT
*	If ERR_OKAY returned, clipaction->ca_StartBlk will contain the
*	block number of the frame header for the color frame which
*	contains the requested field
*
*   EXAMPLE
*
*   NOTES
*
*   BUGS
*
*   SEE ALSO
*
*****************************************************************************
LocateField
	IFD	DEBUGGEN
	DUMPMSG <LocateField>
	ENDC
	movem.l	d1/d6-d7/a0-a1/a3-a5,-(sp)
	moveq.l	#op_LOCATEFLD,d7
	moveq.l	#0,d6		;Unused
	bra	StdClipAction

******* flyer.library/MakeClipHead ******************************************
*
*   NAME
*	MakeClipHead - Define an A/B head for the specified clip
*
*   SYNOPSIS
*	error = MakeClipHead(clipaction)
*	D0                   A0
*
*	ULONG MakeClipHead(struct ClipAction *);
*
*   FUNCTION
*	Define an A/B head for the specified clip.  Use the ca_VidStartField,
*	ca_AudStartField, ca_VidFieldCount, and ca_AudFieldCount entries to
*	specify where the head should start and how long it should be.
*
*	This function can be used in two ways.  If used by itself, the A/B
*	head is made immediately.  If used between StartHeadList and
*	EndHeadList calls, the definition is just added to an internal list
*	which will be created when EndHeadList is called with makeit=1.  The
*	second method can optimize your A/B heads and can take advantage of
*	heads already in existence to shorten its work load.  The immediate
*	method of MakeClipHead cannot do any of these optimizations.
*
*   INPUTS
*	clipaction - specifies the clip and the in/out points
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*
*   BUGS
*
*   SEE ALSO
*	VoidAllHeads
*	VoidCardHeads
*	VoidClipHead
*
*****************************************************************************
MakeClipHead
	IFD	DEBUGGEN
	DUMPMSG <MakeClipHead>
	ENDC
	movem.l	d1/d6-d7/a0-a1/a3-a5,-(sp)
	moveq.l	#op_MAKEHEAD,d7
	moveq.l	#0,d6		;Unused
	bra	StdClipAction

******* flyer.library/AddSeqClip ******************************************
*
*   NAME
*	AddSeqClip - Add an entry to the Flyer sequence
*
*   SYNOPSIS
*	error = AddSeqClip(clip)
*	D0                 A0
*
*	ULONG AddSeqClip(struct ClipAction *);
*
*   FUNCTION
*	Add another event for the Flyer's internal sequencer to play.
*
*	Any combination of Video and Audio in/out points is supported
*	properly, including split audio.
*
*	See NewSequence for more info about the Flyer's sequencer.
*
*   INPUTS
*	clip - a ClipAction structure specifying the event.  The same
*	       structure may be used for each call, as all needed information
*	       is copied out of it before this function returns.
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*
*   BUGS
*
*   SEE ALSO
*	EndSequence
*	EndSequenceNew
*	NewSequence
*	PlaySequence
*
*****************************************************************************
AddSeqClip
	IFD	DEBUGGEN
	DUMPMSG <AddSeqClip>
	ENDC
	movem.l	d1/d6-d7/a0-a1/a3-a5,-(sp)
	moveq.l	#op_ADDSEQCLIP,d7
	moveq.l	#0,d6		;Unused
	bra	StdClipAction

******* flyer.library/VoidClipHead ******************************************
*
*   NAME
*	VoidClipHead - Remove an A/B head for the specified clip
*
*   SYNOPSIS
*	error = VoidClipHead(clipaction)
*	D0                   A0
*
*	ULONG VoidClipHead(struct ClipAction *);
*
*   FUNCTION
*	Removes an A/B head for the specified clip.  Must exactly match the
*	range of a previously defined head (with MakeClipHead) or this
*	does nothing.
*
*   INPUTS
*	clipaction - specifies clip and in/out points of head to remove
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*
*   BUGS
*
*   SEE ALSO
*	MakeClipHead
*	VoidAllHeads
*	VoidCardHeads
*
*****************************************************************************
VoidClipHead
	IFD	DEBUGGEN
	DUMPMSG <VoidClipHead>
	ENDC
	movem.l	d1/d6-d7/a0-a1/a3-a5,-(sp)
	moveq.l	#op_VOIDHEAD,d7
	moveq.l	#0,d6		;Unused
	bra	StdClipAction

******* flyer.library/StartClipCutList ******************************************
*
*   NAME
*	StartClipCutList - Prepares to perform clip cutting
*
*   SYNOPSIS
*	error = StartClipCutList(clip,flags)
*	D0                       A0   D0
*
*	ULONG StartClipCutList(struct ClipAction *,UBYTE);
*
*   FUNCTION
*	Used to begin clip cutting and processing for the clip specified.
*	After opening the list with this function, use AddClipCut to make
*	each subclip definition, then close the list using EndClipCutList.
*
*	Two major types of processing can currently be accomplished using
*	this mechanism: destructive and non-destructive.  The destructive
*	processing will make the listed sub-clips and delete any unused parts
*	of the original, doing a regional de-frag operation so as to not
*	fragment the drive.  The non-destructive operation leaves the
*	original intact and makes new sub-clips.
*
*   INPUTS
*	clip - specifies the master clip from which to make sub-clip(s)
*
*	flags - specifies the type of processing (see Flyer.h CCL_xxx flags)
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*	Currently only one ClipCut list may be open at a time.
*
*   BUGS
*
*   SEE ALSO
*	AddClipCut
*	EndClipCutList
*
*****************************************************************************
StartClipCutList
	IFD	DEBUGGEN
	DUMPMSG <StartCCL>
	ENDC
	movem.l	d1/d6-d7/a0-a1/a3-a5,-(sp)

	bsr	FreeRenameList		;Ensure blank rename list

	clr.w	fl_RefNumber(a6)	;Ref # = 0

	moveq.l	#op_NEWCUTLIST,d7
	move.b	d0,d6
	bra	StdClipAction

	nop

StdClipAction
	move.l	ca_Volume(a0),a1	;Get FlyerVolume structure
	cmp.w	#0,a1
	beq.s	StdClipError

	move.l	a0,-(sp)
	move.l	a1,a0			;Volume structure
	bsr	Get_Vol_Cmd		;Get a free spot to place command
	move.l	(sp)+,a0
	bne.s	StdClipExit		;Failed? Exit

	move.b	ca_ReturnTime(a0),cmd_RetTime(a4)	;User's return time

	CLEAR	d0
	bsr	PassClipAction		;Copy ClipAction and all others
	tst.l	d0
	beq.s	StdClipError		;Failed?

	bra.s	StdClipMerge

StdClipAttach
	cmp.w	#0,a0
	beq	StdClipError		;Must have one
	tst.l	ca_ID(a0)		;A good ID?
	beq	StdClipError

	move.l	ca_Volume(a0),a1	;Get FlyerVolume structure
	cmp.w	#0,a1
	beq.s	StdClipError

	move.l	a0,-(sp)
	move.l	a1,a0			;Volume structure
	bsr	Get_Vol_Cmd		;Get a free spot to place command
	move.l	(sp)+,a0
	bne.s	StdClipExit		;Failed? Exit

	move.b	#RT_ATTACHED,cmd_RetTime(a4)	;Do sync (attached to struct)

	CLEAR	d0
	bsr	PassClipAction		;Copy ClipAction and all others
	tst.l	d0
	beq.s	StdClipError		;Failed?

	clr.l	cmd_CopySize(a4)	;No copyback!

StdClipMerge
	sub.l	unit_SRAMbase(a5),d0
	move.l	d0,4(a3)		;SRAM offset addr
	move.b	#1,2(a3)		;Continue flag
	move.b	d6,8(a3)		;Optional flag

	move.w	d7,d0			;Get opcode
	lea.l	CopyBackAction(pc),a1	;Copyback when done (id = 0)
	bsr	FireAction		;Go!
	bra.s	StdClipExit
StdClipError
	moveq.l	#FERR_LIBFAIL,d0
StdClipExit
	movem.l	(sp)+,d1/d6-d7/a0-a1/a3-a5
	rts


******* flyer.library/StartHeadList ******************************************
*
*   NAME
*	StartHeadList - Prepares Flyer for list of A/B heads
*
*   SYNOPSIS
*	error = StartHeadList(board)
*	D0                    D0
*
*	ULONG StartHeadList(UBYTE);
*
*   FUNCTION
*	Prepares specified Flyer to compose a list of A/B heads.
*	Create a list like this when opening an existing project.  This
*	will be more efficient than just submitting head definitions one
*	at a time, because it allows the Flyer to do some optimizations.
*
*   INPUTS
*	board - specifies the Flyer board (0-3)
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*
*   BUGS
*
*   SEE ALSO
*
*****************************************************************************
StartHeadList
	IFD	DEBUGGEN
	DUMPMSG <StartHeadList>
	ENDC
	movem.l	a0-a1/a3-a5,-(sp)

	bsr	Get_Brd_Cmd	;Get a free spot to place command
	bne.s	.exit		;Failed? Exit

	moveq.l	#op_NEWHEADLIST,d0
	lea.l	StdFollowUp(pc),a1
	bsr	FireCmd		;Go!
.exit
	movem.l	(sp)+,a0-a1/a3-a5
	rts

******* flyer.library/EndHeadList ******************************************
*
*   NAME
*	EndHeadList - Completes list of A/B heads
*
*   SYNOPSIS
*	error = EndHeadList(board,makeit)
*	D0                  D0    D1
*
*	ULONG EndHeadList(UBYTE,UBYTE);
*
*   FUNCTION
*	Completes list of A/B heads.  If 'makeit' is 0, the list is thrown
*	away (aborted).  Otherwise, the Flyer then begins creating heads.
*	It may use old clip heads that already exist or create new ones.
*	Any old heads that are not used in the list are deleted.
*
*   INPUTS
*	board - specifies the Flyer board (0-3)
*
*	makeit - flag
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*
*   BUGS
*
*   SEE ALSO
*
*****************************************************************************
* Stops making A/B head list, process it if and only if flag true
*
*	d0:Flyer board
*	d1:(.b) make it flag (0 for abort)
*****************************************************************************
EndHeadList
	IFD	DEBUGGEN
	DUMPMSG <EndHeadList>
	ENDC
	movem.l	a0-a1/a3-a5,-(sp)

	bsr	Get_Brd_Cmd	;Get a free spot to place command
	bne.s	.exit		;Failed? Exit

	move.b	d1,4(a3)	;"makeit" Flag
	moveq.l	#op_ENDHEADLIST,d0
	lea.l	StdFollowUp(pc),a1
	bsr	FireCmd		;Go!
.exit
	movem.l	(sp)+,a0-a1/a3-a5
	rts


******* flyer.library/VoidAllHeads ******************************************
*
*   NAME
*	VoidAllHeads - Remove all A/B heads from all Flyers
*
*   SYNOPSIS
*	error = VoidAllHeads()
*	D0
*
*	ULONG VoidAllHeads(void);
*
*   FUNCTION
*	Removes all A/B heads from all drives attached to all Flyers.
*
*   INPUTS
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*
*   BUGS
*
*   SEE ALSO
*	MakeClipHead
*	VoidCardHeads
*	VoidClipHead
*
*****************************************************************************
VoidAllHeads
	IFD	DEBUGGEN
	DUMPMSG <VoidAllHeads>
	ENDC
	movem.l	a0-a1/a3-a5,-(sp)

	moveq.l	#0,d0		;Hard-wire to board 0 for now!!!
	bsr	Get_Brd_Cmd	;Get a free spot to place command
	bne.s	.exit		;Failed? Exit

	move.b	#1,2(a3)	;Cont = 1
	moveq.l	#op_VOIDALL,d0
	lea.l	StdFollowUp(pc),a1
	bsr	FireCmd		;Go!
.exit
	movem.l	(sp)+,a0-a1/a3-a5
	rts


******* flyer.library/VoidCardHeads ******************************************
*
*   NAME
*	VoidCardHeads - Remove all A/B heads for the Flyer card specified
*
*   SYNOPSIS
*	error = VoidCardHeads(board)
*	D0                    D0
*
*	ULONG VoidCardHeads(UBYTE board);
*
*   FUNCTION
*	Removes all A/B heads from drives attached to specified Flyer card
*
*   INPUTS
*	board - specifies the Flyer board (0-3)
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*
*   BUGS
*
*   SEE ALSO
*	MakeClipHead
*	VoidAllHeads
*	VoidClipHead
*
*****************************************************************************
VoidCardHeads
	IFD	DEBUGGEN
	DUMPMSG <VoidCardHeads>
	ENDC
	movem.l	a0-a1/a3-a5,-(sp)

	bsr	Get_Brd_Cmd	;Get a free spot to place command
	bne.s	.exit		;Failed? Exit

	move.b	#1,2(a3)	;Cont = 1
	moveq.l	#op_VOIDALL,d0
	lea.l	StdFollowUp(pc),a1
	bsr	FireCmd		;Go!
.exit
	movem.l	(sp)+,a0-a1/a3-a5
	rts



******* flyer.library/AddClipCut ******************************************
*
*   NAME
*	AddClipCut -- Add an entry to the ClipCut list
*
*   SYNOPSIS
*	error = AddClipCut(subclip)
*	D0                 A0
*
*	ULONG AddClipCut(struct ClipAction *);
*
*   FUNCTION
*	Add another sub-clip definition to the currently open ClipCut list.
*	The fields in this structure give specifics for this sub-clip,
*	including:
*
*	   Volume:Path/name for sub-clip
*	   Beginning and ending field numbers
*	   Contents (video and/or audio)
*
*	See StartClipCutList for a full description of this processing
*	mechanism.
*
*   INPUTS
*	subclip - a ClipAction structure specifying the new sub-clip.  The
*	          same structure may be used for each call, as all needed
*	          information is copied out of it before this function
*	          returns.
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*	The ClipAction fields AudStartField/VidStartField and
*	AudFieldCount/VidFieldCount must each match, regardless of the type
*	of clip specified to make.
*
*   BUGS
*
*   SEE ALSO
*	StartClipCutList
*	EndClipCutList
*
*****************************************************************************
AddClipCut
	IFD	DEBUGSKELL
	DUMPMSG <AddCC>
	ENDC

	bsr	AddCC		;Send definition to Flyer
				;This also strips volume name and converts
				;to SCSIdrive number for me -- how nice

	tst.b	d0		;Succeeded?
	bne	.failed

	movem.l	d1-d2/a0-a2/a5-a6,-(sp)

	move.l	a6,a5
	move.l	fl_SysLib(a5),a6

	move.l	ca_Volume(a0),a0
	cmp.w	#0,a0			;No volume?
	beq	.error

	move.l	fv_Path(a0),a1		;Ptr to pathname
	bsr	MeasureString
	moveq.l	#FlyNameNode_Sizeof,d1
	add.l	d1,d0			;For rest of structure

	movem.l	a0-a1,-(sp)
	move.l	d0,d2			;Save size
	move.l	#MEMF_PUBLIC!MEMF_CLEAR,d1

	IFD	DEBUGCLIPCUT
	DUMPHEXI.L <*** Alloc size >,d0,< ***\>
	DUMPHEXI.L <*** Alloc attr >,d1,< ***\>
	ENDC

	XSYS	AllocMem		;Allocate a new RenameNode
	movem.l	(sp)+,a0-a1

	IFD	DEBUGCLIPCUT
	DUMPHEXI.L <(>,d0,<)\>
	ENDC

	tst.l	d0			;Failed?
	beq	.error

	move.l	d0,a2
	move.l	d2,frn_Length(a2)		;Length of structure
	move.w	fl_RefNumber(a5),frn_RefNum(a2)	;Reference number
	move.b	fv_SCSIdrive(a0),frn_Drive(a2)	;SCSI drive

	move.l	a1,a0			;(src)
	lea.l	frn_Name(a2),a1		;(dest)
	move.l	d2,d0			;(size of struct)
	moveq.l	#FlyNameNode_Sizeof,d1
	sub.l	d1,d0			;(just size of string/NULL)
	bsr	FastCopy	;Copy path string

	IFD	DEBUGCLIPCUT
	DUMPHEXI.L <Inserting >,a2,<\>
	lea.l	fl_RenameList(a5),a0
	DUMPHEXI.L <Into list (>,a0,<)\>
	ENDC

	move.l	fl_RenameList(a5),frn_Next(a2)	;Insert at head of list
	move.l	a2,fl_RenameList(a5)

	moveq.l	#FERR_OKAY,d0
	bra.s	.exit

.error
	moveq.l	#FERR_LIBFAIL,d0
.exit
	movem.l	(sp)+,d1-d2/a0-a2/a5-a6
.failed
	rts

*********************************************************************
* AddCC -- Define a sub-clip to build from master clip (to Flyer)
*
* Entry:
*	a0:struct ClipAction *ptr
*	a6:Flyerbase (library)
*
* Exit:
*********************************************************************
AddCC:
	movem.l	a0-a1/a3-a5,-(sp)

	move.l	ca_Volume(a0),a1	;Get FlyerVolume structure
	cmp.w	#0,a1
	beq.s	.error

	move.l	a0,-(sp)
	move.l	a1,a0			;Volume structure
	bsr	Get_Vol_Cmd		;Get a free spot to place command
	move.l	(sp)+,a0
	bne.s	.exit			;Failed? Exit

	move.b	ca_ReturnTime(a0),cmd_RetTime(a4)	;User's return time

	move.b	#1,2(a3)			;Continue flag
	move.b	fv_SCSIdrive(a1),4(a3)		;Drive
	move.b	ca_Flags(a0),5(a3)		;CAF flags

	add.w	#1,fl_RefNumber(a6)		;++
	move.w	fl_RefNumber(a6),6(a3)		;Ref #

	btst	#CAB_VIDEO,ca_Flags(a0)		;Audio only?
	beq.s	.audonly

	move.l	ca_VidStartField(a0),8(a3)	;Start field
	move.l	ca_VidFieldCount(a0),12(a3)	;Field count
	bra.s	.joinup

.audonly
	move.l	ca_AudStartField(a0),8(a3)	;Start field
	move.l	ca_AudFieldCount(a0),12(a3)	;Field count

.joinup
	moveq.l	#op_ADDSUBCLIP,d0	;Get opcode
	lea.l	StdFollowUp(pc),a1
	bsr	FireCmd			;Go!
	bra.s	.exit
.error
	moveq.l	#FERR_LIBFAIL,d0
.exit
	movem.l	(sp)+,a0-a1/a3-a5
	rts


******* flyer.library/EndClipCutList ******************************************
*
*   NAME
*	EndClipCutList - Finalizes ClipCut list
*
*   SYNOPSIS
*	error = EndClipCutList(doit)
*	D0                     D0
*
*	ULONG EndClipCutList(UBYTE);
*
*   FUNCTION
*	Finalizes a ClipCut list that was opened with StartClipCutList.  If
*	the "doit" flag is set, the processing will begin.  Otherwise, the
*	list is thrown away and the original clip remains unchanged.
*
*	See StartClipCutList for a full description of this processing
*	mechanism.
*
*   INPUTS
*	doit - flag: 0 aborts and discards list, 1 starts clip processing
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*
*   BUGS
*
*   SEE ALSO
*	StartClipCutList
*	AddClipCut
*
*****************************************************************************
EndClipCutList
	IFD	DEBUGGEN
	DUMPMSG <EndCCL>
	ENDC

	bsr	EndCCL			;Let Flyer do the hard work

;Rename each temp clip now
	movem.l	d0-d2/a0-a3,-(sp)

	move.l	fl_RenameList(a6),a3
.eachtemp
	cmp.w	#0,a3			;Another?
	beq	.exit

	lea.l	fl_PrivVolume(a6),a1	;My private FlyerVolume
	lea.l	fl_PrivAction(a6),a0	;My private ClipAction

	move.l	a1,ca_Volume(a0)		;Link together
	move.b	#RT_STOPPED,ca_ReturnTime(a0)	;Return time

	clr.b	fv_Board(a1)			;Board 0
	move.b	frn_Drive(a3),fv_SCSIdrive(a1)	;SCSI drive
	move.b	#FVF_USENUMS,fv_Flags(a1)	;Override volume finding

	lea.l	TempNameArea(pc),a2
	move.l	a2,fv_Path(a1)			;Pointer to temp name

	move.l	#$5F746D70,(a2)			;_tmp_
	move.b	#$5F,4(a2)
	lea.l	8(a2),a2
	clr.b	(a2)
	move.w	frn_RefNum(a3),d0		;Reference Number
	moveq.l	#3-1,d2
.digits
	move.b	d0,d1
	and.b	#$0F,d1			;ref MOD 16
	cmp.b	#9,d1
	bls.s	.nothex
	add.b	#7,d1
.nothex
	add.b	#$30,d1
	move.b	d1,-(a2)		;Another digit
	lsr.l	#4,d0			;ref /= 16
	dbf	d2,.digits

	IFD	DEBUGCLIPCUT
	DUMPMSG	<Renaming>
	lea.l	TempNameArea(pc),a2
	DUMPSTR	0(a2)
	DUMPMSG	< - Old name>
	DUMPSTR	frn_Name(a3)
	DUMPMSG	< - New name>
	ENDC

					;a0 = ClipAction of old name
	lea.l	frn_Name(a3),a1		;Pointer to new name
	CLEAR	d0			;Grip = 0
	bsr	Rename			;Conver to final SubClip name

	move.l	frn_Next(a3),a3		;Walk the list
	bra	.eachtemp

.exit
	movem.l	(sp)+,d0-d2/a0-a3

	bsr	FreeRenameList		;Free memory resources
	rts

*********************************************************************
* EndCCL -- Let Flyer perform CutList operation on list
*
* Entry:
*	d0:doit flag.b
*	a6:Flyerbase (library)
*
* Exit:
*********************************************************************
EndCCL:
	movem.l	d1/a0-a1/a3-a5,-(sp)

	move.b	d0,d1

	moveq.l	#0,d0		;Hard-wire to board 0 for now!!!
	bsr	Get_Brd_Cmd	;Get a free spot to place command
	bne.s	.exit		;Failed? Exit

	move.b	#1,2(a3)	;Cont = 1
	move.b	d1,4(a3)	;Doit?

	moveq.l	#op_MAKESUBCLIPS,d0	;Get opcode
	lea.l	StdFollowUp(pc),a1
	bsr	FireCmd			;Go!
	bra.s	.exit
.abort
	moveq.l	#FERR_OKAY,d0
.exit
	movem.l	(sp)+,d1/a0-a1/a3-a5
	rts

******* flyer.library/NewSequence ******************************************
*
*   NAME
*	NewSequence - Prepare Flyer for a sequence download
*
*   SYNOPSIS
*	error = NewSequence(board)
*	D0                  D0
*
*	ULONG NewSequence(UBYTE);
*
*   FUNCTION
*	Used to begin sending a sequence definition to the Flyer.  Then,
*	using other calls, each piece of the sequence is defined, the
*	sequence is "closed", and then it may be played with one call.  This
*	is allows the Flyer to do much more complicated sequences
*	successfully than by using FlyerPlay calls in a double-buffered
*	fashion (which is now only supported in a limited way).
*
*   INPUTS
*	board - specifies the Flyer board (0-3)
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*
*   BUGS
*
*   SEE ALSO
*	AddSeqClip
*	EndSequence
*	EndSequenceNew
*	PlaySequence
*
*****************************************************************************
NewSequence
	IFD	DEBUGGEN
	DUMPMSG <NewSequence>
	ENDC
	movem.l	a0-a1/a3-a5,-(sp)

	bsr	Get_Brd_Cmd	;Get a free spot to place command
	bne.s	.exit		;Failed? Exit

	moveq.l	#op_NEWSEQ,d0
	lea.l	StdFollowUp(pc),a1
	bsr	FireCmd		;Go!
.exit
	movem.l	(sp)+,a0-a1/a3-a5
	rts


******* flyer.library/EndSequenceNew ******************************************
*
*   NAME
*	EndSequenceNew -- Finalizes the Flyer's internal sequence (extra features)
*
*   SYNOPSIS
*	error = EndSequenceNew(action, doit)
*	D0                     A0      D0
*
*	ULONG EndSequenceNew(struct ClipAction *, UBYTE);
*
*   FUNCTION
*	Identical to EndSequence function, except that it uses a ClipAction structure,
*	which specifies the Flyer board number.  This allows some enhanced things
*	during the sometimes lengthy sequence processing phase, such as the ability
*	to be run asynchronously, ability to be aborted, and the ability for the
*	application to obtain status during this phase.
*
*   INPUTS
*	clipaction - specifies the board number in the attached Volume structure
*
*	doit - flag: 0 aborts and discards sequence, 1 starts post-processing
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*
*   BUGS
*
*   SEE ALSO
*	AddSeqClip
*	EndSequence
*	NewSequence
*	PlaySequence
*
*****************************************************************************
EndSequenceNew
	IFD	DEBUGGEN
	DUMPMSG <EndSequenceNew>
	ENDC
	movem.l	a0-a1/a3-a5/d2,-(sp)

	move.b	d0,d2			;Save "doit" flag

	move.l	ca_Volume(a0),a1	;Get FlyerVolume structure
	cmp.w	#0,a1
	beq.s	.error

	move.l	a0,-(sp)
	move.l	a1,a0			;Volume structure
	bsr	Get_Vol_Cmd		;Get a free spot to place command
	move.l	(sp)+,a0
	bne.s	.exit			;Failed? Exit

	move.b	ca_ReturnTime(a0),cmd_RetTime(a4)	;User's return time

	move.b	#1,2(a3)		;Cont = 1
	move.b	d2,4(a3)		;"doit" Flag

	moveq.l	#op_ENDSEQ,d0
	lea.l	StdFollowUp(pc),a1
					;(a0 = ClipAction)
	bsr	FireAction		;Go!
	bra.s	.exit
.error
	moveq.l	#FERR_LIBFAIL,d0
.exit
	movem.l	(sp)+,a0-a1/a3-a5/d2
	rts

******* flyer.library/EndSequence ******************************************
*
*   NAME
*	EndSequence - Finalizes the Flyer's internal sequence
*
*   SYNOPSIS
*	error = EndSequence(board,doit)
*	D0                  D0    D1
*
*	ULONG EndSequence(UBYTE, UBYTE);
*
*   FUNCTION
*	Finalizes the sequence definition that was downloaded.  Post process-
*	ing occurs at this time, such as sequence optimization and temporary
*	data movement.  This call, therefore, may take a while to complete.
*	When it does, the sequence is ready to play (using PlaySequence).
*
*	If the "doit" flag is FALSE (0), no post processing is done, but the
*	sequence is closed (this is required as an "abort" during sequence
*	downloading).
*
*	See NewSequence for more info on Flyer sequencing.
*
*   INPUTS
*	board - specifies the Flyer board (0-3)
*
*	doit - flag: 0 aborts and discards sequence, 1 starts post-processing
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*
*   BUGS
*
*   SEE ALSO
*	AddSeqClip
*	EndSequenceNew
*	NewSequence
*	PlaySequence
*
*****************************************************************************
EndSequence
	IFD	DEBUGGEN
	DUMPMSG <EndSequence>
	ENDC
	movem.l	a0-a1/a3-a5,-(sp)

	bsr	Get_Brd_Cmd	;Get a free spot to place command
	bne.s	.exit		;Failed? Exit

	move.b	#1,2(a3)	;Cont = 1
	move.b	d1,4(a3)	;"doit" Flag

	moveq.l	#op_ENDSEQ,d0
	lea.l	StdFollowUp(pc),a1
	bsr	FireCmd		;Go!
.exit
	movem.l	(sp)+,a0-a1/a3-a5
	rts


******* flyer.library/PlaySequence ******************************************
*
*   NAME
*	PlaySequence - Play the Flyer's internal sequence
*
*   SYNOPSIS
*	error = PlaySequence(board,basetime)
*	D0                   D0    D1
*
*	ULONG PlaySequence(UBYTE, ULONG);
*
*   FUNCTION
*	Starts the sequence playing that was previously downloaded to the
*	Flyer.  "basetime" is the time (on the Flyer's clock) to begin.  All
*	components in the sequence are relative to this start time.
*
*	This call returns immediately so that takes, effects may be done
*	synchronous with the sequence.  No other interaction with the Flyer
*	is required (or recommended) for the sequence to play, other than
*	aborting the sequence early (with AbortSequence).
*
*	See NewSequence for more info on Flyer sequencing.
*
*   INPUTS
*	board - specifies the Flyer board (0-3)
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*
*   BUGS
*
*   SEE ALSO
*	AddSeqClip
*	EndSequence
*	EndSequenceNew
*	NewSequence
*
*****************************************************************************
PlaySequence
	IFD	DEBUGGEN
	DUMPMSG <PlaySequence>
	ENDC
	movem.l	a0-a1/a3-a5,-(sp)

	bsr	Get_Brd_Cmd	;Get a free spot to place command
	bne.s	.exit		;Failed? Exit

	move.l	d1,4(a3)	;Base time for sequence start

	moveq.l	#op_PLAYSEQ,d0
	lea.l	StdFollowUp(pc),a1
	bsr	 FireCmd		;Go!
.exit
	movem.l	(sp)+,a0-a1/a3-a5
	rts


*****i* flyer.library/AudioParams ******************************************
*
*   NAME
*	AudioParams -- (not implemented)
*
*   SYNOPSIS
*	error = AudioParams()
*	D0
*
*	ULONG AudioParams(void);
*
*   FUNCTION
*	(nothing)
*
*   INPUTS
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*
*   BUGS
*
*   SEE ALSO
*
*****************************************************************************
AudioParams
	movem.l	a0-a1/a3-a5,-(sp)
	DUMPMSG	<AUDIOPARAMS>
	bsr	Get_Brd_Cmd	;Get a free spot to place command
	bne.s	.exit		;Failed? Exit

;	move.l	#op_AUDCTRL,d0
	lea.l	StdFollowUp(pc),a1
	bsr	FireCmd		;Go!
.exit
	movem.l	(sp)+,a0-a1/a3-a5
	rts

******* flyer.library/SCSIreset ******************************************
*
*   NAME
*	SCSIreset -- Hardware reset all SCSI busses on Flyer
*
*   SYNOPSIS
*	error = SCSIreset(board)
*	D0                D0
*
*	ULONG SCSIreset(UBYTE);
*
*   FUNCTION
*
*   INPUTS
*	board - specifies the Flyer board (0-3)
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*
*   BUGS
*
*   SEE ALSO
*
*****************************************************************************
SCSIreset
	IFD	DEBUGGEN
	DUMPMSG <SCSIreset>
	ENDC
	movem.l	a0-a1/a3-a5,-(sp)

	bsr	Get_Brd_Cmd	;Get a free spot to place command
	bne.s	.exit		;Failed? Exit

	moveq.l	#op_SCSIRST,d0
	lea.l	StdFollowUp(pc),a1
	bsr	FireCmd		;Go!
.exit
	movem.l	(sp)+,a0-a1/a3-a5
	rts

******* flyer.library/SCSIinit ******************************************
*
*   NAME
*	SCSIinit -- Test and Initialize SCSI bus on Flyer
*
*   SYNOPSIS
*	error = SCSIinit(flyervolume)
*	D0               A0
*
*	ULONG SCSIinit(struct FlyerVolume *);
*
*   FUNCTION
*
*   INPUTS
*	volume - pointer to structure which specifies bus to init
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*	Set v_SCSIdrive to the SCSI bus number x 8
*	Also set 'FVF_USENUMS' in v_Flags
*
*   BUGS
*
*   SEE ALSO
*
*****************************************************************************
SCSIinit
	IFD	DEBUGGEN
	DUMPMSG <SCSIinit>
	ENDC
	movem.l	a0-a1/a3-a5,-(sp)

	bsr	Get_Vol_Cmd	;Get a free spot to place command
	bne.s	.exit		;Failed? Exit

	move.b	fv_SCSIdrive(a0),5(a3)		;SCSI drive
	moveq.l	#op_SCSIINIT,d0
	lea.l	StdFollowUp(pc),a1
	bsr	FireCmd		;Go!
.exit
	movem.l	(sp)+,a0-a1/a3-a5
	rts

******* flyer.library/FindDrives ******************************************
*
*   NAME
*	FindDrives -- Find responding drives on SCSI bus
*
*   SYNOPSIS
*	error = FindDrives(flyervolume,buffer)
*	D0                 A0          A1
*
*	ULONG FindDrives(struct FlyerVolume *,APTR);
*
*   FUNCTION
*	This function scans one of the Flyer's SCSI busses, looking for
*	drives at each of the possible unit numbers.  An array of data
*	is returned which gives some rudimentary information about which
*	unit numbers correspond to a present drive, as well as some info
*	which is helpful in getting more detailed data (with the Inquiry
*	command.
*
*   INPUTS
*	volume - pointer to structure which specifies bus to scan for drives
*
*	buffer - pointer to an 18 byte buffer which receives results
*
*   RESULT
*	Format of data array:
*
*	UBYTE DriveFlags;  // '1' bit at (1<<unit) for each drive present
*	UBYTE pad;
*	UBYTE Versions[8]; // SCSI versions of each drive found, [x] = unit
*	UBYTE InqLens[8];  // Inquiry lengths of each drive found, [x] = unit
*
*   EXAMPLE
*
*   NOTES
*
*   BUGS
*
*   SEE ALSO
*	Inquiry
*
*****************************************************************************
FindDrives
	IFD	DEBUGGEN
	DUMPMSG <FindDrives>
	ENDC
	movem.l	a0-a1/a3-a5,-(sp)

	bsr	Get_Vol_Cmd	;Get a free spot to place command
	bne.s	.exit		;Failed? Exit

	move.l	a1,cmd_CopyDest(a4)	;Save for follow-up
	move.b	fv_SCSIdrive(a0),5(a3)		;SCSI drive
	moveq.l	#op_FINDDRV,d0
	lea.l	.FollowUp(pc),a1
	bsr	FireCmd		;Go!
.exit
	movem.l	(sp)+,a0-a1/a3-a5
	rts

.FollowUp			;Can trash a0,a1,d0
	lea.l	6(a3),a0		;src
	move.l	cmd_CopyDest(a4),a1	;dest
	moveq.l	#18,d0		;18 bytes
	bsr	FastCopy	;Copy results for each drive to user buffer
	move.b	3(a3),d0	;Get error code
	rts


******* flyer.library/CopyData ******************************************
*
*   NAME
*	CopyData - Copy data from one location to another
*
*   SYNOPSIS
*	error = CopyData(srcvolume,destvolume,srcaddr,blocks,destaddr)
*	D0               A0        A1         D0      D1     D2
*
*	ULONG CopyData(struct FlyerVolume *,struct FlyerVolume *,ULONG,ULONG,
*	        ULONG);
*
*   FUNCTION
*	Copies a range of data from one drive to another.  This currently
*	works with a start block number and a block count.  The start
*	locations may be different on the src and dest drives.  This function
*	may also be used to move data on the same drive.  Handles making a
*	copy which overlaps original on same drive.
*
*	Can also read/write to/from a tape drive by simply using -1 for the
*	appropriate address (srcaddr or destaddr).
*
*   INPUTS
*	srcvolume - pointer to structure which describes a volume (used to
*	   pick specific Flyer card).
*
*	destvolume - pointer to structure which describes a volume (used to
*	   pick specific Flyer card).
*
*	srcaddr - SCSI block address on source drive
*
*	blocks - number of SCSI blocks to copy
*
*	destaddr - SCSI block address on destination drive
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*	May copy slower than "real-time" playback rate if copying to and from
*	the same drive.
*
*   BUGS
*
*   SEE ALSO
*
*****************************************************************************
*	a0:struct FlyerVolume *srcvol
*	a1:struct FlyerVolume *destvol
*	d0:scsi address (lba) (long)
*	d1:blocks to copy (long)
*	d2:dest scsi address (lba) (long)
*****************************************************************************
CopyData
	IFD	DEBUGGEN
	DUMPMSG <CopyData>
	ENDC
	movem.l	a0-a1/a3-a5,-(sp)

	bsr	Get_Vol_Cmd	;Get a free spot to place command
	bne.s	.exit		;Failed? Exit

	move.l	d0,8(a3)	;start lba

;Old way (just looked at drive numbers)
;	move.b	fv_SCSIdrive(a0),5(a3)		;src drive
;	move.b	fv_SCSIdrive(a1),7(a3)		;dest drive

;New way (parses volume name into drive numbers/or uses drive #'s if FVF_USENUMS)
	bsr	FindVolume			;Convert src volume to drive
	bne.s	.exit				;Failed? Exit
	move.b	fv_SCSIdrive(a0),5(a3)		;->src drive
	move.l	a1,a0
	bsr	FindVolume			;Convert dest volume to drive
	bne.s	.exit				;Failed? Exit
	move.b	fv_SCSIdrive(a0),7(a3)		;->dest drive

	move.l	d1,12(a3)	;number of blocks
	move.l	d2,16(a3)	;dest lba
	move.b	#0,20(a3)	;No verify

	moveq.l	#op_COPYDATA,d0
	lea.l	StdFollowUp(pc),a1
	bsr	FireCmd		;Go!
.exit
	movem.l	(sp)+,a0-a1/a3-a5
	rts


******* flyer.library/ReqSense ******************************************
*
*   NAME
*	ReqSense -- Do SCSI RequestSense command
*
*   SYNOPSIS
*	error = ReqSense(flyervolume,buffersize,buffer)
*	D0               A0          D0         A1
*
*	ULONG ReqSense(struct FlyerVolume *,UBYTE,APTR);
*
*   FUNCTION
*
*   INPUTS
*	volume - pointer to structure which specifies drive
*
*	buffersize - size of data buffer provided (in bytes)
*
*	buffer - pointer to buffer to receive Sense data
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*
*   BUGS
*
*   SEE ALSO
*
*****************************************************************************
ReqSense
	IFD	DEBUGGEN
	DUMPMSG <ReqSense>
	ENDC
	move.l	d7,-(sp)
	move.b	#SCMD_REQSENSE,d7		;SCSI cmd
	bsr	SCSIdatain
	move.l	(sp)+,d7
	rts


******* flyer.library/Inquiry ******************************************
*
*   NAME
*	Inquiry -- Do SCSI Inquiry command
*
*   SYNOPSIS
*	error = Inquiry(flyervolume,buffersize,buffer)
*	D0              A0          D0         A1
*
*	ULONG Inquiry(struct FlyerVolume *,UBYTE,APTR);
*
*   FUNCTION
*
*   INPUTS
*	volume - pointer to structure which specifies drive
*
*	buffersize - size of buffer provided (in bytes)
*
*	buffer - pointer to buffer to receive Inquiry data
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*
*   BUGS
*
*   SEE ALSO
*
*****************************************************************************
Inquiry
	IFD	DEBUGGEN
	DUMPMSG <Inquiry>
	ENDC
	move.l	d7,-(sp)
	move.b	#SCMD_INQUIRY,d7		;SCSI cmd
	bsr	SCSIdatain
	move.l	(sp)+,d7
	rts


******* flyer.library/ModeSense ******************************************
*
*   NAME
*	ModeSense -- Do SCSI ModeSense command
*
*   SYNOPSIS
*	error = ModeSense(flyervolume,buffersize,page,buffer)
*	D0                A0          D0         D1   A1
*
*	ULONG ModeSense(struct FlyerVolume *,UBYTE,UBYTE,APTR);
*
*   FUNCTION
*
*   INPUTS
*	volume - pointer to structure which specifies drive
*
*	buffersize - size of buffer provided (in bytes)
*
*	page - Mode page code to read
*
*	buffer - pointer to buffer to receive ModeSense data
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*
*   BUGS
*
*   SEE ALSO
*
*****************************************************************************
ModeSense
	IFD	DEBUGGEN
	DUMPMSG <ModeSense>
	ENDC
	move.l	d7,-(sp)
	move.b	#SCMD_MODESENSE,d7		;SCSI cmd
	and.l	#$000000FF,d1			;Page to request
	bsr	SCSIdatain
	move.l	(sp)+,d7
	rts



*********************************************************************
* SCSIdatain -- Do SCSI command that collects data
*
* Entry:
*	a0:struct FlyerVolume *volume
*	d0:Buffer size (byte)
*	d1:Extra data.l (optional)
*	a1:Buffer to receive data
*	d7:SCSI CDB cmd (.b)
*	a6:Flyerbase (library)
*
* Exit:
*********************************************************************
SCSIdatain
	IFD	DEBUGGEN
	DUMPMSG <SCSIdatain>
	ENDC
	movem.l	a0-a1/a3-a5,-(sp)

	bsr	Get_Vol_Cmd	;Get a free spot to place command
	bne.s	.exit		;Failed? Exit

	move.b	fv_SCSIdrive(a0),5(a3)		;SCSI drive
	move.b	d7,6(a3)			;SCSI cmd

	and.l	#$000000FF,d0
	move.l	d0,cmd_CopySize(a4)	;Size of copy (when done)
	move.w	d0,12(a3)		;Size of buffer
				;d0=amount
	bsr	AllocSRAM	;Need some SRAM
	tst.l	d0		;Failed?
	beq.s	.error

	move.l	a1,cmd_CopyDest(a4)	;User buffer for copy (when done)
	move.l	d0,cmd_CopySrc(a4)	;Source SRAM ptr (when done)
	sub.l	unit_SRAMbase(a5),d0	;Turn into offset address
	move.l	d0,8(a3)	;Buffer to receive
	move.l	d1,14(a3)	;Extra info
	moveq.l	#op_SCSICALL,d0
	lea.l	FollowUpCopy(pc),a1
	bsr	FireCmd		;Go!
	bra.s	.exit
.error
	bsr	FreeCmdSlot		;Won't use cmd
	moveq.l	#FERR_LIBFAIL,d0
.exit
	movem.l	(sp)+,a0-a1/a3-a5
	rts


******* flyer.library/ModeSelect ******************************************
*
*   NAME
*	ModeSelect -- Do SCSI ModeSelect command
*
*   SYNOPSIS
*	error = ModeSelect(flyervolume,buffersize,buffer,PFbyte)
*	D0                 A0          D0         A1     D1
*
*	ULONG ModeSelect(struct FlyerVolume *,UBYTE,APTR,UBYTE);
*
*   FUNCTION
*
*   INPUTS
*	volume - pointer to structure which specifies drive
*
*	buffersize - size of buffer provided (in bytes)
*
*	buffer - pointer to buffer which contains ModeSelect data
*
*	PFbyte - SCSI PageFormat byte
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*
*   BUGS
*
*   SEE ALSO
*
*****************************************************************************
ModeSelect
	IFD	DEBUGGEN
	DUMPMSG <ModeSelect>
	ENDC
	movem.l	a0-a1/a3-a5,-(sp)

	bsr	Get_Vol_Cmd	;Get a free spot to place command
	bne.s	.exit		;Failed? Exit

	move.b	fv_SCSIdrive(a0),5(a3)		;SCSI drive
	move.b	#SCMD_MODESEL,6(a3)		;SCSI cmd

	and.l	#$000000FF,d0
	move.w	d0,12(a3)	;Length
				;a1=src ptr
				;d0=size
	bsr	CopytoSRAM	;Copy stuff to SRAM
	bne.s	.exit		;Failed? Exit

	move.l	d0,8(a3)

	moveq	#0,d0
	move.b	d1,d0		;PF byte ---> extra
	move.l	d0,14(a3)

	moveq.l	#op_SCSICALL,d0
	lea.l	StdFollowUp(pc),a1
	bsr	FireCmd		;Go!
.exit
	movem.l	(sp)+,a0-a1/a3-a5
	rts


******* flyer.library/ReadSize ******************************************
*
*   NAME
*	ReadSize -- Read SCSI drive capacity
*
*   SYNOPSIS
*	error = ReadSize(flyervolume,countptr,lengthptr)
*	D0               A0          A1       A2
*
*	ULONG ReadSize(struct FlyerVolume *,ULONG *,ULONG *);
*
*   FUNCTION
*
*   INPUTS
*	volume - pointer to structure which specifies drive
*
*	countptr - pointer to ULONG to receive drive size in blocks
*
*	lengthptr - pointer to ULONG to receive logical block size (bytes)
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*
*   BUGS
*
*   SEE ALSO
*
*****************************************************************************
ReadSize
	IFD	DEBUGGEN
	DUMPMSG <ReadSize>
	ENDC
	movem.l	a0-a1/a3-a5,-(sp)

	bsr	Get_Vol_Cmd	;Get a free spot to place command
	bne.s	.exit		;Failed? Exit

	move.b	fv_SCSIdrive(a0),5(a3)		;SCSI drive

	move.l	a1,cmd_CopyDest(a4)	;Save these for wrap-up time
	move.l	a2,cmd_CopyExtra(a4)
	moveq.l	#op_READSIZE,d0
	lea.l	.FollowUp(pc),a1
	bsr	FireCmd		;Go!
.exit
	movem.l	(sp)+,a0-a1/a3-a5
	rts

.FollowUp			;Can trash a0,a1,d0
	move.l	cmd_CopyDest(a4),d0
	beq.s	.avoid1
	move.l	d0,a0
	move.l	6(a3),d0	;drive size (in blocks)
	move.l	d0,(a0)
.avoid1
	move.l	cmd_CopyExtra(a4),d0
	beq.s	.avoid2
	move.l	d0,a0
	move.l	10(a3),d0	;block size
	move.l	d0,(a0)
.avoid2
	move.b	3(a3),d0	;Get error code
	rts

******* flyer.library/Read10 ******************************************
*
*   NAME
*	Read10 -- Transfer data from SCSI drive to DMA memory
*
*   SYNOPSIS
*	error = Read10(action,blocks,lba,buffer)
*	D0             A0     D0     D1  D2
*
*	ULONG Read10(struct ClipAction *,WORD,ULONG,ULONG);
*
*   FUNCTION
*
*   INPUTS
*	clipaction - specifies the volume and return method
*
*	blocks - blocks to transfer
*
*	lba - starting lba
*
*	buffer - DMA buffer start (block) to receive data
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*
*   BUGS
*
*   SEE ALSO
*
*****************************************************************************
Read10
	IFD	DEBUGGEN
	DUMPMSG <Read10>
	ENDC
	movem.l	a0-a1/a3-a5,-(sp)

	move.l	ca_Volume(a0),a1	;Get FlyerVolume structure
	cmp.w	#0,a1
	beq.s	.error

	move.l	a0,-(sp)
	move.l	a1,a0			;Volume structure
	bsr	Get_Vol_Cmd		;Get a free spot to place command
	move.l	(sp)+,a0
	bne.s	.exit			;Failed? Exit

	move.b	ca_ReturnTime(a0),cmd_RetTime(a4)	;User's return time

	move.b	fv_SCSIdrive(a1),5(a3)		;SCSI drive

	move.l	d2,12(a3)	;DRAM address to receive
	move.w	d0,10(a3)	;Size of buffer
	move.l	d1,6(a3)	;lba
	moveq.l	#op_READ10,d0
	lea.l	StdFollowUp(pc),a1
	bsr	FireAction	;Go!
	bra.s	.exit
.error
	moveq.l	#FERR_LIBFAIL,d0
.exit
	movem.l	(sp)+,a0-a1/a3-a5
	rts

******* flyer.library/Write10 ******************************************
*
*   NAME
*	Write10 -- Transfer data from DMA memory to SCSI drive
*
*   SYNOPSIS
*	error = Write10(action,blocks,buffer,lba)
*	D0              A0     D0     D1     D2
*
*	ULONG Write10(struct ClipAction *,WORD,ULONG,ULONG);
*
*   FUNCTION
*
*   INPUTS
*	clipaction - specifies the volume and the return method
*
*	blocks - blocks to transfer
*
*	buffer - DMA buffer start (block) of data to write
*
*	lba - starting lba
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*
*   BUGS
*
*   SEE ALSO
*
*****************************************************************************
Write10
	IFD	DEBUGGEN
	DUMPMSG <Write10>
	ENDC
	movem.l	a0-a1/a3-a5,-(sp)

	move.l	ca_Volume(a0),a1	;Get FlyerVolume structure
	cmp.w	#0,a1
	beq.s	.error

	move.l	a0,-(sp)
	move.l	a1,a0			;Volume structure
	bsr	Get_Vol_Cmd		;Get a free spot to place command
	move.l	(sp)+,a0
	bne.s	.exit			;Failed? Exit

	move.b	ca_ReturnTime(a0),cmd_RetTime(a4)	;User's return time

	move.b	fv_SCSIdrive(a1),5(a3)		;SCSI drive

	move.l	d1,6(a3)	;lba
	move.w	d0,10(a3)	;# blks
	move.l	d2,12(a3)	;address
	moveq.l	#op_WRITE10,d0
	lea.l	StdFollowUp(pc),a1
	bsr	FireAction	;Go!
	bra.s	.exit
.error
	moveq.l	#FERR_LIBFAIL,d0
.exit
	movem.l	(sp)+,a0-a1/a3-a5
	rts


******* flyer.library/SCSIseek ******************************************
*
*   NAME
*	SCSIseek -- Do SCSI seek command
*
*   SYNOPSIS
*	error = SCSIseek(flyervolume,lba)
*	D0               A0          D0
*
*	ULONG SCSIseek(struct FlyerVolume *,ULONG);
*
*   FUNCTION
*
*   INPUTS
*	volume - pointer to structure which specifies drive
*
*	lba - lba to which to seek
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*
*   BUGS
*
*   SEE ALSO
*
*****************************************************************************
SCSIseek
	IFD	DEBUGGEN
	DUMPMSG <SCSIseek>
	ENDC
	movem.l	a0-a1/a3-a5,-(sp)

	bsr	Get_Vol_Cmd	;Get a free spot to place command
	bne.s	.exit		;Failed? Exit

	move.b	fv_SCSIdrive(a0),5(a3)		;SCSI drive
	move.b	#SCMD_SEEK,6(a3)		;SCSI cmd

	move.l	d0,14(a3)	;position (lba)
	moveq.l	#op_SCSICALL,d0
	lea.l	StdFollowUp(pc),a1
	bsr	FireCmd		;Go!
.exit
	movem.l	(sp)+,a0-a1/a3-a5
	rts


*****i* flyer.library/FlyerSCSIdirect ***************************************
*
*   NAME
*	FlyerSCSIdirect -- standard "SCSI direct" channel to Flyer drives
*
*   SYNOPSIS
*	error = FlyerSCSIdirect(board,unit,scsiinfo,structlen)
*	D0                      D0    D1   A0       D2
*
*	ULONG FlyerSCSIdirect(UBYTE,UBYTE,struct SCSICmd *,UBYTE);
*
*   FUNCTION
*
*   INPUTS
*	board - specifies the Flyer board (0-3)
*
*	unit - SCSI unit number
*
*	scsiinfo - pointer to SCSICmd structure
*
*	structlen - length of SCSICmd structure provided
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*
*   BUGS
*
*   SEE ALSO
*
*****************************************************************************
SCSIdirect
	IFD	DEBUGGEN
	DUMPMSG <SCSIdirect>
	ENDC
	movem.l	a0-a1/a3-a5,-(sp)
	bsr	Get_Brd_Cmd	;Get a free spot to place command
	bne.s	.exit		;Failed? Exit

	move.b	d1,4(a3)	;Drive #

	move.l	a0,cmd_CopyDest(a4)

	bsr	PassSCSICmd		;Copy structure and all buffers to SRAM
	tst.l	d0
	beq.s	.error			;Failed?
	move.l	d0,cmd_CopySrc(a4)
	sub.l	unit_SRAMbase(a5),d0
	move.l	d0,6(a3)		;SRAM offset addr

	CLEAR	d0
	move.b	d2,d0
	move.l	d0,cmd_CopySize(a4)

	moveq.l	#op_SCSIDIRECT,d0
	lea.l	.FollowUp(pc),a1
	bsr	FireCmd		;Go!
	bra.s	.exit
.error
	moveq.l	#FERR_LIBFAIL,d0
.exit
	movem.l	(sp)+,a0-a1/a3-a5
	rts

.FollowUp
	movem.l	a2-a3,-(sp)
	move.l	cmd_CopySrc(a4),a2	;SRAM structure
	move.l	cmd_CopyDest(a4),a3	;User structure

	move.l	scsi_Data(a2),a0
	add.l	unit_SRAMbase(a5),a0
	move.l	scsi_Data(a3),a1
	move.l	a1,scsi_Data(a2)	;Restore original ptr
	move.l	scsi_Length(a3),d0
	bsr	FastCopy		;Copy data buffer back

	move.l	scsi_SenseData(a2),a0
	add.l	unit_SRAMbase(a5),a0
	move.l	scsi_SenseData(a3),a1
	move.l	a1,scsi_SenseData(a2)	;Restore original ptr
	CLEAR	d0
	move.w	scsi_SenseLength(a3),d0
	bsr	FastCopy		;Copy sense buffer back

	move.l	scsi_Command(a3),a1
	move.l	a1,scsi_Command(a2)	;Restore original ptr

	move.l	a2,a0
	move.l	a3,a1
	move.l	cmd_CopySize(a4),d0
	bsr	FastCopy		;Copy structure back

	movem.l	(sp)+,a2-a3
	move.b	3(a3),d0	;Get error code
	rts

***********************************************************************
* *** PassSCSICmd ***
* Allocate SRAM for SCSICmd structure and related buffers.  Copies
* data into allocated SRAM and links them all together.
*
* Entry:
*	a0:Ptr to SCSICmd structure
*	d2:Length of structure
*	a4:cmd ctrl structure
*	a5:unit structure
*
* Exit:
*	d0:Ptr to start of SRAM copy (or 0 if failed)
***********************************************************************
PassSCSICmd:
	IFD	DEBUGGEN
	DUMPMSG <PassSCSIcmd>
	ENDC
	movem.l	d1-d6/a0-a3/a6,-(sp)
	move.l	a0,a3			;SCSICmd structure

	IFD	DEBUGCLIP
	DUMPHEXI.L <PassSCSI - SCSICmd: >,a3,<\>
	ENDC

;	(d2 = structure length)
	move.l	scsi_Length(a3),d1	;Data buffer length
	CLEAR	d4
	move.w	scsi_CmdLength(a3),d4	;CDB length
	CLEAR	d3
	move.w	scsi_SenseLength(a3),d3	;Sense length

	IFD	DEBUGCLIP
	DUMPHEXI.L <Structure Length: >,d2,<\>
	DUMPHEXI.L <Buffer Length: >,d1,<\>
	DUMPHEXI.L <CDB Length: >,d4,<\>
	DUMPHEXI.L <SenseBuffer Length: >,d3,<\>
	ENDC

	move.l	d1,d6
	add.l	d2,d6
	add.l	d3,d6
	add.l	d4,d6
	beq	.exit			;None needed, exit

	move.l	d6,d0
				;d0=amount
	bsr	AllocSRAM		;Get the SRAM I need
	tst.l	d0			;Failed?
	beq	.exit
	move.l	d0,a6
	add.l	d6,a6			;Ptr to end of SRAM

	IFD	DEBUGCLIP
	DUMPMSG <Got it!>
	ENDC

;Copy CDB
	tst.l	d4
	beq.s	.nocopyCDB
	sub.l	d4,a6			;Back up to area
	move.l	a6,a1			;dest
	move.l	scsi_Command(a3),a0	;src
	move.l	d4,d0			;length
	bsr	FastCopy		;Copy CDB
	move.l	a6,d4
	sub.l	unit_SRAMbase(a5),d4	;Keep offset to structure
.nocopyCDB

;Copy SenseBuffer
	tst.l	d3
	beq.s	.nocopysense
	sub.l	d3,a6			;Back up to area
	move.l	a6,a1			;dest
	move.l	scsi_SenseData(a3),a0	;src
	move.l	d3,d0			;length
	bsr	FastCopy		;Copy SenseBuffer
	move.l	a6,d3
	sub.l	unit_SRAMbase(a5),d3	;Keep offset to structure
.nocopysense

;Copy data buffer
	tst.l	d1
	beq.s	.nocopybuffer
	sub.l	d1,a6			;Back up to area
	move.l	a6,a1			;dest
	move.l	scsi_Data(a3),a0	;src
	move.l	d1,d0			;length
	bsr	FastCopy		;Copy data buffer
	move.l	a6,d1
	sub.l	unit_SRAMbase(a5),d1	;Keep offset to name
.nocopybuffer

;Copy SCSICmd structure
	tst.l	d2
	beq.s	.nocopystruct
	sub.l	d2,a6			;Back up to area
	move.l	a6,a1			;dest
	move.l	a3,a0			;src
	move.l	d2,d0			;len
	bsr	FastCopy		;Copy ClipAction structure
	move.l	d4,scsi_Command(a6)	;Plug in SRAM offset->CDB
	move.l	d3,scsi_SenseData(a6)	;Plug in SRAM offset->Sense buffer
	move.l	d1,scsi_Data(a6)	;Plug in SRAM offset->Data buffer

.nocopystruct
	move.l	a6,d0			;Return this

.exit
	movem.l	(sp)+,d1-d6/a0-a3/a6
	rts

******* flyer.library/FlyerDriveCheck ******************************************
*
*   NAME
*	FlyerDriveCheck - check if the specified drive has anything in it
*
*   SYNOPSIS
*	error = FlyerDriveCheck(volume)
*	D0                      A0
*
*	ULONG FlyerDriveCheck(struct FlyerVolume *);
*
*   FUNCTION
*	Checks to see if the specified board/channel/drive has media loaded.
*	Note that you must use the FVF_USENUMS flags, since the use of a
*	volume name is not logical here.
*
*   INPUTS
*	volume - pointer to structure which describes a volume
*
*   RESULT
*	error - FERR_OKAY or FERR_VOLNOTFOUND
*
*   EXAMPLE
*
*   NOTES
*
*   BUGS
*
*   SEE ALSO
*
*****************************************************************************
DriveCheck
	IFD	DEBUGVERBOSE
	DUMPMSG <DriveCheck>
	ENDC
	move.l	a1,-(sp)

	lea.l	fl_Volumes(a6),a1
.nextvol
	move.l	(a1),a1		;Get next node
	tst.l	(a1)		;A valid node?
	beq.s	.fail

	move.b	fvn_Board(a1),d0
	cmp.b	fv_Board(a0),d0
	bne.s	.nextvol
	move.b	fvn_SCSIdrive(a1),d0
	cmp.b	fv_SCSIdrive(a0),d0
	bne.s	.nextvol

	moveq.l	#FERR_OKAY,d0
	bra.s	.exit

.fail
	moveq.l	#FERR_VOLNOTFOUND,d0
.exit
	move.l	(sp)+,a1
	rts


******* flyer.library/FlyerDriveInfo ******************************************
*
*   NAME
*	FlyerDriveInfo - Return general information about a drive
*
*   SYNOPSIS
*	error = FlyerDriveInfo(volume,volinfo)
*	D0                     A0     A1
*
*	ULONG FlyerDriveInfo(struct FlyerVolume *,struct FlyerVolInfo *);
*
*   FUNCTION
*	This returns general information about the drive, including the
*	volume name, total number of blocks, number of blocks free,
*	size of largest contiguous block, and free block size if DeFrag
*	would be performed.
*
*	If volptr is NULL, just fills in info in FlyerVolume structure only.
*
*   INPUTS
*	volume - pointer to structure which specifies volume
*
*	volinfo - pointer to structure to receive information about volume
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*
*   BUGS
*
*   SEE ALSO
*
*****************************************************************************
DriveInfo
	IFD	DEBUGGEN
	DUMPMSG <DriveInfo>
	ENDC
	movem.l	a0-a1/a3-a5,-(sp)

	bsr	Get_Vol_Cmd	;Get a free spot to place command
	bne.s	.exit		;Failed? Exit

	move.b	fv_SCSIdrive(a0),5(a3)		;Drive

	move.l	a0,cmd_CopyExtra(a4)		;Keep for follow-up

	CLEAR	d0
	move.w	fvi_len(a1),d0	;Length of FlyerVolInfo
	beq.s	.error

	move.l	d0,cmd_CopySize(a4)	;Save for later
				;d0=amount
	bsr	AllocSRAM	;Need some SRAM
	tst.l	d0		;Failed?
	beq.s	.error

	move.l	a1,cmd_CopyDest(a4)	;Save for later (caller's ptr)
	move.l	d0,cmd_CopySrc(a4)	;Ptr to SRAM area
	sub.l	unit_SRAMbase(a5),d0	;Turn into offset address
	move.l	d0,6(a3)	;Buffer to receive
	moveq.l	#op_DRIVEINFO,d0
	lea.l	.FollowUp(pc),a1	;Copyback when done
	bsr	FireCmd		;Go!
	bra.s	.exit
.error
	bsr	FreeCmdSlot		;Won't use cmd
	moveq.l	#FERR_LIBFAIL,d0
.exit
	movem.l	(sp)+,a0-a1/a3-a5
	rts

.FollowUp			;Can trash a0,a1,d0
	bsr	FollowUpCopyStruct	;Copy structure back to user

	move.b	3(a3),d0		;Succeeded?
	beq.s	.addnewvol

	move.l	cmd_CopyExtra(a4),a0	;FlyerVolume structure
	bsr	KillVolume		;UnMount removed volume
	bra.s	.zend

.addnewvol
	move.l	cmd_CopyExtra(a4),a0	;FlyerVolume structure
	move.l	cmd_CopyDest(a4),a1	;FlyerVolInfo structure
	bsr	NewVolume		;Mount new volume

.zend
	move.b	3(a3),d0		;Get error code
	rts


*****i* flyer.library/FlyerFreeGrip ******************************************
*
*   NAME
*	FlyerFreeGrip -- free a grip obtained earlier
*
*   SYNOPSIS
*	error = FlyerFreeGrip(flyervolume,grip)
*	D0                    A0          D0
*
*	ULONG FlyerFreeGrip(struct FlyerVolume *,ULONG);
*
*   FUNCTION
*
*   INPUTS
*	volume - pointer to structure which specifies drive
*
*	grip - grip to free
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*
*   BUGS
*
*   SEE ALSO
*
*****************************************************************************
FreeGrip
	IFD	DEBUGGEN
	DUMPMSG <FreeGrip>
	ENDC
	movem.l	a0-a1/a3-a5,-(sp)

	bsr	Get_Vol_Cmd	;Get a free spot to place command
	bne.s	.exit		;Failed? Exit

	move.b	fv_SCSIdrive(a0),5(a3)		;SCSI drive

	move.l	d0,6(a3)	;grip

	moveq.l	#op_FREEGRIP,d0
	lea.l	StdFollowUp(pc),a1
	bsr	FireCmd		;Go!
.exit
	movem.l	(sp)+,a0-a1/a3-a5
	rts

*****i* flyer.library/FlyerCopyGrip ******************************************
*
*   NAME
*	FlyerCopyGrip -- make a clone of a grip
*
*   SYNOPSIS
*	error = FlyerCopyGrip(flyervolume,grip,gripptr)
*	D0                    A0          D0   A1
*
*	ULONG FlyerCopyGrip(struct FlyerVolume *,ULONG,ULONG *);
*
*   FUNCTION
*
*   INPUTS
*	volume - pointer to structure which specifies drive
*
*	grip - grip to copy
*
*	gripptr - pointer to variable to receive copied grip
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*
*   BUGS
*
*   SEE ALSO
*
*****************************************************************************
CopyGrip
	IFD	DEBUGGEN
	DUMPMSG <CopyGrip>
	ENDC
	movem.l	a0-a1/a3-a5,-(sp)

	bsr	Get_Vol_Cmd	;Get a free spot to place command
	bne.s	.exit		;Failed? Exit

	move.b	fv_SCSIdrive(a0),5(a3)		;SCSI drive

	move.l	d0,6(a3)	;grip
	move.l	a1,cmd_CopyDest(a4)	;Save for followup

	moveq.l	#op_COPYGRIP,d0
	lea.l	.FollowUp(pc),a1
	bsr	FireCmd		;Go!
.exit
	movem.l	(sp)+,a0-a1/a3-a5
	rts

.FollowUp			;Can trash a0,a1,d0
	move.l	cmd_CopyDest(a4),d0
	beq.s	.avoid
	move.l	d0,a0
	move.l	10(a3),d0
	move.l	d0,(a0)		;Return new grip
.avoid
	move.b	3(a3),d0	;Get error
	rts

*****i* flyer.library/FlyerCmpGrips ******************************************
*
*   NAME
*	FlyerCmpGrips -- compare the similarity of two grips
*
*   SYNOPSIS
*	error = FlyerCmpGrips(flyervolume,grip1,grip2)
*	D0                    A0          D0    D1
*
*	ULONG FlyerCmpGrips(struct FlyerVolume *,ULONG,ULONG);
*
*   FUNCTION
*
*   INPUTS
*	volume - pointer to structure which specifies drive
*
*	grip1 - first grip
*
*	grip2 - second grip
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*
*   BUGS
*
*   SEE ALSO
*
*****************************************************************************
CmpGrips
	IFD	DEBUGGEN
	DUMPMSG <CmpGrips>
	ENDC
	movem.l	a0-a1/a3-a5,-(sp)

	bsr	Get_Vol_Cmd	;Get a free spot to place command
	bne.s	.exit		;Failed? Exit

	move.b	fv_SCSIdrive(a0),5(a3)		;SCSI drive

	move.l	d0,6(a3)	;grip 1
	move.l	d1,10(a3)	;grip 2

	moveq.l	#op_CMPGRIPS,d0
	lea.l	StdFollowUp(pc),a1
	bsr	FireCmd		;Go!
.exit
	movem.l	(sp)+,a0-a1/a3-a5
	rts

*****i* flyer.library/FlyerParent ******************************************
*
*   NAME
*	FlyerParent -- get a grip on the parent of the grip/file specified
*
*   SYNOPSIS
*	error = FlyerParent(flyervolume,grip,newgripptr,blockptr)
*	D0                  A0          D0   A1         A2
*
*	ULONG FlyerParent(struct FlyerVolume *,ULONG,ULONG *,ULONG *);
*
*   FUNCTION
*
*   INPUTS
*	volume - pointer to structure which specifies drive
*
*	grip1 - grip of file/dir
*
*	newgripptr - pointer to variable to receive the grip on the parent
*
*	blockptr - pointer to var to receive block which identifies parent
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*
*   BUGS
*
*   SEE ALSO
*
*****************************************************************************
Parent
	IFD	DEBUGGEN
	DUMPMSG <Parent>
	ENDC
	movem.l	a0-a1/a3-a5,-(sp)

	bsr	Get_Vol_Cmd	;Get a free spot to place command
	bne.s	.exit		;Failed? Exit

	move.b	fv_SCSIdrive(a0),5(a3)		;SCSI drive

	move.l	d0,6(a3)		;grip
	move.l	a1,cmd_CopyDest(a4)	;&grip
	move.l	a2,cmd_CopyExtra(a4)	;&block

	moveq.l	#op_PARENT,d0
	lea.l	.FollowUp(pc),a1
	bsr	FireCmd		;Go!
.exit
	movem.l	(sp)+,a0-a1/a3-a5
	rts

.FollowUp			;Can trash a0,a1,d0
	move.l	cmd_CopyDest(a4),d0
	beq.s	.avoid
	move.l	d0,a0
	move.l	10(a3),d0
	move.l	d0,(a0)		;Return new grip
.avoid
	move.l	cmd_CopyExtra(a4),d0
	beq.s	.avoid2
	move.l	d0,a0
	move.l	14(a3),d0
	move.l	d0,(a0)		;Return parent block
.avoid2
	move.b	3(a3),d0	;Get error
	rts

*****i* flyer.library/FlyerExamine ******************************************
*
*   NAME
*	FlyerExamine -- return information about a file or directory
*
*   SYNOPSIS
*	error = FlyerExamine(flyervolume,grip,objinfoptr)
*	D0                   A0          D0   A1
*
*	ULONG FlyerExamine(struct FlyerVolume *,ULONG,struct ClipInfo *);
*
*   FUNCTION
*
*   INPUTS
*	volume - pointer to structure which specifies drive
*
*	grip - grip of file/dir
*
*	objinfoptr - Pointer to ClipInfo structure to receive info
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*
*   BUGS
*
*   SEE ALSO
*
*****************************************************************************
Examine
	IFD	DEBUGGEN
	DUMPMSG <Examine>
	ENDC
	movem.l	a0-a1/a3-a5,-(sp)

	bsr	Get_Vol_Cmd	;Get a free spot to place command
	bne.s	.exit		;Failed? Exit

	move.b	fv_SCSIdrive(a0),5(a3)		;SCSI drive

	move.l	d0,6(a3)	;Grip

	CLEAR	d0
	move.w	ci_len(a1),d0	;Length of caller's structure
	move.l	d0,cmd_CopySize(a4)
				;d0=amount
	bsr	AllocSRAM	;Need some SRAM
	tst.l	d0		;Failed?
	beq.s	.error

	move.l	a1,cmd_CopyDest(a4)	;Save for later (caller's ptr)
	move.l	d0,cmd_CopySrc(a4)	;Ptr to SRAM area
	sub.l	unit_SRAMbase(a5),d0	;Turn into offset address
	move.l	d0,10(a3)		;Buffer to receive
	moveq.l	#op_EXAMINE,d0
	lea.l	FollowUpCopyStruct(pc),a1	;Copyback when done
	bsr	FireCmd		;Go!
	bra.s	.exit
.error
	bsr	FreeCmdSlot		;Won't use cmd
	moveq.l	#FERR_LIBFAIL,d0
.exit
	movem.l	(sp)+,a0-a1/a3-a5
	rts




******* flyer.library/FlyerFileExtend ******************************************
*
*   NAME
*	FlyerFileExtend -- Extend an open Flyer file without have to write data
*
*   SYNOPSIS
*	error = FlyerFileExtend(flyervolume,fileID,size)
*	D0                     A0          D0     D1  
*
*	ULONG FlyerFileExtend(struct FlyerVolume *,ULONG,ULONG,UBYTE *,
*	        ULONG *);
*
*   FUNCTION
*
*   INPUTS
*	volume - pointer to same structure as passed to FlyerFileOpen
*
*	fileID - ID returned from FlyerFileOpen call
*
*	size - number of bytes to extend by.
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*
*   BUGS
*
*   SEE ALSO
*
*****************************************************************************
FileExtend
	IFD	DEBUGGEN
	DUMPMSG <FileExtend>
	ENDC
	movem.l	d1/d3/a0-a1/a3-a5,-(sp)

	bsr	Get_Vol_Cmd	;Get a free spot to place command
	bne	.exit		;Failed? Exit

	move.b	fv_SCSIdrive(a0),5(a3)		;SCSI drive
	move.l	d0,6(a3)	;fileID
	move.l	d1,10(a3)	;size

	sub.l	unit_SRAMbase(a5),d0	;Turn into offset address
	move.l	d0,14(a3)

	moveq.l	#op_FILEEXTEND,d0
	lea.l	.FollowUp(pc),a1
	bsr	FireCmd		;Go!
	bra.s	.exit
.error
	bsr	FreeCmdSlot		;Won't use cmd
	moveq.l	#FERR_LIBFAIL,d0
.exit
	movem.l	(sp)+,d1/d3/a0-a1/a3-a5
	rts

.FollowUp				;Can trash a0,a1,d0
	move.b	3(a3),d0		;Get error code
	rts


******* flyer.library/FlyerDirList ******************************************
*
*   NAME
*	FlyerDirList -- return first/next entry in a directory
*
*   SYNOPSIS
*	error = FlyerDirList(flyervolume,grip,objinfoptr,firstflag,fsonly)
*	D0                   A0          D0   A1         D1        D2
*
*	ULONG FlyerDirList(struct FlyerVolume *,ULONG,struct ClipInfo *,
*	        UBYTE,UBYTE);
*
*   FUNCTION
*
*   INPUTS
*	volume - pointer to structure which specifies drive
*
*	grip - grip of directory
*
*	objinfoptr - Pointer to ClipInfo structure to receive info
*
*	firstflag - 0 if first call, 1 for each additional
*
*	fsonly - 0 for full information, 1 for just FileSys info
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*
*   BUGS
*
*   SEE ALSO
*
*****************************************************************************
DirList
	IFD	DEBUGGEN
	DUMPMSG <DirList>
	ENDC
	movem.l	a0-a1/a3-a5,-(sp)

	bsr	Get_Vol_Cmd	;Get a free spot to place command
	bne.s	.exit		;Failed? Exit

	move.b	fv_SCSIdrive(a0),5(a3)		;SCSI drive

	move.l	d0,6(a3)	;Grip

	CLEAR	d0
	move.w	ci_len(a1),d0	;Length of caller's structure
	move.l	d0,cmd_CopySize(a4)
	move.b	d1,14(a3)
	move.b	d2,15(a3)
				;d0=amount
	bsr	AllocSRAM	;Need some SRAM
	tst.l	d0		;Failed?
	beq.s	.error

	move.l	a1,cmd_CopyDest(a4)	;Save for later (caller's ptr)
	move.l	d0,cmd_CopySrc(a4)	;Ptr to SRAM area
	sub.l	unit_SRAMbase(a5),d0	;Turn into offset address
	move.l	d0,10(a3)		;Buffer to receive
	moveq.l	#op_DIRLIST,d0
	lea.l	FollowUpCopyStruct(pc),a1	;Copyback when done
	bsr	FireCmd		;Go!
	bra.s	.exit
.error
	bsr	FreeCmdSlot		;Won't use cmd
	moveq.l	#FERR_LIBFAIL,d0
.exit
	movem.l	(sp)+,a0-a1/a3-a5
	rts


******* flyer.library/FlyerFileClose ******************************************
*
*   NAME
*	FlyerFileClose -- close a file
*
*   SYNOPSIS
*	error = FlyerFileClose(flyervolume,fileID)
*	D0                     A0          D0
*
*	ULONG FlyerFileClose(struct FlyerVolume *,ULONG);
*
*   FUNCTION
*
*   INPUTS
*	volume - pointer to same structure as passed to FlyerFileOpen
*
*	fileID - ID returned from FlyerFileOpen call
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*
*   BUGS
*
*   SEE ALSO
*	FlyerFileOpen
*
*****************************************************************************
FileClose
	IFD	DEBUGGEN
	DUMPMSG <FileClose>
	ENDC
	movem.l	a0-a1/a3-a5,-(sp)

	bsr	Get_Vol_Cmd	;Get a free spot to place command
	bne.s	.exit		;Failed? Exit

	move.b	fv_SCSIdrive(a0),5(a3)		;SCSI drive

	move.l	d0,6(a3)	;file ID

	moveq.l	#op_FILECLOSE,d0
	lea.l	StdFollowUp(pc),a1
	bsr	FireCmd		;Go!
.exit
	movem.l	(sp)+,a0-a1/a3-a5
	rts

******* flyer.library/FlyerFileSeek ******************************************
*
*   NAME
*	FlyerFileSeek -- seek to a given position in a file
*
*   SYNOPSIS
*	error = FlyerFileSeek(flyervolume,fileID,pos_ext,pos,mode,posptr,oldposptr)
*	D0                    A0          D0     D1      D2  D3   A1     A2
*
*	ULONG FlyerFileSeek(struct FlyerVolume *,ULONG,DLONG,UBYTE,DLONG *,
*	        DLONG *);
*
*   FUNCTION
*
*   INPUTS
*	volume - pointer to same structure as passed to FlyerFileOpen
*
*	fileID - ID returned from FlyerFileOpen call
*
*	pos_ext - requested new file position (per 'mode' below)(high 32 bits)
*
*	pos - requested new file position (per 'mode' below)(low 32 bits)
*
*	mode - seek mode to apply to 'pos' (FLYER_POS_xxx)
*
*	posptr - pointer to variable to receive new file position
*
*	oldposptr - pointer to variable to receive old file position
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*	I don't like passing individual ULONGs for the requested position
*	and pointers to DLONGS for the results, but our lack of address registers
*	means we can't do it the consistent way.  This way does have the advantage
*	of changing the prototype for the function enough to warn us if an older 
*	version of fileseek is being called
*
*   BUGS
*
*   SEE ALSO
*	flyer.h
*
*****************************************************************************
FileSeek
	IFD	DEBUGGEN
	DUMPMSG <FileSeek>
	ENDC
	movem.l	d1-d3/a0-a1/a3-a5,-(sp)

	bsr	Get_Vol_Cmd	;Get a free spot to place command
	bne.s	.exit		;Failed? Exit

	move.b	fv_SCSIdrive(a0),5(a3)		;SCSI drive

	move.b	d3,6(a3)	;mode
	move.l	d0,8(a3)	;fileID
	move.l	d1,12(a3)	;pos_ext
	move.l	d2,16(a3)	;pos
	move.l	a1,cmd_CopyDest(a4)	;Save for followup
	move.l	a2,cmd_CopyExtra(a4)

	IFD	DEBUGGEN
	DUMPMSG <calling filesys:FileSeek>
	ENDC
	moveq.l	#op_FILESEEK,d0
	lea.l	.FollowUp(pc),a1
	bsr	FireCmd		;Go!
.exit
	IFD	DEBUGGEN
	DUMPMSG <exitting FileSeek>
	ENDC
	movem.l	(sp)+,d1-d3/a0-a1/a3-a5
	rts

.FollowUp			;Can trash a0,a1,d0
	IFD	DEBUGGEN
	DUMPMSG <FileSeek:FollowUp>
	ENDC
	move.l	cmd_CopyDest(a4),d0
	beq.s	.avoid1
	IFD	DEBUGGEN
	DUMPMSG <FileSeek:preparing new position>
	ENDC
	move.l	d0,a0
	move.l	12(a3),D_high(a0)	;Return new position
	move.l	16(a3),D_low(a0)	;Return new position
.avoid1
	move.l	cmd_CopyExtra(a4),d0
	beq.s	.avoid2
	IFD	DEBUGGEN
	DUMPMSG <FileSeek:Preparing Old position>
	ENDC
	move.l	d0,a0
	move.l	20(a3),D_high(a0)	;Return old position
	move.l	24(a3),D_low(a0)	;Return old position
.avoid2
	move.b	3(a3),d0	;Get error
	IFD	DEBUGGEN
	DUMPMSG <FileSeek:replacing error>
	ENDC
	IFD	DEBUGGEN
	DUMPMSG <FileSeek: ending>
	ENDC
	rts

******* flyer.library/FlyerFileRead ******************************************
*
*   NAME
*	FlyerFileRead -- read from an open Flyer file
*
*   SYNOPSIS
*	error = FlyerFileRead(flyervolume,fileID,size,buffer,actual)
*	D0                    A0          D0     D1   A1     A2
*
*	ULONG FlyerFileRead(struct FlyerVolume *,ULONG,ULONG,UBYTE *,
*	        ULONG *);
*
*   FUNCTION
*
*   INPUTS
*	volume - pointer to same structure as passed to FlyerFileOpen
*
*	fileID - ID returned from FlyerFileOpen call
*
*	size - number of bytes to read
*
*	buffer - pointer to buffer to receive data
*
*	actual - pointer to variable to receive count of actual bytes read
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*
*   BUGS
*
*   SEE ALSO
*
*****************************************************************************
FileRead
	IFD	DEBUGGEN
	DUMPMSG <FileRead>
	ENDC
	movem.l	d1/d3/a0-a1/a3-a5,-(sp)

	bsr	Get_Vol_Cmd	;Get a free spot to place command
	bne.s	.exit		;Failed? Exit

	move.b	fv_SCSIdrive(a0),5(a3)		;SCSI drive

	move.l	d0,6(a3)	;file id

	bsr	AutoAllocSRAM	;Alloc SRAM needed (or as much as possible)
	tst.l	d0		;Failed?
	beq.s	.error
	move.l	d1,10(a3)	;size
	move.l	a1,cmd_CopyDest(a4)	;Save for later (caller's ptr)
	move.l	d0,cmd_CopySrc(a4)	;Ptr to SRAM area
	move.l	a2,cmd_CopyExtra(a4)	;&actual
	sub.l	unit_SRAMbase(a5),d0	;Turn into offset address
	move.l	d0,14(a3)		;Buffer to receive

	moveq.l	#op_FILEREAD,d0
	lea.l	.FollowUp(pc),a1
	bsr	FireCmd		;Go!
	bra.s	.exit
.error
	bsr	FreeCmdSlot		;Won't use cmd
	moveq.l	#FERR_LIBFAIL,d0
.exit
	movem.l	(sp)+,d1/d3/a0-a1/a3-a5
	rts

.FollowUp				;Can trash a0,a1,d0
	move.l	18(a3),d0		;Size of result in bytes
	move.l	cmd_CopyExtra(a4),a0
	cmp.w	#0,a0
	beq.s	.avoid
	move.l	d0,(a0)			;Return actual xfer
.avoid
	move.l	cmd_CopyDest(a4),a1	;User buffer (dest)
	move.l	cmd_CopySrc(a4),a0	;SRAM ptr    (src)
					;d0=len
	bsr	FastCopy		;Copy into user's buffer

	move.b	3(a3),d0	;Get error code
	rts

******* flyer.library/FlyerFileWrite ******************************************
*
*   NAME
*	FlyerFileWrite -- write to an open Flyer file
*
*   SYNOPSIS
*	error = FlyerFileWrite(flyervolume,fileID,size,buffer,actual)
*	D0                     A0          D0     D1   A1     A2
*
*	ULONG FlyerFileWrite(struct FlyerVolume *,ULONG,ULONG,UBYTE *,
*	        ULONG *);
*
*   FUNCTION
*
*   INPUTS
*	volume - pointer to same structure as passed to FlyerFileOpen
*
*	fileID - ID returned from FlyerFileOpen call
*
*	size - number of bytes to write
*
*	buffer - pointer to buffer which contains data
*
*	actual - pointer to variable to receive count of actual bytes written
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*
*   BUGS
*
*   SEE ALSO
*
*****************************************************************************
FileWrite
	IFD	DEBUGGEN
	DUMPMSG <FileWrite>
	ENDC
	movem.l	d1/d3/a0-a1/a3-a5,-(sp)

	DUMPMEM	<BUFFER:>,(A1),#32


	bsr	Get_Vol_Cmd	;Get a free spot to place command
	bne	.exit		;Failed? Exit

	move.b	fv_SCSIdrive(a0),5(a3)		;SCSI drive

	move.l	a2,cmd_CopyDest(a4)	;&actual (save for followup)
	move.l	d0,6(a3)	;fileID

	IFD	DEBUGGEN
	DUMPREG	<CALLING AutoAllocSRAM D1- Size desired>
	ENDC

	bsr	AutoAllocSRAM	;Alloc SRAM needed (or as much as possible)

	IFD	DEBUGGEN
	DUMPREG	<AFTER AutoAllocSRAM D1 - AMT ALLOC>
	ENDC
	;we will see... 

	tst.l	d0		;Failed?
	beq.s	.error
	move.l	d1,10(a3)	;size

	move.l	d0,-(sp)
	move.l	a1,a0		;user buffer (src)
	move.l	d0,a1		;SRAM ptr (dest)
	move.l	d1,d0		;len
	bsr		FastCopy	;Copy from user's buffer to SRAM
	move.l	(sp)+,d0	;Get SRAM ptr again

	sub.l	unit_SRAMbase(a5),d0	;Turn into offset address
	move.l	d0,14(a3)

	moveq.l	#op_FILEWRITE,d0
	lea.l	.FollowUp(pc),a1
	bsr	FireCmd		;Go!
	bra.s	.exit
.error
	bsr	FreeCmdSlot		;Won't use cmd
	moveq.l	#FERR_LIBFAIL,d0
.exit
	movem.l	(sp)+,d1/d3/a0-a1/a3-a5
	rts

.FollowUp				;Can trash a0,a1,d0
	move.l	18(a3),d0		;Size in bytes
	move.l	cmd_CopyDest(a4),a0
	cmp.w	#0,a0
	beq.s	.avoid
	move.l	d0,(a0)			;Return actual xfer
.avoid
	move.b	3(a3),d0	;Get error code
	rts


******* flyer.library/FlyerFileHSRead ******************************************
*
*   NAME
*	FlyerFileHSRead -- read blocks from an open Flyer file
*
*   SYNOPSIS
*	error = FlyerFileHSRead(flyervolume,fileID,startblk,blkcount,buffer)
*	D0                      A0          D0     D1       D2		 A1    
*
*	ULONG FlyerFileHSRead(struct FlyerVolume *,ULONG,ULONG,ULONG,UBYTE *);
*
*   FUNCTION
*
*   INPUTS
*	volume - pointer to same structure as passed to FlyerFileOpen
*
*	fileID - ID returned from FlyerFileOpen call
*
*	startblk - Block number to begin reading on
*	
*	blkcount - Number of blocks to read
*
*	buffer - pointer to buffer in amiga fastram
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*
*   BUGS
*
*   SEE ALSO
*
*****************************************************************************
FileHSRead:

	IFD	DEBUGBUG
	DUMPMSG <FileHSRead>
	ENDC
	movem.l	d1-d6/a0-a6,-(sp)

	bsr	Get_Vol_Cmd		;Get a free spot to place command
	bne	.exit			;Failed? Exit

	move.b	#0,FHSC_WFLAG(a3)	;0 Means we are reading the file.	
	move.b	fv_SCSIdrive(a0),FHSC_drive(a3)	
	move.l	d0,FHSC_fileid(a3)		
	move.l	d1,FHSC_Start_Blk(a3)	
	move.l	d2,FHSC_Blk_Count(a3)
	
	IFD	DEBUGBUG
	DUMPREG <GOT CMD SLOT>
	ENDC

	move.l	d2,d0	
	mulu	#512,d0
	add.l	#512,d0			;get extra block041797	
	move.l	d0,cmd_CopySize(a4)	
	move.l	#0,cmd_CopyExtra(a4)	

	IFD	DEBUGBUG
	DUMPREG <GOING TO ALLOCSRAM D0>
	ENDC

	bsr	AllocSRAM		;Alloc SRAM needed (or as much as possible)
	tst.l	d0			;Failed?
	beq	.error

	IFD	DEBUGBUG
	DUMPREG <GOT MEMORY D0>
	ENDC

	move.l	a1,cmd_CopyDest(a4)	;Save for later (caller's ptr)
	move.l	d0,cmd_CopySrc(a4)	;Ptr to SRAM area
	sub.l	unit_SRAMbase(a5),d0	;Turn into offset address

	add.l	#512,d0			;block align for dma
	and.l	#$FFFFFe00,d0
	move.l	d0,FHSC_buff(a3)

	move.l	#op_FILEHSWRITE,d0
	lea.l	.FollowUp(pc),a1

	IFD	DEBUGGEN
	DUMPREG	<ABOUT TO FIRE CMD D0-OPCODE, A1-FOLLOWUP>
	ENDC

	bsr	FireCmd			;Go!
	bra.s	.exit
.error
	bsr	FreeCmdSlot		;Won't use cmd
	moveq.l	#FERR_LIBFAIL,d0
.exit
	IFD	DEBUGGEN
	DUMPREG <RHS.exit>
	ENDC
	movem.l	(sp)+,d1-d6/a0-a6
	rts

.FollowUp				;Can trash a0,a1,d0
	move.l	cmd_CopySize(a4),d0	;Size of result in bytes
	sub.l	#512,d0			;dont copy the extra 512 bytes
	move.l	cmd_CopyDest(a4),a1	;User buffer (dest)
	move.l	cmd_CopySrc(a4),d1	;SRAM ptr    (src)
	add.l	#512,d1			;round to 512
	andi.l	#$FFFFFe00,d1
	move.l	d1,a0			;Source pointer for fastcopy	


;	IFD	DEBUGBUG
;	DUMPMEM	<BUFFER>,0(a0),#512
;	ENDC

;	IFD	DEBUGBUG
;	DUMPREG <COMPLETED READ IN FOLLOWUP>
;	ENDC
					;d0=len
	bsr	FastCopy		;Copy into user's buffer

;	IFD	DEBUGGEN
;	DUMPMEM	<User BUFFER>,0(a1),#512
;	ENDC

	move.b	3(a3),d0		;Get error code
	rts



******* flyer.library/FlyerFileHSWrite ******************************************
*
*   NAME
*	FlyerFileHSWrite -- write to an open Flyer file
*
*   SYNOPSIS
*	error = FlyerFileHSWrite(flyervolume,fileID,startblk,blkcount,buffer)
*	D0                       A0          D0     D1       D2       A1
*
*	ULONG FlyerFileHSWrite(struct FlyerVolume *,ULONG,ULONG,ULONG,UBYTE *);
*
*   FUNCTION
*
*   INPUTS
*	volume - pointer to same structure as passed to FlyerFileOpen
*
*	fileID - ID returned from FlyerFileOpen call
*
*	startblk - Block number to begin writing on
*	
*	blkcount - Number of blocks to write
*
*	buffer - pointer to buffer in amiga fastram
*
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*
*   BUGS
*
*   SEE ALSO
*
*****************************************************************************
FileHSWrite
	IFD	DEBUGGEN
	DUMPREG <FileHSWrite>
	ENDC
	movem.l	d1-d6/a0-a6,-(sp)
	move.l	a1,d5			;keep safe Buffer address.

	bsr	Get_Vol_Cmd		;Get a free spot to place command
	bne	.exit			;Failed? Exit

	move.b	#1,FHSC_WFLAG(a3)	;1 = writing to file.	
	move.b	fv_SCSIdrive(a0),FHSC_drive(a3)	
	move.l	d0,FHSC_fileid(a3)		
	move.l	d1,FHSC_Start_Blk(a3)	
	move.l	d2,FHSC_Blk_Count(a3)
	
	IFD	DEBUGGEN
	DUMPREG <GOT CMD SLOT>
	ENDC

	move.l	d2,d0	
	mulu	#512,d0	
	add.l	#512,d0
	move.l	d0,cmd_CopySize(a4)	
	move.l	#0,cmd_CopyExtra(a4)	

	IFD	DEBUGGEN
	DUMPREG <GOING TO ALLOCSRAM D0>
	ENDC

	bsr	AllocSRAM		;Alloc SRAM needed (or as much as possible)
	tst.l	d0			;Failed?
	beq	.error
	
	IFD	DEBUGGEN
	DUMPREG <GOT MEMORY D0>
	ENDC

	move.l	#0,cmd_CopyDest(a4)	;Save for later (caller's ptr)
	move.l	d0,cmd_CopySrc(a4)	;Ptr to SRAM area
	sub.l	unit_SRAMbase(a5),d0	;Turn into offset address

	add.l	#512,d0			;block align for dma
	and.l	#$FFFFFe00,d0
	move.l	d0,FHSC_buff(a3)

	IFD	DEBUGGEN
	DUMPREG <GOING TO FastCopy>
	ENDC
	move.l	a1,a0			;user buffer (src)
	move.l	cmd_CopySrc(a4),d1	;SRAM ptr (dest)

	add.l	#512,d1			;round to 512
	andi.l	#$FFFFFe00,d1
	move.l	d1,a1		

	move.l	d5,a0			;get users buffer address ready
	move.l	cmd_CopySize(a4),d0	;len
	sub.l	#512,d0
	bsr	FastCopy		;Copy from user's buffer to SRAM

	move.l	#op_FILEHSWRITE,d0
	lea.l	.FollowUp(pc),a1

	IFD	DEBUGGEN
	DUMPREG	<ABOUT TO FIRE CMD D0-OPCODE, A1-FOLLOWUP>
	ENDC

	bsr	FireCmd			;Go!
	bra.s	.exit
.error
	bsr	FreeCmdSlot		;Won't use cmd
	moveq.l	#FERR_LIBFAIL,d0
.exit
	movem.l	(sp)+,d1-d6/a0-a6
	rts

.FollowUp				;Can trash a0,a1,d0
	move.b	3(a3),d0		;Get error code
	rts


maxblocks	equ	80
******* flyer.library/FlyerNewFileRead ******************************************
*
*   NAME
*	FlyerNewFileRead -- read from an open Flyer file
*
*   SYNOPSIS
*	error = FlyerNewFileRead(flyervolume,fileID,size,buffer,actual)
*	D0                       A0          D0     D1   A1     A2
*
*	ULONG FlyerNewFileRead(struct FlyerVolume *,ULONG,ULONG,UBYTE *,
*	        ULONG *);
*
*   FUNCTION
*
*   INPUTS
*	volume - pointer to same structure as passed to FlyerFileOpen
*
*	fileID - ID returned from FlyerFileOpen call
*
*	size - number of bytes to read
*
*	buffer - pointer to buffer to receive data
*
*	actual - pointer to variable to receive count of actual bytes read
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*
*   BUGS
*
*   SEE ALSO
*
*****************************************************************************
    STRUCTURE 	NFR_WORK,0
	ULONG	IAMPARANOID
	APTR	NFR_volume
	ULONG	NFR_fileid
	ULONG	NFR_Afileid	
	ULONG	NFR_size	
	APTR	NFR_buffer	
	APTR	NFR_actual
	APTR	NFR_wbuffer
	APTR	NFR_FB
	ULONG	NFR_curpos
	ULONG	NFR_startblk
	ULONG	NFR_filelen
	ULONG	NFR_physlen
	ULONG	NFR_amtread
	ULONG	NFR_Endread
	LABEL	NFR_sizeof
	
NewFileRead
	IFD	DEBUGNEW
	DUMPREG <FileNewRead>
	ENDC

	IFEQ 0
	movem.l	d1-d7/a0-a6,-(sp)
	
	lea	-NFR_sizeof(sp),sp		
	move.l	sp,a4		
	
;Keep passed prarms
	move.l	a0,NFR_volume(a4)
	move.l	d0,NFR_fileid(a4)
	move.l	a6,NFR_FB(a4)



	add.l	#$2c0000,d0		;take out for simulation
	move.l	d0,NFR_Afileid(a4)
	move.l	d1,NFR_size(a4)
	move.l	a1,NFR_buffer(a4)
	move.l	a2,NFR_actual(a4)

* ALLOCATE TEMP BUFFER FOR PARTIAL BLOCKS
	move.l	4,a6
	move.l	#512,d0
	move.l	#MEMF_CLEAR!MEMF_PUBLIC,d1
	XSYS	AllocMem
	move.l	d0,NFR_wbuffer(a4)
	IFD	DEBUGNEW
	DUMPREG	<D0-WB>
	ENDC
	move.l	NFR_FB(a4),a6
	
	move.l	NFR_Afileid(a4),a0
	move.l	g_curpos(a0),NFR_curpos(a4) 		;keep these handy (but wastful!)
	move.l	g_startblk(a0),NFR_startblk(a4)
	move.l	g_filelen(a0),NFR_filelen(a4)
	move.l	g_physlen(a0),NFR_physlen(a4)
	move.l	#0,NFR_amtread(a4)

	move.l	NFR_filelen(a4),d0
	sub.l	NFR_curpos(a4),d0
	move.l	NFR_size(a4),d1
	cmp.l	d0,d1
	bls	.sizeOK

	move.l	d0,NFR_size(a4)

.sizeOK

	IFD	DEBUGNEW
	;DUMPMEM	<Magic number>,g_magic(a0),#16
	;DUMPMEM	<FileStart block>,g_startblk(a0),#16
	;DUMPMEM	<g_curpos>,g_curpos(a0),#16
	;DUMPMEM	<g_filelen>,NFR_filelen(a4),#16
	;DUMPMEM	<g_physlen>,NFR_physlen(a4),#16
	ENDC

;;Deal with reading any partial block	
;;check cur_pos for 0 or amt not divsable by 512
;;skip reading partial blocks	

	move.l	g_curpos(a0),d3
	move.l	d3,d4
	and.l	#$1FF,d3				
	bne	.NotOnB	
	
	cmp.l	#512,NFR_size(a4)
	bhs	.OnBlock

.NotOnB

		
;Read partial block into buffer and then move it.
.atstart

	IFD	DEBUGNEW
	DUMPREG	<PARTIAL BLOCK>
	ENDC

	divu	#512,d4
	swap	d4					;clear out remainder
	clr.w	d4
	swap	d4

	IFD	DEBUGNEW
	DUMPREG	<BLOCK - D4>
	ENDC

	move.l	NFR_startblk(a4),d1
	add.l	d4,d1			;add in block offset
	moveq	#1,d2			;number to read.
	move.l	NFR_volume(a4),a0	
	move.l	NFR_fileid(a4),d0	
	move.l	NFR_wbuffer(a4),a1	

	IFD	DEBUGNEW
	DUMPREG	<R_B>
	ENDC

	bsr	FileHSRead	
		
	move.l	#512,d0
	sub.l	d3,d0
;is this more then ask for?
	move.l	NFR_size(a4),d1
	cmp.l	d0,d1
	bhs.s	.copymost
	move.l	NFR_size(a4),d0
.copymost
	add.l	d0,NFR_amtread(a4)
	sub.l	d0,NFR_size(a4)
	add.l	d0,NFR_curpos(a4)
	move.l	NFR_wbuffer(a4),a0
	move.l	NFR_buffer(a4),a1
	add.l	d3,a0
	add.l	d0,NFR_buffer(a4)	;inc buffer pos
	
	IFD	DEBUGNEW
	;DUMPMEM	<NFR_buffer(a4)>,NFR_buffer(a4),#16
	;DUMPMEM	<NFR_amtread(a4)>,NFR_amtread(a4),#16
	;DUMPMEM	<NFR_size(a4)>,NFR_size(a4),#16
	;DUMPMEM	<NFR_curpos(a4)>,NFR_curpos(a4),#16
	DUMPREG	<-FastCopy>
	ENDC	

	bsr	FastCopy	;from(a0),to(a1),len(d0)

	;move.l	NFR_buffer(a4),a0
	;DUMPMEM	<BUFFER>,(A0),#16 

;check for completion
	move.l	NFR_size(a4),d0
	beq	.done


.OnBlock
	cmp.l	#512,NFR_size(a4)
	blo	.DoEndPartal

	
;read Complete blocks in groups on optimal size
;;Optimal size may be 32768 or 64 blocks
;Now deal with complete blocks

	move.l	NFR_size(a4),d0
	move.l	d0,d1			;get and keep last partal block amt
	and.l	#$1FF,d1
	move.l	d1,NFR_Endread(a4)				
	bsr	_Bytes2Blocks
	tst.l	d1
	beq	.NoEndPartRead
	sub.l	#1,d0			;if end part read then reporting 1 too
.NoEndPartRead
	move.l	d0,d4
	move.l	NFR_curpos(a4),d0
	bsr	_Bytes2Blocks
	move.l	NFR_startblk(a4),d3
	add.l	d0,d3			;add in block offset

	move.l	d4,d0
	bsr	_Blocks2Bytes
	add.l	d0,NFR_curpos(a4)
	sub.l	d0,NFR_size(a4)
	add.l 	d0,NFR_amtread(a4)	

	move.l	d4,d5

.blockloop
	cmp.l	#maxblocks,d4
	ble	.lessthenmax	
	move.l	#maxblocks,d5			;need to just byteoff 64 for now
	bra.s	.morethenmax
.lessthenmax
	move.l	d4,d5			;read however many we have.
.morethenmax
	move.l	d5,d0			;calc how much to inc buffer by. 
	bsr	_Blocks2Bytes
	move.l	d0,d6	

	move.l	d3,d1
	move.l	d5,d2			;number to read. fix at 1 for now
	move.l	NFR_volume(a4),a0	
	move.l	NFR_fileid(a4),d0	
	move.l	NFR_buffer(a4),a1	
	IFD	DEBUGNEW
	DUMPREG	<R_B>
	ENDC
	bsr	FileHSRead
	add.l	d6,NFR_buffer(a4)
	add.l	d5,d3			;inc block #		
	sub.l	d5,d4
	bne	.blockloop	
.DoEndPartal
	move.l	NFR_Endread(a4),d1	
	beq	.done
	
	move.l	NFR_curpos(a4),d0
	bsr	_Bytes2Blocks

	move.l	NFR_startblk(a4),d1
	add.l	d0,d1			;add offset to 
	moveq	#1,d2			;number to read.
	move.l	NFR_volume(a4),a0	
	move.l	NFR_fileid(a4),d0	
	move.l	NFR_wbuffer(a4),a1

	IFD	DEBUGNEW
	DUMPREG	<R_B>
	ENDC	

	bsr	FileHSRead		
	
	move.l	NFR_wbuffer(a4),a0
	move.l	NFR_buffer(a4),a1
	move.l	NFR_size(a4),d0
	add.l	d0,NFR_curpos(a4)
	add.l	d0,NFR_amtread(a4)
	sub.l	d0,NFR_size(a4)
	IFD	DEBUGNEW
	DUMPREG	<-FastCopy>
	ENDC
	bsr	FastCopy		;from(a0),to(a1),len(d0)
.done

;;;if amt left to read is smaller then this check for size not ending on 
;;;block boundry 
;;;;if ends on block boundry then can skip dealing with partial end block.
;Deal with reading any partal block

	tst.l	NFR_wbuffer(a4)
	beq.s	.skp_free
	move.l	4,a6
	move.l	NFR_wbuffer(a4),a1
	move.l	#512,d0	
	XSYS	FreeMem
	move.l	NFR_FB(a4),a6
.skp_free

*update file grip position	
*setup returns 	
	move.l	NFR_Afileid(a4),a0	
	move.l	NFR_curpos(a4),g_curpos(a0)

	move.l	NFR_actual(a4),a0	;return actual amt read
	move.l	NFR_amtread(a4),(a0)	

	lea	NFR_sizeof(sp),sp
	move.l	#0,d0
	movem.l	(sp)+,d1-d7/a0-a6
	ENDC

	rts



**********************************************
*
* Convert Byte count to Block count 32bit ver.
*
**********************************************
_Bytes2Blocks	;d0 = bytes,d0 = blocks
	move.l	d1,-(sp)
	moveq	#0,d1
	add.l	#511,d0
	moveq	#9-1,d1
.div512
	lsr.l	#1,d0
	dbf	d1,.div512
	move.l	(sp)+,d1
	rts


**********************************************
*
* Convert Block count to byte count 32bit ver.
*
**********************************************
_Blocks2Bytes
	;d0 = blocks, d0 = bytes
	move.l	d1,-(sp)
	moveq	#9-1,d1
.mult512
	asl.l	#1,d0		;Bytes.x = blocks.l * 512
	dbf	d1,.mult512
	move.l	(sp)+,d1
	rts



******* flyer.library/FlyerNewFileWrite ******************************************
*
*   NAME
*	FlyerNewFileWrite -- write to an open Flyer file
*
*   SYNOPSIS
*	error = FlyerFileHSWrite(flyervolume,fileID,size,buffer,actual)
*	D0                       A0          D0     D1   A1     A2
*
*	ULONG FlyerNewFileWrite(struct FlyerVolume *,ULONG,ULONG,UBYTE *,
*	        ULONG *);
*
*   FUNCTION
*
*   INPUTS
*	volume - pointer to same structure as passed to FlyerFileOpen
*
*	fileID - ID returned from FlyerFileOpen call
*
*	size - number of bytes to write
*
*	buffer - pointer to buffer which contains data
*
*	actual - pointer to variable to receive count of actual bytes written
*
*   RESULT
*	actual 	- passed in a2 is address to return actual amt written.
*	error	- error code is returned in d0.	
*
*   EXAMPLE
*
*   NOTES
*
*	more error conditions can be incountered here
*	
*	FERR_FULL,'Drive full'
*	FERR_CANTEXTEND,'Cannot extend file'
*
*  maybe but, scsi problems are real trouble and file shouldn't open for 
*    write if drive/file protected.
*	FERR_PROTECTED,'Drive write-protected'
*	FERR_INCOMPLETE,'SCSI tranfer not completed fully'
*	FERR_WRITEPROT,'File write-protected'
*	FERR_INUSE,'Disk/object in use'
*
*  REALLY should just check for errors when writing to file!
*
*   BUGS
*
*   SEE ALSO
*
*****************************************************************************
    STRUCTURE 	NFW_WORK,0
	APTR	NFW_volume
	ULONG	NFW_fileid
	ULONG	NFW_Afileid	
	ULONG	NFW_size	
	APTR	NFW_buffer	
	APTR	NFW_actual
	APTR	NFW_wbuffer
	APTR	NFW_FB
	ULONG	NFW_curpos
	ULONG	NFW_startblk
	ULONG	NFW_filelen
	ULONG	NFW_physlen
	ULONG	NFW_amtwritten
	ULONG	NFW_Endwrite
	LABEL	NFW_sizeof
NewFileWrite:
	movem.l	d0-d7/a0-a6,-(sp)
	IFD	DEBUGNEW
	DUMPREG <FileNewWrite>
	ENDC
	
	lea	-NFW_sizeof(sp),sp		
	move.l	sp,a4		
	
;Keep passed prarms
	move.l	a0,NFW_volume(a4)
	move.l	d0,NFW_fileid(a4)
	move.l	#0,NFW_amtwritten(a4)		;init

	add.l	#$2c0000,d0			;comment out for simulation
	move.l	d0,NFW_Afileid(a4)
	move.l	d1,NFW_size(a4)
	move.l	a1,NFW_buffer(a4)
	move.l	a2,NFW_actual(a4)
	move.l	a6,NFW_FB(a4)
	
* ALLOCATE TEMP BUFFER FOR PARTIAL BLOCKS
	move.l	4,a6
	move.l	#512,d0
	move.l	#MEMF_PUBLIC,d1
	XSYS	AllocMem
	move.l	d0,NFW_wbuffer(a4)
	move.l	NFW_FB(a4),a6			;restore flyer base to base reg.

	move.l	NFW_Afileid(a4),a0
	move.l	g_curpos(a0),NFW_curpos(a4) 	;keep these handy (but wastful!)
	move.l	g_startblk(a0),NFW_startblk(a4)
	move.l	g_filelen(a0),NFW_filelen(a4)
	move.l	g_physlen(a0),NFW_physlen(a4)

;is file open for write?
;if file needs to be extended, do so now.
;  if error on file extend, error out on write with 0 bytes written.

	
	move.l	NFW_curpos(a4),d0		;see how long its going to be.
	add.l	NFW_size(a4),d0			
		
	move.l	NFW_filelen(a4),d1
	cmp.l	d0,d1
		
	bhs	.notextend
	
	sub.l	NFW_filelen(a4),d0		;see how much to expand file by
	move.l	d0,d1
	move.l	NFW_volume(a4),a0
	move.l	NFW_fileid(a4),d0
	bsr	FileExtend	
	tst.l	d0				;could file be expaneded?
	bne	.ExtendError
.notextend

;check for partial block, else skip partial block
	move.l	NFW_curpos(a4),d3
	move.l	d3,d4

	and.l	#$1FF,d3
	bne	.NotOnBB	
			
	cmp.l	#512,NFW_size(a4)
	bhs	.OnBlock

.NotOnBB
;	DUMPREG <Not on BB>
	move.l	d4,d0
	bsr	_Bytes2Blocks	
	move.l	d0,d4
	tst.l	d4
	beq	.arzero
	sub.l	#1,d4			;cant be 0? unless at start of file.
.arzero		
	move.l	NFW_startblk(a4),d1
	add.l	d4,d1			;add in block offset
	moveq	#1,d2			;number to read.
	move.l	NFW_volume(a4),a0	
	move.l	NFW_fileid(a4),d0	
	move.l	NFW_wbuffer(a4),a1	

	DUMPREG	<ABOUT TO READ BLOCK>

	bsr	FileHSRead	
	
	move.l	#512,d0
	sub.l	d3,d0
;is this more than we were writing?
	move.l	NFW_size(a4),d1
	cmp.l	d0,d1
	bhs.s	.copymost
	move.l	NFW_size(a4),d0
.copymost
	add.l	d0,NFW_amtwritten(a4)
	sub.l	d0,NFW_size(a4)
	add.l	d0,NFW_curpos(a4)
	move.l	NFW_buffer(a4),a0
	move.l	NFW_wbuffer(a4),a1
	add.l	d3,a1			;offset to start in partal block
	add.l	d0,NFW_buffer(a4)	;inc buffer pos

;	DUMPREG <CALLING FAST COPY1>		
	bsr	FastCopy
	
;Now write it back to disk!
;	DUMPMSG	<ABOUT TO WRITE IT BACK TO DISK>
	
	move.l	NFW_startblk(a4),d1
	add.l	d4,d1                
	move.l	NFW_volume(a4),a0	
	move.l	NFW_fileid(a4),d0	
	move.l	NFW_wbuffer(a4),a1	
	moveq	#1,d2	             
;	DUMPREG <WRITEING BACK TO DISK1>
	bsr	FileHSWrite

	move.l	NFW_size(a4),NFW_Endwrite(a4)	;HOW MUCH MORE?		
	move.l	NFW_size(a4),d0
	beq	.done	
.OnBlock		
	cmp.l	#512,NFW_size(a4)
	blo	.DoEndPartal

	move.l	NFW_size(a4),d0
	move.l	d0,d1			;get and keep last partal block amt
	and.l	#$1FF,d1
	move.l	d1,NFW_Endwrite(a4)				
	bsr	_Bytes2Blocks
	tst.l	d1
	beq	.NoEndPartRead
	sub.l	#1,d0			;if end part read then reporting 1 too
.NoEndPartRead
	move.l	d0,d4
	move.l	NFW_curpos(a4),d0
	bsr	_Bytes2Blocks
	move.l	NFW_startblk(a4),d3
	add.l	d0,d3			;add in block offset

	move.l	d4,d0
	bsr	_Blocks2Bytes
	add.l	d0,NFW_curpos(a4)
	sub.l	d0,NFW_size(a4)
	add.l 	d0,NFW_amtwritten(a4)	

	move.l	d4,d5

.blockloop
;	DUMPREG <.blockwriteloop>	
	cmp.l	#maxblocks,d4
	ble	.lessthenmax	
	move.l	#maxblocks,d5			;need to just byteoff 64 for now
	bra.s	.morethenmax
.lessthenmax
	move.l	d4,d5			;read however many we have.
.morethenmax
	move.l	d5,d0			;calc how much to inc buffer by. 
	bsr	_Blocks2Bytes
	move.l	d0,d6	

	move.l	d3,d1 
	move.l	d5,d2			;number to write 
	move.l	NFW_volume(a4),a0	
	move.l	NFW_fileid(a4),d0	
	move.l	NFW_buffer(a4),a1	
	bsr	FileHSWrite
	add.l	d6,NFW_buffer(a4)
	add.l	d5,d3			;inc block #		
	sub.l	d5,d4
	bne	.blockloop	

.DoEndPartal

	move.l	NFW_Endwrite(a4),d1	
	beq	.done
	
	move.l	NFW_curpos(a4),d0
	bsr	_Bytes2Blocks

;	DUMPREG <doingendpartal>
	move.l	NFW_startblk(a4),d1
	add.l	d0,d1			;add offset to 
	move.l	d1,d6			;keep blk number for writeback!
	moveq	#1,d2			;number to read.
	move.l	NFW_volume(a4),a0	
	move.l	NFW_fileid(a4),d0	
	move.l	NFW_wbuffer(a4),a1
;	DUMPREG <ABOUT TO READ FILE2>
	bsr	FileHSRead		
	
	move.l	NFW_buffer(a4),a0
	move.l	NFW_wbuffer(a4),a1
	move.l	NFW_size(a4),d0
	add.l	d0,NFW_curpos(a4)
	add.l	d0,NFW_amtwritten(a4)
	sub.l	d0,NFW_size(a4)
;	DUMPREG <ABOUT TO FAST COPY2>
	bsr	FastCopy		;from(a0),to(a1),len(d0)

;Now write it back out to disk!
	
	move.l	d6,d1
	move.l	NFW_volume(a4),a0	
	move.l	NFW_fileid(a4),d0	
	move.l	NFW_wbuffer(a4),a1	
	moveq	#1,d2	       
;	DUMPREG <ABOUT TO WRIT3>      
	bsr	FileHSWrite
.done
;	DUMPMSG	<ABOUT TO FREE BUFFER>

	tst.l	NFW_wbuffer(a4)
	beq.s	.skp_free
	move.l	4,a6
	move.l	NFW_wbuffer(a4),a1
	move.l	#512,d0	
	XSYS	FreeMem
	move.l	NFW_FB(a4),a6 		;restore flyer base to base reg.
.skp_free

;	DUMPREG	<AFTER FREE>
*update file grip position	
*setup returns 	

	move.l	NFW_Afileid(a4),a0	
	move.l	NFW_curpos(a4),g_curpos(a0)

	move.l	NFW_actual(a4),a0	;return actual amt written
	move.l	NFW_amtwritten(a4),(a0)	 
	move.l	(a0),d0	
;	DUMPREG <Actual amt copyed in d0>
	lea	NFW_sizeof(sp),sp
	move.l	#0,(sp)

	movem.l	(sp)+,d0-d7/a0-a6
	rts


.ExtendError
;	DUMPREG	<EXTEND ERROR>
	move.l	d0,d7
	tst.l	NFW_wbuffer(a4)
	beq.s	.skp_free2
	move.l	4,a6
	move.l	NFW_wbuffer(a4),a1
	move.l	#512,d0	
	XSYS	FreeMem
	move.l	NFW_FB(a4),a6 		;restore flyer base to base reg.
.skp_free2
	move.l	NFW_actual(a4),a0	;return actual amt written
	move.l	#0,(a0)
	lea	NFW_sizeof(sp),sp
	move.l	d7,(sp)			;return error
	movem.l	(sp)+,d0-d7/a0-a6
	rts
	



******* flyer.library/FlyerRename ******************************************
*
*   NAME
*	FlyerRename -- rename a file/dir on a Flyer drive
*
*   SYNOPSIS
*	error = FlyerRename(oldclip,newgrip,newname)
*	D0                  A0      D0      A1
*
*	ULONG FlyerRename(struct ClipAction *,ULONG,char *);
*
*   FUNCTION
*
*   INPUTS
*	oldclip - specifies the path/name of the file to rename
*
*	newgrip - base grip to which 'newname' is relative
*
*	newname - new path/name for file (relative to 'newgrip')
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*
*   BUGS
*
*   SEE ALSO
*
*****************************************************************************
Rename
	IFD	DEBUGGEN
	DUMPMSG <Rename>
	ENDC
	movem.l	d1/a0-a1/a3-a5,-(sp)

	move.l	a0,-(sp)
	move.l	ca_Volume(a0),a0	;Get volume structure
	cmp.w	#0,a0
	beq.s	.error_a0
	bsr	Get_Vol_Cmd		;Get a free spot to place command
	move.l	(sp)+,a0
	bne.s	.exit			;Failed? Exit

	move.b	ca_ReturnTime(a0),cmd_RetTime(a4)	;User's return time

	move.l	d0,8(a3)		;new grip

	bsr	MeasureString		;d0=len of new name
	bsr	MakeEven		;Round up if needed to make even
	move.l	d0,d1			;keep for later
					;d0=Extra room for "new" string
	bsr	PassClipAction		;Copy ClipAction and all others
	tst.l	d0
	beq.s	.error			;Failed?

	movem.l	a0/d0,-(sp)
	move.l	a1,a0			;Ptr to new name string
	move.l	d0,a1			;Ptr to SRAM to hold new name string
	move.l	d1,d0			;Length of new name
	bsr	FastCopy		;Copy to SRAM
	movem.l	(sp)+,a0/d0

	sub.l	unit_SRAMbase(a5),d0
	move.l	d0,12(a3)		;Offset to new name
	add.l	d1,d0			;
	move.l	d0,4(a3)		;SRAM offset addr of structure(s)

	moveq.l	#op_RENAME,d0		;Get opcode
	lea.l	CopyBackAction(pc),a1	;Copyback when done (id = 0)
	bsr	FireAction		;Go!
	bra.s	.exit

.error_a0
	move.l	(sp)+,a0
.error
	bsr	FreeCmdSlot		;Won't use cmd
	moveq.l	#FERR_LIBFAIL,d0
.exit
	movem.l	(sp)+,d1/a0-a1/a3-a5
	rts


******* flyer.library/FlyerRenameDisk ******************************************
*
*   NAME
*	FlyerRenameDisk -- rename a Flyer drive volume
*
*   SYNOPSIS
*	error = FlyerRenameDisk(flyervolume,newname)
*	D0                      A0          A1
*
*	ULONG FlyerRenameDisk(struct FlyerVolume *,char *);
*
*   FUNCTION
*
*   INPUTS
*	volume - pointer to structure which specifies drive
*
*	newname - pointer to new name string for volume
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*
*   BUGS
*
*   SEE ALSO
*
*****************************************************************************
RenameDisk
	IFD	DEBUGGEN
	DUMPMSG <RenDisk>
	ENDC
	movem.l	a0-a1/a3-a5,-(sp)

	bsr	Get_Vol_Cmd		;Get a free spot to place command
	bne.s	.exit			;Failed? Exit

	move.b	fv_SCSIdrive(a0),5(a3)		;SCSI drive

	bsr	MeasureString	;d0=len of new name
				;a1=src ptr
				;d0=size
	bsr	CopytoSRAM	;Copy name to SRAM
	bne.s	.exit		;Failed? Exit

	move.l	d0,6(a3)

	moveq.l	#op_RENAMEDISK,d0	;Get opcode
	lea.l	StdFollowUp(pc),a1
	bsr	FireCmd			;Go!
.exit
	movem.l	(sp)+,a0-a1/a3-a5
	rts


******* flyer.library/FlyerFormat ******************************************
*
*   NAME
*	FlyerFormat - High-level format a drive with the Flyer's filesystem
*
*   SYNOPSIS
*	error = FlyerFormat(volume,name,datestamp,blocks,flags)
*	D0                  A0     A1   A2        D0     D1
*
*	ULONG FlyerFormat(struct FlyerVolume *,char *,struct DateStamp *,
*	        ULONG,UBYTE);
*
*   FUNCTION
*	This function does a high-level format on a drive connected to the
*	Flyer.  Not all sectors are read/write tested, so this is a "quick"
*	format.  The format procedure normally uses the entire drive, but
*	this can be reduced to avoid using slower parts of the drive.
*
*   INPUTS
*	volume - NULL string, specifies drive to format
*
*	name - pointer to a null-terminated string to use for the volume name
*
*	datestamp - pointer to an AmigaDOS DateStamp structure to use as the
*	   drive's creation date
*
*	blocks - NULL for entire drive, or the number of sectors to use for
*	   video data.  WARNING!  This does not actually prohibit the
*	   Flyer from using the remaining space, but gives a cutoff
*	   point beyond which no video clips may be placed.  Non time-
*	   critical data may eventually be placed in this "slow" region.
*
*	flags - FVIF_xxx flags to request to be applied to this drive
*	   (specifically FVIF_VIDEOREADY and FVIF_AUDIOREADY).  FlyerFormat
*	   will test the speed of the drive and clear the video flag if it
*	   does not find it capable.  This allows drives to be targeted
*	   as data only, data/audio, or data/audio/video.
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*	Do not use an fv_Path string to specify the drive.  Specify a NULL
*	string and specify the exact drive specifically with fv_SCSIdrive.
*	This will prevent formatting the wrong drive if two exist with
*	identical volume names!
*
*   BUGS
*
*   SEE ALSO
*	flyer.h
*
*****************************************************************************
Format
	IFD	DEBUGGEN
	DUMPMSG <Format!>
	ENDC
	movem.l	a0-a1/a3-a5,-(sp)

	bsr	Get_Vol_Cmd	;Get a free spot to place command
	bne	.exit		;Failed? Exit

	IFD	DEBUGSKELL
	DUMPSTR	0(a1)
	DUMPMSG	< - Volume to format>
	ENDC

	move.b	fv_SCSIdrive(a0),5(a3)		;SCSI drive
	move.l	d0,22(a3)	;Blocks to format
	move.b	d1,26(a3)	;Flags for formatting

	bsr	MeasureString
				;a1=src ptr
				;d0=size
	bsr	CopytoSRAM	;Copy name to SRAM
	bne.s	.exit		;Failed? Exit

	move.l	d0,6(a3)
	move.l	(a2),10(a3)	;Copy days
	move.l	4(a2),14(a3)	;Copy minutes
	move.l	8(a2),18(a3)	;Copy ticks

	moveq.l	#op_FORMAT,d0
	lea.l	StdFollowUp(pc),a1
	bsr	FireCmd		;Go!
.exit
	movem.l	(sp)+,a0-a1/a3-a5
	rts


******* flyer.library/FlyerDeFragNew ******************************************
*
*   NAME
*	FlyerDeFragNew -- De-fragment hard drive (extra features)
*
*   SYNOPSIS
*	error = FlyerDeFragNew(clipaction)
*	D0                     A0
*
*	ULONG FlyerDeFragNew(struct ClipAction *);
*
*   FUNCTION
*	Begins defragmentation process on specified drive.  This is identical to
*	FlyerDeFrag function, except that this one uses a ClipAction structure
*	to specifies the Flyer drive.  This allows some enhanced things during
*	defragmentation, such as the ability to be run asynchronously, ability
*	to be aborted, and the ability for the application to obtain status
*	while it's occurring.
*
*   INPUTS
*	clipaction - specifies the drive using an attached FlyerVolume structure
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*
*   BUGS
*
*   SEE ALSO
*	FlyerDeFrag
*
*****************************************************************************
DeFragNew
	IFD	DEBUGGEN
	DUMPMSG <DeFragNew>
	ENDC
	movem.l	a0-a1/a3-a5,-(sp)

	move.l	a0,a1			;Move action here

	move.l	ca_Volume(a1),a0	;Get src FlyerVolume (really don't want action)
	cmp.w	#0,a0
	beq.s	.error
					;a0=Volume structure
	bsr	Get_Vol_Cmd		;Get a free spot to place command
	bne.s	.exit			;Failed? Exit

	move.b	ca_ReturnTime(a1),cmd_RetTime(a4)	;User's return time
	move.b	#1,2(a3)		;Continue flag = TRUE

	move.b	fv_SCSIdrive(a0),5(a3)		;SCSI drive

	moveq.l	#op_DEFRAG,d0
	move.l	a1,a0			;ClipAction ptr
	lea.l	StdFollowUp(pc),a1
	bsr	FireAction		;Go!
	bra.s	.exit
.error
	moveq.l	#FERR_LIBFAIL,d0
.exit
	movem.l	(sp)+,a0-a1/a3-a5
	rts

******* flyer.library/FlyerDeFrag ******************************************
*
*   NAME
*	FlyerDeFrag - De-fragment hard drive
*
*   SYNOPSIS
*	error = FlyerDeFrag(volume)
*	D0                  A0
*
*	ULONG FlyerDeFrag(struct FlyerVolume *);
*
*   FUNCTION
*	Begins defragmentation process on specified drive.
*
*   INPUTS
*	volume - pointer to structure which describes the volume to defrag
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*	Currently accepts no parameters and cannot be interrupted
*
*   BUGS
*	Reports of bugs.  Unable to reproduce to date...
*
*   SEE ALSO
*	FlyerDeFragNew
*
*****************************************************************************
DeFrag
	IFD	DEBUGGEN
	DUMPMSG <Defrag>
	ENDC
	movem.l	a0-a1/a3-a5,-(sp)

	bsr	Get_Vol_Cmd	;Get a free spot to place command
	bne.s	.exit		;Failed? Exit

	move.b	#1,2(a3)	;Continue flag = TRUE

	move.b	fv_SCSIdrive(a0),5(a3)		;SCSI drive

	moveq.l	#op_DEFRAG,d0
	lea.l	StdFollowUp(pc),a1
	bsr	FireCmd		;Go!
.exit
	movem.l	(sp)+,a0-a1/a3-a5
	rts

******* flyer.library/FlyerSetBits ******************************************
*
*   NAME
*	FlyerSetBits -- set protect bits for dir/file
*
*   SYNOPSIS
*	error = FlyerSetBits(flyervolume,grip,bits)
*	D0                   A0          D0   D1
*
*	ULONG FlyerSetBits(struct FlyerVolume *,ULONG,ULONG);
*
*   FUNCTION
*
*   INPUTS
*	volume - pointer to structure which specifies drive/path/name of file
*
*	grip - grip of file/dir
*
*	bits - new bits (32)
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*
*   BUGS
*
*   SEE ALSO
*
*****************************************************************************
SetBits
	IFD	DEBUGGEN
	DUMPMSG <SetBits>
	ENDC
	movem.l	a0-a1/a3-a5,-(sp)

	bsr	Get_Vol_Cmd	;Get a free spot to place command
	bne.s	.exit		;Failed? Exit

	move.b	fv_SCSIdrive(a0),5(a3)		;SCSI drive

	move.l	d0,6(a3)	;grip
	move.l	d1,10(a3)	;bits

	moveq.l	#op_SETBITS,d0
	lea.l	StdFollowUp(pc),a1
	bsr	FireCmd		;Go!
.exit
	movem.l	(sp)+,a0-a1/a3-a5
	rts

******* flyer.library/FlyerSetDate ******************************************
*
*   NAME
*	FlyerSetDate -- set date for file/dir
*
*   SYNOPSIS
*	error = FlyerSetDate(flyervolume,grip,days,minutes,ticks)
*	D0                   A0          D0   D1   D2      D3
*
*	ULONG FlyerSetDate(struct FlyerVolume *,ULONG,ULONG,ULONG,ULONG);
*
*   FUNCTION
*
*   INPUTS
*	volume - pointer to structure which specifies drive/path/name of file
*
*	grip - grip of file/dir
*
*	days - date: days
*
*	minutes - date: minutes
*
*	ticks - date: ticks
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*
*   BUGS
*
*   SEE ALSO
*
*****************************************************************************
SetDate
	IFD	DEBUGGEN
	DUMPMSG <SetDate>
	ENDC
	movem.l	a0-a1/a3-a5,-(sp)

	bsr	Get_Vol_Cmd	;Get a free spot to place command
	bne.s	.exit		;Failed? Exit

	move.b	fv_SCSIdrive(a0),5(a3)		;SCSI drive

	move.l	d0,6(a3)	;grip
	move.l	d1,10(a3)	;days
	move.l	d2,14(a3)	;mins
	move.l	d3,18(a3)	;ticks

	moveq.l	#op_SETDATE,d0
	lea.l	StdFollowUp(pc),a1
	bsr	FireCmd		;Go!
.exit
	movem.l	(sp)+,a0-a1/a3-a5
	rts

******* flyer.library/FlyerSetComment ******************************************
*
*   NAME
*	FlyerSetComment -- set comment for dir/file
*
*   SYNOPSIS
*	error = FlyerSetComment(flyervolume,grip,comment)
*	D0                      A0          D0   A1
*
*	ULONG FlyerSetComment(struct FlyerVolume *,ULONG,char *);
*
*   FUNCTION
*
*   INPUTS
*	volume - pointer to structure which specifies drive/path/name of file
*
*	grip - grip of file/dir
*
*	comment - new comment string
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*
*   BUGS
*
*   SEE ALSO
*
*****************************************************************************
SetComment
	IFD	DEBUGGEN
	DUMPMSG <SetCmt>
	ENDC
	movem.l	a0-a1/a3-a5,-(sp)

	bsr	Get_Vol_Cmd	;Get a free spot to place command
	bne.s	.exit		;Failed? Exit

	move.b	fv_SCSIdrive(a0),5(a3)		;SCSI drive

	move.l	d0,6(a3)	;grip

	bsr	MeasureString	;Measure comment string
				;a1=src ptr
				;d0=size
	bsr	CopytoSRAM	;Copy name to SRAM
	bne.s	.exit		;Failed? Exit

	move.l	d0,10(a3)

	moveq.l	#op_SETCOMMENT,d0
	lea.l	StdFollowUp(pc),a1
	bsr	FireCmd		;Go!
.exit
	movem.l	(sp)+,a0-a1/a3-a5
	rts


*****i* flyer.library/FlyerWriteProt ******************************************
*
*   NAME
*	FlyerWriteProt -- set/test write protect status of drive
*
*   SYNOPSIS
*	error = FlyerWriteProt(flyervolume,setval,setflag,checkvalptr)
*	D0                     A0          D0     D1      A1
*
*	ULONG FlyerWriteProt(struct FlyerVolume *,UBYTE,UBYTE,UBYTE *);
*
*   FUNCTION
*	This function can be used to test or set the write-protect status of
*	a Flyer drive.  The drive is specified using a volume name or
*	SCSIdrive value in the volume structure.
*
*	A state of 0 means "write-enabled", 1 means "write-protected"
*
*   INPUTS
*	volume - pointer to structure which specifies drive and path/name of
*	         file
*
*	setval - value to use (if 'setflag' is true)
*
*	setflag - 0=test state, 1=set state (to 'setval')
*
*	checkvalptr - pointer to variable to receive protect state if just
*	              testing
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*
*   BUGS
*
*   SEE ALSO
*
*****************************************************************************
WriteProt
	IFD	DEBUGGEN
	DUMPMSG <WriteProt>
	ENDC
	movem.l	a0-a1/a3-a5,-(sp)

	bsr	Get_Vol_Cmd	;Get a free spot to place command
	bne.s	.exit		;Failed? Exit

	move.b	fv_SCSIdrive(a0),5(a3)		;SCSI drive

	move.b	d0,6(a3)	;value
	move.b	d1,7(a3)	;setflag
	move.l	a1,cmd_CopyDest(a4)	;Save for followup

	moveq.l	#op_WRITEPROT,d0
	lea.l	.FollowUp(pc),a1
	bsr	FireCmd		;Go!
.exit
	movem.l	(sp)+,a0-a1/a3-a5
	rts

.FollowUp			;Can trash a0,a1,d0
	move.l	cmd_CopyDest(a4),d0
	beq.s	.avoid
	move.l	d0,a0
	move.b	6(a3),d0
	move.b	d0,(a0)		;Return new value
.avoid
	move.b	3(a3),d0	;Get error
	rts


*****i* flyer.library/FlyerChangeMode ******************************************
*
*   NAME
*	FlyerChangeMode -- change access mode of grip object
*
*   SYNOPSIS
*	error = FlyerChangeMode(flyervolume,grip,access)
*	D0                      A0          D0   D1
*
*	ULONG FlyerChangeMode(struct FlyerVolume *,ULONG,UBYTE);
*
*   FUNCTION
*
*   INPUTS
*	volume - pointer to structure which specifies drive and path/name
*	         of file
*
*	grip - grip of file/dir
*
*	access - new access mode
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*
*   BUGS
*
*   SEE ALSO
*
*****************************************************************************
ChangeMode
	IFD	DEBUGGEN
	DUMPMSG <ChgMode>
	ENDC
	movem.l	a0-a1/a3-a5,-(sp)

	bsr	Get_Vol_Cmd	;Get a free spot to place command
	bne.s	.exit		;Failed? Exit

	move.b	fv_SCSIdrive(a0),5(a3)		;SCSI drive

	move.l	d0,6(a3)	;grip
	move.b	d1,10(a3)	;access

	moveq.l	#op_CHANGEMODE,d0
	lea.l	StdFollowUp(pc),a1
	bsr	FireCmd		;Go!
.exit
	movem.l	(sp)+,a0-a1/a3-a5
	rts


******* flyer.library/GetFieldClock ******************************************
*
*   NAME
*	GetFieldClock - Retrieve the Flyer's field counter
*
*   SYNOPSIS
*	error = GetFieldClock(clockptr)
*	D0                    A0
*
*	ULONG GetFieldClock(ULONG *);
*
*   FUNCTION
*	This returns the Flyer's internal field counter by plugging it into
*	the provided pointer to a ULONG.  If more than one Flyer exists, they
*	are automatically sync'd together by the flyer.library.  Therefore,
*	no board number or volume name is required for this function.
*
*   INPUTS
*	clockptr - pointer to ULONG to receive the clock value
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*
*   BUGS
*
*   SEE ALSO
*
*****************************************************************************
GetFieldClock
	IFD	DEBUGGEN
	DUMPMSG <GetFldClock>
	ENDC
	movem.l	a0-a1/a3-a5,-(sp)

	moveq.l	#0,d0		;For now, hard code to 1st Flyer
	bsr	Get_Brd_Cmd	;Get a free spot to place command
	bne.s	.exit		;Failed? Exit

	move.b	#1,2(a3)	;Continue flag TRUE
	move.l	a0,cmd_CopyDest(a4)
	moveq.l	#op_GETCLOCK,d0
	lea.l	.FollowUp(pc),a1
	bsr	FireCmd		;Go!
.exit
	movem.l	(sp)+,a0-a1/a3-a5
	rts

.FollowUp			;Can trash a0,a1,d0
	move.l	cmd_CopyDest(a4),d0
	beq.s	.avoid
	move.l	d0,a0
	move.l	4(a3),(a0)	;Return frame/field clock
.avoid
	move.b	3(a3),d0	;Get error code
	rts

*********************************************************************
* FrameSyncFetch -- Grab frame clock from Flyer
*
* Entry:
*	d0:ID (returned from FrameSyncStart)
*
* Exit:
*	d0:Flyer Frame Clock
*********************************************************************
;FrameSyncFetch
;	movem.l	a3-a4,-(sp)
;	bsr	IDtoA3A4	;Check for bogus ID, retrieve ptrs
;	bne.s	.exit
;	move.l	4(a3),d0	;Get frame count
;.exit
;	movem.l	(sp)+,a3-a4
;	rts


*****i* flyer.library/DebugMode ******************************************
*
*   NAME
*	DebugMode -- Set Flyer Debug modes
*
*   SYNOPSIS
*	error = DebugMode(board,flags)
*	D0                D0    D1
*
*	ULONG DebugMode(UBYTE,ULONG);
*
*   FUNCTION
*
*   INPUTS
*	board - specifies the Flyer board (0-3)
*
*	flags - new debugging flags (32)
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*
*   BUGS
*
*   SEE ALSO
*
*****************************************************************************
DebugMode
	IFD	DEBUGGEN
	DUMPMSG <DebugMode>
	ENDC
	movem.l	a0-a1/a3-a5,-(sp)
	bsr	Get_Brd_Cmd	;Get a free spot to place command
	bne.s	.exit		;Failed? Exit

	move.l	d1,4(a3)	;Debug flags (32)

	moveq.l	#op_DEBUGFLAGS,d0
	lea.l	StdFollowUp(pc),a1
	bsr	FireCmd		;Go!
.exit
	movem.l	(sp)+,a0-a1/a3-a5
	rts

*****i* flyer.library/FlyerOptions ******************************************
*
*   NAME
*	FlyerOptions -- Get/Set Flyer option flags
*
*   SYNOPSIS
*	error = FlyerOptions(board,setflag,options)
*	D0                   D0    D1      A0
*
*	ULONG FlyerOptions(UBYTE,UBYTE,ULONG *);
*
*   FUNCTION
*
*   INPUTS
*	board - specifies the Flyer board (0-3)
*
*	setflag - 0=read flags, 1=set flags
*
*	options - pointer to variable which contains options flags (for
*	          both testing and setting)
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*
*   BUGS
*
*   SEE ALSO
*
*****************************************************************************
FlyerOptions
	IFD	DEBUGGEN
	DUMPMSG <Options>
	ENDC
	movem.l	a0-a1/a3-a5,-(sp)
	bsr	Get_Brd_Cmd	;Get a free spot to place command
	bne.s	.exit		;Failed? Exit

	move.l	(a0),4(a3)	;Option flags (32)
	move.b	d1,8(a3)	;"set" flag

	move.l	a0,cmd_CopyDest(a4)	;Save this for wrap-up time

	moveq.l	#op_GETSETOPT,d0
	lea.l	.FollowUp(pc),a1
	bsr	FireCmd		;Go!
.exit
	movem.l	(sp)+,a0-a1/a3-a5
	rts

.FollowUp			;Can trash a0,a1,d0
	move.l	cmd_CopyDest(a4),a0
	move.l	4(a3),(a0)	;Return updated flags

	move.b	3(a3),d0	;Get error code
	rts


*****i* flyer.library/CacheTest ******************************************
*
*   NAME
*	CacheTest -- Test CPU caching of Flyer shared RAM
*
*   SYNOPSIS
*	error = CacheTest(board)
*	D0                D0
*
*	ULONG CacheTest(UBYTE);
*
*   FUNCTION
*
*   INPUTS
*	board - specifies the Flyer board (0-3)
*
*   RESULT
*	FERR_OKAY if alright, FERR_CMDFAILED if CPU is caching
*
*   EXAMPLE
*
*   NOTES
*
*   BUGS
*
*   SEE ALSO
*
*****************************************************************************
CacheTest
;	IFD	DEBUGGEN
	IFD	DEBUGCACHE
	DUMPMSG <CacheTest>
	ENDC
	movem.l	d1-d2/a0-a1/a2-a6,-(sp)

	move.l	a6,a2			;Keep FlyerBase in a2

	bsr	Get_Brd_Cmd		;Get a free spot to place command
	bne	cache_exit		;Failed? Exit

	btst	#FUB_RUNNING,unit_PrivFlags(a5)	;Not running?
	beq	cache_exit		;If Flyer not alive, cannot perform test

	move.l	fl_SysLib(a6),a6	;Get ExecBase

;Allow no other tasks or interrupts.  This ensures that I can test the
;cache without the possibility of it being hit or flushed by other code
	DISABLE

	move.b	#1,2(a3)		;Set "continue" flag

	move.w	#op_CACHETEST!STAT_NEW,(a3)	;Start Flyer side of test


.wait1	XSYS	CacheClearU		;Flush data cache so (a3) below is not stale
	move.w	(a3),d0
	and.w	#STATMASK,d0		;Check status bits in opcode
	cmp.w	#STAT_INPROG,d0		;Test running yet?
	bne.s	.wait1

	XSYS	CacheClearU		;Flush data cache!

;We'll test long at 28(a3), since this will fall into a different cache line than
;opcode and continue at 0(a3) thru 2(a3) -- this keeps the two areas from stomping
;on each other in the cache, which would invalidate our test

;;;	move.l	28(a3),d0		;Read first value (may or may not get cached)

	move.l	#$DEADD00D,d0
	move.l	d0,28(a3)		;Write my own value here first

	move.b	#0,2(a3)		;Clear "continue" flag (does not do a read!)
	move.w	#200,d1			;Timeout value

.test	move.l	28(a3),d2		;Read value back (comes from cache or memory)
	cmp.l	#$12345678,d2		;Got fresh value without a flush?
	beq	.nocache		;If so, no caching is enabled here
	dbf	d1,.test		;Test for a bit longer
.yescache
	IFD	DEBUGCACHE
	DUMPHEXI.L <First value = >,d0,<\>
	DUMPHEXI.L <value = >,d2,<\>
	DUMPMSG <Uhoh -- cache bug!>
	ENDC
	bset	#FLB_CACHED,fl_PrivFlags(a2)	;Will have to take special measures
	moveq.l	#FERR_CMDFAILED,d0
	bra	.end
.nocache
	IFD	DEBUGCACHE
	DUMPHEXI.L <First value = >,d0,<\>
	DUMPHEXI.L <value = >,d2,<\>
	DUMPMSG <Cache is okay>
	ENDC
	bclr	#FLB_CACHED,fl_PrivFlags(a2)	;No special de-cache code needed
	moveq.l	#FERR_OKAY,d0

.end	move.l	d0,-(sp)		;Save result

.wait2	XSYS	CacheClearU		;Flush data cache so (a3) below is not stale
	move.w	(a3),d0
	and.w	#STATMASK,d0		;Check status bits in opcode
	cmp.w	#STAT_DONE,d0		;Done?
	bne.s	.wait2

	move.w	#0,(a3)			;Clear opcode to make slot free!

	ENABLE				;Allow everybody else to run again

	move.l	(sp)+,d0		;Get result

cache_exit
	movem.l	(sp)+,d1-d2/a0-a1/a2-a6
	rts


*****i* flyer.library/SetPlayMode ******************************************
*
*   NAME
*	SetPlayMode -- Put Flyer in playback mode
*
*   SYNOPSIS
*	error = SetPlayMode(board)
*	D0                  D0
*
*	ULONG SetPlayMode(UBYTE);
*
*   FUNCTION
*
*   INPUTS
*	board - specifies the Flyer board (0-3)
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*
*   BUGS
*
*   SEE ALSO
*
*****************************************************************************
SetPlayMode
	IFD	DEBUGGEN
	DUMPMSG <SetPlayMode>
	ENDC
	movem.l	d1/a0-a1/a3-a5,-(sp)
	moveq.l	#op_PLAYMODE,d1
	lea.l	.FollowUp(pc),a1
	bra	ModeMerge

.FollowUp			;Can trash a0,a1,d0
	move.b	3(a3),d0	;Get error code
	bne.s	.nochange
	move.b	#CURMODE_PLAY,unit_Mode(a5)	;In PLAY mode
.nochange
	rts

*****i* flyer.library/SetRecMode ******************************************
*
*   NAME
*	SetRecMode -- Put Flyer in record mode
*
*   SYNOPSIS
*	error = SetRecMode(board)
*	D0                 D0
*
*	ULONG SetRecMode(UBYTE);
*
*   FUNCTION
*
*   INPUTS
*	board - specifies the Flyer board (0-3)
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*
*   BUGS
*
*   SEE ALSO
*
*****************************************************************************
SetRecMode
	IFD	DEBUGGEN
	DUMPMSG <SetRecMode>
	ENDC
	movem.l	d1/a0-a1/a3-a5,-(sp)
	moveq.l	#op_RECMODE,d1
	lea.l	.FollowUp(pc),a1
	bra	ModeMerge

.FollowUp			;Can trash a0,a1,d0
	move.b	3(a3),d0	;Get error code
	bne.s	.nochange
	move.b	#CURMODE_REC,unit_Mode(a5)	;In RECORD mode
.nochange
	rts

*****i* flyer.library/SetNoMode ******************************************
*
*   NAME
*	SetNoMode -- Put Flyer in no play/record mode
*
*   SYNOPSIS
*	error = SetNoMode(board)
*	D0                D0
*
*	ULONG SetNoMode(UBYTE);
*
*   FUNCTION
*
*   INPUTS
*	board - specifies the Flyer board (0-3)
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*
*   BUGS
*
*   SEE ALSO
*
*****************************************************************************
SetNoMode
	IFD	DEBUGGEN
	DUMPMSG <SetNoMode>
	ENDC
	movem.l	d1/a0-a1/a3-a5,-(sp)
	moveq.l	#op_NOMODE,d1
	lea.l	.FollowUp(pc),a1
	bra	ModeMerge

.FollowUp			;Can trash a0,a1,d0
	move.b	3(a3),d0	;Get error code
	bne.s	.nochange
	move.b	#CURMODE_NONE,unit_Mode(a5)	;In NONE mode
.nochange
	rts

ModeMerge
	bsr	Get_Brd_Cmd		;Get a free spot to place command
	bne.s	.exit			;Failed? Exit

	move.w	d1,d0			;Opcode
					;(a1 contains follow-up address)
	bsr	FireCmd			;Go!
.exit
	movem.l	(sp)+,d1/a0-a1/a3-a5
	rts


******* flyer.library/ToasterMux ******************************************
*
*   NAME
*	ToasterMux - Set Flyer/Toaster multiplex switches
*
*   SYNOPSIS
*	error = ToasterMux(board,input3,input4,preview)
*	D0                 D0    D1     D2     D3
*
*	ULONG ToasterMux(UBYTE,UBYTE,UBYTE,UBYTE);
*
*   FUNCTION
*	Controls how the Flyer interacts with the Toaster's inputs 3 and 4
*	and preview output.
*
*   INPUTS
*	board - specifies the Flyer board (0-3)
*
*	input3 - video source fed to switcher input 3
*	   0 = Toaster input 3
*	   1 = Flyer video output (channel 0)
*
*	input4 - video source fed to switcher input 4
*	   0 = Toaster input 4
*	   1 = Flyer video output (channel 1)
*
*	preview - video fed to preview output
*	   0 = Toaster preview bus
*	   1 = Flyer camcorder input
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*
*   BUGS
*
*   SEE ALSO
*	FlyerInputSel
*	FlyerTermination
*
*****************************************************************************
ToasterMux
	IFD	DEBUGGEN
	DUMPMSG <ToasterMux>
	ENDC
	movem.l	a0-a1/a3-a5,-(sp)

	bsr	Get_Brd_Cmd	;Get a free spot to place command
	bne.s	.exit		;Failed? Exit

	move.b	d1,4(a3)	;input3
	move.b	d2,5(a3)	;input4
	move.b	d3,6(a3)	;preview

	moveq.l	#op_TOASTMUX,d0
	lea.l	StdFollowUp(pc),a1
	bsr	FireCmd		;Go!
.exit
	movem.l	(sp)+,a0-a1/a3-a5
	rts


******* flyer.library/FlyerInputSel ******************************************
*
*   NAME
*	FlyerInputSel - Select Flyer video input sources
*
*   SYNOPSIS
*	error = FlyerInputSel(board,video,sync)
*	D0                    D0    D1    D2
*
*	ULONG FlyerInputSel(UBYTE,UBYTE,UBYTE);
*
*   FUNCTION
*	Specifies what video channel to use for recording to the Flyer and
*	where to get sync.
*
*   INPUTS
*	board - specifies the Flyer board (0-3)
*
*	video - video source to record
*	   FI_Camcorder   = Flyer camcorder input (TBC required)
*	   FI_SVHS        = Flyer SVHS input (TBC required)
*	   FI_Toaster1    = Toaster input 1
*	   FI_Toaster2    = Toaster input 2
*	   FI_ToasterMain = Toaster Main bus output
*	   FI_ToasterPV   = Toaster Preview bus output
*
*	sync - video source to use as a reference
*	   FS_ToasterMain = Toaster Main output
*	   FS_Toaster1    = Toaster input 1
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*	Any changes to video or sync source using this command should be
*	given sufficient time to "settle" before beginning to record.
*
*   BUGS
*
*   SEE ALSO
*	FlyerTermination
*	ToasterMux
*
*****************************************************************************
InputSelect
	IFD	DEBUGGEN
	DUMPMSG <InputSel>
	ENDC
	movem.l	a0-a1/a3-a5,-(sp)

	bsr	Get_Brd_Cmd	;Get a free spot to place command
	bne.s	.exit		;Failed? Exit

	move.b	d1,4(a3)	;source
	move.b	d2,5(a3)	;sync

	moveq.l	#op_INPUTSEL,d0
	lea.l	StdFollowUp(pc),a1
	bsr	FireCmd		;Go!
.exit
	movem.l	(sp)+,a0-a1/a3-a5
	rts


******* flyer.library/FlyerTermination ******************************************
*
*   NAME
*	FlyerTermination - Set Flyer's video termination on/off
*
*   SYNOPSIS
*	error = FlyerTermination(board,flags)
*	D0                       D0    D1
*
*	ULONG FlyerTermination(UBYTE,UBYTE);
*
*   FUNCTION
*	Specifies which of the Flyer's 4 video terminators to turn on.
*
*   INPUTS
*	board - specifies the Flyer board (0-3)
*
*	flags - One flag for each of 4 terminators (0=off, 1=on)
*	   Bit 0 = Toaster Input 1 terminator
*	   Bit 1 = Toaster Input 3 terminator
*	   Bit 2 = Toaster Input 4 terminator
*	   Bit 3 = Toaster Main terminator
*
*	   Power-up default is Inputs 3 & 4 terminated, Main and Input 1 not
*	   terminated.
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*
*   BUGS
*
*   SEE ALSO
*	FlyerInputSel
*	ToasterMux
*
*****************************************************************************
Termination
	IFD	DEBUGGEN
	DUMPMSG <Termination>
	ENDC
	movem.l	a0-a1/a3-a5,-(sp)

	bsr	Get_Brd_Cmd	;Get a free spot to place command
	bne.s	.exit		;Failed? Exit

	move.b	d1,4(a3)	;bits

	moveq.l	#op_TERMINATE,d0
	lea.l	StdFollowUp(pc),a1
	bsr	FireCmd		;Go!
.exit
	movem.l	(sp)+,a0-a1/a3-a5
	rts


******* flyer.library/FlyerWriteCalib ******************************************
*
*   NAME
*	FlyerWriteCalib - Manually set Flyer's calibration registers
*
*   SYNOPSIS
*	error = FlyerWriteCalib(board,item,value,saveflag)
*	D0                      D0    D1   D2    D3
*
*	ULONG FlyerWriteCalib(UBYTE,UWORD,WORD,UBYTE);
*
*   FUNCTION
*	Sets the value of one of the calibration registers.  See flyer.h for
*	the "item" values (CALIB_xxxx).  Starting with the Rev 4 board, these
*	values are kept in non-volatile memory on-board the Flyer.  To also
*	save the specified value to memory, set the "saveflag" argument.
*
*   INPUTS
*	board - specifies the Flyer board (0-3)
*
*	item - which register to change (see flyer.h)
*
*	value - item-specific value
*
*	saveflag - 0=just use value, 1=also save to non-volatile memory
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*
*   BUGS
*
*   SEE ALSO
*	FlyerReadCalib
*
*****************************************************************************
WriteCalib
	IFD	DEBUGGEN
	DUMPMSG <WriteCalib>
	ENDC
	movem.l	a0-a1/a3-a5,-(sp)
	bsr	Get_Brd_Cmd	;Get a free spot to place command
	bne.s	.exit		;Failed? Exit

	move.w	d1,4(a3)	;Item #
	move.w	d2,6(a3)	;Value
	move.b	d3,8(a3)	;Save/use flag

	moveq.l	#op_WRITECALIB,d0
	lea.l	StdFollowUp(pc),a1
	bsr	FireCmd		;Go!
.exit
	movem.l	(sp)+,a0-a1/a3-a5
	rts


******* flyer.library/FlyerReadCalib ******************************************
*
*   NAME
*	FlyerReadCalib - Inspect the Flyer's calibration registers
*
*   SYNOPSIS
*	error = FlyerReadCalib(board,item,valueptr)
*	D0                     D0    D1   A0
*
*	ULONG FlyerReadCalib(UBYTE,UWORD,WORD *);
*
*   FUNCTION
*	Reads the specified Flyer calibration register.  See flyer.h for
*	the "item" values (CALIB_xxxx).  Value placed at pointer "valueptr".
*
*   INPUTS
*	board - specifies the Flyer board (0-3)
*
*	item - which register to change (see flyer.h)
*
*	valueptr - pointer to a UWORD to fill in with the value
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*
*   BUGS
*
*   SEE ALSO
*	FlyerWriteCalib
*
*****************************************************************************
ReadCalib
	IFD	DEBUGGEN
	DUMPMSG <ReadCalib>
	ENDC
	movem.l	a0-a1/a3-a5,-(sp)
	bsr	Get_Brd_Cmd	;Get a free spot to place command
	bne.s	.exit		;Failed? Exit

	move.w	d1,4(a3)	;Item #

	move.l	a0,cmd_CopyDest(a4)

	moveq.l	#op_READCALIB,d0
	lea.l	.FollowUp(pc),a1
	bsr	FireCmd		;Go!
.exit
	movem.l	(sp)+,a0-a1/a3-a5
	rts

.FollowUp				;Can trash a0,a1,d0
	move.l	cmd_CopyDest(a4),d0	;Get storage address
	beq.s	.avoid
	move.l	d0,a0
	move.w	6(a3),(a0)		;Send value back to caller
.avoid
	move.b	3(a3),d0	;Get error code
	rts


*****i* flyer.library/WriteEEreg ******************************************
*
*   NAME
*	WriteEEreg -- Write into Flyer's EEPROM
*
*   SYNOPSIS
*	error = WriteEEreg(board,addr,data)
*	D0                 D0    D1   D2
*
*	ULONG WriteEEreg(UBYTE,UBYTE,UWORD);
*
*   FUNCTION
*
*   INPUTS
*	board - specifies the Flyer board (0-3)
*
*	addr - address in EEPROM (0 - 63)
*
*	data - data word to write
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*
*   BUGS
*
*   SEE ALSO
*
*****************************************************************************
WriteEE
	IFD	DEBUGGEN
	DUMPMSG <WriteEE>
	ENDC
	movem.l	a0-a1/a3-a5,-(sp)
	bsr	Get_Brd_Cmd	;Get a free spot to place command
	bne.s	.exit		;Failed? Exit

	move.b	d1,4(a3)	;Addr (0-F)
	move.w	d2,6(a3)	;Data

	moveq.l	#op_EEWRITE,d0
	lea.l	StdFollowUp(pc),a1
	bsr	FireCmd		;Go!
.exit
	movem.l	(sp)+,a0-a1/a3-a5
	rts


*****i* flyer.library/ReadEEreg ******************************************
*
*   NAME
*	ReadEEreg -- Read from Flyer's EEPROM
*
*   SYNOPSIS
*	error = ReadEEreg(board,addr,dataptr)
*	D0                D0    D1   A0
*
*	ULONG ReadEEreg(UBYTE,UBYTE,UWORD *);
*
*   FUNCTION
*
*   INPUTS
*	board - specifies the Flyer board (0-3)
*
*	addr - address in EEPROM (0 - 63)
*
*	dataptr - pointer to variable to receive data word read from EEPROM
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*
*   BUGS
*
*   SEE ALSO
*
*****************************************************************************
ReadEE
	IFD	DEBUGGEN
	DUMPMSG <ReadEE>
	ENDC
	movem.l	a0-a1/a3-a5,-(sp)
	bsr	Get_Brd_Cmd	;Get a free spot to place command
	bne.s	.exit		;Failed? Exit

	move.b	d1,4(a3)	;Addr

	move.l	a0,cmd_CopyDest(a4)

	moveq.l	#op_EEREAD,d0
	lea.l	.FollowUp(pc),a1
	bsr	FireCmd		;Go!
.exit
	movem.l	(sp)+,a0-a1/a3-a5
	rts

.FollowUp				;Can trash a0,a1,d0
	move.l	cmd_CopyDest(a4),d0	;Get storage address
	beq.s	.avoid
	move.l	d0,a0
	move.w	6(a3),(a0)		;Send data back to caller
.avoid
	move.b	3(a3),d0	;Get error code
	rts


******* flyer.library/ReadTest ******************************************
*
*   NAME
*	ReadTest -- Do a read speed test on a Flyer SCSI drive
*
*   SYNOPSIS
*	error = ReadTest(flyervolume,blocks,repeat,lba,dblflag)
*	D0               A0          D0     D1     D2  D3
*
*	ULONG ReadTest(struct FlyerVolume *,ULONG,ULONG,ULONG,UBYTE);
*
*   FUNCTION
*
*   INPUTS
*	volume - pointer to structure which specifies drive
*
*	blocks - size of each transfer (in blocks)
*
*	repeat - number of transfers to perform
*
*	lba - starting lba on drive
*
*	dblflag - 0=simple test, 1=double-buffered test
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*
*   BUGS
*
*   SEE ALSO
*
*****************************************************************************
ReadTest
	IFD	DEBUGGEN
	DUMPMSG <ReadTest>
	ENDC
	movem.l	a0-a1/a3-a5,-(sp)

	bsr	Get_Vol_Cmd	;Get a free spot to place command
	bne.s	.exit		;Failed? Exit

	move.b	fv_SCSIdrive(a0),5(a3)		;SCSI drive

	move.l	d2,6(a3)	;lba
	move.l	d0,10(a3)	;Size of read
	move.l	d1,14(a3)	;repeat
	move.b	d3,18(a3)	;dblbuf flag
	moveq.l	#op_READTEST,d0
	lea.l	StdFollowUp(pc),a1
	bsr	FireCmd		;Go!
.exit
	movem.l	(sp)+,a0-a1/a3-a5
	rts


******* flyer.library/WriteTest ******************************************
*
*   NAME
*	WriteTest -- Do a write speed test on a Flyer SCSI drive
*
*   SYNOPSIS
*	error = WriteTest(flyervolume,blocks,repeat,lba,dblflag)
*	D0                A0          D0     D1     D2  D3
*
*	ULONG WriteTest(struct FlyerVolume *,ULONG,ULONG,ULONG,UBYTE);
*
*   FUNCTION
*
*   INPUTS
*	volume - pointer to structure which specifies drive
*
*	blocks - size of each transfer (in blocks)
*
*	repeat - number of transfers to perform
*
*	lba - starting lba on drive
*
*	dblflag - 0=simple test, 1=double-buffered test
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*
*   BUGS
*
*   SEE ALSO
*
*****************************************************************************
WriteTest
	IFD	DEBUGGEN
	DUMPMSG <WriteTest>
	ENDC
	movem.l	a0-a1/a3-a5,-(sp)

	bsr	Get_Vol_Cmd	;Get a free spot to place command
	bne.s	.exit		;Failed? Exit

	move.b	fv_SCSIdrive(a0),5(a3)		;SCSI drive

	move.l	d2,6(a3)	;lba
	move.l	d0,10(a3)	;Size of read
	move.l	d1,14(a3)	;repeat
	move.b	d3,18(a3)	;dblbuf flag
	moveq.l	#op_WRITETEST,d0
	lea.l	StdFollowUp(pc),a1
	bsr	FireCmd		;Go!
.exit
	movem.l	(sp)+,a0-a1/a3-a5
	rts


******* flyer.library/SetFlooby ******************************************
*
*   NAME
*	SetFlooby - used to set various Flyer internal values
*
*   SYNOPSIS
*	error = SetFlooby(board,chan,item,value)
*	D0                D0    D1   D2   D3
*
*	ULONG SetFlooby(UBYTE,UBYTE,UBYTE,ULONG);
*
*   FUNCTION
*	Selectively changes Flyer internal parameters by specifying the
*	parameter number and its new value.
*
*   INPUTS
*	board - specifies the Flyer board (0-3)
*
*	chan - video channel (0 or 1)
*
*	item - the parameter number to change
*
*	value - the value to assign to the parameter
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*	All parameters are currently private.
*	Name derived from the term "FloobyDust"
*
*   BUGS
*
*   SEE ALSO
*
*****************************************************************************
SetFlooby
	IFD	DEBUGGEN
	DUMPMSG <SetFlooby>
	ENDC
	movem.l	a0-a1/a3-a5,-(sp)

	bsr	Get_Brd_Cmd	;Get a free spot to place command
	bne.s	.exit		;Failed? Exit

	move.b	d1,4(a3)	;channel
	move.b	d2,5(a3)	;item
	move.l	d3,6(a3)	;value
	moveq.l	#op_FLOOBY,d0
	lea.l	StdFollowUp(pc),a1
	bsr	FireCmd		;Go!
.exit
	movem.l	(sp)+,a0-a1/a3-a5
	rts


******* flyer.library/FlyerQuit ******************************************
*
*   NAME
*	FlyerQuit -- Stop Flyer execution, return to boot ROM
*
*   SYNOPSIS
*	error = FlyerQuit(board)
*	D0           D0
*
*	ULONG FlyerQuit(UBYTE);
*
*   FUNCTION
*
*   INPUTS
*	board - specifies the Flyer board (0-3)
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*
*   BUGS
*
*   SEE ALSO
*
*****************************************************************************
QuitFlyer
	IFD	DEBUGGEN
	DUMPMSG <Quit!>
	ENDC
	movem.l	a0-a1/a3-a5,-(sp)
	bsr	Get_Brd_Cmd	;Get a free spot to place command
	bne.s	.exit		;Failed? Exit

;This might be useful for sync'ing to Flyer reboot into ROM
;	move.l	unit_SRAMbase(a5),a0
;	move.l	#CMDBASE+(MAX_FLYER_CMDS*FLYER_CMD_LEN),d1
;	add.l	d1,a0
;	move.w	$7777,(a0)		;Put marker in SRAM

	moveq.l	#op_QUIT,d0
	lea.l	.FollowUp(pc),a1
	bsr	FireCmd		;Go!
.exit
	movem.l	(sp)+,a0-a1/a3-a5
	rts

.FollowUp				;Can trash a0,a1,d0
	move.b	#CURMODE_UNKNOWN,unit_Mode(a5)	;Forget what mode we think
	bclr	#FUB_RUNNING,unit_PrivFlags(a5)	;Not running anymore
	bclr	#FUB_SETUP,unit_PrivFlags(a5)	;Not setup
	move.b	3(a3),d0	;Get error code
	rts



******* flyer.library/PlayMode ******************************************
*
*   NAME
*	PlayMode - Ready Flyer for playback
*
*   SYNOPSIS
*	error = PlayMode(board)
*	D0               D0
*
*	ULONG PlayMode(UBYTE);
*
*   FUNCTION
*	Readies the Flyer for playback.  This takes about 1/2 second.
*
*	Return value indicates success (0) or the error code on failure
*
*   INPUTS
*	board - specifies the Flyer board (0-3)
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*	You must currently ensure that no playing or recording is occurring
*	before calling this function
*
*   BUGS
*
*   SEE ALSO
*
*****************************************************************************
PlayMode
	IFD	DEBUGGEN
	DUMPMSG <PlayMode>
	ENDC
	movem.l	d1-d4/a0-a2/a5,-(sp)

;	bsr	EnsureVolume		;If NULL, use my default
;
;	bsr	FindVolume		;Convert volume to brd/chan/drv
;	bne	.exit			;Failed? Exit
;
;	move.b	fv_Board(a0),d0		;Board #

;;;	bsr	HideFlyer		;Change Switcher to hide Flyer outputs

	bsr	GetCardUnit		;in a5
	bne	.exit			;Failed? Exit

	cmp.b	#CURMODE_PLAY,unit_Mode(a5)	;Already in PLAY mode?
	beq	.success

	moveq.l	#0,d0			;Flyer board
	bsr	SetNoMode

;	/* Select Output Mode */
;	SBusWrite(UNIT | FLYER_SYNC,0x43,0x0D);

;	moveq.l	#0,d0		;Flyer #0
;	moveq.l	#0,d1		;Coefs 0
;	lea.l	IFIR050(pc),a0
;	bsr	FIRcoef
;	tst.l	d0
;	bne	.exit

;;	moveq.l	#0,d0		;Flyer #0
;;	moveq.l	#1,d1		;Coefs 1
;;	lea.l	IFIR050(pc),a0
;;	bsr	FIRcoef
;;	tst.l	d0
;;	bne	.exit

*** Set P-decoders' clock
	move.l	fl_Pdecode(a6),a1	;Get P-decoder definition data
	cmp.w	#0,a1			;Not taught yet?
	beq	.error
	moveq.l	#0,d0		;Flyer #0
	moveq.l	#3,d1		;Clock 3 (P coder)
	move.l	fch_speed(a1),d2	;P clock speed
	beq.s	.noclock1
	bsr	SetClockGen	;Do it
.noclock1

*** Program both P-decoders
	moveq.l	#0,d0			;Flyer board
	move.l	fch_length(a1),d2	;Size of binary
	moveq.l	#3,d1			;Chip #
	move.b	fch_chiprev(a1),d3	;Revision
	move.b	#1,d4			;Dual (chips 3 and 4)
	lea.l	FlyerChipHdr_Sizeof(a1),a0
	bsr	IntFPGA
	tst.l	d0
	bne	.exit

*** Set M-decoders' clock
	move.l	fl_Mdecode(a6),a1	;Get M-decoder definition data
	cmp.w	#0,a1			;Not taught yet?
	beq	.error
	moveq.l	#0,d0		;Flyer #0
	moveq.l	#2,d1		;Clock 2 (M coder)
	move.l	fch_speed(a1),d2	;M clock speed
	beq.s	.noclock2
	bsr	SetClockGen	;Do it
.noclock2

*** Program both M-decoders
	moveq.l	#0,d0			;Flyer board
	move.l	fch_length(a1),d2	;Size of binary
	moveq.l	#5,d1			;Chip #
	move.b	fch_chiprev(a1),d3	;Revision
	move.b	#1,d4			;Dual (chips 5 and 6)
	lea.l	FlyerChipHdr_Sizeof(a1),a0
	bsr	IntFPGA
	tst.l	d0
	bne	.exit

	moveq.l	#0,d0			;Flyer board
	bsr	SetPlayMode

.success
	moveq.l	#FERR_OKAY,d0
	bra.s	.exit

.error					;Not used!
	bsr	FreeJustCmdSlot		;Won't use cmd
	moveq.l	#FERR_LIBFAIL,d0
.exit
;;;	bsr	RestoreFlyer		;Restore Switcher to previous state

	movem.l	(sp)+,d1-d4/a0-a2/a5
	rts


******* flyer.library/RecordMode ******************************************
*
*   NAME
*	RecordMode - Ready Flyer for recording
*
*   SYNOPSIS
*	error = RecordMode(board)
*	D0                 D0
*
*	ULONG RecordMode(UBYTE);
*
*   FUNCTION
*	Readies the Flyer for recording.  This takes about 1/2 second.
*
*	Return value indicates success (0) or the error code on failure
*
*   INPUTS
*	board - specifies the Flyer board (0-3)
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*	You must currently ensure that no playing or recording is occurring
*	before calling this function
*
*   BUGS
*
*   SEE ALSO
*
*****************************************************************************
RecordMode
	IFD	DEBUGGEN
	DUMPMSG <RecordMode>
	ENDC
	movem.l	d1-d4/a0-a2/a5,-(sp)

;	bsr	EnsureVolume		;If NULL, use my default
;
;	bsr	FindVolume		;Convert volume to brd/chan/drv
;	bne	.exit			;Failed? Exit
;
;	move.b	fv_Board(a0),d0		;Board #

;;;	bsr	HideFlyer		;Change Switcher to hide Flyer outputs

	bsr	GetCardUnit		;in a5
	bne	.exit			;Failed? Exit

	cmp.b	#CURMODE_REC,unit_Mode(a5)	;Already in REC mode?
	beq	.success

	moveq.l	#0,d0			;Flyer board
	bsr	SetNoMode

;	SBusWrite(UNIT | FLYER_SYNC,0x43,0xF0);	   /* Select Input Mode */

;	moveq.l	#0,d0		;Flyer #0
;	moveq.l	#0,d1		;Coefs 0
;	lea.l	FIR050(pc),a0
;	bsr	FIRcoef
;	tst.l	d0
;	bne	.exit

;;	moveq.l	#0,d0		;Flyer #0
;;	moveq.l	#1,d1		;Coefs 1
;;	lea.l	FIR050(pc),a0
;;	bsr	FIRcoef
;;	tst.l	d0
;;	bne	.exit

*** Set P-encoders' clock
	move.l	fl_Pencode(a6),a1	;Get P-encoder definition data
	cmp.w	#0,a1			;Not taught yet?
	beq	.error
	moveq.l	#0,d0		;Flyer #0
	moveq.l	#3,d1		;Clock 3 (P coder)
	move.l	fch_speed(a1),d2	;P clock speed
	beq.s	.noclock3
	bsr	SetClockGen	;Do it
.noclock3

*** Program both P-encoders
	moveq.l	#0,d0			;Flyer board
	move.l	fch_length(a1),d2	;Size of binary
	moveq.l	#3,d1			;Chip #
	move.b	fch_chiprev(a1),d3	;Revision
	move.b	#1,d4			;Dual (chips 3 and 4)
	lea.l	FlyerChipHdr_Sizeof(a1),a0
	bsr	IntFPGA
	tst.l	d0
	bne	.exit

*** Set M-encoders' clock
	move.l	fl_Mencode(a6),a1	;Get M-encoder definition data
	cmp.w	#0,a1			;Not taught yet?
	beq	.error
	moveq.l	#0,d0		;Flyer #0
	moveq.l	#2,d1		;Clock 2 (M coder)
	move.l	fch_speed(a1),d2	;M clock speed
	beq.s	.noclock4
	bsr	SetClockGen	;Do it
.noclock4

*** Program both M-encoders
	moveq.l	#0,d0			;Flyer board
	move.l	fch_length(a1),d2	;Size of binary
	moveq.l	#5,d1			;Chip #
	move.b	fch_chiprev(a1),d3	;Revision
	move.b	#1,d4			;Dual (chips 5 and 6)
	lea.l	FlyerChipHdr_Sizeof(a1),a0
	bsr	IntFPGA
	tst.l	d0
	bne	.exit

;	/* Select the Flyer video input */
;	SBusWrite(UNIT | FLYER_SYNC,0xFB,0x80);

	moveq.l	#0,d0			;Flyer board
	bsr	SetRecMode

.success
	moveq.l	#FERR_OKAY,d0
	bra.s	.exit

.error				;Not used!
	bsr	FreeJustCmdSlot		;Won't use cmd
	moveq.l	#FERR_LIBFAIL,d0
.exit
;;Don't restore back to Flyer outputs when recording!!!???
;;;	bsr	RestoreFlyer		;Restore Switcher to previous state

	movem.l	(sp)+,d1-d4/a0-a2/a5
	rts

******* flyer.library/Defaults ******************************************
*
*   NAME
*	Defaults - clear given ClipAction structure(s) to default values
*
*   SYNOPSIS
*	error = Defaults(clipaction)
*	D0               A0
*
*	VOID Defaults(struct ClipAction *);
*
*   FUNCTION
*	Clears the given ClipAction structure to default values, as well as
*	the attached FlyerVolume structure.  See structure documentation for
*	default values.
*
*   INPUTS
*	clipaction - pointer to a ClipAction structure.  Will also setup
*	   FlyerVolume structure, if attached.
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*
*   BUGS
*
*   SEE ALSO
*	flyer.h
*
*****************************************************************************
Defaults
	IFD	DEBUGGEN
	DUMPMSG <Defaults>
	ENDC
	movem.l	d0/a0-a1,-(sp)
	move.l	a0,a1

	IFD	DEBUGGEN
	DUMPHEXI.L <Defaults called on struct >,a1,<\>
	ENDC

	cmp.w	#0,a0
	beq.s	.eeknoclipact
	move.w	#CA_sizeof-1,d0
	lea.l	ca_ID(a0),a0			;Skip Volume ptr
	subq.l	#4,d0				; "
.clrCA
	clr.b	(a0)+		;Clear entire ClipAction structure
	dbf	d0,.clrCA

	move.b	#RT_STOPPED,ca_ReturnTime(a1)
	move.b	#CAF_VIDEO!CAF_AUDIOL!CAF_AUDIOR,ca_Flags(a1)
	clr.b	ca_PermissFlags(a1)
	move.w	#$FFFF,ca_VolSust1(a1)
	move.w	#$FFFF,ca_VolSust2(a1)
	move.w	#$8000,ca_AudioPan1(a1)	;Left
	move.w	#$7FFF,ca_AudioPan2(a1)	;Right

;Clear entire FlyerVolume structure (if any)
	move.l	ca_Volume(a1),a0
	cmp.w	#0,a0
	beq.s	.eeknovolume
	moveq.l	#FV_sizeof-1,d0
.clrFV
	clr.b	(a0)+		;Clear structure
	dbf	d0,.clrFV
.eeknovolume

.eeknoclipact
	movem.l	(sp)+,d0/a0-a1
	rts


;******* flyer.library/FlyerFileInfo ******************************************
******* flyer.library/GetClipInfo ******************************************
*
*   NAME
*	GetClipInfo - get information about a specific clip
*
*   SYNOPSIS
*	error = GetClipInfo(volume,clipinfo)
*	D0                  A0     A1
*
*	ULONG GetClipInfo(struct FlyerVolume *,struct ClipInfo *);
*
*   FUNCTION
*	Fills in the provided ClipInfo structure with information about the
*	specified clip.  Of particuar interest are: ci_fields equals the
*	number of fields the clip contains, ci_flags describes the type of
*	data in the clip.  See OIB_HASVIDEO and OIB_HASAUDIO in "Flyer.h".
*	Data files (such as icons) will have neither flag set.
*
*	You MUST initialize ci_len to the value CI_sizeof before calling this
*	function.  This is to ensure that future Flyer software does not
*	break old application software.
*
*	A non-zero return code indicates a failure (structure is not filled
*	in).  This call does not return until complete.  The structure may be
*	modified or reused in any way after it returns.
*
*	This routine is useful for obtaining info about a clip which has no
*	icon.
*
*	Also retrieves any starting SMPTE time-code from the clip, which can
*	be read using GetSMPTE.
*
*   INPUTS
*	volume - pointer to a FlyerVolume structure which describes the clip
*
*	clipinfo - pointer to structure to contain clip information
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*
*   BUGS
*
*   SEE ALSO
*	GetSMPTE
*
*****************************************************************************
FileInfo
GetClipInfo
	IFD	DEBUGGEN
	DUMPMSG <Get/FileInfo>
	ENDC
	movem.l	d3/a0-a1/a3-a5,-(sp)

	bsr	Get_Vol_Cmd		;Get a free spot to place command
	bne.s	.exit			;Failed? Exit

	CLEAR	d3
	move.w	ci_len(a1),d3		;Length of structure to fill in
	beq.s	.error

	move.l	d3,d0			;Leave some extra room
	bsr	PassFlyerVolume		;Copy FlyVol structure & Name -> SRAM
	tst.l	d0
	beq.s	.error			;Failed?

	move.l	d0,cmd_CopySrc(a4)	;Copyback src (SRAM ClipInfo)
	move.l	a1,cmd_CopyDest(a4)	;Copyback dest (caller's struct)
	move.l	d3,cmd_CopySize(a4)	;Copyback size

	sub.l	unit_SRAMbase(a5),d0	;Make offset to SRAM
	move.l	d0,8(a3)		;ClipInfo structure offset
	add.l	d3,d0
	move.l	d0,4(a3)		;FlyerVolume offset

	moveq.l	#op_FILEINFO,d0
	lea.l	FollowUpCopyStruct(pc),a1	;Copyback when done
	bsr	FireCmd		;Go!
	bra.s	.exit
.error
	bsr	FreeCmdSlot		;Won't use cmd
	moveq.l	#FERR_LIBFAIL,d0
.exit
	movem.l	(sp)+,d3/a0-a1/a3-a5
	rts

******* flyer.library/MakeFlyerFile ******************************************
*
*   NAME
*	MakeFlyerFile - Create an empty file on a Flyer drive
*
*   SYNOPSIS
*	error = MakeFlyerFile(volume,blocks,startptr)
*	D0                    A0     D0     A1
*
*	ULONG MakeFlyerFile(struct FlyerVolume *,ULONG,ULONG *);
*
*   FUNCTION
*	Creates a file of a specified size on a Flyer drive and adds it to
*	the drive's filesystem.  The start block for the file data area is
*	returned to the caller, who may then fill the file with something
*	useful.
*
*	Previous library versions would only create files of a size which was
*	a multiple of 512.  Starting rev 4.04, MakeFlyerFile can be used to
*	create a file of any size, but for backward compatibility, here's how
*	you must specify the size:
*
*	   Write the byte size into the variable that 'startptr' points to
*	   Pass 'blocks' value of 0
*	   Call MakeFlyerFile()
*
*	The value pointed to by 'startptr' has the same meaning on return as
*	before.
*
*   INPUTS
*	volume - pointer to structure which describes a volume and name for
*	   new file
*
*	blocks - size of file in blocks (512 bytes each)
*
*	startptr - ptr to a ULONG to receive the start block reserved for
*	   file's data.  This ULONG also contains the byte size of the file
*	   to create, providing that 'blocks' is 0.
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*	Errors will be returned if not enough contiguous space for the file,
*	or if a file of the same name already exists on that drive/path.
*
*   BUGS
*
*   SEE ALSO
*	FlyerCopyClip, FlyerCopyClipNew
*
*****************************************************************************
MakeFlyerFile
	IFD	DEBUGGEN
	DUMPMSG <MakeFile>
	ENDC
	movem.l	d1/a0-a1/a3-a5,-(sp)

	bsr	Get_Vol_Cmd	;Get a free spot to place command
	bne.s	.exit		;Failed? Exit

	tst.l	d0			;Blocks 0? (not used)
	bne.s	.blkaligned

;----- Okay, caller is passing in size in bytes.  Break this into # blocks and frag bytes
	move.l	(a1),d1			;Size in bytes
	move.l	d1,d0
	lsr.l	#8,d0			;Divide by 512 to turn into whole blocks
	lsr.l	#1,d0

	and.l	#$1FF,d1		;Modulo 512
	move.l	d1,16(a3)		;Residual bytes
.blkaligned

	move.l	d0,8(a3)		;Size in blocks
	move.l	a1,cmd_CopyDest(a4)	;Ptr to recv start addr

	CLEAR	d0			;No extra room
	bsr	PassFlyerVolume		;Copy FlyVol structure & Name -> SRAM
	tst.l	d0
	beq.s	.error			;Failed?

	sub.l	unit_SRAMbase(a5),d0	;Make offset to SRAM
	move.l	d0,4(a3)		;FlyerVolume offset

	moveq.l	#op_MAKEFILE,d0
	lea.l	.FollowUp(pc),a1
	bsr	FireCmd		;Go!
	bra.s	.exit
.error
	moveq.l	#FERR_LIBFAIL,d0
.novol
	bsr	FreeCmdSlot		;Won't use cmd
.exit
	movem.l	(sp)+,d1/a0-a1/a3-a5
	rts

.FollowUp			;Can trash a0,a1,d0
	move.l	cmd_CopyDest(a4),d0
	beq.s	.avoid
	move.l	d0,a0
	move.l	12(a3),d0
	move.l	d0,(a0)		;Return start address
.avoid
	move.b	3(a3),d0	;Get error
	rts


******* flyer.library/FlyerCopyClipNew ******************************************
*
*   NAME
*	FlyerCopyClipNew -- Fast copy a flyer clip (w/status & abort capabilities)
*
*   SYNOPSIS
*	error = FlyerCopyClipNew(srcaction,destvolume)
*	D0                       A0        A1
*
*	ULONG FlyerCopyClipNew(struct ClipAction *,struct FlyerVolume *);
*
*   FUNCTION
*	Identical to FlyerCopyClip function, except that it uses a ClipAction structure
*	to specify the source, which adds the ability to run it asynchronously, ability
*	to be aborted, and the ability to obtain status during a copy.
*
*   INPUTS
*	srcaction - pointer to structure which describes the source volume and clip
*		    name.  "ReturnTime" and "Status" fields are also used.
*
*	destvolume - pointer to structure which describes the destination
*	             path/name and the volume on which to create it.  Must
*	             always contain the path/name, even if not renaming clip
*	             during copy.
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*	Both source and destination volumes must be attached to the same
*	Flyer card.
*
*   BUGS
*
*   SEE ALSO
*	FlyerCopyClip
*
*****************************************************************************
CopyClipNew
	IFD	DEBUGGEN
	DUMPMSG <CopyClipNew>
	ENDC
	movem.l	a0-a2/a3-a5,-(sp)

	move.l	a0,a2			;Move action here

	move.l	ca_Volume(a2),a0	;Get src FlyerVolume (really don't want action)
	cmp.w	#0,a0
	beq.s	.error
					;a0=Volume structure
	bsr	Get_Vol_Cmd		;Get a free spot to place command
	bne.s	.exit			;Failed? Exit

	move.b	ca_ReturnTime(a2),cmd_RetTime(a4)	;User's return time
	move.b	#1,2(a3)		;Continue flag = 1

	CLEAR	d0			;No extra room
	bsr	PassFlyerVolume		;Copy FlyVol structure & Name -> SRAM
	tst.l	d0
	beq.s	.error			;Failed?

	sub.l	unit_SRAMbase(a5),d0	;Make offset to SRAM
	move.l	d0,4(a3)		;FlyerVolume offset

	move.l	a1,a0			;Work with dest volume
	bsr	FindVolume		;Convert volume to brd/chan/drv
	bne.s	.novol			;Failed? Exit

	CLEAR	d0			;No extra room
	bsr	PassFlyerVolume		;Copy FlyVol structure & Name -> SRAM
	tst.l	d0
	beq.s	.error			;Failed?
	sub.l	unit_SRAMbase(a5),d0	;Make offset to SRAM
	move.l	d0,8(a3)		;FlyerVolume offset
;	move.b	fv_SCSIdrive(a0),9(a3)		;dest drive

	move.b	#0,12(a3)			;no verify

	moveq.l	#op_COPYCLIP,d0
	lea.l	StdFollowUp(pc),a1
	move.l	a2,a0			;ClipAction
	bsr	FireAction		;Go!
	bra.s	.exit
.error
	moveq.l	#FERR_LIBFAIL,d0
.novol
	bsr	FreeCmdSlot		;Won't use cmd
.exit
	movem.l	(sp)+,a0-a2/a3-a5
	rts

******* flyer.library/FlyerCopyClip ******************************************
*
*   NAME
*	FlyerCopyClip - Fast copy a flyer clip
*
*   SYNOPSIS
*	error = FlyerCopyClip(srcvolume,destvolume)
*	D0                    A0        A1
*
*	ULONG FlyerCopyClip(struct FlyerVolume *,struct FlyerVolume *);
*
*   FUNCTION
*	Makes a copy of a Flyer clip using high speed copying (independent of
*	Amiga host operating system).  Will fail if filename is not found
*	on the source volume or if the destination filename already exists on
*	the destination volume.  Will not create subdirectories for the
*	destination name, so ensure entire path exists before starting copy.
*
*	Source and destination volumes may be the same drive, but copying
*	will be slower.
*
*   INPUTS
*	srcvolume - pointer to structure which describes the source clip's
*	            path/name and the volume on which it is found.
*
*	destvolume - pointer to structure which describes the destination
*	             path/name and the volume on which to create it.  Must
*	             always contain the path/name, even if not renaming clip
*	             during copy.
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*	Both source and destination volumes must be attached to the same
*	Flyer card.
*
*   BUGS
*
*   SEE ALSO
*	FlyerCopyClipNew
*
*****************************************************************************
CopyClip
	IFD	DEBUGGEN
	DUMPMSG <CopyClip>
	ENDC
	movem.l	a0-a1/a3-a5,-(sp)

	bsr	Get_Vol_Cmd	;Get a free spot to place command
	bne.s	.exit		;Failed? Exit

	move.b	#1,2(a3)		;Continue flag = 1

	CLEAR	d0			;No extra room
	bsr	PassFlyerVolume		;Copy FlyVol structure & Name -> SRAM
	tst.l	d0
	beq.s	.error		;Failed?

	sub.l	unit_SRAMbase(a5),d0	;Make offset to SRAM
	move.l	d0,4(a3)		;FlyerVolume offset

	move.l	a1,a0			;Work with dest volume
	bsr	FindVolume		;Convert volume to brd/chan/drv
	bne.s	.novol		;Failed? Exit

	CLEAR	d0			;No extra room
	bsr	PassFlyerVolume		;Copy FlyVol structure & Name -> SRAM
	tst.l	d0
	beq.s	.error		;Failed?
	sub.l	unit_SRAMbase(a5),d0	;Make offset to SRAM
	move.l	d0,8(a3)		;FlyerVolume offset
;	move.b	fv_SCSIdrive(a0),9(a3)		;dest drive

	move.b	#0,12(a3)			;no verify

	moveq.l	#op_COPYCLIP,d0
	lea.l	StdFollowUp(pc),a1
	bsr	FireCmd		;Go!
	bra.s	.exit
.error
	moveq.l	#FERR_LIBFAIL,d0
.novol
	bsr	FreeCmdSlot		;Won't use cmd
.exit
	movem.l	(sp)+,a0-a1/a3-a5
	rts


******* flyer.library/FlyerStripAudio ******************************************
*
*   NAME
*	FlyerStripAudio - Strip audio from a clip, make an audio-only clip
*
*   SYNOPSIS
*	error = FlyerStripAudio(srcvolume,destvolume)
*	D0                      A0        A1
*
*	ULONG FlyerStripAudio(struct FlyerVolume *,struct FlyerVolume *);
*
*   FUNCTION
*	Creates a new clip containing only the audio from the source clip.
*	Will fail if the source clip is not found or does not contain audio.
*	Destination clip must not already exist on the destination volume, or
*	an error will result.
*
*	Both source and destination volumes must be attached to the same
*	Flyer card.
*
*   INPUTS
*	srcvolume - pointer to structure which describes the source clip name
*	   and the volume on which it is found.
*
*	destvolume - pointer to structure which describes the destination
*	   clip name and the volume on which to place it.
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*
*   BUGS
*
*   SEE ALSO
*
*****************************************************************************
StripAudio
	IFD	DEBUGGEN
	DUMPMSG <StripAudio>
	ENDC
	movem.l	a0-a1/a3-a5,-(sp)

	bsr	Get_Vol_Cmd	;Get a free spot to place command
	bne.s	.exit		;Failed? Exit

	CLEAR	d0			;No extra room
	bsr	PassFlyerVolume		;Copy FlyVol structure & Name -> SRAM
	tst.l	d0
	beq.s	.error			;Failed?
	sub.l	unit_SRAMbase(a5),d0	;Make offset to SRAM
	move.l	d0,4(a3)		;FlyerVolume offset

	move.l	a1,a0			;Now work with dest volume
	bsr	FindVolume		;Convert volume to brd/chan/drv
	bne.s	.novol			;Failed? Exit

	CLEAR	d0			;No extra room
	bsr	PassFlyerVolume		;Copy FlyVol structure & Name -> SRAM
	tst.l	d0
	beq.s	.error			;Failed?
	sub.l	unit_SRAMbase(a5),d0	;Make offset to SRAM
	move.l	d0,8(a3)		;FlyerVolume offset

	moveq.l	#op_STRIPAUDIO,d0
	lea.l	StdFollowUp(pc),a1
	bsr	FireCmd		;Go!
	bra.s	.exit
.error
	moveq.l	#FERR_LIBFAIL,d0
.novol
	bsr	FreeCmdSlot		;Won't use cmd
.exit
	movem.l	(sp)+,a0-a1/a3-a5
	rts


******* flyer.library/BeginFindField ******************************************
*
*   NAME
*	BeginFindField - Prepare to shuttle/jog a clip
*
*   SYNOPSIS
*	error = BeginFindField(clipaction)
*	D0                     A0
*
*	ULONG BeginFindField(struct ClipAction *);
*
*   FUNCTION
*	Prepares Flyer for a shuttle/jog session for the named clip.  Call
*	this when the user brings up the control panel for a clip.
*
*	You must prepare a ClipAction structure with the desired parameters
*	then pass a pointer to it to this routine, which allows the Flyer to
*	prepare itself internally.  All calls to DoFindField, FindFieldAudio,
*	and EndFindField must be passed this same structure pointer.
*
*	See also FindFieldAudio.
*
*	The fields which need setup prior to calling BeginFindField:
*	   ca_Volume       Ptr to FlyerVolume structure
*
*	   ca_Channel      Video channel to use during session
*
*	   ca_Flags        CAB_VIDEO to see found frames
*	                   CAB_AUDIO1 and/or 2 to hear found frames
*	                      (here it is legal to set none)
*
*	   ca_VolSust1
*	   ca_VolSust2     Volume for audio channels
*
*	   fv_Path         Name of clip -- if volume name is prepended,
*	                      then the next 3 fields can be left blank
*
*	   fv_Board        Flyer board number
*	   fv_SCSIchannel  SCSI channel on which clip resides (optional)
*	   fv_SCSIdrive    Drive on SCSI channel on which clip resides
*	                      (optional)
*
*
*
*	This call should always have a matching EndFindField call eventually.
*	Do not call this twice without an intervening call to EndFindField.
*
*	The result from this call should be checked.  A 0 value indicates all
*	went well, the Flyer is prepared for "DoFindField" calls.  Any non-0
*	value indicates a failure, most likely that the named file could not
*	be found on the specified drive (do not call EndFindField on it).
*
*   INPUTS
*	clipaction - specifies the name of the clip
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*	This call does not return until ready for DoFindField calls (???)
*
*   BUGS
*
*   SEE ALSO
*	FindFieldAudio
*
*****************************************************************************
BeginFindField
	IFD	DEBUGGEN
	DUMPMSG <BeginFindField>
	ENDC
	move.l	d1,-(sp)
			;Structure ptr already in a0
	moveq.l	#1,d1	;New session
	bsr	_SearchArgs
	move.l	(sp)+,d1
	rts


******* flyer.library/EndFindField ******************************************
*
*   NAME
*	EndFindField - Cleanup after a shuttle/jog session
*
*   SYNOPSIS
*	error = EndFindField(clipaction)
*	D0                   A0
*
*	ULONG EndFindField(struct ClipAction *);
*
*   FUNCTION
*	This call frees up resources allocated with a BeginFindField call.
*	Call when the control panel for a clip is put away.  You must pass
*	a pointer to the same structure as was passed to BeginFindField.
*	If CAF_USEMATTE flag is true in the ClipAction structure, this call
*	will also put up the specified matte color on the video channel.
*
*	A return value of 0 indicates all went well.
*
*   INPUTS
*	clipaction - same pointer as was used for entire shuttle/jog session.
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*	Only matte black is currently supported for CAF_USEMATTE
*
*   BUGS
*
*   SEE ALSO
*
*****************************************************************************
EndFindField
	IFD	DEBUGGEN
	DUMPMSG <EndFindField>
	ENDC
	move.l	d1,-(sp)
			;Structure ptr already in a0
	moveq.l	#0,d1	;End session
	bsr	_SearchArgs

	move.l	(sp)+,d1
	rts

******* flyer.library/FindFieldAudio ******************************************
*
*   NAME
*	FindFieldAudio - change audio parameters during shuttle/jog session
*
*   SYNOPSIS
*	error = FindFieldAudio(clipaction)
*	D0                     A0
*
*	ULONG FindFieldAudio(struct ClipAction *);
*
*   FUNCTION
*	This call allows you to change the status of the audio flag while in
*	the middle of a shuttle session (overrides the initial audioflag
*	specified in BeginFindField).  To effect the change, modify the
*	CAB_AUDIO flags in ca_Flags and pass the structure to this routine.
*	Call this as many times as needed (whenever the user clicks the audio
*	button on/off), but do not call it outside of the Begin/EndFindField
*	pair.
*
*	A return value of 0 indicates all went well.
*
*   INPUTS
*	clipaction - same pointer as was used for entire shuttle/jog session.
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*
*   BUGS
*
*   SEE ALSO
*
*****************************************************************************
FindFieldAudio
	IFD	DEBUGGEN
	DUMPMSG <FindFieldAudio>
	ENDC
	move.l	d1,-(sp)
			;Structure ptr already in a0
	moveq.l	#2,d1	;Amend session
	bsr	_SearchArgs
	move.l	(sp)+,d1
	rts



******* flyer.library/GetSMPTE ******************************************
*
*   NAME
*	GetSMPTE - Return SMPTE time code information
*
*   SYNOPSIS
*	error = GetSMPTE(board,SMPTEinfo)
*	D0               D0    A0
*
*	ULONG GetSMPTE(UBYTE,struct SMPTEinfo *);
*
*   FUNCTION
*	This returns the last SMPTE time code information retrieved from a
*	clip.
*
*	This is generally used after a "DoFindField" call to retrieve the
*	SMPTE information related to that field, or after a GetClipInfo call
*	to get the start SMPTE time for the clip.
*
*   INPUTS
*	board - specifies the Flyer board (0-3)
*
*	SMPTEinfo - pointer to SMPTEinfo structure to receive time code info
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*
*   BUGS
*
*   SEE ALSO
*
*****************************************************************************
GetSMPTE
	IFD	DEBUGGEN
	DUMPMSG <GetSMPTE>
	ENDC
	movem.l	a0-a1/a3-a5,-(sp)

	bsr	Get_Brd_Cmd		;Get a free spot to place command
	bne.s	.exit			;Failed? Exit

	moveq.l	#SI_sizeof,d0
	move.l	d0,cmd_CopySize(a4)	;Size of copy (when done)

				;d0=amount
	bsr	AllocSRAM	;Need some SRAM
	tst.l	d0		;Failed?
	beq.s	.error

	move.l	a0,cmd_CopyDest(a4)	;User buffer for copy (when done)
	move.l	d0,cmd_CopySrc(a4)	;Source SRAM ptr (when done)

	sub.l	unit_SRAMbase(a5),d0	;Make offset to SRAM
	move.l	d0,4(a3)		;ClipInfo structure offset

	moveq.l	#op_GETSMPTE,d0
	lea.l	FollowUpCopy(pc),a1	;Copyback when done
	bsr	FireCmd		;Go!
	bra.s	.exit
.error
	bsr	FreeCmdSlot		;Won't use cmd
	moveq.l	#FERR_LIBFAIL,d0
.exit
	movem.l	(sp)+,a0-a1/a3-a5
	rts


;********************* VTASC compression/decompression **********************

******* flyer.library/OpenReadField ******************************************
*
*   NAME
*	OpenReadField - Open a field from a clip for reading
*
*   SYNOPSIS
*	error = OpenReadField(action,field,modes)
*	D0                    A0     D0    D1
*
*	ULONG OpenReadField(struct ClipAction *,ULONG,UBYTE);
*
*   FUNCTION
*	Locates specified field of named clip and prepares to decompress
*	and transfer each scan line of the field using the FlyerReadLine
*	call.
*
*	This function, if successful, places a valid ca_FldHandle in the
*	ClipAction structure provided.  This same structure must be used for
*	any other calls relating to this open field, or you must manually
*	copy the value in ca_FldHandle into the ClipAction structure you wish
*	to use.
*
*	No compression information is required, as this information is
*	embedded in the clips themselves.
*
*   INPUTS
*	action - pointer to structure which describes a volume and the name
*	   of the clip to operate on.
*
*	field - field number of clip (starts at 0)
*
*	modes - various flags
*	   FRF_HALFLINES - allows reading the half lines.  Without this
*	   flag set, half lines are skipped
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*
*   BUGS
*
*   SEE ALSO
*	CloseField
*	EasyOpenWriteField
*	OpenWriteField
*	FlyerReadLine
*
*****************************************************************************
* Locates specific field in clip, prepare to read data
*****************************************************************************
OpenReadField
	IFD	DEBUGVTASC
	DUMPMSG <OpenReadField>
	ENDC
	bra	OpenReadField2

;	movem.l	a0-a1/a3-a5,-(sp)
;
;	move.l	ca_Volume(a0),a1	;Get FlyerVolume structure
;	cmp.w	#0,a1
;	beq.s	.stderror
;
;	move.l	a0,-(sp)
;	move.l	a1,a0			;Volume structure
;	bsr	Get_Vol_Cmd		;Get a free spot to place command
;	move.l	(sp)+,a0
;	bne.s	.exit			;Failed? Exit
;
;	move.b	ca_ReturnTime(a0),cmd_RetTime(a4)	;User's return time
;
;	move.b	#1,2(a3)		;Continue flag
;	move.l	d0,8(a3)		;Field number
;
;	CLEAR	d0			;Leave no extra room
;	bsr	PassClipAction		;Copy FlyVol structure & Name -> SRAM
;	tst.l	d0
;	beq.s	.error			;Failed?
;
;	sub.l	unit_SRAMbase(a5),d0	;Make offset to SRAM
;	move.l	d0,4(a3)		;ClipAction offset
;
;	moveq.l	#op_OPENREADFLD,d0
;	lea.l	CopyBackAction(pc),a1	;Copyback when done (id = 0)
;	bsr	FireAction		;Go!
;	bra.s	.exit
;.error
;	bsr	FreeCmdSlot		;Won't use cmd
;.stderror
;	moveq.l	#FERR_LIBFAIL,d0
;.exit
;	movem.l	(sp)+,a0-a1/a3-a5
;	rts

******* flyer.library/EasyOpenWriteField ******************************************
*
*   NAME
*	EasyOpenWriteField - Open a clip field for writing (easy version)
*
*   SYNOPSIS
*	error = EasyOpenWriteField(action,field,modes,quality)
*	D0                         A0     D0    D1    D2
*
*	ULONG EasyOpenWriteField(struct ClipAction *,ULONG,UBYTE,UBYTE);
*
*   FUNCTION
*	Provides an easier front-end for the more complicated OpenWriteField
*	call.
*
*	See the description under OpenWriteField for a full description of
*	field writing and the "action", "field", and "modes" arguments.
*
*   INPUTS
*	action - pointer to structure which describes a volume and the name
*	         of the clip to operate on.
*
*	field - field number of clip (starts at 0).  Is a don't care with
*	        some open modes
*
*	modes - flags describing how to handle writing field
*
*	quality - a number representing the video quality
*
*	     Currently supported modes, in order of decreasing video quality:
*
*	        0 (D2)  Best quality, worst compression
*	        1 (D2)
*	        2 (SN)
*	        3 (SN)
*	        4 (SN)  Worst quality, best compression
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*
*   BUGS
*
*   SEE ALSO
*	CloseField
*	OpenReadField
*	OpenWriteField
*	FlyerWriteLine
*
*****************************************************************************
* Entry:	a0:struct ClipAction *ptr
*		d0:field.l
*		d1:mode.b
*		d2:quality number
*****************************************************************************
EasyOpenWriteField
	IFD	DEBUGVTASC
	DUMPMSG <EasyOpenWriteField>
	ENDC

	movem.l	d2/a1,-(sp)

;*** Setup a compinfo structure for user
	lea.l	fl_PrivCompInfo(a6),a1
	move.b	#ALGO_D2,vci_Algo(a1)
	cmp.b	#2,d2			;In D2 range?
	blo.s	.settol
	move.b	#ALGO_SN,vci_Algo(a1)
	sub.b	#2,d2			;Bump to SN range
.settol
	move.b	d2,vci_Tolerance(a1)
	move.b	#2,vci_FIRcomp(a1)	;33%
	move.b	#122,vci_RndFreq(a1)
;	move.w	#VIDSIZE_0,vci_DataSize(a1)	;Std blocks per field
	clr.w	vci_DataSize(a1)	;Let Flyer pick based on HQ5 option
	clr.b	vci_Flags(a1)

	bsr	OpenWriteField		;Tie to power-version

	movem.l	(sp)+,d2/a1
	rts

******* flyer.library/OpenWriteField ******************************************
*
*   NAME
*	OpenWriteField - Open a field from a clip for writing
*
*   SYNOPSIS
*	error = OpenWriteField(action,field,modes,compinfo)
*	D0                     A0     D0    D1    A1
*
*	ULONG OpenWriteField(struct ClipAction *,ULONG,UBYTE,
*	        struct VidCompInfo *);
*
*   FUNCTION
*	Prepares to transfer and compress each scan line of a field using the
*	FlyerWriteLine call.  How the new data is integrated into the clip
*	depends on the "modes" flags specified:
*
*	FWF_NEW (field = dont care)
*	   Writes the first field of a new clip (deletes old if exists)
*
*	FWF_APPEND (field = dont care)
*	   Appends another field onto the clip
*
*	FWF_REWRITE (field = n)
*	   Overwrites an existing field in the clip (must be same size or
*	   smaller)
*
*	FWF_APPEND + FWF_REWRITE (field = dont care)
*	   Replaces the last field.  Used for retrying with different
*	   compression
*
*	FWF_APPEND + FWF_REWRITE + FWF_FRAME (field = n)
*	   Rewrite multiple fields in the last color frame (each field
*	   sequentially).  Field must be in the last color frame.  Used
*	   for retrying entire color frame with different compression.
*
*	FWF_REWRITE + FWF_FRAME (field = n)
*	   Rewrite multiple fields in a color frame (each field
*	   sequentially).  Used for retrying entire color frame with
*	   different compression.
*
*	FWF_HALFLINES allows writing of half lines.  Without this flag set,
*	   half lines are skipped and padded.
*
*	"compinfo" points to a structure containing information about how to
*	compress the data.  If this pointer is NULL, the Flyer will default
*	to its best algorithm.
*
*	This function, if successful, places a valid ca_FldHandle in the
*	ClipAction structure provided.  This same structure must be used for
*	any other calls relating to this open field, or you must manually
*	copy the value in ca_FldHandle into the ClipAction structure you wish
*	to use.
*
*	This function may fail and return FERR_FULL if not enough contiguous
*	storage exists at the end of the clip to handle appending a field.
*
*	Also, field writing may fail if the data produced is too large for
*	the hardware to play.  An FERR_FULL error from FlyerWriteLine
*	indicates that the field needs to be compressed harder in order to
*	fit.  If this happens, the field should be closed and reopened using
*	a different level of compression or algorithm.  Also set the
*	FWF_REWRITE mode flag to indicate to replace the previous data.
*
*	When replacing fields in the middle of a clip, the compressed data
*	must be the same size or smaller, as no space insertion is currently
*	supported.  If an FERR_FULL occurs in this case, you must either
*	retry with a tighter compression method or write the original field
*	data back into the clip.  Otherwise, this field will flash
*	unpredictable data near the bottom when the clip is played back.
*
*	Always creates clips with integral color frames regardless of how
*	many fields are written.  If a clip is left with less than a full
*	color frame at the end, the remaining fields in the color frame are
*	temporariliy padded with NTSC black.  These pad fields are auto-
*	matically replaced when new fields are appended.
*
*   INPUTS
*	action - pointer to structure which describes a volume and the name
*	   of the clip to operate on.
*
*	field - field number of clip (starts at 0).  Is a don't care with
*	   some open modes (see below)
*
*	modes - flags describing how to handle writing field
*	   FWF_NEW     - Erase existing clip (if any), start new clip
*	   FWF_APPEND  - Append field to clip
*	   FWF_REWRITE - Re-write over field
*	   FWF_FRAME   - Re-write field (must redo all following fields in
*	                 the same color frame)
*
*	compinfo - pointer to a VidCompInfo structure (or null for defaults)
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*	Replacing fields in the middle of clips not fully tested
*
*   BUGS
*
*   SEE ALSO
*	CloseField
*	EasyOpenWriteField
*	OpenReadField
*	FlyerWriteLine
*
*****************************************************************************
OpenWriteField
	IFD	DEBUGVTASC
	DUMPMSG <OpenWriteField>
	ENDC
	bra	OpenWriteField2


*	a0 : struct ClipAction *ptr
*	a1 : VidCompInfo structure *
*	d0:field.l
*	d1:mode.b
* Returns:
*	d0 : Result
*	d1 : Field from Flyer
*	d2 : RefNum from Flyer
OpenWriteField1
	movem.l	a0-a5,-(sp)
	move.l	a1,a2

	move.l	ca_Volume(a0),a1	;Get FlyerVolume structure
	cmp.w	#0,a1
	beq	.stderror

	move.l	a0,-(sp)

	IFD	DEBUGGEN
	move.l	fv_Path(a1),a0
	DUMPSTR	0(a0)
	DUMPMSG	< - write name**** >
	ENDC

	move.l	a1,a0			;Volume structure
	bsr	Get_Vol_Cmd		;Get a free spot to place command
	move.l	(sp)+,a0
	bne.s	.exit			;Failed? Exit

	move.b	ca_ReturnTime(a0),cmd_RetTime(a4)	;User's return time

	move.b	#1,2(a3)		;Continue flag
	move.l	d0,12(a3)		;Field
	move.b	d1,16(a3)		;Mode

	CLEAR	d1
	move.w	#VCI_sizeof,d1

	move.l	d1,d0			;Leave room for VidCompInfo struct
	bsr	PassClipAction		;Copy FlyVol structure & Name -> SRAM
	tst.l	d0
	beq.s	.error			;Failed?

	move.l	a2,cmd_CopyExtra(a4)	;Keep ptr to this for later

	movem.l	a0/d0,-(sp)
	move.l	a2,a0			;Ptr to VidCompInfo from caller
	move.l	d0,a1			;Ptr to SRAM to hold struct
	move.l	d1,d0			;Size of struct
	bsr	FastCopy		;Copy to SRAM
	movem.l	(sp)+,a0/d0

	sub.l	unit_SRAMbase(a5),d0	;Make offset to SRAM
	move.l	d0,8(a3)		;VidCompInfo offset
	add.l	d1,d0			;
	move.l	d0,4(a3)		;FlyerVolume offset

	moveq.l	#op_OPENWRITEFLD,d0
	lea.l	.FollowUp(pc),a1	;Copyback action & VidCompInfo when done
	bsr	FireAction		;Go!
	bra.s	.exit
.error
	bsr	FreeCmdSlot		;Won't use cmd
.stderror
	moveq.l	#FERR_LIBFAIL,d0
.exit
	movem.l	(sp)+,a0-a5
	rts

.FollowUp
	move.l	8(a3),d0		;VidCompInfo offset in SRAM
	add.l	unit_SRAMbase(a5),d0	;Make back into ptr
	move.l	d0,a0			;(src)
	move.l	cmd_CopyExtra(a4),a1	;Ptr to user's VidCompInfo structure
	CLEAR	d0
	move.w	#VCI_sizeof,d0		;Length
	bsr	FastCopy		;Copy back

	move.l	12(a3),d1		;Internal special! Field returned in d1!
	move.l	18(a3),d2		;Internal special! Reference number!

	bra	CopyBackAction		;Otherwise, normal action follow-up


******* flyer.library/CloseField ******************************************
*
*   NAME
*	CloseField - Closes an OpenReadField or (Easy)OpenWriteField
*
*   SYNOPSIS
*	error = CloseField(action)
*	D0                 A0
*
*	ULONG CloseField(struct ClipAction *);
*
*   FUNCTION
*	Closes the field which was previously opened using an OpenReadField,
*	OpenWriteField, or EasyOpenWriteField call.  In the case of a write
*	session being closed, any unwritten data is written to the clip.
*	Also, if less than a full field of scan lines was written, fills in
*	remainder with fill color (usually black).
*
*	Returns FERR_FULL if not enough room left in current field to write
*	any remaining data.
*
*	The only structure field which needs setup prior to calling
*	CloseField:
*	   ca_FldHandle   Field handle returned from successful
*	                  OpenReadField or (Easy)OpenWriteField call
*
*   INPUTS
*	action - pointer to structure which contains field handle to close
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*
*   BUGS
*
*   SEE ALSO
*	EasyOpenWriteField
*	OpenReadField
*	OpenWriteField
*	SetFillColor
*
*****************************************************************************
CloseField
	IFD	DEBUGVTASC
	DUMPMSG <CloseField>
	ENDC
	bra	CloseField2

CloseField1
*	a0:struct ClipAction *ptr (contains fhandle)
*	d0:RefNum
*	d1:WroteFlag
*	d2:Final LBA ptr (just past end)

	movem.l	d7/a0-a1/a3-a5,-(sp)
	move.l	d0,d7

	moveq.l	#0,d0		;Hard-wire to board 0 for now!!!
				;Need to lookup from table of handles
	bsr	Get_Brd_Cmd	;Get a free spot to place command
	bne.s	.exit		;Failed? Exit

	move.b	ca_ReturnTime(a0),cmd_RetTime(a4)	;User's return time

	move.b	#1,2(a3)	;Continue flag
	move.l	d7,4(a3)	;RefNum
	move.b	d1,8(a3)	;Wrote
	move.l	d2,10(a3)	;Final data ptr

	moveq.l	#op_CLOSEFIELD,d0
	lea.l	StdFollowUp(pc),a1
	bsr	FireAction	;Go!
.exit
	movem.l	(sp)+,d7/a0-a1/a3-a5
	rts


******* flyer.library/FlyerReadLine ******************************************
*
*   NAME
*	FlyerReadLine - Read a scan line from a field previously opened
*
*   SYNOPSIS
*	error = FlyerReadLine(action,buffer)
*	D0                    A0     A1
*
*	ULONG FlyerReadLine(struct ClipAction *,UBYTE *);
*
*   FUNCTION
*	Decompresses next scan line from open field and transfers into
*	caller's buffer (must be big enough to receive 752 bytes).  NTSC line
*	21 is the first line read from the field, and 262 is the last.  Any
*	extra calls will fill the buffer with the fill color (usually black).
*
*	This function does software emulation of the Flyer's hardware which
*	converts VTASC-compressed data into D2 data, including FIR filtering.
*
*	The fields which need setup prior to calling FlyerReadLine:
*	   ca_FldHandle  - Field handle from successful OpenReadField
*	   ca_ReturnTime - RT_xxx value desired (not currently supported)
*
*   INPUTS
*	action - pointer to structure which contains the field handle to read
*	   from and the return time for this call.
*
*	buffer - buffer to receive composite scan line data
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*
*   BUGS
*
*   SEE ALSO
*	CloseField
*	OpenReadField
*	SetFillColor
*	FlyerWriteLine
*
*****************************************************************************
*	a0:struct ClipAction *ptr (contains fhandle)
*	a1:UBYTE *buffer (to receive)
*****************************************************************************
ReadLine
	IFD	DEBUGVTASC
	DUMPMSG <ReadLine>
	ENDC
	bra	ReadLine2

;	movem.l	d7/a0-a1/a3-a5,-(sp)
;
;	move.l	ca_FldHandle(a0),d7	;fhandle
;
;	moveq.l	#0,d0		;Hard-wire to board 0 for now!!!
;				;Need to lookup from table of handles
;	bsr	Get_Brd_Cmd	;Get a free spot to place command
;	bne.s	.exit		;Failed? Exit
;
;	move.b	ca_ReturnTime(a0),cmd_RetTime(a4)	;User's return time
;
;	move.b	#1,2(a3)	;Continue flag
;	move.l	d7,4(a3)	;fhandle
;
;	CLEAR	d0
;	move.w	#SAMPLESPERLINE,d0
;	move.l	d0,cmd_CopySize(a4)	;Size of copyback
;	bsr	AllocSRAM	;Alloc SRAM line buffer
;	tst.l	d0		;Failed?
;	beq.s	.error
;
;	move.l	a1,cmd_CopyDest(a4)	;Save for later (caller's ptr)
;	move.l	d0,cmd_CopySrc(a4)	;Ptr to SRAM area
;	sub.l	unit_SRAMbase(a5),d0	;Turn into offset address
;	move.l	d0,8(a3)		;Buffer to receive
;
;	moveq.l	#op_READLINE,d0
;	lea.l	FollowUpCopy(pc),a1
;	bsr	FireAction		;Go!
;	bra.s	.exit
;.error
;	bsr	FreeCmdSlot		;Won't use cmd
;	moveq.l	#FERR_LIBFAIL,d0
;.exit
;	movem.l	(sp)+,d7/a0-a1/a3-a5
;	rts

******* flyer.library/FlyerWriteLine ******************************************
*
*   NAME
*	FlyerWriteLine - Write a scan line to a field previously opened
*
*   SYNOPSIS
*	error = FlyerWriteLine(action,buffer)
*	D0                     A0     A1
*
*	ULONG FlyerWriteLine(struct ClipAction *,UBYTE *);
*
*   FUNCTION
*	Transfers scan line data from caller's buffer, compresses it, and
*	places in the open clip as specified in (Easy)OpenWriteField call.
*	Expects 752 bytes from caller's buffer.  NTSC line 21 is expected on
*	the first call to this function, and 262 on the last.  Any extra
*	calls will be ignored.
*
*	This function does software emulation of the Flyer's hardware which
*	converts D2 data into VTASC-compressed data, including FIR filtering.
*
*	The fields which need setup prior to calling FlyerWriteLine:
*	   ca_FldHandle   - Field handle from successful OpenWriteField
*	                       or EasyOpenWriteField.
*	   ca_ReturnTime  - RT_xxx value desired (not currently supported)
*
*	Returns FERR_FULL if out of room in current field
*
*   INPUTS
*	action - pointer to structure which contains the field handle to
*	   write to and the return time for this call.
*
*	buffer - contains composite scan line data (will be modified)
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*	Currently modifies the data at the "buffer" pointer
*
*   BUGS
*
*   SEE ALSO
*	CloseField
*	EasyOpenWriteField
*	OpenWriteField
*	FlyerReadLine
*
*****************************************************************************
*	a0:struct ClipAction *ptr (contains fhandle)
*	a1:UBYTE *buffer (source data)
*****************************************************************************
WriteLine
	IFD	DEBUGGEN
	DUMPMSG <WriteLine>
	ENDC
	bra	WriteLine2

;	movem.l	d7/a0-a1/a3-a5,-(sp)
;
;	move.l	ca_FldHandle(a0),d7	;fhandle
;
;	moveq.l	#0,d0		;Hard-wire to board 0 for now!!!
;				;Need to lookup from table of handles
;	bsr	Get_Brd_Cmd	;Get a free spot to place command
;	bne.s	.exit		;Failed? Exit
;
;	move.b	ca_ReturnTime(a0),cmd_RetTime(a4)	;User's return time
;
;	move.b	#1,2(a3)	;Continue flag
;	move.l	d7,4(a3)	;fhandle
;
;				;a1=src ptr
;	CLEAR	d0		;d0=size
;	move.w	#SAMPLESPERLINE,d0
;	bsr	CopytoSRAM	;Copy stuff to SRAM
;	bne.s	.exit		;Failed? Exit
;
;	move.l	d0,8(a3)		;Buffer to receive
;
;	moveq.l	#op_WRITELINE,d0
;	lea.l	StdFollowUp(pc),a1
;	bsr	FireAction		;Go!
;	bra.s	.exit
;.error
;	bsr	FreeCmdSlot		;Won't use cmd
;	moveq.l	#FERR_LIBFAIL,d0
;.exit
;	movem.l	(sp)+,d7/a0-a1/a3-a5
;	rts


******* flyer.library/SetFillColor ******************************************
*
*   NAME
*	SetFillColor - set fill color to use for blank video
*
*   SYNOPSIS
*	error = SetFillColor(action)
*	D0                   A0
*
*	ULONG SetFillColor(struct ClipAction *);
*
*   FUNCTION
*	Sets the specified Matte color as the fill color to use for blank
*	video, such as when skipping lines with SkipLines or closing the
*	write before all scan lines are transferred.
*
*	This color remains valid for the context of this field only.
*	Defaults to black when a new field is opened.
*
*	The fields which need setup prior to calling SetFillColor:
*	   ca_FldHandle  - Field handle returned from successful
*	      OpenReadField or (Easy)OpenWriteField call
*	   ca_ReturnTime - RT_xxx value desired (not currently supported)
*	   ca_MatteY     - Luminance value
*	   ca_MatteI     - Signed I value
*	   ca_MatteQ     - Signed Q value
*
*   INPUTS
*	action - pointer to structure which contains:
*	   The field handle with which to associate this fill color
*	   The fill color (in YIQ color space)
*	   The return time for this call
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*
*   BUGS
*
*   SEE ALSO
*	CloseField
*	EasyOpenWriteField
*	OpenWriteField
*	FlyerWriteLine
*
*****************************************************************************
*	struct ClipAction *ptr (contains fhandle, YIQ)
*****************************************************************************
SetFillColor
	IFD	DEBUGVTASC
	DUMPMSG <SetFillColor>
	ENDC
	bra	SetFillColor2

;	movem.l	d7/a0-a1/a3-a5,-(sp)
;
;	move.l	ca_FldHandle(a0),d7	;fhandle
;
;	moveq.l	#0,d0		;Hard-wire to board 0 for now!!!
;				;Need to lookup from table of handles
;	bsr	Get_Brd_Cmd	;Get a free spot to place command
;	bne.s	.exit		;Failed? Exit
;
;	move.b	ca_ReturnTime(a0),cmd_RetTime(a4)	;User's return time
;
;	move.b	#1,2(a3)	;Continue flag
;	move.l	d7,4(a3)	;fhandle
;
;	move.w	ca_MatteY(a0),d0
;	move.b	d0,8(a3)		;Y
;	move.b	ca_MatteI(a0),9(a3)	;I
;	move.b	ca_MatteQ(a0),10(a3)	;Q
;
;	moveq.l	#op_SETFILLCOLOR,d0
;	lea.l	StdFollowUp(pc),a1
;	bsr	FireAction	;Go!
;.exit
;	movem.l	(sp)+,d7/a0-a1/a3-a5
	rts

******* flyer.library/SkipLines ******************************************
*
*   NAME
*	SkipLines - Seek past scan lines in a field previously opened
*
*   SYNOPSIS
*	error = SkipLines(action,lines)
*	D0                A0     D0
*
*	ULONG SkipLines(struct ClipAction *,UWORD);
*
*   FUNCTION
*	Seeks past a number of scan lines in a field previously opened.  If
*	opened for reading, skips over unwanted scan lines.  If opened for
*	writing, fills skipped lines with fillcolor (usually black).
*	Returns FERR_FULL if out of room in current field when writing.
*
*	The fields which need setup prior to calling SkipLines:
*	   ca_FldHandle   - Field handle returned from successful
*	                  - OpenReadField or (Easy)OpenWriteField call
*	   ca_ReturnTime  - RT_xxx value desired (not currently supported)
*
*   INPUTS
*	action - pointer to structure which contains the field handle to work
*	   with and the return time for this call.
*
*	lines - number of scan lines to skip
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*
*   BUGS
*
*   SEE ALSO
*	CloseField
*	EasyOpenWriteField
*	OpenReadField
*	OpenWriteField
*	FlyerReadLine
*	SetFillColor
*	FlyerWriteLine
*
*****************************************************************************
*	struct ClipAction *ptr -- contains fhandle
*****************************************************************************
SkipLines
	IFD	DEBUGVTASC
	DUMPMSG <SkipLines>
	ENDC
	bra	SkipLines2

;	movem.l	d6-d7/a0-a1/a3-a5,-(sp)
;
;	move.l	ca_FldHandle(a0),d7	;fhandle
;	move.w	d0,d6		;Keep # lines
;
;	moveq.l	#0,d0		;Hard-wire to board 0 for now!!!
;				;Need to lookup from table of handles
;	bsr	Get_Brd_Cmd	;Get a free spot to place command
;	bne.s	.exit		;Failed? Exit
;
;	move.b	ca_ReturnTime(a0),cmd_RetTime(a4)	;User's return time
;
;	move.b	#1,2(a3)	;Continue flag
;	move.l	d7,4(a3)	;fhandle
;	move.w	d6,8(a3)	;lines
;
;	moveq.l	#op_SKIPLINES,d0
;	lea.l	StdFollowUp(pc),a1
;	bsr	FireAction	;Go!
;.exit
;	movem.l	(sp)+,d6-d7/a0-a1/a3-a5
;	rts


*********************************************************************
* GetCompInfo -- Get info about a field's compression
*
* Entry:
*	a0:struct FlyerVolume *volume
*	a1:struct VidCompInfo *info
*	d0:field (0-3)
*	d1:lba
*	a6:Flyerbase (library)
*
* Exit:
*********************************************************************
GetCompInfo
	IFD	DEBUGGEN
	DUMPMSG <GetCompInfo>
	ENDC
	movem.l	d3/a0-a1/a3-a5,-(sp)

	bsr	Get_Vol_Cmd		;Get a free spot to place command
	bne.s	.exit			;Failed? Exit

	move.b	d0,5(a3)		;field
	move.l	d1,6(a3)		;lba

	move.b	fv_SCSIdrive(a0),4(a3)	;drive

	CLEAR	d0
	move.w	#VCI_sizeof,d0		;Size of structure
	move.l	d0,cmd_CopySize(a4)	;Copyback size

	bsr	AllocSRAM	;Need some SRAM
	tst.l	d0		;Failed?
	beq.s	.error

	move.l	d0,cmd_CopySrc(a4)	;Copyback src (SRAM ClipInfo)
	move.l	a1,cmd_CopyDest(a4)	;Copyback dest (caller's struct)
	sub.l	unit_SRAMbase(a5),d0	;Make offset to SRAM
	move.l	d0,10(a3)		;VidCompInfo structure offset

	moveq.l	#op_GETCOMPINFO,d0
	lea.l	FollowUpCopy(pc),a1	;Copyback when done
	bsr	FireCmd		;Go!
	bra.s	.exit
.error
	bsr	FreeCmdSlot		;Won't use cmd
	moveq.l	#FERR_LIBFAIL,d0
.exit
	movem.l	(sp)+,d3/a0-a1/a3-a5
	rts


******* flyer.library/AppendFields ******************************************
*
*   NAME
*	AppendFields - Capture live video field(s) and append to Flyer clip
*
*   SYNOPSIS
*	error = AppendFields(clip)
*	D0                   A0
*
*	ULONG AppendFields(struct ClipAction *);
*
*   FUNCTION
*	Captures live video field(s) and appends them to the specified Flyer
*	video clip.  Creates a new clip if it does not already exist.
*	Grabs correct field(s) from the captured color frames so that any
*	number of fields may be grabbed without concern for color phase.
*
*	Number of fields to record is specified in clip->ca_VidFieldCount.
*
*	This function always captures a new color frame.  Also, if the number
*	of fields specified spans more than one color frame, a new one is
*	captured for every new field 1 needed.  For example, if the current
*	clip needs a field 4 to be appended next and this function is called
*	with fields=3, a color frame is captured, and field 4 is appended.
*	Then a NEW color frame is captured and fields 1 and 2 are appended.
*	If this function is then called again with fields=3, a NEW color
*	frame is captured and fields 3 and 4 are appended.
*
*   INPUTS
*	clip - a ClipAction structure specifying the clip.
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*	This function is not guaranteed to capture consecutive color frames,
*	as the processing delays incurred may prohibit this.  This may make
*	capturing more than 4 fields at a time somewhat useless, yet perhaps
*	interesting.
*
*	This function does not fully support the CAF_VIDEO and CAF_AUDIOL/R
*	flags.  It always captures video only without audio.  It is also not
*	currently capable of capturing audio only.
*
*	Be careful when appending fields onto a clip that was recorded
*	"live", as no checking is done to see that the attributes of appended
*	fields are correct for the rest of the clip (such as VIDEO and/or
*	AUDIO flags).  Since audio is not currently supported by this
*	function, just be sure that fields are appended only to video-only
*	clips (or just build new clips using this function).
*
*   BUGS
*
*   SEE ALSO
*
*****************************************************************************
* AppendFields -- Append field(s) to Flyer clip
*
* Entry:
*	a0:struct ClipAction *ptr (contains fhandle)
*	a6:Flyerbase (library)
*
* Exit:
*	d0:error code or 0
*****************************************************************************
AppendFields
	IFD	DEBUGGEN
	DUMPMSG <AppendFields>
	ENDC

	movem.l	d1-d7/a1/a5,-(sp)

	move.l	ca_VidFieldCount(a0),d3		;Field counter

	IFD	DEBUGAPPEND
	DUMPHEXI.W <Wants to append >,d3,< fields\>
	ENDC

	moveq	#0,d0			;Board 0
	bsr	GetCardUnit		;in a5
	bne	.exit			;Failed? Exit

	moveq	#FERR_WRONGMODE,d0
	cmp.b	#CURMODE_REC,unit_Mode(a5)	;In REC mode?
	bne	.exit				;No? Error!

	moveq	#FERR_BADPARAM,d0
	tst.w	d3			;Non-0 fields to capture?
	beq	.exit
	subq.w	#1,d3			;Prepare for dbf loop

	IFD	DEBUGAPPEND
	move.l	ca_Volume(a0),a1
	move.l	fv_Path(a1),a1
	DUMPSTR	0(a1)
	DUMPMSG	< - Clip name>
	ENDC

;****** First thing to do is find field number to append next (0 thru 3)
	move.l	a0,-(sp)		;Save ClipAction
	move.l	ca_Volume(a0),a0	;Get volume only
	lea.l	fl_PrivClipInfo(a6),a1	;Get ClipInfo ptr
	move.w	#CI_sizeof,ci_len(a1)	;Prepare to receive this structure
	bsr	GetClipInfo
	move.l	(sp)+,a0
	tst.l	d0
	bne	.noclip			;Failed?
	move.l	fl_PrivClipInfo+ci_Fields(a6),d4
	and.b	#3,d4			;Next field to get (0-3)
	moveq	#FWF_APPEND,d5		;Use append mode only

	IFD	DEBUGAPPEND
	DUMPHEXI.B <Found clip, next is field >,d4,<\>
	ENDC

	bra.s	.yesclip

.noclip					;Clip not found, so make & append fields
	moveq	#FWF_APPEND!FWF_NEW,d5	;Make new clip and append field
	moveq	#0,d4			;Field # = 0

	IFD	DEBUGAPPEND
	DUMPMSG <Clip not found, field 0>
	ENDC

.yesclip
;****** If first field is not 0, do a "Capture Frame"
	tst.b	d4			;Will get field 0 anyway?
	beq.s	.nocapture

	IFD	DEBUGAPPEND
	DUMPMSG <*CAPTURE*>
	ENDC

	move.l	a0,-(sp)		;Save ClipAction
	move.l	ca_Volume(a0),a0	;Get volume only
	lea.l	fl_PrivCompInfo(a6),a1	;Where to put results
	moveq	#0,d0			;Field 0 triggers a new capture
	moveq	#0,d1			;LBA=0 for direct
	bsr	GetCompInfo		;Do a new color frame capture
	move.l	(sp)+,a0
	tst.l	d0
	bne	.exit			;Failed?
.nocapture

;****** The field loop! ******
.eachfield

	IFD	DEBUGAPPEND
	DUMPHEXI.B <*** Field >,d4,< ***\>
	ENDC

	move.l	a0,-(sp)		;Save ClipAction
	move.l	ca_Volume(a0),a0	;Get volume only
	lea.l	fl_PrivCompInfo(a6),a1	;Where to put results
	move.b	d4,d0			;Get info for next field
	moveq	#0,d1			;LBA=0 for direct
	bsr	GetCompInfo		;Do a new color frame capture
	move.l	(sp)+,a0
	tst.l	d0
	bne	.exit			;Failed?

	move.l	fl_PrivCompInfo+vci_DataStart(a6),d6	;Field's start DRAM blk
	move.l	fl_PrivCompInfo+vci_DataEnd(a6),d7	;(Field data end)
	sub.l	d6,d7			;Field length in blocks

	IFD	DEBUGAPPEND
	DUMPHEXI.L <  DRAM blk=>,d6,< >
	DUMPHEXI.L <  blocks=>,d7,<\>
	ENDC

;****** Now let Flyer prepare clip so that we may append a new field
	move.w	#VIDSIZE_1,fl_PrivCompInfo+vci_DataSize(a6)	;Grade 0 or 1

	clr.l	ca_FldHandle(a0)		;(Not used w/o VTASC)
	move.b	#RT_STOPPED,ca_ReturnTime(a0)	;Must be synchronous!
	lea.l	fl_PrivCompInfo(a6),a1		;VidCompInfo for new field
	moveq	#0,d0			;Field = don't care
	move.b	d5,d1			;Mode flags: APPEND ( | NEW )
	bsr	OpenWriteField1		;Have Flyer pick start/end points
	tst.l	d0			;Error? (e.g. FERR_FULL)
	bne	.exit			;(d1 = field, d2 = refnum)

	IFD	DEBUGAPPEND
	DUMPHEXI.L <  Ref# = >,d2,<\>
	ENDC

;****** Now copy captured field data to drive at location made by Flyer
	move.l	d2,-(sp)		;Save refnum

					;a0 = ClipAction
	move.l	d7,d0			;Blocks to write
	move.l	d6,d1			;DRAM address of field data start
	move.l	fl_PrivCompInfo+vci_DataStart(a6),d2	;LBA to receive data
	move.l	d2,d6
	add.l	d0,d6			;(Keep last block+1)
	bsr	Write10			;Write out to drive!
	move.l	(sp)+,d2
	tst.l	d0			;Error?
	bne	.exit

	IFD	DEBUGAPPEND
	DUMPMSG <  Write okay>
	ENDC

;****** Now let Flyer wrap things up neatly to make clip legal
	move.l	d2,d0			;Get Flyer reference number
	moveq.l	#1,d1			;Yes, we wrote stuff
	move.l	d6,d2			;Final LBA (just past end)
	bsr	CloseField1		;Let Flyer wrap things up
	tst.l	d0			;Error?
	bne	.exit

	IFD	DEBUGAPPEND
	DUMPMSG <  Close okay>
	ENDC

;****** Do all fields desired
	addq.l	#1,d4			;d4 = (d4+1) % 4
	and.b	#3,d4
	moveq	#FWF_APPEND,d5		;Just append any remaining fields
	dbf	d3,.eachfield

	moveq	#FERR_OKAY,D0
.exit
	movem.l	(sp)+,d1-d7/a1/a5
	rts



******* flyer.library/ResetFlyer ******************************************
*
*   NAME
*	ResetFlyer -- Reset Flyer to known state
*
*   SYNOPSIS
*	error = ResetFlyer(board,flags)
*	D0                 D0    D1
*
*	ULONG ResetFlyer(UBYTE,ULONG);
*
*   FUNCTION
*
*   INPUTS
*	board - specifies the Flyer board (0-3)
*
*	flags - misc flags (unused)
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*
*   BUGS
*
*   SEE ALSO
*
*****************************************************************************
ResetFlyer
	IFD	DEBUGGEN
	DUMPMSG <ResetFlyer>
	ENDC
	movem.l	a0-a1/a3-a5,-(sp)
	bsr	Get_Brd_Cmd	;Get a free spot to place command
	bne.s	.exit		;Failed? Exit

	move.l	d1,4(a3)	;Flags

	moveq.l	#op_RESETFLYER,d0
	lea.l	StdFollowUp(pc),a1
	bsr	FireCmd		;Go!
.exit
	movem.l	(sp)+,a0-a1/a3-a5
	rts


*****i* flyer.library/SetClockGen ******************************************
*
*   NAME
*	SetClockGen -- Set speed of 1 of the Flyer's 4 clock generators
*
*   SYNOPSIS
*	error = SetClockGen(board,clock,speed)
*	D0                  D0    D1    D2
*
*	ULONG SetClockGen(UBYTE,UBYTE,ULONG);
*
*   FUNCTION
*
*   INPUTS
*	board - specifies the Flyer board (0-3)
*
*	clock - code for which clock to set
*
*	speed - desired clock speed (in Hz)
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*
*   BUGS
*
*   SEE ALSO
*
*****************************************************************************
SetClockGen
	IFD	DEBUGGEN
	DUMPMSG <SetClockGen>
	ENDC
	movem.l	a0-a1/a3-a5,-(sp)
	bsr	Get_Brd_Cmd	;Get a free spot to place command
	bne.s	.exit		;Failed? Exit

	move.b	d1,4(a3)	;Clock #
	move.l	d2,6(a3)	;Speed

	moveq.l	#op_SETCLOCKGEN,d0
	lea.l	StdFollowUp(pc),a1
	bsr	FireCmd		;Go!
.exit
	movem.l	(sp)+,a0-a1/a3-a5
	rts


*****i* flyer.library/FlyerLoadVideo ******************************************
*
*   NAME
*	FlyerLoadVideo -- force video data into output buffer
*
*   SYNOPSIS
*	error = FlyerLoadVideo(board,addr,size)
*	D0                    D0     A0   D1
*
*	ULONG FlyerLoadVideo(UBYTE,APTR,ULONG);
*
*   FUNCTION
*
*   INPUTS
*	board - specifies the Flyer board (0-3)
*
*	addr - pointer to video data to load
*
*	size - size of data (in bytes)
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*
*   BUGS
*
*   SEE ALSO
*
*****************************************************************************
LoadVideo
	IFD	DEBUGGEN
	DUMPMSG <LoadVideo>
	ENDC

	movem.l	a0-a1/a3-a5,-(sp)

	bsr	Get_Brd_Cmd	;Get a free spot to place command
	bne.s	.exit		;Failed? Exit

	move.l	d1,8(a3)	;Size

	move.l	d1,d0
	add.l	#512,d0		;d0=amount (extra 512 for block alignment)
	bsr	AllocSRAM	;Get SRAM memory for use
	tst.l	d0		;Succeeded?
	beq.s	.error

	add.l	#511,d0
	and.l	#$FFFFFE00,d0	;Round up to next DMA boundary

				;a0=src ptr
	move.l	d0,a1		;dest ptr
	move.l	d1,d0		;length
	bsr	FastCopy	;Copy source data

	move.l	a1,d0		;Return address of SRAM (offset)
	sub.l	unit_SRAMbase(a5),d0

;	move.l	a0,a1		;a1 = src ptr
;	move.l	d1,d0		;d0 = size
;	bsr	CopytoSRAM	;Copy stuff to SRAM
;	bne.s	.exit		;Failed? Exit

	move.l	d0,4(a3)	;RAM address

	moveq.l	#op_LOADVID,d0
	lea.l	StdFollowUp(pc),a1
	bsr	FireCmd		;Go!
	bra.s	.exit
.error
	bsr	FreeCmdSlot		;Won't use cmd
	moveq.l	#FERR_LIBFAIL,d0
.exit
	movem.l	(sp)+,a0-a1/a3-a5
	rts


******* flyer.library/SetSerDevice ******************************************
*
*   NAME
*	SetSerDevice - Select type of device attached to a Flyer serial port
*
*   SYNOPSIS
*	error = SetSerDevice(board,port,type,device)
*	D0                   D0    D1   D2   D3
*
*	ULONG SetSerDevice(UBYTE,UBYTE,UBYTE,UBYTE);
*
*   FUNCTION
*	Specifies the type and model of device which the user wishes to
*	attach to one of the Flyer's two serial ports.  These ports can be
*	used for a variety of things such as SMPTE read, SMPTE write, MIDI,
*	serial control, etc.  The Flyer will take care of details such as the
*	baud rate, format conversion, etc. for all devices defined in Flyer.h
*
*   INPUTS
*	board - specifies the Flyer board (0-3)
*
*	port - specifies the serial port (0 = A, 1 = B)
*
*	type - type of serial device (SERDEVTYPE_xxx in Flyer.h)
*
*	device - device model (SERDEV_xxx in Flyer.h)
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*
*   BUGS
*
*   SEE ALSO
*
*****************************************************************************
SetSerDevice
	IFD	DEBUGGEN
	DUMPMSG <SetSerDevice>
	ENDC
	movem.l	a0-a1/a3-a5,-(sp)
	bsr	Get_Brd_Cmd	;Get a free spot to place command
	bne.s	.exit		;Failed? Exit

	move.b	d1,4(a3)	;Port (0,1)
	move.b	d2,5(a3)	;Device type
	move.b	d3,6(a3)	;Device sub-code

	moveq.l	#op_SERDEVICE,d0
	lea.l	StdFollowUp(pc),a1
	bsr	FireCmd		;Go!
.exit
	movem.l	(sp)+,a0-a1/a3-a5
	rts


******* flyer.library/LockFlyVolList ******************************************
*
*   NAME
*	LockFlyVolList - obtain lock on internal Flyer volumes list
*
*   SYNOPSIS
*	ptr = LockFlyVolList()
*	D0
*
*	struct MinList *LockFlyVolList(void);
*
*   FUNCTION
*	Returns a pointer to a MinList containing the currently mounted Flyer
*	volumes.  Also locks this list so that you may safely inspect it.  No
*	modifications to the list are allowed.  Be sure to release lock using
*	UnLockFlyVolList.
*
*	A return value of 0 indicates a failure.
*
*   INPUTS
*
*   RESULT
*	ptr - pointer to a MinList of Flyer Volume Node structures
*	   (or 0 for failure)
*
*   EXAMPLE
*
*   NOTES
*
*   BUGS
*
*   SEE ALSO
*	UnLockFlyVolList
*
*****************************************************************************
LockFlyVolList
	IFD	DEBUGGEN
	DUMPMSG <LockVolList>
	ENDC

	move.l	a0,-(sp)
	lea.l	fl_Volumes(a6),a0
	move.l	a0,d0
	move.l	(sp)+,a0
	rts


******* flyer.library/UnLockFlyVolList ******************************************
*
*   NAME
*	UnLockFlyVolList - release lock on Flyer volumes list
*
*   SYNOPSIS
*	error = UnLockFlyVolList(list)
*	D0                       A0
*
*	ULONG UnLockFlyVolList(struct MinList *);
*
*   FUNCTION
*	Releases the lock obtained using LockFlyVolList.
*
*	Like most other library functions, a return value of FERR_OKAY
*	indicates success.
*
*   INPUTS
*	list - pointer to list (previously obtained with LockFlyVolList)
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*
*   BUGS
*
*   SEE ALSO
*	LockFlyVolList
*
*****************************************************************************
UnLockFlyVolList
	IFD	DEBUGGEN
	DUMPMSG <UnLockVolList>
	ENDC

;No list locking implemented yet, but at least we have the mechanism in place
;should this become necessary in the future

	rts


******* flyer.library/TBCcontrol ******************************************
*
*   NAME
*	TBCcontrol - Sense/control TBC functions
*
*   SYNOPSIS
*	error = TBCcontrol(board,TBCctrl,oper)
*	D0                 D0    A0      D1
*
*	ULONG TBCcontrol(UBYTE,struct TBCctrl *,UBYTE);
*
*   FUNCTION
*	Provides access to the (optional) Flyer TBC module.
*
*	The "oper" flags describe which portions of the TBCctrl structure to
*	apply.  This allows somewhat simplified use of this command without
*	always needing to set all values for each call, as well as the
*	ability to check the TBC status flags without modifying anything.
*
*	To determine if the TBC module is present, use this function setting
*	only the TBCOF_STATUS oper flag, then check the "status" flags
*	returned for TBCSF_MODULE to indicate that one was detected.
*
*   INPUTS
*	board - specifies the Flyer board (0-3)
*
*	TBCctrl - pointer to TBCctrl structure
*
*	oper - various flags indicating what kind of operation(s) to perform:
*
*	   TBCOF_STATUS  -- get status flags
*	   TBCOF_MODES   -- set modes, flags, and muxes
*	   TBCOF_ADJUST  -- set adjustment values
*
*	   Any combination of these operations can be specified.
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*	If no TBC module is present, an error will be reported if this
*	command is used for anything except to get status
*
*   BUGS
*
*   SEE ALSO
*	FlyerInputSel
*	flyer.h
*
*****************************************************************************
TBCcontrol
	IFD	DEBUGGEN
	DUMPMSG <TBCctrl>
	ENDC
	movem.l	a0-a1/a3-a5,-(sp)

	bsr	Get_Brd_Cmd	;Get a free spot to place command
	bne.s	.exit		;Failed? Exit

	move.b	d1,8(a3)	;Op flags

	moveq.l	#1,d0		;Amount of structure to copy-back
	move.l	d0,cmd_CopySize(a4)
	move.l	a0,cmd_CopyDest(a4)	;Save for later (caller's ptr)

	moveq.l	#TBC_sizeof,d0	;Length of structure
	move.l	a0,a1		;Src structure
	bsr	CopytoSRAM	;Copy structure to shared RAM
	bne.s	.exit		;Failed? Exit

	move.l	d0,4(a3)	;SRAM addr

	add.l	unit_SRAMbase(a5),d0	;Convert from offset to ptr
	move.l	d0,cmd_CopySrc(a4)	;Ptr to SRAM area

	moveq.l	#op_TBC,d0
	lea.l	FollowUpCopy(pc),a1	;Copyback when done
	bsr	FireCmd		;Go!

.exit
	movem.l	(sp)+,a0-a1/a3-a5
	rts


******* flyer.library/FlyerAudioCtrl ******************************************
*
*   NAME
*	FlyerAudioCtrl - Sense/control audio rec level/aux input functions
*
*   SYNOPSIS
*	error = FlyerAudioCtrl(board,FlyAudCtrl,oper)
*	D0                     D0    A0         D1
*
*	ULONG FlyerAudioCtrl(UBYTE,struct FlyAudCtrl *,UBYTE);
*
*   FUNCTION
*	Provides access to the Flyer's audio subsystem.  This provides a
*	means of smartly setting the input gain on record, as well as control
*	over the Flyer's auxilliary audio inputs.
*
*	The "oper" flags describe which portions of the FlyAudCtrl structure
*	to apply.  This allows modification of individual values, and the
*	ability to sense input levels without changing any values.
*
*   INPUTS
*	board - specifies the Flyer board (0-3)
*
*	FlyAudCtrl - pointer to FlyAudCtrl structure
*
*	oper - various flags indicating what kind of operation(s) to perform:
*	   FACOF_SENSE   -- update LeftSense/RightSense values
*	   FACOF_SENSE8  -- update LeftSense/RightSense with 8-bit values
*	   FACOF_SETGAIN -- set input gain (for recording)
*	   FACOF_SETSRC  -- set the input selector mux
*	   FACOF_SETMIX  -- set auxilliary channel mixing values
*
*	   Any combination of these operations can be specified.
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*	The LeftSense and RightSense values from FACOF_SENSE are interpreted:
*	   0 -- over -1.0 dB underrange
*	   1 -- 0 to -1.0 dB underrange
*	   2 -- 0 to 1.0 dB overrange
*	   3 -- over 1.0 dB overrange
*	FACOF_SENSE8 causes Left/RightSense to contain 8 bit peak-reading
*	values (low 8 bits truncated off)
*
*   BUGS
*
*   SEE ALSO
*	flyer.h
*
*****************************************************************************
AudioControl
	IFD	DEBUGGEN
	DUMPMSG <AudioCtrl>
	ENDC
	movem.l	a0-a1/a3-a5,-(sp)

	bsr	Get_Brd_Cmd	;Get a free spot to place command
	bne.s	.exit		;Failed? Exit

	move.b	d1,8(a3)	;Op flags

	moveq.l	#4,d0		;Amount of structure to copy-back
	move.l	d0,cmd_CopySize(a4)
	move.l	a0,cmd_CopyDest(a4)	;Save for later (caller's ptr)

	moveq.l	#FAC_sizeof,d0	;Length of structure
	move.l	a0,a1		;Src structure
	bsr	CopytoSRAM	;Copy structure to shared RAM
	bne.s	.exit		;Failed? Exit

	move.l	d0,4(a3)	;SRAM addr

	add.l	unit_SRAMbase(a5),d0	;Convert from offset to ptr
	move.l	d0,cmd_CopySrc(a4)	;Ptr to SRAM area

	moveq.l	#op_CODECCTRL,d0
	lea.l	FollowUpCopy(pc),a1	;Copyback when done
	bsr	FireCmd		;Go!

.exit
	movem.l	(sp)+,a0-a1/a3-a5
	rts



******* flyer.library/GetFrameHeader **********************************
*
*   NAME
*	GetFrameHeader -- Read Frame Header structure from clip
*
*   SYNOPSIS
*	error = GetFrameHeader(action,buffer)
*	D0                     A0     A1
*
*	ULONG GetFrameHeader(struct ClipAction *,APTR);
*
*   FUNCTION
*	Retrieves a copy of a specific FrameHeader structure from an audio
*	or video clip.  FrameHeader chosen is the one that contains the field
*	number specified in ca_VidStartField (even for audio clips).
*	Places data at the structure pointed to by "buffer".
*
*	If the return value is not FERR_OKAY, something went wrong (such as
*	the clip was not found, or the requested field number is out of range).
*
*	Note: on success, clipaction->ca_StartBlk will contain the actual
*	block number where the frame header is found, and
*	clipaction->ca_Volume->fv_SCSIdrive will contain the actual drive number.
*
*   INPUTS
*	clipaction - specifies the volume/clip name and the desired field number
*
*	buffer - Pointer to caller's structure to fill in
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*
*   BUGS
*
*   SEE ALSO
*	PutFrameHeader
*
*****************************************************************************
GetFrameHeader
	IFD	DEBUGGEN
	DUMPMSG <GetFrameHeader>
	ENDC
	movem.l	d1-d2/a0-a1/a3-a5,-(sp)

	moveq	#0,d0			;Card 0
	bsr	GetCardUnit		;Get a5 for Flyer card
	bne	.exit			;Failed? Exit

	move.b	#RT_STOPPED,ca_ReturnTime(a0)	;Must be synchronous!
	bsr	LocateField		;a0=action
	tst.b	d0			;Error?
	bne.s	.exit

	moveq	#1,d0			;Read just 1 block
	move.l	ca_StartBlk(a0),d1	;From here
	move.l	#VTASCDRAM,d2		;To here
	bsr	Read10
	tst.b	d0			;Error?
	bne.s	.exit

	move.l	a1,-(sp)		;Save user buffer ptr
	moveq	#0,d0			;Board 0
	move.l	#VTASCSRAM,d1
	move.l	d1,a0			;CPU block ptr
	move.l	#VTASCDRAM,d1
	move.l	d1,a1			;DMA block ptr
	moveq	#1,d1			;Just 1 block
	moveq	#0,d2			;Write from DRAM to SRAM
	bsr	CPUDMA
	move.l	(sp)+,a1		;Restore user buffer ptr
	tst.b	d0			;Error?
	bne.s	.exit

	move.l	unit_SRAMbase(a5),d0
	add.l	#VTASCSRAMADDR,d0
	move.l	d0,a0			;a0=src to copy
	move.l	#512,d0			;Bytes to move
					;a1=caller's buffer
	bsr	FastCopy		;Move into caller's buffer
	moveq	#FERR_OKAY,d0

.exit
	movem.l	(sp)+,d1-d2/a0-a1/a3-a5
	rts


******* flyer.library/PutFrameHeader **********************************
*
*   NAME
*	PutFrameHeader -- Write Frame Header structure back to clip
*
*   SYNOPSIS
*	error = PutFrameHeader(action,buffer)
*	D0                     A0     A1
*
*	ULONG PutFrameHeader(struct ClipAction *,APTR);
*
*   FUNCTION
*	Replaces a specific FrameHeader structure in an audio or video clip
*	with the data structure provided.  FrameHeader chosen is the one
*	that contains the field number specified in ca_VidStartField (even
*	for audio clips).
*
*	If the return value is not FERR_OKAY, something went wrong (such as
*	the clip was not found, or the requested field number is out of range).
*
*	CAUTION! This function is intended to be used to read/modify/write
*	a Frame Header (using GetFrameHeader).  It is dangerous and unwise
*	to hand-craft a header from scratch and plug it in.  Doing so
*	is very difficult and is bound to cause problems.  Also, be very
*	cautious when modifying data in this structure.  The only thing
*	that's safe/useful to modify is the SerData buffer and associated
*	control values.  All else is toxic, flammable, noxious, etc.
*
*   INPUTS
*	clipaction - specifies the volume/clip name and the desired field number
*
*	buffer - Pointer to caller's structure to fill in
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*
*   BUGS
*
*   SEE ALSO
*	GetFrameHeader
*
*****************************************************************************
PutFrameHeader
	IFD	DEBUGGEN
	DUMPMSG <PutFrameHeader>
	ENDC
	movem.l	d1-d2/a0-a1/a3-a5,-(sp)

	moveq	#0,d0			;Card 0
	bsr	GetCardUnit		;Get a5 for Flyer card
	bne	.exit			;Failed? Exit

	move.l	a0,-(sp)		;Save CA ptr
	move.l	a1,a0			;a0=caller's buffer
	move.l	unit_SRAMbase(a5),d0
	add.l	#VTASCSRAMADDR,d0
	move.l	d0,a1			;a1=dest
	move.l	#512,d0			;Bytes to move
	bsr	FastCopy		;Move from caller's buffer to SRAM
	move.l	(sp)+,a0		;Restore CA ptr

	move.b	#RT_STOPPED,ca_ReturnTime(a0)	;Must be synchronous!
	bsr	LocateField		;a0=action
	tst.b	d0			;Error?
	bne.s	.exit

	move.l	a0,-(sp)		;Save CA ptr
	moveq	#0,d0			;Board 0
	move.l	#VTASCSRAM,d1
	move.l	d1,a0			;CPU block ptr
	move.l	#VTASCDRAM,d1
	move.l	d1,a1			;DMA block ptr
	moveq	#1,d1			;Just 1 block
	moveq	#1,d2			;Read to DRAM from SRAM
	bsr	CPUDMA
	move.l	(sp)+,a0		;Restore CA
	tst.b	d0			;Error?
	bne.s	.exit

	moveq	#1,d0			;Write just 1 block
	move.l	#VTASCDRAM,d1		;From here
	move.l	ca_StartBlk(a0),d2	;To here
	bsr	Write10

.exit
	movem.l	(sp)+,d1-d2/a0-a1/a3-a5
	rts


*****i* flyer.library/FlyerSelfTest ******************************************
*
*   NAME
*	FlyerSelfTest -- Run Flyer self-test tool
*
*   SYNOPSIS
*	error = FlyerSelfTest(board,test,arg1,arg2,result)
*	D0                    D0    D1   D2   D3   A0
*
*	ULONG FlyerSelfTest(UBYTE,UBYTE,ULONG,ULONG,ULONG *);
*
*   FUNCTION
*
*   INPUTS
*	board - specifies the Flyer board (0-3)
*
*	test - test code to perform
*
*	arg1 - first arg for test
*
*	arg2 - second arg for test
*
*	result - pointer to variable to receive test results
*
*   RESULT
*
*   EXAMPLE
*
*   NOTES
*
*   BUGS
*
*   SEE ALSO
*
*****************************************************************************
SelfTest
	IFD	DEBUGGEN
	DUMPMSG <SelfTest>
	ENDC
	movem.l	a0-a1/a3-a5,-(sp)
	bsr	Get_Brd_Cmd	;Get a free spot to place command
	bne.s	.exit		;Failed? Exit

	move.l	a0,cmd_CopyDest(a4)	;Save for later

	move.b	d1,4(a3)	;Test
	move.l	d2,6(a3)	;arg1
	move.l	d3,10(a3)	;arg2

	moveq.l	#op_SELFTEST,d0
	lea.l	.FollowUp(pc),a1
	bsr	FireCmd		;Go!
.exit
	movem.l	(sp)+,a0-a1/a3-a5
	rts

.FollowUp			;Can trash a0,a1,d0
	move.l	cmd_CopyDest(a4),d0
	beq.s	.avoid
	move.l	d0,a0
	move.l	14(a3),d0	;Get result code
	move.l	d0,(a0)
.avoid
	move.b	3(a3),d0	;Get error code
	rts


******* flyer.library/Error2String ******************************************
*
*   NAME
*	Error2String - Convert a Flyer error code into an error string
*
*   SYNOPSIS
*	desc = Error2String(error)
*	                    D0
*
*	char * Error2String(UBYTE);
*
*   FUNCTION
*	Gives an descriptive string for the supplied Flyer error code.
*	Simply returns a pointer to the string.  DO NOT MODIFY THE DATA IN
*	THIS STRING.
*
*   INPUTS
*	error - an error code returned by a Flyer call
*
*   RESULT
*	desc - pointer to a static string which describes the error condition
*
*   EXAMPLE
*
*   NOTES
*	Does not currently convert some of the more "internal" Flyer errors,
*	but just gives "???".
*
*   BUGS
*
*   SEE ALSO
*
*****************************************************************************
Error2String
	IFD	DEBUGGEN
	DUMPMSG <Error2String>
	ENDC
	move.l	a0,-(sp)
	lea.l	ErrorStrings(pc),a0
.loop
	cmp.b	#-1,(a0)	;End of list?
	beq.s	.none
	cmp.b	(a0)+,d0	;Match?
	beq.s	.match
.skip
	tst.b	(a0)+		;No, skip to next
	bne.s	.skip
	bra.s	.loop

.none
	addq.l	#1,a0
.match
	move.l	a0,d0		;Return string ptr in d0
	move.l	(sp)+,a0
	rts


ErrorStrings
	dc.b	FERR_OKAY,'Okay',0
	dc.b	FERR_CMDFAILED,'Command failed',0
	dc.b	FERR_BUSY,'Busy',0
	dc.b	FERR_ABORTED,'Aborted',0
	dc.b	FERR_BADPARAM,'Bad command parameter',0
	dc.b	FERR_BADCOMMAND,'Unknown command',0
	dc.b	FERR_BADVIDHDR,'Bad clip header',0
	dc.b	FERR_WRONGMODE,'Wrong play/rec mode',0
	dc.b	FERR_OLDDATA,'Incompatible clip data',0
	dc.b	FERR_NOAUDIOCHAN,'No free audio channel(s)',0
	dc.b	FERR_CHANINUSE,'Channel in use',0
	dc.b	FERR_BADFLDHAND,'Bad field handle',0
	dc.b	FERR_CLIPLATE,'Clip late',0
	dc.b	FERR_DROPPEDFLDS,'Dropped fields',0

	dc.b	FERR_NOTASKS,'No free SCSI task',0
	dc.b	FERR_LISTCORRUPT,'Internal list corrupt',0
	dc.b	FERR_NOTINRANGE,'Not in list',0
	dc.b	FERR_EEFAILURE,'EEPROM failure',0
	dc.b	FERR_NOFINDERS,'No free FrameFinder',0
	dc.b	FERR_BADMODULE,'Incompatible module',0

	dc.b	FERR_OBJNOTFOUND,'Clip/file not found',0
	dc.b	FERR_FULL,'Drive full',0
	dc.b	FERR_DIRFULL,'Directory full',0
	dc.b	FERR_EXHAUSTED,'Dir list exhausted',0
	dc.b	FERR_FSFAIL,'FileSystem failure',0
	dc.b	FERR_WRONGTYPE,'Wrong type of object',0
	dc.b	FERR_UNFORMATTED,'Drive not formatted',0
	dc.b	FERR_EXCLUDED,'Exclusive lock prevents action',0
	dc.b	FERR_OUTOFRANGE,'Seek out of range',0
	dc.b	FERR_CANTEXTEND,'Cannot extend file',0
	dc.b	FERR_PROTECTED,'Drive write-protected',0
	dc.b	FERR_DIFFERENT,'Different objects',0
	dc.b	FERR_EXISTS,'File already exists',0
	dc.b	FERR_NOMEM,'Out of memory',0
	dc.b	FERR_DELPROT,'File delete-protected',0
	dc.b	FERR_READPROT,'File read-protected',0
	dc.b	FERR_WRITEPROT,'File write-protected',0
	dc.b	FERR_INUSE,'Disk/object in use',0
	dc.b	FERR_DIRNOTEMPTY,'Directory not empty',0

	dc.b	FERR_SELTIMEOUT,'Drive not present',0
	dc.b	FERR_BADSTATUS,'SCSI error',0
	dc.b	FERR_LOGBLKSIZE,'Cannot handle this logical block size',0
	dc.b	FERR_INCOMPLETE,'SCSI tranfer not completed fully',0

	dc.b	FERR_WRONGDATATYPE,'Improper content requested',0
	dc.b	FERR_DRIVEINCAPABLE,'Not on video-ready drive',0
	dc.b	FERR_NO_BROLLDRIVE,'No video B-roll drive found',0
	dc.b	FERR_HEADFAILED,'A/B head missing or failure',0

	dc.b	FERR_NOCARD,'Flyer card not found',0
	dc.b	FERR_LIBFAIL,'Library failure',0
	dc.b	FERR_ASYNCFAIL,'Asynchronous failure',0
	dc.b	FERR_VOLNOTFOUND,'Volume name not found',0
	dc.b	FERR_NOFREECMD,'Flyer SRAM clogged',0
	dc.b	FERR_BADID,'Bad async ID',0

	dc.b	-1,'???',0

	CNOP	0,2


;Pattern:
;	IFD	DEBUGGEN
;	DUMPMSG <Pattern>
;	ENDC
;	move.l	d1,-(sp)
;
;	move.l	#$EC0000,a0
;	add.l	#CMDBASE,a0
;	move.l	#MAX_FLYER_CMDS-1,d1
;.loop1	clr.w	(a0)+
;	move.l	#((FLYER_CMD_LEN-2)/2)-1,d0
;.loop2	move.w	#$5678,(a0)+
;	dbf	d0,.loop2
;	dbf	d1,.loop1
;
;	move.l	#$EC0000,a0
;	move.l	#CMDBASE+(MAX_FLYER_CMDS*FLYER_CMD_LEN),d0
;	add.l	d0,a0			;Skip to shared data area
;	move.l	#((SHAREDTOP-CMDBASE-(MAX_FLYER_CMDS*FLYER_CMD_LEN))/2)-1,d0
;.clrSRAM
;	move.w	#$1234,(a0)+		;Recognizable pattern in SRAM
;	dbf	d0,.clrSRAM
;	CLEAR	d0
;	move.l	(sp)+,d1
;	rts
;
;BigPattern:
;	move.l	#$EC0000,a0
;	move.l	#(CMDBASE/2)-1,d0
;.clrSRAM2
;	move.w	#$DEAD,(a0)+		;Recognizable pattern in SRAM
;	dbf	d0,.clrSRAM2
;
;	move.l	#$EC0000,a0
;	move.l	#CMDBASE+(MAX_FLYER_CMDS*FLYER_CMD_LEN),d0
;	add.l	d0,a0			;Skip to shared data area
;	move.l	#((PROGAREA-CMDBASE-(MAX_FLYER_CMDS*FLYER_CMD_LEN))/2)-1,d0
;.clrSRAM
;	move.w	#$ABCD,(a0)+		;Recognizable pattern in SRAM
;	dbf	d0,.clrSRAM
;	CLEAR	d0
;	rts


;EnsureVolume
;	cmp.w	#0,a0			;A Null structure ptr?
;	bne.s	.gotavol
;	lea.l	GratisVolume(pc),a0	;If so, use my structure
;	clr.b	fv_Board(a0)		;Should someday scan all Flyers
;	clr.b	fv_SCSIdrive(a0)	;Best defaults I can provide
;.gotavol
;	rts


*********************************************************************
* FreeChipDef -- Deallocate memory for/throw away old chip definition
*
* Entry:
*	a0:Ptr to allocation pair in Flyer library
*	a6:ExecBase
*
* Exit:
*********************************************************************
FreeChipDef:
	movem.l	d0-d1/a0-a1,-(sp)
	tst.l	(a0)		;Need to free old definition?
	beq.s	.nodefclear
	move.l	4(a0),d0	;Size of old def
	move.l	(a0),a1		;Ptr to old def
	clr.l	(a0)		;Clear pointer from library (do not use)
	XSYS	FreeMem		;Free definition
.nodefclear
	movem.l	(sp)+,d0-d1/a0-a1
	rts


*********************************************************************
* FreeRenameList -- free list of rename nodes (cutting room)
*
* Entry:
*	a6:Flyerbase (library)
*
* Exit:
*********************************************************************
FreeRenameList:
	movem.l	d0-d1/a0-a1/a4-a6,-(sp)

	move.l	a6,a5
	move.l	fl_SysLib(a5),a6

	move.l	fl_RenameList(a5),a1
.loop
	cmp.w	#0,a1		;Another one?
	beq	.exit
	move.l	frn_Next(a1),a4		;Keep next in list
	move.l	frn_Length(a1),d0	;Struct length

	IFD	DEBUGCLIPCUT
	DUMPHEXI.L <*** Free Ptr  >,a1,< ***\>
	DUMPHEXI.L <*** Free Size >,d0,< ***\>
	ENDC

	XSYS	FreeMem			;Free structure
	move.l	a4,a1			;next
	bra	.loop

.exit
	clr.l	fl_RenameList(a5)	;Gone!

	movem.l	(sp)+,d0-d1/a0-a1/a4-a6
	rts



*********************************************************************
* MaybeClearCache -- On systems w/ cache problem, flush data cache
*
* Entry:
*	a6:Flyerbase (library)
*
* Exit:
*********************************************************************
MaybeClearCache
;;On systems where we determined that our board is being data cached, flush cache
;;here so that we can retrieve data from Flyer without the risk of it being stale
	btst	#FLB_CACHED,fl_PrivFlags(a6)	;Need to flush cache on this machine
	beq.s	.noflush
	movem.l	d0-d1/a0-a1/a6,-(sp)
	move.l	fl_SysLib(a6),a6	;Get ExecBase
	XSYS	CacheClearU		;Flush data cache!
	IFD	DEBUGCACHE
	DUMPTXT <*>
	ENDC
	movem.l	(sp)+,d0-d1/a0-a1/a6
.noflush
	rts



	CNOP	0,2
TempNameArea:	ds.b	10		;Build temp names here

;
;GratisVolume	ds.b	FV_sizeof	;When user supplies no volume
;

	CNOP	0,2

*******************************************************
* Debugging stuff

	IFNE	SERDEBUG
	HXDUMP
	HDUMP
	ENDC

	end
