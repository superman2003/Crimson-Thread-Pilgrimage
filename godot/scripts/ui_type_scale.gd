extends RefCounted
## U01: the type scale of the four main pages (backpack, build, map, settings)
## and the World HUD. Each role has one size; controls take their size from here.
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
const HUD_PLACE := 25  ## the HUD's current room name, the one larger HUD line
const BANNER := 30     ## full-screen announcements such as a cleared chapter
## The HUD uses the page scale plus its room name and banner.
const HUD_SCALE := [BREADCRUMB, CAPTION, CONTROL, BODY, ACTION, TITLE, SECTION, READING, DISPLAY, HUD_PLACE, BANNER]
