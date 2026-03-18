def foo():
    # This commented multi-line string delimiter should not prevent `bar()` 
    # from folding.
    # '''

def bar():
    pass
