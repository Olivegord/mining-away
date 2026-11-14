#!/usr/bin/env python3
"""Compatibility entry point for the current Quartz economy; historical fixtures remain in tests/."""
import subprocess,sys
from pathlib import Path
subprocess.run([sys.executable,str(Path(__file__).with_name('test_workshop.py')),*sys.argv[1:]],check=True)
