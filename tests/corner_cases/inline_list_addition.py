# The `] + [` line should not start a data structure fold that extends to the 
# end of the file, in turn messing up the foo() and bar() folds.

x = [
        1,
        2,
] + [
        3,
        4,
]

def foo():
    pass

def bar():
    pass
