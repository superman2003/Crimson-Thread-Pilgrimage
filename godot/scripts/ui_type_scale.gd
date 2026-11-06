extends RefCounted
## U01: the type scale of the four main pages (backpack, build, map, settings).
## Each role has one size; page controls take their size from here.
const BREADCRUMB := 11 ## the "绯线巡礼 / 归途手札" trail
const CAPTION := 12    ## hints, legends, counters and badges
const CONTROL := 14    ## secondary actions: launchers, filters, slots, tools
const BODY := 16       ## running text and value rows
const ACTION := 17     ## primary page actions such as 返回
const TITLE := 18      ## page titles and toggles
const SECTION := 20    ## section headings and tabs
const READING := 21    ## reading-size baseline text
const DISPLAY := 23    ## region or item names
const SCALE := [BREADCRUMB, CAPTION, CONTROL, BODY, ACTION, TITLE, SECTION, READING, DISPLAY]
