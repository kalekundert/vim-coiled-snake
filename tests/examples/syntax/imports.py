import foo

code = 1

import foo
import foo

code = 1

import foo
import foo
import foo

code = 1

import foo
import foo
import foo
import foo

code = 1

import foo
import foo

# Comments between imports don't break the block.
import foo
import foo

# Comments before code aren't included in the block.
code = 1

from foo import foo

code = 1

from foo import foo
from foo import foo

code = 1

from foo import foo
from foo import foo
from foo import foo

code = 1

from foo import foo
from foo import foo
from foo import foo
from foo import foo

code = 1

from foo import foo
from foo import foo

# Comments between imports don't break the block.
from foo import foo
from foo import foo

# Comments before code aren't included in the block.
code = 1

# Imports broken across multiple lines should also be folded.

from foo import ()

code = 1

from foo import (
)

code = 1

from foo import (
foo
)

code = 1

from foo import (
foo
foo
)

code = 1

from foo import (
foo
foo
foo
)

code = 1

import foo; foo()
import foo
import foo
import foo

code = 1

from foo import \
        bar

code = 1

from foo import \
bar             \
bar

code = 1

from foo import \
bar             \
bar             \
bar

code = 1

from foo import \
bar             \
bar             \
bar             \
bar

code = 1

# Mixed imports fold correctly.

import foo
from foo import foo
from foo import (
foo
)
from foo import \
foo
