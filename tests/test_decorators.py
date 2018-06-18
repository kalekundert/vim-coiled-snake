@decorator
def function():
    pass

@decorator(
        args)
def function():
    pass


@decorator
class Class:

    @decorator
    def method():
        pass

    @decorator
    def method():
        pass


    @decorator
    def method():
        pass


