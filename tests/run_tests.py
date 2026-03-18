#!/usr/bin/env python3
"""Automated test runner for vim-coiled-snake fold marks."""

from __future__ import annotations

import argparse
import io
import shlex
import subprocess
import tempfile
from dataclasses import dataclass
from pathlib import Path
from textwrap import indent
from typing import Protocol, Callable, Iterable, Sequence

TEST_DIR = Path(__file__).parent
COLLECT_SCRIPT = TEST_DIR / 'collect_marks.vim'
DEFAULT_VIMRC = TEST_DIR / 'vimrcs' / 'default'
EXAMPLES_DIR = TEST_DIR / 'examples'

class Runner(Protocol):
    name: str

    def __call__(self, test_case: TestCase, log: io.IOBase) -> str:
        ...

class SubprocessRunner(Runner):

    def __init__(
            self,
            name: str,
            cmd_factory: Callable[[TestCase, Path], list[str]],
    ):
        self.name = name
        self.cmd_factory = cmd_factory

    def __repr__(self):
        return f'<SubprocessRunner {self.name}>'

    def __call__(self, test_case: TestCase, log: io.IOBase) -> str:
        with tempfile.TemporaryDirectory() as tmp_dir:
            empty_home = Path(tmp_dir) / 'empty_home'
            empty_home.mkdir()

            out_path = Path(tmp_dir) / 'actual.marks'

            cmd = self.cmd_factory(test_case, out_path)
            env = {'HOME': str(empty_home)}

            print_kv("command", ' '.join(shlex.quote(str(c)) for c in cmd), file=log)
            print_kv("environment", '\n'.join(f'  {k}={v}' for k, v in env.items()), file=log)

            p = subprocess.run(
                cmd,
                env=env,
                timeout=10,
                stdin=subprocess.DEVNULL,
                capture_output=True,
                text=True,
            )
            print_kv("stdout", p.stdout.strip(), file=log)
            print_kv("stderr", p.stderr.strip(), file=log)
            print_kv("return code", p.returncode, file=log)

            if not out_path.exists():
                log.seek(0)
                raise RuntimeError(
                        f"command did not create expected output file: {out_path}\n"
                        + log.read()
                )
            return out_path.read_text()

@dataclass
class TestCase:
    input_file: Path
    marks_file: Path
    vimrc: Path
    runner: Runner

def vim_cmd(test_case: TestCase, out_path: Path) -> list[str]:
    return [
        'vim',
        '--clean',
        '--not-a-term',
        '-n',  # no swap files
        '-u', str(test_case.vimrc),
        '--cmd', f"let g:marks_output_file='{out_path}'",
        '-S', str(COLLECT_SCRIPT),
        str(test_case.input_file),
    ]

def neovim_cmd(test_case: TestCase, out_path: Path) -> list[str]:
    return [
        'nvim',
        '--clean',
        '--headless',
        '-n',  # no swap files
        '-u', str(test_case.vimrc),
        '--cmd', f"let g:marks_output_file='{out_path}'",
        '-S', str(COLLECT_SCRIPT),
        str(test_case.input_file),
    ]

RUNNERS = {
        x.name: x
        for x in [
            SubprocessRunner('vim', vim_cmd),
            SubprocessRunner('nvim', neovim_cmd),
        ]
}

def main():
    parser = argparse.ArgumentParser(
            description="Run vim-coiled-snake fold mark tests.",
    )
    parser.add_argument(
            'tests',
            nargs='*',
            metavar='<test>',
            help="test files to run (default: all)",
    )
    parser.add_argument(
            '--vim',
            dest='vim',
            action='append_const',
            const=RUNNERS['vim'],
            help="only run test(s) in vim",
    )
    parser.add_argument(
            '--nvim',
            dest='vim',
            action='append_const',
            const=RUNNERS['nvim'],
            help="only run test(s) in nvim",
    )
    parser.add_argument(
            '-x',
            dest='fail_fast',
            action='store_true',
            help="stop after first failure",
    )
    args = parser.parse_args()

    discover_kwargs = {}

    if args.tests:
        discover_kwargs['test_paths'] = [Path(x) for x in args.tests]
    if args.vim:
        discover_kwargs['runners'] = args.vim

    test_cases = discover_tests(**discover_kwargs)
    success = run_tests(test_cases, fail_fast=args.fail_fast)

    raise SystemExit(0 if success else 1)

def discover_tests(
        test_paths: Iterable[Path] | None = None,
        runners: Sequence[Runner] = tuple(RUNNERS.values()),
) -> list[TestCase]:
    """Find all test input files, return list of TestCase."""

    if test_paths is None:
        test_paths = sorted(
                EXAMPLES_DIR.glob('**/*.py'),
                key=lambda x: (len(x.parts), x)
        )

    return [
        TestCase(
            input_file=x,
            marks_file=x.with_suffix('.marks'),
            vimrc=find_vimrc(x),
            runner=runner,
        )
        for x in test_paths
        for runner in runners
    ]

def run_tests(test_cases: Sequence[TestCase], fail_fast: bool = False) -> bool:
    """Run all tests. Print failures, then a summary line."""
    passed = failed = new = 0

    def print_failure(test_case, status, log):
        title = f"{status}: {test_case.input_file} ({test_case.runner.name})"
        print(title)
        print('=' * len(title))

        print(log.getvalue())
        print_kv("input", test_case.input_file.read_text())
        print_kv("vimrc", test_case.vimrc.read_text())

    for test_case in test_cases:
        if fail_fast and failed:
            break

        log = io.StringIO()

        try:
            actual = test_case.runner(test_case, log)
        except Exception as e:
            print_failure(test_case, "ERROR", log)
            print_kv("error", e)
            failed += 1
            continue

        if not test_case.marks_file.exists():
            print_failure(test_case, "NEW", log)
            print_kv("actual", actual)
            print()
            print("To create marks file:")
            actual_one_line = "\\n".join(actual.splitlines())
            print(f"  echo -e {shlex.quote(actual_one_line)} > {test_case.marks_file}")
            new += 1
            continue

        expected = test_case.marks_file.read_text()
        if actual == expected:
            passed += 1
        else:
            print_failure(test_case, "FAIL", log)
            print_kv("actual", actual)
            print_kv("expected", expected)
            failed += 1

    success = (failed == 0 and new == 0)
    num_tests = passed + failed + new

    message = (
            f"{'success' if success else 'fail'}: "
            f"{plural(num_tests, 'test', 'tests')}, "
            f"{passed} passed, "
            f"{failed} failed"
    )
    if new:
        message += f", {new} new"
    print(message)

    return success

def find_vimrc(test_path: Path) -> Path:
    """Return companion `*.vimrc` if it exists, otherwise the default."""
    vimrc = test_path.with_suffix('.vimrc')
    return vimrc if vimrc.exists() else DEFAULT_VIMRC

def print_kv(key, value, **kwargs):
    value = str(value)
    if '\n' not in value:
        print(f"{key}: {value}", **kwargs)
    else:
        print(f"{key}:\n{indent(value, '  ')}", **kwargs)

def plural(n, singular, plural):
    if n == 1:
        return f'{n} {singular}'
    else:
        return f'{n} {plural}'


if __name__ == '__main__':
    main()
