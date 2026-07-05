#!/usr/bin/env python3
# Generates TZ01_provision_full.ps1 (PnP.PowerShell / PS7+) from the app's
# App.OnStart collections, so the SharePoint site is created and seeded with
# exactly the test data currently held in the app.
import re

SRC="TZ01/src/Src/App.fx.yaml"
OUT="TZ01/provisioning/TZ01_provision_full.ps1"

raw=open(SRC,encoding="utf-8").read()
body="\n".join(l for l in raw.split("\n") if not l.strip().startswith("//"))

def seg(name):
    i=body.find("ClearCollect("+name+","); j=body.find("(",i); d=0; k=j
    while k<len(body):
        if body[k]=="(":d+=1
        elif body[k]==")":
            d-=1
            if d==0: break
        k+=1
    return body[i:k+1]

def records(s):
    out=[]; d=0; cur=None
    for idx,c in enumerate(s):
        if c=="{":
            if d==0: cur=idx
            d+=1
        elif c=="}":
            d-=1
            if d==0: out.append(s[cur:idx+1])
    return out

def split_top(s):           # split "a:1, b:2" on top-level commas
    parts=[]; d=0; cur=""; q=None
    for c in s:
        if q:
            cur+=c
            if c==q: q=None
            continue
        if c in '"\'': q=c; cur+=c; continue
        if c in "{[(": d+=1
        elif c in "}])": d-=1
        if c=="," and d==0:
            parts.append(cur); cur=""
        else: cur+=c
    if cur.strip(): parts.append(cur)
    return parts

def parse_val(v):
    v=v.strip()
    if v.startswith('"'):
        return ("s", v[1:v.rfind('"')])
    if v=="Blank()": return ("null",None)
    m=re.match(r'DateValue\("(\d+)-(\d+)-(\d+)"\)',v)
    if m: return ("d",(int(m.group(1)),int(m.group(2)),int(m.group(3))))
    m=re.match(r'Date\((\d+),\s*(\d+),\s*(\d+)\)',v)
    if m: return ("d",(int(m.group(1)),int(m.group(2)),int(m.group(3))))
    if v in ("true","false"): return ("b", v=="true")
    if re.match(r'^-?\d+$',v): return ("n", int(v))
    if re.match(r'^-?\d*\.\d+$',v): return ("n", float(v))
    return ("s", v)

def parse_rec(rec):
    inner=rec.strip()[1:-1]
    out=[]
    for part in split_top(inner):
        if ":" not in part: continue
        # key is up to first top-level colon
        d=0; q=None; ci=None
        for i,c in enumerate(part):
            if q:
                if c==q:q=None
                continue
            if c in '"\'':q=c;continue
            if c in "{[(":d+=1
            elif c in "}])":d-=1
            elif c==":" and d==0: ci=i; break
        key=part[:ci].strip().strip("'").strip()
        out.append((key, parse_val(part[ci+1:])))
    return out   # list of (key,(type,value)) preserving order

def parse_collection(name):
    return [parse_rec(r) for r in records(seg(name))]

col={n:parse_collection(n) for n in
     ["colDailyItems","colDailyReports","colChecks","colTransactions",
      "colReasonConfig","colReviewers","colCheckColumns","colTopReport",
      "colInputFiles","colAudit"]}

# ---- PS literal emitters ----
def ps_str(s): return "'"+s.replace("'","''")+"'"
def ps_val(tv):
    t,v=tv
    if t=="s": return ps_str(v)
    if t=="n": return str(v)
    if t=="b": return "$true" if v else "$false"
    if t=="d": return f"(Get-Date -Year {v[0]} -Month {v[1]} -Day {v[2]})"
    return "$null"
def d(rec): return {k:v for k,v in rec}

# ---- source columns (ch. 14.5 display names) ----
FX_SRC=["Company Code","Transaction","Business Partner","Product Type","Product type name",
 "Transaction Type","Name of Transaction Type","Buy/Sell Indicator","Value Date","Expiration Date",
 "Traded Currency","Payment Amount in Payment Currency","Oposit Currency","Oposit Amount",
 "Premium Currency","Premium Amount","Transaction Rate","Leading Currency","Following Currency",
 "Contract Date","Contract.Concl.Time","Trader","Reference","Assignment","Characteristics",
 "Internal Reference","Trading Platform ID","Hedge request","Entered On","Expire/Exercise",
 "Active Status","Release Status","Active activity","Market spot rate"]
MM_SRC=["Company Name","Transaction category","Transaction Currency","Amount/start","Interest Rate",
 "Interest amount","Term Start","Term End","Changed On","Activity Category","Activity Categ. Name"]
SRC_COLS=FX_SRC+[c for c in MM_SRC if c not in FX_SRC]
def enc(n): return re.sub(r"[^A-Za-z0-9]","",n)

# workflow columns on Daily Transactions (display, internal, type)
TXN_WF=[
 ("TxnKey","TxnKey","Text"),("Day Key","DayKey","Text"),
 ("DailyItemID","DailyItemID","Number"),("DailyReportID","DailyReportID","Number"),
 ("DailyReportCheckID","DailyReportCheckID","Number"),
 ("Report Type","ReportType","Choice:FX,MM"),("Check Number","CheckNumber","Number"),
 ("TransactionNo","TransactionNo","Text"),("Product Type (wf)","ProductTypeWf","Text"),
 ("Txn Type Name","TxnTypeName","Text"),("Amount","Amount","Number"),("Currency","Currency","Text"),
 ("MO Reason","MOReason","Text"),("MO Comment","MOComment","Note"),
 ("Flagged To FO","FlaggedToFO","Boolean"),("FO Reviewer","FOReviewer","Text"),
 ("FO Sent","FOSent","Boolean"),("FO Sent On","FOSentOn","DateTime"),
 ("FO Reason","FOReason","Text"),("FO Comment","FOComment","Note"),
 ("FO Responded On","FORespondedOn","DateTime"),("FO Responded","FOResponded","Boolean"),
 ("Status (legacy)","Status","Text"),("Is Late","IsLate","Boolean"),("Days Late","DaysLate","Number"),
]
# collection field -> workflow internal name (ProductType collides with source 'Product Type')
WF_MAP={"DayKey":"DayKey","DailyItemID":"DailyItemID","DailyReportID":"DailyReportID",
 "DailyReportCheckID":"DailyReportCheckID","ReportType":"ReportType","CheckNumber":"CheckNumber",
 "TransactionNo":"TransactionNo","ProductType":"ProductTypeWf","TxnTypeName":"TxnTypeName",
 "Amount":"Amount","Currency":"Currency","MOReason":"MOReason","MOComment":"MOComment",
 "FlaggedToFO":"FlaggedToFO","FOReviewer":"FOReviewer","FOSent":"FOSent","FOSentOn":"FOSentOn",
 "FOReason":"FOReason","FOComment":"FOComment","FORespondedOn":"FORespondedOn",
 "FOResponded":"FOResponded","Status":"Status","IsLate":"IsLate","DaysLate":"DaysLate"}
TXN_SKIP={"ID","DailyItemID","DailyReportID","DailyReportCheckID","_foDraftReason","_foDraftComment"}

SCOPE={("FX",1):"Internal deals net to zero",("FX",2):"CH06 pairwise offset",
 ("FX",3):"DTCC transactions",("FX",4):"Spot vs transaction rate ±5%",
 ("FX",5):"Late entry → TOP report",("FX",6):"Hedging (exceptional → VITUS)",
 ("MM",1):"55A intercompany both legs",("MM",2):"53A commercial paper sum",
 ("MM",3):"No transaction under 56A/56B/56C",("MM",4):"Late entry (56D → Credit line)"}

# findings count per (ReportType, CheckNumber)
fcount={}
for r in col["colTransactions"]:
    dd=d(r); k=(dd["ReportType"][1],dd["CheckNumber"][1]); fcount[k]=fcount.get(k,0)+1

L=[]  # output lines
def w(s=""): L.append(s)

w("#requires -Version 7.0")
w("#requires -Modules PnP.PowerShell")
w("<#")
w("  TZ01 — full SharePoint provisioning + test-data seed  (PnP.PowerShell, PS 7+)")
w("  GENERATED from the app's App.OnStart collections — the seed below is exactly the")
w("  test data the canvas app currently holds offline. Re-generate with")
w("  TZ01/provisioning/gen_provision.py after changing the seed.")
w("")
w("  Creates the 9 TZ01 lists (proposal ch. 14) with friendly display names +")
w("  compact internal names, so the app's production ClearCollect/RenameColumns")
w("  (see App.OnStart 'PRODUCTION SWAP' block) binds without changes, and seeds")
w("  every list with the current collection data in dependency order (real")
w("  SharePoint IDs are captured and wired into child FK columns).")
w("")
w("  USAGE")
w("    pwsh> Install-Module PnP.PowerShell -Scope CurrentUser        # once")
w("    pwsh> ./TZ01_provision_full.ps1 -SiteUrl https://<tenant>.sharepoint.com/sites/<TZ01> [-Reseed]")
w("    Interactive sign-in by default. For app-only (unattended) pass -ClientId <appId>")
w("    and register PnP (Register-PnPEntraIDAppForInteractiveLogin) beforehand.")
w("")
w("    -Reseed        delete existing items in each list before seeding (columns kept)")
w("    -SkipPeople    do not attempt to resolve the Reviewer person column (text email only)")
w("#>")
w("param(")
w("  [Parameter(Mandatory)][string]$SiteUrl,")
w("  [string]$ClientId,")
w("  [switch]$Reseed,")
w("  [switch]$SkipPeople")
w(")")
w("$ErrorActionPreference = 'Stop'")
w("$InformationPreference = 'Continue'")
w("")
w("if ($ClientId) { Connect-PnPOnline -Url $SiteUrl -Interactive -ClientId $ClientId }")
w("else           { Connect-PnPOnline -Url $SiteUrl -Interactive }")
w("Write-Information \"Connected to $SiteUrl\"")
w("")
w("# --------------------------------------------------------------------------")
w("# helpers (idempotent)")
w("# --------------------------------------------------------------------------")
w("function Ensure-List([string]$Title){")
w("  $l = Get-PnPList -Identity $Title -ErrorAction SilentlyContinue")
w("  if (-not $l){ $l = New-PnPList -Title $Title -Template GenericList -EnableVersioning; Write-Information \"list + $Title\" }")
w("  return $l")
w("}")
w("function Ensure-Field($List,$Display,$Internal,$Type,$Choices){")
w("  if (Get-PnPField -List $List -Identity $Internal -ErrorAction SilentlyContinue){ return }")
w("  if ($Type -eq 'Choice'){")
w("    Add-PnPField -List $List -DisplayName $Display -InternalName $Internal -Type Choice -Choices $Choices -AddToDefaultView | Out-Null")
w("  } else {")
w("    Add-PnPField -List $List -DisplayName $Display -InternalName $Internal -Type $Type -AddToDefaultView | Out-Null")
w("  }")
w("  Write-Information \"  field + $Display ($Internal/$Type)\"")
w("}")
w("function Clear-List($List){")
w("  if ($Reseed){")
w("    Get-PnPListItem -List $List -PageSize 500 | ForEach-Object { Remove-PnPListItem -List $List -Identity $_.Id -Force | Out-Null }")
w("    Write-Information \"  cleared items in $List\"")
w("  }")
w("}")
w("function Add-TzItem($List,[hashtable]$Values){ return (Add-PnPListItem -List $List -Values $Values).Id }")
w("")

# ----- column schema per list, emitted as Ensure-Field calls -----
def emit_fields(varname, cols):
    for c in cols:
        disp,intn,typ=c[0],c[1],c[2]
        if typ.startswith("Choice:"):
            ch=typ.split(":",1)[1]
            arr="@("+",".join(ps_str(x) for x in ch.split(","))+")"
            w(f"Ensure-Field ${varname} {ps_str(disp)} {ps_str(intn)} 'Choice' {arr}")
        elif typ=="Note":
            w(f"Ensure-Field ${varname} {ps_str(disp)} {ps_str(intn)} 'Note' $null")
        else:
            w(f"Ensure-Field ${varname} {ps_str(disp)} {ps_str(intn)} '{typ}' $null")

DI_COLS=[("DayKey","DayKey","Text"),("ItemDate","ItemDate","DateTime"),
 ("Status","Status","Choice:To be processed,In review,Completed"),("Reviewer","Reviewer","Text"),
 ("FXFindings","FXFindings","Number"),("MMFindings","MMFindings","Number"),
 ("SubmittedOn","SubmittedOn","DateTime"),("ReviewLog","ReviewLog","Note")]
DR_COLS=[("DailyItemID","DailyItemID","Number"),("DayKey","DayKey","Text"),
 ("ReportType","ReportType","Choice:FX,MM"),("ReportKey","ReportKey","Text"),
 ("ReportDate","ReportDate","DateTime"),("Status","Status","Choice:In review,Completed"),
 ("Reviewer","Reviewer","Text"),("ReviewLog","ReviewLog","Note"),("Submitted","Submitted","Boolean")]
CK_COLS=[("CheckKey","CheckKey","Text"),("ReportKey","ReportKey","Text"),
 ("DailyReportID","DailyReportID","Number"),("DayKey","DayKey","Text"),
 ("Report Type","ReportType","Choice:FX,MM"),("Check Number","CheckNumber","Number"),
 ("Check Name","CheckName","Text"),("Scope","Scope","Text"),
 ("Result","Result","Choice:No finding,Finding,Not compared,Late,Exceptional"),
 ("Findings Count","FindingsCount","Number"),("FO Flagged Count","FOFlaggedCount","Number"),
 ("Not Compared","NotCompared","Boolean"),("Is Late","IsLate","Boolean"),
 ("Completed","Completed","Boolean"),("Completed On","CompletedOn","DateTime")]
RC_COLS=[("Report Type","ReportType","Choice:FX,MM,Both"),("Check Number","CheckNumber","Number"),
 ("Role","Role","Choice:MO,FO"),("Auto","Auto","Boolean"),("Auto Flag FO","AutoFlagFO","Boolean"),
 ("Requires Comment","RequiresComment","Boolean"),("Order","Order","Number"),("Active","Active","Boolean")]
RV_COLS=[("Reviewer","Reviewer","User"),("Email","Email","Text"),("Name","Name","Text"),
 ("Group","Group","Choice:MO,FO,ADMIN"),("Report Type","ReportType","Text"),
 ("Check Number","CheckNumber","Number"),("Default","IsDefault","Boolean"),("Active","Active","Boolean")]
CC_COLS=[("Report","Report","Choice:FX,MM"),("Check Number","CheckNumber","Number"),
 ("Column Name","ColumnName","Text"),("Order","Order","Number"),("Align","Align","Choice:left,right")]
TR_COLS=[("MonthKey","MonthKey","Text"),("DayKey","DayKey","Text"),("ReportType","ReportType","Choice:FX,MM"),
 ("TransactionNo","TransactionNo","Text"),("ProductType","ProductType","Text"),
 ("EnteredOn","EnteredOn","DateTime"),("ContractDate","ContractDate","DateTime"),
 ("DaysLate","DaysLate","Number"),("Amount","Amount","Number"),("Reason","Reason","Text"),
 ("SourceTxnID","SourceTxnID","Number")]
IF_COLS=[("DayKey","DayKey","Text"),
 ("FileKind","FileKind","Choice:FX Listing,MM Listing,ZTRM Export,US Bank Report,Other"),
 ("ReportType","ReportType","Text"),("FileName","FileName","Text"),
 ("ReceivedOn","ReceivedOn","DateTime"),("Source","Source","Text"),("Validated","Validated","Boolean")]
TXN_COLS=TXN_WF+[(c,enc(c),"Text") for c in SRC_COLS]

lists=[("TZ01 Daily Item","di",DI_COLS),("TZ01 Daily Reports","dr",DR_COLS),
 ("TZ01 Daily Report Checks","ck",CK_COLS),("TZ01 Daily Transactions","tx",TXN_COLS),
 ("TZ01 Reason Config","rc",RC_COLS),("TZ01 Reviewers","rv",RV_COLS),
 ("TZ01 Check Columns","cc",CC_COLS),("TZ01 Top Report","tr",TR_COLS),
 ("TZ01 Input Files","inf",IF_COLS)]

w("# --------------------------------------------------------------------------")
w("# 1) lists + columns")
w("# --------------------------------------------------------------------------")
for title,var,cols in lists:
    w(f"${var} = Ensure-List {ps_str(title)}")
    emit_fields(var, cols)
    w("")

w("# --------------------------------------------------------------------------")
w("# 2) seed (dependency order; real IDs captured for child FK columns)")
w("# --------------------------------------------------------------------------")
for _,var,_ in lists:
    w(f"Clear-List ${var}")
w("")

# ----- Daily Item -----
di=d(col["colDailyItems"][0])
audit_lines="; ".join(f"{ps_str_x}" for ps_str_x in [])  # placeholder
review_log=" \\n".join(a[1] for a in [(k,v) for rec in col["colAudit"] for (k,v) in [] ])
# build review log text from colAudit (Stamp Text)
al=[]
for rec in col["colAudit"]:
    dd=d(rec); al.append(dd["Text"][1])
review_text=" | ".join(al)
w("# --- TZ01 Daily Item (1 row) ---")
w("$itemValues = @{")
w(f"  Title = {ps_str(di['Title'][1])}")
w(f"  DayKey = {ps_val(di['DayKey'])}")
w(f"  ItemDate = {ps_val(di['ItemDate'])}")
w(f"  Status = {ps_val(di['Status'])}")
w(f"  Reviewer = {ps_val(di['Reviewer'])}")
w(f"  FXFindings = {ps_val(di['FXFindings'])}")
w(f"  MMFindings = {ps_val(di['MMFindings'])}")
w(f"  ReviewLog = {ps_str(review_text)}")
w("}")
w("$itemId = Add-TzItem $di $itemValues")
w("Write-Information \"seeded Daily Item -> ID $itemId\"")
w("")

# ----- Daily Reports -----
w("# --- TZ01 Daily Reports (2) ---")
w("$reportId = @{}")
for rec in col["colDailyReports"]:
    dd=d(rec); rt=dd["ReportType"][1]
    w("$v = @{")
    w("  DailyItemID = $itemId")
    w(f"  Title = {ps_val(dd['ReportKey'])}")
    for f_ in ["DayKey","ReportType","ReportKey","ReportDate","Status","Submitted"]:
        if f_ in dd: w(f"  {f_} = {ps_val(dd[f_])}")
    if dd.get("Reviewer",("null",None))[0]!="null":
        w(f"  Reviewer = {ps_val(dd['Reviewer'])}")
    if dd.get("ReviewLog",("null",None))[0]!="null":
        w(f"  ReviewLog = {ps_val(dd['ReviewLog'])}")
    w("}")
    w(f"$reportId[{ps_str(rt)}] = Add-TzItem $dr $v")
w("Write-Information \"seeded Daily Reports\"")
w("")

# ----- Checks -----
w("# --- TZ01 Daily Report Checks (10) ---")
w("$checkId = @{}")
for rec in col["colChecks"]:
    dd=d(rec); rt=dd["ReportType"][1]; num=dd["CheckNumber"][1]
    fc=fcount.get((rt,num),0)
    notc = dd.get("NotCompared",("b",False))
    w("$v = @{")
    w(f"  Title = {ps_val(dd['CheckName'])}")
    w(f"  CheckKey = {ps_val(dd['CheckKey'])}")
    w(f"  ReportKey = {ps_str(dd['DayKey'][1]+'|'+rt)}")
    w(f"  DailyReportID = $reportId[{ps_str(rt)}]")
    w(f"  DayKey = {ps_val(dd['DayKey'])}")
    w(f"  ReportType = {ps_val(dd['ReportType'])}")
    w(f"  CheckNumber = {ps_val(dd['CheckNumber'])}")
    w(f"  CheckName = {ps_val(dd['CheckName'])}")
    w(f"  Scope = {ps_str(SCOPE.get((rt,num),''))}")
    w(f"  Result = {ps_val(dd['Result'])}")
    w(f"  FindingsCount = {fc}")
    w(f"  FOFlaggedCount = {ps_val(dd['FlaggedCount'])}")
    w(f"  NotCompared = {ps_val(notc)}")
    w(f"  IsLate = {ps_val(dd['IsLate'])}")
    w(f"  Completed = {ps_val(dd['Completed'])}")
    w("}")
    w(f"$checkId[{ps_str(rt+'|'+str(num))}] = Add-TzItem $ck $v")
w("Write-Information \"seeded Daily Report Checks\"")
w("")

# ----- Transactions -----
w("# --- TZ01 Daily Transactions (11: findings + full source record) ---")
w("$txnId = @{}")
for rec in col["colTransactions"]:
    dd=d(rec); rt=dd["ReportType"][1]; num=dd["CheckNumber"][1]; txn=dd["TransactionNo"][1]
    w("$v = @{")
    w("  DailyItemID = $itemId")
    w(f"  DailyReportID = $reportId[{ps_str(rt)}]")
    w(f"  DailyReportCheckID = $checkId[{ps_str(rt+'|'+str(num))}]")
    w(f"  TxnKey = {ps_str(dd['DayKey'][1]+'|'+rt+'|'+txn) if 'DayKey' in dd else ps_str(rt+'|'+txn)}")
    for k,v in rec:
        if k in TXN_SKIP: continue
        if k in WF_MAP:
            intn=WF_MAP[k]
            if v[0]=="null": continue
            w(f"  {intn} = {ps_val(v)}")
        elif k in [c for c in SRC_COLS]:
            if v[0]=="null": continue
            w(f"  {enc(k)} = {ps_val(v)}")
        # else: ID / drafts already skipped; TransactionNo handled via WF_MAP
    w("}")
    w(f"$txnId[{ps_str(txn)}] = Add-TzItem $tx $v")
w("Write-Information \"seeded Daily Transactions\"")
w("")

# ----- Reason Config -----
w("# --- TZ01 Reason Config (ch. 14.7 production reasons) ---")
for rec in col["colReasonConfig"]:
    dd=d(rec)
    w("$null = Add-TzItem $rc @{")
    w(f"  Title = {ps_val(dd['Reason'])}")
    w(f"  ReportType = {ps_val(dd['ReportType'])}")
    w(f"  CheckNumber = {ps_val(dd['CheckNumber'])}")
    w(f"  Role = {ps_val(dd['AppliesTo'])}")
    w(f"  Auto = {ps_val(dd['Auto'])}")
    w(f"  AutoFlagFO = {ps_val(dd['AutoFlagFO'])}")
    w(f"  RequiresComment = {ps_val(dd['RequiresComment'])}")
    w(f"  Order = {ps_val(dd['Sort'])}")
    w("  Active = $true")
    w("}")
w(f"Write-Information \"seeded Reason Config ({len(col['colReasonConfig'])} rows)\"")
w("")

# ----- Reviewers -----
w("# --- TZ01 Reviewers (role matrix: MO / FO / ADMIN) ---")
for rec in col["colReviewers"]:
    dd=d(rec); email=dd["Email"][1]
    w("$rvVals = @{")
    w(f"  Title = {ps_val(dd['Name'])}")
    w(f"  Email = {ps_str(email)}")
    w(f"  Name = {ps_val(dd['Name'])}")
    w(f"  Group = {ps_val(dd['Group'])}")
    w(f"  ReportType = {ps_val(dd['ReportType'])}")
    w(f"  CheckNumber = {ps_val(dd['CheckNumber'])}")
    w(f"  IsDefault = {ps_val(dd['IsDefault'])}")
    w("  Active = $true")
    w("}")
    w(f"if (-not $SkipPeople){{ try {{ $rvVals['Reviewer'] = {ps_str(email)} ; $null = Add-TzItem $rv $rvVals }}")
    w(f"  catch {{ $rvVals.Remove('Reviewer'); $null = Add-TzItem $rv $rvVals; Write-Warning \"reviewer {email} not resolved as a person — seeded email text only\" }} }}")
    w("else { $null = Add-TzItem $rv $rvVals }")
w("Write-Information \"seeded Reviewers\"")
w("")

# ----- Check Columns -----
w("# --- TZ01 Check Columns (ch. 8.3 quick-view sets) ---")
for rec in col["colCheckColumns"]:
    dd=d(rec)
    w("$null = Add-TzItem $cc @{")
    w(f"  Title = {ps_val(dd['ColName'])}")
    w(f"  Report = {ps_val(dd['Report'])}")
    w(f"  CheckNumber = {ps_val(dd['CheckNo'])}")
    w(f"  ColumnName = {ps_val(dd['ColName'])}")
    w(f"  Order = {ps_val(dd['Order'])}")
    w(f"  Align = {ps_val(dd['Align'])}")
    w("}")
w(f"Write-Information \"seeded Check Columns ({len(col['colCheckColumns'])} rows)\"")
w("")

# ----- Top Report -----
w("# --- TZ01 Top Report (monthly late-entry snapshot) ---")
for rec in col["colTopReport"]:
    dd=d(rec); txn=dd["TransactionNo"][1]
    w("$v = @{")
    w(f"  Title = {ps_str(txn)}")
    for f_ in ["MonthKey","DayKey","ReportType","TransactionNo","ProductType",
               "EnteredOn","ContractDate","DaysLate","Amount","Reason"]:
        if f_ in dd: w(f"  {f_} = {ps_val(dd[f_])}")
    w("}")
    w(f"if ($txnId.ContainsKey({ps_str(txn)})){{ $v['SourceTxnID'] = $txnId[{ps_str(txn)}] }}")
    w("$null = Add-TzItem $tr $v")
w("Write-Information \"seeded Top Report\"")
w("")

# ----- Input Files -----
w("# --- TZ01 Input Files (received/uploaded metadata) ---")
for rec in col["colInputFiles"]:
    dd=d(rec)
    w("$null = Add-TzItem $inf @{")
    w(f"  Title = {ps_val(dd['FileName'])}")
    for f_ in ["DayKey","FileKind","ReportType","FileName","ReceivedOn","Source","Validated"]:
        if f_ in dd and dd[f_][0]!="null": w(f"  {f_} = {ps_val(dd[f_])}")
    w("}")
w("Write-Information \"seeded Input Files\"")
w("")
w("Write-Information \"TZ01 provisioning + seed complete.\"")
w("Disconnect-PnPOnline")

open(OUT,"w",encoding="utf-8",newline="\n").write("\n".join(L)+"\n")
print("wrote",OUT,"lines:",len(L))
print("collections:",{k:len(v) for k,v in col.items()})
