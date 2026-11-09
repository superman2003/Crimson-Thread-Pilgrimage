extends RefCounted
## Source checkouts keep raw audio; desktop PCKs keep imported AudioStreams.
## Each load returns an independent stream so loop variants cannot share flags.

static func exists(path: String) -> bool:
    return not path.is_empty() and (FileAccess.file_exists(path) or ResourceLoader.exists(path,"AudioStream"))

static func load_stream(path: String) -> AudioStream:
    if path.is_empty() or not (path.ends_with(".ogg") or path.ends_with(".wav")):return null
    if FileAccess.file_exists(path):
        if path.ends_with(".ogg"):return AudioStreamOggVorbis.load_from_file(path)
        return AudioStreamWAV.load_from_file(path)
    if ResourceLoader.exists(path,"AudioStream"):
        var imported:=ResourceLoader.load(path,"AudioStream") as AudioStream
        if imported!=null:return imported.duplicate() as AudioStream
    return null
