"""Đóng gói, giải nén và kiểm tra ZIP; công cụ tùy chọn, chỉ dùng Python stdlib."""
from pathlib import Path
import hashlib, json, tempfile, zipfile
from datetime import datetime, timezone
ROOT = Path(__file__).resolve().parents[1]
EXCLUDED = {'MANIFEST_SHA256.json','tests/verification/packaging-verified.json'}

def sha(data): return hashlib.sha256(data).hexdigest()
def payload():
    return {str(f.relative_to(ROOT)).replace('\\','/'):sha(f.read_bytes())
            for f in sorted(ROOT.rglob('*')) if f.is_file()
            and not any(x in f.parts for x in ('__pycache__','.git','work'))
            and str(f.relative_to(ROOT)).replace('\\','/') not in EXCLUDED}
def build(destination):
    with zipfile.ZipFile(destination, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        for f in sorted(ROOT.rglob('*')):
            if f.is_file() and not any(x in f.parts for x in ('__pycache__','.git','work')):
                z.write(f, str(Path(ROOT.name)/f.relative_to(ROOT)))
def verify(destination, hashes):
    with tempfile.TemporaryDirectory(prefix='vivaldi-zip-check-') as temp:
        with zipfile.ZipFile(destination) as z:
            assert z.testzip() is None, 'CRC error'
            for name in z.namelist():
                assert not name.startswith('/') and '..' not in Path(name).parts
            z.extractall(temp)
        base=Path(temp)/ROOT.name
        for name, digest in hashes.items():
            assert sha((base/name).read_bytes()) == digest, name
        assert (base/'Vivaldi_DualPol_Live_API.m').is_file()
        assert (base/'automation'/'VivaldiHFSS.m').is_file()
        assert (base/'custom_helpers'/'hfssVivaldiExtensions.m').is_file()
        assert (base/'third_party'/'hfss-api'/'general'/'hfssExecuteScript.m').is_file()
        assert (base/'third_party'/'hfss-api'/'COPYING').is_file()
        assert (base/'COPYING').is_file()
        assert (base/'docs'/'KNOWN_LIMITATIONS.md').is_file()
        assert (base/'tests'/'runHFSSAPIIntegration.m').is_file()
        return len(list(base.rglob('*')))
if __name__ == '__main__':
    target=ROOT.parent/(ROOT.name+'.zip')
    evidence=ROOT/'tests'/'verification'; evidence.mkdir(parents=True,exist_ok=True)
    hashes=payload()
    (ROOT/'MANIFEST_SHA256.json').write_text(json.dumps({'algorithm':'SHA-256','files':hashes,
        'excluded':sorted(EXCLUDED)},indent=2)+'\n')
    build(target)
    verify(target,hashes)
    report={'status':'PASS','timeUTC':datetime.now(timezone.utc).isoformat(),'archive':target.name,
            'payloadFilesVerified':len(hashes),'checks':['ZIP CRC','actual extraction','per-file SHA-256','required files/dependencies'],
            'scope':'Payload manifest excludes itself and this verification report; final archive also rechecked after embedding report.'}
    (evidence/'packaging-verified.json').write_text(json.dumps(report,indent=2)+'\n')
    build(target)
    verify(target,hashes)
    final={**report,'archiveBytes':target.stat().st_size,'archiveSHA256':sha(target.read_bytes())}
    (ROOT.parent/(ROOT.name+'_ZIP_INTEGRITY.json')).write_text(json.dumps(final,indent=2)+'\n')
    print(json.dumps(final,indent=2))
