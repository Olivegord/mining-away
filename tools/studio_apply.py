#!/usr/bin/env python3
"""Apply committed code to the open DRONEREVOLUTION Studio session. Safe to run from any chat.

    python3 tools/studio_apply.py            install the current commit, save, refresh the canonical file
    python3 tools/studio_apply.py --status   read-only: what is installed, and does it match?
    python3 tools/studio_apply.py --wait 900 if the owner is in Play, wait up to 15 minutes for Edit

What makes it safe with several chats at once:
  * One machine-wide lock: installs never overlap; a second chat waits its turn.
  * Only COMMITTED code is bundled (from `git archive`), so another chat's half-finished
    edits in the same folder can never leak into an install.
  * Every Source in Studio must equal the bundle of some recent commit before it is
    replaced. Unknown Studio edits stop the install with nothing changed.
  * From a separate worktree, the integration branch is fast-forwarded first, so the
    install always contains everyone's merged work.
It never publishes, never starts Play and never changes anything while Studio is in Play.
"""
import argparse
import contextlib
import datetime
import fcntl
import hashlib
import importlib.util
import io
import json
import os
import pathlib
import select
import subprocess
import sys
import tarfile
import tempfile
import time

PLACE_ID = 124078027733625
UNIVERSE_ID = 10774898335
INTEGRATION = 'main'  # was codex/restore-feel-prestige until Nov 23
STUDIO_MCP = '/Applications/RobloxStudio.app/Contents/MacOS/StudioMCP'
HERE = pathlib.Path(__file__).resolve().parents[1]
LEDGER = 'docs/studio-installed.json'
CANONICAL = 'build/DRONE_GAME.rbxl'
HISTORY = 60  # recent commits searched for a known baseline


class Stop(Exception):
    """A refusal with a message for the chat; nothing further is changed."""


def git(*args, cwd=HERE, check=True, binary=False):
    result = subprocess.run(['git', *args], cwd=cwd, check=check, capture_output=True, text=not binary)
    return result.stdout if binary else result.stdout.strip()


def main_checkout():
    """The folder where the integration branch is checked out."""
    current, found = None, None
    for line in git('worktree', 'list', '--porcelain').splitlines():
        if line.startswith('worktree '):
            current = pathlib.Path(line[9:])
        elif line == 'branch refs/heads/' + INTEGRATION:
            found = current
    if not found:
        raise Stop(f'No folder has {INTEGRATION} checked out; cannot tell where the canonical file lives.')
    return found


def fingerprint(text):
    """Cheap exact-enough identity that Luau can compute identically."""
    data = text.encode()
    h = 0
    for byte in data:
        h = (h * 31 + byte) % 4294967296
    return f'{len(data)}:{h}'


_payloads = {}


def payload_at(commit, scratch):
    """The seven bundled Sources exactly as committed at `commit`."""
    if commit in _payloads:
        return _payloads[commit]
    target = pathlib.Path(scratch) / commit
    archive = git('archive', commit, 'src', 'tools/build.py', 'tools/refresh_editable.py', binary=True)
    with tarfile.open(fileobj=io.BytesIO(archive)) as tar:
        for member in tar.getmembers():
            parts = pathlib.PurePosixPath(member.name).parts
            assert parts and parts[0] in ('src', 'tools') and '..' not in parts and (member.isdir() or member.isfile())
        tar.extractall(target)
    spec = importlib.util.spec_from_file_location('build_' + commit[:12], target / 'tools/build.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    payload = module.live_source_payload()
    assert payload['place_id'] == PLACE_ID and payload['universe_id'] == UNIVERSE_ID
    _payloads[commit] = payload
    return payload


class Studio:
    """Minimal stdio client for the MCP server that ships inside Roblox Studio."""

    def __init__(self):
        if not os.path.exists(STUDIO_MCP):
            raise Stop('Roblox Studio is not installed at the expected path.')
        self.proc = subprocess.Popen([STUDIO_MCP], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
        self.next = 0
        self.request('initialize', {'protocolVersion': '2024-11-05', 'capabilities': {},
                                    'clientInfo': {'name': 'studio_apply', 'version': '1'}})
        self.send({'jsonrpc': '2.0', 'method': 'notifications/initialized'})
        self.studio_id = None

    def send(self, message):
        self.proc.stdin.write((json.dumps(message) + '\n').encode())
        self.proc.stdin.flush()

    def request(self, method, params, timeout=120):
        self.next += 1
        wanted = self.next
        self.send({'jsonrpc': '2.0', 'id': wanted, 'method': method, 'params': params})
        deadline = time.time() + timeout
        while time.time() < deadline:
            ready, _, _ = select.select([self.proc.stdout], [], [], 1)
            if not ready:
                continue
            line = self.proc.stdout.readline()
            if not line:
                break
            try:
                reply = json.loads(line)
            except ValueError:
                continue
            if reply.get('id') == wanted:
                if 'error' in reply:
                    raise Stop(f'Studio connector error: {reply["error"]}')
                return reply['result']
        raise Stop(f'Studio did not answer "{method}" in {timeout}s. Is Roblox Studio open?')

    def call(self, tool, arguments=None, timeout=120):
        arguments = dict(arguments or {})
        if self.studio_id and tool != 'list_roblox_studios':
            arguments['studio_id'] = self.studio_id
        result = self.request('tools/call', {'name': tool, 'arguments': arguments}, timeout)
        text = '\n'.join(part.get('text', '') for part in result.get('content', []) if part.get('type') == 'text')
        if result.get('isError'):
            raise Stop(f'Studio tool {tool} failed: {text[:600]}')
        return text

    def select_game(self):
        """Pick the DRONEREVOLUTION session by exact place and universe; return its mode."""
        studios = json.loads(self.call('list_roblox_studios'))['studios']
        matches = [s for s in studios if s.get('placeId') == PLACE_ID and s.get('universeId') == UNIVERSE_ID]
        if not matches:
            names = ', '.join(s.get('name') or s.get('state') or '?' for s in studios) or 'none'
            raise Stop(f'DRONEREVOLUTION (place {PLACE_ID}) is not open in Studio. Open sessions: {names}.')
        if len(matches) > 1:
            raise Stop('More than one DRONEREVOLUTION session is open; close the extra one.')
        self.studio_id = matches[0]['id']
        return matches[0].get('mode')

    def luau(self, code, timeout=180):
        return self.call('execute_luau', {'code': code, 'datamodel_type': 'Edit'}, timeout)

    def close(self):
        with contextlib.suppress(Exception):
            self.proc.kill()


PATHS_LUA = '''local function find(path)
 local node=game
 for name in path:gmatch('[^.]+') do node=node and node:FindFirstChild(name) end
 return node
end
'''

READ_LUA = PATHS_LUA + '''
assert(game.PlaceId==%d and game.GameId==%d,'Wrong game')
local out={running=game:GetService('RunService'):IsRunning(),sources={}}
for _,path in ipairs(%s) do
 local node=find(path)
 if node then
  local source=node.Source;local h=0
  for i=1,#source,4096 do
   for _,byte in ipairs({string.byte(source,i,math.min(#source,i+4095))}) do h=(h*31+byte)%%4294967296 end
  end
  out.sources[path]={class=node.ClassName,fp=#source..':'..string.format('%%d',h)}
 end
end
return game:GetService('HttpService'):JSONEncode(out)
'''

FP_LUA = '''local function fp(source)
 local h=0
 for i=1,#source,4096 do
  for _,byte in ipairs({string.byte(source,i,math.min(#source,i+4095))}) do h=(h*31+byte)%%4294967296 end
 end
 return #source..':'..string.format('%%d',h)
end
'''

# Sources travel in pieces through the connector (Studio's assistant refuses
# localhost HTTP). Each piece is a Luau long string; the assembled text must
# match the committed fingerprint before any script is touched.
CHUNK = 60000
STAGE_LUA = '''shared.StudioApply=shared.StudioApply or {}
local job=shared.StudioApply[%s] or {};shared.StudioApply[%s]=job
job[%s]=job[%s] or {}
job[%s][%d]=%s
return 'ok'
'''

INSTALL_LUA = PATHS_LUA + FP_LUA + '''
assert(not game:GetService('RunService'):IsRunning(),'Install only in Edit')
assert(game.PlaceId==%d and game.GameId==%d,'Wrong game')
local job=assert(shared.StudioApply and shared.StudioApply[%s],'Nothing staged')
shared.StudioApply[%s]=nil
local plan=game:GetService('HttpService'):JSONDecode(%s)
local targets,untouched={},{}
for path,entry in pairs(plan) do
 local node=assert(find(path),'Missing script: '..path)
 assert(node.ClassName==entry.class,'Wrong class: '..path)
 local current=fp(node.Source)
 assert(current==entry.before or current==entry.after,'Studio Source changed since it was checked: '..path)
 local after=nil
 if current~=entry.after then
  local pieces=assert(job[path],'Not staged: '..path)
  after=table.concat(pieces)
  assert(fp(after)==entry.after,'Staged text is damaged: '..path)
 end
 targets[node]={path=path,after=after,before=node.Source}
end
for _,node in ipairs(game:GetDescendants()) do
 if node:IsA('LuaSourceContainer') and not targets[node] then untouched[node]=node.Source end
end
local editor=game:GetService('ScriptEditorService')
local changed={}
local ok,err=pcall(function()
 for node,t in pairs(targets) do
  if t.after then
   editor:UpdateSourceAsync(node,function(current)
    assert(current==t.before,'Source changed during install: '..t.path)
    return t.after
   end)
   table.insert(changed,t.path)
  end
 end
 for node,t in pairs(targets) do assert(node.Source==(t.after or t.before),'Result mismatch: '..t.path) end
 for node,source in pairs(untouched) do assert(node.Source==source,'An unrelated script changed: '..node:GetFullName()) end
end)
if not ok then
 -- Put back anything already replaced so a failed install leaves Studio as it was.
 for node,t in pairs(targets) do
  if node.Source~=t.before then pcall(function() editor:UpdateSourceAsync(node,function() return t.before end) end) end
 end
 error(err)
end
table.sort(changed)
return game:GetService('HttpService'):JSONEncode({changed=changed})
'''


def long_string(text):
    # A Luau long string drops one leading newline, so always supply one.
    level = 1
    while (']' + '=' * level + ']') in text or text.endswith(']' + '=' * level):
        level += 1
    return '[' + '=' * level + '[\n' + text + ']' + '=' * level + ']'


def stage(studio, job, path, text):
    assert '\r' not in text, 'Carriage returns would not survive a Luau long string: ' + path
    data = text.encode()
    pieces, start = [], 0
    while start < len(data):
        end = min(len(data), start + CHUNK)
        while end < len(data) and (data[end] & 0xC0) == 0x80:  # never split a UTF-8 character
            end -= 1
        pieces.append(data[start:end].decode()); start = end
    key = json.dumps(job); name = json.dumps(path)
    for index, piece in enumerate(pieces, 1):
        studio.luau(STAGE_LUA % (key, key, name, name, name, index, long_string(piece)))
    return len(pieces)


def parse_json(text):
    start, end = text.find('{'), text.rfind('}')
    if start < 0 or end < 0:
        raise Stop('Unexpected reply from Studio: ' + text[:300])
    return json.loads(text[start:end + 1])


def read_installed(studio, paths):
    lua_list = '{' + ','.join(json.dumps(p) for p in paths) + '}'
    return parse_json(studio.luau(READ_LUA % (PLACE_ID, UNIVERSE_ID, lua_list)))


def find_baselines(installed, target, commits, scratch):
    """For each Source, the committed text that is in Studio right now (or None)."""
    baselines, origin = {}, {}
    for path, entry in target['sources'].items():
        have = installed['sources'].get(path)
        if not have:
            raise Stop(f'{path} does not exist in Studio.')
        if have['class'] != entry['class']:
            raise Stop(f'{path} is a {have["class"]} in Studio; expected {entry["class"]}.')
        if have['fp'] == fingerprint(entry['source']):
            baselines[path], origin[path] = entry['source'], 'target'
    for commit in commits:
        if len(baselines) == len(target['sources']):
            break
        try:
            payload = payload_at(commit, scratch)
        except (OSError, ImportError, AssertionError) as error:
            # A commit whose build cannot run (e.g. it read a file outside src/) was never
            # installed, so it cannot be what Studio has. The exact-match rule is unchanged.
            print(f'Note: skipping baseline {commit[:7]} (does not build: {type(error).__name__}).')
            continue
        for path, entry in payload['sources'].items():
            if path not in baselines and path in installed['sources'] and installed['sources'][path]['fp'] == fingerprint(entry['source']):
                baselines[path], origin[path] = entry['source'], commit
    return baselines, origin


@contextlib.contextmanager
def machine_lock(wait):
    path = pathlib.Path(git('rev-parse', '--path-format=absolute', '--git-common-dir')) / 'studio-apply.lock'
    handle = open(path, 'a+')
    deadline = time.time() + wait
    announced = False
    while True:
        try:
            fcntl.flock(handle, fcntl.LOCK_EX | fcntl.LOCK_NB)
            break
        except BlockingIOError:
            if time.time() > deadline:
                handle.seek(0)
                raise Stop('Another chat is still installing (' + handle.read().strip() + '). Try again shortly.')
            if not announced:
                print('Another chat is installing; waiting for it to finish...', flush=True)
                announced = True
            time.sleep(2)
    handle.seek(0); handle.truncate()
    handle.write(f'pid {os.getpid()} since {datetime.datetime.now().isoformat(timespec="seconds")} from {HERE}')
    handle.flush()
    try:
        yield
    finally:
        handle.seek(0); handle.truncate(); handle.flush()
        fcntl.flock(handle, fcntl.LOCK_UN)
        handle.close()


def refresh_canonical(main, target_commit, target, baseline_sources, scratch):
    """Rewrite only the seven Sources inside the canonical place file."""
    tree = pathlib.Path(scratch) / target_commit
    sys.path.insert(0, str(tree / 'tools'))
    try:
        for name in ('build', 'refresh_editable'):
            sys.modules.pop(name, None)
        import refresh_editable  # the committed version, reading the committed src
        previous = dict(target, sources={p: {'class': target['sources'][p]['class'], 'source': s,
                                             'sha256': hashlib.sha256(s.encode()).hexdigest()}
                                         for p, s in baseline_sources.items()})
        previous_file = pathlib.Path(scratch) / 'previous-payload.json'
        previous_file.write_text(json.dumps(previous, ensure_ascii=False))
        destination = main / CANONICAL
        try:
            refresh_editable.refresh(previous_payload=previous_file, destination=destination)
        except AssertionError:
            # The file may be one install behind Studio; accept any recent commit's Sources.
            done = False
            for commit in recent_commits(main):
                candidate = pathlib.Path(scratch) / f'previous-{commit[:12]}.json'
                candidate.write_text(json.dumps(payload_at(commit, scratch), ensure_ascii=False))
                try:
                    refresh_editable.refresh(previous_payload=candidate, destination=destination)
                    done = True
                    break
                except AssertionError:
                    continue
            if not done:
                raise Stop('Installed in Studio and saved, but the canonical file holds Sources from no recent commit, '
                           'so it was NOT refreshed. Studio and build/DRONE_GAME.rbxl now differ.')
        return hashlib.sha256(destination.read_bytes()).hexdigest()
    finally:
        sys.path.pop(0)
        for name in ('build', 'refresh_editable'):
            sys.modules.pop(name, None)


def recent_commits(main):
    # Not --first-parent: when a worktree merges the integration branch and the tool
    # fast-forwards to that merge, the commit another chat installed meanwhile sits on
    # the merge's second parent. Every candidate is still an exact committed bundle.
    # tools/build.py shapes the bundles too: a commit that only changes it can be installed.
    return git('log', f'-n{HISTORY}', '--format=%H', INTEGRATION, '--', 'src', 'tools/build.py', cwd=main).split()


def report(installed, target, origin, target_commit):
    lines = []
    for path in sorted(target['sources']):
        where = origin.get(path)
        state = 'up to date' if where == 'target' else f'has {where[:7]}' if where else 'UNKNOWN EDIT (matches no recent commit)'
        lines.append(f'  {path}: {state}')
    return '\n'.join(lines)


def run(args):
    main = main_checkout()
    here_branch = git('rev-parse', '--abbrev-ref', 'HEAD')
    with machine_lock(args.lock_wait), tempfile.TemporaryDirectory(prefix='studio-apply-') as scratch:
        if not args.status and HERE.resolve() != main.resolve():
            # A chat in its own worktree: its commit must already contain everyone else's work.
            head = git('rev-parse', 'HEAD')
            if subprocess.run(['git', 'merge-base', '--is-ancestor', INTEGRATION, head], cwd=HERE).returncode != 0:
                raise Stop(f'Your branch {here_branch} does not include the latest {INTEGRATION}. '
                           f'Run `git merge {INTEGRATION}`, re-test, commit, then apply again.')
            if git('status', '--porcelain', '--untracked-files=no'):
                raise Stop('You have uncommitted changes. Commit them first; only committed code is installed.')
            merged = subprocess.run(['git', 'merge', '--ff-only', head], cwd=main, capture_output=True, text=True)
            if merged.returncode != 0:
                raise Stop(f'Could not fast-forward {INTEGRATION} in {main}: {merged.stderr.strip()[:400]}')
            print(f'Fast-forwarded {INTEGRATION} to {head[:7]}.')
        target_commit = git('rev-parse', INTEGRATION if not args.status else 'HEAD', cwd=main if not args.status else HERE)
        if not args.status:
            dirty = git('status', '--porcelain', '--', CANONICAL, LEDGER, cwd=main)
            if dirty:
                raise Stop(f'{CANONICAL} or {LEDGER} has uncommitted changes in {main}; commit or restore them first.')
            pending = git('status', '--porcelain', '--untracked-files=no', '--', 'src', cwd=main)
            if pending:
                print('Note: uncommitted src/ edits exist in the shared folder and are NOT part of this install:\n' + pending)
        target = payload_at(target_commit, scratch)
        studio = Studio()
        try:
            mode = studio.select_game()
            waited = 0
            while mode != 'Edit' and not args.status:
                if waited >= args.wait:
                    raise Stop(f'Studio is in {mode}, not Edit, so nothing was changed. '
                               'Run again when Play has ended (or pass --wait SECONDS).')
                if waited == 0:
                    print(f'Studio is in {mode}; waiting for Edit...', flush=True)
                time.sleep(10); waited += 10
                mode = studio.select_game()
            installed = read_installed(studio, sorted(target['sources']))
            baselines, origin = find_baselines(installed, target, recent_commits(main), scratch)
            print(f'Studio: DRONEREVOLUTION place {PLACE_ID}, universe {UNIVERSE_ID}, mode {mode}')
            print(f'Target: {target_commit[:7]} ({git("log", "-1", "--format=%s", target_commit)})')
            print(report(installed, target, origin, target_commit))
            unknown = sorted(set(target['sources']) - set(baselines))
            if args.status:
                return 0 if not unknown and all(v == 'target' for v in origin.values()) else 1
            if unknown:
                raise Stop('Studio has edits that match no recent commit, so nothing was changed: ' + ', '.join(unknown) +
                           '. Bring those edits into src/ (or restore the scripts), then apply again.')
            changed = []
            if any(v != 'target' for v in origin.values()):
                job = f'{os.getpid()}-{int(time.time())}'
                plan = {}
                for p, e in target['sources'].items():
                    plan[p] = {'class': e['class'], 'before': fingerprint(baselines[p]), 'after': fingerprint(e['source'])}
                    if origin[p] != 'target':
                        print(f'  sending {p} ({stage(studio, job, p, e["source"])} pieces)', flush=True)
                key = json.dumps(job)
                changed = parse_json(studio.luau(INSTALL_LUA % (PLACE_ID, UNIVERSE_ID, key, key, long_string(json.dumps(plan))), timeout=300))['changed']
                after = read_installed(studio, sorted(target['sources']))
                for path, entry in target['sources'].items():
                    if after['sources'][path]['fp'] != fingerprint(entry['source']):
                        raise Stop(f'After install, {path} in Studio does not match {target_commit[:7]}. Not saved.')
                print('Installed: ' + (', '.join(changed) or 'nothing needed'))
                print('Save: ' + studio.call('save_place', {'notes': f'studio_apply {target_commit[:7]}'}, timeout=300)[:200])
            else:
                print('Studio already has this commit; nothing to install.')
        finally:
            studio.close()
        canonical = refresh_canonical(main, target_commit, target, baselines, scratch)
        ledger = {'commit': target_commit, 'installed_at': datetime.datetime.now(datetime.timezone.utc).isoformat(timespec='seconds'),
                  'place_id': PLACE_ID, 'universe_id': UNIVERSE_ID, 'canonical_sha256': canonical,
                  'sources': {p: e['sha256'] for p, e in sorted(target['sources'].items())}}
        (main / LEDGER).write_text(json.dumps(ledger, indent=2) + '\n')
        git('add', '--', CANONICAL, LEDGER, cwd=main)
        if git('status', '--porcelain', '--', CANONICAL, LEDGER, cwd=main):
            git('commit', '-m', f'Install {target_commit[:7]} in shared Edit and refresh canonical', '--', CANONICAL, LEDGER, cwd=main)
        print(f'Canonical {CANONICAL}: sha256 {canonical}')
        print(f'DONE. The next Play in DRONEREVOLUTION runs {target_commit[:7]}. Not published.')
        return 0


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--status', action='store_true', help='read-only comparison of Studio with the current commit')
    parser.add_argument('--wait', type=int, default=0, help='seconds to wait for the owner to leave Play')
    parser.add_argument('--lock-wait', type=int, default=600, help='seconds to wait for another chat\'s install')
    try:
        sys.exit(run(parser.parse_args()))
    except Stop as stop:
        print('STOPPED: ' + str(stop))
        sys.exit(2)
