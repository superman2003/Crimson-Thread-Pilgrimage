#!/usr/bin/env python3
"""Generate instrumental music through Vercel AI Gateway, or check auth only.

Official protocol: https://vercel.com/docs/ai-gateway/modalities/text-to-speech
The key is loaded locally from the environment or ignored .env.local, never
written to generation receipts or shipped with the game. No dependencies.
"""
import argparse
import base64
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import urllib.error
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
CONFIG = ROOT / "art_requests/ai_music_v1/provider_config.json"


def load_key():
    if key := os.environ.get("AI_GATEWAY_API_KEY"):
        return key
    path = ROOT / ".env.local"
    if path.is_file():
        for line in path.read_text(encoding="utf-8").splitlines():
            name, separator, value = line.partition("=")
            if separator and name.strip() == "AI_GATEWAY_API_KEY":
                return value.strip().strip("\"'")
    raise ValueError("Set AI_GATEWAY_API_KEY or add it to the ignored .env.local file")


def request_json(url, key, *, body=None, headers=None):
    request = urllib.request.Request(url, data=json.dumps(body).encode("utf-8") if body else None,
                                     headers={"Authorization": "Bearer " + key, **(headers or {})})
    # A paid generation is attempted once. A timeout must be reconciled in
    # Vercel's request log before another explicit invocation.
    with urllib.request.urlopen(request, timeout=600 if body else 30) as response:
        return json.load(response)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Read-only authentication check; generates no music")
    parser.add_argument("--prompt-file", type=Path)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--duration-seconds", type=int)
    args = parser.parse_args()
    config = json.loads(CONFIG.read_text(encoding="utf-8"))
    if args.check:
        if args.prompt_file or args.output or args.duration_seconds:
            parser.error("--check cannot be combined with generation arguments")
    elif not args.prompt_file or not args.output:
        parser.error("Provide --prompt-file and --output to generate, or --check for a read-only check")
    try:
        key = load_key()
        if args.check:
            request_json("https://ai-gateway.vercel.sh/v1/credits", key)
            print(json.dumps(dict(provider=config["preferred_provider"], model=config["model"],
                                  authentication="verified", generation_requests=0)))
            return
        duration = args.duration_seconds or config["default_duration_seconds"]
        if not 3 <= duration <= 600:
            parser.error("Duration must be between 3 and 600 seconds")
        target = args.output.resolve()
        receipt_path = target.with_suffix(target.suffix + ".receipt.json")
        if target.exists() or receipt_path.exists():
            parser.error("Choose a new output path; existing output/receipt will not be overwritten")
        prompt = args.prompt_file.read_text(encoding="utf-8").strip()
        if not prompt:
            parser.error("Prompt file is empty")
        target.parent.mkdir(parents=True, exist_ok=True)
        body = dict(text=prompt, outputFormat="mp3", providerOptions=dict(elevenlabs=dict(
            musicLengthMs=duration * 1000, forceInstrumental=config["force_instrumental"])))
        receipt = dict(provider=config["preferred_provider"], model=config["model"],
                       requested_duration_seconds=duration, prompt=prompt, request=body,
                       requested_at=datetime.now(timezone.utc).isoformat(), status="submitted_result_pending")
        receipt_path.write_text(json.dumps(receipt, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        result = request_json(config["endpoint"], key, body=body, headers={
            "Content-Type": "application/json", "ai-gateway-protocol-version": "0.0.1",
            "ai-speech-model-specification-version": "4", "ai-model-id": config["model"]})
        audio = base64.b64decode(result["audio"], validate=True)
        if not audio:
            raise ValueError("Gateway returned empty audio; review the receipt before retrying")
        target.write_bytes(audio)
        receipt.update(status="generated_pending_probe_and_audition", bytes=len(audio),
                       sha256=hashlib.sha256(audio).hexdigest(), warnings=result.get("warnings", []),
                       completed_at=datetime.now(timezone.utc).isoformat())
        receipt_path.write_text(json.dumps(receipt, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(json.dumps(dict(provider=config["preferred_provider"], model=config["model"], output=str(target), bytes=len(audio))))
    except urllib.error.HTTPError as error:
        raise SystemExit(f"Vercel AI Gateway returned HTTP {error.code}; no automatic retry was made") from None
    except (urllib.error.URLError, TimeoutError):
        raise SystemExit("Gateway request failed or timed out; check Vercel request history before resubmitting") from None
    except (OSError, ValueError, KeyError) as error:
        raise SystemExit(str(error)) from None


if __name__ == "__main__":
    main()
