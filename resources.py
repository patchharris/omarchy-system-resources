#!/usr/bin/env python3
import json
import os
from pathlib import Path
import signal
import sys
import time


def identity(pid):
    raw = Path(f'/proc/{pid}/stat').read_text()
    fields = raw[raw.rfind(')') + 2:].split()
    return fields[19], int(fields[21]) * os.sysconf('SC_PAGE_SIZE')


def cpu():
    fields = list(map(int, Path('/proc/stat').read_text().splitlines()[0].split()[1:9]))
    return sum(fields), fields[3] + fields[4]


def snapshot():
    a, ai = cpu()
    time.sleep(0.2)
    b, bi = cpu()
    memory = {line.split(':')[0]: int(line.split()[1]) * 1024 for line in Path('/proc/meminfo').read_text().splitlines()}
    processes = []
    for path in Path('/proc').iterdir():
        if not path.name.isdigit():
            continue
        try:
            start, rss = identity(path.name)
            uid = path.stat().st_uid
            processes.append(dict(pid=int(path.name), start=start, rss=rss,
                                  name=(path / 'comm').read_text().strip(),
                                  killable=uid == os.getuid() and int(path.name) > 1 and int(path.name) not in (os.getpid(), os.getppid())))
        except (OSError, ValueError, IndexError):
            continue
    disks = []
    seen = set()
    for mount in ('/',):
        device = os.statvfs(mount).f_fsid
        if device in seen:
            continue
        seen.add(device)
        stat = os.statvfs(mount)
        total = stat.f_blocks * stat.f_frsize
        used = (stat.f_blocks - stat.f_bfree) * stat.f_frsize
        disks.append(dict(path=mount, total=total, used=used, percent=round(100 * used / total)))
    return dict(cpu=round(100 * (1 - (bi-ai) / max(1, b-a))),
                ramUsed=memory['MemTotal']-memory['MemAvailable'], ramTotal=memory['MemTotal'],
                disks=disks, processes=sorted(processes, key=lambda p: p['rss'], reverse=True)[:10])


def terminate(pid, start):
    pid = int(pid)
    if pid <= 1 or pid in (os.getpid(), os.getppid()):
        raise ValueError('This process is protected')
    fd = os.pidfd_open(pid)
    try:
        if identity(pid)[0] != start:
            raise ValueError('Process has changed; refresh and try again')
        if Path(f'/proc/{pid}').stat().st_uid != os.getuid():
            raise ValueError('You can only stop your own processes')
        signal.pidfd_send_signal(fd, signal.SIGTERM)
    finally:
        os.close(fd)
    return dict(message=f'Termination requested for PID {pid}')


if __name__ == '__main__':
    try:
        print(json.dumps(terminate(*sys.argv[2:]) if len(sys.argv) > 1 and sys.argv[1] == 'terminate' else snapshot()))
    except Exception as error:
        print(json.dumps(dict(error=str(error))))
        sys.exit(1)
