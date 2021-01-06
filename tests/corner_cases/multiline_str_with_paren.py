#!/usr/bin/env python3

# The parentheses should end, allowing the `foo()` function to fold properly, 
# even though the multiline string ends on the same line.

(
"""\
multline string
""")

def foo():
    pass
