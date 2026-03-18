# Related to #22. Adding a lone # after a function should prevent folding as in
# test_ignore.py. Here, including more text after the # (like a comment, or
# code to prevent a linting message), should allow it to fold again. Including
# another # at the end of the line should still prevent folding.

def foo(): # comment here should still fold
    pass

def foo(): # trailing # still prevents folding #
    pass

@decorator
def foo(): # comment here should still fold
    pass

@decorator
def foo(): # trailing # still prevents folding #
    pass
