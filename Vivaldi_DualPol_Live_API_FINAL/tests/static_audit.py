"""Kiểm tra tĩnh, nguồn/GPL và VBS; không thay MATLAB GUI hoặc HFSS runtime."""
from pathlib import Path
import argparse
import hashlib
import json
import re

ROOT = Path(__file__).resolve().parents[1]
SHA = "631820b2c07f457fd22f5cdab2aeae15694788c869629935460b2cefda1ba619"


def audit_sources():
    ref = ROOT / "reference/17_10_2026_vivaldi.aedt"
    assert hashlib.sha256(ref.read_bytes()).hexdigest() == SHA
    assert ref.read_bytes() == (ROOT.parent / "17_10_2026_vivaldi.aedt").read_bytes()
    md = "Phan_tich_chi_tiet_Vivaldi_dual_pol_17_10_2026.md"
    assert (ROOT / "reference" / md).read_bytes() == (ROOT.parent / md).read_bytes()
    stack, blocks = [], 0
    for line in ref.read_text().splitlines():
        begin = re.match(r"\s*\$begin '([^']+)'", line)
        end = re.match(r"\s*\$end '([^']+)'", line)
        if begin:
            stack.append(begin[1])
            blocks += 1
        if end:
            assert stack.pop() == end[1]
    assert not stack and blocks == 3285
    own = [
        f for f in ROOT.rglob("*.m")
        if not {"third_party", "work"} & set(f.relative_to(ROOT).parts)
    ]
    assert len(own) < 34 and not (ROOT / "com").exists()
    for file in own:
        text = file.read_text()
        first = re.search(
            r"^\s*(?:classdef\s+(\w+)|function\s+(?:\[[^]]*\]\s*=\s*|\w+\s*=\s*)?(\w+)\s*\()",
            text, re.M,
        )
        assert first and (first[1] or first[2]) == file.stem, file
        assert "Mục đích:" in text[:1000], file
        assert not re.search(r"\bactx(?:server|GetRunningServer)\s*\(", text), file
    gui = (ROOT / "Vivaldi_DualPol_Live_API.m").read_text()
    for label in ("Thông số anten", "Xem trước 3D", "Kết nối HFSS", "Mô phỏng", "Nhật ký & kiểm tra"):
        assert re.search(r"'Title'\s*,\s*'" + re.escape(label) + "'", gui)
    assert len(re.findall(r"\bbutton\((?:pb|cb|sb|z),", gui)) == 11
    for obsolete in ("'Calculate'", "'Apply Changes'", "'Connect HFSS'", "'RUN SIMULATION'"):
        assert obsolete not in gui
    assert re.search(r"'Limits'\s*,\s*\[-Inf\s+Inf\]", gui)
    provenance = json.loads((ROOT / "third_party/HFSS_API_PROVENANCE.json").read_text())
    vendor = ROOT / "third_party/hfss-api"
    changed = []
    for name, digest in provenance["upstreamFilesSHA256"].items():
        file = vendor / name
        assert file.is_file(), name
        if hashlib.sha256(file.read_bytes()).hexdigest() != digest:
            changed.append(name)
    assert changed == ["general/hfssExecuteScript.m"], changed
    assert (vendor / "COPYING").read_bytes() == (ROOT / "COPYING").read_bytes()
    assert "GNU GENERAL PUBLIC LICENSE" in (ROOT / "COPYING").read_text()
    for example in ("1_Dipole/dipole_example.m", "2_Horn/temHorn.m",
                    "3_Patch/microwave_patch.m", "4_Folded_dipole/folded_dipole.m"):
        assert (vendor / "examples" / example).is_file()
    return {
        "sourceSHA256": SHA, "sourceBytes": ref.stat().st_size,
        "balancedBlocks": blocks, "ownMATLABFiles": len(own),
        "baselineOwnMATLABFiles": 34,
        "upstreamFiles": len(provenance["upstreamFilesSHA256"]),
        "modifiedUpstreamFiles": changed,
        "primaryArchitecture": "hfss-api -> VBScript -> HFSS",
        "checks": ["source/reference integrity", "function/file names",
                   "Vietnamese function headers", "5 Vietnamese tabs / 11 primary buttons",
                   "no MATLAB persistent COM", "GPL / pinned upstream hashes"],
    }


def audit_script(file):
    raw = file.read_bytes()
    assert raw.startswith(b"\xff\xfe") and len(raw) % 2 == 0, file
    text = raw.decode("utf-16")
    assert "\0" not in text
    depth, continued = 0, 0
    for line in text.splitlines():
        assert len(line) < 1023, (file, len(line))
        continued = continued + 1 if line.rstrip().endswith("_") else 0
        assert continued < 25, file
        index, quoted = 0, False
        while index < len(line):
            char = line[index]
            if char == '"':
                if quoted and index + 1 < len(line) and line[index + 1] == '"':
                    index += 2
                    continue
                quoted = not quoted
            elif char == "'" and not quoted:
                break
            elif not quoted:
                if char == "(":
                    depth += 1
                elif char == ")":
                    depth -= 1
                    assert depth >= 0, (file, line)
            index += 1
        assert not quoted, (file, line)
    assert depth == 0, file
    for kind in ("Sub", "Function"):
        assert len(re.findall(r"^\s*" + kind + r"\s+\w+", text, re.M | re.I)) == len(
            re.findall(r"^\s*End " + kind + r"\s*$", text, re.M | re.I)
        ), file
    assert "Option Explicit" in text and "VERIFIED|1" in text and "JOB|" in text
    return {"file": file.name, "physicalLines": len(text.splitlines()),
            "maxLineLength": max(map(len, text.splitlines()))}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--scripts-json", type=Path)
    args = parser.parse_args()
    report = audit_sources()
    if args.scripts_json:
        scripts = json.loads(args.scripts_json.read_text())["scripts"]
        report["generatedVBSScripts"] = [audit_script(Path(file)) for file in scripts]
    report["status"] = "PASS"
    report["scope"] = "Static only; MATLAB desktop/VBScript execution/HFSS CAD/solver still PENDING"
    print(json.dumps(report, ensure_ascii=False, indent=2))
