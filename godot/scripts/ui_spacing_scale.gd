extends RefCounted
## U01: the spacing scale for window and page containers. Container gaps
## (separation, h_separation, v_separation) take one of these values.
const TIGHT := 8    ## buttons and fields inside one tool row
const ROW := 10     ## rows of a list, filter chips, grid cells
const BLOCK := 12   ## blocks inside a dialog column
const SECTION := 16 ## sections of a dialog that has few, larger parts
const SCALE := [TIGHT, ROW, BLOCK, SECTION]
