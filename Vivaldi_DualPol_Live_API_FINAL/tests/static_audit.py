"""Read-only release checks; optional Python developer tool, not app runtime."""
from pathlib import Path
import hashlib, json, re
ROOT = Path(__file__).resolve().parents[1]
SHA = '631820b2c07f457fd22f5cdab2aeae15694788c869629935460b2cefda1ba619'

def audit():
    ref = ROOT/'reference'/'17_10_2026_vivaldi.aedt'
    assert hashlib.sha256(ref.read_bytes()).hexdigest() == SHA
    stack, blocks = [], 0
    for line in ref.read_text().splitlines():
        begin = re.match(r"\s*\$begin '([^']+)'", line)
        end = re.match(r"\s*\$end '([^']+)'", line)
        if begin: stack.append(begin[1]); blocks += 1
        if end: assert stack.pop() == end[1]
    assert not stack and blocks == 3285
    matlab = sorted(ROOT.rglob('*.m'))
    assert len(matlab) >= 34
    for file in matlab:
        text = file.read_text()
        declaration = re.search(r'^\s*(?:classdef\s+(\w+)|function\s+(?:\[[^]]*\]\s*=\s*|\w+\s*=\s*)?(\w+)\s*\()', text, re.M)
        assert declaration, file
        name = declaration[1] or declaration[2]
        assert name == file.stem, (file, name)
    runtime = list((ROOT/'com').glob('*.m')) + [ROOT/'Vivaldi_DualPol_Live_API.m']
    for file in runtime:
        text = file.read_text()
        code = '\n'.join(line for line in text.splitlines() if not line.lstrip().startswith('%'))
        assert not re.search(r'(?:RunScript|\.vbs\b|AnalyzeAll\b|system\s*\(|dos\s*\()', code, re.I), file
    project = (ROOT/'com'/'HFSSProjectManager.m').read_text()
    update = project.split('function report = update(', 1)[1].split('function restore(', 1)[0]
    assert 'HFSSVariableManager.write' in update and 'o.validate' in update
    assert not re.search(r"'(?:NewProject|InsertDesign|SaveAs|Save|Analyze)'", update)
    assert "o.Healthy = false" in update and "ROLLBACK" in update
    session = (ROOT/'com'/'HFSSCOMConnection.m').read_text()
    assert 'actxGetRunningServer' in session and 'actxserver' in session and 'invoke(target, method, varargin{:})' in session
    main = (ROOT/'Vivaldi_DualPol_Live_API.m').read_text()
    assert main.count("uitab(tabs, 'Title'") == 5
    assert "'Limits', [-Inf Inf]" in main
    validator = (ROOT/'com'/'HFSSGeometryValidator.m').read_text()
    assert 'containsPoint' in validator and 'GetObjectVolume' in validator and 'GetFaceArea' in validator
    assert 'ratio = [.45 .55]' in validator
    required_docs = ['INSTALL_WINDOWS','DIRECT_COM_API_GUIDE','HFSS_SOURCE_ANALYSIS','GEOMETRY_RECONSTRUCTION',
                     'PARAMETRIC_DESIGN_GUIDE','LIVE_UPDATE_WORKFLOW','SIMULATION_GUIDE','TROUBLESHOOTING',
                     'VALIDATION_REPORT','KNOWN_LIMITATIONS']
    for name in required_docs: assert len((ROOT/'docs'/(name+'.md')).read_text()) > 300
    assert not list(ROOT.rglob('*.vbs'))
    return {'status':'PASS','matlabFiles':len(matlab),'sourceBytes':ref.stat().st_size,
            'sourceSHA256':SHA,'balancedSourceBlocks':blocks,
            'checks':['function/file names','source integrity','direct COM gateway','no script execution',
                      'same-project update guard','topology/volume probes present','five GUI tabs','required Vietnamese docs'],
            'scope':'Static structure only; MATLAB desktop/HFSS still PENDING'}

if __name__ == '__main__':
    print(json.dumps(audit(), ensure_ascii=False, indent=2))
