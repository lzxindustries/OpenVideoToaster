/********************************************************************
* cgrexx.c 
* Copyright (c)1994 NewTek, Inc.
* Confidental and Proprietary. All rights reserved.
* $Id: cgrexx.c,v 2.1 1995/11/15 19:14:38 Holt Exp $
* $Log: cgrexx.c,v $
 * Revision 2.1  1995/11/15  19:14:38  Holt
 * put in kanhi changes
 *
 * Revision 2.0  1995/08/31  15:27:31  Holt
 * FirstCheckIn
 *
*********************************************************************/
/********************************************************************
* cgrexx.c
*
* Copyright �1993 NewTek, Inc.
* Confidental and Proprietary. All rights reserved.
*
* CG Arexx functions
* Thu Jan 13 16:54:20 1994
* Apr  1 1994
* Sat Oct 15 13:27:56 1994
* Oct 18 1994
* Sun Nov 20 15:57:15 1994
****************/
#include <exec/nodes.h>
#include <exec/libraries.h>
#include <exec/lists.h>
#include <exec/types.h>
#include <clib/exec_protos.h>
#include <clib/dos_protos.h>
#include <stdarg.h>
#include <ctype.h>
#include <string.h>
#include <proto/exec.h>
#include <proto/dos.h>
#include <intuition/intuition.h>
#include <rexx/storage.h>
#include <rexx/rxslib.h>
#include <rexx/errors.h>
#include <devices/serial.h>
#include <libraries/dos.h>
#include <stdio.h>
#include <Book.h>
#include <NewSupport.h>
#include <toastfont.h>
#include <psfont.h>
#include <commonrgb.h>

// Homemade prototypes
#ifndef PROTO_PASS
#include <protos.h>
BOOL __asm CaseDelete(register __a0 struct IntuiMessage *);
BOOL __asm CaseDown(register __a0 struct IntuiMessage *);
void __asm RenderEditLine(register __a0 struct CGLine *);

#endif

extern char           *CreateArgstring( char *str, ULONG length );
extern void            DeleteArgstring( char *argstr );
extern struct RexxMsg *CreateRexxMsg( struct MsgPort *replyport,
                                      char *extension, char *hostaddress );
extern void            DeleteRexxMsg( struct RexxMsg *msg );
extern void            ClearRexxMsg( struct RexxMsg *msg, ULONG numargs );
extern long            FillRexxMsg( struct RexxMsg *msg, ULONG numargs, ULONG mask );
extern long            IsRexxMsg( struct RexxMsg *msg );

extern struct RenderData *RD;
extern char PSMess[];
extern char but0[],but1[],but2[],but3[],dir0[],dir1[],dir2[],dir3[];

extern int PSFontFlags;
extern ULONG RawKeyTable[];
struct RxsLib *RexxSysBase = NULL;
struct MsgPort *CGRexxPort = NULL, *FEP_ReplyPort = NULL;
struct RexxMsg *FEPmsg;
struct IntuiMessage intuidummy;
char  *Edit,*Addr,*Begin,*Intuimsg,*Verify,*CodeWord,*codebuf;
BOOL FEP_Enable=FALSE;

//#define SERDEBUG 1
#ifndef SERDEBUG
#define DumpStr(x)	{}
#define DumpMsg(x)	{}
#endif

#define BEGIN_CMD       "FEP_BEGIN"
#define EDIT_CMD        "FEP_EDIT"
#define INTUIMSG_CMD    "FEP_INTUIMSG"
#define VERIFY_CMD      "FEP_VERIFYFONT"

#define   MIN_COMPCODE  0x81
#define   MAX_COMPCODE  0xFE

#define RX_PORT_NAME    "CG_AREXX"
#define FEP_PORT_NAME   "FEP.PORT"
#define FEPREP_PORT_NAME  "FEP_REPLY.PORT"
#define CG_CONFIG			"CG_Support/CG-Config"
#define IS_REPLY(m)     ( m->rm_Node.mn_Node.ln_Type == NT_REPLYMSG )
#define IS_FUNCTION(m)  ( (m->rm_Action & RXCODEMASK) == RXFUNC )
#define HAS_RESULT(m)   ( m->rm_Action & RXFF_RESULT )
#define ARG_NUM(m)      ((int)(m->rm_Action & RXARGMASK))
#define ARG3(rmp) (rmp->rm_Args[3])
#define ARG4(rmp) (rmp->rm_Args[4])
#define ARG5(rmp) (rmp->rm_Args[5])
#define ARG6(rmp) (rmp->rm_Args[6])
#define MAX_RESULT      256
#define NO_MATCH        -1
#define RED(tc)         ( ((UBYTE *)&tc)[0] )
#define GREEN(tc)       ( ((UBYTE *)&tc)[1] )
#define BLUE(tc)        ( ((UBYTE *)&tc)[2] )
#define ALPHA(tc)       ( ((UBYTE *)&tc)[3] )
#define NOT_READY       "Not available at present"

#define REG register
#define RAW_RETURN    0x44
#define RAW_F1		    0x50

#define MACRO_MAX 56
#define MACRO_COUNT 19 // highest macro index
char mac1[MACRO_MAX]="CG1",mac2[MACRO_MAX]="CG2",mac3[MACRO_MAX]="CG3",
	mac4[MACRO_MAX]="CG4",mac5[MACRO_MAX]="CG5",mac6[MACRO_MAX]="CG6",mac7[MACRO_MAX]="CG7",
	mac8[MACRO_MAX]="CG8",mac9[MACRO_MAX]="CG9",mac10[MACRO_MAX]="CG10",
	mac11[MACRO_MAX]="CG11",mac12[MACRO_MAX]="CG12",mac13[MACRO_MAX]="CG13",
	mac14[MACRO_MAX]="CG14",mac15[MACRO_MAX]="CG15",mac16[MACRO_MAX]="CG16",mac17[MACRO_MAX]="CG17",
	mac18[MACRO_MAX]="CG18",mac19[MACRO_MAX]="CG19",mac20[MACRO_MAX]="CG20",StartupMac[MACRO_MAX]="";
//char	FontPath[MAX_PATH],PagePath[MAX_PATH],BookPath[MAX_PATH],
//			BrshPath[MAX_PATH],TextPath[MAX_PATH];
extern char TextFilesPath[],PagesPath[],FontsPath[],
						BrushPath[],BGFilesPath[],OldFontPath[];
static char *PageTypes[] = {"Empty","Key","Framestore","Scroll","Crawl"};
static char *LineTypes[] = {"Text","Brush","Box","NotALine"};
static char *JustTypes[] = {"None","Center","Left","Right"};
static char *ShadTypes[] = {"None","Drop","Cast"};
char *Macros[] = {mac1,mac2,mac3,mac4,mac5,mac6,mac7,mac8,mac9,mac10,
									mac11,mac12,mac13,mac14,mac15,mac16,mac17,mac18,mac19,mac20,""};
char *Devs[] = {but0,dir0,but1,dir1,but2,dir2,but3,dir3};
char *Paths[] = {FontsPath,PagesPath,BGFilesPath,BrushPath,TextFilesPath};
char	ReqPath[MAX_PATH],ReqFile[MAX_PATH],ReqTitle[MACRO_MAX],ReqBuf1[MACRO_MAX],ReqBuf2[MACRO_MAX];
char	RexxStatus[65]="";
// Maybe these arrays should be declared as ULONG and filled like IFF chunks
UBYTE *RexxCmd[] = {  // 1st level (ARG0) Command, always available
  "GET_",             // Retrieve attribute for current selection
  "SET_",             // Set attribute for current selection
  "PICK",             // Set current selection
  "MAKE",             // Add object (make current)
  "KILL",             // Delete current object(s)
  "LOAD",             // Load object (make current)
  "SAVE",             // Save object
  "EXIT",             // Exit to Switcher
  "FEP_",             // Front-End-Processor command
  "REQ_",             // requester
  "REND",             // render
  "REXX",							// run Rexx script
  "MACR",							// Macro get/set
  "" };               // NULL terminated array!!

enum {
  GET_id,
  SET_id,
  PICKid,
  MAKEid,
  KILLid,
  LOADid,
  SAVEid,
  EXITid,
  FEP_id,
  REQ_id,
  RENDid,
  REXXid,
  MACRid,
  NULLid,
  };

UBYTE *RexxObj[] = {
  "FONT",
  "CHAR",
  "BRUS",
  "LINE",
  "PAGE",
  "BOOK",
  "PICT",
  "RECT",
  "SHAD",
  "BORD",
  "BACK",
  "TEXT",
  "DRAW",
  "" };  // NULL terminated array

enum {
  FONTid,
  CHARid,
  BRUSid,
  LINEid,
  PAGEid,
  BOOKid,
  PICTid,
  RECTid,
  SHADid,
  BORDid,
  BACKid,
  FILEid,
  DRAWid,
  };

UBYTE *RexxAttr[] = {  // Attributes
  "FACE",
  "TOPR",
  "BOTR",
  "TYPE",
  "SIZE",
  "JUST",
  "PRIO",
  "SPOT",
  "VALU",
  "RGBA",
  "NEXT",
  "PREV",
  "FIRS",
  "FILL",
  "TALL",
  "STAT",
  "LAST",
  "" };  // NULL terminated array

enum {
  FACEid,
  TOPRid,
  BOTRid,
  TYPEid,
  SIZEid,
  JUSTid,
  PRIOid,
  SPOTid,
  VALUid,
  RGBAid,
  NEXTid,
  PREVid,
  FIRSid,
  FILLid,
  TALLid,
  STATid,
  LASTid
  };

#define ERR_BADMESS     ERR10_010
#define ERR_FNRETURN    ERR10_012
#define ERR_UNKNOWN_FN  ERR10_015
#define ERR_MISSING_FN  1
#define ERR_BADARGNUM   ERR10_017
#define ERR_BADARG      ERR10_018

int __asm FEP_Func(register __a0 struct RexxMsg *msg)
{
  char *ms[5],*obj=(ARG0(msg)+4),fname[150],num[160],*buf;
  UWORD code;
	ULONG type;
  int args=ARG_NUM(msg),c;
	struct CGLine *Line;
	struct Attributes *Attr;

  if(FindFEP())
  {
    switch(obj[0])
    {
      case 'e': case 'E':  // FEP_END
        FillReply(msg,RC_OK,NULL,0);
        TemplateOn(BAR_NORMAL);
        break;
      case 'n': case 'N':  // FEP_NEWCHAR
        code=atoi(ARG1(msg));
        if (Line = RD->CurrentLine)
      		if (Attr = GetCharAttrib(Line,RD->CursorPosition))
          {
            CaseDefault(code,0);
            FillReply(msg,RC_OK,NULL,0);
            return(REFRESH_YES);
          }
        FillReply(msg,RC_WARN,NULL,ERR_FNRETURN);
        break;
      case 'l': case 'L':  // FEP_LOADFONT
        c=40;
        if(args==0)
        {
          ms[0]=strcpy(num,"Load Comp Font");
          ms[1]=strcpy(fname,"CG:");
          if(buf=FileRequest(num,"",fname))
            if(c=strlen(buf)) buf[c-2]=0;
        }
        else buf=ARG1(msg);
//				if(!FEP_VerifyFont(buf))
//				{
//	        FillReply(msg,RC_ERROR,NULL,ERR_FNRETURN);
//	        return(REFRESH_NONE);
//				}
        if( (args==1) || (c=atoi(ARG2(msg)))==0 )
        {
          if(c=PromptFontHeight(buf,40))
            type=PSFONT_2BYTE|PSFONT_COMPHEX;
//		Inseart	By Koichi Dekune
          else
	        return(REFRESH_NONE);
//		Inseart	By Koichi Dekune
        }
        else if ( (args==2) || (type=atoi(ARG3(msg)))==0 )
          type=PSFONT_2BYTE|PSFONT_COMPHEX;

        if(!(type&PSFONT_COMPHEX)) type |= 0x14000000;  // hardwire Korean translator
        CompLoad(buf,c, type );

        FillReply(msg,RC_OK,NULL,0);
        return(REFRESH_YES);
        break;
      default:
        FillReply(msg,RC_ERROR,NULL,ERR_UNKNOWN_FN);
        return(REFRESH_NONE);
   }
  }
  FillReply(msg,RC_WARN,NULL,ERR_FNRETURN);
  return(REFRESH_NONE);
}

int __asm REXXFunc(register __a0 struct RexxMsg *msg)
{
  int args=ARG_NUM(msg);
	char *ms[3],result[MAX_RESULT]="";
  if(args>0) ms[0]=ARG1(msg);
  else
	{
		ms[0]="ARexx Macro Name:";
    ms[1]="";
    if(CGStringRequest(ms,2,REQ_CENTER | REQ_H_CENTER | REQ_STRING,(APTR)result))
       ms[0]=result;
    else
		{
			FillReply(msg,RC_WARN,NULL,ERR_FNRETURN);
  		return(REFRESH_NONE);
		}
	}
	ARexxMacro(ms[0]);
	FillReply(msg,RC_OK,NULL,0);
	return(REFRESH_NONE);
}

int __asm MACRFunc(register __a0 struct RexxMsg *msg)
{
  int args=ARG_NUM(msg),m;
	char result[MAX_RESULT]="";
  if( (args>0) )
	{
		m=atol(ARG1(msg));
		if(m>MACRO_COUNT) m=MACRO_COUNT;
		if(args>1) // Write Macro
		{
			strncpy(Macros[m],ARG2(msg),MACRO_MAX-1);
			FillReply(msg,RC_OK,NULL,0);
		}
		else
		{
			strncpy(result,Macros[m],MAX_RESULT-1);
			FillReply(msg,RC_OK,result,0);
		}
	}
	else 	FillReply(msg,RC_WARN,NULL,ERR_BADARGNUM);
	return(REFRESH_NONE);
}


static UWORD RexxFontListID=0;
int __asm GET_Func(register __a0 struct RexxMsg *msg)
{
  char *obj=(ARG0(msg)+4),result[MAX_RESULT]="";
  int i,n,atr,args=ARG_NUM(msg);
  UWORD len,X;
	struct LineData *Data,*Next;
  struct TextInfo *t;
  struct TempInfo *tmp;
  struct CGLine *curline = RD->CurrentLine;
  struct CGPage *curpage = RD->CurrentPage;
  struct Attributes *attr;
  struct ToasterFont *tf;


	if ( !(attr = GetCharAttrib(curline,RD->CursorPosition)) )
    attr=&(RD->DefaultAttr);
  n=MatchCommand(obj,RexxObj,4);
  switch(n)
  {
    case CHARid:
      if(args<1)  // Get first selected char on current line
      {
        t=curline->Text;
        result[0]=(UBYTE)(t[RD->CursorPosition]).Ascii;
        result[1]=0;
        FillReply(msg,RC_OK,result,0);
        break;
      }
      atr=MatchCommand( ARG1(msg), RexxAttr,4 );
      switch(atr)
      {
        case RGBAid: // doesn't seem to work...Jan  5 1994
        case TOPRid:
          sprintf(result,"%d %d %d %d",
          attr->FaceColor.Red,
          attr->FaceColor.Green,
          attr->FaceColor.Blue,
          attr->FaceColor.Alpha);
          FillReply(msg,RC_OK,result,0);
          break;
        case BOTRid:
          sprintf(result,"%d %d %d %d",
          attr->GradColor.Red,
          attr->GradColor.Green,
          attr->GradColor.Blue,
          attr->GradColor.Alpha);
          FillReply(msg,RC_OK,result,0);
          break;
        case FILLid:
          if(attr->SpecialFill&FILL_TBGRAD)
            FillReply(msg,RC_OK,"1",0);
          else
            FillReply(msg,RC_OK,"0",0);
          break;
        case SIZEid:
          tmp=&(curline->Temp[RD->CursorPosition]);
          sprintf(result,"%d",tmp->EndX - tmp->StartX);
          FillReply(msg,RC_OK,result,0);
          break;
        case FACEid:
          if (Data = GetData(attr->ID))
            FillReply(msg,RC_OK,Data->FileName,0);
          else
            FillReply(msg,RC_WARN,NULL,ERR_FNRETURN);
          break;
        case FIRSid:
          t=&(curline->Text[0]);
          result[0]=(UBYTE)t->Ascii;
          result[1]=0;
          FillReply(msg,RC_OK,result,0);
          break;
        case STATid:
          t=&(curline->Text[0]);
          result[0]=(t->Select==SELECT_ON) ? '1':'0' ;
          result[1]=0;
          FillReply(msg,RC_OK,result,0);
          break;
        case LASTid:
          len=LineLength(curline);
          t=&(curline->Text[len-1]);
          result[0]=(UBYTE)t->Ascii;
          result[1]=0;
          FillReply(msg,RC_OK,result,0);
          break;
        case NEXTid:
          t=&(curline->Text[RD->CursorPosition+1]);
          result[0]=(UBYTE)t->Ascii;
          result[1]=0;
          FillReply(msg,RC_OK,result,0);
          break;
        case PREVid:
          X=RD->CursorPosition-1;
          t=&(curline->Text[(X>=0 ? X:0)]);
          result[0]=(UBYTE)t->Ascii;
          result[1]=0;
          FillReply(msg,RC_OK,result,0);
          break;
        case SPOTid:
          stci_d(result,RD->CursorPosition);
          FillReply(msg,RC_OK,result,0);
          break;
        default:
          FillReply(msg,RC_ERROR,NULL,ERR_BADARG);
      }
      break;

    case LINEid: // GET_LINE
      if(args<1)
      {
        len=LineLength(curline);
        t=curline->Text;
        for(i=0; i<len ;i++)
        {
          result[i]=(UBYTE)t->Ascii;
          t++;
        }
        result[i]=0;
        FillReply(msg,RC_OK,result,0);
        break;
      }
      atr=MatchCommand( ARG1(msg), RexxAttr,4 );
      switch(atr)
      {
        case TYPEid:
          // stci_d(result,curline->Type);
          FillReply(msg,RC_OK,LineTypes[curline->Type],0);
          break;
        case SIZEid:
          stci_d(result,LineLength(curline));
          FillReply(msg,RC_OK,result,0);
          break;
        case JUSTid:
          // stci_d(result,curline->JustifyMode);
          FillReply(msg,RC_OK,JustTypes[curline->JustifyMode],0);
          break;
        case SPOTid:
          sprintf(result,"%d %d",curline->XOffset,curline->YOffset);
          FillReply(msg,RC_OK,result,0);
          break;
        case TALLid:
          sprintf(result,"%d",curline->TotalHeight);
          FillReply(msg,RC_OK,result,0);
          break;
        case STATid:
          result[0]=AnyCharSelected(curline) ? '1':'0' ;
          result[1]=0;
          FillReply(msg,RC_OK,result,0);
          break;
        default:
          FillReply(msg,RC_ERROR,NULL,ERR_BADARG);
      }
      break;

    case PAGEid:
      if(args<1)
      {
        stci_d(result,RD->PageNumber);
        FillReply(msg,RC_OK,result,0);
        break;
      }
      atr=MatchCommand( ARG1(msg), RexxAttr,4 );
      switch(atr)
      {
        case TYPEid:
          // stci_d(result,curpage->Type);
          FillReply(msg,RC_OK,PageTypes[curpage->Type],0);
          break;
        case SIZEid:
          stci_d(result,NodesThisList(&curpage->LineList));
          FillReply(msg,RC_OK,result,0);
          break;
        default:
          FillReply(msg,RC_ERROR,NULL,ERR_BADARG);
          break;
      }
      break;

    case BOOKid:
      break;
    case FONTid:
      if ( !(Data = GetData(attr->ID)) )
      {
        FillReply(msg,RC_WARN,NULL,ERR_FNRETURN);
        break;
      }
      if(args<1)
      {
        if (Data->Type != LINE_TEXT)
          FillReply(msg,RC_OK,"",0);
        else
          FillReply(msg,RC_OK,Data->FileName,0);
        break;
      }
      tf=(struct ToasterFont *)Data->Data;
      atr=MatchCommand( ARG1(msg), RexxAttr,4 );
      switch(atr)
      {
        case FIRSid:
					FillReply(msg,RC_OK,"",0);
					RexxFontListID=0;
					Data = (struct LineData *)RD->CurrentBook->DataList.mlh_Head;
					if(Data && Data->Node.mln_Succ)
						if (Data->Type == LINE_TEXT)
							sprintf(result,"%s,%d",Data->FileName,Data->Height);
          break;
        case NEXTid:
          FillReply(msg,RC_OK,"",0);
					Data = (struct LineData *)RD->CurrentBook->DataList.mlh_Head;
					i=0;
					while((i<=RexxFontListID) && (Next = (struct LineData *)Data->Node.mln_Succ) ) {
						if (Data->Type == LINE_TEXT)
						{
							if(i++==RexxFontListID)
							{
								sprintf(result,"%s,%d",Data->FileName,Data->Height);
								FillReply(msg,RC_OK,result,0);
							}
						}
						Data = Next;
					}
					if(i<RexxFontListID) // List ended before next ID
						RexxFontListID=0;
					else
						RexxFontListID++;
          break;
        case TYPEid:
          stci_d(result,tf->Type);
          FillReply(msg,RC_OK,result,0);
          break;
        case SIZEid:
          stci_d(result,Data->Height);
          FillReply(msg,RC_OK,result,0);
          break;
        default:
          len=(args>1 ? atoi(ARG2(msg)):ANY_HEIGHT);
          if(Data=GetDataFromFileName(&(RD->CurrentBook->DataList),ARG1(msg),len))
          {
            stci_d(result,Data->Height);
            FillReply(msg,RC_OK,result,0);
          }
          else  FillReply(msg,RC_OK,"0",0);
          break;
      }
      break;

    case PICTid:
      break;
    case RECTid:
    case DRAWid:
      if(args<1)
      {
        FillReply(msg,RC_ERROR,NULL,ERR_BADARGNUM);
        break;
      }
      atr=MatchCommand( ARG1(msg), RexxAttr,4 );
      switch(atr)
      {
        case TOPRid:
        case RGBAid:
          sprintf(result,"%d %d %d %d",
          attr->FaceColor.Red,
          attr->FaceColor.Green,
          attr->FaceColor.Blue,
          attr->FaceColor.Alpha);
          FillReply(msg,RC_OK,result,0);
          break;
        case BOTRid:
          sprintf(result,"%d %d %d %d",
          attr->GradColor.Red,
          attr->GradColor.Green,
          attr->GradColor.Blue,
          attr->GradColor.Alpha);
          FillReply(msg,RC_OK,result,0);
          break;
        case FILLid:
          if(attr->SpecialFill&FILL_TBGRAD)
            FillReply(msg,RC_OK,"1",0);
          else
            FillReply(msg,RC_OK,"0",0);
          break;
        case SIZEid:
          sprintf(result,"%d %d",curline->FaceWidth,curline->FaceHeight);
          FillReply(msg,RC_OK,result,0);
          break;
        case SPOTid:
          sprintf(result,"%d %d",curline->XOffset,curline->YOffset);
          FillReply(msg,RC_OK,result,0);
          break;
        default:
          FillReply(msg,RC_ERROR,NULL,ERR_BADARG);
      }
      break;

    case SHADid:
      if(args<1)
      {
        FillReply(msg,RC_ERROR,NULL,ERR_BADARGNUM);
        break;
      }
      atr=MatchCommand( ARG1(msg), RexxAttr,4 );
      switch(atr)
      {
        case TOPRid:
        case RGBAid:
        case BOTRid:
          sprintf(result,"%d %d %d %d",
          attr->ShadowColor.Red,
          attr->ShadowColor.Green,
          attr->ShadowColor.Blue,
          attr->ShadowColor.Alpha);
          FillReply(msg,RC_OK,result,0);
          break;
        case TYPEid:
          // stci_d(result,attr->ShadowType);
          FillReply(msg,RC_OK,ShadTypes[attr->ShadowType],0);
          break;
        case SIZEid:
          stci_d(result,(attr->ShadowLength>>1));
          FillReply(msg,RC_OK,result,0);
          break;
        case SPOTid:
          stci_d(result,attr->ShadowDirection);
          FillReply(msg,RC_OK,result,0);
          break;
        case PRIOid:
          stci_d(result,attr->ShadowPriority);
          FillReply(msg,RC_OK,result,0);
          break;
        default:
          FillReply(msg,RC_ERROR,NULL,ERR_BADARG);
      }
      break;

    case BORDid:
      if(args<1)
      {
        FillReply(msg,RC_ERROR,NULL,ERR_BADARGNUM);
        break;
      }
      atr=MatchCommand( ARG1(msg), RexxAttr,4 );
      switch(atr)
      {
        case TOPRid: 
        case RGBAid:
          sprintf(result,"%d %d %d %d",
          attr->OutlineColor.Red,
          attr->OutlineColor.Green,
          attr->OutlineColor.Blue,
          attr->OutlineColor.Alpha);
          FillReply(msg,RC_OK,result,0);
          break;
        case BOTRid:
          sprintf(result,"%d %d %d %d",
          attr->OGradColor.Red,
          attr->OGradColor.Green,
          attr->OGradColor.Blue,
          attr->OGradColor.Alpha);
          FillReply(msg,RC_OK,result,0);
          break;
        case FILLid:
          if(attr->SpecialFill&OLFILL_GRAD)
            FillReply(msg,RC_OK,"1",0);
          else
            FillReply(msg,RC_OK,"0",0);
          break;
        case SIZEid:
          stci_d(result,attr->OutlineType);
          FillReply(msg,RC_OK,result,0);
          break;
        case PRIOid:
          stci_d(result,(attr->ShadowPriority ? 0:1) );
          FillReply(msg,RC_OK,result,0);
          break;
        default:
          FillReply(msg,RC_ERROR,NULL,ERR_BADARG);
      }
      break;

    case BACKid:
      if(args<1)
      {
        stcl_d(result,(LONG)&(RD->CommonRGB->Picture));
        FillReply(msg,RC_OK,result,0);
        break;
      }
      atr=MatchCommand( ARG1(msg), RexxAttr,4 );
      switch(atr)
      {
        case TOPRid: case RGBAid:
          sprintf(result,"%d %d %d",
          curpage->TopBackground.Red,
          curpage->TopBackground.Green,
          curpage->TopBackground.Blue);
          FillReply(msg,RC_OK,result,0);
          break;
        case BOTRid:
          sprintf(result,"%d %d %d",
          curpage->BottomBackground.Red,
          curpage->BottomBackground.Green,
          curpage->BottomBackground.Blue);
          FillReply(msg,RC_OK,result,0);
          break;
        case FILLid:
          if(curpage->Background==BACKGROUND_GRADATION)
            FillReply(msg,RC_OK,"1",0);
          else
            FillReply(msg,RC_OK,"0",0);
          break;
        case TYPEid:
          stci_d(result,curpage->Background);
          FillReply(msg,RC_OK,result,0);
          break;
        default:
          FillReply(msg,RC_ERROR,NULL,ERR_BADARG);
      }
      break;
    default:
      FillReply(msg,RC_ERROR,NULL,ERR_UNKNOWN_FN);
  }
  return(REFRESH_NONE);
}


int __asm SetLine(REG __d0 int num)
{
	struct CGLine *Line,*Next;
  int i=0;
  if(RD->CurrentPage->Type != PAGE_EMPTY)
  {
  	Line = (struct CGLine *)RD->CurrentPage->LineList.mlh_Head;
	  while ( (Next=(struct CGLine *)(Line->Node.mln_Succ) ) && ++i<num)
		  Line = Next;
    NewCurrentLine(Line);
  }
  return(i);
}


//~~*~~*~~*~~*~~*~~*~~*~~*~~*~~*~~*~~*~~*~~*~~*~~*~~*~~*~~*~~*~~*~~*~~*~~*~

int __asm SET_Func(register __a0 struct RexxMsg *msg)
{
  char *obj=(ARG0(msg)+4),result[MAX_RESULT]="";
  int n,atr,args=ARG_NUM(msg);
  UWORD len,X;
  // UBYTE R,G,B,A;
	struct LineData *Data;
  struct RexxArg  *ra;
  struct TextInfo *t;
  struct CGLine *line,*curline = RD->CurrentLine;
  struct CGPage *curpage = RD->CurrentPage;
  struct Attributes *attr= &(RD->DefaultAttr);

  n=MatchCommand(obj,RexxObj,4);
  switch(n)
  {
    case CHARid:  // SET_CHAR -- Set character value
      if(args<1)
      {
        FillReply(msg,RC_ERROR,NULL,ERR_BADARGNUM);
        return(REFRESH_NONE);
      }
      atr=MatchCommand( ARG1(msg), RexxAttr,4 );
      switch(atr)
      {
        case RGBAid:
        case TOPRid:
          if(args<4)
          {
            FillReply(msg,RC_ERROR,NULL,ERR_BADARGNUM);
            return(REFRESH_NONE);
          }
          attr->FaceColor.Red   =(UBYTE)atoi(ARG2(msg));
          attr->FaceColor.Green =(UBYTE)atoi(ARG3(msg));
          attr->FaceColor.Blue  =(UBYTE)atoi(ARG4(msg));
          attr->FaceColor.Alpha =(UBYTE)atoi(ARG5(msg));
        	SetSelectAttrib(RD->CurrentPage,(UBYTE *)&attr->FaceColor,ATTR_COLOR);
          FillReply(msg,RC_OK,result,0);
          break;
        case BOTRid:
          if(args<4)
          {
            FillReply(msg,RC_ERROR,NULL,ERR_BADARGNUM);
            return(REFRESH_NONE);
          }
          attr->GradColor.Red   =(UBYTE)atoi(ARG2(msg));
          attr->GradColor.Green =(UBYTE)atoi(ARG3(msg));
          attr->GradColor.Blue  =(UBYTE)atoi(ARG4(msg));
          attr->GradColor.Alpha =(UBYTE)atoi(ARG5(msg));
        	SetSelectAttrib(RD->CurrentPage,(UBYTE *)&attr->FaceColor,ATTR_COLOR);
          FillReply(msg,RC_OK,result,0);
          break;
        case FILLid:
          if( args>1)
          {
            len=atoi(ARG2(msg));
            if(len==1) attr->SpecialFill |= FILL_TBGRAD;
            else attr->SpecialFill &= (~FILL_TBGRAD);
          	SetSelectAttrib(RD->CurrentPage,(UBYTE *)&attr->SpecialFill,ATTR_FILL);
	          FillReply(msg,RC_OK,NULL,0);
          }
          else FillReply(msg,RC_ERROR,NULL,ERR_BADARGNUM);
          break;
        case SPOTid: // Set cursor position
          if( args<2  || ( len=atoi(ARG2(msg)) )==0 )
          {
            FillReply(msg,RC_ERROR,NULL,ERR_BADARGNUM);
            return(REFRESH_NONE);
          }
          NewCurrentCursor(len-1);
          FillReply(msg,RC_OK,NULL,0);
          break;
        case NEXTid:
          X=RD->CursorPosition+1;
          NewCurrentCursor(X);
          FillReply(msg,RC_OK,NULL,0);
          break;
        case FACEid:
          if( args>1)
          {
            if( (Data=GetDataFromFileName(&(RD->CurrentBook->DataList),ARG2(msg),args>2 ? atoi(ARG3(msg)):ANY_HEIGHT)) )
            {
							RD->DefaultLine.Type = Data->Type;
							RD->DefaultAttr.ID = Data->ID;
							if (Data->Type == LINE_TEXT) RD->LastDefaultFont = Data->ID;
							SetSelectAttrib(RD->CurrentPage,(UBYTE *)&Data->ID,ATTR_ID);
	            FillReply(msg,RC_OK,NULL,0);
						}
	          else FillReply(msg,RC_ERROR,NULL,ERR_FNRETURN);
          }
          else FillReply(msg,RC_ERROR,NULL,ERR_BADARGNUM);
          break;
        case PREVid:
          X=RD->CursorPosition-1;
          NewCurrentCursor((X>=0 ? X:0));
          FillReply(msg,RC_OK,NULL,0);
          break;
        case FIRSid:
          NewCurrentCursor(0);
          FillReply(msg,RC_OK,NULL,0);
          break;
        case LASTid:
          NewCurrentCursor(LineLength(curline)-1);
          FillReply(msg,RC_OK,NULL,0);
          break;
        case VALUid:  // Set ASCII (2byte) value as dec. int
          if( args<2 && ( len=0xFFFF&atoi(ARG2(msg)) )==0 )
          {
            FillReply(msg,RC_ERROR,NULL,ERR_BADARGNUM);
            return(REFRESH_NONE);
          }
          t=&(curline->Text[RD->CursorPosition]);
          t->Ascii=len;
          FillReply(msg,RC_OK,NULL,0);
          break;
        default:      // Set ASCII value with actual byte(s) in message
          if( (args>=1) )
          {
            t=&(curline->Text[RD->CursorPosition]);
            ra = (struct RexxArg *)( ((UBYTE *)ARG1(msg) ) - 8 );
            if(ra->ra_Length>1) t->Ascii=*((UWORD *)ARG1(msg));  // 2 Bytes
            else  t->Ascii=(UWORD) (ARG1(msg))[0];  // just 1st char
            FillReply(msg,RC_OK,NULL,0);
          }
          else FillReply(msg,RC_ERROR,NULL,ERR_BADARG);
      }
      break;
    case LINEid: // SET_LINE -- Set current line number
      if(args<1)
      {
        FillReply(msg,RC_ERROR,NULL,ERR_BADARGNUM);
        return(REFRESH_NONE);
      }
      atr=MatchCommand( ARG1(msg), RexxAttr,4 );
      switch(atr)
      {
        case SPOTid:
          if(args<3)
          {
            FillReply(msg,RC_ERROR,NULL,ERR_BADARGNUM);
            return(REFRESH_NONE);
          }
          curline->XOffset = atoi(ARG2(msg)); // check  valid ??
          curline->YOffset = atoi(ARG3(msg));
          FillReply(msg,RC_OK,NULL,0);
          break;
        case JUSTid:
          if(args<2)
          {
            FillReply(msg,RC_ERROR,NULL,ERR_BADARGNUM);
            return(REFRESH_NONE);
          }
          obj=ARG2(msg);
          switch(obj[0])
          {
            case 'C':   case 'c':
              curline->JustifyMode=JUSTIFY_CENTER;
              break;
            case 'L':   case 'l':
              curline->JustifyMode=JUSTIFY_LEFT;
              break;
            case 'R':   case 'r':
              curline->JustifyMode=JUSTIFY_RIGHT;
              break;
            case 'N':   case 'n':
            default:
              curline->JustifyMode=JUSTIFY_NONE;
          }
    			JustifyThisLine(curline);
          FillReply(msg,RC_OK,NULL,0);
          break;
        case FIRSid:
          // if(line = (struct CGLine *)RD->CurrentPage->LineList.mlh_Head)
          if(line = GetTopmostLine(&RD->CurrentPage->LineList) )
            NewCurrentLine(line);
          FillReply(msg,RC_OK,NULL,0);
          break;
        case LASTid:
          //if(line = (struct CGLine *)RD->CurrentPage->LineList.mlh_Tail)
          if(line = GetBottommostLine(&RD->CurrentPage->LineList) )
            NewCurrentLine(line);
          FillReply(msg,RC_OK,NULL,0);
          break;
        case NEXTid:
         // if( line=(struct CGLine *)(curline->Node.mln_Succ) )
          if(line=GetNextLowerLine(curpage,curline))
            NewCurrentLine(line);
          FillReply(msg,RC_OK,NULL,0);
          break;
        case PREVid:
         // if( line=(struct CGLine *)(curline->Node.mln_Pred) )
          if(line=GetNextHigherLine(curpage,curline))
            NewCurrentLine(line);
          FillReply(msg,RC_OK,NULL,0);
          break;
        default: // set new line
          if( (args==1) && (len=atoi(ARG1(msg))) )
          {
            FillReply(msg,RC_OK,NULL,0);
            SetLine(len);
          }
          else FillReply(msg,RC_ERROR,NULL,ERR_BADARG);
      }
      break;

    case PAGEid:
      if(args<1)
      {
        FillReply(msg,RC_ERROR,NULL,ERR_BADARGNUM);
        return(REFRESH_NONE);
      }
      atr=MatchCommand( ARG1(msg), RexxAttr,4 );
      switch(atr)
      {
        case TYPEid:
          if(args<2)
          {
            FillReply(msg,RC_ERROR,NULL,ERR_BADARGNUM);
            return(REFRESH_NONE);
          }
          obj=ARG2(msg);
          switch(obj[0])
          {
            case 'C':   case 'c':
       				ChangePageType(RD->CurrentPage,PAGE_CRAWL);
              break;
            case 'K':   case 'k':
       				ChangePageType(RD->CurrentPage,PAGE_STATIC);
              break;
            case 'S':   case 's':
       				ChangePageType(RD->CurrentPage,PAGE_SCROLL);
              break;
            case 'F':   case 'f':
       				ChangePageType(RD->CurrentPage,PAGE_BUFFER);
            default:
              break;
          }
          FillReply(msg,RC_OK,"",0);
          break;
        case NEXTid:
          CasePageDown(&intuidummy);
          FillReply(msg,RC_OK,result,0);
          break;
        case PREVid:
          CasePageUp(&intuidummy);
          FillReply(msg,RC_OK,result,0);
          break;
        default: // Set Page number
          if( (args==1) )
          {
						atr=atol(ARG1(msg));
         		if ((atr != RD->PageNumber) && (atr < PAGES_PER_BOOK) && (atr>=0) )
						{
        			RD->PageNumber = atr;
        			RD->UpdateInterface = TRUE;
        			RD->UpdatePage = UPDATE_PAGE_NEW;
        		}
          }
          else FillReply(msg,RC_ERROR,NULL,ERR_BADARG);
          break;
      }
      break;

    case FONTid:
      if(args<1)
      {
        FillReply(msg,RC_ERROR,NULL,ERR_BADARGNUM);
        return(REFRESH_NONE);
      }
      if((Data = GetDataFromFileName(&(RD->CurrentBook->DataList),ARG1(msg),args>=2 ? atoi(ARG2(msg)):ANY_HEIGHT) ))
      {
  			SetSelectAttrib(RD->CurrentPage,(UBYTE *)&Data->ID,ATTR_ID);
	  		UpdateFixPage();
		  	RD->UpdatePage = UPDATE_PAGE_OLD;
        FillReply(msg,RC_OK,result,0);
      }
      else FillReply(msg,RC_ERROR,NULL,ERR_BADARG);
      break;


    case SHADid:
      if(args<1)
      {
        FillReply(msg,RC_ERROR,NULL,ERR_BADARGNUM);
        return(REFRESH_NONE);
      }
      atr=MatchCommand( ARG1(msg), RexxAttr,4 );
      switch(atr)
      {
        case RGBAid:
        case TOPRid:
          if(args<4)
          {
            FillReply(msg,RC_ERROR,NULL,ERR_BADARGNUM);
            return(REFRESH_NONE);
          }
          attr->ShadowColor.Red   =(UBYTE)atoi(ARG2(msg));
          attr->ShadowColor.Green =(UBYTE)atoi(ARG3(msg));
          attr->ShadowColor.Blue  =(UBYTE)atoi(ARG4(msg));
          attr->ShadowColor.Alpha =(UBYTE)atoi(ARG5(msg));
        	SetSelectAttrib(RD->CurrentPage,(UBYTE *)&attr->FaceColor,ATTR_COLOR);
          FillReply(msg,RC_OK,result,0);
          break;
        case PRIOid:
          if( args>1)
          {
            len=atoi(ARG2(msg));
            if(len==1) attr->ShadowPriority=1;
            else attr->ShadowPriority=0;
          	SetSelectAttrib(RD->CurrentPage,(UBYTE *)&attr->ShadowPriority,ATTR_SHADOW_PRIORITY);
          }
          FillReply(msg,RC_OK,result,0);
          break;
        case TYPEid:
          if( args>1)
          {
            switch((ARG2(msg))[0])
            {
              case 'n': case 'N':
                len=0;
                break;
              case 'd': case 'D':
                len=1;
                break;
              case 'c': case 'C':
                len=2;
                break;
              default:
                len=atoi(ARG2(msg));
                break;
            }
            attr->ShadowType=len;
          	SetSelectAttrib(RD->CurrentPage,(UBYTE *)&attr->ShadowType,ATTR_SHADOW_TYPE);
          }
          FillReply(msg,RC_OK,result,0);
          break;
        case SIZEid:
          stci_d(result,attr->ShadowLength);
          if( args>1)
          {
            len=atoi(ARG2(msg));
            if(len<1) len=1;
            if(len>5) len=5;
            attr->ShadowLength=len<<1;  //MIN_SHADOW_LENGTH
          	SetSelectAttrib(RD->CurrentPage,(UBYTE *)&attr->ShadowLength,ATTR_SHADOW_LENGTH);
          }
          FillReply(msg,RC_OK,result,0);
          break;
        case SPOTid:
          if( args>1)
          {
            len=(atoi(ARG2(msg)))&0x07 ; // limit to 3 bits.. 0-7
            attr->ShadowDirection=len;
          	SetSelectAttrib(RD->CurrentPage,(UBYTE *)&attr->ShadowDirection,ATTR_SHADOW_DIRECTION);
          }
          FillReply(msg,RC_OK,result,0);
          break;
        default:
          if( (args==1) && (len=atoi(ARG1(msg))) )
          {
            attr->ShadowLength = len;
            FillReply(msg,RC_OK,NULL,0);
          	SetSelectAttrib(RD->CurrentPage,(UBYTE *)&attr->ShadowLength,ATTR_SHADOW_LENGTH);
          }
          else FillReply(msg,RC_ERROR,NULL,ERR_BADARG);
      }
      break;
    case BORDid:
      if(args<1)
      {
        FillReply(msg,RC_ERROR,NULL,ERR_BADARGNUM);
        return(REFRESH_NONE);
      }
      atr=MatchCommand( ARG1(msg), RexxAttr,4 );
      switch(atr)
      {
        case RGBAid:
        case TOPRid:
          if(args<4)
          {
            FillReply(msg,RC_ERROR,NULL,ERR_BADARGNUM);
            return(REFRESH_NONE);
          }
          attr->OutlineColor.Red   =(UBYTE)atoi(ARG2(msg));
          attr->OutlineColor.Green =(UBYTE)atoi(ARG3(msg));
          attr->OutlineColor.Blue  =(UBYTE)atoi(ARG4(msg));
          attr->OutlineColor.Alpha =(UBYTE)atoi(ARG5(msg));
        	SetSelectAttrib(RD->CurrentPage,(UBYTE *)&attr->FaceColor,ATTR_COLOR);
          FillReply(msg,RC_OK,result,0);
          break;
        case BOTRid:
          attr->OGradColor.Red   =(UBYTE)atoi(ARG2(msg));
          attr->OGradColor.Green =(UBYTE)atoi(ARG3(msg));
          attr->OGradColor.Blue  =(UBYTE)atoi(ARG4(msg));
          attr->OGradColor.Alpha =(UBYTE)atoi(ARG5(msg));
        	SetSelectAttrib(RD->CurrentPage,(UBYTE *)&attr->FaceColor,ATTR_COLOR);
          FillReply(msg,RC_OK,result,0);
          break;
        case SIZEid:
          if( args>1)
          {
            len=atoi(ARG2(msg));
            attr->OutlineType=len;
          	SetSelectAttrib(RD->CurrentPage,(UBYTE *)&attr->OutlineType,ATTR_OUTLINE_TYPE);
          }
          FillReply(msg,RC_OK,result,0);
          break;
        case PRIOid:
          if( args>1)
          {
            len=atoi(ARG2(msg));
            if(len==1) attr->ShadowPriority=0;
            else attr->ShadowPriority=1;
          	SetSelectAttrib(RD->CurrentPage,(UBYTE *)&attr->ShadowPriority,ATTR_SHADOW_PRIORITY);
          }
          FillReply(msg,RC_OK,result,0);
          break;
        case FILLid:
          if( args>1)
          {
            len=atoi(ARG2(msg));
            if(len==1) attr->SpecialFill |= OLFILL_GRAD;
            else attr->SpecialFill &= (~OLFILL_GRAD);
          	SetSelectAttrib(RD->CurrentPage,(UBYTE *)&attr->SpecialFill,ATTR_FILL);
          }
          FillReply(msg,RC_OK,result,0);
          break;
        default:
          if( (args==1) && (len=atoi(ARG1(msg))) )
          {
            attr->OutlineType = len;
            FillReply(msg,RC_OK,NULL,0);
          	SetSelectAttrib(RD->CurrentPage,(UBYTE *)&attr->OutlineType,ATTR_OUTLINE_TYPE);
          }
          else FillReply(msg,RC_ERROR,NULL,ERR_BADARG);
      }
      break;
    case BACKid:
      if(args<1)
      {
        FillReply(msg,RC_ERROR,NULL,ERR_BADARGNUM);
        return(REFRESH_NONE);
      }
      atr=MatchCommand( ARG1(msg), RexxAttr,4 );
      switch(atr)
      {
        case RGBAid:
        case TOPRid:
          if(args<4)
          {
            FillReply(msg,RC_ERROR,NULL,ERR_BADARGNUM);
            return(REFRESH_NONE);
          }
          curpage->TopBackground.Red   =(UBYTE)atoi(ARG2(msg));
          curpage->TopBackground.Green =(UBYTE)atoi(ARG3(msg));
          curpage->TopBackground.Blue  =(UBYTE)atoi(ARG4(msg));
          FillReply(msg,RC_OK,result,0);
          break;
        case BOTRid:
          if(args<4)
          {
            FillReply(msg,RC_ERROR,NULL,ERR_BADARGNUM);
            return(REFRESH_NONE);
          }
          curpage->BottomBackground.Red   =(UBYTE)atoi(ARG2(msg));
          curpage->BottomBackground.Green =(UBYTE)atoi(ARG3(msg));
          curpage->BottomBackground.Blue  =(UBYTE)atoi(ARG4(msg));
          FillReply(msg,RC_OK,result,0);
          break;
        case FILLid:
        case TYPEid:
          if(args>1) curpage->Background=atoi(ARG2(msg));
          FillReply(msg,RC_OK,result,0);
          break;
        default:
          curpage->Background=atoi(ARG1(msg));
          FillReply(msg,RC_OK,result,0);
          break;
      }
      break;
    default:
      FillReply(msg,RC_ERROR,NULL,ERR_UNKNOWN_FN);
  }
  return(REFRESH_YES);
}

int __asm PICKFunc(register __a0 struct RexxMsg *msg)
{
  char *obj=(ARG0(msg)+4);
  int n,args=ARG_NUM(msg);
  UWORD len;
  struct TextInfo *t;
  struct CGLine *curline = RD->CurrentLine;

  n=MatchCommand(obj,RexxObj,4);
  switch(n)
  {
    case CHARid:  // Pick current char, deselect if third arg provided
      t=&(curline->Text[RD->CursorPosition]);
      t->Select=(args==0 ? SELECT_ON:SELECT_OFF);
      RendDispLine(RD->CurrentPage,curline);
      FillReply(msg,RC_OK,NULL,0);
      break;
    case LINEid:
      len=(args==0 ? SELECT_ON:SELECT_OFF);
      SelectLine(RD->CurrentPage,curline,len,TRUE);
      FillReply(msg,RC_OK,NULL,0);
      break;
    case PAGEid:
      len=(args==0 ? SELECT_ON:SELECT_OFF);
      if(RD->CurrentPage->Type != PAGE_EMPTY)
        SelectPage(RD->CurrentPage,len,TRUE);
      FillReply(msg,RC_OK,NULL,0);
      break;
    default:
      FillReply(msg,RC_ERROR,NULL,ERR_UNKNOWN_FN);
  }
  return(REFRESH_YES);
}

int __asm MAKEFunc(register __a0 struct RexxMsg *msg)
{
  char *obj=(ARG0(msg)+4);
	UWORD ID=ID_BOX;
  int i,n,args=ARG_NUM(msg);
  struct RexxArg *ra;

  n=MatchCommand(obj,RexxObj,4);
  switch(n)
  {
    case CHARid:
      if(args<1)
      {
        FillReply(msg,RC_ERROR,NULL,ERR_BADARGNUM);
        return(REFRESH_NONE);
      }
      CaseDefault((UWORD)(ARG1(msg))[0],0);
      FillReply(msg,RC_OK,NULL,0);
      break;
    case LINEid:
      intuidummy.Class=RAWKEY;
      intuidummy.Code=RAW_RETURN;
      intuidummy.Qualifier=0;
      if(args>0)
      {
        ra = (struct RexxArg *)( ((UBYTE *)ARG1(msg) ) - 8 );
        obj=ARG1(msg);
        for(i=0;i<ra->ra_Length && *obj; i++)
          CaseDefault(*obj++,0);
        RendDispLine(RD->CurrentPage,RD->CurrentLine);
      }
      CaseDown(&intuidummy);
      FillReply(msg,RC_OK,NULL,0);
      return(REFRESH_YES);
      break;
    case RECTid:
			if ((RD->CurrentPage->Type != PAGE_STATIC) && (RD->CurrentPage->Type != PAGE_BUFFER))
			{ // No boxes on moving pages... for some reason.
				FillReply(msg,RC_ERROR,NULL,ERR_FNRETURN);
				return(REFRESH_YES);
			}
			SetSelectAttrib(RD->CurrentPage,(UBYTE *)&ID,ATTR_ID);
			UpdateFixPage();
			if(args>0) RD->CurrentLine->XOffset=atoi(ARG1(msg));
			if(args>1) RD->CurrentLine->YOffset=atoi(ARG2(msg));
			if(args>3)
				SetBoxSize(RD->CurrentPage,RD->CurrentLine,atoi(ARG3(msg)),atoi(ARG4(msg)));
			RD->UpdatePage = UPDATE_PAGE_OLD;
			FillReply(msg,RC_OK,NULL,0);
			return(REFRESH_YES);
			break;
    case PAGEid:
    default:
      FillReply(msg,RC_ERROR,NULL,ERR_UNKNOWN_FN);
  }
  return(REFRESH_YES);
}


int __asm KILLFunc(register __a0 struct RexxMsg *msg)
{
  char *obj=(ARG0(msg)+4);
  int n;

  n=MatchCommand(obj,RexxObj,4);
  switch(n)
  {
    case CHARid:
      CaseDelete((struct IntuiMessage *)msg);
      FillReply(msg,RC_OK,NULL,0);
      break;
    case LINEid:
      CaseEraseLine((struct IntuiMessage *)msg);
      FillReply(msg,RC_OK,NULL,0);
      break;
    case PAGEid:
      CaseErasePage((struct IntuiMessage *)msg);
      FillReply(msg,RC_OK,NULL,0);
      break;
    default:
      FillReply(msg,RC_ERROR,NULL,ERR_UNKNOWN_FN);
  }
  return(REFRESH_YES);
}

//*******************************************************************
struct LineData * __asm RexxAddFont(
	register __a0 char *FileName, register __d0 UWORD height)
{
	struct LineData *Data;
	BOOL Success = FALSE;
	struct CGBook *Book;
	struct RenderData *R;
	UWORD Type;

	R = RD;
	Book = R->CurrentBook;
	if (Data = AllocLineData(&Book->DataList))
  {
		Data->Height = ANY_HEIGHT; // most font types are set height
		BuildFileName(Data,FileName);
		Type = GetFontDiskType(FileName);
    if( Type!=FONT_TYPE_NOT_FOUND && Type!=FONT_TYPE_NOT_A_FONT )
    {
      if( Type==FONT_TYPE_BULLET || Type==FONT_TYPE_PS )
       	Data->Height = height;
      if (!GetDataFromFileName(&Book->DataList,Data->FileName,Data->Height))
      {
      	PSWaitPointer(TRUE);
      	PSMess[0] = NULL;
      	Data->Data = LoadToasterFont(FileName,Data->Height,Type);
      	PSWaitPointer(FALSE);
      	if (Data->Data)
        {
      		Data->Height = ((struct ToasterFont *)Data->Data)->TextBM.Rows;
      		ReadFileSize(Data);
      		AddSortDataList(&Book->DataList,Data);
      	  if (PageIDOK(Data->ID))			// make it the new default item
          {
      		  R->DefaultLine.Type = Data->Type;
      			R->DefaultAttr.ID = Data->ID;
      			R->LastDefaultFont = Data->ID;
        	}
      		R->UpdateInterface = TRUE;
      		Success = TRUE;
      	}
      }
    }
		if (!Success) FreeLineData(Data);
	}
	return(Success ? Data:NULL);
}


int __asm LOADFunc(register __a0 struct RexxMsg *msg)
{
  char *obj=(ARG0(msg)+4); // ,result[MAX_RESULT]="";
  int n,args=ARG_NUM(msg);
  UWORD A;

  n=MatchCommand(obj,RexxObj,4);
  switch(n)
  {
    case PICTid:
      if(!args)
      {
        CaseLoadRGB((struct IntuiMessage *)msg);
        FillReply(msg,RC_OK,NULL,0);
      }
      else
      {
				if(RD->CommonRGB)
				{
	        if(LoadRGBPicture(ARG1(msg),&RD->CommonRGB->Picture))
  	        FillReply(msg,RC_OK,NULL,0);
    	    else FillReply(msg,RC_ERROR,NULL,ERR_FNRETURN);
				}
    	  else FillReply(msg,RC_ERROR,NULL,ERR_FNRETURN);
      }
      break;
    case BRUSid:
      if(!args)
      {
        if( CaseLoadBrush((struct IntuiMessage *)msg) == REFRESH_YES)
          FillReply(msg,RC_OK,"1",0);
        else FillReply(msg,RC_OK,"0",0);
      }
      else
      {
        if(LoadAddBrush(ARG1(msg)) )
          FillReply(msg,RC_OK,"1",0);
        else FillReply(msg,RC_OK,"0",0);
      }
      break;
    case FONTid:
      if(args<2)
      {
        if( CaseLoadFont((struct IntuiMessage *)msg) == REFRESH_YES)
          FillReply(msg,RC_OK,"1",0);
        else FillReply(msg,RC_OK,"0",0);
      }
      else
      {
        A=atoi(ARG2(msg));
        if(A<10) FillReply(msg,RC_ERROR,NULL,ERR_FNRETURN);
        else if( RexxAddFont(ARG1(msg),A) )
          FillReply(msg,RC_OK,"1",0);
        else FillReply(msg,RC_OK,"0",0);
      }
      break;
/*
    case BOOKid:
      if(!args) FillReply(msg,RC_ERROR,NULL,ERR_BADARGNUM);
      else
      {
        if(DoLoadBook(ARG1(msg),NULL) )  // messes up if page not empty
        {
          FillReply(msg,RC_OK,NULL,0);
          RenderEditPage(RD->CurrentPage);
        }
        else FillReply(msg,RC_OK,"0",0);
      }
      break;
*/
    case BOOKid:
    case PAGEid:
      if(!args) FillReply(msg,RC_ERROR,NULL,ERR_BADARGNUM);
      else
      {
        if(LoadPage(ARG1(msg)) )
        {
          FillReply(msg,RC_OK,NULL,0);
          RenderEditPage(RD->CurrentPage);
        }
        else FillReply(msg,RC_OK,"0",0);
      }
      break;
    case FILEid:
      if(!args)
      {
        if( CaseLoadText((struct IntuiMessage *)msg) == REFRESH_YES)
          FillReply(msg,RC_OK,"1",0);
        else FillReply(msg,RC_OK,"0",0);
      }
      else
      {
        ReadDiskPage(ARG1(msg));  // this f'n will call CGRequest on error!!
  			PreRenderPage(RD->CurrentPage,NULL);
        FillReply(msg,RC_OK,"1",0);
      }
      break;
    default:
      FillReply(msg,RC_ERROR,NULL,ERR_UNKNOWN_FN);
  }
  return(REFRESH_YES);
}

int __asm SAVEFunc(register __a0 struct RexxMsg *msg)
{
  char *obj=(ARG0(msg)+4);
  int n;

  if(ARG_NUM(msg)>=1)
  {
    n=MatchCommand(obj,RexxObj,4);
    switch(n)
    {
      case PAGEid:
        if(SaveCrouton(ARG1(msg))) FillReply(msg,RC_OK,NULL,0);
        else FillReply(msg,RC_ERROR,NULL,ERR_FNRETURN);
        break;
      case BOOKid:
        if(SaveBook(ARG1(msg),RD->CurrentBook)) FillReply(msg,RC_OK,NULL,0);
        else FillReply(msg,RC_ERROR,NULL,ERR_FNRETURN);
        break;
      default:
        FillReply(msg,RC_ERROR,NULL,ERR_UNKNOWN_FN);
        break;
    }
  }
	else FillReply(msg,RC_ERROR,NULL,ERR_BADARGNUM);
  return(REFRESH_NONE);
}

int __asm EXITFunc(register __a0 struct RexxMsg *msg)
{
  FillReply(msg,RC_OK,NULL,0);
  return(REFRESH_EXIT);
}

int __asm RENDFunc(register __a0 struct RexxMsg *msg)
{
  FillReply(msg,RC_OK,NULL,0);
  return(CaseRender((struct IntuiMessage *)msg));
}

int __asm REQ_Func(register __a0 struct RexxMsg *msg)
{
  char *obj=(ARG0(msg)+4),result[MAX_RESULT]="",
       *m1=ReqTitle,*m2=ReqFile,*m3=ReqPath,*ms[8],*ret;
  int i,args=ARG_NUM(msg);

	  if(!args)
	  {
	    FillReply(msg,RC_ERROR,NULL,ERR_BADARGNUM);
	    return(REFRESH_NONE);
	  }

  switch(obj[0])
  {
    case 'a':   case 'A':   // Ask Y/N works like notify
		  if(!args)
		  {
		    FillReply(msg,RC_ERROR,NULL,ERR_BADARGNUM);
		    return(REFRESH_NONE);
		  }
      if(args>2) { ms[2]=ARG3(msg); args=3; }
      if(args>1) ms[1]=ARG2(msg);
      if(args>0) ms[0]=ARG1(msg);
      if(CGMultiRequest(ms,args,REQ_CENTER | REQ_H_CENTER | REQ_OK_CANCEL))
        FillReply(msg,RC_OK,"1",0);
      else FillReply(msg,RC_OK,"0",0);
      break;
    case 't':   case 'T':   // tell
		  if(!args)
		  {
		    FillReply(msg,RC_ERROR,NULL,ERR_BADARGNUM);
		    return(REFRESH_NONE);
		  }
      if(args>4) { ms[4]=ARG5(msg); args=4; }
      if(args>3) ms[3]=ARG4(msg);
      if(args>2) ms[2]=ARG3(msg);
      if(args>1) ms[1]=ARG2(msg);
      if(args>0) ms[0]=ARG1(msg);
      if(CGMultiRequest(ms,args,REQ_CENTER | REQ_H_CENTER ))  // just continue??
        FillReply(msg,RC_OK,"1",0);
      else FillReply(msg,RC_OK,"0",0);
      break;
    case 'f':   case 'F':   // file req
      if(args>2) strncpy(m3,ARG3(msg),MAX_PATH-1);
      if(args>1) strncpy(m2,ARG2(msg),MAX_PATH-1);
			else *m2=0;
      if(args>0) strncpy(m1,ARG1(msg),MACRO_MAX-1);
			else strcpy(m1,"Get File");
      if(ret=FileRequest(m1,m2,m3)) FillReply(msg,RC_OK,m2,0);
      else FillReply(msg,RC_OK,"",0);
      break;
    case 'd':   case 'D':   // Dir req
      if(args>1) strncpy(m3,ARG2(msg),MAX_PATH-1);
			*m2=0;
      if(args>0) strncpy(m1,ARG1(msg),MACRO_MAX-1);
			else strcpy(m1,"Get Directory");
      if(ret=FileRequest(m1,m2,m3))
			{
				i=strlen(m3);
				if((m3[i-1]!=':') && (i<MAX_PATH-1) )
				{
					m3[i]='/';
					m3[i+1]=0;
					FillReply(msg,RC_OK,m3,0);
					m3[i]=0;
				}
				else FillReply(msg,RC_OK,m3,0);
			}
      else FillReply(msg,RC_OK,"",0);
      break;

    case 's':   case 'S':   // string req
      if(args>1) strncpy(result,ARG2(msg),MAX_RESULT);
      if(args>0) ms[0]=ARG1(msg);
      else ms[0]="Enter Text";
      ms[1]="";
      if(CGStringRequest(ms,2,REQ_CENTER | REQ_H_CENTER | REQ_STRING,(APTR)result))
        FillReply(msg,RC_OK,result,0);
      else FillReply(msg,RC_OK,"",0);
      break;

    case 'n':   case 'N':   // Num req
      if(args>1) i=atol(ARG2(msg));
      if(args>0) ms[0]=ARG1(msg);
		  else
		  {
		    FillReply(msg,RC_ERROR,NULL,ERR_BADARGNUM);
		    return(REFRESH_NONE);
		  }
      if(CGSwitcherRequest(ms,1,REQ_CENTER | REQ_H_CENTER | REQ_LONG,&i,TRUE))
      {
        stcu_d(result,i);
        FillReply(msg,RC_OK,result,0);
      }
      else FillReply(msg,RC_OK,"",0);
      break;

    case 'b':   case 'B':   // Bar (title bar!)
      if(args>0)
			{

				strncpy(RexxStatus,ARG1(msg),64);
				NewUpdateMessage(RexxStatus);
			}
      else NewUpdateMessage(NULL);
      FillReply(msg,RC_OK,NULL,0);
      break;

    default:
      FillReply(msg,RC_ERROR,NULL,ERR_UNKNOWN_FN);
  }
  return(REFRESH_YES);
}


void *RxFuncs[LASTid+1] = {
  GET_Func,
  SET_Func,
  PICKFunc,
  MAKEFunc,
  KILLFunc,
  LOADFunc,
  SAVEFunc,
  EXITFunc,
  FEP_Func,
  REQ_Func,
  RENDFunc,
  REXXFunc,
  MACRFunc,
  NULL };


BOOL __asm InitARexx()
{
  BOOL  res=FALSE;
	if ( RexxSysBase=(struct RxsLib *)OpenLibrary("rexxsyslib.library",0L) )
  	if( !FindPort(RX_PORT_NAME) ) // port doesn't exist already
    	if( CGRexxPort=CreatePort(RX_PORT_NAME,0))
      	res=TRUE;
  FEP_Enable=InitFEP();
	ReadConfig(CG_CONFIG);
  return(res);
}

VOID __asm CloseARexx()
{
  struct Message *msg;
	RemFuncHost();
  if(CGRexxPort)
  {
    while(msg=GetMsg(CGRexxPort)) ReplyMsg(msg); // Ignore pending messages
    DeletePort(CGRexxPort);
  }
  CloseFEP();
  if (RexxSysBase) CloseLibrary((struct Library *)RexxSysBase);
}

// strip trailing whitespace off string, return new length
int strtrim(char *str)
{
	int	i=strlen(str)-1;
	while((i>=0) && isspace(str[i]))
		str[i--]=0;
	return(i+1);
}

BOOL ReadConfig(char *cfgfil)
{
	BPTR	fp;
	char buf[256]="",*c;
	int	i=0;
	BOOL ret=FALSE;
	if(fp=Open(cfgfil,MODE_OLDFILE))
	{
		FGets(fp,(STRPTR)&buf,255);
		if(!strncmp(buf,"CG Config",9))  // match file identifier
		{
			ret=TRUE;
			FGets(fp,(STRPTR)&buf,255);
			if(!strnicmp(buf,"#Macros",7)) // Read Macros
				while(FGets(fp,(STRPTR)&buf,255) && *buf!='#')
				{
					c=buf;
					while((*c>30) && (*c!='#') ) c++; // read to comment/EOL
						*c=0; // wipe out comment char in string
					if(*buf && i++<=MACRO_COUNT) strncpy(Macros[i-1],buf,MACRO_MAX-1);
				}
			if(!strnicmp(buf,"#Startup",8)) // Read Startup Macro
				if(FGets(fp,(STRPTR)&buf,255) && *buf!='#')
				{
					c=buf;
					while((*c>30) && (*c!='#') ) c++; // read to comment/EOL
						*c=0; // wipe out comment char in string
					if(*buf) strncpy(StartupMac,buf,MACRO_MAX-1);
					FGets(fp,(STRPTR)&buf,255);
				}
			i=0;
			if(!strnicmp(buf,"#Paths",6)) // Read Paths
				while(FGets(fp,(STRPTR)&buf,255) && *buf!='#')
				{
					c=buf;
					while((*c>30) && (*c!='#') ) c++; // read to comment/EOL
						*c=0; // wipe out comment char in string
					if(*buf && i++<=4)
					{
						strtrim(buf);
						strncpy(Paths[i-1],buf,MAX_PATH-1);
					}
				}
			i=0;
			if(!strnicmp(buf,"#Devices",8)) // Read  Devices
				while(FGets(fp,(STRPTR)&buf,255) && *buf!='#')
				{
					c=buf;
					while((*c>30) && (*c!='#') ) c++; // read to comment/EOL
						*c=0; // wipe out comment char in string
					if(*buf && i++<=7)
					{
						strtrim(buf);
						strncpy(Devs[i-1],buf,(i&1 ? 7:MAX_PATH-1));
					}
				}
		}
		Close(fp);
	}
	return(ret);
}

// Send a filename to ARexx resident process for execution
BOOL ARexxMacro(char *macro)
{
	struct RexxMsg *msg;
	struct MsgPort *port;
//	if( !(msg = CreateRexxMsg(CGRexxPort,NULL,NULL)) )
	if( !(msg = CreateRexxMsg(FEP_ReplyPort,NULL,NULL)) )
		return( FALSE );
	msg->rm_Action  = RXCOMM|RXFF_NOIO;
	if( !(msg->rm_Args[0]=CreateArgstring(macro,strlen(macro))) )
		return(FALSE);
	msg->rm_Args[1] = (STRPTR) 0;
	Forbid();
	if( ( port = FindPort( (UBYTE *) "AREXX" ) ) != NULL )
		PutMsg( port, (struct Message *) msg );
	Permit();
	DumpStr("Sent Macro: ");
	DumpMsg(ARG0(msg));
	if(!port)
	{
		DumpStr("Didn't Send Macro: ");
		DumpMsg(ARG0(msg));
		ClearRexxMsg( msg, 16 );
		DeleteRexxMsg( msg );
		msg = NULL;
	}
	else
  {
    WaitPort(FEP_ReplyPort);
    while(msg=(struct RexxMsg *)GetMsg(FEP_ReplyPort))
      if (msg->rm_Node.mn_Node.ln_Type != NT_REPLYMSG)
			{
				DumpStr("Got weird, non-reply message in reply port!!???\7/7 ");
				ReplyMsg((struct Message *)msg); // shouldn't happen
			}
      else
      {
				DumpStr("Got Macro Reply: ");
				DumpMsg(ARG0(msg));
				ClearRexxMsg( msg, 16 );
				DeleteRexxMsg( msg );
				msg = NULL;
      }
  }

	return( (BOOL) (msg != NULL) );
}


// This f'n adds the port name to list of function hosts... this is best left to the arexx prog.
BOOL AddFuncHost()
{
  struct RexxMsg *msg;
  struct MsgPort *port;

  if( !(msg = CreateRexxMsg(CGRexxPort,".cgx",RX_PORT_NAME)) )
      return( FALSE );
  msg->rm_Action  = RXADDFH | RXFF_NONRET;
  msg->rm_Args[0] = (STRPTR) RX_PORT_NAME;
  msg->rm_Args[1] = (STRPTR) 0;
  Forbid();
  if( ( port = FindPort( (UBYTE *) "REXX" ) ) != NULL )
      PutMsg( port, (struct Message *) msg );
  else
    {
      ClearRexxMsg( msg, 16 );
      DeleteRexxMsg( msg );
      msg = NULL;
    }
  Permit();
  return( (BOOL) (msg != NULL) );
}

BOOL RemFuncHost()
{
  struct RexxMsg *msg;
  struct MsgPort *port;
  if( !(msg = CreateRexxMsg(CGRexxPort,".cgx",RX_PORT_NAME)) )
    return( FALSE );
  msg->rm_Action  = RXREMLIB | RXFF_NONRET;
  msg->rm_Args[0] = (STRPTR) RX_PORT_NAME;
  Forbid();
  if( ( port = FindPort( (UBYTE *) "REXX" ) ) != NULL )
    PutMsg( port, (struct Message *) msg );
  else
  {
    ClearRexxMsg( msg, 16 );
    DeleteRexxMsg( msg );
    msg = NULL;
  }
  Permit();
  return( (BOOL) (msg != NULL) );
}

void ReplyARexxMess(struct RexxMsg *msg, LONG rc, char *result, LONG errc)
{
  msg->rm_Result1 = rc;
  msg->rm_Result2 = (LONG) NULL;
  if( result != NULL && rc == RC_OK && (msg->rm_Action&RXFF_RESULT)!=0 )
      msg->rm_Result2 = (LONG)CreateArgstring(result,strlen(result));
  else if( rc != RC_OK ) msg->rm_Result2 = errc;
  ReplyMsg( (struct Message *) msg );
}

void FillReply(struct RexxMsg *msg, LONG rc, char *result, LONG errc)
{
  msg->rm_Result1 = rc;
  msg->rm_Result2 = (LONG) NULL;
  if( (result!=NULL) && (rc==RC_OK) && ((msg->rm_Action&RXFF_RESULT)!=0) )
      msg->rm_Result2 = (LONG)CreateArgstring(result,strlen(result));
  else if( rc != RC_OK ) msg->rm_Result2 = errc;
}

int __asm HandleARexxMess(register __a0 struct RexxMsg *msg)
{
// AAR - CleanFlushe
  int CleanFlushe=REFRESH_NONE;

  if(IS_REPLY(msg))
	{
		DumpStr("Reply: ");
		DumpMsg(ARG0(msg));
		ClearRexxMsg( msg, 16 );
		DeleteRexxMsg( msg );
// AAR - CleanFlushe
		return(CleanFlushe);
	}
	DumpStr("Message: ");
	DumpMsg(ARG0(msg));
// AAR - CleanFlushe
  if(IS_FUNCTION(msg)) CleanFlushe=HandleCommand(msg);
	else FillReply(msg,RC_ERROR,NULL,ERR_BADMESS);
  ReplyMsg((struct Message *)msg);
// AAR - CleanFlushe
  return(CleanFlushe);
}

int __asm HandleCommand(register __a0 struct RexxMsg *msg)
{
// AAR - CleanFlushe
  int i,CleanFlushe=REFRESH_NONE;
//  UWORD args;
	int __asm (*Handler)(register __a0 struct RexxMsg *);

	PSWaitPointer(TRUE);

//  args=(UWORD)ARG_NUM(msg);
//  if(CGMultiRequest(msg->rm_Args,(args>1 ? args:1)+1,REQ_CENTER|REQ_H_CENTER|REQ_OK_CANCEL))
  {
    i=MatchCommand(ARG0(msg),RexxCmd,4);
    if(i == NO_MATCH )
    {
//      CGRequest("Unknown Command...");
      FillReply(msg,RC_WARN,NULL,ERR_MISSING_FN);
   		PSWaitPointer(FALSE);
      return(FALSE);
    }
    Handler=(int (* __asm )(struct RexxMsg *) )RxFuncs[i];  // IGNORE THIS WARNING
// AAR - CleanFlushe
    if(i<NULLid && Handler!=NULL) CleanFlushe=Handler(msg);
 		PSWaitPointer(FALSE);
// AAR - CleanFlushe
    return(CleanFlushe);
  }
// 	PSWaitPointer(FALSE);
//  return(REFRESH_NONE);  // No problem missing this
}

int MatchCommand(char *cmd, UBYTE **Array,int len)
{
  int i=0;
  while( Array[i][0] && strnicmp(cmd,Array[i],len)!=0 ) i++;
  return( (Array[i][0]) ? i:NO_MATCH);
}

void __asm DoStartupMacro()
{
	if(*StartupMac) ARexxMacro(StartupMac);
}


BOOL InitFEP()
{
  if( (FEP_ReplyPort = CreatePort (FEPREP_PORT_NAME, 0L)) == NULL ) return(FALSE);
  if ((FEPmsg = CreateRexxMsg (FEP_ReplyPort,NULL,NULL)))
  {
    FEPmsg->rm_Action = RXFUNC|RXFF_RESULT|(UBYTE)1;
    FEPmsg->rm_LibBase = (APTR) RexxSysBase;
    Edit=CreateArgstring(EDIT_CMD,strlen(EDIT_CMD));
    Begin=CreateArgstring(BEGIN_CMD,strlen(BEGIN_CMD));
    Intuimsg=CreateArgstring(INTUIMSG_CMD,strlen(INTUIMSG_CMD));
    Verify=CreateArgstring(VERIFY_CMD,strlen(VERIFY_CMD));
    Addr=CreateArgstring("\0\0\0\0\0\0\0\0\0\0\0\0",12);
    CodeWord=CreateArgstring("\0\0\0\0\0\0\0\0",8);
    FEPmsg->rm_Args[1]=Addr;
    if(Edit && Addr && Begin && Intuimsg && Verify)
      return(TRUE);
    else  // Clean up and return false
    {
      if(Edit) DeleteArgstring (Edit);
      if(Begin) DeleteArgstring (Begin);
      if(Addr) DeleteArgstring (Addr);
      if(Intuimsg) DeleteArgstring (Intuimsg);
      if(Verify) DeleteArgstring (Verify);
      if(CodeWord) DeleteArgstring (CodeWord);
      DeleteRexxMsg(FEPmsg);
    }
  }
  DeletePort(FEP_ReplyPort);
  return(FALSE);
}

void CloseFEP()
{
  if(Edit) DeleteArgstring (Edit);
  if(Begin) DeleteArgstring (Begin);
  if(Addr) DeleteArgstring (Addr);
  if(Intuimsg) DeleteArgstring (Intuimsg);
  if(CodeWord) DeleteArgstring (CodeWord);
  if(FEPmsg) DeleteRexxMsg(FEPmsg);
  if(FEP_ReplyPort) DeletePort(FEP_ReplyPort);
}

int __asm SendFEP(register __a0 char *argstr, register __a1  char *arg)
{                  /* Array of args, num of args from f'n (arg[0]) */
  struct RexxMsg *repmsg;
  int result=0;
  struct MsgPort *ToPort;

//  char mess[180]="";

  FEPmsg->rm_Args[0]=argstr;
  strcpy(FEPmsg->rm_Args[1],arg);
  Forbid();  // Don't let port escape once it's found!
    if (ToPort = (struct MsgPort *)FindPort(FEP_PORT_NAME))
      PutMsg (ToPort, (struct Message *) FEPmsg);
  Permit();
  if (ToPort)
  {
    WaitPort(FEP_ReplyPort);
    while(repmsg=(struct RexxMsg *)GetMsg(FEP_ReplyPort))
      if (repmsg->rm_Node.mn_Node.ln_Type != NT_REPLYMSG)  ReplyMsg((struct Message *)repmsg);
      else if(!repmsg->rm_Result1)  /* No Error has occured! */
      {
        if( HAS_RESULT(FEPmsg) ) result=atol((char *)repmsg->rm_Result2);
        else result=1;

//         sprintf(mess," A: %d B: %s c: %d",result,(char *)repmsg->rm_Result2,repmsg->rm_Result2);
//         CGRequest(mess);

        if(HAS_RESULT(FEPmsg) && result && repmsg->rm_Result2 != (ULONG)repmsg->rm_Args[0])
          DeleteArgstring((char *)repmsg->rm_Result2);
      }

  }
  return(result);
}

void __asm FEP_IntuiMsg(register __a0 struct IntuiMessage *msg)
{
  char addr[12]="";
  sprintf(addr,"%10d",(ULONG)msg);
  SendFEP(Intuimsg,addr);
}

/* UWORD __asm FEP_Edit(register __d0 UWORD glyph)
{
  char addr[12]="";
  UWORD NewGlyph=0;
  sprintf(addr,"%10d",(ULONG)RD->InterfaceScreen);
  sprintf(CodeWord,"%6d",glyph);
  FEPmsg->rm_Action = RXFUNC|RXFF_RESULT|(UBYTE)2;
  FEPmsg->rm_Args[2]=CodeWord;
  NewGlyph=(UWORD)SendFEP(Edit,addr);
  FEPmsg->rm_Action = RXFUNC|RXFF_RESULT|(UBYTE)1;
  FEPmsg->rm_Args[2] = NULL;
  return( NewGlyph );
}   */


// str must have storage for at least 3 bytes!
void  Word2Str(UWORD code, UBYTE *str)
{
  str[0] = ((UBYTE *)&code)[0];
  str[1] = ((UBYTE *)&code)[1];
  str[2] = 0;
}

UWORD __asm FEP_Edit(register __a0 struct CGLine *Line)
{
  char addr[12]="";
  struct TextInfo *t=Line->Text;
  int len;
  UWORD i;

  sprintf(addr,"%10d",(ULONG)RD->InterfaceScreen);
  len=LineLength(Line);
  codebuf=CreateArgstring("",len*3);
  for(i=0;i<len;i++,t++)
    Word2Str(t->Ascii,&(codebuf[i*3]));
  FEPmsg->rm_Action = RXFUNC|(UBYTE)2;  // don't ask for result
  FEPmsg->rm_Args[2]=codebuf;
  i=SendFEP(Edit,addr);
  FEPmsg->rm_Action = RXFUNC|RXFF_RESULT|(UBYTE)1;
  FEPmsg->rm_Args[2] = NULL;
  DeleteArgstring(codebuf);
  return( i );
}

BOOL __asm FEP_VerifyFont(register __a1 char *font)  // Verify that font is OK default to true on error
{   // return false if FEP gives no error and returns 0
  struct RexxMsg *repmsg;
  char *argstr;
  BOOL result=TRUE;
  struct MsgPort *ToPort;

  argstr=FEPmsg->rm_Args[1];
  FEPmsg->rm_Args[0]=Verify;
  if( !(FEPmsg->rm_Args[1]=CreateArgstring(font,strlen(font))) ) return(TRUE);
  Forbid();
    if (ToPort = (struct MsgPort *)FindPort(FEP_PORT_NAME))
      PutMsg (ToPort, (struct Message *) FEPmsg);
  Permit();
  if (ToPort)
  {
    WaitPort(FEP_ReplyPort);
    while(repmsg=(struct RexxMsg *)GetMsg(FEP_ReplyPort))
      if (repmsg->rm_Node.mn_Node.ln_Type != NT_REPLYMSG)  ReplyMsg((struct Message *)repmsg);
      else if(!repmsg->rm_Result1)  /* No Error has occured! */
      {
        result=( repmsg->rm_Result2==0 ? FALSE:TRUE );
        if(result && (repmsg->rm_Result2 != (ULONG)repmsg->rm_Args[0]) )
          DeleteArgstring((char *)repmsg->rm_Result2);
      }
  }
  DeleteArgstring(FEPmsg->rm_Args[1]);
  FEPmsg->rm_Args[1]=argstr;
  return(result);
}

BOOL __asm FindFEP()
{
  if(FEP_Enable && FindPort(FEP_PORT_NAME)) return(TRUE);
  else return(FALSE);
}

BOOL CompLoad(char *buf,WORD H,ULONG type)
{
  struct LineData *Data;
 	if (Data = AllocLineData(&RD->CurrentBook->DataList))
  {
		BuildFileName(Data,buf);
    Data->Height = H;
 		if (!GetDataFromFileName(&RD->CurrentBook->DataList,Data->FileName,Data->Height))
    {
			PSWaitPointer(TRUE);
      Data->Data = NewLoadPSCompFont(buf,Data->Height,type);
 			PSWaitPointer(FALSE);
      if (Data->Data)
      {
        AddSortDataList(&RD->CurrentBook->DataList,Data);
        return(TRUE);
      }
    }
    FreeLineData(Data);
  }
  return(FALSE);
}

BOOL ChooseOne(char *tit, char *First, char *Second)
{
  char *ms[5];
  ms[0]=tit;
  ms[1]="Your Choice... ";
  ms[2]=First;
  ms[3]=Second;
  return(CGMultiRequest(ms,4,REQ_CUSTOMTEXT |REQ_CENTER | REQ_H_CENTER | REQ_OK_CANCEL));
}

// uses RD->ByteStrip->Planes[0]
#define BUFF_SIZE 90000
#define PSPLANE_SIZE	128000 // 1280x800 bits

WORD __asm CaseTestFun(register __a0 struct IntuiMessage *IntuiMsg)
{
	WORD Refresh = REFRESH_YES;

//	if(InitGadgetImagery())
//		FreeGadgetImagery();
/*
	strncpy(ReqTitle,"Load BOOK",MACRO_MAX-1);
	strncpy(ReqBuf1," Gurm",MACRO_MAX-1);
	strncpy(ReqBuf2," 'scool",MACRO_MAX-1);
	if(DoTellReqPanel(ReqTitle,ReqBuf1,ReqBuf2,""))
		DoTestPanel();
//if(ret=FileRequest(m1,m2,m3))
// if(DoLoadBook(ret,NULL) )  // messes up if page not empty
*/
	return(Refresh);
}

WORD __asm CaseMacro(register __a0 struct IntuiMessage *IntuiMsg)
{
	WORD Refresh = REFRESH_YES,Code = IntuiMsg->Code - RAW_F1;
	if(IntuiMsg->Qualifier & (IEQUALIFIER_LSHIFT|IEQUALIFIER_RSHIFT) )
		Code+=10;
	if( (Code>=0) && (Code<=MACRO_COUNT) )
		ARexxMacro(Macros[Code]);
	return(Refresh);
}

WORD __asm CaseHotKey(register __a0 struct IntuiMessage *IntuiMsg)
{
	WORD Refresh = REFRESH_NONE,bmode;
	struct RenderData *R;
	struct CGLine *Line;
  char addr[12]="";

	R = RD;
#ifdef DEBUG
	CheckBook(RD->CurrentBook);
#endif
	if(IntuiMsg->Code == 0x20) // if hotkey is ctl-space
		if( !(IntuiMsg->Qualifier&IEQUALIFIER_CONTROL) ) return(CaseDefault(0x20,0));
  if(R->BarMode==BAR_FEP) return(Refresh);
  if(FindFEP())
  {
    bmode=R->BarMode;
    TemplateOff();
    R->BarMode=BAR_FEP;

    if (Line = RD->CurrentLine)
      if(AnyCharSelected(Line))
      {
//        if( FEP_Edit(Line) ) 			Modify By Dekune
        if( !FEP_Edit(Line) ) 
        {
          Refresh = REFRESH_YES;
        }
        else {
          TemplateOn(bmode);
        }
      	return(Refresh);
      }
    sprintf(addr,"%10d",(ULONG)R->InterfaceScreen);
    if( !SendFEP(Begin,addr) ) // Fep Begin failed
    {
      TemplateOn(bmode);
    }
  	else
    {
      Refresh = REFRESH_YES;
    }
  }
  else return(CaseTestFun(IntuiMsg));
	return(Refresh);
}

