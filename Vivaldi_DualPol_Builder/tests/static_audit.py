"""Audit độc lập nguồn, thư viện, GUI và lexical script; không chạy compiler/HFSS."""
from pathlib import Path
import argparse, hashlib, json, re
ROOT = Path(__file__).resolve().parents[1]
PROTECTED = {
    '17_10_2026_vivaldi.aedt': '631820b2c07f457fd22f5cdab2aeae15694788c869629935460b2cefda1ba619',
    'Phan_tich_chi_tiet_Vivaldi_dual_pol_17_10_2026.md': '49c5cbc0bc445e9bad6df008d9487f987c5db99cee7aca567fed0b205ad6e912',
}
def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def audit_script(path):
    data = path.read_bytes()
    assert data.startswith(b'Option Explicit\r\n') and all(b < 128 for b in data) and b'\0' not in data
    text = data.decode('ascii')
    lines = text.splitlines()
    assert max(map(len, lines)) < 1023
    quoted = False; depth = 0; continuation = 0; stack = []
    for line in lines:
        if line.rstrip().endswith('_'): continuation += 1
        else: continuation = 0
        assert continuation < 25
        code = []; i = 0
        while i < len(line):
            c = line[i]
            if c == '"':
                if quoted and i+1 < len(line) and line[i+1] == '"': i += 2; continue
                quoted = not quoted
            elif not quoted:
                if c == "'": break
                code.append(c)
                if c == '(': depth += 1
                if c == ')': depth -= 1
                assert depth >= 0
            i += 1
        assert not quoted
        bare = ''.join(code).strip().lower()
        if re.match(r'^(sub|function)\s', bare): stack.append(bare.split()[0])
        if bare.startswith('end sub'): assert stack.pop() == 'sub'
        if bare.startswith('end function'): assert stack.pop() == 'function'
    assert depth == 0 and not stack
    # Giải mã ChrW theo UTF-16 để kiểm tra roundtrip đường dẫn/log thật, không chỉ BOM.
    pattern = r'\((?:ChrW\(-?\d+\)(?:\s*&\s*)?)+\)'
    def decode(match):
        units = [int(v) & 0xffff for v in re.findall(r'ChrW\((-?\d+)\)', match[0])]
        value = b''.join(v.to_bytes(2, 'little') for v in units).decode('utf-16-le')
        return '"' + value.replace('"', '""') + '"'
    decoded = re.sub(pattern, decode, re.sub(r'\s+_\r?\n\s*', ' ', text))
    if path.name == 'encoding.vbs':
        assert 'C:\\Đồ án\\anten ""mới"".aedt' in decoded
        assert 'nhật ký.txt' in decoded
    if path.name == 'build.vbs':
        assert str(path.parent/'status.txt') in decoded
    assert 'RestorePrevious' not in text and 'vRollbackEnabled' not in text
    return {'file': str(path), 'bytes': len(data), 'maxPhysicalLine': max(map(len, lines)),
            'checks': ['ASCII/no BOM/NUL', 'strings/parentheses', 'Sub/Function blocks',
                       'line/continuation limits', 'Unicode ChrW roundtrip']}
def main():
    parser = argparse.ArgumentParser(); parser.add_argument('--results', type=Path, required=True)
    parser.add_argument('--extra-script', type=Path, action='append', default=[])
    args = parser.parse_args()
    for name, digest in PROTECTED.items():
        assert sha(ROOT.parent/name) == digest and sha(ROOT/'reference'/name) == digest
    provenance = json.loads((ROOT/'third_party/HFSS_API_PROVENANCE.json').read_text())
    for name, original in provenance['upstreamFilesSHA256'].items():
        expected = provenance['patchedFiles'].get(name, {}).get('afterSHA256', original)
        assert sha(ROOT/'third_party/hfss-api'/name) == expected, name
    assert len(provenance['upstreamFilesSHA256']) == 89
    assert (ROOT/'COPYING').read_bytes() == (ROOT/'third_party/hfss-api/COPYING').read_bytes()
    gui = (ROOT/'Vivaldi_GUI.m').read_text()
    assert len(re.findall(r'= uitab\(', gui)) == 5 and gui.count('= uibutton(') == 6
    assert "'Limits', [-Inf Inf]" in gui
    # Không launch khi tạo GUI: các lệnh chỉ được đặt trong nested callback.
    setup = gui[:gui.index('    function parameterChanged')]
    assert "Vivaldi_HFSS_Builder('" not in setup and 'hfssExecuteScript(' not in setup
    own = list(ROOT.glob('*.m')) + list((ROOT/'custom_helpers').glob('*.m'))
    assert len(own) == 6 and len(list(ROOT.glob('*.m'))) == 4
    for file in own:
        source = file.read_text()
        assert 'classdef' not in source and 'actxserver' not in source
        assert 'Mục đích:' in source
    assert not (ROOT/'automation').exists() and not (ROOT/'core').exists()
    runtime = (ROOT/'custom_helpers/hfssVivaldiChecks.vbs').read_text()
    assert 'CreateObject("Scripting.Dictionary")' not in runtime
    assert 'objects = QueryGroup(CStr(groupName))' in runtime
    assert 'Err.Raise number, command, description' in runtime
    assert 'oProject.SaveAs vDebugPath, False' in runtime
    builder = (ROOT/'Vivaldi_HFSS_Builder.m').read_text()
    for surface in ('EquationSurface1', 'EquationSurface2'):
        assert f'HasName(ObjectNames(),"{surface}")' not in builder
        assert f'HasName(sbObjects,"{surface}")' in builder
    assert builder.count('sbObjects = QueryGroup("Sheets")') == 2
    result = json.loads(args.results.read_text())
    scripts = [audit_script(Path(path)) for path in result['scripts']]
    scripts.extend(audit_script(path) for path in args.extra_script)
    report = {'status': 'PASS', 'ownMainFiles': 4, 'ownHelperMATLABFiles': 2,
              'upstreamFilesVerified': 89, 'protectedFilesSHA256': PROTECTED,
              'generatedScripts': scripts, 'HFSSCheckpointStatus': {f'CHECK_{k:02d}': 'PENDING' for k in range(1, 19)}, 'WindowsQueryFixtures': 'PENDING', 'scope': 'Static only; Windows compiler, GUI and HFSS remain PENDING.'}
    (ROOT/'tests/verification/static-audit.json').write_text(json.dumps(report, indent=2)+'\n')
    print(json.dumps({'status': 'PASS', 'scripts': len(scripts), 'ownMATLABFiles': len(own)}))
if __name__ == '__main__': main()
