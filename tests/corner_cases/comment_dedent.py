def f1():
    # folded
# not folded

def f2():
    def g1():
        # folded
    # not folded
    def g2():
        # folded
    # not folded
# not folded

def f3():
# folded
    x = 1
# not folded
