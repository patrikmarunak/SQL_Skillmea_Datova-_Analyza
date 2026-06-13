#!/usr/bin/env python3
"""
Generátor canvas zdrojov (PASopa fx.yaml) pre HR Hub – RESPONZÍVNA verzia.

Rozloženie je postavené na auto-layout kontajneroch (groupContainer
.verticalAutoLayoutContainer / .horizontalAutoLayoutContainer) namiesto
absolútnych X/Y. Prvky majú FillPortions (rast po hlavnej osi) a kontajnery
LayoutGap / Padding / LayoutAlignItems / LayoutJustifyContent (flexbox model).
Galérie majú vždy Layout = Layout.Vertical/Horizontal (bez toho padali do
horizontálneho renderu).

Časti:
  build_onstart()  -> Src/App.fx.yaml (demo kolekcie + LIVE SharePoint markery)
  build_screens()  -> Src/<screen>.fx.yaml (8 obrazoviek)

Spustenie:  python3 build_canvas.py   (potom PASopa -pack)
"""
import csv
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / "data"
SRC = ROOT / "canvas" / "src" / "Src"
TODAY = date(2026, 6, 10)

# ---------------------------------------------------------------- dizajn tokeny
PURPLE = "RGBA(91, 95, 199, 1)"
PURPLE_D = "RGBA(79, 82, 178, 1)"
BG = "RGBA(243, 243, 243, 1)"
WHITE = "RGBA(255, 255, 255, 1)"
TEXT = "RGBA(36, 36, 36, 1)"
MUTED = "RGBA(97, 97, 97, 1)"
BORDER = "RGBA(225, 225, 225, 1)"
G_BG, G_FG = "RGBA(223, 246, 221, 1)", "RGBA(14, 107, 14, 1)"
A_BG, A_FG = "RGBA(255, 244, 206, 1)", "RGBA(122, 82, 0, 1)"
R_BG, R_FG = "RGBA(253, 231, 233, 1)", "RGBA(164, 38, 44, 1)"
N_BG, N_FG = "RGBA(237, 237, 237, 1)", "RGBA(77, 77, 77, 1)"

STATUS_FILL = f'Switch(ThisItem.LiveStatus, "Valid", {G_BG}, "Expiring", {A_BG}, "Expired", {R_BG}, {N_BG})'
STATUS_COLOR = f'Switch(ThisItem.LiveStatus, "Valid", {G_FG}, "Expiring", {A_FG}, "Expired", {R_FG}, {N_FG})'
STATUS_TEXT = "LookUp(colStatuses, S = ThisItem.LiveStatus, L)"

# Prepočet colRecords z colRecordsBase: join lookupov, ExpirationDate
# (= DateAdd(CompletionDate, ValidityMonths, Months)) a LiveStatus k dnešku.
# Inlinuje sa pri štarte aj po každej zmene záznamu (Patch -> tento prepočet).
REFRESH_RECORDS = """ClearCollect(colRecords,
    AddColumns(
        AddColumns(
            AddColumns(colRecordsBase,
                "EmployeeID", Emp,
                "EmployeeName", LookUp(colEmployees, EmployeeID = Emp, FullName),
                "DepartmentCode", LookUp(colEmployees, EmployeeID = Emp, DepartmentCode),
                "ManagerEmail", LookUp(colEmployees, EmployeeID = Emp, ManagerEmail),
                "TrainingName", LookUp(colTrainingsCatalog, ID = Tr, TrainingName),
                "TrainingType", LookUp(colTrainingsCatalog, ID = Tr, TrainingType),
                "ValidityMonths", LookUp(colTrainingsCatalog, ID = Tr, ValidityMonths),
                "CompletionDate", DateAdd(Today(), Off, TimeUnit.Days)
            ),
            "ExpirationDate", If(Pl || ValidityMonths = 0, Blank(), DateAdd(CompletionDate, ValidityMonths, TimeUnit.Months))
        ),
        "LiveStatus", If(
            Pl, "Planned",
            IsBlank(ExpirationDate), "Valid",
            ExpirationDate < Today(), "Expired",
            ExpirationDate <= DateAdd(Today(), 30, TimeUnit.Days), "Expiring",
            "Valid"
        )
    )
)"""


# ============================================================ emit jadro
def emit(node, indent=1, z=1):
    """node = (name, template, props_dict, children_list)."""
    name, template, props, children = node
    pad = "    " * indent
    # dotted template (groupContainer.x, gallery.x) je validný bez úvodzoviek
    out = [f"{pad}{name} As {template}:"]
    p = dict(props)
    p.setdefault("ZIndex", str(z))
    for k in sorted(p):
        v = str(p[k]).strip()
        if "\n" in v or ": " in v:
            out.append(f"{pad}    {k}: |-")
            lines = v.split("\n")
            out.append(f"{pad}        ={lines[0]}")
            out.extend(f"{pad}        {ln}" for ln in lines[1:])
        else:
            out.append(f"{pad}    {k}: ={v}")
    for i, ch in enumerate(children, start=1):
        out.append("")
        out.append(emit(ch, indent + 1, i))
    return "\n".join(out)


def C(name, template, props=None, children=None):
    return (name, template, props or {}, children or [])


def gc_v(name, props=None, children=None):
    return C(name, "groupContainer.verticalAutoLayoutContainer", props, children)


def gc_h(name, props=None, children=None):
    return C(name, "groupContainer.horizontalAutoLayoutContainer", props, children)


def label(name, text, props=None):
    base = {"Text": text, "FillPortions": "0"}
    base.update(props or {})
    return C(name, "label", base)


# ============================================================ spoločné bloky
NAV_SWITCH = (
    'Switch(ThisItem.Tag, '
    '"home", Navigate(scrHome, ScreenTransition.None), '
    '"emps", Navigate(scrEmployees, ScreenTransition.None), '
    '"cat", Navigate(scrCatalog, ScreenTransition.None), '
    '"recs", Navigate(scrRecords, ScreenTransition.None), '
    '"my", Navigate(scrMyTrainings, ScreenTransition.None), '
    'Navigate(scrReports, ScreenTransition.None))'
)
ROLE_LABEL = 'Switch(varRole, "admin", "HR Admin", "manager", "Manažér", "Zamestnanec")'


def nav_rail(s):
    return gc_v(f"navRail{s}", {
        "Width": "220", "FillPortions": "0", "Fill": WHITE,
        "LayoutGap": "4", "PaddingTop": "12", "PaddingBottom": "12",
        "PaddingLeft": "8", "PaddingRight": "8",
        "LayoutAlignItems": "LayoutAlignItems.Stretch",
        "BorderColor": BORDER, "BorderThickness": "0",
    }, [
        label(f"navBrand{s}", '"HR Hub"', {
            "Color": PURPLE, "FontWeight": "FontWeight.Bold", "Size": "16",
            "Height": "44", "PaddingLeft": "12",
            "VerticalAlign": "VerticalAlign.Middle"}),
        C(f"navGal{s}", "gallery.galleryVertical", {
            "FillPortions": "1", "Layout": "Layout.Vertical",
            "Items": 'Filter(colNav, varRole <> "employee" || EmpVisible)',
            "TemplatePadding": "0", "TemplateSize": "46", "ShowScrollbar": "false"},
          [label(f"navItem{s}", 'ThisItem.Icon & "   " & ThisItem.Title', {
              "Color": f'If(ThisItem.Tag = varNavTag, {PURPLE}, {TEXT})',
              "Fill": f'If(ThisItem.Tag = varNavTag, {N_BG}, RGBA(0,0,0,0))',
              "FontWeight": "If(ThisItem.Tag = varNavTag, FontWeight.Semibold, FontWeight.Normal)",
              "Height": "Parent.TemplateHeight", "Width": "Parent.TemplateWidth",
              "PaddingLeft": "12", "Size": "12", "VerticalAlign": "VerticalAlign.Middle",
              "OnSelect": NAV_SWITCH})]),
        label(f"navRole{s}", '"Rola: " & ' + ROLE_LABEL, {
            "Color": MUTED, "Size": "10", "Height": "26", "PaddingLeft": "12",
            "VerticalAlign": "VerticalAlign.Middle"}),
    ])


def header(s, title_text, subtitle, actions=None, height="64"):
    title_block = gc_v(f"hdrTitle{s}", {
        "FillPortions": "1", "LayoutGap": "2",
        "LayoutAlignItems": "LayoutAlignItems.Start",
        "LayoutJustifyContent": "LayoutJustifyContent.Center"}, [
        label(f"hdrTitleLbl{s}", title_text, {
            "FontWeight": "FontWeight.Bold", "Size": "21", "Height": "30"}),
        label(f"hdrSubLbl{s}", subtitle, {"Color": MUTED, "Size": "11", "Height": "20"}),
    ])
    kids = [title_block]
    if actions:
        kids.append(gc_h(f"hdrActions{s}", {
            "FillPortions": "0", "LayoutGap": "8", "Width": str(actions[0]),
            "LayoutAlignItems": "LayoutAlignItems.Center",
            "LayoutJustifyContent": "LayoutJustifyContent.End"}, actions[1]))
    return gc_h(f"hdr{s}", {
        "FillPortions": "0", "Height": height, "LayoutGap": "12",
        "LayoutAlignItems": "LayoutAlignItems.Center",
        "LayoutJustifyContent": "LayoutJustifyContent.SpaceBetween"}, kids)


def screen(name, tag, body_children, onvisible_extra="", actions=None,
           title_text='""', subtitle='""', header_height="64"):
    ov = f'Set(varNavTag, "{tag}")'
    if onvisible_extra:
        ov = ov + ";\n" + onvisible_extra
    s = name[3:]  # bez "scr"
    main_children = [header(s, title_text, subtitle, actions, header_height)] + body_children
    main = gc_v(f"main{s}", {
        "FillPortions": "1", "LayoutGap": "16",
        "PaddingTop": "20", "PaddingBottom": "20", "PaddingLeft": "24", "PaddingRight": "24",
        "LayoutAlignItems": "LayoutAlignItems.Stretch",
        "LayoutOverflowY": "LayoutOverflow.Scroll"}, main_children)
    frame = gc_h(f"frame{s}", {
        "Width": "Parent.Width", "Height": "Parent.Height", "LayoutGap": "0",
        "LayoutAlignItems": "LayoutAlignItems.Stretch"}, [nav_rail(s), main])
    body = [f"{name} As screen:"]
    if "\n" in ov or ": " in ov:
        body.append("    OnVisible: |-")
        lines = ov.split("\n")
        body.append(f"        ={lines[0]}")
        body.extend(f"        {ln}" for ln in lines[1:])
    else:
        body.append(f"    OnVisible: ={ov}")
    body.append(f"    Fill: ={BG}")
    return "\n".join(body) + "\n\n" + emit(frame, 1, 1) + "\n"


def card(name, children, props=None):
    base = {"FillPortions": "0", "Fill": WHITE, "BorderColor": BORDER,
            "BorderThickness": "1", "PaddingTop": "16", "PaddingBottom": "16",
            "PaddingLeft": "16", "PaddingRight": "16", "LayoutGap": "8",
            "LayoutAlignItems": "LayoutAlignItems.Stretch",
            "RadiusTopLeft": "8", "RadiusTopRight": "8",
            "RadiusBottomLeft": "8", "RadiusBottomRight": "8"}
    base.update(props or {})
    return gc_v(name, base, children)


# ============================================================ record row (responzívne)
CAN_EDIT = ('varRole = "admin" || (varRole = "manager" && '
            'LookUp(colEmployees, EmployeeID = ThisItem.EmployeeID, ManagerEmail) = varCurrentUser.Email)')
EDIT_SEL = ('Set(varEditRecord, ThisItem); '
            'Set(varPickedEmp, LookUp(colEmployees, EmployeeID = ThisItem.EmployeeID)); '
            'Set(varPickedTraining, LookUp(colTrainingsCatalog, ID = ThisItem.Tr)); '
            'Navigate(scrAddRecord, ScreenTransition.None)')


def record_row(prefix, show_emp):
    """Riadky galérie záznamov – pravý stĺpec ukotvený k Parent.TemplateWidth (responzívne)."""
    kids = [C(f"recBg{prefix}", "rectangle", {
        "Fill": WHITE, "BorderColor": BORDER, "BorderThickness": "1",
        "Height": "Parent.TemplateHeight - 6", "Width": "Parent.TemplateWidth",
        "X": "0", "Y": "3", "OnSelect": "Select(Parent)"})]
    if show_emp:
        kids += [
            label(f"recEmp{prefix}", "ThisItem.EmployeeName", {
                "FontWeight": "FontWeight.Semibold", "Size": "11", "Height": "24",
                "Width": "210", "X": "16", "Y": "9", "OnSelect": "Select(Parent)"}),
            label(f"recEmpId{prefix}", "ThisItem.EmployeeID", {
                "Color": MUTED, "Size": "9", "Height": "18",
                "Width": "210", "X": "16", "Y": "33", "OnSelect": "Select(Parent)"}),
        ]
        tr_x = "236"
    else:
        tr_x = "16"
    kids += [
        label(f"recTr{prefix}", "ThisItem.TrainingName", {
            "FontWeight": "FontWeight.Semibold", "Size": "11", "Height": "24",
            "Width": "320", "X": tr_x, "Y": "9", "OnSelect": "Select(Parent)"}),
        label(f"recDates{prefix}",
              'If(ThisItem.Pl, "Plán: ", "Absolvované: ") & Text(ThisItem.CompletionDate, "d.m.yyyy") '
              '& "   Platí do: " & If(IsBlank(ThisItem.ExpirationDate), "—", Text(ThisItem.ExpirationDate, "d.m.yyyy"))',
              {"Color": MUTED, "Size": "9", "Height": "18",
               "Width": "360", "X": tr_x, "Y": "33", "OnSelect": "Select(Parent)"}),
        # pravý blok – ukotvený k šírke šablóny
        label(f"recPill{prefix}", STATUS_TEXT, {
            "Align": "Align.Center", "Color": STATUS_COLOR, "Fill": STATUS_FILL,
            "FontWeight": "FontWeight.Semibold", "Size": "10", "Height": "26",
            "Width": "150", "X": "Parent.TemplateWidth - 330", "Y": "Parent.TemplateHeight/2 - 13",
            "OnSelect": "Select(Parent)"}),
        label(f"recCert{prefix}", 'If(ThisItem.Cert = "", "", "PDF")', {
            "Color": PURPLE, "Size": "10", "Height": "26", "Align": "Align.Center",
            "Width": "60", "X": "Parent.TemplateWidth - 168", "Y": "Parent.TemplateHeight/2 - 13"}),
        label(f"recEdit{prefix}", '"Upraviť"', {
            "Color": PURPLE, "FontWeight": "FontWeight.Semibold", "Size": "10", "Height": "26",
            "Align": "Align.Center", "Width": "90", "X": "Parent.TemplateWidth - 100",
            "Y": "Parent.TemplateHeight/2 - 13", "Visible": CAN_EDIT, "OnSelect": EDIT_SEL}),
    ]
    return kids


print("helpers ready")


# ============================================================ OnStart / dáta
def _read(name):
    return list(csv.DictReader(open(DATA / name, encoding="utf-8-sig")))


def _fx(s):
    return '"' + s.replace('"', '""') + '"'


def _offset(iso):
    return (date.fromisoformat(iso) - TODAY).days


def build_onstart():
    emps = _read("Employees.csv")
    recs = _read("TrainingRecords.csv")
    trains = _read("TrainingsCatalog.csv")
    deps = _read("Departments.csv")
    by_id = {e["EmployeeID"]: e for e in emps}

    # výber demo zamestnancov: HR admin + OPS mgr&podriadení + IT mgr&pár + HR podriadení + 1 neaktívny
    ops = by_id["EMP0006"]["Email"]; it = by_id["EMP0002"]["Email"]; hr = by_id["EMP0001"]["Email"]
    sel = ["EMP0001", "EMP0006", "EMP0002"]
    sel += [e["EmployeeID"] for e in emps if e["ManagerEmail"] == ops and e["Status"] == "Active"][:5]
    sel += [e["EmployeeID"] for e in emps if e["ManagerEmail"] == it and e["Status"] == "Active"][:3]
    sel += [e["EmployeeID"] for e in emps if e["ManagerEmail"] == hr and e["Status"] == "Active" and e["Department"] == "HR"][:2]
    sel += [e["EmployeeID"] for e in emps if e["Status"] == "Inactive"][:1]
    sel_set = set(sel)
    dep_name = {d["DepartmentCode"]: d["DepartmentName"] for d in deps}
    train_id = {t["TrainingName"]: i + 1 for i, t in enumerate(trains)}

    er = []
    for i, code in enumerate(sel):
        e = by_id[code]
        er.append(
            f'{{ID:{i+1}, EmployeeID:{_fx(e["EmployeeID"])}, FullName:{_fx(e["FullName"])}, '
            f'Email:{_fx(e["Email"])}, Department:{_fx(dep_name[e["Department"]])}, '
            f'DepartmentCode:{_fx(e["Department"])}, Position:{_fx(e["Position"])}, '
            f'ManagerEmail:{_fx(e["ManagerEmail"])}, HireDate:DateAdd(Today(), {_offset(e["HireDate"])}, TimeUnit.Days), '
            f'Status:{_fx(e["Status"])}}}')

    dr = [f'{{ID:{i+1}, DepartmentName:{_fx(d["DepartmentName"])}, '
          f'DepartmentCode:{_fx(d["DepartmentCode"])}, Manager:{_fx(d["Manager"])}}}'
          for i, d in enumerate(deps)]

    tr = [f'{{ID:{i+1}, TrainingName:{_fx(t["TrainingName"])}, TrainingType:{_fx(t["TrainingType"])}, '
          f'ValidityMonths:{t["ValidityMonths"]}, Provider:{_fx(t["Provider"])}}}'
          for i, t in enumerate(trains)]

    rr = []
    n = 0
    for r in recs:
        if r["Employee"] not in sel_set:
            continue
        n += 1
        pl = "true" if r["Status"] == "Planned" else "false"
        rr.append(f'{{ID:{n}, Emp:{_fx(r["Employee"])}, Tr:{train_id[r["Training"]]}, '
                  f'Off:{_offset(r["CompletionDate"])}, Pl:{pl}, Cert:{_fx(r["CertificateLink"])}, '
                  f'Notes:{_fx(r["Notes"])}}}')

    def block(name, rows):
        return f"ClearCollect({name},\n    " + ",\n    ".join(rows) + "\n);"

    onstart = f"""// ============================================================
// HR Hub – inicializácia. Aplikácia pracuje s LOKÁLNYMI KOLEKCIAMI:
// pri štarte sa dáta načítajú do colXxx, obrazovky čítajú/píšu kolekcie a
// pri zmene sa Patchne SharePoint + obnoví dotknutá kolekcia (RefreshRecords()).
//
// === LIVE REŽIM (po pridaní SharePoint listov ako dátových zdrojov v Studiu) ===
// Nahraď DEMO blok nižšie týmto (mapuje interné stĺpce listov na kolekcie):
//   ClearCollect(colDepartments, ShowColumns(Departments, "ID","DepartmentName","DepartmentCode","Manager"));
//   ClearCollect(colTrainingsCatalog, ShowColumns(TrainingsCatalog, "ID","TrainingName","TrainingType","ValidityMonths","Provider"));
//   ClearCollect(colEmployees, AddColumns(Employees, "DepartmentCode", Department.Value /* lookup */, ...));
//   ClearCollect(colRecordsBase, AddColumns(TrainingRecords, "Emp", Employee.EmployeeID, "Tr", Training.ID, ...));
// Detailné LIVE formuly sú v canvas/README.md (sekcia „Napojenie na SharePoint").
// ============================================================

// --- navigácia + číselník stavov (rovnaké pre demo aj live) ---
ClearCollect(colNav,
    {{Ord:1, Title:"Domov", Icon:"⌂", Tag:"home", EmpVisible:true}},
    {{Ord:2, Title:"Zamestnanci", Icon:"👥", Tag:"emps", EmpVisible:false}},
    {{Ord:3, Title:"Katalóg školení", Icon:"📚", Tag:"cat", EmpVisible:false}},
    {{Ord:4, Title:"Záznamy školení", Icon:"📋", Tag:"recs", EmpVisible:false}},
    {{Ord:5, Title:"Moje školenia", Icon:"🎓", Tag:"my", EmpVisible:true}},
    {{Ord:6, Title:"Reporty", Icon:"📊", Tag:"rep", EmpVisible:false}}
);
ClearCollect(colStatuses,
    {{S:"Valid", L:"Platné"}}, {{S:"Expiring", L:"Čoskoro exspiruje"}},
    {{S:"Expired", L:"Exspirované"}}, {{S:"Planned", L:"Naplánované"}}
);

// === DEMO ZDROJ (v LIVE režime zmaž celý tento blok) ===
{block("colDepartments", dr)}
{block("colTrainingsCatalog", tr)}
{block("colEmployees", er)}
{block("colRecordsBase", rr)}
// === koniec DEMO ZDROJA ===

// --- odvodené stĺpce: join + ExpirationDate + LiveStatus (rovnaké pre demo aj live) ---
// (rovnaký prepočet sa volá aj po každej zmene záznamu – pozri komentáre pri Patchoch)
{REFRESH_RECORDS};
ClearCollect(colAudit,
    {{ID:1, Action:"Create", EntityType:"TrainingRecord", EntityID:"EMP0034", ChangedBy:"katarina.bielikova@contoso.sk", ChangedOn:DateAdd(Now(), -26, TimeUnit.Hours), Details:"Pridaný záznam školenia 'Ochrana pred požiarmi' pre Štefan Lukáč (EMP0034)."}},
    {{ID:2, Action:"Update", EntityType:"Employee", EntityID:"EMP0035", ChangedBy:"katarina.bielikova@contoso.sk", ChangedOn:DateAdd(Now(), -49, TimeUnit.Hours), Details:"Aktualizovaný profil Silvia Sedláková (EMP0035)."}}
);

// --- stav UI + demo používateľ (v LIVE rolu urči cez Entra ID skupiny voči User().Email) ---
Set(varCurrentUser, LookUp(colEmployees, EmployeeID = "EMP0001"));
Set(varRole, "admin");
Set(varNavTag, "home");
Set(varDeptFilter, Blank());
Set(varStatusFilter, Blank());
Set(varSelEmployee, Blank());
Set(varEditRecord, Blank());
Set(varPickedEmp, Blank());
Set(varPickedTraining, Blank());
Set(varTab, "trainings");
Set(varCatType, "Mandatory")"""

    onstart_body = "\n".join((" " * 8 + ("=" + ln if i == 0 else ln))
                             for i, ln in enumerate(onstart.split("\n")))
    (SRC / "App.fx.yaml").write_text("App As appinfo:\n    OnStart: |-\n" + onstart_body + "\n")
    print(f"  App.fx.yaml ({len(sel)} zam., {n} zázn.)")


# ============================================================ stavebné prvky obrazoviek
def btn(name, text, props=None, primary=False):
    base = {"Text": text, "FillPortions": "0", "Size": "11", "Height": "40",
            "RadiusTopLeft": "6", "RadiusTopRight": "6", "RadiusBottomLeft": "6", "RadiusBottomRight": "6"}
    if primary:
        base.update({"Color": WHITE, "Fill": PURPLE, "HoverFill": PURPLE_D,
                     "PressedFill": PURPLE_D, "BorderColor": PURPLE, "FontWeight": "FontWeight.Semibold"})
    else:
        base.update({"Color": TEXT, "Fill": WHITE, "HoverFill": N_BG,
                     "BorderColor": BORDER, "BorderThickness": "1"})
    base.update(props or {})
    return C(name, "button", base)


def textinput(name, props=None):
    base = {"FillPortions": "0", "Height": "40", "Size": "11", "Fill": WHITE,
            "BorderColor": BORDER, "Color": TEXT}
    base.update(props or {})
    return C(name, "text", base)


def chip_gallery(name, items, sel_expr, set_expr, all_label=None):
    """Horizontálna galéria filter-chipov (Layout.Horizontal nech sa renderuje vodorovne)."""
    row = btn(f"{name}Btn", "ThisItem.L", {
        "Color": "If(" + sel_expr + ", " + WHITE + ", " + TEXT + ")",
        "Fill": "If(" + sel_expr + ", " + PURPLE + ", " + WHITE + ")",
        "BorderColor": BORDER, "BorderThickness": "1", "Height": "34",
        "RadiusTopLeft": "17", "RadiusTopRight": "17", "RadiusBottomLeft": "17", "RadiusBottomRight": "17",
        "Size": "10", "Width": "Parent.TemplateWidth - 6", "X": "0", "Y": "6",
        "OnSelect": set_expr})
    return C(name, "gallery.galleryHorizontal", {
        "FillPortions": "0", "Height": "46", "Layout": "Layout.Horizontal",
        "Items": items, "TemplatePadding": "0", "TemplateSize": "172", "ShowScrollbar": "false"},
        [row])


def kpi_tile(s, idx, value, caption, tone="default", onselect=None):
    color = {"warn": A_FG, "danger": R_FG}.get(tone, TEXT)
    vp = {"FontWeight": "FontWeight.Bold", "Size": "28", "Height": "42", "Color": color}
    cp = {"Color": MUTED, "Size": "11", "Height": "30"}
    if onselect:
        vp["OnSelect"] = onselect
        cp["OnSelect"] = onselect
    return card(f"kpi{idx}{s}", [
        label(f"kpiVal{idx}{s}", value, vp),
        label(f"kpiCap{idx}{s}", caption, cp),
    ], {"FillPortions": "1", "LayoutMinWidth": "170", "LayoutGap": "2",
        "PaddingTop": "18", "PaddingBottom": "18"})


def avatar(name, expr_name, size="44", x="14", y="14"):
    return label(name, "Upper(Left(" + expr_name + ", 1)) & Upper(Left(Last(Split(" + expr_name + ', " ")).Value, 1))', {
        "Align": "Align.Center", "Color": WHITE, "Fill": PURPLE, "FontWeight": "FontWeight.Bold",
        "Height": size, "Width": size, "Size": "13", "VerticalAlign": "VerticalAlign.Middle",
        "X": x, "Y": y, "RadiusTopLeft": "22", "RadiusTopRight": "22",
        "RadiusBottomLeft": "22", "RadiusBottomRight": "22", "OnSelect": "Select(Parent)"})


# ============================================================ obrazovky
def build_screens():
    out = {}

    # ---------------------------------------------------------- 1. Domov
    go = 'If(varRole <> "employee", {nav})'
    rate = ('With({t: CountRows(Filter(colRecords, LiveStatus <> "Planned"))}, '
            'If(t = 0, "100 %", Round(CountRows(Filter(colRecords, LiveStatus = "Valid")) / t * 100, 0) & " %"))')
    role_btns = (360, [
        btn("homeRoleAdmin", '"HR Admin"', {
            "Color": 'If(varRole = "admin", ' + WHITE + ", " + TEXT + ")",
            "Fill": 'If(varRole = "admin", ' + PURPLE + ", " + WHITE + ")",
            "BorderColor": BORDER, "BorderThickness": "1", "Width": "104", "Height": "34", "Size": "10",
            "RadiusTopLeft": "17", "RadiusTopRight": "17", "RadiusBottomLeft": "17", "RadiusBottomRight": "17",
            "OnSelect": 'Set(varCurrentUser, LookUp(colEmployees, EmployeeID = "EMP0001")); Set(varRole, "admin")'}),
        btn("homeRoleMgr", '"Manažér"', {
            "Color": 'If(varRole = "manager", ' + WHITE + ", " + TEXT + ")",
            "Fill": 'If(varRole = "manager", ' + PURPLE + ", " + WHITE + ")",
            "BorderColor": BORDER, "BorderThickness": "1", "Width": "100", "Height": "34", "Size": "10",
            "RadiusTopLeft": "17", "RadiusTopRight": "17", "RadiusBottomLeft": "17", "RadiusBottomRight": "17",
            "OnSelect": 'Set(varCurrentUser, LookUp(colEmployees, EmployeeID = "EMP0006")); Set(varRole, "manager")'}),
        btn("homeRoleEmp", '"Zamestnanec"', {
            "Color": 'If(varRole = "employee", ' + WHITE + ", " + TEXT + ")",
            "Fill": 'If(varRole = "employee", ' + PURPLE + ", " + WHITE + ")",
            "BorderColor": BORDER, "BorderThickness": "1", "Width": "118", "Height": "34", "Size": "10",
            "RadiusTopLeft": "17", "RadiusTopRight": "17", "RadiusBottomLeft": "17", "RadiusBottomRight": "17",
            "OnSelect": 'Set(varCurrentUser, LookUp(colEmployees, EmployeeID = "EMP0035")); Set(varRole, "employee"); Navigate(scrMyTrainings, ScreenTransition.None)'}),
    ])
    home_body = [
        gc_h("kpiRowHome", {
            "FillPortions": "0", "Height": "112", "LayoutGap": "14",
            "LayoutOverflowX": "LayoutOverflow.Scroll",
            "LayoutAlignItems": "LayoutAlignItems.Stretch"}, [
            kpi_tile("Home", 1, 'CountRows(Filter(colEmployees, Status = "Active"))', '"Aktívni zamestnanci"',
                     onselect=go.format(nav="Navigate(scrEmployees, ScreenTransition.None)")),
            kpi_tile("Home", 2, 'CountRows(Filter(colRecords, LiveStatus = "Expiring"))', '"Exspiruje do 30 dní"', "warn",
                     onselect=go.format(nav='Set(varStatusFilter, "Expiring"); Navigate(scrRecords, ScreenTransition.None)')),
            kpi_tile("Home", 3, 'CountRows(Filter(colRecords, LiveStatus = "Expired"))', '"Exspirované školenia"', "danger",
                     onselect=go.format(nav='Set(varStatusFilter, "Expired"); Navigate(scrRecords, ScreenTransition.None)')),
            kpi_tile("Home", 4, rate, '"Miera splnenia"'),
        ]),
        gc_h("searchRowHome", {
            "FillPortions": "0", "Height": "44", "LayoutGap": "8",
            "LayoutAlignItems": "LayoutAlignItems.Center"}, [
            textinput("txtSearchHome", {
                "FillPortions": "1", "HintText": '"Hľadať zamestnanca (meno alebo osobné číslo)…"'}),
            btn("btnSearchHome", '"Hľadať"', {
                "Width": "120",
                "OnSelect": 'Set(varSearch, txtSearchHome.Text); ' + go.format(nav="Navigate(scrEmployees, ScreenTransition.None)")},
                primary=True),
        ]),
        label("lblDeptsHome", '"Rýchle filtre podľa oddelenia"', {
            "FillPortions": "0", "FontWeight": "FontWeight.Semibold", "Size": "12", "Height": "26"}),
        C("galDeptHome", "gallery.galleryHorizontal", {
            "FillPortions": "0", "Height": "48", "Layout": "Layout.Horizontal",
            "Items": "colDepartments", "TemplatePadding": "0", "TemplateSize": "186", "ShowScrollbar": "false"},
          [btn("galDeptHomeBtn", "ThisItem.DepartmentName", {
              "BorderColor": BORDER, "BorderThickness": "1", "Color": TEXT, "Fill": WHITE, "HoverFill": N_BG,
              "Height": "36", "Size": "10", "Width": "Parent.TemplateWidth - 8", "X": "0", "Y": "6",
              "RadiusTopLeft": "18", "RadiusTopRight": "18", "RadiusBottomLeft": "18", "RadiusBottomRight": "18",
              "OnSelect": 'Set(varDeptFilter, ThisItem.DepartmentCode); ' + go.format(nav="Navigate(scrEmployees, ScreenTransition.None)")})]),
        gc_v("spacerHome", {"FillPortions": "1"}),  # vyplní zvyšok
    ]
    out["scrHome"] = screen(
        "scrHome", "home", home_body, actions=role_btns,
        title_text='"Vitajte, " & First(Split(varCurrentUser.FullName, " ")).Value & " 👋"',
        subtitle='"Prehľad zamestnancov a stavu školení k dnešnému dňu."', header_height="56")

    # ---------------------------------------------------------- 2. Zamestnanci
    emp_filter = ('SortByColumns(Filter(colEmployees, '
                  '(txtSearchEmp.Text = "" || StartsWith(FullName, txtSearchEmp.Text) || StartsWith(EmployeeID, txtSearchEmp.Text)) '
                  '&& (IsBlank(varDeptFilter) || DepartmentCode = varDeptFilter) '
                  '&& (!chkActiveEmp.Value || Status = "Active")), "FullName")')
    emp_row = [
        C("empBg", "rectangle", {"Fill": WHITE, "BorderColor": BORDER, "BorderThickness": "1",
                                 "Height": "Parent.TemplateHeight - 8", "Width": "Parent.TemplateWidth",
                                 "X": "0", "Y": "4", "OnSelect": "Select(Parent)"}),
        avatar("empAvatar", "ThisItem.FullName", "44", "16", "16"),
        label("empName", "ThisItem.FullName", {
            "FontWeight": "FontWeight.Semibold", "Size": "12", "Height": "24",
            "Width": "Parent.TemplateWidth - 320", "X": "74", "Y": "14", "OnSelect": "Select(Parent)"}),
        label("empMeta", 'ThisItem.Position & " · " & ThisItem.Department & " · " & ThisItem.EmployeeID', {
            "Color": MUTED, "Size": "10", "Height": "22",
            "Width": "Parent.TemplateWidth - 320", "X": "74", "Y": "38", "OnSelect": "Select(Parent)"}),
        label("empStatus", 'If(ThisItem.Status = "Active", "Aktívny", "Neaktívny")', {
            "Align": "Align.Center", "Color": 'If(ThisItem.Status = "Active", ' + G_FG + ", " + N_FG + ")",
            "Fill": 'If(ThisItem.Status = "Active", ' + G_BG + ", " + N_BG + ")",
            "FontWeight": "FontWeight.Semibold", "Size": "10", "Height": "26",
            "Width": "120", "X": "Parent.TemplateWidth - 140", "Y": "Parent.TemplateHeight/2 - 13",
            "OnSelect": "Select(Parent)"}),
    ]
    emp_body = [
        gc_h("toolbarEmp", {"FillPortions": "0", "Height": "44", "LayoutGap": "12",
                            "LayoutAlignItems": "LayoutAlignItems.Center"}, [
            textinput("txtSearchEmp", {"FillPortions": "1", "Default": "varSearch",
                                       "HintText": '"Hľadať (meno alebo EMP…)"'}),
            C("chkActiveEmp", "checkbox", {"FillPortions": "0", "Width": "150", "Height": "40",
                                           "Text": '"Len aktívni"', "Size": "11", "Default": "true"}),
        ]),
        gc_h("deptChipsEmp", {"FillPortions": "0", "Height": "46", "LayoutGap": "8",
                              "LayoutOverflowX": "LayoutOverflow.Scroll",
                              "LayoutAlignItems": "LayoutAlignItems.Center"}, [
            btn("btnAllDeptEmp", '"Všetky oddelenia"', {
                "Color": "If(IsBlank(varDeptFilter), " + WHITE + ", " + TEXT + ")",
                "Fill": "If(IsBlank(varDeptFilter), " + PURPLE + ", " + WHITE + ")",
                "BorderColor": BORDER, "BorderThickness": "1", "Width": "150", "Height": "34", "Size": "10",
                "RadiusTopLeft": "17", "RadiusTopRight": "17", "RadiusBottomLeft": "17", "RadiusBottomRight": "17",
                "OnSelect": "Set(varDeptFilter, Blank())"}),
            C("galDeptEmp", "gallery.galleryHorizontal", {
                "FillPortions": "1", "Height": "46", "Layout": "Layout.Horizontal",
                "Items": "colDepartments", "TemplatePadding": "0", "TemplateSize": "168", "ShowScrollbar": "false"},
              [btn("galDeptEmpBtn", "ThisItem.DepartmentName", {
                  "Color": "If(varDeptFilter = ThisItem.DepartmentCode, " + WHITE + ", " + TEXT + ")",
                  "Fill": "If(varDeptFilter = ThisItem.DepartmentCode, " + PURPLE + ", " + WHITE + ")",
                  "BorderColor": BORDER, "BorderThickness": "1", "Height": "34", "Size": "10",
                  "RadiusTopLeft": "17", "RadiusTopRight": "17", "RadiusBottomLeft": "17", "RadiusBottomRight": "17",
                  "Width": "Parent.TemplateWidth - 6", "X": "0", "Y": "6",
                  "OnSelect": "Set(varDeptFilter, If(varDeptFilter = ThisItem.DepartmentCode, Blank(), ThisItem.DepartmentCode))"})]),
        ]),
        C("galEmps", "gallery.galleryVertical", {
            "FillPortions": "1", "Layout": "Layout.Vertical", "Items": emp_filter,
            "TemplatePadding": "0", "TemplateSize": "72", "ShowScrollbar": "true",
            "OnSelect": "Set(varSelEmployee, galEmps.Selected); Set(varTab, \"trainings\"); Navigate(scrEmployeeDetail, ScreenTransition.None)"},
          emp_row),
    ]
    out["scrEmployees"] = screen(
        "scrEmployees", "emps", emp_body,
        title_text='"Zamestnanci"',
        subtitle='"Vyhľadávanie podľa začiatku mena alebo osobného čísla (delegovateľné StartsWith)."')

    return out


def tab_btn(name, text, tag):
    return btn(name, text, {
        "Color": 'If(varTab = "' + tag + '", ' + PURPLE + ", " + MUTED + ")",
        "Fill": "RGBA(0,0,0,0)", "BorderThickness": "0", "Height": "40", "Size": "12",
        "FontWeight": 'If(varTab = "' + tag + '", FontWeight.Semibold, FontWeight.Normal)',
        "Width": "130", "OnSelect": 'Set(varTab, "' + tag + '")'})


def build_screens_rest(out):
    # ---------------------------------------------------------- 3. Detail zamestnanca
    deact = ('Patch(colEmployees, LookUp(colEmployees, EmployeeID = varSelEmployee.EmployeeID), {Status: "Inactive"}); '
             'Set(varSelEmployee, LookUp(colEmployees, EmployeeID = varSelEmployee.EmployeeID)); '
             'Collect(colAudit, {ID: Max(colAudit, ID) + 1, Action: "Update", EntityType: "Employee", '
             'EntityID: varSelEmployee.EmployeeID, ChangedBy: varCurrentUser.Email, ChangedOn: Now(), '
             'Details: "Zmena stavu zamestnanca " & varSelEmployee.FullName & " na Inactive (soft-delete)."}); '
             '/* LIVE: Patch(Employees, LookUp(Employees, EmployeeID = varSelEmployee.EmployeeID), {Status: {Value:"Inactive"}}); '
             'Patch(AuditLog, Defaults(AuditLog), {Title:"Update", EntityType:{Value:"Employee"}, EntityID: varSelEmployee.EmployeeID, ChangedBy: User().Email, ChangedOn: Now(), Details:"soft-delete"}); */ '
             'Notify("Zamestnanec bol deaktivovaný (soft-delete, záznamy ostávajú).", NotificationType.Success, 2500)')

    detail_actions = (160, [
        btn("btnDeactDetail", '"Deaktivovať"', {
            "Color": R_FG, "Fill": WHITE, "BorderColor": R_FG, "BorderThickness": "1", "HoverFill": R_BG,
            "FontWeight": "FontWeight.Semibold", "Width": "150",
            "Visible": 'varRole = "admin" && varSelEmployee.Status = "Active"',
            "OnSelect": deact})])

    info_rows = [
        ("E-mail", "varSelEmployee.Email"),
        ("Oddelenie", "varSelEmployee.Department"),
        ("Pozícia", "varSelEmployee.Position"),
        ("Manažér", 'If(varSelEmployee.ManagerEmail = "", "—", varSelEmployee.ManagerEmail)'),
        ("Dátum nástupu", 'Text(varSelEmployee.HireDate, "d.m.yyyy")'),
        ("Osobné číslo", "varSelEmployee.EmployeeID"),
    ]
    info_children = []
    for i, (lab, expr) in enumerate(info_rows):
        info_children.append(gc_h("infoRow" + str(i), {
            "FillPortions": "0", "Height": "30", "LayoutGap": "8",
            "LayoutAlignItems": "LayoutAlignItems.Center"}, [
            label("infoLab" + str(i), '"' + lab + '"', {
                "Color": MUTED, "Size": "11", "Width": "150", "FillPortions": "0"}),
            label("infoVal" + str(i), expr, {"Size": "11", "FillPortions": "1"}),
        ]))

    cert_row = [
        C("certBg", "rectangle", {"Fill": WHITE, "BorderColor": BORDER, "BorderThickness": "1",
                                  "Height": "Parent.TemplateHeight - 8", "Width": "Parent.TemplateWidth",
                                  "X": "0", "Y": "4"}),
        label("certName", "ThisItem.TrainingName", {
            "FontWeight": "FontWeight.Semibold", "Size": "11", "Height": "24", "Width": "Parent.TemplateWidth - 180",
            "X": "16", "Y": "12"}),
        label("certExp", '"platné do " & If(IsBlank(ThisItem.ExpirationDate), "—", Text(ThisItem.ExpirationDate, "d.m.yyyy"))', {
            "Color": MUTED, "Size": "9", "Height": "20", "Width": "Parent.TemplateWidth - 180", "X": "16", "Y": "36"}),
        label("certOpen", '"Otvoriť PDF"', {
            "Color": PURPLE, "FontWeight": "FontWeight.Semibold", "Size": "10", "Height": "26", "Align": "Align.Center",
            "Width": "120", "X": "Parent.TemplateWidth - 140", "Y": "Parent.TemplateHeight/2 - 13"}),
    ]

    detail_body = [
        gc_h("tabsDetail", {"FillPortions": "0", "Height": "44", "LayoutGap": "4",
                            "BorderColor": BORDER, "BorderThickness": "0",
                            "LayoutAlignItems": "LayoutAlignItems.Center"}, [
            tab_btn("tabOverview", '"Prehľad"', "overview"),
            tab_btn("tabTrainings", '"Školenia"', "trainings"),
            tab_btn("tabCerts", '"Certifikáty"', "certificates"),
            tab_btn("tabAudit", '"História zmien"', "audit"),
        ]),
        card("ovCard", info_children, {"Visible": 'varTab = "overview"', "FillPortions": "1",
                                       "LayoutJustifyContent": "LayoutJustifyContent.Start"}),
        C("galRecsDetail", "gallery.galleryVertical", {
            "FillPortions": "1", "Layout": "Layout.Vertical", "Visible": 'varTab = "trainings"',
            "Items": "Sort(Filter(colRecords, EmployeeID = varSelEmployee.EmployeeID), CompletionDate, SortOrder.Descending)",
            "TemplatePadding": "0", "TemplateSize": "60", "ShowScrollbar": "true"},
          record_row("Det", False)),
        C("galCertsDetail", "gallery.galleryVertical", {
            "FillPortions": "1", "Layout": "Layout.Vertical", "Visible": 'varTab = "certificates"',
            "Items": 'Filter(colRecords, EmployeeID = varSelEmployee.EmployeeID && Cert <> "")',
            "TemplatePadding": "0", "TemplateSize": "64", "ShowScrollbar": "true"},
          cert_row),
        C("galAuditDetail", "gallery.galleryVertical", {
            "FillPortions": "1", "Layout": "Layout.Vertical", "Visible": 'varTab = "audit"',
            "Items": "Sort(Filter(colAudit, EntityID = varSelEmployee.EmployeeID), ChangedOn, SortOrder.Descending)",
            "TemplatePadding": "0", "TemplateSize": "44", "ShowScrollbar": "true"},
          [label("auditRow",
                 'Text(ThisItem.ChangedOn, "d.m.yyyy hh:mm") & "  •  " & ThisItem.Action & "  •  " & ThisItem.Details', {
                     "Color": MUTED, "Size": "9", "Height": "Parent.TemplateHeight", "Width": "Parent.TemplateWidth",
                     "VerticalAlign": "VerticalAlign.Middle"})]),
        label("emptyTrainings", '"Žiadne záznamy školení."', {
            "FillPortions": "0", "Color": MUTED, "Height": "30",
            "Visible": 'varTab = "trainings" && CountRows(Filter(colRecords, EmployeeID = varSelEmployee.EmployeeID)) = 0'}),
    ]
    out["scrEmployeeDetail"] = screen(
        "scrEmployeeDetail", "emps", detail_body, onvisible_extra='Set(varTab, "overview")',
        actions=detail_actions,
        title_text="varSelEmployee.FullName",
        subtitle='varSelEmployee.Position & " · " & varSelEmployee.Department & " · " & varSelEmployee.EmployeeID')

    # ---------------------------------------------------------- 4. Katalóg školení
    TYPE_FILL = ('Switch(ThisItem.TrainingType, "Mandatory", ' + R_BG + ', "Safety", ' + A_BG +
                 ', "Certification", ' + G_BG + ", " + N_BG + ")")
    TYPE_COLOR = ('Switch(ThisItem.TrainingType, "Mandatory", ' + R_FG + ', "Safety", ' + A_FG +
                  ', "Certification", ' + G_FG + ", " + N_FG + ")")
    TYPE_LABEL = ('Switch(ThisItem.TrainingType, "Mandatory", "Povinné", "Safety", "Bezpečnosť", '
                  '"Certification", "Certifikácia", "Voliteľné")')
    cat_row = [
        C("catBg", "rectangle", {"Fill": WHITE, "BorderColor": BORDER, "BorderThickness": "1",
                                 "Height": "Parent.TemplateHeight - 8", "Width": "Parent.TemplateWidth", "X": "0", "Y": "4"}),
        label("catName", "ThisItem.TrainingName", {
            "FontWeight": "FontWeight.Semibold", "Size": "12", "Height": "24",
            "Width": "Parent.TemplateWidth - 200", "X": "16", "Y": "10"}),
        label("catMeta",
              '"Platnosť: " & If(ThisItem.ValidityMonths = 0, "neobmedzená", ThisItem.ValidityMonths & " mes.") & "   ·   " & ThisItem.Provider', {
                  "Color": MUTED, "Size": "10", "Height": "20", "Width": "Parent.TemplateWidth - 200", "X": "16", "Y": "36"}),
        label("catType", TYPE_LABEL, {
            "Align": "Align.Center", "Color": TYPE_COLOR, "Fill": TYPE_FILL, "FontWeight": "FontWeight.Semibold",
            "Size": "10", "Height": "26", "Width": "130", "X": "Parent.TemplateWidth - 150", "Y": "Parent.TemplateHeight/2 - 13"}),
    ]
    cat_save = ('If(IsBlank(txtCatName.Text), Notify("Zadajte názov školenia.", NotificationType.Error, 2500), '
                '!IsNumeric(txtCatVal.Text), Notify("Platnosť musí byť číslo (0 = neobmedzená).", NotificationType.Error, 3000), '
                'Collect(colTrainingsCatalog, {ID: Max(colTrainingsCatalog, ID) + 1, TrainingName: txtCatName.Text, '
                'TrainingType: varCatType, ValidityMonths: Value(txtCatVal.Text), Provider: txtCatProv.Text}); '
                '/* LIVE: Patch(TrainingsCatalog, Defaults(TrainingsCatalog), {Title: txtCatName.Text, TrainingType:{Value:varCatType}, ValidityMonths: Value(txtCatVal.Text), Provider: txtCatProv.Text}); */ '
                'Collect(colAudit, {ID: Max(colAudit, ID) + 1, Action: "Create", EntityType: "TrainingCatalog", '
                'EntityID: txtCatName.Text, ChangedBy: varCurrentUser.Email, ChangedOn: Now(), '
                'Details: "Pridané školenie do katalógu: " & txtCatName.Text}); '
                'Notify("Školenie bolo pridané do katalógu.", NotificationType.Success, 2000); '
                'Reset(txtCatName); Reset(txtCatVal); Reset(txtCatProv))')
    type_chip = C("galCatType", "gallery.galleryHorizontal", {
        "FillPortions": "1", "Height": "40", "Layout": "Layout.Horizontal",
        "Items": 'Table({T:"Mandatory", L:"Povinné"}, {T:"Optional", L:"Voliteľné"}, {T:"Certification", L:"Certifikácia"}, {T:"Safety", L:"Bezpečnosť"})',
        "TemplatePadding": "0", "TemplateSize": "150", "ShowScrollbar": "false"},
      [btn("galCatTypeBtn", "ThisItem.L", {
          "Color": "If(varCatType = ThisItem.T, " + WHITE + ", " + TEXT + ")",
          "Fill": "If(varCatType = ThisItem.T, " + PURPLE + ", " + WHITE + ")",
          "BorderColor": BORDER, "BorderThickness": "1", "Height": "32", "Size": "9",
          "RadiusTopLeft": "16", "RadiusTopRight": "16", "RadiusBottomLeft": "16", "RadiusBottomRight": "16",
          "Width": "Parent.TemplateWidth - 6", "X": "0", "Y": "4", "OnSelect": "Set(varCatType, ThisItem.T)"})])
    cat_form = card("catForm", [
        label("catFormTitle", '"Nové školenie (len HR Admin)"', {
            "FontWeight": "FontWeight.Semibold", "Size": "12", "Height": "24"}),
        gc_h("catFormRow1", {"FillPortions": "0", "Height": "40", "LayoutGap": "8",
                             "LayoutAlignItems": "LayoutAlignItems.Center"}, [
            textinput("txtCatName", {"FillPortions": "2", "HintText": '"Názov školenia"'}),
            textinput("txtCatVal", {"FillPortions": "1", "HintText": '"Platnosť (mes., 0 = bez)"'}),
            textinput("txtCatProv", {"FillPortions": "1", "HintText": '"Poskytovateľ"'}),
        ]),
        gc_h("catFormRow2", {"FillPortions": "0", "Height": "40", "LayoutGap": "8",
                             "LayoutAlignItems": "LayoutAlignItems.Center"}, [
            type_chip,
            btn("btnCatSave", '"+ Pridať školenie"', {"Width": "180", "OnSelect": cat_save}, primary=True),
        ]),
    ], {"Visible": 'varRole = "admin"'})
    cat_body = [
        C("galCat", "gallery.galleryVertical", {
            "FillPortions": "1", "Layout": "Layout.Vertical", "Items": 'SortByColumns(colTrainingsCatalog, "TrainingName")',
            "TemplatePadding": "0", "TemplateSize": "62", "ShowScrollbar": "true"}, cat_row),
        cat_form,
    ]
    out["scrCatalog"] = screen(
        "scrCatalog", "cat", cat_body,
        title_text='"Katalóg školení"',
        subtitle='"Dostupné školenia, platnosť a poskytovatelia. Pridávanie len pre rolu HR Admin."')

    # ---------------------------------------------------------- 5. Záznamy školení
    rec_items = ('Sort(Filter(colRecords, '
                 '(varRole = "admin" || ManagerEmail = varCurrentUser.Email) '
                 '&& (IsBlank(varStatusFilter) || LiveStatus = varStatusFilter) '
                 '&& (txtSearchRec.Text = "" || StartsWith(EmployeeName, txtSearchRec.Text))), '
                 'CompletionDate, SortOrder.Descending)')
    rec_count = ('CountRows(Filter(colRecords, '
                 '(varRole = "admin" || ManagerEmail = varCurrentUser.Email) '
                 '&& (IsBlank(varStatusFilter) || LiveStatus = varStatusFilter) '
                 '&& (txtSearchRec.Text = "" || StartsWith(EmployeeName, txtSearchRec.Text)))) & " záznamov"')
    rec_actions = (200, [
        btn("btnAddRec", '"+ Pridať záznam"', {
            "Width": "180",
            "OnSelect": ('Set(varEditRecord, Blank()); Set(varPickedEmp, Blank()); '
                         'Set(varPickedTraining, Blank()); Navigate(scrAddRecord, ScreenTransition.None)')},
            primary=True)])
    rec_body = [
        gc_h("toolbarRec", {"FillPortions": "0", "Height": "44", "LayoutGap": "8",
                            "LayoutOverflowX": "LayoutOverflow.Scroll", "LayoutAlignItems": "LayoutAlignItems.Center"}, [
            textinput("txtSearchRec", {"FillPortions": "0", "Width": "300",
                                       "HintText": '"Meno zamestnanca (začiatok)…"'}),
            btn("btnAllStatRec", '"Všetky stavy"', {
                "Color": "If(IsBlank(varStatusFilter), " + WHITE + ", " + TEXT + ")",
                "Fill": "If(IsBlank(varStatusFilter), " + PURPLE + ", " + WHITE + ")",
                "BorderColor": BORDER, "BorderThickness": "1", "Width": "130", "Height": "34", "Size": "10",
                "RadiusTopLeft": "17", "RadiusTopRight": "17", "RadiusBottomLeft": "17", "RadiusBottomRight": "17",
                "OnSelect": "Set(varStatusFilter, Blank())"}),
            C("galStatusRec", "gallery.galleryHorizontal", {
                "FillPortions": "1", "Height": "44", "Layout": "Layout.Horizontal", "Items": "colStatuses",
                "TemplatePadding": "0", "TemplateSize": "162", "ShowScrollbar": "false"},
              [btn("galStatusRecBtn", "ThisItem.L", {
                  "Color": "If(varStatusFilter = ThisItem.S, " + WHITE + ", " + TEXT + ")",
                  "Fill": "If(varStatusFilter = ThisItem.S, " + PURPLE + ", " + WHITE + ")",
                  "BorderColor": BORDER, "BorderThickness": "1", "Height": "34", "Size": "9",
                  "RadiusTopLeft": "17", "RadiusTopRight": "17", "RadiusBottomLeft": "17", "RadiusBottomRight": "17",
                  "Width": "Parent.TemplateWidth - 6", "X": "0", "Y": "6",
                  "OnSelect": "Set(varStatusFilter, If(varStatusFilter = ThisItem.S, Blank(), ThisItem.S))"})]),
        ]),
        label("lblCountRec", rec_count, {"FillPortions": "0", "Color": MUTED, "Size": "10", "Height": "22"}),
        C("galRecs", "gallery.galleryVertical", {
            "FillPortions": "1", "Layout": "Layout.Vertical", "Items": rec_items,
            "TemplatePadding": "0", "TemplateSize": "60", "ShowScrollbar": "true"},
          record_row("Rec", True)),
    ]
    out["scrRecords"] = screen(
        "scrRecords", "recs", rec_body, actions=rec_actions,
        title_text='"Záznamy školení"',
        subtitle='If(varRole = "manager", "Záznamy vašich priamych podriadených.", "Všetky záznamy školení vo firme.")')

    _build_add_record(out)
    _build_my_trainings(out)
    _build_reports(out)
    return out


def _build_add_record(out):
    exp_preview = ('If(IsBlank(varPickedTraining) || IsError(DateValue(txtDateAdd.Text)), "—", '
                   'chkPlanned.Value, "— (doplní sa po absolvovaní)", '
                   'varPickedTraining.ValidityMonths = 0, "neobmedzená", '
                   'Text(DateAdd(DateValue(txtDateAdd.Text), varPickedTraining.ValidityMonths, TimeUnit.Months), "d.m.yyyy"))')
    save = ('If(IsBlank(varPickedEmp) || IsBlank(varPickedTraining), '
            'Notify("Vyberte zamestnanca aj školenie.", NotificationType.Error, 2500), '
            'IsError(DateValue(txtDateAdd.Text)), '
            'Notify("Zadajte platný dátum v tvare d.m.rrrr.", NotificationType.Error, 2500), '
            '!chkPlanned.Value && DateValue(txtDateAdd.Text) > Today(), '
            'Notify("Dátum absolvovania nemôže byť v budúcnosti. Označte Naplánované školenie.", NotificationType.Error, 3000), '
            'chkPlanned.Value && DateValue(txtDateAdd.Text) <= Today(), '
            'Notify("Plánovaný termín musí byť v budúcnosti.", NotificationType.Error, 2500), '
            'If(IsBlank(varEditRecord), '
            # nový – do colRecordsBase
            'Collect(colRecordsBase, {ID: Max(colRecordsBase, ID) + 1, Emp: varPickedEmp.EmployeeID, '
            'Tr: varPickedTraining.ID, Off: DateDiff(Today(), DateValue(txtDateAdd.Text), TimeUnit.Days), '
            'Pl: chkPlanned.Value, Cert: "", Notes: txtNotesAdd.Text}); '
            '/* LIVE: Patch(TrainingRecords, Defaults(TrainingRecords), {Employee: {Id: varPickedEmp.ID, Value: varPickedEmp.FullName}, '
            'Training: {Id: varPickedTraining.ID, Value: varPickedTraining.TrainingName}, '
            'CompletionDate: DateValue(txtDateAdd.Text), Status: {Value: If(chkPlanned.Value, "Planned", "Valid")}}); */ '
            'Collect(colAudit, {ID: Max(colAudit, ID) + 1, Action: "Create", EntityType: "TrainingRecord", '
            'EntityID: varPickedEmp.EmployeeID, ChangedBy: varCurrentUser.Email, ChangedOn: Now(), '
            'Details: "Pridaný záznam školenia " & varPickedTraining.TrainingName & " pre " & varPickedEmp.FullName}), '
            # úprava existujúceho
            'Patch(colRecordsBase, LookUp(colRecordsBase, ID = varEditRecord.ID), '
            '{Off: DateDiff(Today(), DateValue(txtDateAdd.Text), TimeUnit.Days), Pl: chkPlanned.Value, Notes: txtNotesAdd.Text}); '
            '/* LIVE: Patch(TrainingRecords, LookUp(TrainingRecords, ID = varEditRecord.ID), {CompletionDate: DateValue(txtDateAdd.Text)}); */ '
            'Collect(colAudit, {ID: Max(colAudit, ID) + 1, Action: "Update", EntityType: "TrainingRecord", '
            'EntityID: varEditRecord.EmployeeID, ChangedBy: varCurrentUser.Email, ChangedOn: Now(), '
            'Details: "Upravený záznam školenia " & varEditRecord.TrainingName}) '
            '); ' + REFRESH_RECORDS + '; '  # refresh dotknutej kolekcie
            'Notify("Záznam školenia bol uložený.", NotificationType.Success, 2000); '
            'Navigate(scrRecords, ScreenTransition.None))')

    emp_sug = C("galEmpSug", "gallery.galleryVertical", {
        "FillPortions": "0", "Height": "150", "Layout": "Layout.Vertical",
        "Fill": WHITE, "BorderColor": BORDER, "BorderThickness": "1",
        "Items": ('FirstN(Filter(colEmployees, Status = "Active" '
                  '&& (varRole <> "manager" || ManagerEmail = varCurrentUser.Email) '
                  '&& (StartsWith(FullName, txtEmpSearch.Text) || StartsWith(EmployeeID, txtEmpSearch.Text))), 5)'),
        "Visible": '!IsBlank(txtEmpSearch.Text) && (IsBlank(varPickedEmp) || txtEmpSearch.Text <> varPickedEmp.FullName)',
        "TemplatePadding": "0", "TemplateSize": "36", "ShowScrollbar": "false"},
      [label("empSugRow", 'ThisItem.FullName & "  (" & ThisItem.EmployeeID & ")"', {
          "Fill": WHITE, "Height": "Parent.TemplateHeight", "Width": "Parent.TemplateWidth", "PaddingLeft": "12",
          "Size": "10", "VerticalAlign": "VerticalAlign.Middle",
          "OnSelect": "Set(varPickedEmp, ThisItem); Reset(txtEmpSearch)"})])

    train_pick = C("galTrainPick", "gallery.galleryVertical", {
        "FillPortions": "0", "Height": "150", "Layout": "Layout.Vertical",
        "Fill": WHITE, "BorderColor": BORDER, "BorderThickness": "1",
        "Items": 'SortByColumns(colTrainingsCatalog, "TrainingName")',
        "TemplatePadding": "0", "TemplateSize": "34", "ShowScrollbar": "true"},
      [label("trainPickRow",
             'ThisItem.TrainingName & If(ThisItem.ValidityMonths > 0, " (platnosť " & ThisItem.ValidityMonths & " mes.)", "")', {
                 "Color": "If(varPickedTraining.ID = ThisItem.ID, " + PURPLE + ", " + TEXT + ")",
                 "Fill": "If(varPickedTraining.ID = ThisItem.ID, " + N_BG + ", " + WHITE + ")",
                 "FontWeight": "If(varPickedTraining.ID = ThisItem.ID, FontWeight.Semibold, FontWeight.Normal)",
                 "Height": "Parent.TemplateHeight", "Width": "Parent.TemplateWidth", "PaddingLeft": "12", "Size": "10",
                 "VerticalAlign": "VerticalAlign.Middle", "OnSelect": "Set(varPickedTraining, ThisItem)"})])

    form = gc_v("addForm", {
        "FillPortions": "0", "Width": "640", "AlignInContainer": "AlignInContainer.Start",
        "LayoutGap": "8", "LayoutAlignItems": "LayoutAlignItems.Stretch"}, [
        label("lblEmpCap", '"Zamestnanec"', {"FontWeight": "FontWeight.Semibold", "Size": "11", "Height": "22"}),
        textinput("txtEmpSearch", {
            "Default": 'If(IsBlank(varPickedEmp), "", varPickedEmp.FullName)',
            "DisplayMode": "If(IsBlank(varEditRecord), DisplayMode.Edit, DisplayMode.View)",
            "HintText": '"Začnite písať meno alebo osobné číslo…"'}),
        emp_sug,
        label("lblPicked", '"Vybraný: " & If(IsBlank(varPickedEmp), "—", varPickedEmp.FullName & " (" & varPickedEmp.EmployeeID & ")")',
              {"Color": MUTED, "Size": "10", "Height": "22"}),
        label("lblTrCap", '"Školenie"', {"FontWeight": "FontWeight.Semibold", "Size": "11", "Height": "22"}),
        train_pick,
        C("chkPlanned", "checkbox", {"FillPortions": "0", "Height": "36", "Size": "11",
                                     "Text": '"Naplánované školenie (budúci termín)"', "Default": "false"}),
        label("lblDateCap", 'If(chkPlanned.Value, "Plánovaný termín (d.m.rrrr)", "Dátum absolvovania (d.m.rrrr)")',
              {"FontWeight": "FontWeight.Semibold", "Size": "11", "Height": "22"}),
        gc_h("dateRow", {"FillPortions": "0", "Height": "40", "LayoutGap": "12",
                         "LayoutAlignItems": "LayoutAlignItems.Center"}, [
            textinput("txtDateAdd", {"FillPortions": "0", "Width": "200",
                                     "Default": 'If(IsBlank(varEditRecord), Text(Today(), "d.m.yyyy"), Text(varEditRecord.CompletionDate, "d.m.yyyy"))'}),
            label("lblExpPrev", '"Platnosť do: " & ' + exp_preview, {"FillPortions": "1", "Color": MUTED, "Size": "10", "Height": "26"}),
        ]),
        label("lblNotesCap", '"Poznámky"', {"FontWeight": "FontWeight.Semibold", "Size": "11", "Height": "22"}),
        textinput("txtNotesAdd", {"Height": "80", "Mode": "TextMode.MultiLine",
                                  "Default": 'If(IsBlank(varEditRecord), "", varEditRecord.Notes)'}),
        gc_h("addBtnRow", {"FillPortions": "0", "Height": "48", "LayoutGap": "10", "PaddingTop": "8",
                           "LayoutJustifyContent": "LayoutJustifyContent.End"}, [
            btn("btnCancelAdd", '"Zrušiť"', {"Width": "120", "OnSelect": "Navigate(scrRecords, ScreenTransition.None)"}),
            btn("btnSaveAdd", 'If(IsBlank(varEditRecord), "Uložiť záznam", "Uložiť zmeny")',
                {"Width": "170", "OnSelect": save}, primary=True),
        ]),
    ])
    out["scrAddRecord"] = screen(
        "scrAddRecord", "recs", [form],
        title_text='If(IsBlank(varEditRecord), "Nový záznam školenia", "Upraviť záznam školenia")',
        subtitle='"Výberom zamestnanca a školenia sa platnosť dopočíta automaticky z katalógu."')


def _build_my_trainings(out):
    my_exp = 'CountRows(Filter(colRecords, EmployeeID = varCurrentUser.EmployeeID && LiveStatus = "Expired"))'
    my_warn = 'CountRows(Filter(colRecords, EmployeeID = varCurrentUser.EmployeeID && LiveStatus = "Expiring"))'
    my_row = [
        C("myBg", "rectangle", {"Fill": WHITE, "BorderColor": BORDER, "BorderThickness": "1",
                                "Height": "Parent.TemplateHeight - 8", "Width": "Parent.TemplateWidth", "X": "0", "Y": "4"}),
        label("myTr", "ThisItem.TrainingName", {
            "FontWeight": "FontWeight.Semibold", "Size": "11", "Height": "24", "Width": "Parent.TemplateWidth - 360", "X": "16", "Y": "12"}),
        label("myDates",
              'If(ThisItem.Pl, "Plán: ", "Absolvované: ") & Text(ThisItem.CompletionDate, "d.m.yyyy") & "   Platí do: " & If(IsBlank(ThisItem.ExpirationDate), "—", Text(ThisItem.ExpirationDate, "d.m.yyyy"))', {
                  "Color": MUTED, "Size": "9", "Height": "20", "Width": "Parent.TemplateWidth - 360", "X": "16", "Y": "36"}),
        label("myPill", STATUS_TEXT, {
            "Align": "Align.Center", "Color": STATUS_COLOR, "Fill": STATUS_FILL, "FontWeight": "FontWeight.Semibold",
            "Size": "10", "Height": "26", "Width": "150", "X": "Parent.TemplateWidth - 340", "Y": "Parent.TemplateHeight/2 - 13"}),
        label("myCert", 'If(ThisItem.Cert = "", "", "Stiahnuť certifikát (PDF)")', {
            "Color": PURPLE, "Size": "10", "Height": "26", "Align": "Align.Center",
            "Width": "170", "X": "Parent.TemplateWidth - 180", "Y": "Parent.TemplateHeight/2 - 13"}),
    ]
    my_body = [
        label("banExpMy", '"Máte " & ' + my_exp + ' & " exspirované školenia. Kontaktujte HR oddelenie a dohodnite si náhradný termín."', {
            "FillPortions": "0", "Color": R_FG, "Fill": R_BG, "FontWeight": "FontWeight.Semibold", "Height": "40",
            "PaddingLeft": "16", "Size": "11", "VerticalAlign": "VerticalAlign.Middle", "Visible": my_exp + " > 0",
            "RadiusTopLeft": "8", "RadiusTopRight": "8", "RadiusBottomLeft": "8", "RadiusBottomRight": "8"}),
        label("banWarnMy", '"Čoskoro vám exspiruje " & ' + my_warn + ' & " školení – termíny nájdete v zozname nižšie."', {
            "FillPortions": "0", "Color": A_FG, "Fill": A_BG, "FontWeight": "FontWeight.Semibold", "Height": "40",
            "PaddingLeft": "16", "Size": "11", "VerticalAlign": "VerticalAlign.Middle", "Visible": my_warn + " > 0",
            "RadiusTopLeft": "8", "RadiusTopRight": "8", "RadiusBottomLeft": "8", "RadiusBottomRight": "8"}),
        C("galMy", "gallery.galleryVertical", {
            "FillPortions": "1", "Layout": "Layout.Vertical",
            "Items": "Sort(Filter(colRecords, EmployeeID = varCurrentUser.EmployeeID), CompletionDate, SortOrder.Descending)",
            "TemplatePadding": "0", "TemplateSize": "60", "ShowScrollbar": "true"}, my_row),
        label("emptyMy", '"Zatiaľ žiadne školenia. Po absolvovaní vám ich HR zaznamená aj s certifikátom."', {
            "FillPortions": "0", "Color": MUTED, "Height": "30",
            "Visible": "CountRows(Filter(colRecords, EmployeeID = varCurrentUser.EmployeeID)) = 0"}),
    ]
    out["scrMyTrainings"] = screen(
        "scrMyTrainings", "my", my_body,
        title_text='"Moje školenia"',
        subtitle='"Prihlásený: " & varCurrentUser.FullName & " (" & varCurrentUser.Email & ")"')


def _build_reports(out):
    ov = ('Set(varRepBy, Sort(AddColumns(RenameColumns(colDepartments, "DepartmentCode", "DC"), "Cnt", '
          'CountRows(Filter(colRecords, DepartmentCode = DC))), Cnt, SortOrder.Descending));\n'
          'Set(varRepMax, Max(Max(varRepBy, Cnt), 1));\n'
          'Set(varRepExp, Sort(AddColumns(RenameColumns(colDepartments, "DepartmentCode", "DC"), "Cnt", '
          'CountRows(Filter(colRecords, DepartmentCode = DC && LiveStatus = "Expiring"))), Cnt, SortOrder.Descending));\n'
          'Set(varRepExpMax, Max(Max(varRepExp, Cnt), 1));\n'
          'Set(varRepComp, Sort(AddColumns(RenameColumns(colDepartments, "DepartmentCode", "DC"), "Pct", '
          'With({t: CountRows(Filter(colRecords, DepartmentCode = DC && LiveStatus <> "Planned"))}, '
          'If(t = 0, 100, Round(CountRows(Filter(colRecords, DepartmentCode = DC && LiveStatus <> "Planned" && LiveStatus <> "Expired")) / t * 100, 0)))), Pct, SortOrder.Ascending))')

    def chart_card(name, title, items, value, maxexpr, fill, suffix=""):
        bar = [
            label(name + "Name", "ThisItem.DepartmentName", {
                "Size": "10", "Height": "Parent.TemplateHeight", "Width": "170", "X": "0", "Y": "0",
                "VerticalAlign": "VerticalAlign.Middle"}),
            C(name + "Track", "rectangle", {
                "Fill": N_BG, "Height": "12", "Width": "Parent.TemplateWidth - 240",
                "X": "176", "Y": "Parent.TemplateHeight/2 - 6",
                "RadiusTopLeft": "6", "RadiusTopRight": "6", "RadiusBottomLeft": "6", "RadiusBottomRight": "6"}),
            C(name + "Bar", "rectangle", {
                "Fill": fill, "Height": "12",
                "Width": "Max(4, ThisItem." + value + " / " + maxexpr + " * (Parent.TemplateWidth - 240))",
                "X": "176", "Y": "Parent.TemplateHeight/2 - 6",
                "RadiusTopLeft": "6", "RadiusTopRight": "6", "RadiusBottomLeft": "6", "RadiusBottomRight": "6"}),
            label(name + "Val", "ThisItem." + value + suffix, {
                "FontWeight": "FontWeight.Semibold", "Size": "10", "Height": "Parent.TemplateHeight",
                "Width": "56", "X": "Parent.TemplateWidth - 56", "Y": "0", "Align": "Align.End",
                "VerticalAlign": "VerticalAlign.Middle"}),
        ]
        return card(name + "Card", [
            label(name + "Title", title, {"FontWeight": "FontWeight.Semibold", "Size": "13", "Height": "26"}),
            C(name + "Gal", "gallery.galleryVertical", {
                "FillPortions": "0", "Height": "240", "Layout": "Layout.Vertical", "Items": items,
                "TemplatePadding": "0", "TemplateSize": "30", "ShowScrollbar": "false"}, bar),
        ], {"FillPortions": "0", "Height": "300"})

    rep_body = [
        chart_card("rep1", '"Počet školení podľa oddelenia"', "varRepBy", "Cnt", "varRepMax", PURPLE),
        chart_card("rep2", '"Exspiruje do 30 dní"', "varRepExp", "Cnt", "varRepExpMax", A_FG),
        chart_card("rep3", '"Miera súladu podľa oddelenia (% neexspirovaných)"', "varRepComp", "Pct", "100",
                   "If(ThisItem.Pct >= 90, " + G_FG + ", ThisItem.Pct >= 75, " + A_FG + ", " + R_FG + ")", ' & " %"'),
    ]
    out["scrReports"] = screen(
        "scrReports", "rep", rep_body, onvisible_extra=ov,
        title_text='"Reporty"',
        subtitle='"Školenia podľa oddelení a miera súladu jednotlivých tímov."')


def main():
    print("Generujem canvas zdroje (responzívne kontajnery):")
    build_onstart()
    screens = build_screens()
    build_screens_rest(screens)
    for name, txt in screens.items():
        (SRC / (name + ".fx.yaml")).write_text(txt)
        print(f"  {name}.fx.yaml ({len(txt)} B)")
    # CanvasManifest ScreenOrder
    import json
    mf = SRC.parent / "CanvasManifest.json"
    m = json.load(open(mf))
    m["ScreenOrder"] = ["scrHome", "scrEmployees", "scrEmployeeDetail", "scrCatalog",
                        "scrRecords", "scrAddRecord", "scrMyTrainings", "scrReports"]
    # Responzívne rozloženie: vypnúť scale-to-fit a fixný pomer strán, landscape canvas,
    # nech Screen.Width/Height sledujú okno a kontajnery sa preusporiadajú (Teams desktop aj mobil).
    m["Properties"].update({
        "DocumentLayoutScaleToFit": False,
        "DocumentLayoutMaintainAspectRatio": False,
        "DocumentLayoutLockOrientation": False,
        "DocumentLayoutOrientation": "landscape",
        "DocumentLayoutWidth": 1366,
        "DocumentLayoutHeight": 768,
        "DocumentAppType": "DesktopOrTablet",
    })
    json.dump(m, open(mf, "w"), indent=2, ensure_ascii=False)
    print("Hotovo.")


if __name__ == "__main__":
    main()
