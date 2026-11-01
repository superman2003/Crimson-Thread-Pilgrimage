extends "res://journey/tests/i_support.gd"
const M := preload("res://journey/fieldwork/share_cards/model.gd")
const A := preload("res://journey/fieldwork/share_cards/advanced.gd")
const FEATURE := preload("res://journey/features/i_share_cards.gd")


func run() -> void:
    label = "I29_SHARE_CARDS"
    var context := field_fixture("j29_share_cards")
    await exercise(context, M, FEATURE, "j_share_cards", "include_counts")
    domain_checks(context)
    await inspector_checks(context)
    finish()


func flatten(pages: Array) -> Array:
    var result:=[]
    for page in pages:
        result.append_array(page)
    return result


func parsed_svg(text: String) -> bool:
    var parser:=XMLParser.new()
    if parser.open_buffer(text.to_utf8_buffer())!=OK:
        return false
    var status:=parser.read()
    var count:=0
    while status==OK and count<20000:
        count+=1
        status=parser.read()
    return status==ERR_FILE_EOF and count>10


func domain_checks(context: RefCounted) -> void:
    check(A.wrap_text("abcdef",3)==["abc","def"], "ASCII wrap respects requested columns")
    check(A.wrap_text("巡礼旅途",4)==["巡礼","旅途"], "Chinese glyphs take two reference columns")
    check(A.wrap_text("a\r\nb\rc",10)==["a","b","c"], "CRLF and CR are normalized without lost rows")
    check(A.wrap_text("a\n",10)==["a",""], "trailing explicit blank line is preserved")
    check(A.wrap_text("abc",1).is_empty(), "impossible wrap width rejects")
    check(A.wrap_text("ab\u0301c",2)==["ab\u0301","c"], "combining mark stays with preceding base at line edge")
    check(A.escape("<&\"'>")=="&lt;&amp;&quot;&apos;&gt;", "SVG content and attribute markup escaped")
    var payload:=M.capture(context.snapshot())
    payload.note="private-unselected-note person@example.com token=private-value"
    payload.region="private-unselected-location"
    var card:=M.body(payload)
    var document:=M.svg(payload)
    check(parsed_svg(document), "standalone multi-sheet SVG parses fully")
    check(not document.contains("private-unselected-note") and not document.contains("private-unselected-location"), "unselected fields cannot leak into SVG")
    check(not document.contains("person@example.com") and not document.contains("private-value"), "private raw note does not bypass sanitizer")
    payload.include_note=true
    payload.note="巡礼".repeat(250)
    payload.include_abilities=true
    payload.abilities=[]
    for i in 40:
        payload.abilities.append("能力"+str(i)+"甲乙丙丁戊己庚辛壬癸".repeat(4))
    card=M.body(payload)
    var layout:=A.paginate(card)
    check(layout.ok and layout.pages.size()>1, "full long public card spans multiple sheets")
    var original:=[]
    for entry in A.entries(card):
        for line in A.wrap_text(entry.text):
            original.append({"text":line,"heading":entry.heading,"field":entry.field})
    check(flatten(layout.pages)==original, "pagination preserves every wrapped public line in exact order")
    for page in layout.pages:
        check(page.size()<=A.LINES, "every sheet fits fixed content rectangle")
        if not page.is_empty() and page[-1].heading:
            check(page==layout.pages[-1], "section heading never orphaned before following content")
    document=M.svg(payload)
    check(parsed_svg(document), "large sanitized export remains complete XML")
    check(document.contains("第1 /") and document.contains("第%d /"%layout.pages.size()), "all sheet numbers and total count are exported")
    check(document.contains("巡礼") and not document.contains("…"), "public content is wrapped rather than silently ellipsized")
    check(not document.contains("<script") and not document.contains("xlink:href") and not document.contains("<image"), "SVG export embeds no scripts or external resources")
    check(A.paginate(card)==layout, "pagination is deterministic")
    var frozen:=JSON.stringify(card)
    A.svg(card)
    check(JSON.stringify(card)==frozen, "rendering cannot edit sanitized body")
    var reordered:={}
    var keys:=card.keys()
    keys.reverse()
    for key in keys:
        reordered[key]=card[key]
    check(A.svg(reordered)==A.svg(card), "dictionary insertion order does not affect sheet order")
    for capacity in [2,3,7,19,34]:
        var paged:=A.paginate(card,capacity)
        check(paged.ok and flatten(paged.pages)==original, "all valid page capacities preserve complete line stream")
        check(paged.pages.all(func(page: Array): return page.size()<=capacity), "custom capacity never overfills a page")
    check(not A.paginate(card,1).ok and not A.paginate(card,101).ok, "invalid page limits rejected")
    var empty:=A.paginate({"title":"空公开卡"})
    check(empty.ok and empty.pages.size()==1, "empty public body produces a labeled empty sheet")
    payload.include_note=true
    payload.note="<script>alert(1)</script> & <未知>"
    document=M.svg(payload)
    check(not document.contains("<script>") and document.contains("&lt;script&gt;"), "public markup remains literal escaped text")
    check(parsed_svg(document), "escaped literal markup does not break XML")
    var oversized:={"title":"Too long","note":"长".repeat(200000)}
    check(not A.paginate(oversized).ok and A.svg(oversized).is_empty(), "capacity overrun never emits a partial document")


func inspector_checks(context: RefCounted) -> void:
    var before := V.fingerprint(context.latest)
    var payload := M.capture(context.snapshot())
    var view := preload("res://journey/fieldwork/share_cards/advanced_view.gd").new()
    view.configure({"body":M.body(payload)})
    view.size = Vector2(760, 600)
    root.add_child(view)
    await process_frame
    await process_frame
    check(view.get_child_count()>0, "native advanced inspector builds on its own branch")
    view._change(1); view._change(-1)
    await process_frame
    check(V.fingerprint(context.latest)==before, "interactive inspector never changes live progress")
    view.free()
