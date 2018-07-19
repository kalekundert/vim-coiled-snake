'''
Docstring
'''

import foo
import bar

from bar import baz
from qux import quz

class Class:
    """ Doc """

    class NestedClass:
        pass

    def method():
        def nested_method():
            pass

    @decorator
    def decoratee():
        pass

def function():
    code = 0
    more_code = 1

    def nested_function():
        pass

code = 0
more_code = 1
    
if __name__ == '__main__':
    pass
