extends RefCounted
## A neutral-stick measurement. Recommendations are staged, never applied here.
const DURATION := 3.0
const MIN_SAMPLES := 24
const MARGIN := 0.04
const MAX_NEUTRAL := 0.55
var device := -1
var active := false
var elapsed := 0.0
var samples := 0
var peaks: Array[float] = [0.0, 0.0, 0.0, 0.0]
var result: Dictionary = {}

func start(id: int) -> void:
    cancel()
    if id < 0:return
    device = id
    active = true

func cancel(reason: String = "") -> void:
    device = -1
    active = false
    elapsed = 0.0
    samples = 0
    peaks = [0.0, 0.0, 0.0, 0.0]
    result = {"ok":false,"reason":reason}

func sample(id: int, values: Array, delta: float) -> void:
    if not active:return
    if id != device:
        cancel("设备已切换或断开，请重新测量。")
        return
    if values.size() != 4 or not is_finite(delta) or delta <= 0.0 or delta > 0.25:
        cancel("采样中断，请松开摇杆后重新测量。")
        return
    for value in values:
        if typeof(value) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(value)) or absf(float(value)) > MAX_NEUTRAL:
            cancel("检测到明显推杆；请松开两支摇杆后重试。")
            return
    for index in 4:peaks[index] = maxf(peaks[index],absf(float(values[index])))
    samples += 1
    elapsed += delta
    if elapsed < DURATION:return
    active = false
    if samples < MIN_SAMPLES:
        result = {"ok":false,"reason":"有效样本不足，请重新测量。"}
        return
    var peak := 0.0
    for value in peaks:peak = maxf(peak,value)
    # Round upward so the largest measured neutral value is always covered.
    var recommendation := clampf(ceilf((peak+MARGIN)*100.0)/100.0,0.1,0.6)
    result = {"ok":true,"deadzone":recommendation,"peak":peak,"samples":samples,"peaks":peaks.duplicate()}

func status() -> String:
    if active:return "松开两支摇杆：测量中 %.1f / %.1f 秒（%d 次）" % [minf(elapsed,DURATION),DURATION,samples]
    if result.get("ok",false):return "中立漂移峰值 %.2f；建议死区 %d%%。可先暂存，再核对下方变化。" % [float(result.peak),int(round(float(result.deadzone)*100))]
    return String(result.get("reason","点击测量，在三秒内松开两支摇杆。"))
